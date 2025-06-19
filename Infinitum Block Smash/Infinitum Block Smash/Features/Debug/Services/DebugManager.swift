import Foundation
import SwiftUI

/// Global Debug Manager for controlling all debug features and logging
/// This provides a single point of control for enabling/disabling debug functionality
class DebugManager: ObservableObject {
    static let shared = DebugManager()
    
    // MARK: - Global Debug State
    @Published var isDebugModeEnabled: Bool = false
    @Published var isProductionMode: Bool = true
    
    // MARK: - Feature Toggles
    @Published var showDebugUI: Bool = false
    @Published var showDebugLogs: Bool = false
    @Published var showDebugBorders: Bool = false
    @Published var showDebugInfo: Bool = false
    @Published var enableVerboseLogging: Bool = false
    @Published var enableForceLogout: Bool = false
    @Published var enableDeviceSimulation: Bool = false
    @Published var enableDebugAnalytics: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let debugModeKey = "DebugManager_DebugMode"
    private let productionModeKey = "DebugManager_ProductionMode"
    
    // MARK: - Initialization
    private init() {
        loadSettings()
        setupEnvironmentDetection()
    }
    
    // MARK: - Environment Detection
    private func setupEnvironmentDetection() {
        #if DEBUG
        // In debug builds, allow debug mode but default to off
        isDebugModeEnabled = userDefaults.bool(forKey: debugModeKey)
        isProductionMode = userDefaults.bool(forKey: productionModeKey)
        #else
        // In release builds, force production mode
        isDebugModeEnabled = false
        isProductionMode = true
        userDefaults.set(false, forKey: debugModeKey)
        userDefaults.set(true, forKey: productionModeKey)
        #endif
        
        updateFeatureStates()
    }
    
    // MARK: - Public Methods
    
    /// Enable debug mode (only works in DEBUG builds)
    func enableDebugMode() {
        #if DEBUG
        isDebugModeEnabled = true
        userDefaults.set(true, forKey: debugModeKey)
        updateFeatureStates()
        #endif
    }
    
    /// Disable debug mode
    func disableDebugMode() {
        isDebugModeEnabled = false
        userDefaults.set(false, forKey: debugModeKey)
        updateFeatureStates()
    }
    
    /// Toggle debug mode
    func toggleDebugMode() {
        if isDebugModeEnabled {
            disableDebugMode()
        } else {
            enableDebugMode()
        }
    }
    
    /// Set production mode
    func setProductionMode(_ enabled: Bool) {
        isProductionMode = enabled
        userDefaults.set(enabled, forKey: productionModeKey)
        updateFeatureStates()
    }
    
    /// Check if debug features should be available
    var shouldShowDebugFeatures: Bool {
        #if DEBUG
        return isDebugModeEnabled && !isProductionMode
        #else
        return false
        #endif
    }
    
    /// Check if verbose logging should be enabled
    var shouldEnableVerboseLogging: Bool {
        return shouldShowDebugFeatures && enableVerboseLogging
    }
    
    /// Check if debug UI should be shown
    var shouldShowDebugUI: Bool {
        return shouldShowDebugFeatures && showDebugUI
    }
    
    /// Check if debug borders should be shown
    var shouldShowDebugBorders: Bool {
        return shouldShowDebugFeatures && showDebugBorders
    }
    
    /// Check if force logout should be enabled
    var shouldEnableForceLogout: Bool {
        return shouldShowDebugFeatures && enableForceLogout
    }
    
    /// Check if device simulation should be enabled
    var shouldEnableDeviceSimulation: Bool {
        return shouldShowDebugFeatures && enableDeviceSimulation
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        showDebugUI = userDefaults.bool(forKey: "DebugManager_ShowDebugUI")
        showDebugLogs = userDefaults.bool(forKey: "DebugManager_ShowDebugLogs")
        showDebugBorders = userDefaults.bool(forKey: "DebugManager_ShowDebugBorders")
        showDebugInfo = userDefaults.bool(forKey: "DebugManager_ShowDebugInfo")
        enableVerboseLogging = userDefaults.bool(forKey: "DebugManager_EnableVerboseLogging")
        enableForceLogout = userDefaults.bool(forKey: "DebugManager_EnableForceLogout")
        enableDeviceSimulation = userDefaults.bool(forKey: "DebugManager_EnableDeviceSimulation")
        enableDebugAnalytics = userDefaults.bool(forKey: "DebugManager_EnableDebugAnalytics")
    }
    
