/*
 * FPSManager.swift
 * 
 * PERFORMANCE OPTIMIZATION AND FRAME RATE MANAGEMENT
 * 
 * This service manages frame rate settings, performance monitoring, and device-specific
 * optimization for the Infinitum Block Smash game. It provides intelligent FPS control
 * based on device capabilities, thermal conditions, and user preferences.
 * 
 * KEY RESPONSIBILITIES:
 * - Frame rate target management and control
 * - Device capability detection and optimization
 * - Real-time FPS monitoring and tracking
 * - Performance-based FPS adjustment
 * - Thermal throttling detection and response
 * - Memory pressure monitoring
 * - Device simulation support for testing
 * - Battery optimization and power management
 * - Performance analytics and reporting
 * - Adaptive performance scaling
 * - Thermal state monitoring and response
 * - Battery level awareness and optimization
 * 
 * MAJOR DEPENDENCIES:
 * - DeviceSimulator.swift: Device simulation and testing
 * - GameScene.swift: SpriteKit scene performance
 * - GameState.swift: Game performance state
 * - SettingsView.swift: FPS configuration interface
 * - PerformanceMonitor.swift: System performance tracking
 * - UIKit: Device capability detection
 * - SpriteKit: Game rendering performance
 * 
 * FPS OPTIONS:
 * - 30 FPS: Standard performance mode (default)
 * - 60 FPS: Smooth gameplay mode
 * - Adaptive: Dynamic FPS based on conditions
 * 
 * DEVICE CAPABILITIES:
 * - Maximum refresh rate detection
 * - ProMotion display support
 * - Device performance classification
 * - Memory capacity assessment
 * - Thermal management capabilities
 * - Battery optimization features
 * 
 * PERFORMANCE MONITORING:
 * - Real-time FPS tracking
 * - Frame time analysis
 * - Performance degradation detection
 * - Thermal throttling monitoring
 * - Memory pressure assessment
 * - Battery level consideration
 * - Thermal state monitoring
 * 
 * ADAPTIVE OPTIMIZATION:
 * - Dynamic FPS adjustment
 * - Thermal throttling response
 * - Memory pressure handling
 * - Battery optimization
 * - Performance scaling
 * - Quality vs performance balance
 * - Thermal state-based adjustments
 * 
 * DEVICE SIMULATION:
 * - Simulated device capabilities
 * - Performance testing support
 * - Low-end device simulation
 * - Thermal throttling simulation
 * - Memory pressure simulation
 * - Cross-device testing
 * 
 * BATTERY OPTIMIZATION:
 * - Power consumption monitoring
 * - Battery level awareness
 * - Low power mode detection
 * - Adaptive performance scaling
 * - Energy-efficient rendering
 * - Background performance management
 * 
 * THERMAL MANAGEMENT:
 * - Thermal state monitoring
 * - Throttling detection
 * - Performance degradation response
 * - Cooling optimization
 * - Thermal warning systems
 * - Proactive performance adjustment
 * - Real-time thermal state tracking
 * 
 * MEMORY MANAGEMENT:
 * - Memory pressure monitoring
 * - Memory usage optimization
 * - Cache management
 * - Resource cleanup
 * - Memory warning response
 * - Efficient resource allocation
 * 
 * USER EXPERIENCE:
 * - Smooth gameplay at all FPS levels
 * - Consistent performance across devices
 * - Battery life optimization
 * - Thermal management transparency
 * - Performance customization options
 * - Adaptive quality settings
 * - Proactive overheating prevention
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the performance optimization coordinator,
 * ensuring smooth gameplay across all device types while managing
 * system resources efficiently and preventing device overheating.
 * 
 * THREADING CONSIDERATIONS:
 * - Real-time performance monitoring
 * - Background optimization tasks
 * - Thread-safe FPS management
 * - Efficient notification handling
 * 
 * INTEGRATION POINTS:
 * - Game rendering system
 * - Device capability detection
 * - Performance monitoring
 * - Settings management
 * - Analytics and tracking
 * - System resource management
 * - Thermal state monitoring
 */

import Foundation
import UIKit
import SpriteKit
import Combine

class FPSManager: ObservableObject {
    static let shared = FPSManager()
    
    private let userDefaults = UserDefaults.standard
    private let targetFPSKey = "targetFPS"
    
    // Available FPS options based on device capabilities
    @Published private(set) var availableFPSOptions: [Int]
    
    // Current target FPS
    @Published private(set) var targetFPS: Int
    
