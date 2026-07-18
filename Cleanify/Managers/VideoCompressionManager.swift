import Foundation
import Photos
import AVFoundation

class VideoCompressionManager {
    static let shared = VideoCompressionManager()
    
    private init() {}
    
    /// Compresses a given PHAsset and returns the new PHAsset, deleting the old one if successful.
    func compressVideo(asset: PHAsset, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<PHAsset, Error>) -> Void) {
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPreset1280x720) { session, info in
            guard let session = session else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "VideoCompression", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session."])))
                }
                return
            }
            
            // Create a temporary file path
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".mp4"
            let outputURL = tempDir.appendingPathComponent(fileName)
            
            // Remove existing file just in case
            try? FileManager.default.removeItem(at: outputURL)
            
            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true
            
            // Setup progress timer
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async {
                    progressHandler(session.progress)
                }
            }
            
            session.exportAsynchronously {
                timer.invalidate()
                DispatchQueue.main.async {
                    progressHandler(1.0)
                    
                    switch session.status {
                    case .completed:
                        self.saveToLibraryAndDeleteOriginal(outputURL: outputURL, originalAsset: asset, completion: completion)
                    case .failed:
                        let error = session.error ?? NSError(domain: "VideoCompression", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed."])
                        completion(.failure(error))
                    case .cancelled:
                        let error = NSError(domain: "VideoCompression", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export cancelled."])
                        completion(.failure(error))
                    default:
                        let error = NSError(domain: "VideoCompression", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export unknown error."])
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func saveToLibraryAndDeleteOriginal(outputURL: URL, originalAsset: PHAsset, completion: @escaping (Result<PHAsset, Error>) -> Void) {
        var placeholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            // 1. Save new asset
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            placeholder = creationRequest?.placeholderForCreatedAsset
            
            // 2. Delete original asset
            PHAssetChangeRequest.deleteAssets([originalAsset] as NSArray)
            
        }) { success, error in
            // Clean up temporary file
            try? FileManager.default.removeItem(at: outputURL)
            
            DispatchQueue.main.async {
                if success, let placeholder = placeholder, let localId = placeholder.localIdentifier as String? {
                    // Fetch the newly created asset
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
                    if let newAsset = fetchResult.firstObject {
                        completion(.success(newAsset))
                    } else {
                        completion(.failure(NSError(domain: "VideoCompression", code: 5, userInfo: [NSLocalizedDescriptionKey: "Saved successfully but could not fetch new asset."])))
                    }
                } else {
                    let err = error ?? NSError(domain: "VideoCompression", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to save or delete."])
                    completion(.failure(err))
                }
            }
        }
    }
}
