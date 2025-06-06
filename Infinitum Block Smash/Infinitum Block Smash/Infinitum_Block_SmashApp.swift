// MARK: - Imports
import SwiftUI
import GoogleMobileAds
import FirebaseCore
import AppTrackingTransparency
import AdSupport
import FirebaseAppCheck
import FirebaseCrashlytics
import FirebaseAuth
import FirebaseFirestore

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase on the main thread
        FirebaseApp.configure()
        
        // Configure AppCheck
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        // Configure Google Mobile Ads
        MobileAds.shared.start { status in
            print("Google Mobile Ads SDK initialization status: \(status)")
        }
        
        // Request App Tracking Transparency on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("ATT status: \(status.rawValue)")
                }
            }
        }
        
        // Check for updates immediately
        VersionCheckService.shared.checkForUpdates()
        
        return true
    }
    
    // MARK: - AppCheck Configuration
    private func configureAppCheck() {
        let providerFactory = MyAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] Using custom AppCheckProviderFactory")
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
    @StateObject private var gameState = GameState()
    
    var body: some Scene {
        WindowGroup {
            if VersionCheckService.shared.isUpdateRequired {
                // Show a loading view while checking for updates
                LoadingView()
            } else {
                ContentView()
                    .environmentObject(gameState)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // Save game state when app moves to background
                do {
                    try gameState.saveProgress()
                    print("[App] Successfully saved game progress in background")
                } catch {
                    print("[App] Error saving game progress in background: \(error.localizedDescription)")
                }
                // Notify game scene to pause animations
                NotificationCenter.default.post(name: NSNotification.Name("PauseBackgroundAnimations"), object: nil)
            case .inactive:
                // Save game state when app becomes inactive
                do {
                    try gameState.saveProgress()
                    print("[App] Successfully saved game progress when inactive")
                } catch {
                    print("[App] Error saving game progress when inactive: \(error.localizedDescription)")
                }
                // Notify game scene to pause animations
                NotificationCenter.default.post(name: NSNotification.Name("PauseBackgroundAnimations"), object: nil)
            case .active:
                // App became active
                print("[App] App became active")
                // Notify game scene to resume animations
                NotificationCenter.default.post(name: NSNotification.Name("ResumeBackgroundAnimations"), object: nil)
            @unknown default:
                break
            }
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking for updates...")
                .padding()
        }
    }
}

// MARK: - SceneDelegate
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var gameState: GameState?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save game state when app moves to background
        if let gameState = gameState {
            do {
                try gameState.saveProgress()
                print("[SceneDelegate] Successfully saved game progress")
            } catch {
                print("[SceneDelegate] Error saving game progress: \(error.localizedDescription)")
            }
        }
    }
    
    func sceneWillTerminate(_ scene: UIScene) {
        // Save game state when app is about to terminate
        if let gameState = gameState {
            do {
                try gameState.saveProgress()
                print("[SceneDelegate] Successfully saved game progress before termination")
            } catch {
                print("[SceneDelegate] Error saving game progress before termination: \(error.localizedDescription)")
            }
        }
    }
    
    var window: UIWindow?
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
