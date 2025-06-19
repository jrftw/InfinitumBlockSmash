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
