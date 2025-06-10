import Foundation
import FirebaseAppCheck
import FirebaseCore
import DeviceCheck

class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    static func configureDebugProvider() {
        #if DEBUG
        // Set debug token in environment
        if let debugToken = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppCheckDebugToken") as? String {
            let setenvResult = setenv("FIREBASE_APP_CHECK_DEBUG_TOKEN", debugToken, 1)
            if setenvResult != 0 {
                print("[AppCheck] ⚠️ Failed to set debug token in environment")
            }
        }
        
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] 🔍 Using debug provider")
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
        // Always use debug provider in simulator
        #if targetEnvironment(simulator)
        print("[AppCheck] Using debug provider in simulator")
        return AppCheckDebugProvider(app: app)
        #else
        // In production, try App Attest first
        if #available(iOS 14.0, *) {
            do {
                let appAttestProvider = AppAttestProvider(app: app)
                print("[AppCheck] Using App Attest provider")
                return appAttestProvider
            } catch {
                print("[AppCheck] App Attest failed: \(error.localizedDescription)")
            }
        }
        
        // Fallback to DeviceCheck
        print("[AppCheck] Using DeviceCheck provider")
        return DCAppAttestProvider(app: app)
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
        return "CE67CA55-B0A6-4C0E-813D-ED8068E81657"
    }
    #endif
} 