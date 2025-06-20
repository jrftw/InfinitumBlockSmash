/*
 * GameView.swift
 * 
 * MAIN GAME SWIFTUI VIEW WRAPPER
 * 
 * This is the primary SwiftUI view that wraps the SpriteKit game scene and provides
 * the complete game interface including overlays, settings, achievements, and
 * various UI components. It serves as the main entry point for the game experience.
 * 
 * KEY RESPONSIBILITIES:
 * - SwiftUI wrapper for SpriteKit GameScene
 * - Game state management and UI updates
 * - Overlay management (settings, achievements, stats)
 * - Advertisement integration and management
 * - Notification permission handling
 * - Tutorial system integration
 * - Score animation display
 * - Sync status and error handling
 * - High score banner display
 * - Save game confirmation dialogs
 * 
 * MAJOR DEPENDENCIES:
 * - GameScene.swift: Core SpriteKit game scene
 * - GameState.swift: Game data and logic management
 * - AdManager.swift: Advertisement loading and display
 * - NotificationService.swift: Push notification management
 * - SettingsView.swift: Game settings interface
 * - AchievementsView.swift: Achievement display
 * - StatsView.swift: Statistics and analytics display
 * - TutorialModal.swift: Tutorial system
 * - HighScoreBannerView.swift: High score notifications
 * - ScoreAnimationView.swift: Score animation effects
 * 
 * UI COMPONENTS:
 * - GameSceneProvider: SpriteKit scene container
 * - BannerAdView: Advertisement banner
 * - Overlay system for various modals
 * - Score animation container
 * - Sync status indicators
 * - Error handling dialogs
 * - Achievement progress overlays
 * 
 * STATE MANAGEMENT:
 * - Game state observation and updates
 * - Advertisement loading states
 * - Notification permission states
 * - Tutorial display states
 * - Settings and overlay visibility
 * - Sync status and error handling
 * - Achievement notification states
 * 
 * USER INTERACTION:
 * - Settings menu access
 * - Achievement viewing
 * - Tutorial system interaction
 * - Advertisement interaction
 * - Notification permission requests
 * - Save game confirmations
 * - Statistics viewing
 * 
 * PERFORMANCE FEATURES:
 * - Lazy loading of heavy resources
 * - Background task management
 * - Memory-efficient overlay system
 * - Optimized advertisement loading
 * - Efficient state updates
 * 
 * INTEGRATION POINTS:
 * - SpriteKit scene for game rendering
 * - Firebase for data synchronization
 * - Advertisement networks for monetization
 * - Push notification services
 * - Analytics and tracking systems
 * - Settings and preferences storage
 * 
 * ERROR HANDLING:
 * - Sync error recovery
 * - Advertisement loading failures
 * - Network connectivity issues
 * - Data persistence errors
 * - User-friendly error messages
 * 
 * ACCESSIBILITY:
 * - VoiceOver support
 * - Dynamic type support
 * - High contrast mode
 * - Reduced motion support
 * - Accessibility labels and hints
 * 
 * ARCHITECTURE ROLE:
 * This view acts as the "View" layer in the MVVM architecture, providing
 * the complete user interface and coordinating between various services
 * and the core game logic.
 * 
 * THREADING CONSIDERATIONS:
 * - UI updates on main thread
 * - Background operations for data loading
 * - Async/await for network operations
 * - State management with Combine
 * 
 * LIFECYCLE MANAGEMENT:
 * - View appearance/disappearance handling
 * - Resource cleanup and memory management
 * - Background/foreground state handling
 * - Scene lifecycle coordination
 */

import SwiftUI
import SpriteKit
import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import Firebase
import FirebaseAuth

// Add AdError reference
typealias AdError = AdManager.AdError

