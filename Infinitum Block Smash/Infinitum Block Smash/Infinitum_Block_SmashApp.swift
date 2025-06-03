// MARK: - Imports
import SwiftUI
import GoogleMobileAds
import FirebaseCore
import AppTrackingTransparency
import AdSupport
import FirebaseAppCheck

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure AppCheck
        configureAppCheck()
        
        // Initialize AdMob
        MobileAds.shared.start { status in
            print("AdMob initialization status: \(status)")
        }
        
        // Request App Tracking Transparency on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("ATT status: \(status.rawValue)")
                }
            }
        }
        
        return true
    }
    
    // MARK: - AppCheck Configuration
    private func configureAppCheck() {
        #if os(macOS)
        // 🖥️ macOS: Use debug provider
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] Using DebugProvider for macOS")
        
        #elseif targetEnvironment(simulator)
        // 🧪 Simulator: Use debug provider
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] Using DebugProvider for Simulator")

        #elseif DEBUG
        if isTestFlight() {
            // 🧪 TestFlight build: Use debug provider
            let providerFactory = AppCheckDebugProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
            print("[AppCheck] Using DebugProvider for TestFlight")
        } else {
            // ✅ Development Device: Use real provider
            let providerFactory = DeviceCheckProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
            print("[AppCheck] Using DeviceCheckProvider for Development Device")
        }

        #else
        // 🚀 Production: Use DeviceCheck
        let providerFactory = DeviceCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] Using DeviceCheckProvider for Production")
        #endif
    }

    private func isTestFlight() -> Bool {
        #if DEBUG
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #else
        return false
        #endif
    }
}

// MARK: - Main App Entry Point
@main
struct Infinitum_Block_SmashApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showGame = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false

    // MARK: - Scene Definition
    var body: some Scene {
        WindowGroup {
            if userID.isEmpty {
                AuthView()
            } else {
                ContentView()
            }
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @Binding var showGame: Bool

    var body: some View {
        ZStack {
            Color(.systemIndigo).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text("Infinitum Block Smash")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 8)

                Spacer()

                Button(action: {
                    showGame = true
                }) {
                    Text("Play Classic")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                }

                Spacer()
            }
        }
    }
}
