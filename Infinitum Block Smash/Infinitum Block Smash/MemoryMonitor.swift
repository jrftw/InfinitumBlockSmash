import Foundation
import UIKit

class MemoryMonitor {
    static let shared = MemoryMonitor()
    private let warningThreshold: Double = 0.7 // 70% of available memory
    private let criticalThreshold: Double = 0.85 // 85% of available memory
    
    private init() {}
    
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
    
    func checkMemoryUsage() -> MemoryStatus {
        let (used, total) = getMemoryUsage()
        let usagePercentage = used / total
        
        if usagePercentage >= criticalThreshold {
            return .critical
        } else if usagePercentage >= warningThreshold {
            return .warning
        }
        return .normal
    }
    
    func logMemoryUsage() {
        let (used, total) = getMemoryUsage()
        let usagePercentage = (used / total) * 100
        print("[Memory] Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", usagePercentage))%)")
    }
}

enum MemoryStatus {
    case normal
    case warning
    case critical
} 