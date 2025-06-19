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
    @Published private(set) var frameTime: Double = 0
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var networkLatency: Double = 0
    @Published private(set) var inputLatency: Double = 0
    
    private let maxHistorySize = 100 // Keep last 100 FPS readings
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var lastInputTimestamp: CFTimeInterval = 0
    private var processInfo: ProcessInfo { ProcessInfo.processInfo }
    
    // Timer properties for proper cleanup
    private var memoryTimer: Timer?
    private var cpuTimer: Timer?
    private var networkTimer: Timer?
    
    private init() {
        setupDisplayLink()
        startMemoryMonitoring()
        startCPUMonitoring()
        startNetworkMonitoring()
    }
    
    deinit {
        stopAllTimers()
        displayLink?.invalidate()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .default)
    }
    
    private func startMemoryMonitoring() {
        // Start periodic memory monitoring
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    private func startCPUMonitoring() {
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
        }
    }
    
    private func startNetworkMonitoring() {
        networkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNetworkLatency()
        }
    }
    
    private func stopAllTimers() {
        memoryTimer?.invalidate()
        memoryTimer = nil
        cpuTimer?.invalidate()
        cpuTimer = nil
        networkTimer?.invalidate()
        networkTimer = nil
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
    
    private func updateCPUUsage() {
        var cpuInfo = processor_info_array_t?(nil)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        var totalUsage: Double = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &cpuInfo,
                                       &numCpuInfo)
        
        if result == KERN_SUCCESS {
            let cpuInfoArray = UnsafeBufferPointer(start: cpuInfo, count: Int(numCpuInfo))
            let cpuInfoArraySize = Int(numCpuInfo) / Int(numCpus)
            
            for i in 0..<Int(numCpus) {
                let offset = i * cpuInfoArraySize
                let user = Double(cpuInfoArray[offset + Int(CPU_STATE_USER)])
                let system = Double(cpuInfoArray[offset + Int(CPU_STATE_SYSTEM)])
                let idle = Double(cpuInfoArray[offset + Int(CPU_STATE_IDLE)])
                let total = user + system + idle
                
                if total > 0 {
                    totalUsage += ((user + system) / total) * 100.0
                }
            }
            
            cpuUsage = totalUsage / Double(numCpus)
            performanceMetrics["cpu"] = cpuUsage
        }
        
        if let cpuInfo = cpuInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
    }
    
    private func updateNetworkLatency() {
        // Simulate network latency measurement
        // In a real implementation, you would ping your game server
        networkLatency = Double.random(in: 20...100)
        performanceMetrics["network_latency"] = networkLatency
    }
    
    @objc private func updateFPS() {
        let currentTime = CACurrentMediaTime()
        
        // Calculate frame time
        if lastFrameTimestamp > 0 {
            frameTime = (currentTime - lastFrameTimestamp) * 1000 // Convert to milliseconds
            performanceMetrics["frame_time"] = frameTime
        }
        lastFrameTimestamp = currentTime
        
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
    
    func recordInputEvent() {
        let currentTime = CACurrentMediaTime()
        if lastInputTimestamp > 0 {
            inputLatency = (currentTime - lastInputTimestamp) * 1000 // Convert to milliseconds
            performanceMetrics["input_latency"] = inputLatency
        }
        lastInputTimestamp = currentTime
    }
} 