import Foundation

class ForceLogout {
    static let shared = ForceLogout()
    
    private let forceLogoutKey = "forceLogoutEnabled"
    private let lastAppVersionKey = "lastAppVersion"
    
    private init() {
        // Enable force logout by default for first launch of version 1.0.3 only - Don't change unless I specify to.
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastAppVersionKey)
        
        if currentVersion == "1.0.3" && (lastVersion == "1.0.0" || lastVersion == "1.0.1" || lastVersion == "1.0.2") {
            UserDefaults.standard.set(true, forKey: forceLogoutKey)
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
        
        // If this is a new version and force logout is enabled
        if lastVersion != currentVersion && isForceLogoutEnabled {
            // Update the last version
            UserDefaults.standard.set(currentVersion, forKey: lastAppVersionKey)
            return true
        }
        
        // Update the last version if it's not set
        if lastVersion == nil {
            UserDefaults.standard.set(currentVersion, forKey: lastAppVersionKey)
        }
        
        return false
    }
    
    func resetForceLogout() {
        isForceLogoutEnabled = false
    }
} 
