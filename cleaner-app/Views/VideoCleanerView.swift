//  VideoCleanerView.swift
//  Model + ViewModel + View all in one file (no separate service needed)

import SwiftUI
import Combine
import Photos

// MARK: - Model
struct VideoItem: Identifiable {
    let id: String
    let asset: PHAsset
    let filename: String
    let fileSize: Int64
    let duration: TimeInterval
    let creationDate: Date?
}

// MARK: - ViewModel
@MainActor
class VideoCleanerViewModel: ObservableObject {
    @Published var videos:         [VideoItem] = []
    @Published var isLoading       = false
    @Published var selectedIDs     = Set<String>()
    @Published var sortBy: SortOption = .size
    @Published var showDeleteAlert = false
    @Published var toastMessage:   String?

    enum SortOption: String, CaseIterable {
        case size = "Largest", newest = "Newest", oldest = "Oldest", duration = "Longest"
    }

    var sorted: [VideoItem] {
        switch sortBy {
        case .size:     return videos.sorted { $0.fileSize > $1.fileSize }
        case .newest:   return videos.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        case .oldest:   return videos.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .duration: return videos.sorted { $0.duration > $1.duration }
        }
    }

    var totalSelectedSize: Int64 { videos.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileSize } }
    var totalSize: Int64 { videos.reduce(0) { $0 + $1.fileSize } }

    func load() {
        isLoading = true
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self?.isLoading = false }; return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let opts = PHFetchOptions()
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let assets = PHAsset.fetchAssets(with: .video, options: opts)
                var items: [VideoItem] = []
                assets.enumerateObjects { asset, _, _ in
                    let res      = PHAssetResource.assetResources(for: asset)
                    let fileSize = res.first.flatMap { $0.value(forKey: "fileSize") as? Int64 } ?? 0
                    let filename = res.first?.originalFilename ?? "video.mp4"
                    items.append(VideoItem(id: asset.localIdentifier, asset: asset,
                                           filename: filename, fileSize: fileSize,
                                           duration: asset.duration, creationDate: asset.creationDate))
                }
                DispatchQueue.main.async {
                    self?.videos    = items.sorted { $0.fileSize > $1.fileSize }
                    self?.isLoading = false
                }
            }
        }
    }

    func toggleSelect(_ id: String) { if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) } }
    func selectAll()   { selectedIDs = Set(videos.map(\.id)) }
    func deselectAll() { selectedIDs = [] }

    func deleteSelected() {
        let assets = videos.filter { selectedIDs.contains($0.id) }.map(\.asset)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { [weak self] success, _ in
            guard success else { return }
            DispatchQueue.main.async {
                self?.videos.removeAll { self?.selectedIDs.contains($0.id) ?? false }
                self?.selectedIDs = []
                self?.toast("✅ Videos deleted!")
            }
        }
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - View
struct VideoCleanerView: View {
    @StateObject private var vm = VideoCleanerViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                if vm.isLoading {
                    ScanningView(text: "Loading videos…", progress: 0)
                } else if vm.videos.isEmpty {
                    EmptyStateView(icon: "video.slash.fill", title: "No Videos",
                                   subtitle: "No videos found in your library",
                                   buttonTitle: "Refresh") { vm.load() }
                } else {
                    videoBody
                }
                if let msg = vm.toastMessage {
                    VStack { Spacer(); ToastView(message: msg).padding(.bottom, 90) }
                        .animation(.spring(), value: vm.toastMessage)
                }
            }
            .navigationTitle("Videos")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(VideoCleanerViewModel.SortOption.allCases, id: \.self) { opt in
                            Button(opt.rawValue) { vm.sortBy = opt }
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !vm.selectedIDs.isEmpty {
                        Button(role: .destructive) { vm.showDeleteAlert = true } label: {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Delete \(vm.selectedIDs.count) Videos?", isPresented: $vm.showDeleteAlert) {
                Button("Delete", role: .destructive) { vm.deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Free \(formatBytes(vm.totalSelectedSize)). Cannot be undone.") }
            .onAppear { if vm.videos.isEmpty { vm.load() } }
        }
    }

    private var videoBody: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.videos.count) videos · \(formatBytes(vm.totalSize))")
                        .font(.subheadline).bold()
                    if !vm.selectedIDs.isEmpty {
                        Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(vm.selectedIDs.count == vm.videos.count ? "Deselect All" : "Select All") {
                        if vm.selectedIDs.count == vm.videos.count { vm.deselectAll() } else { vm.selectAll() }
                    }.font(.caption).foregroundColor(.purple)
                    if !vm.selectedIDs.isEmpty {
                        Button("Delete") { vm.showDeleteAlert = true }
                            .font(.caption).bold().foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            List {
                ForEach(vm.sorted) { item in
                    VideoItemRow(item: item, isSelected: vm.selectedIDs.contains(item.id)) {
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
}

// MARK: - Video Row
struct VideoItemRow: View {
    let item: VideoItem
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
                .frame(width: 80, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2))

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
                Circle().stroke(isSelected ? Color.red : Color.gray.opacity(0.4), lineWidth: 2)
                    .frame(width: 26, height: 26)
                if isSelected {
                    Circle().fill(Color.red).frame(width: 18, height: 18)
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.red.opacity(0.06) : Color(.secondarySystemBackground)))
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
