import Foundation
import UIKit
import Combine

// MARK: - Device Simulation Manager
@MainActor
class DeviceSimulationManager: ObservableObject {
    static let shared = DeviceSimulationManager()
    
    // MARK: - Published Properties
    @Published private(set) var isSimulatorMode: Bool = false
    @Published private(set) var currentDeviceModel: String = "Unknown"
    @Published private(set) var memoryLimit: Double = 0
    @Published private(set) var memoryPressure: Double = 0
    @Published private(set) var thermalThrottling: Double = 0
    @Published private(set) var isLowEndDevice: Bool = false
    @Published private(set) var maxFPS: Int = 60
    @Published private(set) var cpuCores: Int = 6
    
    // MARK: - Private Properties
    private let deviceSimulator = DeviceSimulator.shared
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupDeviceSimulation()
        startMonitoring()
    }
    
    private func setupDeviceSimulation() {
        isSimulatorMode = deviceSimulator.isRunningInSimulator()
        currentDeviceModel = deviceSimulator.getCurrentDeviceModel()
        memoryLimit = deviceSimulator.getSimulatedMemoryLimit()
        isLowEndDevice = deviceSimulator.isLowEndDevice()
        maxFPS = deviceSimulator.getSimulatedMaxFPS()
        cpuCores = deviceSimulator.getSimulatedCPUCores()
        
        if isSimulatorMode {
            print("[DeviceSimulationManager] Initialized in simulator mode")
            print("[DeviceSimulationManager] Device: \(currentDeviceModel)")
            print("[DeviceSimulationManager] Memory Limit: \(String(format: "%.1f", memoryLimit))MB")
            print("[DeviceSimulationManager] Low-end: \(isLowEndDevice)")
            print("[DeviceSimulationManager] Max FPS: \(maxFPS)")
            print("[DeviceSimulationManager] CPU Cores: \(cpuCores)")
        }
    }
    
    private func startMonitoring() {
        // Update metrics every second
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
    }
    
    private func updateMetrics() {
        memoryPressure = deviceSimulator.getSimulatedMemoryPressure()
        thermalThrottling = deviceSimulator.getSimulatedThermalThrottling()
    }
    
    // MARK: - Public Interface
    
    /// Get current device simulation status
    func getSimulationStatus() -> DeviceSimulationStatus {
        return DeviceSimulationStatus(
            isSimulatorMode: isSimulatorMode,
            deviceModel: currentDeviceModel,
            memoryLimit: memoryLimit,
            memoryPressure: memoryPressure,
            thermalThrottling: thermalThrottling,
            isLowEndDevice: isLowEndDevice,
            maxFPS: maxFPS,
            cpuCores: cpuCores
        )
    }
    
    /// Check if performance should be limited
    func shouldLimitPerformance() -> Bool {
        guard isSimulatorMode else { return false }
        
        // Limit performance under high memory pressure
        if memoryPressure > 0.8 {
            return true
        }
        
        // Limit performance under high thermal throttling
        if thermalThrottling > 0.7 {
            return true
        }
        
        // Always limit performance on low-end devices
        if isLowEndDevice {
            return true
        }
        
        return false
    }
    
    /// Get recommended performance settings
    func getRecommendedPerformanceSettings() -> PerformanceSettings {
        guard isSimulatorMode else {
            return PerformanceSettings(
                targetFPS: 60,
                enableParticles: true,
                enableAnimations: true,
                enableShadows: true,
                textureQuality: .high
            )
        }
        
        var targetFPS = maxFPS
        var enableParticles = true
        var enableAnimations = true
        var enableShadows = true
        var textureQuality = TextureQuality.high
        
        // Adjust based on memory pressure
        if memoryPressure > 0.8 {
            targetFPS = 30
            enableParticles = false
            enableShadows = false
            textureQuality = .medium
        } else if memoryPressure > 0.6 {
            targetFPS = min(targetFPS, 60)
            enableShadows = false
            textureQuality = .medium
        }
        
        // Adjust based on thermal throttling
        if thermalThrottling > 0.7 {
            targetFPS = 30
            enableParticles = false
            enableAnimations = false
            textureQuality = .low
        } else if thermalThrottling > 0.5 {
            targetFPS = min(targetFPS, 60)
            enableParticles = false
            textureQuality = .medium
        }
        
        // Adjust based on device type
        if isLowEndDevice {
            targetFPS = 30
            enableParticles = false
            enableShadows = false
            textureQuality = .low
        }
        
        return PerformanceSettings(
            targetFPS: targetFPS,
            enableParticles: enableParticles,
            enableAnimations: enableAnimations,
            enableShadows: enableShadows,
            textureQuality: textureQuality
        )
    }
    
    /// Get memory usage information
    func getMemoryInfo() -> MemoryInfo {
        let (used, total) = MemorySystem.shared.getMemoryUsage()
        let available = total - used
        
        return MemoryInfo(
            used: used,
            total: total,
            available: available,
            pressure: memoryPressure,
            limit: memoryLimit
        )
    }
    
    /// Get performance recommendations
    func getPerformanceRecommendations() -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        guard isSimulatorMode else { return recommendations }
        
        // Memory pressure recommendations
        if memoryPressure > 0.8 {
            recommendations.append(.init(
                type: .critical,
                title: "High Memory Pressure",
                description: "Memory usage is critically high. Consider reducing graphics quality or closing other apps.",
                action: "Reduce memory usage immediately"
            ))
        } else if memoryPressure > 0.6 {
            recommendations.append(.init(
                type: .warning,
                title: "Moderate Memory Pressure",
                description: "Memory usage is elevated. Monitor for potential performance issues.",
                action: "Consider reducing graphics quality"
            ))
        }
        
        // Thermal throttling recommendations
        if thermalThrottling > 0.7 {
            recommendations.append(.init(
                type: .critical,
                title: "High Thermal Throttling",
                description: "Device is experiencing thermal throttling. Performance may be reduced.",
                action: "Reduce graphics quality and FPS"
            ))
        } else if thermalThrottling > 0.5 {
            recommendations.append(.init(
                type: .warning,
                title: "Moderate Thermal Throttling",
                description: "Device is warming up. Performance may be affected.",
                action: "Monitor temperature and reduce load if needed"
            ))
        }
        
        // Low-end device recommendations
        if isLowEndDevice {
            recommendations.append(.init(
                type: .info,
                title: "Low-End Device Detected",
                description: "Running on a device with limited resources. Performance optimizations are active.",
                action: "Settings optimized for your device"
            ))
        }
        
        return recommendations
    }
    
    /// Force a memory cleanup
    func forceMemoryCleanup() async {
        guard isSimulatorMode else { return }
        
        print("[DeviceSimulationManager] Forcing memory cleanup")
        await MemorySystem.shared.cleanupMemory()
    }
    
    /// Reset simulation to default settings
    func resetSimulation() {
        setupDeviceSimulation()
        print("[DeviceSimulationManager] Simulation reset to default settings")
    }
    
    deinit {
        monitoringTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

struct DeviceSimulationStatus {
    let isSimulatorMode: Bool
    let deviceModel: String
    let memoryLimit: Double
    let memoryPressure: Double
    let thermalThrottling: Double
    let isLowEndDevice: Bool
    let maxFPS: Int
    let cpuCores: Int
}

struct PerformanceSettings {
    let targetFPS: Int
    let enableParticles: Bool
    let enableAnimations: Bool
    let enableShadows: Bool
    let textureQuality: TextureQuality
}

enum TextureQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct MemoryInfo {
    let used: Double
    let total: Double
    let available: Double
    let pressure: Double
    let limit: Double
}

struct PerformanceRecommendation {
    enum RecommendationType {
        case info
        case warning
        case critical
    }
    
    let type: RecommendationType
    let title: String
    let description: String
    let action: String
}

// MARK: - Extensions

extension DeviceSimulationManager {
    /// Get a formatted string representation of current status
    func getStatusString() -> String {
        let status = getSimulationStatus()
        let memoryInfo = getMemoryInfo()
        
        var statusString = "Device Simulation Status:\n"
        statusString += "Mode: \(status.isSimulatorMode ? "Simulator" : "Real Device")\n"
        statusString += "Device: \(status.deviceModel)\n"
        statusString += "Memory: \(String(format: "%.1f", memoryInfo.used))MB / \(String(format: "%.1f", memoryInfo.total))MB\n"
        statusString += "Memory Pressure: \(String(format: "%.1f", status.memoryPressure * 100))%\n"
        statusString += "Thermal Throttling: \(String(format: "%.1f", status.thermalThrottling * 100))%\n"
        statusString += "Low-end Device: \(status.isLowEndDevice)\n"
        statusString += "Max FPS: \(status.maxFPS)\n"
        statusString += "CPU Cores: \(status.cpuCores)"
        
        return statusString
    }
} 