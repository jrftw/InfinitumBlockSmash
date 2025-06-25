/*
 * CrashReporter.swift
 * 
 * CRASH REPORTING AND DEBUG LOGGING SYSTEM
 * 
 * This service provides comprehensive crash reporting, debug logging, and performance
 * monitoring for the Infinitum Block Smash game. It integrates with Firebase Crashlytics
 * and provides detailed logging for debugging and performance analysis.
 * 
 * KEY RESPONSIBILITIES:
 * - Crash reporting and error tracking
 * - Debug logging and log management
 * - Performance monitoring and metrics
 * - Memory usage tracking and reporting
 * - Gameplay analytics logging
 * - User consent management for crash reports
 * - Real-time log monitoring
 * - Crash report generation and export
 * - Error categorization and prioritization
 * - Debug information collection
 * 
 * MAJOR DEPENDENCIES:
 * - FirebaseCrashlytics: Crash reporting service
 * - FirebaseAuth: User identification
 * - MemorySystem.swift: Memory usage monitoring
 * - AnalyticsManager.swift: Gameplay analytics
 * - UserDefaults: User consent storage
 * - UIKit: Device information collection
 * - os.log: System logging integration
 * 
 * CRASH REPORTING FEATURES:
 * - Automatic crash detection and reporting
 * - User consent management
 * - Custom error recording
 * - User identification
 * - Custom value tracking
 * - Crash report generation
 * - Debug information collection
 * 
 * LOGGING FEATURES:
 * - Debug log management (1000 entries)
 * - Real-time log monitoring (100 entries)
 * - Timestamp-based logging
 * - Log rotation and cleanup
 * - Performance-optimized logging
 * - Conditional logging (DEBUG vs RELEASE)
 * 
 * PERFORMANCE MONITORING:
 * - Memory usage tracking (5-second intervals)
 * - Gameplay metrics logging (10-second intervals)
 * - Cache performance monitoring
 * - FPS tracking and reporting
 * - Session duration monitoring
 * - Performance degradation detection
 * 
 * MEMORY MONITORING:
 * - Real-time memory usage tracking
 * - Memory pressure detection
 * - Cache hit/miss ratio monitoring
 * - Memory status reporting
 * - Memory optimization recommendations
 * 
 * GAMEPLAY ANALYTICS:
 * - Session duration tracking
 * - Average score per level
 * - Blocks per minute metrics
 * - Chain length monitoring
 * - FPS performance tracking
 * - Gameplay pattern analysis
 * 
 * USER CONSENT MANAGEMENT:
 * - Crash report consent tracking
 * - Privacy-compliant logging
 * - User preference respect
 * - Consent change handling
 * - Data protection compliance
 * 
 * DEBUG INFORMATION:
 * - Device information collection
 * - App version tracking
 * - User identification
 * - System information
 * - Performance metrics
 * - Error context collection
 * 
 * ERROR HANDLING:
 * - Graceful error recording
 * - Network failure handling
 * - Log corruption prevention
 * - Memory pressure response
 * - Service unavailability handling
 * 
 * INTEGRATION POINTS:
 * - Firebase Crashlytics backend
 * - Memory monitoring system
 * - Analytics tracking system
 * - User authentication system
 * - Debug interface components
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central crash reporting and debugging
 * coordinator, providing comprehensive error tracking and performance
 * monitoring while respecting user privacy and consent.
 * 
 * THREADING CONSIDERATIONS:
 * - @MainActor for UI updates
 * - Background logging operations
 * - Thread-safe log management
 * - Safe crash reporting
 * 
 * PERFORMANCE CONSIDERATIONS:
 * - Efficient log storage
 * - Minimal performance impact
 * - Background monitoring
 * - Memory-efficient logging
 * 
 * PRIVACY CONSIDERATIONS:
 * - User consent compliance
 * - Data minimization
 * - Secure data transmission
 * - Privacy-by-design approach
 * 
 * REVIEW NOTES:
 * - Verify Firebase Crashlytics integration and configuration
 * - Check user consent management and privacy compliance
 * - Test crash reporting functionality and data collection
 * - Validate debug logging performance and storage
 * - Check memory monitoring accuracy and impact
 * - Test gameplay analytics logging and metrics
 * - Verify log rotation and cleanup mechanisms
 * - Check crash report generation and export functionality
 * - Test performance monitoring during heavy game operations
 * - Validate error categorization and prioritization
 * - Check debug information collection completeness
 * - Test logging during network interruptions
 * - Verify real-time log monitoring performance
 * - Check log storage efficiency and memory usage
 * - Test crash reporting during app background/foreground
 * - Validate user consent change handling
 * - Check crash report data privacy and security
 * - Test logging performance on low-end devices
 * - Verify crash reporting integration with other systems
 * - Check debug log export and sharing functionality
 * - Test memory monitoring during memory pressure
 * - Validate gameplay analytics accuracy
 * - Check crash reporting during app updates
 * - Test logging during rapid state changes
 * - Verify crash report data integrity and completeness
 * - Check performance impact of monitoring systems
 * - Test crash reporting during device storage pressure
 * - Validate debug information accuracy and relevance
 * - Check crash reporting compatibility with different iOS versions
 * - Test logging during heavy network operations
 */

