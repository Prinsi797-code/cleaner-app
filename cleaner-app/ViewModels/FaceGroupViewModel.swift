//  FaceGroupViewModel.swift

import Foundation
import Combine
import Photos

@MainActor
class FaceGroupViewModel: ObservableObject {
    @Published var groups:         [FaceGroup] = []
    @Published var isScanning      = false
    @Published var progress        = 0
    @Published var total           = 0
    @Published var selectedIDs     = Set<String>()
    @Published var showDeleteAlert = false
    @Published var toastMessage:   String?

    var progressText: String { total > 0 ? "Scanning \(progress) / \(total)" : "Preparing…" }

    var totalSelectedSize: Int64 {
        groups.flatMap(\.photos)
            .filter { selectedIDs.contains($0.asset.localIdentifier) }
            .reduce(0) { $0 + $1.fileSize }
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true; groups = []; selectedIDs = []
        FaceDetectionService.shared.detectAllFaces(
            progress: { [weak self] c, t in self?.progress = c; self?.total = t },
            completion: { [weak self] result in
                self?.groups = result
                self?.isScanning = false
                self?.autoSelectDuplicates()
            }
        )
    }

    private func autoSelectDuplicates() {
        for g in groups {
            for photo in g.photos.sorted(by: { $0.fileSize > $1.fileSize }).dropFirst() {
                selectedIDs.insert(photo.asset.localIdentifier)
            }
        }
    }

    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func deleteSelected() {
        let assets = groups.flatMap(\.photos)
            .filter { selectedIDs.contains($0.asset.localIdentifier) }.map(\.asset)
        FaceDetectionService.shared.deleteAssets(assets) { [weak self] success in
            guard success, let self else { return }
            self.groups = self.groups.compactMap { g in
                let rem = g.photos.filter { !self.selectedIDs.contains($0.asset.localIdentifier) }
                return rem.count >= 2 ? FaceGroup(photos: rem) : nil
            }
            self.selectedIDs = []
            self.toast("✅ Deleted successfully!")
        }
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}
