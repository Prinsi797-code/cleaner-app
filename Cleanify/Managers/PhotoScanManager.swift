//
//  PhotoScanManager.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import Foundation
import Photos
import Vision
import UIKit

struct PhotoGroup {
    let leadingAsset: PHAsset
    var assets: [PHAsset]
}

class PhotoScanManager {
    
    static let shared = PhotoScanManager()
    
    private init() {}
    
    
    var allPhotos: [PHAsset] = []
    var screenshots: [PHAsset] = []
    var livePhotos: [PHAsset] = []
    var burstPhotos: [PHAsset] = []
    var blurryPhotos: [PHAsset] = []
    
    var duplicateGroups: [PhotoGroup] = []
    var similarGroups: [PhotoGroup] = []
    
    // MARK: - Update Cache
    
    func removeAssets(withIds ids: Set<String>) {
        var allIdsToRemove = ids
        
        // If a representative burst asset is deleted, iOS deletes the entire burst sequence.
        // We need to identify any burst sequences being deleted and remove all their child assets.
        let deletedBursts = allPhotos.filter { ids.contains($0.localIdentifier) && $0.representsBurst }
        let burstIdentifiers = Set(deletedBursts.compactMap { $0.burstIdentifier })
        
        if !burstIdentifiers.isEmpty {
            for burstAsset in burstPhotos {
                if let bId = burstAsset.burstIdentifier, burstIdentifiers.contains(bId) {
                    allIdsToRemove.insert(burstAsset.localIdentifier)
                }
            }
        }
        
        allPhotos.removeAll { allIdsToRemove.contains($0.localIdentifier) }
        screenshots.removeAll { allIdsToRemove.contains($0.localIdentifier) }
        livePhotos.removeAll { allIdsToRemove.contains($0.localIdentifier) }
        burstPhotos.removeAll { allIdsToRemove.contains($0.localIdentifier) }
        blurryPhotos.removeAll { allIdsToRemove.contains($0.localIdentifier) }
        
        duplicateGroups = duplicateGroups.compactMap { group in
            var updatedGroup = group
            updatedGroup.assets.removeAll { allIdsToRemove.contains($0.localIdentifier) }
            return updatedGroup.assets.isEmpty ? nil : updatedGroup
        }
        
        similarGroups = similarGroups.compactMap { group in
            var updatedGroup = group
            updatedGroup.assets.removeAll { allIdsToRemove.contains($0.localIdentifier) }
            return updatedGroup.assets.isEmpty ? nil : updatedGroup
        }
        
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    func saveToDisk() {
        let defaults = UserDefaults.standard
        let duplicateDicts = duplicateGroups.map { group -> [String: Any] in
            return [
                "leading": group.leadingAsset.localIdentifier,
                "assets": group.assets.map { $0.localIdentifier }
            ]
        }
        defaults.set(duplicateDicts, forKey: "PhotoScanManager_duplicateGroups")
        
        let similarDicts = similarGroups.map { group -> [String: Any] in
            return [
                "leading": group.leadingAsset.localIdentifier,
                "assets": group.assets.map { $0.localIdentifier }
            ]
        }
        defaults.set(similarDicts, forKey: "PhotoScanManager_similarGroups")
        
        defaults.set(screenshots.map { $0.localIdentifier }, forKey: "PhotoScanManager_screenshots")
        defaults.set(livePhotos.map { $0.localIdentifier }, forKey: "PhotoScanManager_livePhotos")
        defaults.set(burstPhotos.map { $0.localIdentifier }, forKey: "PhotoScanManager_burstPhotos")
        defaults.set(blurryPhotos.map { $0.localIdentifier }, forKey: "PhotoScanManager_blurryPhotos")
        defaults.set(allPhotos.map { $0.localIdentifier }, forKey: "PhotoScanManager_allPhotos")
        
        defaults.set(true, forKey: "PhotoScanManager_hasCachedData")
    }
    
    func loadFromDisk() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "PhotoScanManager_hasCachedData") else { return false }
        