    // Real-time FPS tracking
    private var frameTimes: [CFTimeInterval] = []
    private let maxFrameTimeHistory = 60 // Keep last 60 frames for calculation
    private var lastFrameTime: CFTimeInterval = 0
    @Published private(set) var currentFPS: Int = 0
    
    // Thermal and battery monitoring
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var batteryLevel: Float = 1.0
    @Published private(set) var isLowPowerMode: Bool = false
    @Published private(set) var shouldReducePerformance: Bool = false
    
    // Performance monitoring timer
    private var performanceTimer: Timer?
    
    private init() {
        // Get device's maximum refresh rate with simulation support
        let deviceSimulator = DeviceSimulator.shared
        let maxRefreshRate: Int
        
        if deviceSimulator.isRunningInSimulator() {
            // Use simulated device's max FPS
            maxRefreshRate = deviceSimulator.getSimulatedMaxFPS()
            print("[FPSManager] Running in simulator mode with max FPS: \(maxRefreshRate)")
        } else {
            // Use real device's maximum refresh rate
            maxRefreshRate = UIScreen.main.maximumFramesPerSecond
            print("[FPSManager] Running on real device with max FPS: \(maxRefreshRate)")
        }
        
        // Build available FPS options based on device capabilities
        var options: [Int] = [30] // 30 FPS is always available
        
        if maxRefreshRate >= 60 {
            options.append(60)
        }
        
        // Remove 120 FPS and unlimited options for all devices
        // Only keep 30 and 60 FPS options
        
        // For low-end devices in simulator, limit options
        if deviceSimulator.isRunningInSimulator() && deviceSimulator.isLowEndDevice() {
            // Limit to 30 FPS only for low-end devices
            options = [30]
            print("[FPSManager] Limited FPS options for low-end device: \(options)")
        }
        
        // Initialize properties in correct order
        self.availableFPSOptions = options
        
        // Load saved FPS or use default based on device capabilities
        let savedFPS = userDefaults.integer(forKey: targetFPSKey)
        
        // Migrate old FPS settings (120 FPS or unlimited) to 30 FPS
        if savedFPS == 120 || savedFPS == 0 {
            print("[FPSManager] Migrating old FPS setting \(savedFPS) to 30 FPS")
            userDefaults.set(30, forKey: targetFPSKey)
            userDefaults.synchronize()
            self.targetFPS = 30
        } else if savedFPS == 0 || !options.contains(savedFPS) {
            // Always default to 30 FPS for all devices
            self.targetFPS = 30
        } else {
            self.targetFPS = savedFPS
        }
        
        // Log device simulation status
        if deviceSimulator.isRunningInSimulator() {
            print("[FPSManager] Simulated device: \(deviceSimulator.getCurrentDeviceModel())")
            print("[FPSManager] Low-end device: \(deviceSimulator.isLowEndDevice())")
            print("[FPSManager] Available FPS options: \(availableFPSOptions)")
            print("[FPSManager] Target FPS: \(targetFPS)")
        }
        
        // Start thermal and battery monitoring
        startThermalAndBatteryMonitoring()
    }
    
    deinit {
        performanceTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Thermal and Battery Monitoring
    
    private func startThermalAndBatteryMonitoring() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Initial state
        updateThermalState()
        updateBatteryState()
        
        // Start periodic monitoring - significantly reduced frequency to prevent heating
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in // Increased from 5.0 to 15.0
            self?.updateThermalState()
            self?.updateBatteryState()
            self?.updatePerformanceRecommendations()
        }
        
