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
            Logger.shared.log("Failed to set debug token in environment", category: .appCheck, level: .warning)
            }
        }
        
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        Logger.shared.log("Using debug provider", category: .appCheck, level: .info)
        #else
        Logger.shared.log("Debug provider not available in release build", category: .appCheck, level: .info)
        #endif
    }
    
    static func configureProductionProvider() {
        let providerFactory = MyAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        Logger.shared.log("Using production AppCheckProviderFactory", category: .appCheck, level: .info)
    }
    
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        // Always use debug provider in simulator
        #if targetEnvironment(simulator)
        Logger.shared.log("Using debug provider in simulator", category: .appCheck, level: .info)
        return AppCheckDebugProvider(app: app)
        #else
        // In production, try App Attest first
        if #available(iOS 14.0, *) {
                let appAttestProvider = AppAttestProvider(app: app)
                Logger.shared.log("Using App Attest provider", category: .appCheck, level: .info)
                return appAttestProvider
        }
        
        // Fallback to DeviceCheck
        Logger.shared.log("Using DeviceCheck provider", category: .appCheck, level: .info)
        return DeviceCheckProvider(app: app)
        #endif
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    static func getDebugToken() -> String {
        // First try to get from environment
        if let envToken = ProcessInfo.processInfo.environment["FIREBASE_APP_CHECK_DEBUG_TOKEN"] {
            Logger.shared.log("Using debug token from environment", category: .appCheck, level: .info)
            return envToken
        }
        
        // Then try to get from Info.plist
        if let plistToken = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppCheckDebugToken") as? String {
            Logger.shared.log("Using debug token from Info.plist", category: .appCheck, level: .info)
            return plistToken
        }
        
        // Fallback to default token
        Logger.shared.log("Using default debug token", category: .appCheck, level: .info)
        return "CE67CA55-B0A6-4C0E-813D-ED8068E81657"
    }
    #endif
} 