//  DuplicateVideoView.swift
//  cleaner-app

import SwiftUI
import Combine
import Photos
import CryptoKit

// MARK: - Model
struct VideoGroupItem: Identifiable {
    let id = UUID()
    let type: GroupType
    var videos: [VideoItem]
    var totalSize: Int64 { videos.reduce(0) { $0 + $1.fileSize } }

    enum GroupType {
        case duplicate
        case similar
    }
}

// MARK: - Service
class DuplicateVideoService {
    static let shared = DuplicateVideoService()

    func findDuplicateVideos(
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping ([VideoGroupItem]) -> Void
    ) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion([]) }; return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let opts = PHFetchOptions()
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let assets = PHAsset.fetchAssets(with: .video, options: opts)
                var videos: [VideoItem] = []
                assets.enumerateObjects { asset, _, _ in
                    let res      = PHAssetResource.assetResources(for: asset)
                    let fileSize = res.first.flatMap { $0.value(forKey: "fileSize") as? Int64 } ?? 0
                    let filename = res.first?.originalFilename ?? "video.mp4"
                    videos.append(VideoItem(id: asset.localIdentifier, asset: asset,
                                            filename: filename, fileSize: fileSize,
                                            duration: asset.duration, creationDate: asset.creationDate))
                }

                let total = videos.count
                var hashMap: [String: [VideoItem]] = [:]
                let lock = NSLock()
                let sem  = DispatchSemaphore(value: 3)
                let grp  = DispatchGroup()
                var done = 0

                for video in videos {
                    grp.enter(); sem.wait()
                    self.quickHash(video.asset) { hash in
                        defer { sem.signal(); grp.leave() }
                        lock.lock()
                        done += 1
                        let key = hash ?? "dur_\(Int(video.duration))_\(video.fileSize)"
                        hashMap[key, default: []].append(video)
                        let d = done
                        lock.unlock()
                        DispatchQueue.main.async { progress(d, total) }
                    }
                }

                grp.notify(queue: .main) {
                    var groups: [VideoGroupItem] = hashMap.values
                        .filter { $0.count >= 2 }
                        .map { VideoGroupItem(type: .duplicate, videos: $0.sorted { $0.fileSize > $1.fileSize }) }

                    let usedIDs = Set(groups.flatMap { $0.videos.map(\.id) })
                    let remaining = videos.filter { !usedIDs.contains($0.id) }
                    groups += self.findSimilarVideos(remaining)

                    completion(groups.sorted { $0.totalSize > $1.totalSize })
                }
            }
        }
    }

    private func findSimilarVideos(_ videos: [VideoItem]) -> [VideoGroupItem] {
        var used   = Set<String>()
        var groups = [VideoGroupItem]()
        let sorted = videos.sorted { $0.fileSize > $1.fileSize }

        for base in sorted {
            if used.contains(base.id) { continue }
            var group = [base]; used.insert(base.id)
            for candidate in sorted {
                if used.contains(candidate.id) { continue }
                let durDiff   = abs(base.duration - candidate.duration)
                let sizeDiff  = abs(base.fileSize - candidate.fileSize)
                let sizeRatio = base.fileSize > 0 ? Double(sizeDiff) / Double(base.fileSize) : 1
                if durDiff <= 2.0 && sizeRatio <= 0.30 {
                    group.append(candidate); used.insert(candidate.id)
                }
            }
            if group.count >= 2 {
                groups.append(VideoGroupItem(type: .similar, videos: group))
            }
        }
        return groups
    }

    private func quickHash(_ asset: PHAsset, completion: @escaping (String?) -> Void) {
        let res = PHAssetResource.assetResources(for: asset)
        guard let resource = res.first else { completion(nil); return }
        var data = Data()
        let opts  = PHAssetResourceRequestOptions()
        opts.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().requestData(
            for: resource, options: opts,
            dataReceivedHandler: { chunk in if data.count < 524_288 { data.append(chunk) } },
            completionHandler: { error in
                guard error == nil, !data.isEmpty else { completion(nil); return }
                let hash = SHA256.hash(data: data)
                completion(hash.compactMap { String(format: "%02x", $0) }.joined())
            }
        )
    }

    func deleteAssets(_ assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { success, _ in DispatchQueue.main.async { completion(success) } }
    }
}

// MARK: - ViewModel
@MainActor
class DuplicateVideoViewModel: ObservableObject {
    @Published var groups:         [VideoGroupItem] = []
    @Published var isScanning      = false
    @Published var progress        = 0
    @Published var total           = 0
    @Published var selectedIDs     = Set<String>()
    @Published var showDeleteAlert = false
    @Published var toastMessage:   String?

