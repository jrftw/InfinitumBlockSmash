/*
 * MemoryLeakDetector.swift
 * 
 * SIMPLE MEMORY LEAK DETECTION UTILITY
 * 
 * This utility provides basic memory leak detection by tracking object
 * creation and destruction. It integrates with the existing MemorySystem
 * for comprehensive memory management.
 * 
 * KEY FEATURES:
 * - Object lifecycle tracking
 * - Memory usage pattern analysis
 * - Leak detection alerts
 * - Integration with MemorySystem
 * - Debug information logging
 */

import Foundation
import UIKit
import SpriteKit

class MemoryLeakDetector {
    static let shared = MemoryLeakDetector()
    
    // MARK: - Properties
    private var trackedObjects: [String: WeakReference] = [:]
    private var memorySnapshots: [MemorySnapshot] = []
    private var lastSnapshotTime: Date = Date()
    private let snapshotInterval: TimeInterval = 60.0 // Take snapshot every 60 seconds (increased from 30)
    private let maxSnapshots = 10 // Keep last 10 snapshots (reduced from 20)
    private var monitoringTimer: Timer?
    private var isLoggingEnabled: Bool = true
    
    // MARK: - Memory Snapshot
    struct MemorySnapshot {
        let timestamp: Date
        let memoryUsage: Double
        let objectCount: Int
        let description: String
    }
    
    // MARK: - Weak Reference Wrapper
    class WeakReference {
        weak var object: AnyObject?
        let creationTime: Date
        let objectType: String
        
        init(object: AnyObject, type: String) {
            self.object = object
            self.creationTime = Date()
            self.objectType = type
        }
    }
    
    // MARK: - Initialization
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Track an object for potential memory leaks
    func trackObject(_ object: AnyObject, type: String) {
        let key = "\(type)_\(ObjectIdentifier(object))"
        trackedObjects[key] = WeakReference(object: object, type: type)
        
        // Clean up dead references
        cleanupDeadReferences()
    }
    
    /// Stop tracking an object
    func stopTracking(_ object: AnyObject, type: String) {
        let key = "\(type)_\(ObjectIdentifier(object))"
        trackedObjects.removeValue(forKey: key)
    }
    
    /// Get current memory statistics
    func getMemoryStats() -> String {
        let (used, _) = getCurrentMemoryUsage()
        let activeObjects = trackedObjects.values.filter { $0.object != nil }.count
        let deadObjects = trackedObjects.values.filter { $0.object == nil }.count
        
        return """
        Memory Stats:
        - Used: \(String(format: "%.1f", used))MB
        - Active Objects: \(activeObjects)
        - Dead References: \(deadObjects)
        - Total Tracked: \(trackedObjects.count)
        """
    }
    
    /// Check for potential memory leaks
    func checkForLeaks() -> [String] {
        var leaks: [String] = []
        
        // Check for objects that have been alive too long
        let now = Date()
        let maxLifetime: TimeInterval = 300.0 // 5 minutes
        
        for (_, weakRef) in trackedObjects {
            if weakRef.object != nil {
                let lifetime = now.timeIntervalSince(weakRef.creationTime)
                if lifetime > maxLifetime {
                    leaks.append("Potential leak: \(weakRef.objectType) alive for \(String(format: "%.1f", lifetime))s")
                }
            }
        }
        
        // Check for memory growth pattern
        if let growthPattern = analyzeMemoryGrowth() {
            leaks.append("Memory growth detected: \(growthPattern)")
        }
        
        return leaks
    }
    
    /// Emergency memory cleanup for immediate pressure situations
    func performEmergencyCleanup() {
        Logger.shared.log("Performing emergency memory cleanup", category: .systemMemory, level: .warning)
        
        // Clear all tracked objects
        trackedObjects.removeAll()
        
        // Clear memory snapshots
        memorySnapshots.removeAll()
        
        // Force garbage collection
        autoreleasepool {
            // Clear any cached data
            URLCache.shared.removeAllCachedResponses()
        }
        
        Logger.shared.log("Emergency memory cleanup completed", category: .systemMemory, level: .info)
    }
    
