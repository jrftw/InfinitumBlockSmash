import Foundation
import UIKit
import SpriteKit
import MachO
import Combine

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
    private let warningThreshold: Double = 0.40   // 40% - ~120-150MB
    private let criticalThreshold: Double = 0.60  // 60% - ~180-200MB
    private let extremeThreshold: Double = 0.80   // 80% - ~240-250MB
    
    // Memory targets
    private let targetMemoryUsage: Double = 120.0  // Target 120MB
    private let maxMemoryUsage: Double = 200.0     // Max 200MB
    
    // MARK: — Timing
    private var lastCleanupDate = Date.distantPast
    private let minimumInterval: TimeInterval = 2.0 // seconds
    private let monitoringInterval: TimeInterval = 1.0 // seconds
    
    // MARK: — Memory Pressure Source
    private let pressureSource: DispatchSourceMemoryPressure
    private var monitoringTimer: Timer?
    
    // MARK: — Cache Management
    private let memoryCache = NSCache<NSString, AnyObject>()
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    
    // MARK: — Publishers
    private let memoryStatusSubject = CurrentValueSubject<MemoryStatus, Never>(.normal)
    var memoryStatus: AnyPublisher<MemoryStatus, Never> {
        memoryStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: — Initialization
    private init() {
        // Dynamic cache limits based on device RAM
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        let targetMB = min(25.0, totalMB * 0.01)  // at most 25 MB, or 1% of RAM
        memoryCache.totalCostLimit = Int(targetMB * 1024 * 1024)
        memoryCache.countLimit = 50
        
        // Set up system memory pressure monitoring
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        pressureSource.setEventHandler { [weak self] in
            Task { await self?.handleMemoryPressure() }
        }
        pressureSource.resume()
        
        // Start memory monitoring
        startMemoryMonitoring()
        
        // Observe UIKit memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: — Memory Monitoring
    private func startMemoryMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.checkAndHandleMemoryStatus()
                self.logMemoryUsage()
            }
        }
    }
    
    private func checkAndHandleMemoryStatus() async {
        let status = checkMemoryStatus()
        if status != memoryStatusSubject.value {
            memoryStatusSubject.send(status)
            if status == .critical {
                await performAggressiveCleanup()
            }
        }
    }
    
    private func handleMemoryPressure() async {
        let status = checkMemoryStatus()
        memoryStatusSubject.send(status)
        
        switch status {
        case .critical:
            await performAggressiveCleanup()
            // If still critical after cleanup, try one more time
            if checkMemoryStatus() == .critical {
                await performAggressiveCleanup()
            }
        case .warning:
            await cleanupMemory()
        case .normal:
            break
        }
    }
    
    func getMemoryUsage() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        
        let kr: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    intPtr,
                    &count
                )
            }
        }
        
        if kr == KERN_SUCCESS {
            let used = Double(info.resident_size) / 1024.0 / 1024.0
            let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            return (used, total)
        }
        
        // Fallback method
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        let used = total * 0.5
        return (used, total)
    }
    
    // MARK: — Cleanup Triggers
    @objc private func didReceiveMemoryWarning() {
        Task { await handleMemoryPressure() }
    }
    
    func checkMemoryStatus() -> MemoryStatus {
        let (used, total) = getMemoryUsage()
        let ratio = used / total
        
        if ratio >= extremeThreshold {
            return .critical
        } else if ratio >= criticalThreshold {
            return .critical
        } else if ratio >= warningThreshold {
            return .warning
        }
        return .normal
    }
    
    // MARK: — Cleanup Entry Points
    func cleanupMemory() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupDate) >= minimumInterval else { return }
        lastCleanupDate = now
        await performCleanup()
    }
    
    private func performAggressiveCleanup() async {
        log("[MemorySystem] Starting aggressive cleanup")
        let startTime = Date()
        let initialMemory = getMemoryUsage()
        
        // Clear all caches immediately
        log("[MemorySystem] Clearing all caches")
        clearAllCaches()
        
        // Force garbage collection
        autoreleasepool {
            log("[MemorySystem] Clearing URL cache")
            URLCache.shared.removeAllCachedResponses()
            
            log("[MemorySystem] Removing temporary files")
            let tmp = FileManager.default.temporaryDirectory
            if let files = try? FileManager.default.contentsOfDirectory(
                at: tmp,
                includingPropertiesForKeys: nil
            ) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
                log("[MemorySystem] Removed \(files.count) temporary files")
            }
            
            log("[MemorySystem] Purging SpriteKit textures")
            SKTextureAtlas.preloadTextureAtlases([], withCompletionHandler: {})
            
            log("[MemorySystem] Clearing gradient cache")
            BlockShapeView.clearCache()
            
            log("[MemorySystem] Clearing image cache")
            UIImageView.clearImageCache()
        }
        
        // Reset cache statistics
        cacheHits = 0
        cacheMisses = 0
        
        // Force garbage collection
        autoreleasepool {
            // Additional cleanup if needed
        }
        
        let endTime = Date()
        let finalMemory = getMemoryUsage()
        let memoryReduction = initialMemory.used - finalMemory.used
        
        log("[MemorySystem] Aggressive cleanup completed in \(String(format: "%.2f", endTime.timeIntervalSince(startTime)))s")
        log("[MemorySystem] Memory reduced by \(String(format: "%.1f", memoryReduction))MB")
        logMemoryUsage()
    }
    
    private func performCleanup() async {
        log("[MemorySystem] Starting normal cleanup")
        let startTime = Date()
        let initialMemory = getMemoryUsage()
        
        autoreleasepool {
            log("[MemorySystem] Clearing URL cache")
            URLCache.shared.removeAllCachedResponses()
            
            log("[MemorySystem] Removing old temporary files")
            let tmp = FileManager.default.temporaryDirectory
            let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
            if let files = try? FileManager.default.contentsOfDirectory(
                at: tmp,
                includingPropertiesForKeys: [.creationDateKey]
            ) {
                var removedCount = 0
                for file in files {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       creationDate < thirtyMinutesAgo {
                        try? FileManager.default.removeItem(at: file)
                        removedCount += 1
                    }
                }
                log("[MemorySystem] Removed \(removedCount) old temporary files")
            }
            
            log("[MemorySystem] Purging unused SpriteKit textures")
            SKTextureAtlas.preloadTextureAtlases([], withCompletionHandler: {})
            
            log("[MemorySystem] Clearing old cached images")
            UIImageView.clearOldImageCache()
        }
        
        let endTime = Date()
        let finalMemory = getMemoryUsage()
        let memoryReduction = initialMemory.used - finalMemory.used
        
        log("[MemorySystem] Normal cleanup completed in \(String(format: "%.2f", endTime.timeIntervalSince(startTime)))s")
        log("[MemorySystem] Memory reduced by \(String(format: "%.1f", memoryReduction))MB")
        logMemoryUsage()
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
    
    private func logMemoryUsage() {
        let (used, total) = getMemoryUsage()
        let ratio = used / total
        let status = checkMemoryStatus()
        
        log("[MemorySystem] Memory Status: \(status)")
        log("[MemorySystem] Memory Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", ratio * 100))%)")
        log("[MemorySystem] Cache Stats - Hits: \(cacheHits), Misses: \(cacheMisses), Hit Ratio: \(String(format: "%.1f", Double(cacheHits) / Double(max(1, cacheHits + cacheMisses)) * 100))%")
    }
    
    deinit {
        monitoringTimer?.invalidate()
        pressureSource.cancel()
    }
}
