import FirebaseAppCheck
import FirebaseCore

class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        // Use debug provider on simulator
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            // Use App Attest on real devices
            return AppAttestProvider(app: app)
        } else {
            // Fallback to DeviceCheck on older iOS
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
} 