//  BlurryPhotoView.swift
//  Detects blurry photos using Laplacian variance (lower = more blurry)

import SwiftUI
import Combine
import Photos
import Accelerate

// MARK: - Model
struct BlurryPhotoItem: Identifiable {
    let id: String
    let asset: PHAsset
    let fileSize: Int64
    let creationDate: Date?
    let filename: String
    let blurScore: Float      // lower = more blurry
    var blurLabel: BlurLevel

    enum BlurLevel {
        case veryBlurry
        var label: String { "Very Blurry" }
        var color: Color  { Color(hexString: "#E53935") }
    }
}

// MARK: - Service
class BlurDetectionService {
    static let shared = BlurDetectionService()

    func detectBlurryPhotos(
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping ([BlurryPhotoItem]) -> Void
    ) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion([]) }; return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let opts = PHFetchOptions()
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let assets = PHAsset.fetchAssets(with: .image, options: opts)
                let total  = assets.count
                var results: [BlurryPhotoItem] = []
                let lock   = NSLock()
                let sem    = DispatchSemaphore(value: 6)
                let grp    = DispatchGroup()
                var done   = 0

                assets.enumerateObjects { asset, _, _ in
                    grp.enter(); sem.wait()
                    self.blurScore(for: asset) { score in
                        defer { sem.signal(); grp.leave() }
                        lock.lock()
                        done += 1
                        let d = done
                        if let score, score < 30 {    // threshold — below 30 = very blurry only
                            let res      = PHAssetResource.assetResources(for: asset)
                            let fileSize = res.first.flatMap { $0.value(forKey: "fileSize") as? Int64 } ?? 0
                            let filename = res.first?.originalFilename ?? "photo.jpg"
                            let level: BlurryPhotoItem.BlurLevel = .veryBlurry
                            results.append(BlurryPhotoItem(
                                id: asset.localIdentifier, asset: asset,
                                fileSize: fileSize, creationDate: asset.creationDate,
                                filename: filename, blurScore: score, blurLabel: level
                            ))
                        }
                        lock.unlock()
                        DispatchQueue.main.async { progress(d, total) }
                    }
                }

                grp.notify(queue: .main) {
                    // Sort: most blurry first
                    completion(results.sorted { $0.blurScore < $1.blurScore })
                }
            }
        }
    }

    // ── Laplacian variance — lower = more blurry ────────────────────────────
    private func blurScore(for asset: PHAsset, completion: @escaping (Float?) -> Void) {
        let opts = PHImageRequestOptions()
        opts.isSynchronous        = false
        opts.deliveryMode         = .fastFormat
        opts.resizeMode           = .fast
        opts.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 256, height: 256),
            contentMode: .aspectFit,
            options: opts
        ) { image, _ in
            guard let cgImage = image?.cgImage else { completion(nil); return }
            completion(self.laplacianVariance(cgImage))
        }
    }

    private func laplacianVariance(_ cgImage: CGImage) -> Float {
        let width  = 256
        let height = 256
        var gray   = [UInt8](repeating: 0, count: width * height)

        // Convert to grayscale
        guard let ctx = CGContext(
            data: &gray, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Laplacian kernel: [0,1,0,1,-4,1,0,1,0]
        var laplacian = [Float](repeating: 0, count: width * height)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Float(gray[y * width + x])
                let top    = Float(gray[(y-1) * width + x])
                let bottom = Float(gray[(y+1) * width + x])
                let left   = Float(gray[y * width + (x-1)])
                let right  = Float(gray[y * width + (x+1)])
                laplacian[y * width + x] = abs(top + bottom + left + right - 4 * center)
            }
        }

        // Variance of laplacian
        var mean: Float = 0
        vDSP_meanv(laplacian, 1, &mean, vDSP_Length(laplacian.count))
        var variance: Float = 0
        var meanArr = [Float](repeating: mean, count: laplacian.count)
        var diff    = [Float](repeating: 0, count: laplacian.count)
        vDSP_vsub(meanArr, 1, laplacian, 1, &diff, 1, vDSP_Length(laplacian.count))
        vDSP_dotpr(diff, 1, diff, 1, &variance, vDSP_Length(diff.count))
        return variance / Float(laplacian.count)
    }

    func deleteAssets(_ assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { success, _ in DispatchQueue.main.async { completion(success) } }
    }
}

// MARK: - ViewModel
@MainActor
class BlurryPhotoViewModel: ObservableObject {
    @Published var photos:         [BlurryPhotoItem] = []
    @Published var isScanning      = false
    @Published var progress        = 0
    @Published var total           = 0
    @Published var selectedIDs     = Set<String>()
    @Published var showDeleteAlert = false
    @Published var toastMessage:   String?

    var filtered: [BlurryPhotoItem] { photos }

    var progressFraction: Double { total > 0 ? Double(progress) / Double(total) : 0 }
    var progressText: String { total > 0 ? "Analyzing \(progress) / \(total)" : "Preparing…" }

