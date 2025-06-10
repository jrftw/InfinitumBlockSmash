import Foundation
import FirebaseAppCheck
import FirebaseCore
import DeviceCheck

class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    static func configureDebugProvider() {
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] Using debug AppCheckProviderFactory with token: \(getDebugToken())")
        #else
        print("[AppCheck] Debug provider not available in release build")
        #endif
    }
    
    static func configureProductionProvider() {
        let providerFactory = MyAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] Using production AppCheckProviderFactory")
    }
    
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        // Use debug provider in simulator with explicit token
        let debugProvider = AppCheckDebugProvider(app: app)
        print("[AppCheck] Using debug provider in simulator with token: \(MyAppCheckProviderFactory.getDebugToken())")
        return debugProvider
        #else
        if #available(iOS 14.0, *) {
            // Use App Attest provider for iOS 14+ on real devices
            return AppAttestProvider(app: app)
        } else {
            // Fallback to DeviceCheck provider for older iOS versions
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    static func getDebugToken() -> String {
        // First try to get from environment
        if let envToken = ProcessInfo.processInfo.environment["FIREBASE_APP_CHECK_DEBUG_TOKEN"] {
            print("[AppCheck] Using debug token from environment")
            return envToken
        }
        
        // Then try to get from Info.plist
        if let plistToken = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppCheckDebugToken") as? String {
            print("[AppCheck] Using debug token from Info.plist")
            return plistToken
        }
        
        // Fallback to default token
        print("[AppCheck] Using default debug token")
        return "2F8387F3-1DA9-46B8-9817-9EE434A923C5"
    }
    
    static func isDebugMode() -> Bool {
        // Always return true in simulator
        #if targetEnvironment(simulator)
        return true
        #else
        // Check environment variable
        if ProcessInfo.processInfo.environment["FIREBASE_APP_CHECK_DEBUG"] == "true" {
            return true
        }
        // Check Info.plist
        if let debugEnabled = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppCheckDebugEnabled") as? Bool {
            return debugEnabled
        }
        // Default to true in DEBUG builds
        #if DEBUG
        return true
        #else
        return false
        #endif
        #endif
    }
    #endif
} 