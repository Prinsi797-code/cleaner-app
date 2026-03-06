//  VideoCompressView.swift

import SwiftUI
import Combine
import Photos
import AVFoundation

// MARK: - Models
struct CompressVideoItem: Identifiable {
    let id: String
    let asset: PHAsset
    let filename: String
    let fileSize: Int64
    let duration: TimeInterval
    let creationDate: Date?
}

enum CompressQuality: String, CaseIterable, Identifiable {
    case low    = "Low (360p)"
    case medium = "Medium (540p)"
    case high   = "High (720p)"
    case best   = "Best (1080p)"

    var id: String { rawValue }

    var preset: String {
        switch self {
        case .low:    return AVAssetExportPreset640x480
        case .medium: return AVAssetExportPreset960x540
        case .high:   return AVAssetExportPreset1280x720
        case .best:   return AVAssetExportPreset1920x1080
        }
    }

    var description: String {
        switch self {
        case .low:    return "~60% smaller"
        case .medium: return "~45% smaller"
        case .high:   return "~30% smaller"
        case .best:   return "~15% smaller"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green; case .medium: return .blue
        case .high: return .orange; case .best: return .purple
        }
    }
}

struct CompressResult: Identifiable {
    let id = UUID()
    let filename: String
    let originalSize: Int64
    let compressedSize: Int64
    let savedFileURL: URL       // ✅ Keep file URL for sharing/download
    var savedSize: Int64 { originalSize - compressedSize }
    var savedPercent: Int { originalSize > 0 ? Int(Double(savedSize) / Double(originalSize) * 100) : 0 }
}

// MARK: - Service
class VideoCompressService {
    static let shared = VideoCompressService()

    // ✅ Persistent folder in Documents so files survive
    private var outputDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CompressedVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func fetchVideos(completion: @escaping ([CompressVideoItem]) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion([]) }; return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let opts = PHFetchOptions()
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let assets = PHAsset.fetchAssets(with: .video, options: opts)
                var items: [CompressVideoItem] = []
                assets.enumerateObjects { asset, _, _ in
                    let res      = PHAssetResource.assetResources(for: asset)
                    let fileSize = res.first.flatMap { $0.value(forKey: "fileSize") as? Int64 } ?? 0
                    let filename = res.first?.originalFilename ?? "video.mp4"
                    items.append(CompressVideoItem(
                        id: asset.localIdentifier, asset: asset,
                        filename: filename, fileSize: fileSize,
                        duration: asset.duration, creationDate: asset.creationDate
                    ))
                }
                DispatchQueue.main.async {
                    completion(items.sorted { $0.fileSize > $1.fileSize })
                }
            }
        }
    }

    func compressVideo(
        asset: PHAsset,
        quality: CompressQuality,
        progress: @escaping (Float) -> Void,
        completion: @escaping (CompressResult?, Error?) -> Void
    ) {
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat

        PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
            guard let avAsset else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "Compress", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Could not load video"]))
                }
                return
            }

            guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: quality.preset) else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "Compress", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "Format not supported"]))
                }
                return
            }

            // ✅ Save to Documents/CompressedVideos — persistent, shareable
            let origName  = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "video"
            let baseName  = URL(fileURLWithPath: origName).deletingPathExtension().lastPathComponent
            let outName   = "\(baseName)_compressed_\(Int(Date().timeIntervalSince1970)).mp4"
            let outputURL = self.outputDir.appendingPathComponent(outName)
            try? FileManager.default.removeItem(at: outputURL)

            exportSession.outputURL      = outputURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true

            let originalSize = PHAssetResource.assetResources(for: asset)
                .first.flatMap { $0.value(forKey: "fileSize") as? Int64 } ?? 0

            // Poll progress on main thread
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async { progress(exportSession.progress) }
            }
            RunLoop.main.add(timer, forMode: .common)

            exportSession.exportAsynchronously {
                timer.invalidate()
                switch exportSession.status {
                case .completed:
                    let compSize = (try? FileManager.default
                        .attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

                    // ✅ Also save copy to Photos library
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                    }) { _, _ in }

                    DispatchQueue.main.async {
                        completion(CompressResult(
                            filename: outName,
                            originalSize: originalSize,
                            compressedSize: compSize,
                            savedFileURL: outputURL   // ✅ URL for share/download
                        ), nil)
                    }

                case .failed, .cancelled:
                    DispatchQueue.main.async { completion(nil, exportSession.error) }
                default:
                    break
                }
            }
        }
    }

    // ✅ List already compressed files in Documents
    func savedCompressedFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: outputDir, includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ))?.filter { $0.pathExtension == "mp4" } ?? []
    }

    func deleteFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - ViewModel
