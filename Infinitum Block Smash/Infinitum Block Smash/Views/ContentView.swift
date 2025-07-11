/*
 * ContentView.swift
 * 
 * MAIN NAVIGATION AND MENU INTERFACE
 * 
 * This is the primary navigation view that serves as the main menu and entry point
 * for the Infinitum Block Smash game. It handles user authentication, game mode
 * selection, and navigation to various app features and settings.
 * 
 * KEY RESPONSIBILITIES:
 * - Main menu interface and navigation
 * - User authentication state management
 * - Game mode selection and routing
 * - Saved game management and resumption
 * - User statistics and leaderboard access
 * - Settings and configuration access
 * - Store and premium feature access
 * - Announcements and notifications display
 * - User profile and information management
 * - Advertisement integration for non-premium users
 * 
 * MAJOR DEPENDENCIES:
 * - AuthView.swift: User authentication interface
 * - GameView.swift: Main game interface
 * - GameModeSelectionView.swift: Game mode selection
 * - LeaderboardView.swift: Leaderboard display
 * - StatsView.swift: Statistics and analytics
 * - SettingsView.swift: App settings and configuration
 * - StoreView.swift: In-app purchase interface
 * - AnnouncementsView.swift: App announcements
 * - ChangeInformationView.swift: User profile editing
 * - BannerAdView.swift: Advertisement display
 * - RatingPromptView.swift: App rating prompts
 * - ReferralPromptView.swift: Referral system
 * 
 * NAVIGATION FEATURES:
 * - Conditional navigation based on authentication
 * - Saved game detection and resumption
 * - Game mode selection routing
 * - Modal presentation for various features
 * - Deep linking support for specific features
 * - Navigation state management
 * 
 * USER INTERFACE COMPONENTS:
 * - App branding and logo display
 * - Menu button system with icons
 * - User statistics display
 * - Online player count indicators
 * - Advertisement banner for non-premium users
 * - Rating and referral prompts
 * - Loading states and transitions
 * 
 * AUTHENTICATION INTEGRATION:
 * - User login/logout state management
 * - Guest user support
 * - Authentication flow coordination
 * - User data synchronization
 * - Cross-device authentication
 * 
 * GAME STATE MANAGEMENT:
 * - Saved game detection and loading
 * - Game progress synchronization
 * - Cloud data loading and caching
 * - Game state persistence
 * - Progress restoration
 * 
 * PREMIUM FEATURE INTEGRATION:
 * - Top player advertisement exemption
 * - Premium feature access control
 * - Subscription status checking
 * - Store access and purchase flow
 * - Premium content unlocking
 * 
 * PERFORMANCE FEATURES:
 * - Lazy loading of heavy components
 * - Efficient state management
 * - Background data synchronization
 * - Memory-efficient navigation
 * - Optimized advertisement loading
 * 
 * USER EXPERIENCE:
 * - Intuitive navigation flow
 * - Clear visual hierarchy
 * - Responsive interface design
 * - Accessibility support
 * - Smooth transitions and animations
 * 
 * ANALYTICS AND TRACKING:
 * - User engagement metrics
 * - Feature usage tracking
 * - Navigation flow analysis
 * - User retention monitoring
 * - Performance analytics
 * 
 * ARCHITECTURE ROLE:
 * This view acts as the main coordinator for user navigation and app flow,
 * providing a central hub for accessing all major app features while
 * managing authentication and user state.
 * 
 * THREADING CONSIDERATIONS:
 * - UI updates on main thread
 * - Background data loading
 * - Async/await for network operations
 * - State management with Combine
 * 
 * INTEGRATION POINTS:
 * - Authentication system
 * - Game state management
 * - Advertisement system
 * - Analytics and tracking
 * - Push notifications
 * - In-app purchases
 */

