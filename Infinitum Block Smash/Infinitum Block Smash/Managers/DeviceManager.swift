/******************************************************
 * FILE: DeviceManager.swift
 * MARK: Device Simulation and Capability Management
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides device simulation and capability management for testing and
 * optimization, enabling realistic device constraints and performance testing.
 *
 * KEY RESPONSIBILITIES:
 * - Device specification simulation for testing
 * - Memory limit management and constraints
 * - CPU core and performance simulation
 * - FPS capability detection and simulation
 * - Low-end device identification and optimization
 * - Device model detection and classification
 * - Simulator mode management
 * - Performance testing support
 *
 * MAJOR DEPENDENCIES:
 * - UIKit: Device capability detection
 * - Foundation: Core framework for device information
 * - FirebaseFirestore: Device data storage
 * - System information: Device hardware detection
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for data structures
 * - FirebaseFirestore: Cloud database for device data
 * - UIKit: iOS UI framework for device detection
 *
 * ARCHITECTURE ROLE:
 * Acts as a device simulation layer that provides realistic
 * device constraints for testing and optimization purposes.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Device detection must be accurate and reliable
 * - Simulator mode must be properly detected
 * - Memory limits must be realistic and safe
 * - Performance constraints must be appropriate
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify device detection accuracy across all models
 * - Test simulator mode functionality
 * - Check memory limit calculations
 * - Validate performance constraint application
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add more device models and specifications
 * - Implement dynamic performance testing
 * - Add device-specific optimization profiles
 ******************************************************/

import Foundation
import FirebaseFirestore
import UIKit

// MARK: - Device Simulator
class DeviceSimulator {
    static let shared = DeviceSimulator()
    
    // Device specifications for different iPhone models
    private struct DeviceSpecs {
        let model: String
        let memoryGB: Double
        let cpuCores: Int
        let maxFPS: Int
        let isLowEnd: Bool
    }
    
