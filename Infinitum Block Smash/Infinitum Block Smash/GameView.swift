import SwiftUI
import SpriteKit
import UIKit
import GoogleMobileAds

struct GameView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var adManager = AdManager.shared
    @State private var showingSettings = false
    @State private var showingAchievements = false
    @State private var showingAchievementNotification = false
    @State private var currentAchievement: Achievement?
    @AppStorage("showTutorial") private var showTutorial = true
    @State private var showingTutorial = false
    @State private var isPaused = false

    var body: some View {
        ZStack {
            GameSceneProvider(gameState: gameState)
            VStack(spacing: 0) {
                GameTopBar(showingSettings: $showingSettings, showingAchievements: $showingAchievements, isPaused: $isPaused)
                // Custom Score/Level/Undo Bar
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.sRGB, red: 32/255, green: 36/255, blue: 48/255, opacity: 0.92))
                    VStack(spacing: 0) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Score")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(gameState.score)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Button(action: { gameState.undoLastMove() }) {
                                Text("Undo Last Move")
                                    .font(.headline)
                                    .foregroundColor(gameState.canUndo ? Color(#colorLiteral(red: 0.2, green: 0.5, blue: 1, alpha: 1)) : Color.gray)
                            }
                            .disabled(!gameState.canUndo)
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Level")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(gameState.level)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        Spacer(minLength: 0)
                        HStack {
                            Text("Level High: \(UserDefaults.standard.integer(forKey: "highScore_level_\(gameState.level)"))")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.leading, 12)
                            Spacer()
                            Text("All-Time High: \(UserDefaults.standard.integer(forKey: "highScore"))")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.trailing, 12)
                        }
                        .padding(.bottom, 6)
                    }
                }
                .frame(height: 88)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                Spacer()
            }
            // Overlays and modals
            if gameState.showingAchievementNotification, let achievement = gameState.currentAchievement {
                AchievementNotificationOverlay(showing: $gameState.showingAchievementNotification, achievement: $gameState.currentAchievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
            LevelCompleteOverlay(isPresented: gameState.levelComplete, score: gameState.score, level: gameState.level) {
                gameState.advanceToNextLevel()
            }
            PauseMenuOverlay(isPresented: isPaused, onResume: { isPaused = false }, onSave: {
                gameState.saveProgress(); isPaused = false
            }, onRestart: {
                gameState.resetGame(); isPaused = false
            }, onHome: {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(rootView: ContentView())
                    window.makeKeyAndVisible()
                }
            })
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
                // Show rewarded interstitial after level completion
                if let root = getRootViewController() {
                    adManager.showRewardedInterstitial(from: root) {
                        // Optional reward logic here
                    }
                }
            }
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController })
            .first
    }
}

struct TutorialModal: View {
    @Binding var showingTutorial: Bool
    @Binding var showTutorial: Bool
    @State private var step = 0
    private let steps: [(String, String, String?)] = [
        ("Welcome to Infinitum Stack & Smash!", "Get ready to stack and smash blocks for high scores.", "star.fill"),
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


