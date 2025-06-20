/*
 * MemoryLeakDetector.swift
 * 
 * MEMORY LEAK DETECTION AND MONITORING
 * 
 * This utility helps identify potential memory leaks by tracking object
 * creation and destruction, monitoring memory usage patterns, and
 * providing alerts when suspicious memory growth is detected.
 * 
 * KEY FEATURES:
 * - Object lifecycle tracking
 * - Memory usage pattern analysis
 * - Leak detection alerts
 * - Performance impact monitoring
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
    private let snapshotInterval: TimeInterval = 30.0 // Take snapshot every 30 seconds
    private let maxSnapshots = 20 // Keep last 20 snapshots
    
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
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self] _ in
            self?.takeMemorySnapshot()
        }
    }
    
    private func takeMemorySnapshot() {
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
        
        // If memory grew more than 10MB in the time span, it's suspicious
        if memoryGrowth > 10.0 && timeSpan > 60.0 {
            return "Memory grew \(String(format: "%.1f", memoryGrowth))MB over \(String(format: "%.1f", timeSpan))s"
        }
        
        return nil
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
} 