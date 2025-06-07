import Foundation

class ForceLogout {
    static let shared = ForceLogout()
    
    private let forceLogoutKey = "forceLogoutEnabled"
    private let lastAppVersionKey = "lastAppVersion"
    
    private init() {}
    
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