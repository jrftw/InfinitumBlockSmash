import Foundation
import QuartzCore
import UIKit
import SwiftUI

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
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    
    private let maxHistorySize = 100 // Keep last 100 FPS readings
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var lastInputTimestamp: CFTimeInterval = 0
    private var processInfo: ProcessInfo { ProcessInfo.processInfo }
    
    // Timer properties for proper cleanup
    private var memoryTimer: Timer?
    private var cpuTimer: Timer?
    private var networkTimer: Timer?
    
    // Memory logging control
    private var lastLoggedMemoryLevel: MemoryLevel = .normal
    private var lastMemoryLogTime: CFTimeInterval = 0
    private let memoryLogCooldown: CFTimeInterval = 300.0 // 5 minutes between logs for same level
    
    // Memory level enum for tracking
    private enum MemoryLevel: Int {
        case normal = 0
        case elevated = 1
        case warning = 2
        case critical = 3
        case extreme = 4
        
        var threshold: Double {
            switch self {
            case .normal: return 0.0
            case .elevated: return 0.3
            case .warning: return 0.4
            case .critical: return 0.55
            case .extreme: return 0.65
            }
        }
        
        var description: String {
            switch self {
            case .normal: return "Normal"
            case .elevated: return "Elevated"
            case .warning: return "Warning"
            case .critical: return "Critical"
            case .extreme: return "Extreme"
            }
        }
    }
    
    private init() {
        setupDisplayLink()
        startMemoryMonitoring()
        startCPUMonitoring()
        startNetworkMonitoring()
        startThermalMonitoring()
        
        // Perform immediate initial updates
        updateMemoryUsage()
        updateCPUUsage()
        updateNetworkLatency()
        updateThermalState()
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
    
    private func startThermalMonitoring() {
        // Update thermal state every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateThermalState()
        }
        
        // Observe thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
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
                
                // Check if memory usage has changed significantly and should be logged
                self?.checkAndLogMemoryUsage(newMemoryUsage)
            }
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
    
    /// Manually check and log current memory usage (for debugging)
    func checkMemoryUsageNow() {
        updateMemoryUsage()
    }
    
    private func determineMemoryLevel(for usage: Double) -> MemoryLevel {
        // Get total device memory to calculate percentage
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 // Convert to MB
        let memoryPercentage = usage / totalMemory
        
        if memoryPercentage < MemoryLevel.elevated.threshold {
            return .normal
        } else if memoryPercentage < MemoryLevel.warning.threshold {
            return .elevated
        } else if memoryPercentage < MemoryLevel.critical.threshold {
            return .warning
        } else if memoryPercentage < MemoryLevel.extreme.threshold {
            return .critical
        } else {
            return .extreme
        }
    }
    
    private func checkAndLogMemoryUsage(_ usage: Double) {
        let currentTime = CACurrentMediaTime()
        let newLevel = determineMemoryLevel(for: usage)
        
        // Only log if:
        // 1. Memory level has changed to a higher level, OR
        // 2. Memory level has improved (returned to normal), OR
        // 3. We're at a concerning level (warning or higher) and enough time has passed
        let shouldLog = (newLevel != lastLoggedMemoryLevel && newLevel.rawValue > lastLoggedMemoryLevel.rawValue) ||
                       (newLevel == .normal && lastLoggedMemoryLevel != .normal) ||
                       (newLevel.rawValue >= MemoryLevel.warning.rawValue && currentTime - lastMemoryLogTime > memoryLogCooldown)
        
        if shouldLog {
            #if DEBUG
            if newLevel == .normal && lastLoggedMemoryLevel != .normal {
                print("[PerformanceMonitor] Memory usage returned to normal - \(String(format: "%.1f", usage))MB")
            } else {
                print("[PerformanceMonitor] Memory usage is \(newLevel.description) - \(String(format: "%.1f", usage))MB")
            }
            #endif
            
            lastLoggedMemoryLevel = newLevel
            lastMemoryLogTime = currentTime
        }
    }
    
    private func updateThermalState() {
        let newThermalState = ProcessInfo.processInfo.thermalState
        if newThermalState != thermalState {
            DispatchQueue.main.async { [weak self] in
                self?.thermalState = newThermalState
                self?.performanceMetrics["thermal_state"] = Double(newThermalState.rawValue)
            }
        }
    }
    
    @objc private func thermalStateDidChange() {
        updateThermalState()
    }
    
    // MARK: - Thermal State Helpers
    
    /// Get color for thermal state display
    func getThermalStateColor() -> Color {
        switch thermalState {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    /// Get description for thermal state display
    func getThermalStateDescription() -> String {
        switch thermalState {
        case .nominal:
            return "Good"
        case .fair:
            return "Mild"
        case .serious:
            return "Bad"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Get detailed temperature description
    func getDetailedTemperatureDescription() -> String {
        switch thermalState {
        case .nominal:
            return "Good (Normal)"
        case .fair:
            return "Mild (Warm)"
        case .serious:
            return "Bad (Hot)"
        case .critical:
            return "Critical (Overheating)"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Get estimated temperature in Celsius
    func getTemperatureCelsius() -> Double {
        switch thermalState {
        case .nominal:
            return 25.0 // Normal room temperature
        case .fair:
            return 35.0 // Warm
        case .serious:
            return 45.0 // Hot
        case .critical:
            return 55.0 // Very hot
        @unknown default:
            return 30.0
        }
    }
    
    /// Get estimated temperature in Fahrenheit
    func getTemperatureFahrenheit() -> Double {
        let celsius = getTemperatureCelsius()
        return (celsius * 9/5) + 32
    }
    
    /// Get temperature string based on unit preference
    func getTemperatureString(unit: String) -> String {
        let temp: Double
        let unitSymbol: String
        
        switch unit {
        case "Fahrenheit":
            temp = getTemperatureFahrenheit()
            unitSymbol = "°F"
        default: // Celsius
            temp = getTemperatureCelsius()
            unitSymbol = "°C"
        }
        
        return String(format: "~%.0f%@", temp, unitSymbol) // Added ~ to indicate estimate
    }
    
    /// Get thermal state percentage (0-100) based on thermal state
    func getThermalStatePercentage() -> Int {
        switch thermalState {
        case .nominal:
            return 25 // 0-25% range
        case .fair:
            return 50 // 26-50% range
        case .serious:
            return 75 // 51-75% range
        case .critical:
            return 100 // 76-100% range
        @unknown default:
            return 30
        }
    }
    
    /// Get thermal state percentage string
    func getThermalStatePercentageString() -> String {
        return "\(getThermalStatePercentage())%"
    }
} 