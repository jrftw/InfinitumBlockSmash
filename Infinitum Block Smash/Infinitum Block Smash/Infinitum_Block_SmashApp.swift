/*
 * Infinitum_Block_SmashApp.swift
 * 
 * MAIN APPLICATION ENTRY POINT
 * 
 * This is the primary SwiftUI app file that serves as the entry point for the Infinitum Block Smash game.
 * It handles all app-level initialization, configuration, and lifecycle management.
 * 
 * KEY RESPONSIBILITIES:
 * - App lifecycle management (launch, background, foreground)
 * - Firebase configuration and initialization
 * - Third-party service setup (Game Center, Analytics, Ads, etc.)
 * - Push notification handling
 * - App tracking transparency
 * - Background task registration
 * - Authentication state monitoring
 * 
 * MAJOR DEPENDENCIES:
 * - FirebaseManager.swift: Core Firebase operations and data management
 * - StartupManager.swift: App startup sequence coordination
 * - ForceLogout.swift: Version migration and forced logout handling
 * - VersionCheckService.swift: App update checking
 * - NotificationManager.swift: Push notification management
 * - GameCenterManager.swift: Game Center integration
 * - AdManager.swift: Advertisement management
 * - AnalyticsManager.swift: Analytics tracking
 * 
 * EXTERNAL FRAMEWORKS:
 * - SwiftUI: Main UI framework
 * - Firebase: Backend services (Auth, Firestore, Analytics, etc.)
 * - GoogleMobileAds: Advertisement integration
 * - GameKit: Game Center features
 * - StoreKit: In-app purchases
 * - UserNotifications: Push notifications
 * - BackgroundTasks: Background processing
 * 
 * ARCHITECTURE ROLE:
 * This file acts as the "bootstrap" layer that initializes all core services
 * before the main UI is presented. It ensures all dependencies are properly
 * configured and ready before the user interacts with the app.
 * 
 * CRITICAL INITIALIZATION ORDER:
 * 1. Firebase configuration
 * 2. App Check setup
 * 3. Analytics and Performance monitoring
 * 4. Remote Config setup
 * 5. Push notification configuration
 * 6. Game Center authentication
 * 7. Firestore and RTDB persistence
 * 8. Core manager initialization
 * 9. Background task registration
 * 10. Tracking authorization request
 */

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
import FirebaseAnalytics
import DeviceCheck
import FirebaseRemoteConfig
import FirebasePerformance
import FirebaseMessaging
import StoreKit
import FirebaseDatabase

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // First, configure Firebase
        FirebaseApp.configure()
        #if DEBUG
        print("[Firebase] Successfully configured Firebase")
        #endif
        
        // Then configure App Check based on environment
        #if targetEnvironment(simulator)
        // Use debug provider in Simulator
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #if DEBUG
        print("[AppCheck] Using debug provider for simulator")
        #endif
        #else
        // Use DeviceCheck provider for all non-simulator environments
        let providerFactory = DeviceCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #if DEBUG
        print("[AppCheck] Using DeviceCheck provider")
        #endif
        #endif
        
        // Enable token auto-refresh
        AppCheck.appCheck().isTokenAutoRefreshEnabled = true
        
        // Configure Firebase Analytics
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Configure Firebase Performance
        Performance.sharedInstance().isDataCollectionEnabled = true
        
        // Configure Firebase Remote Config
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        // Configure Firebase Messaging
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        // Configure Game Center
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let error = error {
                #if DEBUG
                print("Game Center authentication error: \(error.localizedDescription)")
                #endif
            }
        }
        
        // Configure Firestore settings before any Firestore operations
        let settingsFirestore = FirestoreSettings()
        settingsFirestore.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        Firestore.firestore().settings = settingsFirestore
        #if DEBUG
        print("[Firebase] Firestore settings configured")
        #endif
        
        // Now configure RTDB persistence
        Database.database().isPersistenceEnabled = true
        #if DEBUG
        print("[Firebase] RTDB persistence enabled")
        #endif
        
        // Initialize FirebaseManager
        _ = FirebaseManager.shared
        #if DEBUG
        print("[Firebase] FirebaseManager initialized")
        #endif
        
        // Only enable force logout for specific version migrations
        if ForceLogout.shared.shouldEnableForceLogout() {
            ForceLogout.shared.isForceLogoutEnabled = true
            #if DEBUG
            print("[Firebase] Force logout enabled for version migration")
            #endif
        }
        
        // Configure In-App Messaging
        configureInAppMessaging()
        
        // Configure Firebase Messaging
        configureFirebaseMessaging(application)
        
        // Configure Analytics
        configureAnalytics()
        
        // Configure Crashlytics
        configureCrashlytics()
        
        // Configure background tasks
        configureBackgroundTasks()
        
        // Add auth state listener
        _ = Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                #if DEBUG
                print("[Firebase] User is signed in with uid: \(user.uid)")
                #endif
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
                        #if DEBUG
                        print("[Firebase] Successfully updated last login time for user: \(user.uid)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("[Firebase] Error updating last login: \(error)")
                        #endif
                    }
                }
            } else {
                #if DEBUG
                print("[Firebase] User is signed out")
                #endif
            }
        }
        
        // Configure Google Mobile Ads
        MobileAds.shared.start { status in
            #if DEBUG
            print("Google Mobile Ads SDK initialization status: \(status)")
            #endif
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
        // Let NotificationService handle the permission check
        NotificationService.shared.checkNotificationStatus()
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
            if GKLocalPlayer.local.isAuthenticated {
                print("[GameCenter] Player authenticated successfully")
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
        #if DEBUG
        print("[Analytics] ✅ Analytics collection enabled")
        
        // Log app open event
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        print("[Analytics] ✅ Logged app open event")
        #else
        // In release builds, only log critical app events
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        #endif
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
        
        #if DEBUG
        print("[Crashlytics] Crash reporting is \(UserDefaults.standard.bool(forKey: "allowCrashReports") ? "enabled" : "disabled")")
        #endif
    }

    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
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
    @StateObject private var startupManager = StartupManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if !startupManager.isReady {
                LaunchLoadingView()
            } else if ForcePublicVersion.shared.isEnabled {
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