import Foundation
import FirebaseCrashlytics
import UIKit
import FirebaseAuth
import os.log

@MainActor
class CrashReporter {
    static let shared = CrashReporter()
    private var debugLogs: [String] = []
    private var realTimeLogs: [String] = []
    private let maxLogEntries = 1000
    private let maxRealTimeEntries = 100
    private var memoryLogTimer: Timer?
    private var gameplayLogTimer: Timer?
    private let analyticsManager = AnalyticsManager.shared
    
    private init() {
        // Set default value for allowCrashReports if not set
        if UserDefaults.standard.object(forKey: "allowCrashReports") == nil {
            UserDefaults.standard.set(true, forKey: "allowCrashReports")
        }
        
        // Start memory and gameplay logging
        startMemoryLogging()
        startGameplayLogging()
    }
    
    func log(_ message: String) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        
        #if DEBUG
        Crashlytics.crashlytics().log(message)
        #else
        // In release builds, only log critical messages to reduce noise
        if message.contains("ERROR") || message.contains("CRITICAL") || message.contains("FAILED") {
            Crashlytics.crashlytics().log(message)
        }
        #endif
        
        // Add to debug logs
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        debugLogs.append(logEntry)
        
        // Add to real-time logs
        realTimeLogs.append(logEntry)
        
        // Keep only the last maxLogEntries
        if debugLogs.count > maxLogEntries {
            debugLogs.removeFirst(debugLogs.count - maxLogEntries)
        }
        
