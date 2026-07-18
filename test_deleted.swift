import Foundation
import Photos

let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumRecentlyDeleted, options: nil)
if let collection = collections.firstObject {
    print("Found recently deleted collection: \(collection.localizedTitle ?? "")")
    let assets = PHAsset.fetchAssets(in: collection, options: nil)
    print("Assets count: \(assets.count)")
} else {
    print("Recently deleted collection not found")
}
