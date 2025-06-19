import Foundation

class ForceLogout {
    static let shared = ForceLogout()
    
    private let forceLogoutKey = "forceLogoutEnabled"
    private let lastAppVersionKey = "lastAppVersion"
    
    private init() {
        // Only enable force logout for specific version migrations
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastAppVersionKey)
        
        // Enable force logout only for specific version migrations
        if currentVersion == "1.0.3" && (lastVersion == "1.0.0" || lastVersion == "1.0.1" || lastVersion == "1.0.2") {
            UserDefaults.standard.set(true, forKey: forceLogoutKey)
            print("[ForceLogout] Enabled force logout for version 1.0.3 migration")
        }
    }
    
    var isForceLogoutEnabled: Bool {
        get {
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
            print("[ForceLogout] Fresh install detected, setting version to \(currentVersion)")
            return false
        }
        
        // Only force logout if this is a new version and force logout is enabled
        if lastVersion != currentVersion && isForceLogoutEnabled {
            // Update the last version
            UserDefaults.standard.set(currentVersion, forKey: lastAppVersionKey)
            print("[ForceLogout] Force logout triggered for version migration from \(lastVersion ?? "unknown") to \(currentVersion)")
            return true
        }
        
        // Update the last version if it's different but force logout is not enabled
        if lastVersion != currentVersion {
            UserDefaults.standard.set(currentVersion, forKey: lastAppVersionKey)
            print("[ForceLogout] Version updated from \(lastVersion ?? "unknown") to \(currentVersion) without force logout")
        }
        
        return false
    }
    
    func resetForceLogout() {
        isForceLogoutEnabled = false
        print("[ForceLogout] Force logout disabled")
    }
    
    // Helper method to check if force logout should be enabled for current version
    func shouldEnableForceLogout() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastAppVersionKey)
        
        // Only enable for specific version migrations
        return currentVersion == "1.0.3" && (lastVersion == "1.0.0" || lastVersion == "1.0.1" || lastVersion == "1.0.2")
    }
} 
