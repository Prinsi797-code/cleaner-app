//
//  VideoScanManager.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import Foundation
import Photos

class VideoScanManager {
    
    static let shared = VideoScanManager()
    
    private init() {}
    
    // Cached lists
    var allVideos: [PHAsset] = []
    var largeVideos: [PHAsset] = []
    var oldVideos: [PHAsset] = []
    
    // File sizes mapping: key is asset localIdentifier, value is bytes count
    var videoSizes: [String: Int64] = [:]
    
    // MARK: - Persistence
    
    func saveToDisk() {
        let defaults = UserDefaults.standard
        defaults.set(allVideos.map { $0.localIdentifier }, forKey: "VideoScanManager_allVideos")
        defaults.set(largeVideos.map { $0.localIdentifier }, forKey: "VideoScanManager_largeVideos")
        defaults.set(oldVideos.map { $0.localIdentifier }, forKey: "VideoScanManager_oldVideos")
        defaults.set(videoSizes, forKey: "VideoScanManager_videoSizes")
        defaults.set(true, forKey: "VideoScanManager_hasCachedData")
    }
    
    func loadFromDisk() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "VideoScanManager_hasCachedData") else { return false }
        
        func fetchAssets(for identifiers: [String]) -> [PHAsset] {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var assets = [PHAsset]()
            fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
            let assetDict = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })
            return identifiers.compactMap { assetDict[$0] }
        }
        
        if let allIDs = defaults.stringArray(forKey: "VideoScanManager_allVideos") {
            self.allVideos = fetchAssets(for: allIDs)
        }
        
        if let largeIDs = defaults.stringArray(forKey: "VideoScanManager_largeVideos") {
            self.largeVideos = fetchAssets(for: largeIDs)
        }
        
        if let oldIDs = defaults.stringArray(forKey: "VideoScanManager_oldVideos") {
            self.oldVideos = fetchAssets(for: oldIDs)
        }
        
        if let sizes = defaults.dictionary(forKey: "VideoScanManager_videoSizes") as? [String: NSNumber] {
            var newSizes: [String: Int64] = [:]
            for (k, v) in sizes {
                newSizes[k] = v.int64Value
            }
            self.videoSizes = newSizes
        }
        
        return true
    }
    
    func scanVideoLibrary(progressHandler: @escaping (String, Double) -> Void, completion: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            completion()
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            progressHandler("Scanning videos list...", 0.2)
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
            
            var tempAll: [PHAsset] = []
            var tempLarge: [PHAsset] = []
            var tempOld: [PHAsset] = []
            
            let totalCount = fetchResult.count
            
            fetchResult.enumerateObjects { [weak self] asset, index, _ in
                guard let self = self else { return }
                tempAll.append(asset)
                
                // Let's query video size in bytes
                let size = self.getFileSize(for: asset)
                self.videoSizes[asset.localIdentifier] = size
                
                // Update log progress slightly
                if index % 10 == 0 && totalCount > 0 {
                    let ratio = Double(index) / Double(totalCount)
                    progressHandler("Evaluating video sizes...", 0.2 + (ratio * 0.6))
                }
                
                // Large videos threshold: 100 MB
                if size > 100 * 1024 * 1024 {
                    tempLarge.append(asset)
                }
                
                // Old videos: created > 6 months ago (approx 180 days)
                if let date = asset.creationDate {
                    let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                    if date < sixMonthsAgo {
                        tempOld.append(asset)
                    }
                }
            }
            
            self.allVideos = tempAll
            self.largeVideos = tempLarge
            self.oldVideos = tempOld
            
            progressHandler("Finalizing video metrics...", 0.95)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func getFileSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        if let first = resources.first {
            if let fileSizeVal = first.value(forKey: "fileSize") as? Int64 {
                return fileSizeVal
            }
        }
        return 0
    }
}