    private func updateFeatureStates() {
        // Update LoggerConfig based on debug state
        updateLoggerConfig()
        
        // Update ForceLogout based on debug state
        updateForceLogout()
        
        // Save current settings
        saveSettings()
    }
    
    private func updateLoggerConfig() {
        // This will be called to update LoggerConfig when debug state changes
        // We'll implement this by modifying LoggerConfig to check DebugManager
    }
    
    private func updateForceLogout() {
        // Update ForceLogout to check DebugManager
        ForceLogout.shared.isForceLogoutEnabled = shouldEnableForceLogout
    }
    
    private func saveSettings() {
        userDefaults.set(showDebugUI, forKey: "DebugManager_ShowDebugUI")
        userDefaults.set(showDebugLogs, forKey: "DebugManager_ShowDebugLogs")
        userDefaults.set(showDebugBorders, forKey: "DebugManager_ShowDebugBorders")
        userDefaults.set(showDebugInfo, forKey: "DebugManager_ShowDebugInfo")
        userDefaults.set(enableVerboseLogging, forKey: "DebugManager_EnableVerboseLogging")
        userDefaults.set(enableForceLogout, forKey: "DebugManager_EnableForceLogout")
        userDefaults.set(enableDeviceSimulation, forKey: "DebugManager_EnableDeviceSimulation")
        userDefaults.set(enableDebugAnalytics, forKey: "DebugManager_EnableDebugAnalytics")
    }
}

// MARK: - Debug UI View
struct DebugManagerView: View {
    @StateObject private var debugManager = DebugManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Debug Mode") {
                    HStack {
                        Text("Debug Mode")
                        Spacer()
                        Toggle("", isOn: $debugManager.isDebugModeEnabled)
                            .onChange(of: debugManager.isDebugModeEnabled) { newValue in
                                if newValue {
                                    debugManager.enableDebugMode()
                                } else {
                                    debugManager.disableDebugMode()
                                }
                            }
                    }
                    
                    HStack {
                        Text("Production Mode")
                        Spacer()
                        Toggle("", isOn: $debugManager.isProductionMode)
                            .onChange(of: debugManager.isProductionMode) { newValue in
                                debugManager.setProductionMode(newValue)
                            }
                    }
                }
                
                if debugManager.shouldShowDebugFeatures {
                    Section("Debug Features") {
                        Toggle("Show Debug UI", isOn: $debugManager.showDebugUI)
                        Toggle("Show Debug Logs", isOn: $debugManager.showDebugLogs)
                        Toggle("Show Debug Borders", isOn: $debugManager.showDebugBorders)
                        Toggle("Show Debug Info", isOn: $debugManager.showDebugInfo)
                        Toggle("Verbose Logging", isOn: $debugManager.enableVerboseLogging)
                        Toggle("Force Logout", isOn: $debugManager.enableForceLogout)
                        Toggle("Device Simulation", isOn: $debugManager.enableDeviceSimulation)
                        Toggle("Debug Analytics", isOn: $debugManager.enableDebugAnalytics)
                    }
                    
                    Section("Actions") {
                        Button("Reset All Settings") {
                            debugManager.disableDebugMode()
                            debugManager.setProductionMode(true)
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Status") {
                    HStack {
                        Text("Debug Features Available")
                        Spacer()
                        Text(debugManager.shouldShowDebugFeatures ? "Yes" : "No")
                            .foregroundColor(debugManager.shouldShowDebugFeatures ? .green : .red)
                    }
                }
            }
            .navigationTitle("Debug Manager")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Convenience Extensions
extension DebugManager {
    /// Quick access to check if debug mode is active
    static var isDebugActive: Bool {
        return shared.shouldShowDebugFeatures
    }
    
    /// Quick access to check if verbose logging is enabled
    static var isVerboseLoggingEnabled: Bool {
        return shared.shouldEnableVerboseLogging
    }
    
    /// Quick access to check if debug UI should be shown
    static var shouldShowDebugUI: Bool {
        return shared.shouldShowDebugUI
    }
    
    /// Quick access to check if debug borders should be shown
    static var shouldShowDebugBorders: Bool {
        return shared.shouldShowDebugBorders
    }
    
    /// Quick access to check if force logout should be enabled
    static var shouldEnableForceLogout: Bool {
        return shared.shouldEnableForceLogout
    }
    
    /// Quick access to check if debug features should be shown
    static var shouldShowDebugFeatures: Bool {
        return shared.shouldShowDebugFeatures
    }
    
    /// Quick access to check if device simulation should be enabled
    static var shouldEnableDeviceSimulation: Bool {
        return shared.shouldEnableDeviceSimulation
    }
} 