/*
 * MemorySystem.swift
 *
 * ADVANCED MEMORY MANAGEMENT AND MONITORING SYSTEM
 *
 * This service provides comprehensive memory management, monitoring, and optimization
 * for the Infinitum Block Smash game. It includes device simulation support, dynamic
 * thresholds, and intelligent memory cleanup strategies.
 *
 * KEY RESPONSIBILITIES:
 * - Real-time memory usage monitoring
 * - Dynamic memory threshold management
 * - Device simulation memory constraints
 * - Memory pressure detection and response
 * - Intelligent memory cleanup strategies
 * - Cache management and optimization
 * - Memory status tracking and reporting
 * - Performance monitoring and logging
 * - Memory warning handling
 * - Device-specific memory optimization
 *
 * MAJOR DEPENDENCIES:
 * - UIKit: Memory warning notifications
 * - SpriteKit: Game rendering memory management
 * - MachO: System memory information
 * - Combine: Memory status publishing
 * - DeviceSimulator.swift: Device simulation support
 * - NotificationCenter: System notifications
 * - DispatchSource: Memory pressure monitoring
 *
 * MEMORY MONITORING:
 * - Real-time memory usage tracking
 * - Dynamic threshold calculation
 * - Memory pressure detection
 * - Device-specific constraints
 * - Performance impact monitoring
 * - Memory trend analysis
 *
 * DEVICE SIMULATION:
 * - Simulated memory constraints
 * - Low-end device simulation
 * - Dynamic threshold adjustment
 * - Memory limit simulation
 * - Device-specific optimization
 * - Performance testing support
 *
 * MEMORY THRESHOLDS:
 * - Warning threshold (25-30% usage)
 * - Critical threshold (35-45% usage)
 * - Extreme threshold (45-60% usage)
 * - Device-specific adjustments
 * - Dynamic threshold calculation
 * - Adaptive memory management
 *
 * CLEANUP STRATEGIES:
 * - Normal cleanup: Standard memory optimization
 * - Aggressive cleanup: Critical memory pressure response
 * - Cache cleanup: Memory cache optimization
 * - Texture cleanup: SpriteKit texture management
 * - Background cleanup: Periodic maintenance
 * - Emergency cleanup: Extreme memory pressure
 *
 * CACHE MANAGEMENT:
 * - Dynamic cache size limits
 * - Cache hit/miss tracking
 * - Memory-efficient caching
 * - Cache cleanup strategies
 * - Performance optimization
 * - Device-specific limits
 *
 * PERFORMANCE FEATURES:
 * - Efficient memory monitoring
 * - Background cleanup operations
 * - Memory pressure response
 * - Performance impact minimization
 * - Real-time status updates
 * - Optimized cleanup timing
 *
 * MEMORY PRESSURE HANDLING:
 * - System memory pressure detection
 * - Automatic cleanup triggers
 * - Progressive cleanup strategies
 * - Memory warning response
 * - Emergency memory recovery
 * - Performance degradation prevention
 *
 * DEVICE OPTIMIZATION:
 * - Low-end device support
 * - High-end device optimization
 * - Device-specific thresholds
 * - Memory constraint simulation
 * - Performance testing
 * - Cross-device compatibility
 *
 * MONITORING FEATURES:
 * - Real-time memory tracking
 * - Status change detection
 * - Performance logging
 * - Memory usage statistics
 * - Cleanup effectiveness tracking
 * - Device simulation logging
 *
 * INTEGRATION POINTS:
 * - GameScene for texture management
 * - CacheManager for cache optimization
 * - DeviceSimulator for constraints
 * - Performance monitoring systems
 * - Crash reporting system
 * - Analytics tracking
 *
 * ARCHITECTURE ROLE:
 * This service acts as the central memory management coordinator,
 * providing intelligent memory optimization while maintaining
 * performance and device compatibility.
 *
 * THREADING CONSIDERATIONS:
 * - @MainActor for UI updates
 * - Background cleanup operations
 * - Thread-safe memory monitoring
 * - Safe pressure handling
 *
 * PERFORMANCE CONSIDERATIONS:
 * - Minimal monitoring overhead
 * - Efficient cleanup strategies
 * - Background processing
 * - Memory-efficient operations
 *
 * DEVICE COMPATIBILITY:
 * - Cross-device optimization
 * - Low-end device support
 * - High-end device utilization
 * - Device simulation testing
 *
 * REVIEW NOTES:
 * - Verify memory monitoring accuracy and performance impact
 * - Check device simulation memory constraint accuracy
 * - Test memory cleanup strategies effectiveness
 * - Validate memory pressure detection and response
 * - Check cache management and optimization
 * - Test memory thresholds on different device types
 * - Verify memory warning handling and recovery
 * - Check device-specific memory optimization
 * - Test memory monitoring during heavy game operations
 * - Validate memory cleanup timing and frequency
 * - Check memory usage statistics and reporting
 * - Test memory pressure response during gameplay
 * - Verify cache hit/miss ratio optimization
 * - Check memory monitoring during app background/foreground
 * - Test memory cleanup during low memory conditions
 * - Validate device simulation memory constraints
 * - Check memory optimization impact on game performance
 * - Test memory monitoring during rapid state changes
 * - Verify memory cleanup integration with other systems
 * - Check memory usage tracking accuracy
 * - Test memory pressure handling during network operations
 * - Validate memory optimization during app updates
 * - Check memory monitoring compatibility with different iOS versions
 * - Test memory cleanup during device storage pressure
 * - Verify memory threshold calculation accuracy
 * - Check memory monitoring during heavy rendering operations
 * - Test memory optimization during background processing
 * - Validate memory pressure detection timing
 * - Check memory cleanup effectiveness on low-end devices
 * - Test memory monitoring during rapid UI updates
 */

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
    private let warningThreshold: Double = MemoryConfig.getMemoryThresholds().warning
    private let criticalThreshold: Double = MemoryConfig.getMemoryThresholds().critical
    private let extremeThreshold: Double = MemoryConfig.getMemoryThresholds().extreme
    
    // Dynamic memory targets based on device simulation
    private var targetMemoryUsage: Double {
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            let limit = deviceSimulator.getSimulatedMemoryLimit()
            return limit * 0.3 // Target 30% of available memory (reduced from 40%)
        } else {
            return 60.0 // Default 60MB for real devices (reduced from 80MB)
        }
    }
    
    private var maxMemoryUsage: Double {
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isRunningInSimulator() {
            let limit = deviceSimulator.getSimulatedMemoryLimit()
            return limit * 0.45 // Max 45% of available memory (reduced from 60%)
        } else {
            return 90.0 // Default 90MB for real devices (reduced from 120MB)
        }
    }
    
    // MARK: — Timing
    private var lastCleanupDate = Date.distantPast
    private let minimumInterval: TimeInterval = 120.0 // Increased from 60.0 to 120.0 seconds to reduce overhead
    private let monitoringInterval: TimeInterval = MemoryConfig.getIntervals().memoryCheck
    
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
            let targetMB = min(limit * 0.005, 10.0) // 0.5% of available memory, max 10MB (reduced from 1% and 15MB)
            memoryCache.totalCostLimit = Int(targetMB * 1024 * 1024)
            memoryCache.countLimit = deviceSimulator.isLowEndDevice() ? 10 : 20 // Reduced from 15:30
        } else {
            // Original logic for real devices
            let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
            let targetMB = min(10.0, totalMB * 0.003)  // at most 10 MB, or 0.3% of RAM (reduced from 15MB and 0.5%)
            memoryCache.totalCostLimit = Int(targetMB * 1024 * 1024)
            memoryCache.countLimit = 20 // Reduced from 30
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
    
    func getMemoryUsage() -> (used: Double, total: Double) {
        let deviceSimulator = DeviceSimulator.shared
        
        if deviceSimulator.isRunningInSimulator() {
            // For simulator, use more conservative memory estimation
            // since ProcessInfo.processInfo.physicalMemory returns host Mac memory
            let estimatedUsage = getEstimatedSimulatorMemoryUsage()
            let simulatedLimit = deviceSimulator.getSimulatedMemoryLimit()
            return (estimatedUsage, simulatedLimit)
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
    
    /// Get estimated memory usage for simulator (more accurate than ProcessInfo)
    private func getEstimatedSimulatorMemoryUsage() -> Double {
        let deviceSimulator = DeviceSimulator.shared
        let baseMemory = 80.0 // Base memory usage in MB
        
        // Add memory from various sources
        let textureMemory = estimateTextureMemory()
        let nodeMemory = estimateNodeMemory()
        let cacheMemory = estimateCacheMemory()
        let particleMemory = estimateParticleMemory()
        
        let totalEstimated = baseMemory + textureMemory + nodeMemory + cacheMemory + particleMemory
        
        // Apply device-specific adjustments
        if deviceSimulator.isLowEndDevice() {
            return totalEstimated * 1.2 // Low-end devices use more memory due to less optimization
        }
        
        return totalEstimated
    }
    
    private func estimateTextureMemory() -> Double {
        // Estimate based on texture cache size and active textures
        let textureCacheSize = Double(memoryCache.totalCostLimit) / 1024.0 / 1024.0
        return textureCacheSize * 2.0 // Estimate 2x the cache size for active textures
    }
    
    private func estimateNodeMemory() -> Double {
        // Estimate based on active nodes (rough estimate)
        return 25.0 // Conservative estimate for active nodes
    }
    
    private func estimateCacheMemory() -> Double {
        // Estimate based on memory cache usage
        let cacheSize = Double(memoryCache.totalCostLimit) / 1024.0 / 1024.0
        return cacheSize
    }
    
    private func estimateParticleMemory() -> Double {
        // Estimate particle system memory usage
        return 15.0 // Conservative estimate for particle effects
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
        
        // Single autoreleasepool for all cleanup operations to reduce overhead
        autoreleasepool {
            log("[MemorySystem] Clearing caches")
            clearAllCaches()
            
            log("[MemorySystem] Clearing URL cache")
            URLCache.shared.removeAllCachedResponses()
            
            log("[MemorySystem] Clearing texture caches")
            clearTextureCaches()
            
            log("[MemorySystem] Clearing node pools")
            NodePool.shared.clearAllPools()
            
            log("[MemorySystem] Clearing memory cache")
            memoryCache.removeAllObjects()
            
            log("[MemorySystem] Clearing temporary data")
            clearTemporaryData()
        }
        
        // Clear SpriteKit textures in separate operation
        log("[MemorySystem] Clearing SpriteKit textures")
        Task {
            await SKTexture.preload([])
            await SKTextureAtlas.preloadTextureAtlases([])
        }
        
        let endTime = Date()
        let finalMemory = getMemoryUsage()
        let duration = endTime.timeIntervalSince(startTime)
        let memoryFreed = initialMemory.used - finalMemory.used
        
        log("[MemorySystem] Aggressive cleanup completed in \(String(format: "%.2f", duration))s")
        log("[MemorySystem] Memory freed: \(String(format: "%.1f", memoryFreed))MB")
        log("[MemorySystem] Final memory usage: \(String(format: "%.1f", finalMemory.used))MB / \(String(format: "%.1f", finalMemory.total))MB")
        
        // Only perform emergency cleanup if still critical and significant time has passed
        if checkMemoryStatus() == .critical && Date().timeIntervalSince(startTime) > 120.0 {
            log("[MemorySystem] Memory still critical after cleanup, performing emergency cleanup")
            await performEmergencyCleanup()
        }
    }
    
    /// Emergency memory cleanup for immediate pressure situations
    func performEmergencyCleanup() async {
        log("[MemorySystem] Starting emergency cleanup")
        
        autoreleasepool {
            // Clear everything possible
            clearAllCaches()
            URLCache.shared.removeAllCachedResponses()
            clearTextureCaches()
            NodePool.shared.clearAllPools()
            memoryCache.removeAllObjects()
            clearTemporaryData()
            
            // Force garbage collection multiple times
            for _ in 0..<3 {
                autoreleasepool {
                    clearAllCaches()
                    memoryCache.removeAllObjects()
                }
            }
        }
        
        log("[MemorySystem] Emergency cleanup completed")
    }
    
    /// Ultra-aggressive memory cleanup for thermal emergency situations
    func performThermalEmergencyCleanup() {
        log("[MemorySystem] Starting thermal emergency cleanup")
        
        // Stop all monitoring immediately
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Clear all caches immediately
        clearAllCaches()
        memoryCache.removeAllObjects()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear texture caches
        Task {
            await SKTexture.preload([])
            await SKTextureAtlas.preloadTextureAtlases([])
        }
        
        // Clear node pools
        NodePool.shared.clearAllPools()
        
        // Clear temporary data
        clearTemporaryData()
        
        // Force garbage collection multiple times
        for _ in 0..<5 {
            autoreleasepool {
                clearAllCaches()
                memoryCache.removeAllObjects()
                URLCache.shared.removeAllCachedResponses()
            }
        }
        
        // Clear all tracked objects in memory leak detector
        MemoryLeakDetector.shared.performEmergencyCleanup()
        
        // Restart minimal monitoring only
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in // Very infrequent - 5 minutes
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.checkAndHandleMemoryStatus()
            }
        }
        
        log("[MemorySystem] Thermal emergency cleanup completed")
    }
    
    /// Set debug logging enabled/disabled for thermal emergency mode
    func setDebugLoggingEnabled(_ enabled: Bool) {
        isDebugLoggingEnabled = enabled
    }
    
    /// Immediate memory cleanup for critical situations
    func performImmediateCleanup() {
        log("[MemorySystem] Performing immediate cleanup")
        
        // Stop all monitoring timers temporarily
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Clear all caches immediately
        clearAllCaches()
        memoryCache.removeAllObjects()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear texture caches
        Task {
            await SKTexture.preload([])
            await SKTextureAtlas.preloadTextureAtlases([])
        }
        
        // Clear node pools
        NodePool.shared.clearAllPools()
        
        // Clear temporary data
        clearTemporaryData()
        
        // Restart monitoring after cleanup
        startMemoryMonitoring()
        
        log("[MemorySystem] Immediate cleanup completed")
    }
    
    private func performCleanup() async {
        let deviceSimulator = DeviceSimulator.shared
        let isLowEnd = deviceSimulator.isLowEndDevice()
        
        #if DEBUG
        log("[MemorySystem] Starting normal cleanup")
        if deviceSimulator.isRunningInSimulator() {
            log("[MemorySystem] Simulated device: \(deviceSimulator.getCurrentDeviceModel())")
        }
        #endif
        
        let startTime = Date()
        let initialMemory = getMemoryUsage()
        
        // Move heavy operations to background queue
        await withTaskGroup(of: Void.self) { group in
            // Background task for URL cache cleanup (heavy I/O)
            group.addTask {
                Task.detached(priority: .background) {
                    URLCache.shared.removeAllCachedResponses()
                }
            }
            
            // Background task for temporary file cleanup (disk I/O)
            group.addTask {
                Task.detached(priority: .background) {
                    await self.cleanupTemporaryFiles()
                }
            }
            
            // Background task for texture cleanup (GPU operations)
            group.addTask {
                Task.detached(priority: .background) {
                    await SKTextureAtlas.preloadTextureAtlases([])
                }
            }
            
            // Background task for image cache cleanup
            group.addTask {
                Task.detached(priority: .background) {
                    await UIImageView.clearOldImageCache()
                }
            }
            
            // Additional cleanup for low-end devices in simulator
            if deviceSimulator.isRunningInSimulator() && isLowEnd {
                group.addTask {
                    Task.detached(priority: .background) {
                        await BlockShapeView.clearCache()
                    }
                }
            }
        }
        
        let endTime = Date()
        let finalMemory = getMemoryUsage()
        let memoryReduction = initialMemory.used - finalMemory.used
        
        #if DEBUG
        log("[MemorySystem] Normal cleanup completed in \(String(format: "%.2f", endTime.timeIntervalSince(startTime)))s")
        log("[MemorySystem] Memory reduced by \(String(format: "%.1f", memoryReduction))MB")
        logMemoryUsage()
        #endif
    }
    
    // New method for background temporary file cleanup
    private func cleanupTemporaryFiles() async {
        let tmp = FileManager.default.temporaryDirectory
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: tmp,
                includingPropertiesForKeys: [.creationDateKey]
            )
            
            var removedCount = 0
            for file in files {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < thirtyMinutesAgo {
                    try? FileManager.default.removeItem(at: file)
                    removedCount += 1
                }
            }
            
            #if DEBUG
            if removedCount > 0 {
                log("[MemorySystem] Removed \(removedCount) old temporary files")
            }
            #endif
        } catch {
            #if DEBUG
            log("[MemorySystem] Error cleaning temporary files: \(error)")
            #endif
        }
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
        Task {
            BlockShapeView.clearCache()
        }
        cacheHits = 0
        cacheMisses = 0
    }
    
    // MARK: - Texture Cache Management
    private func clearTextureCaches() {
        log("[MemorySystem] Clearing texture caches")
        
        // Clear SpriteKit texture caches
        Task {
            await SKTexture.preload([])
            await SKTextureAtlas.preloadTextureAtlases([])
        }
        
        // Clear any custom texture caches
        Task {
            BlockShapeView.clearCache()
        }
        
        log("[MemorySystem] Texture caches cleared")
    }
    
    // MARK: - Temporary Data Management
    private func clearTemporaryData() {
        log("[MemorySystem] Clearing temporary data")
        
        // Clear temporary files
        removeTemporaryFiles()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any other temporary data
        Task {
            UIImageView.clearOldImageCache()
        }
        
        log("[MemorySystem] Temporary data cleared")
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
        guard isDebugLoggingEnabled else { return }
        print(message)
    }
    
    private func logMemoryUsage() {
        let (used, total) = getMemoryUsage()
        let ratio = used / total
        let status = checkMemoryStatus()
        let deviceSimulator = DeviceSimulator.shared
        
        #if DEBUG
        log("[MemorySystem] Memory Status: \(status)")
        log("[MemorySystem] Memory Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", ratio * 100))%)")
        log("[MemorySystem] Cache Stats - Hits: \(cacheHits), Misses: \(cacheMisses), Hit Ratio: \(String(format: "%.1f", Double(cacheHits) / Double(max(1, cacheHits + cacheMisses)) * 100))%")
        
        if deviceSimulator.isRunningInSimulator() {
            log("[MemorySystem] Simulated Device: \(deviceSimulator.getCurrentDeviceModel())")
            log("[MemorySystem] Low-end Device: \(deviceSimulator.isLowEndDevice())")
            log("[MemorySystem] Simulated Memory Pressure: \(String(format: "%.1f", deviceSimulator.getSimulatedMemoryPressure() * 100))%")
            log("[MemorySystem] Simulated Thermal Throttling: \(String(format: "%.1f", deviceSimulator.getSimulatedThermalThrottling() * 100))%")
        }
        #else
        // In production, only log critical memory issues
        if status == .critical || ratio > 0.8 {
            log("[MemorySystem] Memory Status: \(status)")
            log("[MemorySystem] Memory Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", ratio * 100))%)")
        }
        #endif
    }
    
    deinit {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        pressureSource.cancel()
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
    
    // MARK: - Private Properties
    private var isDebugLoggingEnabled: Bool = true
    
    /// Get memory statistics for diagnostics
    func getMemoryStats() -> String {
        let (used, total) = getMemoryUsage()
        let ratio = used / total
        let status = checkMemoryStatus()
        
        return """
        Memory Stats:
        - Used: \(String(format: "%.1f", used))MB
        - Total: \(String(format: "%.1f", total))MB
        - Ratio: \(String(format: "%.1f", ratio * 100))%
        - Status: \(status)
        - Cache Hits: \(cacheHits)
        - Cache Misses: \(cacheMisses)
        """
    }
}