    /// Stop monitoring (for thermal emergency mode)
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        print("[MemoryLeakDetector] Monitoring stopped")
    }
    
    /// Start monitoring (for thermal emergency mode)
    func startMonitoring() {
        stopMonitoring() // Ensure any existing timer is invalidated
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self] _ in
            self?.takeMemorySnapshot()
        }
        print("[MemoryLeakDetector] Monitoring started")
    }
    
    /// Set logging enabled/disabled for thermal emergency mode
    func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        if !enabled {
            // Clear any pending logs when disabling
            memorySnapshots.removeAll()
        }
    }
    
    /// Enhanced zombie object detection
    func detectZombieObjects() {
        Logger.shared.log("Detecting potential zombie objects", category: .systemMemory, level: .warning)
        
        // Check for objects that might be accessed after deallocation
        var zombieCount = 0
        
        for (_, weakRef) in trackedObjects {
            // Check if object is still valid
            if let obj = weakRef.object as? NSObject {
                // Check if object has been deallocated but still referenced
                // Note: We can't directly check for NSZombie in Swift, but we can check for invalid objects
                if obj.description.contains("deallocated") || obj.description.contains("zombie") {
                    zombieCount += 1
                    Logger.shared.log("ZOMBIE DETECTED: \(weakRef.objectType) - \(obj.description)", category: .systemMemory, level: .error)
                }
            }
        }
        
        if zombieCount > 0 {
            Logger.shared.log("Found \(zombieCount) potential zombie objects", category: .systemMemory, level: .error)
            performEmergencyCleanup()
        } else {
            Logger.shared.log("No zombie objects detected", category: .systemMemory, level: .info)
        }
    }
    
    /// Check for strong reference cycles in closures
    func detectStrongReferenceCycles() {
        Logger.shared.log("Detecting strong reference cycles", category: .systemMemory, level: .warning)
        
        // Check for common strong reference cycle patterns
        var cycleCount = 0
        
        // Check timer closures
        for (_, weakRef) in trackedObjects {
            if weakRef.objectType.contains("Timer") {
                // Timers are common sources of strong reference cycles
                cycleCount += 1
                Logger.shared.log("Potential timer cycle: \(weakRef.objectType) - \(weakRef.object?.description ?? "unknown")", category: .systemMemory, level: .warning)
            }
        }
        
        // Check notification observers
        for (_, weakRef) in trackedObjects {
            if weakRef.objectType.contains("Observer") || weakRef.objectType.contains("Notification") {
                cycleCount += 1
                Logger.shared.log("Potential notification cycle: \(weakRef.objectType) - \(weakRef.object?.description ?? "unknown")", category: .systemMemory, level: .warning)
            }
        }
        
        if cycleCount > 0 {
            Logger.shared.log("Found \(cycleCount) potential strong reference cycles", category: .systemMemory, level: .warning)
        } else {
            Logger.shared.log("No strong reference cycles detected", category: .systemMemory, level: .info)
        }
    }
    
    /// Comprehensive memory leak detection including zombie objects
    func performComprehensiveLeakDetection() {
        Logger.shared.log("Performing comprehensive memory leak detection", category: .systemMemory, level: .info)
        
        // Detect zombie objects
        detectZombieObjects()
        
        // Detect strong reference cycles
        detectStrongReferenceCycles()
        
        // Perform regular leak detection
        takeMemorySnapshot()
        
        // Check for unmanaged timers
        detectUnmanagedTimers()
    }
    
    /// Detect unmanaged timers that might cause leaks
    func detectUnmanagedTimers() {
        Logger.shared.log("Detecting unmanaged timers", category: .systemMemory, level: .warning)
        
        var unmanagedTimerCount = 0
        
        for (_, weakRef) in trackedObjects {
            if weakRef.objectType.contains("Timer") {
                if let timer = weakRef.object as? Timer {
                    // Check if timer is still valid and running
                    if timer.isValid {
                        unmanagedTimerCount += 1
                        Logger.shared.log("Unmanaged timer detected: \(weakRef.objectType) - \(timer.description)", category: .systemMemory, level: .warning)
                    }
                }
            }
        }
        
        if unmanagedTimerCount > 0 {
            Logger.shared.log("Found \(unmanagedTimerCount) unmanaged timers", category: .systemMemory, level: .warning)
        } else {
            Logger.shared.log("No unmanaged timers detected", category: .systemMemory, level: .info)
        }
    }
    
    // MARK: - Private Methods
    
    private func takeMemorySnapshot() {
        guard isLoggingEnabled else { return }
        
        let (used, _) = getCurrentMemoryUsage()
        let activeObjects = trackedObjects.values.filter { $0.object != nil }.count
        
        let snapshot = MemorySnapshot(
            timestamp: Date(),
            memoryUsage: used,
            objectCount: activeObjects,
            description: "Periodic snapshot"
        )
        
        memorySnapshots.append(snapshot)
        
        // Keep only recent snapshots
        if memorySnapshots.count > maxSnapshots {
            memorySnapshots.removeFirst()
        }
        
        // Check for suspicious patterns
        if let pattern = analyzeMemoryGrowth() {
            Logger.shared.log("Memory leak detector: \(pattern)", category: .systemMemory, level: .warning)
        }
    }
    
    private func cleanupDeadReferences() {
        let beforeCount = trackedObjects.count
        trackedObjects = trackedObjects.filter { $0.value.object != nil }
        let afterCount = trackedObjects.count
        
        if beforeCount != afterCount {
            Logger.shared.debug("Cleaned up \(beforeCount - afterCount) dead references", category: .systemMemory)
        }
    }
    
    private func getCurrentMemoryUsage() -> (used: Double, total: Double) {
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
        
        // Fallback
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        let used = total * 0.5
        return (used, total)
    }
    
    private func analyzeMemoryGrowth() -> String? {
        guard memorySnapshots.count >= 3 else { return nil }
        
        let recentSnapshots = Array(memorySnapshots.suffix(3))
        let memoryGrowth = recentSnapshots.last!.memoryUsage - recentSnapshots.first!.memoryUsage
        let timeSpan = recentSnapshots.last!.timestamp.timeIntervalSince(recentSnapshots.first!.timestamp)
        
        // If memory grew more than 5MB in the time span, it's suspicious (reduced from 10MB)
        if memoryGrowth > 5.0 && timeSpan > 60.0 {
            return "Memory grew \(String(format: "%.1f", memoryGrowth))MB over \(String(format: "%.1f", timeSpan))s"
        }
        
        return nil
    }
    
    deinit {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
}

// MARK: - Convenience Extensions

extension MemoryLeakDetector {
    /// Track a GameScene object
    func trackGameScene(_ scene: GameScene) {
        trackObject(scene, type: "GameScene")
    }
    
    /// Track a GameState object
    func trackGameState(_ state: GameState) {
        trackObject(state, type: "GameState")
    }
    
    /// Track a particle emitter
    func trackParticleEmitter(_ emitter: SKEmitterNode) {
        trackObject(emitter, type: "SKEmitterNode")
    }
    
    /// Track a timer
    func trackTimer(_ timer: Timer, type: String) {
        trackObject(timer, type: "Timer_\(type)")
    }
    
    /// Stop tracking a timer
    func stopTrackingTimer(_ timer: Timer, type: String) {
        stopTracking(timer, type: "Timer_\(type)")
    }
} 
