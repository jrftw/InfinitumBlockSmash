import Foundation
import UIKit
import SpriteKit
import MachO

// MARK: - Supporting Types
public enum MemoryStatus {
    case normal
    case warning
    case critical
}

// MARK: - MemorySystem
@MainActor
final class MemorySystem {
    static let shared = MemorySystem()
    
    // MARK: — Thresholds
    private let warningThreshold: Double = 0.70   // 70%
    private let criticalThreshold: Double = 0.85  // 85%
    
    // MARK: — Timing
    private var lastCleanupDate = Date.distantPast
    private let minimumInterval: TimeInterval = 30.0 // seconds
    
    // MARK: — Memory Pressure Source
    private let pressureSource: DispatchSourceMemoryPressure
    
    // MARK: — Cache Management
    private let memoryCache = NSCache<NSString, AnyObject>()
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    
    // MARK: — Initialization
    private init() {
        // Configure cache limits
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 75 * 1024 * 1024 // 75 MB
        
        // Set up system memory pressure monitoring
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        pressureSource.setEventHandler { [weak self] in
            Task { await self?.cleanupMemory() }
        }
        pressureSource.resume()
        
        // Observe UIKit memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: — Memory Monitoring
    func getMemoryUsage() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size
        )
        let kr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0) }
        let used  = Double(info.resident_size) / 1024 / 1024
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        return (used, total)
    }
    
    // MARK: — Cleanup Triggers
    @objc private func didReceiveMemoryWarning() {
        Task { await cleanupMemory() }
    }
    
    func checkMemoryStatus() -> MemoryStatus {
        let (used, total) = getMemoryUsage()
        let ratio = used / total
        if ratio >= criticalThreshold {
            Task { await cleanupMemory() }
            return .critical
        } else if ratio >= warningThreshold {
            return .warning
        }
        return .normal
    }
    
    // MARK: — Cleanup Entry Point
    func cleanupMemory() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupDate) >= minimumInterval else { return }
        lastCleanupDate = now
        await performCleanup()
    }
    
    // MARK: — Perform Cleanup
    private func performCleanup() async {
        log("[MemorySystem] Cleanup started")
        
        autoreleasepool {
            // Clear URL cache
            URLCache.shared.removeAllCachedResponses()
            
            // Remove temp files
            let tmp = FileManager.default.temporaryDirectory
            if let files = try? FileManager.default.contentsOfDirectory(
                at: tmp,
                includingPropertiesForKeys: nil
            ) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            
            // Purge SpriteKit textures
            SKTextureAtlas.preloadTextureAtlases([], withCompletionHandler: {})
            
            // Clear our memory-based cache
            memoryCache.removeAllObjects()
            
            // Clear custom gradient cache
            BlockShapeView.clearCache()
        }
        
        // Reset cache statistics
        cacheHits = 0
        cacheMisses = 0
        
        logMemoryUsage()
        log("[MemorySystem] Cleanup completed")
    }
    
    // MARK: — Cache Management
    func setMemoryCache<T: AnyObject>(_ object: T, forKey key: String, cost: Int = 1) {
        memoryCache.setObject(object, forKey: key as NSString, cost: cost)
    }
    
    func getMemoryCache<T: AnyObject>(forKey key: String) -> T? {
        let result = memoryCache.object(forKey: key as NSString) as? T
        if result != nil {
            cacheHits += 1
        } else {
            cacheMisses += 1
        }
        return result
    }
    
    func removeMemoryCache(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
    }
    
    func clearAllCaches() {
        memoryCache.removeAllObjects()
        BlockShapeView.clearCache()
        cacheHits = 0
        cacheMisses = 0
    }
    
    func getCacheStats() -> (hits: Int, misses: Int) {
        return (cacheHits, cacheMisses)
    }
    
    // MARK: — Logging
    private func log(_ message: String) {
        print(message)
    }
    
    func logMemoryUsage() {
        let (used, total) = getMemoryUsage()
        let percent = (used / total) * 100
        log(String(
            format: "[MemorySystem] Usage: %.1fMB / %.1fMB (%.1f%%)",
            used, total, percent
        ))
    }
}
