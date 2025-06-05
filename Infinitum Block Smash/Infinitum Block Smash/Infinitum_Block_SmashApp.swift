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
        
        // Check for updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            VersionCheckService.shared.checkForUpdates()
        }
        
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
    @State private var showGame = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Scene Definition
    var body: some Scene {
        WindowGroup {
            if userID.isEmpty {
                AuthView()
            } else {
                ContentView()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                // Save game state when app moves to background
                if let gameState = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.gameState {
                    do {
                        try gameState.saveProgress()
                    } catch {
                        print("[App] Error saving game progress: \(error.localizedDescription)")
                    }
                }
            }
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
