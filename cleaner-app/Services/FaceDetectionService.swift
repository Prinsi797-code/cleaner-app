//  FaceDetectionService.swift

import Vision
import Photos
import UIKit

// MARK: - Models
struct FaceDescriptor {
    let assetID: String
    let normX: Float, normY: Float, normW: Float, normH: Float
    let eyeDistRatio: Float, eyeNoseRatio: Float, eyeMouthRatio: Float
    let sizeRatio: Float
    let confidence: Float
}

struct DetectedFacePhoto {
    let asset: PHAsset
    let descriptors: [FaceDescriptor]
    var fileSize: Int64 = 0
}

struct FaceGroup: Identifiable {
    let id = UUID()
    var photos: [DetectedFacePhoto]
    var totalSize: Int64 { photos.reduce(0) { $0 + $1.fileSize } }
    var representative: PHAsset { photos.first!.asset }
}

// MARK: - Service
class FaceDetectionService {
    static let shared = FaceDetectionService()
    private init() {}

    func detectAllFaces(
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping ([FaceGroup]) -> Void
    ) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion([]) }; return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let opts = PHFetchOptions()
                opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let allPhotos = PHAsset.fetchAssets(with: opts)
                let total = allPhotos.count
                var detected: [DetectedFacePhoto] = []
                let semaphore = DispatchSemaphore(value: 4)
                let lock = NSLock()
                var current = 0
                let group = DispatchGroup()

                allPhotos.enumerateObjects { asset, _, _ in
                    if asset.mediaSubtypes.contains(.photoScreenshot) { return }
                    group.enter(); semaphore.wait()
                    self.detectFaces(in: asset) { result in
                        defer { semaphore.signal(); group.leave() }
                        lock.lock()
                        current += 1
                        if let r = result { detected.append(r) }
                        let c = current
                        lock.unlock()
                        DispatchQueue.main.async { progress(c, total) }
                    }
                }
                group.notify(queue: .global()) {
                    let groups = self.groupByFace(detected, threshold: 0.78)
                    DispatchQueue.main.async { completion(groups) }
                }
            }
        }
    }

    private func detectFaces(in asset: PHAsset, completion: @escaping (DetectedFacePhoto?) -> Void) {
        let opts = PHImageRequestOptions()
        opts.isSynchronous = false
        opts.deliveryMode  = .highQualityFormat
        opts.resizeMode    = .fast
        opts.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 1024, height: 1024),
            contentMode: .aspectFit, options: opts
        ) { image, _ in
            guard let image, let cgImage = image.cgImage else { completion(nil); return }

            let req = VNDetectFaceLandmarksRequest { req, err in
                guard err == nil,
                      let results = req.results as? [VNFaceObservation], !results.isEmpty
                else { completion(nil); return }

                let real = results.filter { $0.boundingBox.width * $0.boundingBox.height >= 0.02 }
                guard !real.isEmpty else { completion(nil); return }

                let descs = real.compactMap { self.buildDescriptor($0, assetID: asset.localIdentifier) }
                guard !descs.isEmpty else { completion(nil); return }

                let fileSize = PHAssetResource.assetResources(for: asset)
                    .first.flatMap { $0.value(forKey: "fileSize") as? Int64 } ?? 0
                var photo = DetectedFacePhoto(asset: asset, descriptors: descs)
                photo.fileSize = fileSize
                completion(photo)
            }
            req.revision = VNDetectFaceLandmarksRequestRevision3
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([req])
        }
    }

    private func buildDescriptor(_ obs: VNFaceObservation, assetID: String) -> FaceDescriptor? {
        let bb = obs.boundingBox
        let normX = Float(bb.minX), normY = Float(1 - bb.maxY)
        let normW = Float(bb.width), normH = Float(bb.height)

        guard let lm = obs.landmarks else {
            return FaceDescriptor(assetID: assetID, normX: normX, normY: normY, normW: normW, normH: normH,
                                  eyeDistRatio: 0, eyeNoseRatio: 0, eyeMouthRatio: 0,
                                  sizeRatio: normW * normH, confidence: obs.confidence)
        }

        func imgPt(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let pts = region?.normalizedPoints, !pts.isEmpty else { return nil }
            let mx = pts.map(\.x).reduce(0, +) / Double(pts.count)
            let my = pts.map(\.y).reduce(0, +) / Double(pts.count)
            return CGPoint(x: bb.minX + mx * bb.width, y: 1 - (bb.minY + my * bb.height))
        }

        let lePt = imgPt(lm.leftEye);  let rePt = imgPt(lm.rightEye)
        let nPt  = imgPt(lm.nose) ?? imgPt(lm.noseCrest)
        let mPt  = imgPt(lm.outerLips) ?? imgPt(lm.innerLips)

        let lx = Float(lePt?.x ?? 0), ly = Float(lePt?.y ?? 0)
        let rx = Float(rePt?.x ?? 0), ry = Float(rePt?.y ?? 0)
        let nx = Float(nPt?.x  ?? 0), ny = Float(nPt?.y  ?? 0)
        let mx = Float(mPt?.x  ?? 0), my = Float(mPt?.y  ?? 0)

        let eyeDist    = sqrt((lx-rx)*(lx-rx) + (ly-ry)*(ly-ry))
        let eyeMidX    = (lx+rx)/2, eyeMidY = (ly+ry)/2
        let eyeToNose  = sqrt((eyeMidX-nx)*(eyeMidX-nx) + (eyeMidY-ny)*(eyeMidY-ny))
        let eyeToMouth = sqrt((eyeMidX-mx)*(eyeMidX-mx) + (eyeMidY-my)*(eyeMidY-my))

        return FaceDescriptor(
            assetID: assetID, normX: normX, normY: normY, normW: normW, normH: normH,
            eyeDistRatio:  normW > 0 ? eyeDist    / normW : 0,
            eyeNoseRatio:  normH > 0 ? eyeToNose  / normH : 0,
            eyeMouthRatio: normH > 0 ? eyeToMouth / normH : 0,
            sizeRatio: normW * normH, confidence: obs.confidence
        )
    }

    private func groupByFace(_ photos: [DetectedFacePhoto], threshold: Float) -> [FaceGroup] {
        var used = Set<String>()
        var groups = [FaceGroup]()
        let sorted = photos.sorted { $0.fileSize > $1.fileSize }

        for base in sorted {
            let baseID = base.asset.localIdentifier
            if used.contains(baseID) { continue }
            var group = [base]; used.insert(baseID)

            for candidate in sorted {
                let cID = candidate.asset.localIdentifier
                if used.contains(cID) { continue }
                let timeDiff = abs((base.asset.creationDate ?? .distantPast)
                    .timeIntervalSince(candidate.asset.creationDate ?? .distantPast))
                let timeBonus: Float = timeDiff < 600 ? 0.06 : 0
                var best: Float = 0
                for bf in base.descriptors {
                    for cf in candidate.descriptors {
                        let s = similarity(bf, cf) + timeBonus
                        if s > best { best = s }
                    }
                }
                if best >= threshold { group.append(candidate); used.insert(cID) }
            }
            if group.count >= 2 { groups.append(FaceGroup(photos: group)) }
        }
        return groups.sorted { $0.totalSize > $1.totalSize }
    }

    private func similarity(_ a: FaceDescriptor, _ b: FaceDescriptor) -> Float {
        let hasLM = a.eyeDistRatio > 0 && b.eyeDistRatio > 0 && a.eyeNoseRatio > 0 && b.eyeNoseRatio > 0
        if hasLM {
            return 1 - min(1,
                abs(a.eyeDistRatio  - b.eyeDistRatio)  * 3 +
                abs(a.eyeNoseRatio  - b.eyeNoseRatio)  * 2 +
                abs(a.eyeMouthRatio - b.eyeMouthRatio)  * 2)
        }
        let dx = a.normX - b.normX, dy = a.normY - b.normY
        return 1 - min(1, sqrt(dx*dx + dy*dy) * 2 + abs(a.sizeRatio - b.sizeRatio) * 3)
    }

    func deleteAssets(_ assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { success, _ in DispatchQueue.main.async { completion(success) } }
    }
}
