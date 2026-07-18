//
//  StorageManager.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import Foundation

class StorageManager {
    
    static let shared = StorageManager()
    
    private init() {}
    
    func getDiskSpaceBytes() -> (total: Int64, free: Int64, used: Int64) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            
            if let totalCapacity = values.volumeTotalCapacity,
               let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
                
                let total = Int64(totalCapacity)
                let free = availableCapacity
                let used = total - free
                
                return (total, free, used)
            }
        } catch {
            print("Error reading disk space: \(error)")
        }
        return (0, 0, 0)
    }
    
    func getFormattedStats() -> (total: String, free: String, used: String, percentUsed: Double) {
        let (total, free, used) = getDiskSpaceBytes()
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .file
        
        let totalStr = formatter.string(fromByteCount: total)
        let freeStr = formatter.string(fromByteCount: free)
        let usedStr = formatter.string(fromByteCount: used)
        
        let percent = total > 0 ? Double(used) / Double(total) : 0.0
        return (totalStr, freeStr, usedStr, percent)
    }
}
