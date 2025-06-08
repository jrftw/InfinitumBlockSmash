import Foundation
import QuartzCore
import UIKit

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 // Update FPS every second
    
    @Published private(set) var currentFPS: Double = 0
    @Published private(set) var memoryUsage: Double = 0
    @Published private(set) var performanceMetrics: [String: Double] = [:]
    @Published private(set) var fpsHistory: [Double] = []
    
    private let maxHistorySize = 100 // Keep last 100 FPS readings
    
    private init() {
        setupDisplayLink()
        startMemoryMonitoring()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .default)
    }
    
    private func startMemoryMonitoring() {
        // Start periodic memory monitoring
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    private func updateMemoryUsage() {
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
            memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
            performanceMetrics["memory"] = memoryUsage
        }
    }
    
    @objc private func updateFPS() {
        let currentTime = CACurrentMediaTime()
        frameCount += 1
        
        if currentTime - lastFPSUpdate >= updateInterval {
            currentFPS = Double(frameCount) / (currentTime - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = currentTime
            
            // Update FPS history
            fpsHistory.append(currentFPS)
            if fpsHistory.count > maxHistorySize {
                fpsHistory.removeFirst()
            }
            
            // Update performance metrics
            performanceMetrics["fps"] = currentFPS
        }
    }
    
    deinit {
        displayLink?.invalidate()
    }
} 