        func fetchAssets(for identifiers: [String]) -> [PHAsset] {
            let options = PHFetchOptions()
            options.includeAllBurstAssets = true
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)
            var assets = [PHAsset]()
            fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
            let assetDict = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })
            return identifiers.compactMap { assetDict[$0] }
        }
        
        func fetchGroups(for nestedDicts: [[String: Any]]) -> [PhotoGroup] {
            var groups = [PhotoGroup]()
            for dict in nestedDicts {
                guard let leadingID = dict["leading"] as? String,
                      let assetIDs = dict["assets"] as? [String] else { continue }
                
                let leadingAssets = fetchAssets(for: [leadingID])
                let duplicateAssets = fetchAssets(for: assetIDs)
                
                if let leading = leadingAssets.first, !duplicateAssets.isEmpty {
                    groups.append(PhotoGroup(leadingAsset: leading, assets: duplicateAssets))
                }
            }
            return groups
        }
        
        if let dupDicts = defaults.array(forKey: "PhotoScanManager_duplicateGroups") as? [[String: Any]] {
            self.duplicateGroups = fetchGroups(for: dupDicts)
        } else if let dupIDs = defaults.array(forKey: "PhotoScanManager_duplicateGroups") as? [[String]] {
            // Legacy support
            self.duplicateGroups = fetchGroups(for: dupIDs.map { ["leading": $0.first ?? "", "assets": Array($0.dropFirst())] })
        }
        
        if let simDicts = defaults.array(forKey: "PhotoScanManager_similarGroups") as? [[String: Any]] {
            self.similarGroups = fetchGroups(for: simDicts)
        } else if let simIDs = defaults.array(forKey: "PhotoScanManager_similarGroups") as? [[String]] {
            // Legacy support
            self.similarGroups = fetchGroups(for: simIDs.map { ["leading": $0.first ?? "", "assets": Array($0.dropFirst())] })
        }
        
        if let screenIDs = defaults.stringArray(forKey: "PhotoScanManager_screenshots") {
            self.screenshots = fetchAssets(for: screenIDs)
        }
        
        if let liveIDs = defaults.stringArray(forKey: "PhotoScanManager_livePhotos") {
            self.livePhotos = fetchAssets(for: liveIDs)
        }
        
        if let burstIDs = defaults.stringArray(forKey: "PhotoScanManager_burstPhotos") {
            self.burstPhotos = fetchAssets(for: burstIDs)
        }
        
        if let blurryIDs = defaults.stringArray(forKey: "PhotoScanManager_blurryPhotos") {
            self.blurryPhotos = fetchAssets(for: blurryIDs)
        }
        
        if let allIDs = defaults.stringArray(forKey: "PhotoScanManager_allPhotos") {
            self.allPhotos = fetchAssets(for: allIDs)
        }
        
        return true
    }
    
    func scanPhotoLibrary(progressHandler: @escaping (String, Double) -> Void, completion: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            completion()
            return
        }
        
        // Run in background queue to prevent UI freezing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Fetch all images
            progressHandler("Scanning photo database...", 0.1)
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let allAssetsResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            var tempPhotos: [PHAsset] = []
            var tempScreenshots: [PHAsset] = []
            var tempLivePhotos: [PHAsset] = []
            var tempBurstPhotos: [PHAsset] = []
            
            allAssetsResult.enumerateObjects { asset, _, _ in
                tempPhotos.append(asset)
                
                // Screenshots
                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    tempScreenshots.append(asset)
                }
                
                // Live photos
                if asset.mediaSubtypes.contains(.photoLive) {
                    tempLivePhotos.append(asset)
                }
                
                // Bursts
                if asset.representsBurst, let burstId = asset.burstIdentifier {
                    let burstOptions = PHFetchOptions()
                    burstOptions.includeAllBurstAssets = true
                    let burstFetch = PHAsset.fetchAssets(withBurstIdentifier: burstId, options: burstOptions)
                    burstFetch.enumerateObjects { burstAsset, _, _ in
                        tempBurstPhotos.append(burstAsset)
                    }
                }
            }
            
            self.allPhotos = tempPhotos
            self.screenshots = tempScreenshots
            self.livePhotos = tempLivePhotos
            self.burstPhotos = tempBurstPhotos
            
            // 1.5 Scan for Blurry Photos
            progressHandler("Scanning for blurry photos...", 0.2)
            var tempBlurry: [PHAsset] = []
            
            // Limit to a subset if library is huge to prevent long wait times, but for accuracy we scan all standard photos (skip videos/bursts for speed).
            for (index, asset) in tempPhotos.enumerated() {
                if index % 10 == 0 {
                    let ratio = Double(index) / Double(tempPhotos.count)
                    progressHandler("Checking blur (\(Int(ratio * 100))%)...", 0.2 + (ratio * 0.2))
                }
                
                // Skip if it's a screenshot or represents burst, as they are mostly sharp or handled separately
                if asset.mediaSubtypes.contains(.photoScreenshot) { continue }
                
                if let cgImage = self.getCGImage(for: asset) {
                    if self.isBlurry(cgImage: cgImage) {
                        tempBlurry.append(asset)
                    }
                }
            }
            self.blurryPhotos = tempBlurry
            
            // 2. Find Duplicates
            progressHandler("Analyzing duplicates...", 0.4)
            
            // 2. Perform Vision FeaturePrint scans for similarity
            self.scanForDuplicatesAndSimilars(assets: tempPhotos, progressHandler: progressHandler)
            
            progressHandler("Finalizing metrics...", 0.95)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func scanForDuplicatesAndSimilars(assets: [PHAsset], progressHandler: @escaping (String, Double) -> Void) {
        var duplicatesTemp: [PhotoGroup] = []
        var similarsTemp: [PhotoGroup] = []
        
        // Group photos taken very close together first (time window optimization)
        // This is necessary because full cross-comparison is O(N^2) which crashes/slows down on larger libraries.
        // We cluster photos that are taken within 45 seconds of each other.
        var timeGroups: [[PHAsset]] = []
        var currentGroup: [PHAsset] = []
        
        // Assets are sorted by creationDate descending
        for asset in assets {
            if currentGroup.isEmpty {
                currentGroup.append(asset)
            } else {
                guard let lastAsset = currentGroup.last,
                      let lastDate = lastAsset.creationDate,
                      let currentDate = asset.creationDate else {
                    currentGroup.append(asset)
                    continue
                }
                
                let timeDiff = abs(lastDate.timeIntervalSince(currentDate))
                if timeDiff <= 45.0 {
                    currentGroup.append(asset)
                } else {
                    timeGroups.append(currentGroup)
                    currentGroup = [asset]
                }
            }
        }
        if !currentGroup.isEmpty {
            timeGroups.append(currentGroup)
        }
        
        // Feature print cache to save computations
        var printCache: [String: VNFeaturePrintObservation] = [:]
        
        let totalGroupCount = timeGroups.count
        
        for (gIndex, group) in timeGroups.enumerated() {
            if group.count < 2 { continue }
            
            // Update progress occasionally
            if gIndex % 5 == 0 {
                let ratio = Double(gIndex) / Double(totalGroupCount)
                let pct = 0.4 + (ratio * 0.5)
                progressHandler("Analyzing similarities (\(Int(ratio * 100))%)...", pct)
            }
            
            var matchedAssetIds = Set<String>()
            
            for i in 0..<group.count {
                let assetA = group[i]
                if matchedAssetIds.contains(assetA.localIdentifier) { continue }
                
                guard let printA = getFeaturePrint(for: assetA, cache: &printCache) else { continue }
                
                var currentDuplicates: [PHAsset] = []
                var currentSimilars: [PHAsset] = []
                
                for j in (i+1)..<group.count {
                    let assetB = group[j]
                    if matchedAssetIds.contains(assetB.localIdentifier) { continue }
                    
                    guard let printB = getFeaturePrint(for: assetB, cache: &printCache) else { continue }
                    
                    var distance: Float = 100.0
                    do {
                        try printA.computeDistance(&distance, to: printB)
                        
                        if distance < 0.3 {
                            // High similarity - Exact Duplicate
                            currentDuplicates.append(assetB)
                            matchedAssetIds.insert(assetB.localIdentifier)
                        } else if distance < 3.0 {
                            // Medium similarity - Similar
                            currentSimilars.append(assetB)
                            matchedAssetIds.insert(assetB.localIdentifier)
                        }
                    } catch {
                        print("Error computing feature print distance: \(error)")
                    }
                }
                
                if !currentDuplicates.isEmpty {
                    duplicatesTemp.append(PhotoGroup(leadingAsset: assetA, assets: currentDuplicates))
                    matchedAssetIds.insert(assetA.localIdentifier)
                }
                
                if !currentSimilars.isEmpty {
                    similarsTemp.append(PhotoGroup(leadingAsset: assetA, assets: currentSimilars))
                    matchedAssetIds.insert(assetA.localIdentifier)
                }
            }
        }
        
        self.duplicateGroups = duplicatesTemp
        self.similarGroups = similarsTemp
    }
    
    private func getFeaturePrint(for asset: PHAsset, cache: inout [String: VNFeaturePrintObservation]) -> VNFeaturePrintObservation? {
        let key = asset.localIdentifier
        if let cached = cache[key] {
            return cached
        }
        
        guard let cgImage = getCGImage(for: asset) else { return nil }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        
        do {
            try requestHandler.perform([request])
            if let observation = request.results?.first as? VNFeaturePrintObservation {
                cache[key] = observation
                return observation
            }
        } catch {
            print("Vision request failed for asset \(key): \(error)")
        }
        
        return nil
    }
    
    private func getCGImage(for asset: PHAsset) -> CGImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        
        var resultImage: CGImage? = nil
        // Request a small thumbnail size to prevent OOM memory issues
        manager.requestImage(for: asset, targetSize: CGSize(width: 120, height: 120), contentMode: .aspectFill, options: options) { image, _ in
            resultImage = image?.cgImage
        }
        return resultImage
    }
    
    private func isBlurry(cgImage: CGImage) -> Bool {
        let ciImage = CIImage(cgImage: cgImage)
        
        // 1. Edge detection
        guard let edgeFilter = CIFilter(name: "CIEdges") else { return false }
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(10.0, forKey: "inputIntensity")
        
        guard let edgeImage = edgeFilter.outputImage else { return false }
        
        // 2. Area Average
        guard let areaAverage = CIFilter(name: "CIAreaAverage") else { return false }
        areaAverage.setValue(edgeImage, forKey: kCIInputImageKey)
        areaAverage.setValue(CIVector(cgRect: edgeImage.extent), forKey: kCIInputExtentKey)
        
        guard let output = areaAverage.outputImage else { return false }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: nil)
        context.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // bitmap[0] is the red channel (since edges result is mostly grayscale/colored, we check intensity)
        let edgeIntensity = bitmap[0]
        
        // A very low average edge intensity means few edges (uniform/blurry)
        // Values usually fall under 10 for very blurry 120x120 images.
        return edgeIntensity < 8
    }
}
