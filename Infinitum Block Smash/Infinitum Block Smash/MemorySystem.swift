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
    
    // MARK: — Dynamic Thresholds based on Device Simulation
    private var warningThreshold: Double {
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            // Use device-specific thresholds
            if deviceSimulator.isLowEndDevice() {
                return 0.25 // 25% for low-end devices
            } else {
                return 0.30 // 30% for mid/high-end devices
            }
        } else {
            return 0.30 // Default for real devices
        }
    }
    
    private var criticalThreshold: Double {
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            if deviceSimulator.isLowEndDevice() {
                return 0.35 // 35% for low-end devices
            } else {
                return 0.45 // 45% for mid/high-end devices
            }
        } else {
            return 0.45 // Default for real devices
        }
    }
    
    private var extremeThreshold: Double {
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            if deviceSimulator.isLowEndDevice() {
                return 0.45 // 45% for low-end devices
            } else {
                return 0.60 // 60% for mid/high-end devices
            }
        } else {
            return 0.60 // Default for real devices
        }
    }
    
    // Dynamic memory targets based on device simulation
    private var targetMemoryUsage: Double {
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            let limit = deviceSimulator.getSimulatedMemoryLimit()
            return limit * 0.6 // Target 60% of available memory
        } else {
            return 100.0 // Default 100MB for real devices
        }
    }
    
    private var maxMemoryUsage: Double {
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            let limit = deviceSimulator.getSimulatedMemoryLimit()
            return limit * 0.8 // Max 80% of available memory
        } else {
            return 150.0 // Default 150MB for real devices
        }
    }
    
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
        // Dynamic cache limits based on device simulation
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            let limit = deviceSimulator.getSimulatedMemoryLimit()
            let targetMB = min(limit * 0.02, 25.0) // 2% of available memory, max 25MB
            memoryCache.totalCostLimit = Int(targetMB * 1024 * 1024)
            memoryCache.countLimit = deviceSimulator.isLowEndDevice() ? 25 : 50
        } else {
            // Original logic for real devices
            let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
            let targetMB = min(25.0, totalMB * 0.01)  // at most 25 MB, or 1% of RAM
            memoryCache.totalCostLimit = Int(targetMB * 1024 * 1024)
            memoryCache.countLimit = 50
        }
        
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
        
        // Log device simulation status
        if deviceSimulator.isRunningInSimulator() {
            log("[MemorySystem] Running in simulator mode")
            log("[MemorySystem] Simulated device: \(deviceSimulator.getCurrentDeviceModel())")
            log("[MemorySystem] Memory limit: \(String(format: "%.1f", deviceSimulator.getSimulatedMemoryLimit()))MB")
            log("[MemorySystem] Low-end device: \(deviceSimulator.isLowEndDevice())")
        }
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
        let deviceSimulator = DeviceSimulator.shared
        
        if deviceSimulator.isRunningInSimulator() {
            // Use simulated memory constraints
            let currentMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            let simulatedLimit = deviceSimulator.getSimulatedMemoryLimit()
            return (currentMemory, simulatedLimit)
        } else {
            // Original logic for real devices
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
        let deviceSimulator = DeviceSimulator.shared
        let isLowEnd = deviceSimulator.isLowEndDevice()
        
        log("[MemorySystem] Starting aggressive cleanup")
        if deviceSimulator.isRunningInSimulator() {
            log("[MemorySystem] Simulated device: \(deviceSimulator.getCurrentDeviceModel())")
            log("[MemorySystem] Low-end device: \(isLowEnd)")
        }
        
        let startTime = Date()
        let initialMemory = getMemoryUsage()
        
        autoreleasepool {
            log("[MemorySystem] Clearing all caches")
            clearAllCaches()
            
            log("[MemorySystem] Clearing URL cache")
            URLCache.shared.removeAllCachedResponses()
            
            log("[MemorySystem] Removing temporary files")
            removeTemporaryFiles()
            
            log("[MemorySystem] Purging SpriteKit textures")
            SKTextureAtlas.preloadTextureAtlases([], withCompletionHandler: {})
            
            // Additional cleanup for low-end devices in simulator
            if deviceSimulator.isRunningInSimulator() && isLowEnd {
                log("[MemorySystem] Performing low-end device specific cleanup")
                // Clear more aggressively for low-end devices
                UIImageView.clearOldImageCache()
                BlockShapeView.clearCache()
            }
        }
        
        // Reset cache statistics
        cacheHits = 0
        cacheMisses = 0
        
        let endTime = Date()
        let finalMemory = getMemoryUsage()
        let memoryReduction = initialMemory.used - finalMemory.used
        
        log("[MemorySystem] Aggressive cleanup completed in \(String(format: "%.2f", endTime.timeIntervalSince(startTime)))s")
        log("[MemorySystem] Memory reduced by \(String(format: "%.1f", memoryReduction))MB")
        logMemoryUsage()
    }
    
    private func performCleanup() async {
        let deviceSimulator = DeviceSimulator.shared
        let isLowEnd = deviceSimulator.isLowEndDevice()
        
        log("[MemorySystem] Starting normal cleanup")
        if deviceSimulator.isRunningInSimulator() {
            log("[MemorySystem] Simulated device: \(deviceSimulator.getCurrentDeviceModel())")
        }
        
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
            
            // Additional cleanup for low-end devices in simulator
            if deviceSimulator.isRunningInSimulator() && isLowEnd {
                log("[MemorySystem] Performing low-end device specific cleanup")
                // More aggressive cleanup for low-end devices
                BlockShapeView.clearCache()
            }
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
        let deviceSimulator = DeviceSimulator.shared
        
        // Adjust cache cost based on device simulation
        var adjustedCost = cost
        if deviceSimulator.isRunningInSimulator() && deviceSimulator.isLowEndDevice() {
            adjustedCost = Int(Double(cost) * 1.5) // Higher cost for low-end devices
        }
        
        memoryCache.setObject(object, forKey: key as NSString, cost: adjustedCost)
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
    
    // MARK: — Helper Functions
    private func removeTemporaryFiles() {
        let tmp = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
                if let encodedPath = file.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                    log("[MemorySystem] Removed temp file: \(encodedPath)")
                } else {
                    log("[MemorySystem] Removed temp file: \(file.path)")
                }
            }
            if let encodedTmpPath = tmp.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                log("[MemorySystem] Removed \(files.count) temporary files from \(encodedTmpPath)")
            } else {
                log("[MemorySystem] Removed \(files.count) temporary files from \(tmp.path)")
            }
        }
    }
    
    // MARK: — Logging
    private func log(_ message: String) {
        print(message)
    }
    
    private func logMemoryUsage() {
        let (used, total) = getMemoryUsage()
        let ratio = used / total
        let status = checkMemoryStatus()
        let deviceSimulator = DeviceSimulator.shared
        
        log("[MemorySystem] Memory Status: \(status)")
        log("[MemorySystem] Memory Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", ratio * 100))%)")
        log("[MemorySystem] Cache Stats - Hits: \(cacheHits), Misses: \(cacheMisses), Hit Ratio: \(String(format: "%.1f", Double(cacheHits) / Double(max(1, cacheHits + cacheMisses)) * 100))%")
        
        if deviceSimulator.isRunningInSimulator() {
            log("[MemorySystem] Simulated Device: \(deviceSimulator.getCurrentDeviceModel())")
            log("[MemorySystem] Low-end Device: \(deviceSimulator.isLowEndDevice())")
            log("[MemorySystem] Simulated Memory Pressure: \(String(format: "%.1f", deviceSimulator.getSimulatedMemoryPressure() * 100))%")
            log("[MemorySystem] Simulated Thermal Throttling: \(String(format: "%.1f", deviceSimulator.getSimulatedThermalThrottling() * 100))%")
        }
    }
    
    deinit {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        pressureSource.cancel()
    }
}