    var totalSelectedSize: Int64 {
        photos.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    func startScan() {
        isScanning = true; photos = []; selectedIDs = []
        BlurDetectionService.shared.detectBlurryPhotos(
            progress: { [weak self] c, t in self?.progress = c; self?.total = t },
            completion: { [weak self] result in
                self?.photos     = result
                self?.isScanning = false
                // Auto-select all very blurry
                result.filter { $0.blurLabel == .veryBlurry }
                    .forEach { self?.selectedIDs.insert($0.id) }
            }
        )
    }

    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func selectAll()   { photos.forEach { selectedIDs.insert($0.id) } }
    func deselectAll() { photos.forEach { selectedIDs.remove($0.id) } }

    func deleteSelected() {
        let assets = photos.filter { selectedIDs.contains($0.id) }.map(\.asset)
        BlurDetectionService.shared.deleteAssets(assets) { [weak self] success in
            guard success, let self else { return }
            let count = assets.count
            self.photos.removeAll { self.selectedIDs.contains($0.id) }
            self.selectedIDs = []
            self.toast("✅ Deleted \(count) blurry photos!")
        }
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - View
struct BlurryPhotoView: View {
    @StateObject private var vm = BlurryPhotoViewModel()

    let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.isScanning {
                    scanningBody
                } else if vm.photos.isEmpty {
                    EmptyStateView(
                        icon: "camera.filters",
                        title: "No Blurry Photos",
                        subtitle: "Tap Scan to analyze your photo library",
                        buttonTitle: "Scan Now"
                    ) { vm.startScan() }
                } else {
                    mainBody
                }

                if let msg = vm.toastMessage {
                    VStack { Spacer(); ToastView(message: msg).padding(.bottom, 90) }
                        .animation(.spring(), value: vm.toastMessage)
                }
            }
            .navigationTitle("Blurry Photos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Scan") { vm.startScan() }
                        .font(.subheadline).bold()
                }
            }
            .alert("Delete \(vm.selectedIDs.count) Photos?", isPresented: $vm.showDeleteAlert) {
                Button("Delete", role: .destructive) { vm.deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Free \(formatBytes(vm.totalSelectedSize)). Cannot be undone.")
            }
        }
    }

    // MARK: - Scanning View (custom with tip)
    private var scanningBody: some View {
        VStack(spacing: 28) {
            ScanningView(text: vm.progressText, progress: vm.progressFraction)

            Text("Analyzing sharpness of each photo\nusing Laplacian edge detection")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Main body
    private var mainBody: some View {
        VStack(spacing: 0) {

            // ── Action bar ─────────────────────────────────────────────────
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.photos.count) very blurry photos found")
                        .font(.subheadline).bold()
                    if !vm.selectedIDs.isEmpty {
                        Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                Spacer()
                Button(vm.selectedIDs.count == vm.photos.count ? "Deselect All" : "Select All") {
                    if vm.selectedIDs.count == vm.photos.count { vm.deselectAll() }
                    else { vm.selectAll() }
                }
                .font(.caption).foregroundColor(.purple)

                if !vm.selectedIDs.isEmpty {
                    Button("Delete") { vm.showDeleteAlert = true }
                        .font(.caption).bold().foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.red).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            // ── Photo grid ─────────────────────────────────────────────────
            ScrollView {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(vm.filtered) { item in
                        BlurryPhotoCell(
                            item: item,
                            isSelected: vm.selectedIDs.contains(item.id)
                        ) { vm.toggleSelection(item.id) }
                    }
                }
                .padding(3)
            }
        }
    }
}

// MARK: - Blurry Photo Cell
struct BlurryPhotoCell: View {
    let item: BlurryPhotoItem
    let isSelected: Bool
    let onTap: () -> Void
    @State private var image: UIImage?

    var cellSize: CGFloat { (UIScreen.main.bounds.width - 12) / 3 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo
            Group {
                if let img = image {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .frame(width: cellSize, height: cellSize)
            .clipped()
            .blur(radius: isSelected ? 0 : 0)   // keep actual blur visible
            .overlay(isSelected ? Color.blue.opacity(0.25) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )

            // Checkmark
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.75))
                    .frame(width: 22, height: 22)
                    .shadow(radius: 1)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(5)
        }
        .overlay(alignment: .bottomLeading) {
            // Blur level badge
            Text(item.blurLabel.label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(item.blurLabel.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(4)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(formatBytes(item.fileSize))
                .font(.system(size: 8))
                .foregroundColor(.white)
                .padding(.horizontal, 4).padding(.vertical, 3)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(4)
        }
        .onTapGesture { onTap() }
        .onAppear {
            guard image == nil else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            opts.isSynchronous = false
            PHImageManager.default().requestImage(
                for: item.asset,
                targetSize: CGSize(width: cellSize * 2, height: cellSize * 2),
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in DispatchQueue.main.async { if let img { self.image = img } } }
        }
    }
}