    private let deviceSpecs: [String: DeviceSpecs] = [
        // iPhone SE (1st gen) - 2GB RAM
        "iPhone8,4": DeviceSpecs(model: "iPhone SE (1st gen)", memoryGB: 2.0, cpuCores: 2, maxFPS: 60, isLowEnd: true),
        // iPhone 6s - 2GB RAM
        "iPhone8,1": DeviceSpecs(model: "iPhone 6s", memoryGB: 2.0, cpuCores: 2, maxFPS: 60, isLowEnd: true),
        "iPhone8,2": DeviceSpecs(model: "iPhone 6s Plus", memoryGB: 2.0, cpuCores: 2, maxFPS: 60, isLowEnd: true),
        // iPhone 7 - 2GB RAM
        "iPhone9,1": DeviceSpecs(model: "iPhone 7", memoryGB: 2.0, cpuCores: 2, maxFPS: 60, isLowEnd: true),
        "iPhone9,3": DeviceSpecs(model: "iPhone 7", memoryGB: 2.0, cpuCores: 2, maxFPS: 60, isLowEnd: true),
        // iPhone 8 - 2GB RAM
        "iPhone10,1": DeviceSpecs(model: "iPhone 8", memoryGB: 2.0, cpuCores: 2, maxFPS: 60, isLowEnd: true),
        "iPhone10,4": DeviceSpecs(model: "iPhone 8", memoryGB: 2.0, cpuCores: 2, maxFPS: 60, isLowEnd: true),
        // iPhone X - 3GB RAM
        "iPhone10,3": DeviceSpecs(model: "iPhone X", memoryGB: 3.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone10,6": DeviceSpecs(model: "iPhone X", memoryGB: 3.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone XR - 3GB RAM
        "iPhone11,8": DeviceSpecs(model: "iPhone XR", memoryGB: 3.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone XS - 4GB RAM
        "iPhone11,2": DeviceSpecs(model: "iPhone XS", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone11,6": DeviceSpecs(model: "iPhone XS Max", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 11 - 4GB RAM
        "iPhone12,1": DeviceSpecs(model: "iPhone 11", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 11 Pro - 4GB RAM
        "iPhone12,3": DeviceSpecs(model: "iPhone 11 Pro", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone12,5": DeviceSpecs(model: "iPhone 11 Pro Max", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone SE (2nd gen) - 3GB RAM
        "iPhone12,8": DeviceSpecs(model: "iPhone SE (2nd gen)", memoryGB: 3.0, cpuCores: 6, maxFPS: 60, isLowEnd: true),
        // iPhone 12 - 4GB RAM
        "iPhone13,2": DeviceSpecs(model: "iPhone 12", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone13,3": DeviceSpecs(model: "iPhone 12 mini", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 12 Pro - 6GB RAM
        "iPhone13,1": DeviceSpecs(model: "iPhone 12 Pro", memoryGB: 6.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone13,4": DeviceSpecs(model: "iPhone 12 Pro Max", memoryGB: 6.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 13 - 4GB RAM
        "iPhone14,5": DeviceSpecs(model: "iPhone 13", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone14,2": DeviceSpecs(model: "iPhone 13 mini", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 13 Pro - 6GB RAM
        "iPhone14,3": DeviceSpecs(model: "iPhone 13 Pro", memoryGB: 6.0, cpuCores: 6, maxFPS: 120, isLowEnd: false),
        "iPhone14,4": DeviceSpecs(model: "iPhone 13 Pro Max", memoryGB: 6.0, cpuCores: 6, maxFPS: 120, isLowEnd: false),
        // iPhone 14 - 6GB RAM
        "iPhone14,7": DeviceSpecs(model: "iPhone 14", memoryGB: 6.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone14,8": DeviceSpecs(model: "iPhone 14 Plus", memoryGB: 6.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 14 Pro - 6GB RAM
        "iPhone15,2": DeviceSpecs(model: "iPhone 14 Pro", memoryGB: 6.0, cpuCores: 6, maxFPS: 120, isLowEnd: false),
        "iPhone15,3": DeviceSpecs(model: "iPhone 14 Pro Max", memoryGB: 6.0, cpuCores: 6, maxFPS: 120, isLowEnd: false),
        // iPhone 15 - 6GB RAM
        "iPhone15,4": DeviceSpecs(model: "iPhone 15", memoryGB: 6.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone15,5": DeviceSpecs(model: "iPhone 15 Plus", memoryGB: 6.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 15 Pro - 8GB RAM
        "iPhone16,1": DeviceSpecs(model: "iPhone 15 Pro", memoryGB: 8.0, cpuCores: 6, maxFPS: 120, isLowEnd: false),
        "iPhone16,2": DeviceSpecs(model: "iPhone 15 Pro Max", memoryGB: 8.0, cpuCores: 6, maxFPS: 120, isLowEnd: false),
        // iPhone SE (3rd gen) - 4GB RAM
        "iPhone14,6": DeviceSpecs(model: "iPhone SE (3rd gen)", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: true),
        // iPhone 16 - 8GB RAM
        "iPhone17,1": DeviceSpecs(model: "iPhone 16", memoryGB: 8.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        "iPhone17,2": DeviceSpecs(model: "iPhone 16 Plus", memoryGB: 8.0, cpuCores: 6, maxFPS: 60, isLowEnd: false),
        // iPhone 16 Pro - 8GB RAM
        "iPhone17,3": DeviceSpecs(model: "iPhone 16 Pro", memoryGB: 8.0, cpuCores: 6, maxFPS: 120, isLowEnd: false),
        "iPhone17,4": DeviceSpecs(model: "iPhone 16 Pro Max", memoryGB: 8.0, cpuCores: 6, maxFPS: 120, isLowEnd: false)
    ]
    
    private var currentDeviceSpecs: DeviceSpecs?
    private var isSimulatorMode: Bool = false
    
    private init() {
        setupDeviceSimulation()
    }
    
    private func setupDeviceSimulation() {
        #if targetEnvironment(simulator)
        isSimulatorMode = true
        currentDeviceSpecs = getSimulatedDeviceSpecs()
        print("[DeviceSimulator] Running in simulator mode with device: \(currentDeviceSpecs?.model ?? "Unknown")")
        #else
        isSimulatorMode = false
        currentDeviceSpecs = getRealDeviceSpecs()
        print("[DeviceSimulator] Running on real device: \(currentDeviceSpecs?.model ?? "Unknown")")
        #endif
    }
    
    private func getSimulatedDeviceSpecs() -> DeviceSpecs {
        // Get the simulated device identifier from environment or use a default
        let deviceIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "iPhone 12"
        
        // Map common simulator names to device identifiers
        let simulatorMapping: [String: String] = [
            "iPhone SE (1st generation)": "iPhone8,4",
            "iPhone SE (2nd generation)": "iPhone12,8",
            "iPhone SE (3rd generation)": "iPhone14,6",
            "iPhone 8": "iPhone10,1",
            "iPhone 8 Plus": "iPhone10,2",
            "iPhone X": "iPhone10,3",
            "iPhone XR": "iPhone11,8",
            "iPhone XS": "iPhone11,2",
            "iPhone XS Max": "iPhone11,6",
            "iPhone 11": "iPhone12,1",
            "iPhone 11 Pro": "iPhone12,3",
            "iPhone 11 Pro Max": "iPhone12,5",
            "iPhone 12": "iPhone13,2",
            "iPhone 12 mini": "iPhone13,3",
            "iPhone 12 Pro": "iPhone13,1",
            "iPhone 12 Pro Max": "iPhone13,4",
            "iPhone 13": "iPhone14,5",
            "iPhone 13 mini": "iPhone14,2",
            "iPhone 13 Pro": "iPhone14,3",
            "iPhone 13 Pro Max": "iPhone14,4",
            "iPhone 14": "iPhone14,7",
            "iPhone 14 Plus": "iPhone14,8",
            "iPhone 14 Pro": "iPhone15,2",
            "iPhone 14 Pro Max": "iPhone15,3",
            "iPhone 15": "iPhone15,4",
            "iPhone 15 Plus": "iPhone15,5",
            "iPhone 15 Pro": "iPhone16,1",
            "iPhone 15 Pro Max": "iPhone16,2",
            "iPhone 16": "iPhone17,1",
            "iPhone 16 Plus": "iPhone17,2",
            "iPhone 16 Pro": "iPhone17,3",
            "iPhone 16 Pro Max": "iPhone17,4"
        ]
        
        let deviceID = simulatorMapping[deviceIdentifier] ?? "iPhone13,2" // Default to iPhone 12
        return deviceSpecs[deviceID] ?? deviceSpecs["iPhone13,2"]!
    }
    
    private func getRealDeviceSpecs() -> DeviceSpecs {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            let scalar = UnicodeScalar(UInt8(value))
            return identifier + String(scalar)
        }
        
        return deviceSpecs[identifier] ?? DeviceSpecs(model: "Unknown Device", memoryGB: 4.0, cpuCores: 6, maxFPS: 60, isLowEnd: false)
    }
    
    // MARK: - Public Interface
    
    /// Get the simulated memory limit in MB
    func getSimulatedMemoryLimit() -> Double {
        guard let specs = currentDeviceSpecs else { return 4000.0 } // Default 4GB
        
        // Convert GB to MB and apply some realistic constraints
        let totalMemoryMB = specs.memoryGB * 1024.0
        
        // Reserve some memory for system processes (typically 20-30% on iOS)
        let systemReserved = totalMemoryMB * 0.25
        let availableMemory = totalMemoryMB - systemReserved
        
        // Apply additional constraints for low-end devices
        if specs.isLowEnd {
            return availableMemory * 0.8 // More aggressive limits for low-end devices
        }
        
        return availableMemory
    }
    
    /// Get the simulated CPU cores
    func getSimulatedCPUCores() -> Int {
        return currentDeviceSpecs?.cpuCores ?? 6
    }
    
    /// Get the simulated max FPS
    func getSimulatedMaxFPS() -> Int {
        return currentDeviceSpecs?.maxFPS ?? 60
    }
    
    /// Check if current device is considered low-end
    func isLowEndDevice() -> Bool {
        return currentDeviceSpecs?.isLowEnd ?? false
    }
    
    /// Get the current device model name
    func getCurrentDeviceModel() -> String {
        return currentDeviceSpecs?.model ?? "Unknown Device"
    }
    
    /// Check if running in simulator mode
    func isRunningInSimulator() -> Bool {
        return isSimulatorMode
    }
    
    /// Get memory pressure simulation level (0.0 to 1.0)
    func getSimulatedMemoryPressure() -> Double {
        guard isSimulatorMode else { return 0.0 }
        
        // For simulator, we need to estimate memory usage differently
        // since ProcessInfo.processInfo.physicalMemory returns host Mac memory
        let estimatedMemoryUsage = getEstimatedSimulatorMemoryUsage()
        let limit = getSimulatedMemoryLimit()
        
        return min(estimatedMemoryUsage / limit, 1.0)
    }
    
    /// Estimate memory usage in simulator (more accurate than ProcessInfo)
    private func getEstimatedSimulatorMemoryUsage() -> Double {
        // Use a more conservative estimate for simulator
        // Simulator typically has much lower memory limits than host Mac
        let baseMemory = 100.0 // Base memory usage in MB
        
        // Add estimated memory from various sources
        let textureMemory = estimateTextureMemory()
        let nodeMemory = estimateNodeMemory()
        let cacheMemory = estimateCacheMemory()
        
        return baseMemory + textureMemory + nodeMemory + cacheMemory
    }
    
    private func estimateTextureMemory() -> Double {
        // Estimate texture memory based on active textures
        // This is a rough estimate - in real implementation you'd track actual texture usage
        return 50.0 // Conservative estimate
    }
    
    private func estimateNodeMemory() -> Double {
        // Estimate node memory based on active nodes
        // This is a rough estimate - in real implementation you'd track actual node count
        return 30.0 // Conservative estimate
    }
    
    private func estimateCacheMemory() -> Double {
        // Estimate cache memory
        return 20.0 // Conservative estimate
    }
    
    /// Simulate thermal throttling based on CPU usage
    func getSimulatedThermalThrottling() -> Double {
        guard isSimulatorMode else { return 0.0 }
        
        // Simulate thermal throttling based on device type and CPU usage
        let cpuUsage = PerformanceMonitor.shared.cpuUsage
        let baseThrottling = cpuUsage / 100.0
        
        if let specs = currentDeviceSpecs, specs.isLowEnd {
            // Low-end devices throttle more aggressively
            return min(baseThrottling * 1.5, 1.0)
        }
        
        return min(baseThrottling, 1.0)
    }
}

// MARK: - Device Manager (Original Code)
class DeviceManager {
    static let shared = DeviceManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Get the device identifier
    private func getDeviceIdentifier() -> String {
        if let identifier = UIDevice.current.identifierForVendor?.uuidString {
            return identifier
        }
        return "unknown"
    }
    
    // Track a new account creation for this device
    func trackAccountCreation(userID: String) async throws {
        let deviceID = getDeviceIdentifier()
        let deviceRef = db.collection("devices").document(deviceID)
        
        // First check if this user already exists in any device
        let existingDevices = try await db.collection("devices")
            .whereField("accounts", arrayContains: userID)
            .getDocuments()
        
        // If user exists in another device, copy the referral status
        if let existingDevice = existingDevices.documents.first,
           let hasUsedReferral = existingDevice.data()["hasUsedReferral"] as? Bool {
            try await deviceRef.setData([
                "accounts": FieldValue.arrayUnion([userID]),
                "hasUsedReferral": hasUsedReferral,
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
        } else {
            // Check if user has been referred before
            let userDoc = try await db.collection("users").document(userID).getDocument()
            if let data = userDoc.data(),
               let referredBy = data["referredBy"] as? String,
               !referredBy.isEmpty {
                // User was previously referred, mark this device as having used a referral
                try await deviceRef.setData([
                    "accounts": FieldValue.arrayUnion([userID]),
                    "hasUsedReferral": true,
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
            } else {
                // New user, no previous referral
                try await deviceRef.setData([
                    "accounts": FieldValue.arrayUnion([userID]),
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
            }
        }
    }
    
    // Get all accounts associated with this device
    func getDeviceAccounts() async throws -> [String] {
        let deviceID = getDeviceIdentifier()
        let deviceDoc = try await db.collection("devices").document(deviceID).getDocument()
        
        if let data = deviceDoc.data(),
           let accounts = data["accounts"] as? [String] {
            return accounts
        }
        return []
    }
    
    // Check if this device has already used a referral code
    func hasUsedReferralCode() async throws -> Bool {
        let deviceID = getDeviceIdentifier()
        let deviceDoc = try await db.collection("devices").document(deviceID).getDocument()
        
        if let data = deviceDoc.data(),
           let hasUsedReferral = data["hasUsedReferral"] as? Bool {
            return hasUsedReferral
        }
        
        // For backwards compatibility, check if any account on this device has been referred
        let accounts = try await getDeviceAccounts()
        for accountID in accounts {
            let userDoc = try await db.collection("users").document(accountID).getDocument()
            if let data = userDoc.data(),
               let referredBy = data["referredBy"] as? String,
               !referredBy.isEmpty {
                // Found a referred account, mark this device as having used a referral
                try await markReferralCodeUsed()
                return true
            }
        }
        
        return false
    }
    
    // Mark that this device has used a referral code
    func markReferralCodeUsed() async throws {
        let deviceID = getDeviceIdentifier()
        try await db.collection("devices").document(deviceID).setData([
            "hasUsedReferral": true,
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }
} 