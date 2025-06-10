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
import FirebaseInAppMessaging
import UserNotifications
import BackgroundTasks
import GameKit
import FirebaseDatabase
import FirebaseAnalytics
import DeviceCheck

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure AppCheck first with debug token
        #if DEBUG
        // Set debug token in environment
        let debugToken = "CE67CA55-B0A6-4C0E-813D-ED8068E81657"
        let setenvResult = setenv("FIREBASE_APP_CHECK_DEBUG_TOKEN", debugToken, 1)
        let setenvSuccess = setenvResult == 0
        if !setenvSuccess {
            print("[AppCheck] ⚠️ Failed to set debug token in environment")
        }
        
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] 🔍 Using debug provider with token: \(debugToken)")
        
        // Verify debug token is set
        if let debugToken = ProcessInfo.processInfo.environment["FIREBASE_APP_CHECK_DEBUG_TOKEN"] {
            print("[AppCheck] ✅ Debug token from environment: \(debugToken)")
        } else if let debugToken = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppCheckDebugToken") as? String {
            print("[AppCheck] ✅ Debug token from Info.plist: \(debugToken)")
        } else {
            print("[AppCheck] ⚠️ WARNING: No debug token found!")
        }
        #else
        // For production builds, use Device Check as fallback
        let providerFactory = DeviceCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AppCheck] ✅ Using Device Check provider")
        #endif
        
        // Configure Firebase after AppCheck
        FirebaseApp.configure()
        print("[Firebase] ✅ Firebase configured successfully")
        
        
        // Configure Firestore settings before any Firestore operations
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        Firestore.firestore().settings = settings
        print("[Firebase] Firestore settings configured")
        
        // Now configure RTDB persistence
        Database.database().isPersistenceEnabled = true
        print("[Firebase] RTDB persistence enabled")
        
        // Initialize FirebaseManager
        _ = FirebaseManager.shared
        print("[Firebase] FirebaseManager initialized")
        
        // Enable force logout
        ForceLogout.shared.isForceLogoutEnabled = true
        
        // Configure In-App Messaging
        configureInAppMessaging()
        
        // Configure Game Center
        configureGameCenter()
        
        // Configure Firebase Messaging
        configureFirebaseMessaging(application)
        
        // Configure Analytics
        configureAnalytics()
        
        // Configure Crashlytics
        configureCrashlytics()
        
        // Configure background tasks
        configureBackgroundTasks()
        
        print("[Firebase] Successfully configured Firebase")
        
        // Add auth state listener
        _ = Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                print("[Firebase] User is signed in with uid: \(user.uid)")
                // Update last login time
                Task {
                    do {
                        try await Firestore.firestore()
                            .collection("users")
                            .document(user.uid)
                            .updateData([
                                "lastLogin": FieldValue.serverTimestamp(),
                                "lastActive": FieldValue.serverTimestamp()
                            ])
                        print("[Firebase] Successfully updated last login time for user: \(user.uid)")
                    } catch {
                        print("[Firebase] Error updating last login: \(error)")
                    }
                }
            } else {
                print("[Firebase] User is signed out")
            }
        }
        
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
        print("[ATT] Starting tracking authorization request")
        
        // Check if we've already requested tracking authorization
        let hasRequestedTracking = UserDefaults.standard.bool(forKey: "hasRequestedTracking")
        print("[ATT] Has requested tracking before: \(hasRequestedTracking)")
        
        if !hasRequestedTracking {
            // Ensure we're on the main thread and the app is active
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active {
                    print("[ATT] App is active, requesting authorization")
                    if #available(iOS 14, *) {
                        ATTrackingManager.requestTrackingAuthorization { status in
                            DispatchQueue.main.async {
                                print("[ATT] Authorization status received: \(status.rawValue)")
                                
                                // Save the tracking status
                                UserDefaults.standard.set(true, forKey: "hasRequestedTracking")
                                UserDefaults.standard.set(status == .authorized, forKey: "trackingAuthorized")
                                
                                // Update ad-related settings based on tracking status
                                if status == .authorized {
                                    // Enable personalized ads
                                    UserDefaults.standard.set(true, forKey: "allowAnalytics")
                                    UserDefaults.standard.set(true, forKey: "allowDataSharing")
                                    print("[ATT] Tracking authorized, enabling personalized ads")
                                } else {
                                    // Disable personalized ads
                                    UserDefaults.standard.set(false, forKey: "allowAnalytics")
                                    UserDefaults.standard.set(false, forKey: "allowDataSharing")
                                    print("[ATT] Tracking not authorized, disabling personalized ads")
                                }
                            }
                        }
                    } else {
                        print("[ATT] iOS version below 14, skipping tracking request")
                    }
                } else {
                    print("[ATT] App not active, will retry when app becomes active")
                    // Schedule the request for when the app becomes active
                    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                        self.requestTrackingAuthorization()
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
            await handleAppRefresh()
            task.setTaskCompleted(success: true)
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
    
    func handleAppRefresh() async {
        do {
            try await FirebaseManager.shared.syncDataInBackground()
        } catch {
            print("Error syncing data in background: \(error)")
        }
    }
    
    // MARK: - In-App Messaging Configuration
    private func configureInAppMessaging() {
        InAppMessaging.inAppMessaging().automaticDataCollectionEnabled = true
        InAppMessaging.inAppMessaging().messageDisplaySuppressed = false
        
        // Set up message display delegate
        InAppMessaging.inAppMessaging().delegate = self
    }
    
    // MARK: - Game Center Configuration
    private func configureGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                // Present the view controller if needed
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(viewController, animated: true)
                }
            } else if GKLocalPlayer.local.isAuthenticated {
                print("[GameCenter] Player authenticated successfully")
                // Use the modern Game Center authentication approach
                GameCenterAuthProvider.getCredential { credential, error in
                    if let error = error {
                        print("Failed to get Game Center credential: \(error)")
                        return
                    }
                    
                    guard let credential = credential else {
                        print("No Game Center credential available")
                        return
                    }
                    
                    Auth.auth().signIn(with: credential) { authResult, error in
                        if let error = error {
                            print("Firebase Game Center sign-in failed: \(error)")
                        } else {
                            print("Firebase Game Center sign-in succeeded!")
                        }
                    }
                }
                // Initialize Game Center manager
                _ = GameCenterManager.shared
            } else if let error = error {
                print("[GameCenter] Authentication error: \(error.localizedDescription)")
            }
        }
    }

    private func isTestFlight() -> Bool {
        #if DEBUG
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #else
        return false
        #endif
    }

    // MARK: - Firebase Messaging Configuration
    private func configureFirebaseMessaging(_ application: UIApplication) {
        // Implementation of configureFirebaseMessaging method
    }

    // MARK: - Analytics Configuration
    private func configureAnalytics() {
        // Configure Analytics
        Analytics.setAnalyticsCollectionEnabled(true)
        print("[Analytics] ✅ Analytics collection enabled")
        
        // Log app open event
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        print("[Analytics] ✅ Logged app open event")
    }

    // MARK: - Crashlytics Configuration
    private func configureCrashlytics() {
        // Set default value for allowCrashReports if not set
        if UserDefaults.standard.object(forKey: "allowCrashReports") == nil {
            UserDefaults.standard.set(true, forKey: "allowCrashReports")
        }
        
        // Configure Crashlytics
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(UserDefaults.standard.bool(forKey: "allowCrashReports"))
        
        // Add observer for when the setting changes
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(UserDefaults.standard.bool(forKey: "allowCrashReports"))
        }
        
        print("[Crashlytics] Crash reporting is \(UserDefaults.standard.bool(forKey: "allowCrashReports") ? "enabled" : "disabled")")
    }
}

