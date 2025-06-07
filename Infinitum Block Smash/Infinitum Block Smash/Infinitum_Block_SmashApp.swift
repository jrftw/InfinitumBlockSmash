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
import UserNotifications
import BackgroundTasks

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Enable force logout
        ForceLogout.shared.isForceLogoutEnabled = true
        
        // Initialize Firebase on the main thread
        FirebaseApp.configure()
        
        // Configure Crashlytics
        #if !targetEnvironment(simulator)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
        
        // Configure AppCheck with proper provider
        configureAppCheck()
        
        // Initialize FirebaseManager to set up Firestore settings
        _ = FirebaseManager.shared
        
        // Configure Google Mobile Ads
        MobileAds.shared.start { status in
            print("Google Mobile Ads SDK initialization status: \(status)")
        }
        
        // Request App Tracking Transparency on first launch
        requestTrackingAuthorization()
        
        // Check notification permissions
        checkNotificationPermissions()
        
        // Check for updates immediately
        VersionCheckService.shared.checkForUpdates()
        
        // Configure background tasks
        configureBackgroundTasks()
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Handle discarded scenes if needed
    }
    
    private func requestTrackingAuthorization() {
        // Check if we've already requested tracking authorization
        let hasRequestedTracking = UserDefaults.standard.bool(forKey: "hasRequestedTracking")
        
        if !hasRequestedTracking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if #available(iOS 14, *) {
                    ATTrackingManager.requestTrackingAuthorization { status in
                        DispatchQueue.main.async {
                            // Save the tracking status
                            UserDefaults.standard.set(true, forKey: "hasRequestedTracking")
                            UserDefaults.standard.set(status == .authorized, forKey: "trackingAuthorized")
                            
                            // Update ad-related settings based on tracking status
                            if status == .authorized {
                                // Enable personalized ads
                                UserDefaults.standard.set(true, forKey: "allowAnalytics")
                                UserDefaults.standard.set(true, forKey: "allowDataSharing")
                            } else {
                                // Disable personalized ads
                                UserDefaults.standard.set(false, forKey: "allowAnalytics")
                                UserDefaults.standard.set(false, forKey: "allowDataSharing")
                            }
                            
                            print("ATT status: \(status.rawValue)")
                        }
                    }
                }
            }
        }
    }
    
    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // Request notification permission if not determined
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if granted {
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                                // Set all notification preferences to true by default
                                UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                                UserDefaults.standard.set(true, forKey: "eventNotifications")
                                UserDefaults.standard.set(true, forKey: "updateNotifications")
                                UserDefaults.standard.set(true, forKey: "reminderNotifications")
                                NotificationManager.shared.scheduleDailyReminder()
                            }
                        }
                    }
                case .denied:
                    // If notifications were denied, we'll show the permission request on next login
                    UserDefaults.standard.set(false, forKey: "notificationsEnabled")
                case .authorized, .provisional, .ephemeral:
                    // If notifications are authorized, ensure preferences are set to true
                    UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                    UserDefaults.standard.set(true, forKey: "eventNotifications")
                    UserDefaults.standard.set(true, forKey: "updateNotifications")
                    UserDefaults.standard.set(true, forKey: "reminderNotifications")
                    NotificationManager.shared.scheduleDailyReminder()
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func configureBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.infinitum.blocksmash.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleAppRefresh()
        
        // Set up an expiration handler
        task.expirationHandler = {
            // Cancel any ongoing work
            task.setTaskCompleted(success: false)
        }
        
        // Perform background work
        Task {
            do {
                // Attempt to sync data in background
                try await FirebaseManager.shared.syncDataInBackground()
                task.setTaskCompleted(success: true)
            } catch {
                print("[Background Refresh] Error syncing data: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.infinitum.blocksmash.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if ForcePublicVersion.shared.isEnabled {
                // Show the public version update prompt
                PublicVersionUpdateView()
            } else if VersionCheckService.shared.isUpdateRequired {
                // Show the regular update prompt
                UpdatePromptView(isTestFlight: VersionCheckService.shared.isTestFlight())
            } else {
                ContentView()
                    .environmentObject(gameState)
                    .onAppear {
                        // Check for force logout on app launch
                        if ForceLogout.shared.checkAndHandleForceLogout() {
                            // Force logout the user
                            userID = ""
                            username = ""
                            isGuest = false
                            try? Auth.auth().signOut()
                        }
                    }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // Save game state when app moves to background
                Task {
                    do {
                        try await gameState.saveProgress()
                        print("[App] Successfully saved game progress in background")
                    } catch {
                        print("[App] Error saving game progress in background: \(error.localizedDescription)")
                    }
                }
                // Notify game scene to pause animations
                NotificationCenter.default.post(name: NSNotification.Name("PauseBackgroundAnimations"), object: nil)
            case .inactive:
                // Save game state when app becomes inactive
                Task {
                    do {
                        try await gameState.saveProgress()
                        print("[App] Successfully saved game progress when inactive")
                    } catch {
                        print("[App] Error saving game progress when inactive: \(error.localizedDescription)")
                    }
                }
                // Notify game scene to pause animations
                NotificationCenter.default.post(name: NSNotification.Name("PauseBackgroundAnimations"), object: nil)
            case .active:
                // Resume animations
                NotificationCenter.default.post(name: NSNotification.Name("ResumeBackgroundAnimations"), object: nil)
            @unknown default:
                break
            }
        }
    }
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
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var gameState: GameState?
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save game state when app enters background
        guard let gameState = gameState else { return }
        
        Task {
            do {
                try await gameState.saveProgress()
                print("[Scene] Successfully saved game progress in background")
            } catch {
                print("[Scene] Error saving game progress in background: \(error.localizedDescription)")
            }
        }
    }
    
    func sceneWillTerminate(_ scene: UIScene) {
        // Save game state when app is about to terminate
        guard let gameState = gameState else { return }
        
        Task {
            do {
                try await gameState.saveProgress()
                print("[Scene] Successfully saved game progress before termination")
            } catch {
                print("[Scene] Error saving game progress before termination: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @Binding var showGame: Bool
    @State private var onlineUsersCount = 0
    
    var body: some View {
        ZStack {
            Color(.systemIndigo).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Infinitum Block Smash")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .shadow(radius: 8)
                    
                    Text(onlineUsersCountText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(radius: 4)
                }

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
        .onAppear {
            Task { @MainActor in
                onlineUsersCount = FirebaseManager.shared.getOnlineUsersCount()
            }
            NotificationCenter.default.addObserver(
                forName: .onlineUsersCountDidChange,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    onlineUsersCount = FirebaseManager.shared.getOnlineUsersCount()
                }
            }
        }
    }
    
    private var onlineUsersCountText: String {
        "\(onlineUsersCount) players online"
    }
}