        // Observe thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        
        // Observe battery state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        // Observe low power mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    private func updateThermalState() {
        let newThermalState = ProcessInfo.processInfo.thermalState
        if newThermalState != thermalState {
            thermalState = newThermalState
            print("[FPSManager] Thermal state changed to: \(thermalStateDescription(newThermalState))")
            
            // Adjust monitoring frequency based on thermal state
            adjustMonitoringForThermalState(newThermalState)
        }
    }
    
    private func adjustMonitoringForThermalState(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .serious, .critical:
            // Reduce monitoring frequency when hot
            performanceTimer?.invalidate()
            performanceTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in // Very infrequent when hot
                self?.updateThermalState()
                self?.updateBatteryState()
                self?.updatePerformanceRecommendations()
            }
            print("[FPSManager] Reduced monitoring frequency due to thermal state: \(state)")
        case .nominal, .fair:
            // Normal monitoring frequency
            performanceTimer?.invalidate()
            performanceTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                self?.updateThermalState()
                self?.updateBatteryState()
                self?.updatePerformanceRecommendations()
            }
            print("[FPSManager] Normal monitoring frequency restored")
        @unknown default:
            break
        }
    }
    
    private func updateBatteryState() {
        let newBatteryLevel = UIDevice.current.batteryLevel
        if newBatteryLevel != batteryLevel {
            batteryLevel = newBatteryLevel
            print("[FPSManager] Battery level: \(Int(batteryLevel * 100))%")
        }
        
        let newLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        if newLowPowerMode != isLowPowerMode {
            isLowPowerMode = newLowPowerMode
            print("[FPSManager] Low power mode: \(newLowPowerMode)")
        }
    }
    
    private func updatePerformanceRecommendations() {
        let shouldReduce = shouldReducePerformanceForThermalOrBattery()
        if shouldReduce != shouldReducePerformance {
            shouldReducePerformance = shouldReduce
            if shouldReduce {
                print("[FPSManager] Performance reduction recommended due to thermal/battery conditions")
            } else {
                print("[FPSManager] Performance reduction no longer needed")
            }
        }
    }
    
    @objc private func thermalStateDidChange() {
        updateThermalState()
        updatePerformanceRecommendations()
    }
    
    @objc private func batteryStateDidChange() {
        updateBatteryState()
        updatePerformanceRecommendations()
    }
    
    @objc private func lowPowerModeDidChange() {
        updateBatteryState()
        updatePerformanceRecommendations()
    }
    
    func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    // MARK: - Performance Reduction Logic
    
    private func shouldReducePerformanceForThermalOrBattery() -> Bool {
        // Reduce performance for serious or critical thermal state
        if thermalState == .serious || thermalState == .critical {
            return true
        }
        
        // Reduce performance for low battery
        if batteryLevel < 0.2 { // Below 20%
            return true
        }
        
        // Reduce performance in low power mode
        if isLowPowerMode {
            return true
        }
        
        return false
    }
    
    func setTargetFPS(_ fps: Int) {
        // Only set if it's a valid option
        if availableFPSOptions.contains(fps) {
            targetFPS = fps
            userDefaults.set(fps, forKey: targetFPSKey)
            userDefaults.synchronize()
            
            // Notify any observers that FPS has changed
            NotificationCenter.default.post(name: .fpsDidChange, object: nil, userInfo: ["fps": fps])
            
            // Log FPS change
            let deviceSimulator = DeviceSimulator.shared
            if deviceSimulator.isRunningInSimulator() {
                print("[FPSManager] FPS changed to \(fps) on simulated device: \(deviceSimulator.getCurrentDeviceModel())")
            }
        }
    }
    
    func getDisplayFPS(for targetFPS: Int) -> Int {
        // Simply return the target FPS since we no longer support unlimited
        return targetFPS
    }
    
    func getFPSDisplayName(for fps: Int) -> String {
        return "\(fps) FPS"
    }
    
    // MARK: - Real-time FPS Tracking
    
    func updateFrameTime() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimes.append(frameTime)
            
            // Keep only the last N frame times
            if frameTimes.count > maxFrameTimeHistory {
                frameTimes.removeFirst()
            }
            
            // Calculate average FPS
            if !frameTimes.isEmpty {
                let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                currentFPS = Int(round(1.0 / averageFrameTime))
            }
        }
        
        lastFrameTime = currentTime
    }
    
    // MARK: - Device Simulation Support
    
    /// Get the effective FPS considering device simulation constraints
    func getEffectiveFPS() -> Int {
        let deviceSimulator = DeviceSimulator.shared
        
        if deviceSimulator.isRunningInSimulator() {
            let displayFPS = getDisplayFPS(for: targetFPS)
            
            // Apply thermal throttling simulation
            let thermalThrottling = deviceSimulator.getSimulatedThermalThrottling()
            if thermalThrottling > 0.7 { // If thermal throttling is high
                // Reduce FPS by up to 50% for low-end devices, 30% for others
                let reductionFactor = deviceSimulator.isLowEndDevice() ? 0.5 : 0.7
                let throttledFPS = Double(displayFPS) * reductionFactor
                return Int(throttledFPS)
            }
            
            return displayFPS
        } else {
            return getDisplayFPS(for: targetFPS)
        }
    }
    
    /// Check if FPS should be limited due to device constraints
    func shouldLimitFPS() -> Bool {
        let deviceSimulator = DeviceSimulator.shared
        
        if deviceSimulator.isRunningInSimulator() {
            // Check memory pressure
            let memoryPressure = deviceSimulator.getSimulatedMemoryPressure()
            if memoryPressure > 0.8 {
                return true
            }
            
            // Check thermal throttling
            let thermalThrottling = deviceSimulator.getSimulatedThermalThrottling()
            if thermalThrottling > 0.6 {
                return true
            }
            
            // Low-end devices should always limit FPS
            if deviceSimulator.isLowEndDevice() {
                return true
            }
        }
        
        return false
    }
    
    /// Get recommended FPS for current device conditions
    func getRecommendedFPS() -> Int {
        let deviceSimulator = DeviceSimulator.shared
        
        if deviceSimulator.isRunningInSimulator() {
            if deviceSimulator.isLowEndDevice() {
                return 30 // Always recommend 30 FPS for low-end devices
            }
            
            // Check memory pressure
            let memoryPressure = deviceSimulator.getSimulatedMemoryPressure()
            if memoryPressure > 0.8 {
                return 30 // Reduce to 30 FPS under high memory pressure
            } else if memoryPressure > 0.6 {
                return 60 // Limit to 60 FPS under moderate memory pressure
            }
            
            // Check thermal throttling
            let thermalThrottling = deviceSimulator.getSimulatedThermalThrottling()
            if thermalThrottling > 0.7 {
                return 30 // Reduce to 30 FPS under high thermal throttling
            } else if thermalThrottling > 0.5 {
                return 60 // Limit to 60 FPS under moderate thermal throttling
            }
            
            return getDisplayFPS(for: targetFPS)
        } else {
            return getDisplayFPS(for: targetFPS)
        }
    }
    
    // MARK: - Thermal and Battery Aware FPS
    
    /// Get FPS adjusted for thermal and battery conditions
    func getThermalAwareFPS() -> Int {
        let baseFPS = getDisplayFPS(for: targetFPS)
        
        // Apply thermal state adjustments
        switch thermalState {
        case .critical:
            return max(30, baseFPS / 2) // Reduce by 50%, minimum 30 FPS
        case .serious:
            return max(30, Int(Double(baseFPS) * 0.7)) // Reduce by 30%, minimum 30 FPS
        case .fair:
            return max(30, Int(Double(baseFPS) * 0.85)) // Reduce by 15%, minimum 30 FPS
        case .nominal:
            break // No reduction needed
        @unknown default:
            break
        }
        
        // Apply battery level adjustments
        if batteryLevel < 0.1 { // Below 10%
            return max(30, baseFPS / 2)
        } else if batteryLevel < 0.2 { // Below 20%
            return max(30, Int(Double(baseFPS) * 0.7))
        } else if batteryLevel < 0.3 { // Below 30%
            return max(30, Int(Double(baseFPS) * 0.85))
        }
        
        // Apply low power mode adjustment
        if isLowPowerMode {
            return max(30, Int(Double(baseFPS) * 0.8))
        }
        
        return baseFPS
    }
    
    /// Get performance recommendations based on current conditions
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        switch thermalState {
        case .critical:
            recommendations.append("Critical thermal state detected. Performance reduced to prevent overheating.")
        case .serious:
            recommendations.append("High thermal state detected. Consider reducing graphics quality.")
        case .fair:
            recommendations.append("Moderate thermal state. Monitor device temperature.")
        case .nominal:
            break
        @unknown default:
            break
        }
        
        if batteryLevel < 0.2 {
            recommendations.append("Low battery detected. Performance optimized for battery life.")
        }
        
        if isLowPowerMode {
            recommendations.append("Low power mode enabled. Performance reduced to save battery.")
        }
        
        return recommendations
    }
    
    /// Stop monitoring (for thermal emergency mode)
    func stopMonitoring() {
        performanceTimer?.invalidate()
        performanceTimer = nil
        print("[FPSManager] Monitoring stopped")
    }
    
    /// Start monitoring (for thermal emergency mode)
    func startMonitoring() {
        stopMonitoring() // Ensure any existing timer is invalidated
        
        // Start performance monitoring with reduced frequency
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in // Increased from 5.0 to 15.0
            self?.updateThermalState()
            self?.updateBatteryState()
            self?.updatePerformanceRecommendations()
        }
        
        print("[FPSManager] Monitoring started")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let fpsDidChange = Notification.Name("fpsDidChange")
}