import SwiftUI
import GoogleMobileAds
import FirebaseAuth

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @State private var showingTutorial = false
    @State private var showingLeaderboard = false
    @State private var showingSettings = false
    @State private var showingChangeInfo = false
    @State private var showingGameView = false
    @State private var showingAuth = false
    @State private var showingStats = false
    @State private var showingLeaderboardAlert = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false
    @State private var showingNewGameConfirmation = false
    @State private var showingStore = false
    @State private var showingClassicTimedView = false
    @State private var showingAnnouncements = false
    @StateObject private var authViewModel = AuthViewModel()
    @State private var onlineUsersCount = 0
    @State private var dailyPlayersCount = 0
    @State private var totalPlayersCount = 0
    @State private var showingGameModeSelection = false
    @State private var isTopThreePlayer = false
    @StateObject private var appOpenManager = AppOpenManager.shared
    @State private var showingDeviceSimulation = false
    @State private var showingDebugManager = false
    @State private var onlineUsersObserver: NSObjectProtocol?
    @State private var dailyPlayersObserver: NSObjectProtocol?
    @State private var showingGuestPlayAlert = false
    @State private var showingProfileCompletion = false
    @State private var showingGuestSignInAlert = false
    
    var isLoggedIn: Bool {
        !userID.isEmpty && (!username.isEmpty || isGuest)
    }
    
    // Add profile completion check
    private var needsProfileCompletion: Bool {
        guard !isGuest else { return false }
        let email = Auth.auth().currentUser?.email ?? ""
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        return email.isEmpty || username.isEmpty || username == "unknown"
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.2, blue: 0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if isLoggedIn {
                VStack(spacing: 8) {
                    // App Icon
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.top, 4)
                    
                    // App Title
                    VStack(spacing: 2) {
                        Text("Infinitum Block Smash")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        
                        // Version indicator
                        if AppVersion.shouldShowEnvironmentBadge {
                            Text(AppVersion.buildEnvironment)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        HStack(spacing: 12) {
                            Text(onlineUsersCountText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            
                            Text("•")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(dailyPlayersCountText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            
                            Text("•")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(totalPlayersCountText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }
                    }
                    
                    // Menu Buttons
                    VStack(spacing: 10) {
                        if gameState.hasSavedGame() {
                            MenuButton(title: "Resume Game", icon: "play.fill", onDelete: {
                                if !isGuest {
                                    gameState.deleteSavedGame()
                                }
                            }) {
                                if isGuest {
                                    showingGuestSignInAlert = true
                                } else {
                                    handleMainMenuInteraction()
                                    // Load the saved game when Resume is clicked
                                    Task {
                                        do {
                                            try await gameState.loadSavedGame()
                                            Logger.shared.log("Successfully loaded saved game", category: .gameState, level: .info)
                                            
                                            // Check if it's a timed mode game and show appropriate view
                                            if UserDefaults.standard.bool(forKey: "isTimedMode") {
                                                showingClassicTimedView = true
                                            } else {
                                                showingGameView = true
                                            }
                                        } catch {
                                            Logger.shared.log("Error loading saved game: \(error.localizedDescription)", category: .gameState, level: .error)
                                            // If loading fails, clean up the invalid save and start a fresh game
                                            gameState.deleteSavedGame()
                                            gameState.resetGame()
                                            showingGameView = true
                                        }
                                    }
                                }
                            }
                            .opacity(isGuest ? 0.5 : 1.0)
                        }
                        
                        // Play Button (replaces Game Modes)
                        MenuButton(title: "Play", icon: "gamecontroller.fill") {
                            if isGuest {
                                showingGuestSignInAlert = true
                            } else {
                                handleMainMenuInteraction()
                                // Check if there's a saved game and ask for confirmation
                                if gameState.hasSavedGame() {
                                    showingNewGameConfirmation = true
                                } else {
                                    showingGameModeSelection = true
                                }
                            }
                        }
                        .opacity(isGuest ? 0.5 : 1.0)
                        
                        MenuButton(title: "Leaderboard", icon: "trophy.fill") {
                            if isGuest {
                                showingGuestSignInAlert = true
                            } else {
                                handleMainMenuInteraction()
                                handleLeaderboardAccess()
                            }
                        }
                        .opacity(isGuest ? 0.5 : 1.0)
                        
                        MenuButton(title: "Statistics", icon: "chart.bar.fill") {
                            if isGuest {
                                showingGuestSignInAlert = true
                            } else {
                                handleMainMenuInteraction()
                                showingStats = true
                            }
                        }
                        .opacity(isGuest ? 0.5 : 1.0)
                        
                        MenuButton(title: "Change Information", icon: "person.fill") {
                            if isGuest {
                                showingGuestSignInAlert = true
                            } else {
                                handleMainMenuInteraction()
                                showingChangeInfo = true
                            }
                        }
                        .opacity(isGuest ? 0.5 : 1.0)
                        
                        MenuButton(title: "Store", icon: "cart.fill") {
                            if isGuest {
                                showingGuestSignInAlert = true
                            } else {
                                handleMainMenuInteraction()
                                showingStore = true
                            }
                        }
                        .opacity(isGuest ? 0.5 : 1.0)
                        
                        MenuButton(title: "Announcements", icon: "bell.fill") {
                            if isGuest {
                                showingGuestSignInAlert = true
                            } else {
                                handleMainMenuInteraction()
                                showingAnnouncements = true
                            }
                        }
                        .opacity(isGuest ? 0.5 : 1.0)
                        
                        MenuButton(title: "Settings", icon: "gear") {
                            if isGuest {
                                showingGuestSignInAlert = true
                            } else {
                                handleMainMenuInteraction()
                                showingSettings = true
                            }
                        }
                        .opacity(isGuest ? 0.5 : 1.0)
                        
                        // Device Simulation Debug (only in simulator and debug mode)
                        #if targetEnvironment(simulator)
                        if DebugManager.shouldShowDebugFeatures && DebugManager.shouldEnableDeviceSimulation {
                            MenuButton(title: "Device Simulation", icon: "iphone") {
                                if isGuest {
                                    showingGuestSignInAlert = true
                                } else {
                                    handleMainMenuInteraction()
                                    showingDeviceSimulation = true
                                }
                            }
                            .opacity(isGuest ? 0.5 : 1.0)
                        }
                        #endif
                        
                        // Debug Manager (only in debug builds)
                        #if DEBUG
                        if DebugManager.shouldShowDebugFeatures {
                            MenuButton(title: "Debug Manager", icon: "wrench.and.screwdriver") {
                                if isGuest {
                                    showingGuestSignInAlert = true
                                } else {
                                    handleMainMenuInteraction()
                                    showingDebugManager = true
                                }
                            }
                            .opacity(isGuest ? 0.5 : 1.0)
                        }
                        #endif
                        
                        MenuButton(title: "Log Out", icon: "rectangle.portrait.and.arrow.right") {
                            handleMainMenuInteraction()
                            userID = ""
                            username = ""
                            isGuest = false
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: userID) { newValue in
                    if !newValue.isEmpty {
                        // FIXED: Skip Firebase loading if we're resuming a local game
                        if !gameState.isResumingGame {
                            // User logged in, load cloud data
                            Task {
                                await gameState.loadCloudData()
                            }
                        } else {
                            print("[ContentView] Skip Firebase load: Local save already restored")
                        }
                    }
                }
            } else {
                AuthView()
            }
            
            VStack {
                Spacer()
                if !isTopThreePlayer {
                    HStack {
                        Spacer()
                        BannerAdView()
                            .frame(width: 320, height: 50)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.1))
                }
            }
            
            // Add rating and referral prompts
            if appOpenManager.showingRatingPrompt {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        RatingPromptView(isPresented: $appOpenManager.showingRatingPrompt)
                            .onDisappear {
                                appOpenManager.markRatingAsShown()
                            }
                    )
                    .transition(.opacity)
            }
            
            if appOpenManager.showingReferralPrompt {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        ReferralPromptView()
                            .onDisappear {
                                appOpenManager.markReferralAsShown()
                            }
                    )
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Check if user needs to complete profile
            if isLoggedIn && needsProfileCompletion {
                showingProfileCompletion = true
            }
            
            // Connect GameState to SceneDelegate
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                sceneDelegate.gameState = gameState
            }
            
            // Check for inactivity ad
            Task {
                await AdManager.shared.showInactivityAd()
            }
            
            setupOnlineUsersTracking()
            setupDailyPlayersTracking()
            updateTotalPlayersCount()
            
            // Check top three status when view appears
            Task {
                await AdManager.shared.checkTopThreeStatus()
            }
            
            // Fetch leaderboard high score when main menu appears (not during gameplay)
            Task {
                await gameState.fetchLeaderboardHighScore()
            }
        }
        .onDisappear {
            cleanup()
        }
        .fullScreenCover(isPresented: $showingGameView) {
            GameView(gameState: gameState)
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(gameState: gameState, showingTutorial: $showingTutorial)
        }
        .fullScreenCover(isPresented: $showingChangeInfo) {
            ChangeInformationView()
        }
        .fullScreenCover(isPresented: $showingAuth) {
            AuthView()
        }
        .sheet(isPresented: $showingStats) {
            StatsView(gameState: gameState)
        }
        .sheet(isPresented: $showingStore) {
            StoreView()
        }
        .fullScreenCover(isPresented: $showingClassicTimedView) {
            ClassicTimedGameView(gameState: gameState)
        }
        .sheet(isPresented: $showingAnnouncements) {
            AnnouncementsView()
        }
        .sheet(isPresented: $showingDeviceSimulation) {
            DeviceSimulationDebugView()
        }
        .sheet(isPresented: $showingDebugManager) {
            DebugManagerView()
        }
        .sheet(isPresented: $showingProfileCompletion) {
            ProfileCompletionView()
        }
        .alert("Start New Game?", isPresented: $showingNewGameConfirmation) {
            Button("No", role: .cancel) { }
            Button("Yes", role: .destructive) {
                gameState.startNewGame()
                showingGameModeSelection = true
            }
        } message: {
            Text("This will delete your saved game and start a new one. Are you sure?")
        }
        .alert("Sign in Required", isPresented: $showingLeaderboardAlert) {
            Button("Sign In") {
                showingAuth = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Sign in or create an account to view the leaderboard")
        }
        .alert("Sign in Required", isPresented: $showingGuestSignInAlert) {
            Button("Sign In") {
                showingAuth = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Sign in or create an account to view this feature")
        }
        .fullScreenCover(isPresented: $showingGameModeSelection) {
            GameModeSelectionView(
                onClassic: {
                    UserDefaults.standard.set(false, forKey: "isTimedMode")
                    showingGameModeSelection = false
                    // Only start a new game if we're not resuming a game
                    if !gameState.isResumingGame {
                        gameState.startNewGame()
                    }
                    showingGameView = true
                },
                onClassicTimed: {
                    UserDefaults.standard.set(true, forKey: "isTimedMode")
                    showingGameModeSelection = false
                    // Only start a new game if we're not resuming a game
                    if !gameState.isResumingGame {
                        gameState.startNewGame()
                    }
                    showingClassicTimedView = true
                }
            )
        }
    }
    
    private func handleMainMenuInteraction() {
        AdManager.shared.recordMainMenuInteraction()
        
        // Check for main menu ad after interaction
        Task {
            await AdManager.shared.showMainMenuAd()
        }
    }
    
    private func handleLeaderboardAccess() {
        if isGuest {
            showingLeaderboardAlert = true
        } else {
            showingLeaderboard = true
        }
    }
    
    private func setupOnlineUsersTracking() {
        // Set initial count
        updateOnlineUsersCount()

        // Observe changes with proper observer storage
        onlineUsersObserver = NotificationCenter.default.addObserver(
            forName: .onlineUsersCountDidChange,
            object: nil,
            queue: .main
        ) { _ in
            updateOnlineUsersCount()
        }
    }
    
    private func setupDailyPlayersTracking() {
        // Set initial count
        updateDailyPlayersCount()

        // Observe changes with proper observer storage
        dailyPlayersObserver = NotificationCenter.default.addObserver(
            forName: .dailyPlayersCountDidChange,
            object: nil,
            queue: .main
        ) { _ in
            updateDailyPlayersCount()
        }
    }
    
    private func updateTotalPlayersCount() {
        Task { @MainActor in
            do {
                totalPlayersCount = try await FirebaseManager.shared.getTotalPlayersCount()
            } catch {
                Logger.shared.log("Error getting total players count: \(error)", category: .firebaseManager, level: .error)
                totalPlayersCount = 0
            }
        }
    }
    
    private func cleanup() {
        // Remove specific observers instead of removing all
        if let observer = onlineUsersObserver {
            NotificationCenter.default.removeObserver(observer)
            onlineUsersObserver = nil
        }
        if let observer = dailyPlayersObserver {
            NotificationCenter.default.removeObserver(observer)
            dailyPlayersObserver = nil
        }
    }
    
    private func updateOnlineUsersCount() {
        Task { @MainActor in
            do {
                onlineUsersCount = try await FirebaseManager.shared.getOnlineUsersCount()
            } catch {
                Logger.shared.log("Error getting online users count: \(error)", category: .firebaseManager, level: .error)
                onlineUsersCount = 0
            }
        }
    }
    
    private func updateDailyPlayersCount() {
        Task { @MainActor in
            do {
                dailyPlayersCount = try await FirebaseManager.shared.getDailyPlayersCount()
            } catch {
                Logger.shared.log("Error getting daily players count: \(error)", category: .firebaseManager, level: .error)
                dailyPlayersCount = 0
            }
        }
    }
    
    private var onlineUsersCountText: String {
        "\(onlineUsersCount) players online"
    }
    
    private var dailyPlayersCountText: String {
        "\(dailyPlayersCount) players today"
    }
    
    private var totalPlayersCountText: String {
        "\(totalPlayersCount) total players"
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    var onDelete: (() -> Void)? = nil
    let action: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button
            if onDelete != nil {
                Button(action: {
                    withAnimation(.spring()) {
                        onDelete?()
                        offset = 0
                        isSwiped = false
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 90, height: 50)
                        .background(Color.red)
                        .cornerRadius(15)
                }
                .opacity(isSwiped ? 1 : 0)
                .padding(.trailing, 5)
            }
            
            // Main button
            Button(action: {
                if !isSwiped {
                    action()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if onDelete != nil {
                            if gesture.translation.width < 0 {
                                offset = max(gesture.translation.width, -90)
                            }
                        }
                    }
                    .onEnded { gesture in
                        if onDelete != nil {
                            withAnimation(.spring()) {
                                if gesture.translation.width < -50 {
                                    offset = -90
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                    }
            )
        }
    }
}

struct GameModeButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
