import FirebaseAppCheck
import FirebaseCore

class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        // Use debug provider on simulator
        return AppCheckDebugProvider(app: app)
        #else
        // Use DeviceCheck on all real devices
        return DeviceCheckProvider(app: app)
        #endif
    }
} 