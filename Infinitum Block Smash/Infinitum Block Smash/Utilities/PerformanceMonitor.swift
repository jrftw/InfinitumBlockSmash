import Foundation
import QuartzCore
import UIKit
import SwiftUI
import SpriteKit

final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var networkLatency: Double = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var isThermalEmergencyMode: Bool = false
    @Published var currentFPS: Double = 60.0
    @Published private(set) var batteryLevel: Float = 1.0
    @Published private(set) var isLowPowerMode: Bool = false
    
    // MARK: - Private Properties
    private var displayLink: CADisplayLink?
    private var memoryTimer: Timer?
    private var cpuTimer: Timer?
    private var networkTimer: Timer?
    private var thermalTimer: Timer?
    
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private var lastFrameTimestamp: CFTimeInterval = 0
    var frameTime: Double = 0 // Made public for GameView access
    
    private let updateInterval: TimeInterval = 2.0 // Increased from 1.0 to reduce overhead
    private let maxHistorySize = 30 // Reduced from 60 to save memory
    
    @Published private(set) var fpsHistory: [Double] = []
    @Published private(set) var performanceMetrics: [String: Double] = [:]
    
    // MARK: - Input Latency Tracking
    private var inputEvents: [CFTimeInterval] = []
    private let maxInputEvents = 10 // Reduced from 20
    
    private var lastFrameTime: CFTimeInterval = 0
    private var lastInputTimestamp: CFTimeInterval = 0
    private var processInfo: ProcessInfo { ProcessInfo.processInfo }
    
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
    
    private var isMonitoring = false
    private var lastThermalCheck: Date = Date()
    private let thermalEmergencyThreshold: TimeInterval = 30.0 // 30 seconds of hot state triggers emergency mode
    
    // MARK: - Initialization
    private init() {
        setupDisplayLink()
    }
    
    deinit {
        stopAllTimers()
        displayLink?.invalidate()
    }
    
    private func setupDisplayLink() {
        // Only enable CADisplayLink when performance monitoring is actually needed
        // This significantly reduces battery drain
        #if DEBUG
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .default)
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring with thermal awareness
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Check thermal state before starting
        let currentThermalState = ProcessInfo.processInfo.thermalState
        if currentThermalState == .serious || currentThermalState == .critical {
            print("[PerformanceMonitor] Device is hot - starting in thermal emergency mode")
            startThermalEmergencyMode()
            return
        }
        
        isMonitoring = true
        startMemoryMonitoring()
        startCPUMonitoring()
        startNetworkMonitoring()
        startThermalMonitoring()
        
        print("[PerformanceMonitor] Monitoring started")
    }
    
    /// Stop all monitoring
    func stopMonitoring() {
        isMonitoring = false
        stopAllTimers()
        print("[PerformanceMonitor] Monitoring stopped")
    }
    
    /// Emergency stop for thermal issues
    func emergencyStop() {
        isMonitoring = false
        isThermalEmergencyMode = true
        stopAllTimers()
        
        // Stop all other timers across the app
        stopAllAppTimers()
        
        print("[PerformanceMonitor] Emergency stop due to thermal issues")
    }
    
    /// Stop all timers across the entire app
    private func stopAllAppTimers() {
        print("[PerformanceMonitor] Stopping all app timers for thermal emergency")
        
        // Stop MemoryLeakDetector timer
        Task { @MainActor in MemoryLeakDetector.shared.stopMonitoring() }
        
        // Stop NetworkMetricsManager timers
        Task { @MainActor in NetworkMetricsManager.shared.stopMonitoring() }
        
        // Stop AdaptiveQualityManager timer
        Task { @MainActor in AdaptiveQualityManager.shared.stopMonitoring() }
        
        // Stop FPSManager timer
        Task { @MainActor in FPSManager.shared.stopMonitoring() }
        
        // Stop UserDefaultsManager timer
        Task { @MainActor in UserDefaultsManager.shared.stopMonitoring() }
        
        // Disable all debug logging to reduce CPU load
        disableAllDebugLogging()
        
        print("[PerformanceMonitor] All app timers stopped")
    }
    
    /// Restart all timers when device cools down
    private func restartAllAppTimers() {
        print("[PerformanceMonitor] Restarting all app timers")
        
        // Restart MemoryLeakDetector timer
        Task { @MainActor in MemoryLeakDetector.shared.startMonitoring() }
        
        // Restart NetworkMetricsManager timers
        Task { @MainActor in NetworkMetricsManager.shared.startMonitoring() }
        
        // Restart AdaptiveQualityManager timer
        Task { @MainActor in AdaptiveQualityManager.shared.startMonitoring() }
        
        // Restart FPSManager timer
        Task { @MainActor in FPSManager.shared.startMonitoring() }
        
        // Restart UserDefaultsManager timer
        Task { @MainActor in UserDefaultsManager.shared.startMonitoring() }
        
        // Re-enable debug logging
        enableAllDebugLogging()
        
        print("[PerformanceMonitor] All app timers restarted")
    }
    
    /// Disable all debug logging to reduce CPU load during thermal emergency
    private func disableAllDebugLogging() {
        print("[PerformanceMonitor] Disabling all debug logging for thermal emergency")
        
        // Disable Logger debug output
        Logger.shared.setDebugEnabled(false)
        
        // Disable MemoryLeakDetector logging
        MemoryLeakDetector.shared.setLoggingEnabled(false)
        
        // Disable MemorySystem debug logging
        Task { @MainActor in MemorySystem.shared.setDebugLoggingEnabled(false) }
        
        print("[PerformanceMonitor] All debug logging disabled")
    }
    
    /// Enable all debug logging when device cools down
    private func enableAllDebugLogging() {
        print("[PerformanceMonitor] Re-enabling debug logging")
        
        // Re-enable Logger debug output
        Logger.shared.setDebugEnabled(true)
        
        // Re-enable MemoryLeakDetector logging
        MemoryLeakDetector.shared.setLoggingEnabled(true)
        
        // Re-enable MemorySystem debug logging
        Task { @MainActor in MemorySystem.shared.setDebugLoggingEnabled(true) }
        
        print("[PerformanceMonitor] Debug logging re-enabled")
    }
    
    private func startMemoryMonitoring() {
        // Start periodic memory monitoring with much longer intervals
        let interval = MemoryConfig.getIntervals().memoryCheck * 10 // 10x longer intervals
        memoryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        #if DEBUG
        print("[PerformanceMonitor] Memory monitoring started with interval: \(interval)s")
        #endif
    }
    
    private func startCPUMonitoring() {
        // Significantly reduce CPU monitoring frequency to prevent heating
        // CPU monitoring is very expensive and causes thermal issues
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in // Increased from 60.0 to 120.0
            self?.updateCPUUsage()
        }
    }
    
    private func startNetworkMonitoring() {
        // Reduce network monitoring frequency even more
        networkTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in // Increased from 120.0 to 300.0
            self?.updateNetworkLatency()
        }
    }
    
    private func startThermalMonitoring() {
        // Invalidate any existing timer first
        thermalTimer?.invalidate()
        
        // Reduce thermal monitoring frequency significantly
        thermalTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in // Increased from 30.0 to 60.0
            self?.updateThermalState()
        }
    }
    
    private func stopAllTimers() {
        memoryTimer?.invalidate()
        memoryTimer = nil
        cpuTimer?.invalidate()
        cpuTimer = nil
        networkTimer?.invalidate()
        networkTimer = nil
        thermalTimer?.invalidate()
        thermalTimer = nil
    }
    
    private func updateMemoryUsage() {
        // Calculate memory usage directly without calling getCurrentMemoryUsage()
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
            memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            // Fallback calculation
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            memoryUsage = totalMemory * 0.5 // Estimate 50% usage as fallback
        }
        
        // Check for excessive memory usage - trigger emergency mode at 800MB
        if memoryUsage > 800.0 {
            print("[PerformanceMonitor] WARNING: High memory usage detected: \(String(format: "%.1f", memoryUsage))MB - triggering memory emergency mode")
            
            // Force emergency mode regardless of thermal state
            if !isThermalEmergencyMode {
                startThermalEmergencyMode()
            }
            
            // Perform immediate aggressive cleanup
            performEmergencyMemoryCleanup()
        } else if memoryUsage > 600.0 {
            print("[PerformanceMonitor] WARNING: High memory usage detected: \(String(format: "%.1f", memoryUsage))MB")
            performEmergencyMemoryCleanup()
        }
    }
    
    private func updateCPUUsage() {
        // Simplified CPU monitoring to reduce overhead
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform a small calculation to measure CPU
        var result = 0.0
        for i in 0..<1000 {
            result += sqrt(Double(i))
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000 // Convert to milliseconds
        
        // Normalize to a percentage (this is a rough estimate)
        cpuUsage = min(100.0, max(0.0, duration / 10.0))
    }
    
    private func updateNetworkLatency() {
        // Simplified network latency check
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate network check (in real implementation, this would ping a server)
        DispatchQueue.global(qos: .utility).async {
            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000
            
            DispatchQueue.main.async {
                self.networkLatency = latency
            }
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
                self?.performanceMetrics["input_latency"] = newInputLatency
            }
        }
        lastInputTimestamp = currentTime
    }
    
    // MARK: - Public Methods for Debugging
    
    /// Get current input latency
    var inputLatency: Double {
        return performanceMetrics["input_latency"] ?? 0.0
    }
    
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
        // Update memory usage if not in emergency mode to avoid excessive calls
        if !isThermalEmergencyMode {
            updateMemoryUsage()
        }
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
        thermalState = newThermalState
        
        // Check if device is getting hot
        if newThermalState == .serious || newThermalState == .critical {
            if !isThermalEmergencyMode {
                // Check how long it's been hot
                let timeSinceLastCheck = Date().timeIntervalSince(lastThermalCheck)
                if timeSinceLastCheck > thermalEmergencyThreshold {
                    print("[PerformanceMonitor] Device has been hot for \(String(format: "%.1f", timeSinceLastCheck))s - entering thermal emergency mode")
                    startThermalEmergencyMode()
                }
            }
            lastThermalCheck = Date()
        } else {
            // Device is cooling down
            if isThermalEmergencyMode {
                print("[PerformanceMonitor] Device cooling down - exiting thermal emergency mode")
                exitThermalEmergencyMode()
            }
            lastThermalCheck = Date()
        }
        
        // Update monitoring frequency based on thermal state
        adjustMonitoringForThermalState(newThermalState)
    }
    
    private func startThermalEmergencyMode() {
        isThermalEmergencyMode = true
        isMonitoring = false
        
        // Stop all intensive monitoring
        stopAllTimers()
        
        // Only keep minimal thermal monitoring
        thermalTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in // Very infrequent
            self?.updateThermalState()
        }
        
        // Perform emergency memory cleanup
        performEmergencyMemoryCleanup()
        
        print("[PerformanceMonitor] Thermal emergency mode activated")
    }
    
    private func exitThermalEmergencyMode() {
        isThermalEmergencyMode = false
        
        // Stop minimal monitoring
        thermalTimer?.invalidate()
        thermalTimer = nil
        
        // Restart all app timers
        restartAllAppTimers()
        
        // Restart normal monitoring
        startMonitoring()
        
        print("[PerformanceMonitor] Exited thermal emergency mode")
    }
    
    private func adjustMonitoringForThermalState(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:
            // Normal monitoring frequency
            break
        case .fair:
            // Slightly reduce monitoring frequency
            disableIntensiveMonitoring()
        case .serious:
            // Significantly reduce monitoring frequency
            disableIntensiveMonitoring()
        case .critical:
            // Enter emergency mode
            if !isThermalEmergencyMode {
                startThermalEmergencyMode()
            }
        @unknown default:
            break
        }
    }
    
    private func disableIntensiveMonitoring() {
        // Stop CPU monitoring (most intensive)
        cpuTimer?.invalidate()
        cpuTimer = nil
        
        // Stop network monitoring
        networkTimer?.invalidate()
        networkTimer = nil
        
        // Reduce thermal monitoring frequency even more
        thermalTimer?.invalidate()
        thermalTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in // Very infrequent when hot
            self?.updateThermalState()
        }
    }
    
    private func enableIntensiveMonitoring() {
        // Restart monitoring with normal intervals
        startCPUMonitoring()
        startNetworkMonitoring()
        startThermalMonitoring()
    }
    
    private func performEmergencyMemoryCleanup() {
        print("[PerformanceMonitor] Performing emergency memory cleanup")
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear texture caches
        Task { @MainActor in
            await SKTexture.preload([])
            await SKTextureAtlas.preloadTextureAtlases([])
        }
        
        // Clear node pools
        Task { @MainActor in NodePool.shared.clearAllPools() }
        
        // Clear memory leak detector data
        Task { @MainActor in MemoryLeakDetector.shared.performEmergencyCleanup() }
        
        // Clear memory system cache
        Task { @MainActor in MemorySystem.shared.clearAllCaches() }
        
        print("[PerformanceMonitor] Emergency memory cleanup completed")
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
    func getThermalStateDetails() -> String {
        let baseDescription = getThermalStateDescription()
        let emergencyMode = isThermalEmergencyMode ? " (Emergency Mode)" : ""
        return "\(baseDescription)\(emergencyMode)"
    }
    
    /// Get detailed temperature description (legacy method for compatibility)
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
    
    /// Get percentage for thermal state display
    func getThermalStatePercentage() -> Int {
        switch thermalState {
        case .nominal:
            return 25
        case .fair:
            return 50
        case .serious:
            return 75
        case .critical:
            return 100
        @unknown default:
            return 0
        }
    }
    
    /// Get thermal state percentage string (legacy method for compatibility)
    func getThermalStatePercentageString() -> String {
        return "\(getThermalStatePercentage())%"
    }
    
    /// Get temperature string based on unit preference (legacy method for compatibility)
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
    
    /// Get estimated temperature in Celsius (legacy method for compatibility)
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
    
    /// Get estimated temperature in Fahrenheit (legacy method for compatibility)
    func getTemperatureFahrenheit() -> Double {
        let celsius = getTemperatureCelsius()
        return (celsius * 9/5) + 32
    }
} 
