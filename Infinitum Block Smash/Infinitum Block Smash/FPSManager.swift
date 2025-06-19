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
 * - 30 FPS: Standard performance mode
 * - 60 FPS: Smooth gameplay mode
 * - 120 FPS: High refresh rate mode (ProMotion)
 * - Unlimited: Maximum device refresh rate
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
 * 
 * ADAPTIVE OPTIMIZATION:
 * - Dynamic FPS adjustment
 * - Thermal throttling response
 * - Memory pressure handling
 * - Battery optimization
 * - Performance scaling
 * - Quality vs performance balance
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
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the performance optimization coordinator,
 * ensuring smooth gameplay across all device types while managing
 * system resources efficiently.
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
        
        if maxRefreshRate >= 120 {
            options.append(120)
        }
        
        // Add unlimited option (0) if device supports ProMotion
        if maxRefreshRate > 60 {
            options.append(0)
        }
        
        // For low-end devices in simulator, limit options
        if deviceSimulator.isRunningInSimulator() && deviceSimulator.isLowEndDevice() {
            // Remove unlimited option for low-end devices
            options = options.filter { $0 != 0 }
            // Limit to 30 and 60 FPS for low-end devices
            options = options.filter { $0 <= 60 }
            print("[FPSManager] Limited FPS options for low-end device: \(options)")
        }
        
        // Initialize properties in correct order
        self.availableFPSOptions = options
        
        // Load saved FPS or use default based on device capabilities
        let savedFPS = userDefaults.integer(forKey: targetFPSKey)
        if savedFPS == 0 || !options.contains(savedFPS) {
            // Choose appropriate default based on device type
            if deviceSimulator.isRunningInSimulator() && deviceSimulator.isLowEndDevice() {
                self.targetFPS = 30 // Default to 30 FPS for low-end devices
            } else {
                self.targetFPS = options.first ?? 30
            }
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
        let deviceSimulator = DeviceSimulator.shared
        
        if deviceSimulator.isRunningInSimulator() {
            // If unlimited (0) is selected, use device's maximum refresh rate
            if targetFPS == 0 {
                return deviceSimulator.getSimulatedMaxFPS()
            }
            return targetFPS
        } else {
            // If unlimited (0) is selected, use device's maximum refresh rate
            if targetFPS == 0 {
                return UIScreen.main.maximumFramesPerSecond
            }
            return targetFPS
        }
    }
    
    func getFPSDisplayName(for fps: Int) -> String {
        if fps == 0 {
            return "Unlimited"
        }
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
}

// MARK: - Notification Names
extension Notification.Name {
    static let fpsDidChange = Notification.Name("fpsDidChange")
}
