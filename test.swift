import Foundation
let url = URL(fileURLWithPath: NSHomeDirectory())
do {
    let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
    let total = values.volumeTotalCapacity ?? 0
    let free = values.volumeAvailableCapacityForImportantUsage ?? 0
    print("Total: \(total), Free: \(free)")
} catch {
    print("Error")
}