    var progressText: String { total > 0 ? "Scanning \(progress) / \(total)" : "Preparing…" }
    var totalSelectedSize: Int64 {
        groups.flatMap(\.videos).filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    func startScan() {
        isScanning = true; groups = []; selectedIDs = []
        DuplicateVideoService.shared.findDuplicateVideos(
            progress: { [weak self] c, t in self?.progress = c; self?.total = t },
            completion: { [weak self] result in
                self?.groups     = result
                self?.isScanning = false
                self?.autoSelect()
            }
        )
    }

    private func autoSelect() {
        for g in groups {
            for video in g.videos.sorted(by: { $0.fileSize > $1.fileSize }).dropFirst() {
                selectedIDs.insert(video.id)
            }
        }
    }

    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func deleteSelected() {
        let assets = groups.flatMap(\.videos)
            .filter { selectedIDs.contains($0.id) }.map(\.asset)
        DuplicateVideoService.shared.deleteAssets(assets) { [weak self] success in
            guard success, let self else { return }
            self.groups = self.groups.compactMap { g in
                let rem = g.videos.filter { !self.selectedIDs.contains($0.id) }
                return rem.count >= 2 ? VideoGroupItem(type: g.type, videos: rem) : nil
            }
            self.selectedIDs = []
            self.toast("✅ Deleted \(assets.count) videos!")
        }
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - View
// NavigationView HATA DIYA — MoreView ka NavigationView use hoga
struct DuplicateVideoView: View {
    @StateObject private var vm = DuplicateVideoViewModel()

    var body: some View {
        ZStack {
            if vm.isScanning {
                ScanningView(text: vm.progressText,
                             progress: vm.total > 0 ? Double(vm.progress) / Double(vm.total) : 0)
            } else if vm.groups.isEmpty {
                EmptyStateView(icon: "video.badge.checkmark", title: "No Duplicate Videos",
                               subtitle: "Tap Scan to find duplicate or similar videos",
                               buttonTitle: "Scan Now") { vm.startScan() }
            } else {
                mainBody
            }
            if let msg = vm.toastMessage {
                VStack { Spacer(); ToastView(message: msg).padding(.bottom, 20) }
                    .animation(.spring(), value: vm.toastMessage)
            }
        }
        .navigationTitle("Dup Videos")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !vm.groups.isEmpty {
                    Button("Rescan") { vm.startScan() }
                        .padding(.leading, 16)
                }
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
//        .toolbar(.hidden, for: .tabBar)
    }

    private var mainBody: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.groups.count) groups · \(vm.groups.flatMap(\.videos).count) videos")
                        .font(.subheadline).bold()
                    Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if !vm.selectedIDs.isEmpty {
                    Button("Delete") { vm.showDeleteAlert = true }
                        .font(.caption).bold().foregroundColor(.red)
                }
            }
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            // ✅ Native Ad
            SmartNativeAdView(screen: .dupVideo)

            List {
                ForEach(vm.groups) { group in
                    VideoGroupCard(group: group, selectedIDs: $vm.selectedIDs) {
                        vm.toggleSelection($0)
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

// MARK: - Video Group Card
struct VideoGroupCard: View {
    let group: VideoGroupItem
    @Binding var selectedIDs: Set<String>
    let onToggle: (String) -> Void

    var badgeColor: Color { group.type == .duplicate ? .red : .orange }
    var badgeText: String { group.type == .duplicate ? "EXACT" : "SIMILAR" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(badgeText)
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(badgeColor).clipShape(Capsule())
                Text("\(group.videos.count) videos").font(.subheadline).bold()
                Spacer()
                Text(formatBytes(group.totalSize)).font(.caption).foregroundColor(.secondary)
            }
            ForEach(group.videos) { video in
                DupVideoRow(
                    video: video,
                    isSelected: selectedIDs.contains(video.id),
                    isBest: video.id == group.videos.first?.id
                ) { onToggle(video.id) }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct DupVideoRow: View {
    let video: VideoItem
    let isSelected: Bool
    let isBest: Bool
    let onTap: () -> Void
    @State private var thumb: UIImage?

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = thumb { Image(uiImage: img).resizable().scaledToFill() }
                    else { Color.gray.opacity(0.3) }
                }
                .frame(width: 70, height: 52).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2))
                Text(formatDuration(video.duration))
                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 3)).padding(3)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if isBest {
                        Text("KEEP").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.green).clipShape(Capsule())
                    }
                    Text(video.filename).font(.caption).lineLimit(1)
                }
                Text(formatBytes(video.fileSize)).font(.caption).bold().foregroundColor(.orange)
            }
            Spacer()
            ZStack {
                Circle().stroke(isSelected ? Color.red : Color.gray.opacity(0.4), lineWidth: 2)
                    .frame(width: 24, height: 24)
                if isSelected {
                    Circle().fill(Color.red).frame(width: 16, height: 16)
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.red.opacity(0.06) : Color(.tertiarySystemBackground)))
        .onTapGesture { onTap() }
        .onAppear {
            guard thumb == nil else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat; opts.isSynchronous = false
            PHImageManager.default().requestImage(
                for: video.asset, targetSize: CGSize(width: 140, height: 104),
                contentMode: .aspectFill, options: opts
            ) { img, _ in DispatchQueue.main.async { thumb = img } }
        }
    }
}