@MainActor
class VideoCompressViewModel: ObservableObject {
    @Published var videos:           [CompressVideoItem] = []
    @Published var isLoading         = false
    @Published var selectedIDs       = Set<String>()
    @Published var quality: CompressQuality = .medium
    @Published var isCompressing     = false
    @Published var compressProgress: Float = 0
    @Published var currentFile       = ""
    @Published var results:          [CompressResult] = []
    @Published var showResults       = false
    @Published var toastMessage:     String?
    @Published var compressDoneCount = 0
    @Published var shareURL: URL?    // ✅ For share sheet
    @Published var showShareSheet    = false
    @Published var savedFiles:       [URL] = []   // ✅ Previously compressed files

    var totalSelectedSize: Int64 {
        videos.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    func load() {
        isLoading = true
        VideoCompressService.shared.fetchVideos { [weak self] items in
            self?.videos    = items
            self?.isLoading = false
            self?.loadSavedFiles()
        }
    }

    func loadSavedFiles() {
        savedFiles = VideoCompressService.shared.savedCompressedFiles()
            .sorted { ($0.lastPathComponent) > ($1.lastPathComponent) }
    }

    func toggleSelect(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func selectAll()   { selectedIDs = Set(videos.map(\.id)) }
    func deselectAll() { selectedIDs = [] }

    func compressSelected() {
        let toCompress = videos.filter { selectedIDs.contains($0.id) }
        guard !toCompress.isEmpty else { return }
        isCompressing = true; results = []; compressDoneCount = 0
        compress(queue: toCompress, index: 0)
    }

    private func compress(queue: [CompressVideoItem], index: Int) {
        guard index < queue.count else {
            isCompressing = false
            showResults   = true
            loadSavedFiles()
            return
        }
        let item = queue[index]
        currentFile      = item.filename
        compressProgress = 0

        VideoCompressService.shared.compressVideo(
            asset: item.asset, quality: quality,
            progress: { [weak self] p in self?.compressProgress = p },
            completion: { [weak self] result, _ in
                if let r = result { self?.results.append(r) }
                self?.compressDoneCount += 1
                self?.compress(queue: queue, index: index + 1)
            }
        )
    }

    // ✅ Share a single file
    func share(_ url: URL) {
        shareURL     = url
        showShareSheet = true
    }

    // ✅ Delete a saved file
    func deleteSavedFile(_ url: URL) {
        VideoCompressService.shared.deleteFile(url)
        loadSavedFiles()
        toast("🗑️ File deleted")
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View
struct VideoCompressView: View {
    @StateObject private var vm = VideoCompressViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                if vm.isLoading {
                    ScanningView(text: "Loading videos…", progress: 0)
                } else if vm.isCompressing {
                    compressingView
                } else if vm.showResults {
                    resultsView
                } else if vm.videos.isEmpty {
                    EmptyStateView(icon: "video.fill", title: "No Videos",
                                   subtitle: "No videos in library",
                                   buttonTitle: "Refresh") { vm.load() }
                } else {
                    videoListBody
                }

                if let msg = vm.toastMessage {
                    VStack { Spacer(); ToastView(message: msg).padding(.bottom, 90) }
                        .animation(.spring(), value: vm.toastMessage)
                }
            }
            .navigationTitle("Compress Videos")
            .sheet(isPresented: $vm.showShareSheet) {
                if let url = vm.shareURL { ShareSheet(url: url) }
            }
            .onAppear { if vm.videos.isEmpty { vm.load() } }
        }
    }

    // MARK: - Compressing View
    private var compressingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(Color.purple.opacity(0.15), lineWidth: 12).frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: CGFloat(vm.compressProgress))
                    .stroke(LinearGradient(colors: [.purple, .pink],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                    .animation(.easeInOut, value: vm.compressProgress)
                VStack(spacing: 4) {
                    Text("\(Int(vm.compressProgress * 100))%").font(.title2).bold()
                    Text("\(vm.compressDoneCount)/\(vm.selectedIDs.count)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Text("Compressing…").font(.headline)
            Text(vm.currentFile).font(.caption).foregroundColor(.secondary)
                .lineLimit(1).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Header
            let totalSaved = vm.results.reduce(Int64(0)) { $0 + $1.savedSize }
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52)).foregroundColor(.green)
                Text("Done!").font(.title2).bold()
                Text("Saved \(formatBytes(totalSaved)) total")
                    .font(.subheadline).foregroundColor(.secondary)
                Button("Compress More") { vm.showResults = false; vm.selectedIDs = [] }
                    .font(.subheadline).bold().foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.purple).clipShape(Capsule())
            }
            .padding()

            Divider()

