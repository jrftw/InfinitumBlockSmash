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
        
        // Perform immediate initial updates
        updateMemoryUsage()
        updateCPUUsage()
        updateNetworkLatency()
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
        // Start periodic memory monitoring with device-specific frequency
        let interval = MemoryConfig.getIntervals().memoryCheck
        memoryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        #if DEBUG
        print("[PerformanceMonitor] Memory monitoring started with interval: \(interval)s")
        #endif
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
            let newMemoryUsage = Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
            
            DispatchQueue.main.async { [weak self] in
                self?.memoryUsage = newMemoryUsage
                self?.performanceMetrics["memory"] = newMemoryUsage
            }
            
            #if DEBUG
            print("[PerformanceMonitor] Memory updated: \(String(format: "%.1f", newMemoryUsage))MB")
            #endif
        } else {
            #if DEBUG
            print("[PerformanceMonitor] Failed to get memory info: \(kr)")
            #endif
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
            
            let newCPUUsage = totalUsage / Double(numCpus)
            
            DispatchQueue.main.async { [weak self] in
                self?.cpuUsage = newCPUUsage
                self?.performanceMetrics["cpu"] = newCPUUsage
            }
        }
        
        if let cpuInfo = cpuInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
    }
    
    private func updateNetworkLatency() {
        // Simulate network latency measurement
        // In a real implementation, you would ping your game server
        let newNetworkLatency = Double.random(in: 20...100)
        
        DispatchQueue.main.async { [weak self] in
            self?.networkLatency = newNetworkLatency
            self?.performanceMetrics["network_latency"] = newNetworkLatency
        }
    }
    
    @objc private func updateFPS() {
        let currentTime = CACurrentMediaTime()
        
        // Calculate frame time
        if lastFrameTimestamp > 0 {
            let newFrameTime = (currentTime - lastFrameTimestamp) * 1000 // Convert to milliseconds
            
            DispatchQueue.main.async { [weak self] in
                self?.frameTime = newFrameTime
                self?.performanceMetrics["frame_time"] = newFrameTime
            }
        }
        lastFrameTimestamp = currentTime
        
        frameCount += 1
        
        if currentTime - lastFPSUpdate >= updateInterval {
            let newFPS = Double(frameCount) / (currentTime - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = currentTime
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Update FPS history
                self.fpsHistory.append(newFPS)
                if self.fpsHistory.count > self.maxHistorySize {
                    self.fpsHistory.removeFirst()
                }
                
                // Update performance metrics
                self.currentFPS = newFPS
                self.performanceMetrics["fps"] = newFPS
            }
        }
    }
    
    func recordInputEvent() {
        let currentTime = CACurrentMediaTime()
        if lastInputTimestamp > 0 {
            let newInputLatency = (currentTime - lastInputTimestamp) * 1000 // Convert to milliseconds
            
            DispatchQueue.main.async { [weak self] in
                self?.inputLatency = newInputLatency
                self?.performanceMetrics["input_latency"] = newInputLatency
            }
        }
        lastInputTimestamp = currentTime
    }
    
    // MARK: - Public Methods for Debugging
    
    /// Force an immediate memory usage update
    func forceMemoryUpdate() {
        updateMemoryUsage()
    }
    
    /// Force an immediate CPU usage update
    func forceCPUUpdate() {
        updateCPUUsage()
    }
    
    /// Get current memory usage with immediate update
    func getCurrentMemoryUsage() -> Double {
        updateMemoryUsage()
        return memoryUsage
    }
    
    /// Check if memory monitoring timer is running
    func isMemoryMonitoringActive() -> Bool {
        return memoryTimer?.isValid == true
    }
    
    /// Get memory monitoring interval
    func getMemoryMonitoringInterval() -> TimeInterval {
        return MemoryConfig.getIntervals().memoryCheck
    }
} 