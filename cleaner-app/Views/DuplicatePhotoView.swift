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
// Width is calculated deterministically from photoCount — no layout measurement,
// no Auto Layout ambiguity. contentSize is set once in viewDidLoad and is exact.

private let kThumbW:    CGFloat = 160
private let kThumbH:    CGFloat = 160
private let kSpacing:   CGFloat = 8
private let kHPad:      CGFloat = 24   // 12 leading + 12 trailing from .padding(.horizontal, 12)
private let kVPad:      CGFloat = 20   // 10 top + 10 bottom from .padding(.vertical, 10)

/// Exact row width for N photos — must match HStack layout values above
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

        // ✅ Set contentSize immediately — exact, no measurement pass needed
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
        // ✅ Frame-based: set exact frame so SwiftUI content has full width to lay out
        hostingController.view.frame = CGRect(x: 0, y: 0,
                                              width: contentWidth,
                                              height: contentHeight)
        hostingController.view.autoresizingMask = []
        scrollView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

struct HScrollFix<Content: View>: UIViewControllerRepresentable {
    let height:     CGFloat
    let photoCount: Int        // ← number of photos in the row
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
            for: asset,
            options: opts
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("", selection: $vm.scanMode) {
                        ForEach(DuplicatePhotoViewModel.ScanMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.groups.count) groups · \(vm.groups.flatMap(\.photos).count) photos")
                        .font(.subheadline).bold()
                    Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button("Select All")    { vm.selectAll() }
                    .font(.caption).foregroundColor(.purple)
                Button("Deselect All")  { vm.deselectAll() }
                    .font(.caption).foregroundColor(.gray)
                if !vm.selectedIDs.isEmpty {
                    Button("Delete") { vm.showDeleteAlert = true }
                        .font(.caption).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.red).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(vm.groups) { group in
                        PhotoGroupCard(group: group, selectedIDs: $vm.selectedIDs) {
                            vm.toggleSelection($0)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Photo Group Card
struct PhotoGroupCard: View {
    let group: PhotoGroup
    @Binding var selectedIDs: Set<String>
    let onToggle: (String) -> Void

    var best: PhotoItem    { group.photos[0] }
    var rest: [PhotoItem]  { Array(group.photos.dropFirst()) }
    var groupLabel: String { "\(group.photos.count) \(group.type == .duplicate ? "Duplicate" : "Similar")" }
    var cardWidth: CGFloat { UIScreen.main.bounds.width - 28 }

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text(groupLabel)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button("Deselect All") {
                    group.photos.forEach { selectedIDs.remove($0.id) }
                }
                .font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            ZStack(alignment: .topLeading) {
                PhotoThumb(asset: best.asset, width: cardWidth, height: 210)
                    .overlay(selectedIDs.contains(best.id) ? Color.red.opacity(0.18) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedIDs.contains(best.id) ? Color.red : Color.clear, lineWidth: 3)
                    )

                Button {
                    rest.forEach { selectedIDs.insert($0.id) }
                    selectedIDs.remove(best.id)
                } label: {
                    Text("Keep All")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(hexString: "#4CAF50"))
                        .clipShape(Capsule())
                }
                .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Text("Best Result")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(hexString: "#4CAF50"))
                    Text(formatBytes(best.fileSize))
                        .font(.system(size: 9)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.black.opacity(0.6))
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
            }
            .overlay(alignment: .bottomTrailing) {
                SelectCheckmark(isSelected: selectedIDs.contains(best.id)) { onToggle(best.id) }
                    .padding(8)
            }

            // ── Horizontal row ─────────────────────────────────────────────
            if !rest.isEmpty {
                // ✅ kThumbH + kVPad = row height matches padding(.vertical, 10) on HStack
                let rowH = kThumbH + kVPad

                HScrollFix(height: rowH, photoCount: rest.count) {
                    HStack(spacing: kSpacing) {          // ← kSpacing = 8
                        ForEach(rest) { photo in
                            let isSelected = selectedIDs.contains(photo.id)
                            ZStack(alignment: .topTrailing) {
                                PhotoThumb(asset: photo.asset, width: kThumbW, height: kThumbH)
                                    .overlay(isSelected ? Color(hexString: "#E91E63").opacity(0.15) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                isSelected ? Color(hexString: "#E91E63") : Color.gray.opacity(0.3),
                                                lineWidth: isSelected ? 3 : 1
                                            )
                                    )

                                SelectCheckmark(isSelected: isSelected) { onToggle(photo.id) }
                                    .padding(6)
                            }
                            .overlay(alignment: .bottomLeading) {
                                Text(formatBytes(photo.fileSize))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.black.opacity(0.65))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(6)
                            }
                            .onTapGesture { onToggle(photo.id) }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)  // ← kHPad/2 each side, kVPad/2 each side
                }
                .frame(height: rowH)
                .background(Color(.tertiarySystemBackground))
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Select Checkmark
struct SelectCheckmark: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.white.opacity(0.8))
                .frame(width: 26, height: 26)
                .shadow(radius: 1)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - Photo Thumbnail
struct PhotoThumb: View {
    let asset: PHAsset
    let width: CGFloat
    let height: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(ProgressView().scaleEffect(0.7))
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            guard image == nil else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: width * 2, height: height * 2),
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in
                DispatchQueue.main.async { if let img { self.image = img } }
            }
        }
    }
}