            // Results list with download/share buttons
            List {
                ForEach(vm.results) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.filename).font(.subheadline).lineLimit(1)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(formatBytes(result.originalSize))
                                        .font(.caption).foregroundColor(.secondary)
                                    Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                                    Text(formatBytes(result.compressedSize))
                                        .font(.caption).bold().foregroundColor(.green)
                                }
                                Text("Saved \(result.savedPercent)%")
                                    .font(.caption).bold().foregroundColor(.green)
                            }
                            Spacer()

                            // ✅ Share button
                            Button {
                                vm.share(result.savedFileURL)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.caption).bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }

                            // ✅ Save to Files button
                            Button {
                                saveToFiles(result.savedFileURL)
                            } label: {
                                Label("Files", systemImage: "folder.badge.plus")
                                    .font(.caption).bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Video List
    private var videoListBody: some View {
        VStack(spacing: 0) {
            // Quality picker
            VStack(spacing: 10) {
                HStack {
                    Text("Compression Quality").font(.subheadline).bold()
                    Spacer()
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CompressQuality.allCases) { q in
                        QualityCard(quality: q, isSelected: vm.quality == q) { vm.quality = q }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            // Summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.videos.count) videos").font(.subheadline).bold()
                    if !vm.selectedIDs.isEmpty {
                        Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                            .font(.caption).foregroundColor(.purple)
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(vm.selectedIDs.count == vm.videos.count ? "Deselect All" : "Select All") {
                        if vm.selectedIDs.count == vm.videos.count { vm.deselectAll() } else { vm.selectAll() }
                    }.font(.caption).foregroundColor(.purple)

                    if !vm.selectedIDs.isEmpty {
                        Button("Compress ▶") { vm.compressSelected() }
                            .font(.caption).bold().foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.purple).clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 10)

            // ✅ Previously compressed files section
            if !vm.savedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Compressed Files (\(vm.savedFiles.count))")
                            .font(.caption).bold().foregroundColor(.secondary)
                        Spacer()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.savedFiles, id: \.absoluteString) { url in
                                SavedFileChip(url: url,
                                    onShare: { vm.share(url) },
                                    onDelete: { vm.deleteSavedFile(url) }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))
            }

            List {
                ForEach(vm.videos) { item in
                    CompressVideoRow(item: item, isSelected: vm.selectedIDs.contains(item.id)) {
                        vm.toggleSelect(item.id)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }

    // ✅ Save to Files app using document picker
    private func saveToFiles(_ url: URL) {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root  = scene.windows.first?.rootViewController {
            root.present(picker, animated: true)
        }
    }
}

// MARK: - Saved File Chip
struct SavedFileChip: View {
    let url: URL
    let onShare: () -> Void
    let onDelete: () -> Void

    var fileSize: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(url.lastPathComponent)
                .font(.system(size: 10)).lineLimit(1).frame(maxWidth: 120, alignment: .leading)
            Text(formatBytes(fileSize)).font(.system(size: 10, weight: .bold)).foregroundColor(.green)
            HStack(spacing: 6) {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11)).foregroundColor(.blue)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11)).foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Quality Card
struct QualityCard: View {
    let quality: CompressQuality
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(quality.rawValue).font(.caption).bold()
            Text(quality.description).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(isSelected ? quality.color.opacity(0.15) : Color(.tertiarySystemBackground))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? quality.color : Color.clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { onTap() }
    }
}

// MARK: - Compress Video Row
struct CompressVideoRow: View {
    let item: CompressVideoItem
    let isSelected: Bool
    let onTap: () -> Void
    @State private var thumb: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = thumb { Image(uiImage: img).resizable().scaledToFill() }
                    else { Color.gray.opacity(0.3) }
                }
                .frame(width: 80, height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2))

                Text(formatDuration(item.duration))
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4)).padding(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename).font(.subheadline).lineLimit(2)
                Text(formatBytes(item.fileSize)).font(.subheadline).bold().foregroundColor(.orange)
                if let d = item.creationDate {
                    Text(d.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()

            ZStack {
                Circle().stroke(isSelected ? Color.purple : Color.gray.opacity(0.4), lineWidth: 2)
                    .frame(width: 26, height: 26)
                if isSelected {
                    Circle().fill(Color.purple).frame(width: 18, height: 18)
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.purple.opacity(0.06) : Color(.secondarySystemBackground)))
        .onTapGesture { onTap() }
        .onAppear {
            guard thumb == nil else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat; opts.isSynchronous = false
            PHImageManager.default().requestImage(
                for: item.asset, targetSize: CGSize(width: 160, height: 120),
                contentMode: .aspectFill, options: opts
            ) { img, _ in DispatchQueue.main.async { thumb = img } }
        }
    }
}