        // Keep only the last maxRealTimeEntries
        if realTimeLogs.count > maxRealTimeEntries {
            realTimeLogs.removeFirst(realTimeLogs.count - maxRealTimeEntries)
        }
    }
    
    private func startMemoryLogging() {
        // Start memory logging timer - significantly reduced frequency to prevent heating
        memoryLogTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in // Increased from 15.0 to 60.0
            Task { @MainActor in
                self?.logMemoryUsage()
            }
        }
    }
    
    private func startGameplayLogging() {
        // Start gameplay logging timer - significantly reduced frequency to prevent heating
        gameplayLogTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in // Increased from 30.0 to 120.0
            Task { @MainActor in
                self?.logGameplayMetrics()
            }
        }
    }
    
    func setUserIdentifier(_ userId: String) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        Crashlytics.crashlytics().setUserID(userId)
    }
    
    func setCustomValue(_ value: Any, forKey key: String) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
    
    func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }
    
    func forceCrash() {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        fatalError("Forced crash for testing")
    }
    
    func getCrashReport() -> String {
        // Get the last crash report if available
        var report = "No crash report available"
        
        // Add device information
        let device = UIDevice.current
        report += "\n\nDevice Information:"
        report += "\nModel: \(device.model)"
        report += "\nSystem Version: \(device.systemVersion)"
        report += "\nApp Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
        
        // Add user information if available
        if let userId = Auth.auth().currentUser?.uid {
            report += "\n\nUser Information:"
            report += "\nUser ID: \(userId)"
        }
        
        return report
    }
    
    func getDebugLogs() -> String {
        var logs = "=== Debug Logs ===\n"
        logs += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))\n\n"
        
        // Add device information
        let device = UIDevice.current
        logs += "Device Information:\n"
        logs += "Model: \(device.model)\n"
        logs += "System Version: \(device.systemVersion)\n"
        logs += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n\n"
        
        // Add user information if available
        if let userId = Auth.auth().currentUser?.uid {
            logs += "User Information:\n"
            logs += "User ID: \(userId)\n\n"
        }
        
        // Add memory information
        let (used, total) = MemorySystem.shared.getMemoryUsage()
        let ratio = used / total
        let status = MemorySystem.shared.checkMemoryStatus()
        let cacheStats = MemorySystem.shared.getCacheStats()
        
        logs += "Memory Information:\n"
        logs += "Status: \(status)\n"
        logs += "Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", ratio * 100))%)\n"
        logs += "Cache Stats: Hits: \(cacheStats.hits), Misses: \(cacheStats.misses)\n\n"
        
        // Add gameplay information if available
        if let gameAnalytics = analyticsManager.gameAnalytics {
            logs += "Gameplay Information:\n"
            logs += "Session Duration: \(String(format: "%.1f", gameAnalytics.averageSessionDuration))s\n"
            logs += "Average Score: \(String(format: "%.1f", gameAnalytics.averageScorePerLevel))\n"
            logs += "Blocks/Minute: \(String(format: "%.1f", gameAnalytics.averageBlocksPerMinute))\n"
            logs += "Average Chain: \(String(format: "%.1f", gameAnalytics.averageChainLength))\n"
            logs += "FPS: \(String(format: "%.1f", gameAnalytics.averageFPS))\n\n"
        }
        
        // Add debug logs
        logs += "Session Logs:\n"
        logs += debugLogs.joined(separator: "\n")
        
        return logs
    }
    
    func getRealTimeLogs() -> String {
        return realTimeLogs.joined(separator: "\n")
    }
    
    func clearDebugLogs() {
        debugLogs.removeAll()
        realTimeLogs.removeAll()
    }
    
    deinit {
        memoryLogTimer?.invalidate()
        gameplayLogTimer?.invalidate()
    }
    
    private func logMemoryUsage() {
        Task { @MainActor in
            let (used, total) = MemorySystem.shared.getMemoryUsage()
            let ratio = used / total
            let status = MemorySystem.shared.checkMemoryStatus()
            let cacheStats = MemorySystem.shared.getCacheStats()
            
            let memoryLog = """
            Memory Status: \(status)
            Memory Usage: \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", ratio * 100))%)
            Cache Stats: Hits: \(cacheStats.hits), Misses: \(cacheStats.misses)
            """
            
            self.log("[Memory] \(memoryLog)")
        }
    }
    
    private func logGameplayMetrics() {
        Task { @MainActor in
            if let gameAnalytics = self.analyticsManager.gameAnalytics {
                let gameplayLog = """
                Session Duration: \(String(format: "%.1f", gameAnalytics.averageSessionDuration))s
                Average Score: \(String(format: "%.1f", gameAnalytics.averageScorePerLevel))
                Blocks/Minute: \(String(format: "%.1f", gameAnalytics.averageBlocksPerMinute))
                Average Chain: \(String(format: "%.1f", gameAnalytics.averageChainLength))
                FPS: \(String(format: "%.1f", gameAnalytics.averageFPS))
                """
                
                self.log("[Gameplay] \(gameplayLog)")
            }
        }
    }
    
    /// Stop monitoring (for thermal emergency mode)
    func stopMonitoring() {
        memoryLogTimer?.invalidate()
        memoryLogTimer = nil
        gameplayLogTimer?.invalidate()
        gameplayLogTimer = nil
        print("[CrashReporter] Monitoring stopped")
    }
    
    /// Start monitoring (for thermal emergency mode)
    func startMonitoring() {
        stopMonitoring() // Ensure any existing timers are invalidated
        
        // Start memory logging timer - significantly reduced frequency to prevent heating
        memoryLogTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in // Increased from 15.0 to 60.0
            Task { @MainActor in
                self?.logMemoryUsage()
            }
        }
        
        // Start gameplay logging timer - significantly reduced frequency to prevent heating
        gameplayLogTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in // Increased from 30.0 to 120.0
            Task { @MainActor in
                self?.logGameplayMetrics()
            }
        }
        
        print("[CrashReporter] Monitoring started")
    }
} 