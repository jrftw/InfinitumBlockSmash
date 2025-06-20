/******************************************************
 * FILE: ForceLogout.swift
 * MARK: Version Migration Force Logout Manager
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST:  6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Manages forced logout functionality for version migrations and debug purposes,
 * ensuring users are properly logged out when critical app changes require it.
 *
 * KEY RESPONSIBILITIES:
 * - Detect version changes that require force logout
 * - Manage force logout state persistence
 * - Handle version migration scenarios
 * - Provide debug override capabilities
 * - Track version history for migration logic
 *
 * MAJOR DEPENDENCIES:
 * - DebugManager.swift: Debug override capabilities
 * - Logger.swift: Logging force logout events
 * - UserDefaults: Persistent storage for logout state
 * - Bundle: App version information retrieval
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for data structures and UserDefaults
 *
 * ARCHITECTURE ROLE:
 * Acts as a version migration safety mechanism that ensures users are
 * properly logged out when app changes require fresh authentication.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Must be initialized early in app lifecycle
 * - Version checking occurs on app launch
 * - Force logout state persists across app restarts
 * - Debug manager can override normal behavior
 */

/******************************************************
 * REVIEW NOTES:
 * - Critical for data integrity during version migrations
 * - Debug override provides testing flexibility
 * - Version comparison logic is hardcoded for specific migrations
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Implement remote configuration for migration rules
 * - Add migration progress tracking
 * - Enhance version comparison logic
 ******************************************************/

import Foundation

class ForceLogout {
    static let shared = ForceLogout()
    
    private let forceLogoutKey = "forceLogoutEnabled"
    private let lastAppVersionKey = "lastAppVersion"
    
    private init() {
        // Only enable force logout for specific version migrations or debug mode
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastAppVersionKey)
        
        // Enable force logout only for specific version migrations or debug mode
        if shouldEnableForceLogoutForVersion(currentVersion: currentVersion, lastVersion: lastVersion) {
            UserDefaults.standard.set(true, forKey: forceLogoutKey)
            Logger.shared.log("Enabled force logout for version \(currentVersion) migration", category: .forceLogout, level: .info)
        }
    }
    
    var isForceLogoutEnabled: Bool {
        get {
            // Check if debug manager wants to enable force logout
            if DebugManager.shouldEnableForceLogout {
                return true
            }
            return UserDefaults.standard.bool(forKey: forceLogoutKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: forceLogoutKey)
        }
    }
    
    func checkAndHandleForceLogout() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastAppVersionKey)
        
        // If this is a fresh install (no lastVersion), don't force logout
        if lastVersion == nil {
            UserDefaults.standard.set(currentVersion, forKey: lastAppVersionKey)
            Logger.shared.log("Fresh install detected, setting version to \(currentVersion)", category: .forceLogout, level: .info)
            return false
        }
        
        // Only force logout if this is a new version and force logout is enabled
        if lastVersion != currentVersion && isForceLogoutEnabled {
            // Update the last version
            UserDefaults.standard.set(currentVersion, forKey: lastAppVersionKey)
            Logger.shared.log("Force logout triggered for version migration from \(lastVersion ?? "unknown") to \(currentVersion)", category: .forceLogout, level: .warning)
            return true
        }
        
        // Update the last version if it's different but force logout is not enabled
        if lastVersion != currentVersion {
            UserDefaults.standard.set(currentVersion, forKey: lastAppVersionKey)
            Logger.shared.log("Version updated from \(lastVersion ?? "unknown") to \(currentVersion) without force logout", category: .forceLogout, level: .info)
        }
        
        return false
    }
    
    func resetForceLogout() {
        isForceLogoutEnabled = false
        Logger.shared.log("Force logout disabled", category: .forceLogout, level: .info)
    }
    
    // Helper method to check if force logout should be enabled for current version
    func shouldEnableForceLogout() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastAppVersionKey)
        
        // Check debug manager first
        if DebugManager.shouldEnableForceLogout {
            return true
        }
        
        // Only enable for specific version migrations
        return shouldEnableForceLogoutForVersion(currentVersion: currentVersion, lastVersion: lastVersion)
    }
    
    // Private method to determine if force logout should be enabled for version migration
    private func shouldEnableForceLogoutForVersion(currentVersion: String, lastVersion: String?) -> Bool {
        // Enable force logout only for specific version migrations
        return currentVersion == "1.0.3" && (lastVersion == "1.0.0" || lastVersion == "1.0.1" || lastVersion == "1.0.2")
    }
} 