struct GameView: View {
    @ObservedObject var gameState: GameState
    @StateObject private var adManager = AdManager.shared
    @State private var showingSettings = false
    @State private var showingAchievements = false
    @State private var showingAchievementNotification = false
    @State private var currentAchievement: Achievement?
    @AppStorage("showTutorial") private var showTutorial = true
    @State private var showingTutorial = false
    @State private var isPaused = false
    @Environment(\.presentationMode) var presentationMode
    @State private var scoreAnimator = ScoreAnimationContainer()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingStats = false
    @AppStorage("showStatsOverlay") private var showStatsOverlay = false
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("showMemory") private var showMemory = false
    @State private var isSyncing = false
    @State private var syncError: String?
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingSaveWarning = false
    @State private var isSettingsLoading = false
    @State private var showingAchievementProgress = false
    @State private var currentAchievementProgress: (id: String, progress: Double)?
    @State private var achievementTimer: Timer?
    @State private var showingAdError = false
    @State private var adErrorMessage = ""
    @State private var adRetryCount = 0
    @State private var isAdRetrying = false
    
    private enum SettingsAction {
        case resumeGame
        case endGame
        case showTutorial
        case showAchievements
        case showStats
    }

    var body: some View {
        ZStack {
            GameSceneProvider(gameState: gameState)
            mainGameView
            overlays
            scoreAnimator
            bannerAdView
            
            // Add notification permission request
            if notificationService.shouldShowPermissionRequest {
                VStack {
                    Text("Enable Notifications")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Get notified about new high scores and daily reminders!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                    
                    HStack(spacing: 16) {
                        Button("Not Now") {
                            notificationService.shouldShowPermissionRequest = false
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Enable") {
                            notificationService.requestNotificationPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .padding()
            }
            
            // Add sync status indicator
            if isSyncing {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Syncing...")
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
            }
            
            // Show sync error if any
            if let error = syncError {
                Color.clear
                    .onAppear {
                        print("[GameView] Sync error occurred: \(error)")
                        Task {
                            await syncGameData()
                        }
                    }
            }
            
            // Add high score banner
            if notificationService.showHighScoreBanner,
               let notification = notificationService.currentHighScoreNotification {
                VStack {
                    HighScoreBannerView(
                        notification: notification,
                        isShowing: $notificationService.showHighScoreBanner
                    )
                    Spacer()
                }
                .padding(.top, 50)
            }
            
            // Add save warning alert
            if showingSaveWarning {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 20) {
                            Text("Save Game")
                                .font(.title)
                                .foregroundColor(.white)
                            Text("You already have a saved game. Do you want to overwrite it?")
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            HStack(spacing: 20) {
                                Button("Cancel") {
                                    showingSaveWarning = false
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                
                                Button("Overwrite") {
                                    Task {
                                        do {
                                            try await gameState.confirmSaveOverwrite()
                                            isPaused = false
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                presentationMode.wrappedValue.dismiss()
                                            }
                                        } catch {
                                            print("[PauseMenu] Error saving progress: \(error.localizedDescription)")
                                            isPaused = false
                                        }
                                        showingSaveWarning = false
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.sRGB, red: 32/255, green: 36/255, blue: 48/255, opacity: 0.95))
                        .cornerRadius(15)
                        .padding()
                    )
            }
            
            // Achievement progress overlay
            if showingAchievementProgress, let achievement = currentAchievementProgress {
                achievementProgressView(achievement)
            }
            
            // Ad loading indicator
            if adManager.isLoadingIndicatorVisible {
                adLoadingView
            }
        }
        .sheet(isPresented: $showingSettings) {
            if isSettingsLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else {
                SettingsView(gameState: gameState, showingTutorial: $showingTutorial)
                    .onAppear {
                        // Preload any heavy resources here
                        Task {
                            await gameState.preloadSettingsResources()
                        }
                    }
            }
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView(achievementsManager: gameState.achievementsManager)
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialModal(showingTutorial: $showingTutorial, showTutorial: $showTutorial)
        }
        .onAppear {
            print("[DEBUG] GameView appeared - Current level: \(gameState.level)")
            
            // FIXED: Ensure game is properly initialized for new Classic games
            if !UserDefaults.standard.bool(forKey: "isTimedMode") {
                print("[DEBUG] Classic mode detected, ensuring proper initialization")
                gameState.ensureProperInitialization()
            }
            
            if showTutorial {
                showingTutorial = true
            }
            // Delay sync by 1 second to allow network monitor to update
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await syncGameData()
            }
            // Request notification permission when game view appears
            notificationService.requestNotificationPermission()
            
            // Add observer for save warning
            NotificationCenter.default.addObserver(
                forName: .showSaveGameWarning,
                object: nil,
                queue: .main
            ) { _ in
                showingSaveWarning = true
            }
            
            setupAchievementTracking()
        }
        .onChange(of: gameState.levelComplete) { isComplete in
            if isComplete {
                // Level complete - no ad here, ads only show every 15th level
                // The ad logic is handled in GameState.swift during level progression
            }
        }
        .onChange(of: gameState.score) { _ in
            // Check top three status when score changes
            Task {
                await adManager.checkTopThreeStatus()
            }
        }
        .onChange(of: showingSettings) { newValue in
            if newValue {
                isSettingsLoading = true
                // Add a small delay to ensure smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSettingsLoading = false
                }
            }
        }
        .onDisappear {
            Task {
                await gameState.cleanup()
            }
            
            // Remove observer
            NotificationCenter.default.removeObserver(self)
            
            achievementTimer?.invalidate()
        }
        .onChange(of: adManager.adLoadFailed) { failed in
            if failed {
                handleAdError(adManager.adError ?? AdError.loadFailed)
            }
        }
        .onChange(of: adManager.adState) { state in
            switch state {
            case .error:
                handleAdError(adManager.adError ?? AdError.loadFailed)
            case .ready:
                resetAdState()
            default:
                break
            }
        }
    }
    
    private var mainGameView: some View {
        VStack(spacing: 0) {
            GameTopBar(showingSettings: $showingSettings, showingAchievements: $showingAchievements, isPaused: $isPaused, gameState: gameState)
            scoreLevelBar
            
            // Stats overlay positioned at the top with proper spacing
            if showStatsOverlay {
                StatsOverlayView(gameState: gameState)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            
            Spacer()
        }
    }
    
    private var scoreLevelBar: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.sRGB, red: 32/255, green: 36/255, blue: 48/255, opacity: 0.92))
            VStack(spacing: 0) {
                scoreLevelContent
                Spacer(minLength: 0)
                highScoresView
            }
        }
        .frame(height: UIScreen.main.bounds.width <= 390 ? 76 : 88)
        .padding(.horizontal, 8)
        .padding(.top, UIScreen.main.bounds.width <= 390 ? 4 : 8)
    }
    
    private var scoreLevelContent: some View {
        HStack(alignment: .center) {
            scoreView
            Spacer()
            undoButtonView
            Spacer()
            levelView
        }
        .padding(.horizontal)
        .padding(.top, UIScreen.main.bounds.width <= 390 ? 4 : 8)
        .padding(.bottom, 4)
    }
    
    private var scoreView: some View {
        VStack(spacing: 4) {
            Text("Score")
                .font(.system(size: UIScreen.main.bounds.width <= 390 ? 12 : 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Text("\(gameState.isGameOver ? gameState.score : gameState.temporaryScore)")
                .font(.system(size: UIScreen.main.bounds.width <= 390 ? 20 : 24, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var undoButtonView: some View {
        VStack(spacing: 2) {
            Button(action: {
                Task {
                    await gameState.undo()
                }
            }) {
                Text(gameState.canUndo ? 
                    NSLocalizedString("Undo Last Move", comment: "Undo button text") :
                    NSLocalizedString("Watch Ad for Undo", comment: "Watch ad for undo button text"))
                    .font(.system(size: UIScreen.main.bounds.width <= 390 ? 14 : 16, weight: .semibold))
                    .foregroundColor(gameState.canUndo ? Color(#colorLiteral(red: 0.2, green: 0.5, blue: 1, alpha: 1)) : Color.gray)
            }
            .disabled(!gameState.canUndo && !gameState.canAdUndo)
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(gameState.canUndo ? 
                NSLocalizedString("Undo Last Move", comment: "Undo button accessibility label") :
                NSLocalizedString("Watch Ad for Undo", comment: "Watch ad for undo button accessibility label"))
            .accessibilityHint(gameState.canUndo ? 
                NSLocalizedString("Tap to undo your last move", comment: "Undo button accessibility hint") :
                NSLocalizedString("Watch an ad to get more undos", comment: "Watch ad for undo button accessibility hint"))
            
            if !gameState.canUndo && gameState.canAdUndo {
                Text(String(format: NSLocalizedString("Undos: %d", comment: "Remaining undos count"), gameState.adUndoCount))
                    .font(.system(size: UIScreen.main.bounds.width <= 390 ? 10 : 12))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Text(String(format: NSLocalizedString("Need: %d", comment: "Required score"), gameState.calculateRequiredScore() - gameState.temporaryScore))
                .font(.system(size: UIScreen.main.bounds.width <= 390 ? 10 : 12))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private var levelView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(NSLocalizedString("Level", comment: "Level label"))
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            Text("\(gameState.level)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("%d level", comment: "Level accessibility label"), gameState.level))
    }
    
    private var highScoresView: some View {
        HStack {
            Text(String(format: NSLocalizedString("Level High: %d", comment: "Level high score"), UserDefaults.standard.integer(forKey: "highScore_level_\(gameState.level)")))
                .font(.caption2)
                .foregroundColor(Color.blue.opacity(0.9))
                .padding(.leading, 12)
            Spacer()
            Text(String(format: NSLocalizedString("All-Time High: %d", comment: "All-time high score"), gameState.leaderboardHighScore))
                .font(.caption2)
                .foregroundColor(Color.orange.opacity(0.9))
                .padding(.trailing, 12)
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("Level High Score: %d and All-Time High Score: %d", comment: "High scores accessibility label"), 
            UserDefaults.standard.integer(forKey: "highScore_level_\(gameState.level)"),
            gameState.leaderboardHighScore))
    }
    
    private var overlays: some View {
        Group {
            if gameState.showingAchievementNotification, let achievement = gameState.currentAchievement {
                AchievementNotificationOverlay(
                    showing: .constant(true),
                    achievement: .constant(achievement)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Achievement Unlocked: \(achievement.name)")
                .accessibilityHint(achievement.description)
            }
            
            LevelCompleteOverlay(
                isPresented: gameState.levelComplete, 
                score: gameState.score, 
                level: gameState.level,
                onContinue: {
                    gameState.confirmLevelCompletion()
                },
                isPerfectLevel: gameState.isPerfectLevel,
                linesCleared: gameState.linesCleared,
                blocksPlaced: gameState.blocksPlaced,
                currentChain: gameState.currentChain,
                breakdown: gameState.getCurrentLevelBreakdown()
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Level \(gameState.level) Complete! Score: \(gameState.score)")
            
            GameOverOverlay(
                isPresented: gameState.isGameOver,
                score: gameState.score,
                level: gameState.level,
                onRetry: {
                    gameState.startNewGame()
                },
                onMainMenu: {
                    presentationMode.wrappedValue.dismiss()
                },
                onContinue: {
                    gameState.continueGame()
                },
                canContinue: !gameState.hasUsedContinueAd,
                isTimedMode: UserDefaults.standard.bool(forKey: "isTimedMode"),
                timeRemaining: 0, // Classic mode doesn't use time
                breakdown: gameState.getGameBreakdown()
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Game Over. Final Score: \(gameState.score), Level: \(gameState.level)")
            
            PauseMenuOverlay(
                isPresented: isPaused,
                onResume: {
                    isPaused = false
                },
                onSave: {
                    Task {
                        do {
                            // Always save the current game state
                            try await gameState.forceSaveGame()
                            isPaused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        } catch {
                            print("[PauseMenu] Error saving progress: \(error.localizedDescription)")
                            isPaused = false
                        }
                    }
                },
                onRestart: {
                    gameState.startNewGame()
                    isPaused = false
                },
                onEndGame: {
                    if !UserDefaults.standard.bool(forKey: "isGuest") && gameState.score > 0 {
                        Task {
                            try? await LeaderboardService.shared.updateLeaderboard(
                                score: gameState.score,
                                level: gameState.level,
                                time: gameState.totalTime,
                                type: .score
                            )
                        }
                    }
                    gameState.endGameFromSettings()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pause Menu")
            
            if showingStats {
                StatsView(gameState: gameState)
            }
        }
    }
    
    private var bannerAdView: some View {
        VStack {
            Spacer()
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
    
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController })
            .first
    }
    
    private func handleSettingsAction(_ action: SettingsAction) {
        switch action {
        case .resumeGame:
            isPaused = false
        case .endGame:
            if !UserDefaults.standard.bool(forKey: "isGuest") && gameState.score > 0 {
                Task {
                    try? await LeaderboardService.shared.updateLeaderboard(
                        score: gameState.score,
                        level: gameState.level,
                        time: gameState.totalTime,
                        type: .score
                    )
                }
            }
            gameState.endGameFromSettings()
            isPaused = false
            presentationMode.wrappedValue.dismiss()
        case .showTutorial:
            showingTutorial = true
        case .showAchievements:
            showingAchievements = true
        case .showStats:
            showingStats = true
        }
    }
    
    // Update sync function
    private func syncGameData() async {
        guard !UserDefaults.standard.bool(forKey: "isGuest") else { return }
        
        // Check network connectivity first
        guard await NetworkMonitor.shared.checkConnection() else {
            syncError = "No internet connection. Please check your network and try again."
            return
        }
        
        // Ensure we're authenticated
        guard FirebaseManager.shared.isAuthenticated else {
            syncError = "Please sign in to sync your game data."
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // First try to sync any offline changes
            try await gameState.syncOfflineQueue()
            
            // Then check if we need to load cloud data
            let hasCloudData = await FirebaseManager.shared.checkSyncStatus()
            if hasCloudData {
                await gameState.loadCloudData()
            }
            
            // Update last sync time
            UserDefaults.standard.set(Date(), forKey: "lastFirebaseSaveTime")
            UserDefaults.standard.synchronize()
            
            isSyncing = false
        } catch let error as FirebaseError {
            print("[GameView] Firebase error syncing game data: \(error)")
            switch error {
            case .notAuthenticated:
                print("[GameView] ❌ User not authenticated")
            case .invalidData:
                print("[GameView] ❌ Invalid data")
            case .updateFailed(let underlyingError):
                print("[GameView] ❌ Update failed: \(underlyingError.localizedDescription)")
            case .networkError:
                syncError = "Network error. Please check your connection and try again."
            case .permissionDenied:
                syncError = "Permission denied. Please sign in again."
            case .offlineMode:
                syncError = "You're currently offline. Changes will be saved locally."
            case .retryLimitExceeded:
                syncError = "Too many sync attempts. Please try again later."
            case .invalidCredential:
                syncError = "Invalid credentials. Please sign in again."
            }
            isSyncing = false
        } catch {
            print("[GameView] Error syncing game data: \(error.localizedDescription)")
            syncError = error.localizedDescription
            isSyncing = false
        }
    }
    
    private func setupAchievementTracking() {
        // Start a timer to check achievement progress
        achievementTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await checkAchievementProgress()
            }
        }
    }
    
    private func checkAchievementProgress() async {
        // Check score achievements
        let scoreProgress = await GameCenterManager.shared.getAchievementProgress(id: "score_\(gameState.score)")
        if scoreProgress > 0 {
            showAchievementProgress(id: "score_\(gameState.score)", progress: scoreProgress)
        }
        
        // Check level achievements
        let levelProgress = await GameCenterManager.shared.getAchievementProgress(id: "level_\(gameState.level)")
        if levelProgress > 0 {
            showAchievementProgress(id: "level_\(gameState.level)", progress: levelProgress)
        }
        
        // Check other achievements as needed
        // ...
    }
    
    private func showAchievementProgress(id: String, progress: Double) {
        withAnimation {
            currentAchievementProgress = (id: id, progress: progress)
            showingAchievementProgress = true
            
            // Hide the progress after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showingAchievementProgress = false
                }
            }
        }
    }
    
    private func handleAdError(_ error: Error) {
        // Silently handle ad errors without showing alerts
        if adRetryCount < 3 && !isAdRetrying {
            isAdRetrying = true
            adRetryCount += 1
            
            // Exponential backoff with jitter
            let baseDelay = pow(2.0, Double(adRetryCount))
            let jitter = Double.random(in: 0...0.3) * baseDelay
            let delay = baseDelay + jitter
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Task {
                    // Attempt to reload all ad types
                    await adManager.preloadAllAds()
                    isAdRetrying = false
                }
            }
        }
        
        // Track the error silently
        Task {
            AnalyticsManager.shared.trackEvent(.performanceMetric(
                name: "ad_error",
                value: 1.0
            ))
        }
    }
    
    private func resetAdState() {
        adRetryCount = 0
        isAdRetrying = false
    }
    
    private func achievementProgressView(_ achievement: (id: String, progress: Double)) -> some View {
        VStack {
            if let description = GameCenterManager.shared.getAchievementDescription(id: achievement.id) {
                HStack {
                    Image(systemName: description.icon)
                        .font(.title2)
                    Text(description.title)
                        .font(.headline)
                }
                ProgressView(value: achievement.progress, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.blue)
                Text("\(Int(achievement.progress))%")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .padding()
        .transition(.move(edge: .top))
    }
    
    private var adLoadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("Loading Ad...")
                .foregroundColor(.white)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

private struct StatsOverlayView: View {
    @ObservedObject var gameState: GameState
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var networkMetrics = NetworkMetricsManager.shared
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("showMemory") private var showMemory = false
    @AppStorage("showFrame") private var showFrame = false
    @AppStorage("showCPU") private var showCPU = false
    @AppStorage("showNetwork") private var showNetwork = false
    @AppStorage("showInput") private var showInput = false
    @AppStorage("showResolution") private var showResolution = false
    @AppStorage("showPing") private var showPing = false
    @AppStorage("showBitrate") private var showBitrate = false
    @AppStorage("showJitter") private var showJitter = false
    @AppStorage("showDecode") private var showDecode = false
    @AppStorage("showPacketLoss") private var showPacketLoss = false
    
    private var hasAnyStatsEnabled: Bool {
        showFPS || showMemory || showFrame || showCPU || showNetwork || showInput || showResolution || showPing || showBitrate || showJitter || showDecode || showPacketLoss
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if hasAnyStatsEnabled {
                VStack(spacing: 4) {
                    // Performance Metrics Row
                    if showFPS || showMemory || showFrame {
                        HStack(spacing: 8) {
                            if showFPS {
                                StatText("FPS: \(Int(performanceMonitor.currentFPS))")
                            }
                            if showMemory {
                                StatText("Memory: \(String(format: "%.1f", performanceMonitor.getCurrentMemoryUsage()))MB")
                            }
                            if showFrame {
                                StatText("Frame: \(String(format: "%.1f", performanceMonitor.frameTime))ms")
                            }
                        }
                    }
                    
                    // Advanced Stats Row
                    if showCPU || showNetwork || showInput {
                        HStack(spacing: 8) {
                            if showCPU {
                                StatText("CPU: \(String(format: "%.1f", performanceMonitor.cpuUsage))%")
                            }
                            if showNetwork {
                                StatText("Network: \(String(format: "%.1f", performanceMonitor.networkLatency))ms")
                            }
                            if showInput {
                                StatText("Input: \(String(format: "%.1f", performanceMonitor.inputLatency))ms")
                            }
                        }
                    }
                    
                    // Display Metrics Row
                    if showResolution {
                        HStack(spacing: 8) {
                            StatText("Res: \(networkMetrics.resolution)")
                        }
                    }
                    
                    // Network Metrics Row
                    if showPing || showBitrate || showJitter {
                        HStack(spacing: 8) {
                            if showPing {
                                StatText("Ping: \(String(format: "%.0f", networkMetrics.ping))ms")
                            }
                            if showBitrate {
                                StatText("Bitrate: \(String(format: "%.1f", networkMetrics.bitrate))Mbps")
                            }
                            if showJitter {
                                StatText("Jitter: \(String(format: "%.1f", networkMetrics.jitter))ms")
                            }
                        }
                    }
                    
                    // Additional Network Metrics Row
                    if showDecode || showPacketLoss {
                        HStack(spacing: 8) {
                            if showDecode {
                                StatText("Decode: \(String(format: "%.1f", networkMetrics.decodeTime))ms")
                            }
                            if showPacketLoss {
                                StatText("Loss: \(String(format: "%.1f", networkMetrics.packetLoss))%")
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }
}

private struct StatText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
    }
}
