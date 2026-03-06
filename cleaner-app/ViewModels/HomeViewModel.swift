//
//  HomeViewModel.swift
//  cleaner-app
//
//  Created by Hevin Technoweb on 05/03/26.
//

//  HomeViewModel.swift

import Foundation
import Combine
import Photos
import Contacts

@MainActor
class HomeViewModel: ObservableObject {
    @Published var usedGB: Double  = 0
    @Published var totalGB: Double = 0
    @Published var photoCount   = "—"
    @Published var videoCount   = "—"
    @Published var contactCount = "—"
    @Published var appCount     = "—"

    func load() {
        loadStorage()
        loadMediaCount()
        loadContactCount()
    }

    private func loadStorage() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) else { return }
        let total = attrs[.systemSize]     as? Int64 ?? 0
        let free  = attrs[.systemFreeSize] as? Int64 ?? 0
        totalGB = Double(total) / 1_073_741_824
        usedGB  = Double(total - free) / 1_073_741_824
    }

    private func loadMediaCount() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard status == .authorized || status == .limited else { return }
            DispatchQueue.main.async {
                self?.photoCount = "\(PHAsset.fetchAssets(with: .image, options: nil).count)"
                self?.videoCount = "\(PHAsset.fetchAssets(with: .video, options: nil).count)"
            }
        }
    }

    private func loadContactCount() {
        DispatchQueue.global().async { [weak self] in
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, _ in
                guard granted else { return }
                var count = 0
                let req = CNContactFetchRequest(keysToFetch: [CNContactGivenNameKey] as [CNKeyDescriptor])
                try? store.enumerateContacts(with: req) { _, _ in count += 1 }
                DispatchQueue.main.async {
                    self?.contactCount = "\(count)"
                    self?.appCount     = "\(Bundle.allBundles.count)"
                }
            }
        }
    }
}
