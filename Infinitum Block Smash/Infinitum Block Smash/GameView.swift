import SwiftUI
import SpriteKit
import UIKit
import GoogleMobileAds
import AppTrackingTransparency

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
    
    private enum SettingsAction {
        case resume
        case restart
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
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(gameState: gameState, showingTutorial: $showingTutorial)
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView(achievementsManager: gameState.achievementsManager)
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialModal(showingTutorial: $showingTutorial, showTutorial: $showTutorial)
        }
        .onAppear {
            if showTutorial {
                showingTutorial = true
            }
        }
        .onChange(of: gameState.levelComplete) { isComplete in
            if isComplete {
                Task {
                    await adManager.showRewardedInterstitial(onReward: {
                        // Don't automatically reset levelComplete - wait for user interaction
                    })
                }
            }
        }
        .onChange(of: gameState.score) { _ in
            // Check top three status when score changes
            Task {
                await adManager.checkTopThreeStatus()
            }
        }
        .onDisappear {
            Task {
                await gameState.cleanup()
            }
        }
    }
    
    private var mainGameView: some View {
        VStack(spacing: 0) {
            GameTopBar(showingSettings: $showingSettings, showingAchievements: $showingAchievements, isPaused: $isPaused, gameState: gameState)
            scoreLevelBar
            if showStatsOverlay && (showFPS || showMemory) {
                StatsOverlayView(gameState: gameState)
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
        .frame(height: 88)
        .padding(.horizontal, 8)
        .padding(.top, 8)
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
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private var scoreView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(NSLocalizedString("Score", comment: "Score label"))
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            Text("\(gameState.score)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("%d points", comment: "Score accessibility label"), gameState.score))
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
                    .font(.headline)
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
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Text(String(format: NSLocalizedString("Need: %d", comment: "Required score"), gameState.calculateRequiredScore() - gameState.score))
                .font(.caption2)
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
            Text(String(format: NSLocalizedString("All-Time High: %d", comment: "All-time high score"), gameState.highScore))
                .font(.caption2)
                .foregroundColor(Color.orange.opacity(0.9))
                .padding(.trailing, 12)
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("Level High Score: %d and All-Time High Score: %d", comment: "High scores accessibility label"), 
            UserDefaults.standard.integer(forKey: "highScore_level_\(gameState.level)"),
            gameState.highScore))
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
            
            LevelCompleteOverlay(isPresented: gameState.levelComplete, score: gameState.score, level: gameState.level) {
                gameState.confirmLevelCompletion()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Level \(gameState.level) Complete! Score: \(gameState.score)")
            
            GameOverOverlay(
                isPresented: gameState.isGameOver,
                score: gameState.score,
                level: gameState.level,
                onRetry: {
                    gameState.resetGame()
                },
                onMainMenu: {
                    presentationMode.wrappedValue.dismiss()
                },
                onContinue: {
                    Task {
                        await adManager.showRewardedInterstitial(onReward: {
                            gameState.continueGame()
                        })
                    }
                },
                canContinue: !gameState.hasUsedContinueAd
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Game Over. Final Score: \(gameState.score), Level: \(gameState.level)")
            
            PauseMenuOverlay(
                isPresented: isPaused,
                onResume: { handleSettingsAction(.resume) },
                onSave: {
                    Task {
                        do {
                            try await gameState.saveProgress()
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
                onRestart: { handleSettingsAction(.restart) },
                onHome: { presentationMode.wrappedValue.dismiss() },
                onEndGame: { handleSettingsAction(.endGame) }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pause Menu")
            
            if showingTutorial {
                TutorialModal(showingTutorial: $showingTutorial, showTutorial: $showTutorial)
            }
            
            if showingAchievements {
                AchievementsView(achievementsManager: gameState.achievementsManager)
            }
            
            if showingStats {
                StatsView(gameState: gameState)
            }
        }
    }
    
    private var bannerAdView: some View {
        VStack {
            Spacer()
            BannerAdView()
                .frame(maxWidth: .infinity)
                .frame(height: 50)
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
        case .resume:
            gameState.isPaused = false
            isPaused = false
        case .restart:
            // Check username before restarting
            if !UserDefaults.standard.bool(forKey: "isGuest") {
                if let username = UserDefaults.standard.string(forKey: "username"), !username.isEmpty {
                    gameState.resetGame()
                    isPaused = false
                } else {
                    // Show alert or handle missing username
                    print("[GameView] Cannot start game: Username not set")
                    // You might want to show an alert here
                }
            } else {
                gameState.resetGame()
                isPaused = false
            }
        case .endGame:
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
}

struct TutorialModal: View {
    @Binding var showingTutorial: Bool
    @Binding var showTutorial: Bool
    @State private var step = 0
    private let steps: [(String, String, String?)] = [
        ("Welcome to Infinitum Block Smash!", "Get ready to stack and smash blocks for high scores.", "star.fill"),
        ("Drag Shapes", "Drag shapes from the tray onto the grid.", "hand.point.up.left.fill"),
        ("Clear Lines", "Fill an entire row or column to clear it and earn points.", "line.horizontal.3.decrease.circle"),
        ("Level Up", "The game gets harder as you level up, with more complex shapes.", "arrow.up.right.square"),
        ("Game Over", "The game ends when no more moves are possible.", "xmark.octagon"),
        ("Achievements", "Try to beat your high score and unlock achievements!", "star.fill")
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            if let icon = steps[step].2 {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)
            }
            Text(steps[step].0)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(steps[step].1)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .padding()
                }
                Spacer()
                if step < steps.count - 1 {
                    Button("Next") { step += 1 }
                        .padding()
                } else {
                    Button("Done") {
                        showTutorial = false
                        showingTutorial = false
                    }
                    .padding()
                }
            }
            Button("Skip Tutorial") {
                showTutorial = false
                showingTutorial = false
            }
            .foregroundColor(.red)
            .padding(.top, 8)
        }
        .padding()
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .cornerRadius(24)
        .padding(32)
    }
}

private struct StatsOverlayView: View {
    @ObservedObject var gameState: GameState
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("showMemory") private var showMemory = false
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if showFPS {
                    Text("FPS: \(Int(performanceMonitor.currentFPS))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                }
                
                if showMemory {
                    Text("Memory: \(String(format: "%.1f", performanceMonitor.memoryUsage))MB")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .allowsHitTesting(false)
    }
}
