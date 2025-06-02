import SwiftUI
import SpriteKit
import UIKit

struct GameView: View {
    @StateObject private var gameState = GameState()
    @State private var showingSettings = false
    @State private var showingAchievements = false
    @State private var showingAchievementNotification = false
    @State private var currentAchievement: Achievement?
    @AppStorage("showTutorial") private var showTutorial = true
    @State private var showingTutorial = false
    @State private var isPaused = false
    
    var scene: SKScene {
        let scene = GameScene()
        scene.size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        scene.scaleMode = .aspectFill
        scene.gameState = gameState
        return scene
    }
    
    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            
            // Top Bar
            VStack {
                HStack {
                    Button(action: { isPaused = true }) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 8)
                    Text("Infinitum Stack & Smash")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 20) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Button(action: { showingAchievements = true }) {
                            Image(systemName: "rosette")
                                .font(.title2)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }
            
            // Score and Level Display
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Score")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(gameState.score)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Level")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(gameState.level)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.yellow)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(BlurView(style: .systemUltraThinMaterialDark).cornerRadius(16).padding(.horizontal, 8))
                    .padding(.top, geometry.safeAreaInsets.top)
                    // Undo Button
                    if gameState.canUndo {
                        Button(action: { gameState.undoLastMove() }) {
                            Text("Undo Last Move")
                                .font(.subheadline.bold())
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                        .transition(.opacity)
                    }
                    // Per-level high score and all-time highest score
                    let levelHighScore = UserDefaults.standard.integer(forKey: "highScore_level_\(gameState.level)")
                    let allTimeHighScore = UserDefaults.standard.integer(forKey: "highScore")
                    HStack {
                        Text("Level High: \(levelHighScore)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("All-Time High: \(allTimeHighScore)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    Spacer()
                }
            }
            
            // Game Over Overlay
            if gameState.isGameOver {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Text("Game Over!")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Final Score: \(gameState.score)")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Level Reached: \(gameState.level)")
                                .font(.title3)
                                .foregroundColor(.yellow)
                            
                            HStack(spacing: 20) {
                                Button(action: {
                                    gameState.resetGame()
                                }) {
                                    Text("Play Again")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Text("Settings")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 12)
                                        .background(Color.gray)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(30)
                        .background(BlurView(style: .systemUltraThinMaterialDark))
                        .cornerRadius(20)
                        .padding(40)
                    )
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
        .overlay {
            if showingAchievementNotification, let achievement = currentAchievement {
                AchievementNotification(achievement: achievement, isPresented: $showingAchievementNotification)
                    .transition(.scale.combined(with: .opacity))
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
        .onChange(of: gameState.achievementsManager.getAllAchievements()) { achievements in
            for achievement in achievements {
                if achievement.unlocked && !achievement.unlocked {
                    currentAchievement = achievement
                    withAnimation {
                        showingAchievementNotification = true
                    }
                }
            }
        }
        .onAppear {
            if showTutorial {
                showingTutorial = true
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var gameState: GameState
    @Binding var showingTutorial: Bool
    @AppStorage("showTutorial") private var showTutorial = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("musicVolume") private var musicVolume: Double = 0.7
    @AppStorage("sfxVolume") private var sfxVolume: Double = 0.7
    @AppStorage("difficulty") private var difficulty: String = "normal"
    @AppStorage("theme") private var theme: String = "dark"
    @AppStorage("autoSave") private var autoSave = true
    
    private let difficulties = ["easy", "normal", "hard", "expert"]
    private let themes = ["dark", "light", "neon", "pastel"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Game Settings")) {
                    Picker("Theme", selection: $theme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme.capitalized)
                        }
                    }
                    
                    Toggle("Show Tutorial", isOn: $showTutorial)
                    Toggle("Auto Save", isOn: $autoSave)
                }
                
                Section(header: Text("Audio Settings")) {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Music Volume")
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $musicVolume, in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SFX Volume")
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $sfxVolume, in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                    }
                }
                
                Section(header: Text("Game Progress")) {
                    HStack {
                        Text("High Score")
                        Spacer()
                        Text("\(UserDefaults.standard.integer(forKey: "highScore"))")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Highest Level")
                        Spacer()
                        Text("\(UserDefaults.standard.integer(forKey: "highestLevel"))")
                            .foregroundColor(.blue)
                    }
                }
                
                // Rules Section
                Section(header: Text("Rules").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Drag shapes from the tray onto the grid.", systemImage: "hand.point.up.left.fill")
                        Label("Shapes come in many sizes and rotations, including I, L, T, and more.", systemImage: "cube")
                        Label("Fill an entire row or column to clear it and earn points.", systemImage: "line.horizontal.3.decrease.circle")
                        Label("Bonus points for clearing lines with all the same color.", systemImage: "star.fill")
                        Label("Group bonuses for clearing large groups when clearing lines.", systemImage: "sparkles")
                        Label("Level up by reaching the required score (Level × 1000).", systemImage: "arrow.up.right.square")
                        Label("Each level gets harder with more shapes and colors.", systemImage: "flame")
                        Label("Undo your last move once per placement.", systemImage: "arrow.uturn.left.circle")
                        Label("Pause the game anytime with the pause button.", systemImage: "pause.circle")
                        Label("Game over if none of your tray shapes can be placed.", systemImage: "xmark.octagon")
                        Label("Track your high score and highest level in the settings.", systemImage: "chart.bar")
                        Divider()
                        Button(action: { showingTutorial = true }) {
                            Label("View Tutorial", systemImage: "questionmark.circle")
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Section {
                    Button(action: {
                        gameState.resetGame()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Game")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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

// Add BlurView for background blur
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}


