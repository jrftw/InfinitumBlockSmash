import Foundation
import FirebaseAppCheck
import FirebaseCore
import DeviceCheck

class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    static func configureDebugProvider() {
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] Using debug AppCheckProviderFactory")
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
        if #available(iOS 14.0, *) {
            // Use DeviceCheck provider for iOS 14+
            return DeviceCheckProvider(app: app)
        } else {
            // Fallback to DeviceCheck provider for older iOS versions
            return DeviceCheckProvider(app: app)
        }
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    static func getDebugToken() -> String {
        return ProcessInfo.processInfo.environment["FIREBASE_APP_CHECK_DEBUG_TOKEN"] ?? "D605B88E-43B0-42C8-BBDE-718858DF4ED3"
    }
    
    static func isDebugMode() -> Bool {
        return ProcessInfo.processInfo.environment["FIREBASE_APP_CHECK_DEBUG"] == "true"
    }
    #endif
} 