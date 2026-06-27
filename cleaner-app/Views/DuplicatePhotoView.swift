//  DuplicatePhotoView.swift

import SwiftUI
import Combine
import Photos
import CryptoKit

// MARK: - Models
struct PhotoItem: Identifiable {
    let id: String
    let asset: PHAsset
    let fileSize: Int64
    let creationDate: Date?
    let filename: String
}

struct PhotoGroup: Identifiable {
    let id = UUID()
    let type: GroupType
    var photos: [PhotoItem]
    var totalSize: Int64 { photos.reduce(0) { $0 + $1.fileSize } }
    enum GroupType { case duplicate, similar }
}

// MARK: - Horizontal Scroll Fix
private let kThumbW:    CGFloat = 110
private let kThumbH:    CGFloat = 140
private let kSpacing:   CGFloat = 8
private let kHPad:      CGFloat = 24
private let kVPad:      CGFloat = 20

func rowWidth(for count: Int) -> CGFloat {
    let n = max(count, 1)
    return CGFloat(n) * kThumbW + CGFloat(n - 1) * kSpacing + kHPad
}

class HScrollFixController<Content: View>: UIViewController {
    var hostingController: UIHostingController<Content>
    let scrollView    = UIScrollView()
    let contentWidth:  CGFloat
    let contentHeight: CGFloat

    init(content: Content, photoCount: Int, rowHeight: CGFloat) {
        self.hostingController = UIHostingController(rootView: content)
        self.contentWidth      = rowWidth(for: photoCount)
        self.contentHeight     = rowHeight
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.alwaysBounceHorizontal         = true
        scrollView.alwaysBounceVertical           = false
        scrollView.backgroundColor                = .clear
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor    .constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor .constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hostingController.view.autoresizingMask = []
        scrollView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

struct HScrollFix<Content: View>: UIViewControllerRepresentable {
    let height:     CGFloat
    let photoCount: Int
    let content:    Content

    init(height: CGFloat, photoCount: Int, @ViewBuilder content: () -> Content) {
        self.height     = height
        self.photoCount = photoCount
        self.content    = content()
    }

    func makeUIViewController(context: Context) -> HScrollFixController<Content> {
        HScrollFixController(content: content, photoCount: photoCount, rowHeight: height)
    }

    func updateUIViewController(_ vc: HScrollFixController<Content>, context: Context) {
        vc.hostingController.rootView = content
    }
}

// MARK: - Service
class DuplicatePhotoService {
    static let shared = DuplicatePhotoService()

    func fetchAllPhotos(completion: @escaping ([PhotoItem]) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion([]) }; return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let opts = PHFetchOptions()
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let assets = PHAsset.fetchAssets(with: .image, options: opts)
                var items: [PhotoItem] = []
                assets.enumerateObjects { asset, _, _ in
                    let res      = PHAssetResource.assetResources(for: asset)
                    let fileSize = res.first.flatMap { $0.value(forKey: "fileSize") as? Int64 } ?? 0
                    let filename = res.first?.originalFilename ?? "photo.jpg"
                    items.append(PhotoItem(
                        id: asset.localIdentifier, asset: asset,
                        fileSize: fileSize, creationDate: asset.creationDate, filename: filename
                    ))
                }
                DispatchQueue.main.async { completion(items) }
            }
        }
    }

    private func computeHash(_ asset: PHAsset, completion: @escaping (String?) -> Void) {
        let opts = PHImageRequestOptions()
        opts.isSynchronous          = false
        opts.deliveryMode           = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.version                = .current

        PHImageManager.default().requestImageDataAndOrientation(
            for: asset, options: opts
        ) { data, _, _, _ in
            guard let data else { completion(nil); return }
            let hash = SHA256.hash(data: data)
            completion(hash.compactMap { String(format: "%02x", $0) }.joined())
        }
    }

    func findDuplicates(
        photos: [PhotoItem],
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping ([PhotoGroup]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let total = photos.count
            var hashMap: [String: [PhotoItem]] = [:]
            let lock = NSLock(); let sem = DispatchSemaphore(value: 6); let grp = DispatchGroup()
            var done = 0

            for photo in photos {
                grp.enter(); sem.wait()
                self.computeHash(photo.asset) { hash in
                    defer { sem.signal(); grp.leave() }
                    guard let hash else { return }
                    lock.lock(); done += 1
                    hashMap[hash, default: []].append(photo)
                    let d = done; lock.unlock()
                    DispatchQueue.main.async { progress(d, total) }
                }
            }
            grp.notify(queue: .main) {
                let groups = hashMap.values
                    .filter { $0.count >= 2 }
                    .map { PhotoGroup(type: .duplicate, photos: $0.sorted { $0.fileSize > $1.fileSize }) }
                    .sorted { $0.totalSize > $1.totalSize }
                completion(groups)
            }
        }
    }

    func findSimilar(
        photos: [PhotoItem],
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping ([PhotoGroup]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let total = photos.count
            var fingerprints: [(PhotoItem, [UInt8])] = []
            let lock = NSLock()
            let sem  = DispatchSemaphore(value: 4)
            let grp  = DispatchGroup()
            var done = 0

            for photo in photos {
                grp.enter(); sem.wait()
                self.computeFingerprint(photo.asset) { fp in
                    defer { sem.signal(); grp.leave() }
                    lock.lock()
                    done += 1
                    if let fp { fingerprints.append((photo, fp)) }
                    let d = done; lock.unlock()
                    DispatchQueue.main.async { progress(d, total) }
                }
            }

            grp.notify(queue: .global()) {
                let groups = self.groupByFingerprint(fingerprints, maxDiff: 30)
                DispatchQueue.main.async { completion(groups) }
            }
        }
    }

    private func computeFingerprint(_ asset: PHAsset, completion: @escaping ([UInt8]?) -> Void) {
        let opts = PHImageRequestOptions()
        opts.isSynchronous          = false
        opts.deliveryMode           = .fastFormat
        opts.resizeMode             = .fast
        opts.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 8, height: 8),
            contentMode: .aspectFill,
            options: opts
        ) { image, _ in
            guard let cgImage = image?.cgImage else { completion(nil); return }
            let w = 8, h = 8
            var rgba = [UInt8](repeating: 0, count: w * h * 4)
            guard let ctx = CGContext(
                data: &rgba, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { completion(nil); return }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            var fp = [UInt8]()
            fp.reserveCapacity(w * h * 3)
            for i in 0..<(w * h) {
                fp.append(rgba[i*4])
                fp.append(rgba[i*4 + 1])
                fp.append(rgba[i*4 + 2])
            }
            completion(fp)
        }
    }

    private func groupByFingerprint(_ items: [(PhotoItem, [UInt8])], maxDiff: Int) -> [PhotoGroup] {
        var used   = Set<String>()
        var groups = [PhotoGroup]()
        let sorted = items.sorted { $0.0.fileSize > $1.0.fileSize }

        for i in 0..<sorted.count {
            let (base, baseFP) = sorted[i]
            if used.contains(base.id) { continue }
            var group: [PhotoItem] = [base]
            used.insert(base.id)

            for j in (i + 1)..<sorted.count {
                let (candidate, candFP) = sorted[j]
                if used.contains(candidate.id) { continue }
                guard baseFP.count == candFP.count else { continue }
                var totalDiff = 0
                for k in 0..<baseFP.count {
                    totalDiff += abs(Int(baseFP[k]) - Int(candFP[k]))
                }
                let avgDiff = totalDiff / baseFP.count
                if avgDiff <= maxDiff {
                    group.append(candidate)
                    used.insert(candidate.id)
                }
            }
            if group.count >= 2 {
                groups.append(PhotoGroup(
                    type: .similar,
                    photos: group.sorted { $0.fileSize > $1.fileSize }
                ))
            }
        }
        return groups.sorted { $0.totalSize > $1.totalSize }
    }

    func deleteAssets(_ assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { success, _ in DispatchQueue.main.async { completion(success) } }
    }
}

