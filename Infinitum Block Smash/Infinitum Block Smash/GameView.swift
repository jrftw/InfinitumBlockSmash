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
            VStack(spacing: 0) {
                GameTopBar(showingSettings: $showingSettings, showingAchievements: $showingAchievements, isPaused: $isPaused, gameState: gameState)
                // Custom Score/Level/Undo Bar
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.sRGB, red: 32/255, green: 36/255, blue: 48/255, opacity: 0.92))
                    VStack(spacing: 0) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Score")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(gameState.score)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Score: \(gameState.score)")
                            
                            Spacer()
                            
                            VStack(spacing: 2) {
                                Button(action: { gameState.undo() }) {
                                    Text("Undo Last Move")
                                        .font(.headline)
                                        .foregroundColor(gameState.canUndo ? Color(#colorLiteral(red: 0.2, green: 0.5, blue: 1, alpha: 1)) : Color.gray)
                                }
                                .disabled(!gameState.canUndo)
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Undo Last Move")
                                .accessibilityHint(gameState.canUndo ? "Tap to undo your last move" : "Undo is not available")
                                
                                Text("Need: \(gameState.calculateRequiredScore() - gameState.score)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Level")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(gameState.level)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.yellow)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Level: \(gameState.level)")
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        
                        Spacer(minLength: 0)
                        
                        HStack {
                            Text("Level High: \(UserDefaults.standard.integer(forKey: "highScore_level_\(gameState.level)"))")
                                .font(.caption2)
                                .foregroundColor(Color.blue.opacity(0.9))
                                .padding(.leading, 12)
                            Spacer()
                            Text("All-Time High: \(gameState.highScore)")
                                .font(.caption2)
                                .foregroundColor(Color.orange.opacity(0.9))
                                .padding(.trailing, 12)
                        }
                        .padding(.bottom, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Level High Score: \(UserDefaults.standard.integer(forKey: "highScore_level_\(gameState.level)")) and All-Time High Score: \(gameState.highScore)")
                    }
                }
                .frame(height: 88)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                Spacer()
            }
            
            // Overlays and modals
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
            
            // Score animation container
            scoreAnimator
            
            VStack {
                Spacer()
                BannerAdView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black.opacity(0.1))
            }
            
            // Overlay views
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
            gameState.cleanup()
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
