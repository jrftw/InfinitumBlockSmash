import Foundation
import UIKit
import SpriteKit

// MARK: - Supporting Types
public enum MemoryStatus {
    case normal
    case warning
    case critical
}

@MainActor
final class MemorySystem {
    static let shared = MemorySystem()
    
    // MARK: - Properties
    private let warningThreshold: Double = 0.7 // 70% of available memory
    private let criticalThreshold: Double = 0.85 // 85% of available memory
    private var lastCleanupTime: TimeInterval = 0
    private let cleanupInterval: TimeInterval = 30.0 // Cleanup every 30 seconds
    private var activeTasks: Set<Task<Void, Never>> = []
    
    private init() {}
    
    // MARK: - Memory Monitoring
    func getMemoryUsage() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            return (usedMB, totalMB)
        }
        
        return (0, 0)
    }
    
    // MARK: - Memory Management
    func cleanupMemory() async {
        print("[MemorySystem] Starting memory cleanup")
        
        // Cancel any existing cleanup tasks
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
        
        // Create and execute cleanup task
        let task = Task {
            await performCleanup()
        }
        activeTasks.insert(task)
        
        // Wait for cleanup to complete
        _ = await task.value
    }
    
    private func performCleanup() async {
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temporary files
        let tmpDirectory = FileManager.default.temporaryDirectory
        do {
            let tmpContents = try FileManager.default.contentsOfDirectory(at: tmpDirectory, includingPropertiesForKeys: nil)
            for file in tmpContents {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("[MemorySystem] Error cleaning temporary files: \(error)")
        }
        
        // Clear SpriteKit textures
        await SKTexture.preload([])
        
        // Force garbage collection
        autoreleasepool {
            // Additional cleanup if needed
        }
        
        // Log memory usage
        logMemoryUsage()
    }
    
    // MARK: - Periodic Cleanup
    func startPeriodicCleanup() async {
        while !Task.isCancelled {
            if Date().timeIntervalSince1970 - lastCleanupTime > cleanupInterval {
                await cleanupMemory()
                lastCleanupTime = Date().timeIntervalSince1970
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Sleep for 1 second
        }
    }
    
    // MARK: - Memory Status
    func checkMemoryStatus() async -> MemoryStatus {
        let (used, total) = getMemoryUsage()
        let usagePercentage = used / total
        
        if usagePercentage >= criticalThreshold {
            await cleanupMemory()
            return .critical
        } else if usagePercentage >= warningThreshold {
            return .warning
        }
        return .normal
    }
    
    // MARK: - Logging
    func logMemoryUsage() {
        let (used, total) = getMemoryUsage()
        let usagePercentage = (used / total) * 100
        print("[MemorySystem] Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", usagePercentage))%)")
    }
} 