// MARK: - ViewModel
@MainActor
class DuplicatePhotoViewModel: ObservableObject {
    @Published var groups:         [PhotoGroup] = []
    @Published var isScanning      = false
    @Published var progress        = 0
    @Published var total           = 0
    @Published var selectedIDs     = Set<String>()
    @Published var showDeleteAlert = false
    @Published var scanMode: ScanMode = .duplicate
    @Published var toastMessage:   String?

    enum ScanMode: String, CaseIterable { case duplicate = "Duplicate"; case similar = "Similar" }

    var progressFraction: Double { total > 0 ? Double(progress) / Double(total) : 0 }
    var progressText: String { total > 0 ? "Scanning \(progress) / \(total)" : "Preparing…" }
    var totalSelectedSize: Int64 {
        groups.flatMap(\.photos).filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    func startScan() {
        isScanning = true; groups = []; selectedIDs = []
        DuplicatePhotoService.shared.fetchAllPhotos { [weak self] photos in
            guard let self else { return }
            self.total = photos.count
            let prog: (Int, Int) -> Void = { [weak self] c, t in self?.progress = c; self?.total = t }
            let done: ([PhotoGroup]) -> Void = { [weak self] result in
                self?.groups = result; self?.isScanning = false; self?.autoSelect()
            }
            if self.scanMode == .duplicate {
                DuplicatePhotoService.shared.findDuplicates(photos: photos, progress: prog, completion: done)
            } else {
                DuplicatePhotoService.shared.findSimilar(photos: photos, progress: prog, completion: done)
            }
        }
    }

    private func autoSelect() {
        for g in groups {
            g.photos.sorted(by: { $0.fileSize > $1.fileSize }).dropFirst().forEach { selectedIDs.insert($0.id) }
        }
    }

    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func selectAll()   { for g in groups { g.photos.dropFirst().forEach { selectedIDs.insert($0.id) } } }
    func deselectAll() { selectedIDs = [] }

    func deleteSelected() {
        let assets = groups.flatMap(\.photos).filter { selectedIDs.contains($0.id) }.map(\.asset)
        DuplicatePhotoService.shared.deleteAssets(assets) { [weak self] success in
            guard success, let self else { return }
            self.groups = self.groups.compactMap { g in
                let rem = g.photos.filter { !self.selectedIDs.contains($0.id) }
                return rem.count >= 2 ? PhotoGroup(type: g.type, photos: rem) : nil
            }
            self.selectedIDs = []
            self.toast("✅ Deleted \(assets.count) photos!")
        }
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - Main View
struct DuplicatePhotoView: View {
    @StateObject private var vm = DuplicatePhotoViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.isScanning {
                    ScanningView(text: vm.progressText, progress: vm.progressFraction)
                } else if vm.groups.isEmpty {
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: "No \(vm.scanMode.rawValue) Photos",
                        subtitle: "Tap Scan to find \(vm.scanMode.rawValue.lowercased()) photos",
                        buttonTitle: "Scan Now") { vm.startScan() }
                } else {
                    mainBody
                }

                if let msg = vm.toastMessage {
                    VStack { Spacer(); ToastView(message: msg).padding(.bottom, 90) }
                        .animation(.spring(), value: vm.toastMessage)
                }
            }
            .navigationTitle(vm.scanMode == .duplicate ? "Duplicate Photos" : "Similar Photos")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $vm.scanMode) {
                        ForEach(DuplicatePhotoViewModel.ScanMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
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

    private var mainBody: some View {
        VStack(spacing: 0) {
            // ── Summary bar ────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.groups.count) Groups").font(.subheadline).bold()
                    Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if !vm.selectedIDs.isEmpty {
                    Button { vm.showDeleteAlert = true } label: {
                        Text("Delete Selected").font(.subheadline).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color.red).clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.groups) { group in
                        DuplicateGroupCard(group: group, selectedIDs: $vm.selectedIDs) {
                            vm.toggleSelection($0)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Group Card  (FaceGroupCard-style layout)
struct DuplicateGroupCard: View {
    let group: PhotoGroup
    @Binding var selectedIDs: Set<String>
    let onToggle: (String) -> Void

    var representative: PhotoItem { group.photos[0] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Image(systemName: group.type == .duplicate ? "doc.on.doc.fill" : "photo.on.rectangle.angled")
                    .foregroundColor(.purple)
                Text("\(group.photos.count) \(group.type == .duplicate ? "duplicate" : "similar") photos")
                    .font(.subheadline).bold()
                Spacer()
                Text(formatBytes(group.totalSize))
                    .font(.caption).foregroundColor(.secondary)
            }

            // Horizontal photo strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.photos, id: \.asset.localIdentifier) { photo in
                        let isBest     = photo.asset.localIdentifier == representative.asset.localIdentifier
                        let isSelected = selectedIDs.contains(photo.asset.localIdentifier)

                        DuplicatePhotoCell(
                            asset:      photo.asset,
                            fileSize:   photo.fileSize,
                            isSelected: isSelected,
                            isBest:     isBest
                        ) { onToggle(photo.asset.localIdentifier) }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Photo Cell  (FacePhotoCell-style)
struct DuplicatePhotoCell: View {
    let asset:      PHAsset
    let fileSize:   Int64
    let isSelected: Bool
    let isBest:     Bool
    let onTap:      () -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            Group {
                if let img = image {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 110, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Border: red when selected, green when best, clear otherwise
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.red : isBest ? Color.green : Color.clear,
                        lineWidth: 3
                    )
            )
            // Tint overlay when selected
            .overlay(isSelected ? Color.red.opacity(0.15) : Color.clear)

            // Checkmark badge (top-right)
            ZStack {
                Circle()
                    .fill(isSelected ? Color.red : Color.white.opacity(0.8))
                    .frame(width: 24, height: 24)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption).bold().foregroundColor(.white)
                }
            }
            .padding(6)
        }
        // Bottom overlay: KEEP badge + file size
        .overlay(alignment: .bottom) {
            HStack {
                if isBest {
                    Text("KEEP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(formatBytes(fileSize))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(radius: 1)
            }
            .padding(.horizontal, 6).padding(.bottom, 6)
        }
        .onTapGesture { onTap() }
        .onAppear {
            let opts = PHImageRequestOptions()
            opts.deliveryMode  = .fastFormat
            opts.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 220, height: 280),
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in DispatchQueue.main.async { image = img } }
        }
    }
}
