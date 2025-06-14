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
        Crashlytics.crashlytics().log(message)
        
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
        memoryLogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
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
                
                self?.log("[Memory] \(memoryLog)")
            }
        }
    }
    
    private func startGameplayLogging() {
        gameplayLogTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if let gameAnalytics = self?.analyticsManager.gameAnalytics {
                    let gameplayLog = """
                    Session Duration: \(String(format: "%.1f", gameAnalytics.averageSessionDuration))s
                    Average Score: \(String(format: "%.1f", gameAnalytics.averageScorePerLevel))
                    Blocks/Minute: \(String(format: "%.1f", gameAnalytics.averageBlocksPerMinute))
                    Average Chain: \(String(format: "%.1f", gameAnalytics.averageChainLength))
                    FPS: \(String(format: "%.1f", gameAnalytics.averageFPS))
                    """
                    
                    self?.log("[Gameplay] \(gameplayLog)")
                }
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
} 