// MARK: - InAppMessagingDelegate
extension AppDelegate: InAppMessagingDisplayDelegate {
    func messageClicked(_ inAppMessage: InAppMessagingDisplayMessage, with action: InAppMessagingAction) {
        print("[InAppMessaging] Message clicked: \(inAppMessage.campaignInfo.campaignName)")
    }
    
    func messageDismissed(_ inAppMessage: InAppMessagingDisplayMessage, dismissType: InAppMessagingDismissType) {
        print("[InAppMessaging] Message dismissed: \(inAppMessage.campaignInfo.campaignName)")
    }
    
    func impressionDetected(for inAppMessage: InAppMessagingDisplayMessage) {
        print("[InAppMessaging] Impression detected: \(inAppMessage.campaignInfo.campaignName)")
    }
    
    func displayError(for inAppMessage: InAppMessagingDisplayMessage, error: Error) {
        print("[InAppMessaging] Display error: \(error.localizedDescription)")
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
            updateOnlineUsersCount()
            NotificationCenter.default.addObserver(
                forName: .onlineUsersCountDidChange,
                object: nil,
                queue: .main
            ) { _ in
                updateOnlineUsersCount()
            }
        }
    }
    
    private func updateOnlineUsersCount() {
        Task { @MainActor in
            do {
                onlineUsersCount = try await FirebaseManager.shared.getOnlineUsersCount()
            } catch {
                print("Error getting online users count: \(error)")
                onlineUsersCount = 0
            }
        }
    }
    
    private var onlineUsersCountText: String {
        "\(onlineUsersCount) players online"
    }
}
