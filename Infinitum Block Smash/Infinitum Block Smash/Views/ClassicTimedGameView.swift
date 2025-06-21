/******************************************************
 * FILE: ClassicTimedGameView.swift
 * MARK: Classic Timed Game Mode SwiftUI Interface
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides the SwiftUI interface for the classic timed game mode, featuring
 * time-based gameplay with countdown timers, level progression, and enhanced
 * scoring mechanics. This view manages the complete timed game experience
 * including timer display, score tracking, and game state coordination.
 *
 * KEY RESPONSIBILITIES:
 * - Classic timed game mode interface and user experience
 * - Timer display and countdown management
 * - Time-based scoring and level progression
 * - Game state coordination with ClassicTimedGameState
 * - Save game warning and confirmation dialogs
 * - Performance monitoring and statistics overlay
 * - Game pause and resume functionality
 * - Score animation and visual feedback
 * - High score display and tracking
 * - Settings and achievements access
 * - Game cleanup and state management
 * - Notification handling for save warnings
 * - Accessibility support for timed gameplay
 *
 * MAJOR DEPENDENCIES:
 * - GameState.swift: Core game state and logic management
 * - ClassicTimedGameState.swift: Timed game mode state management
 * - GameSceneProvider.swift: SpriteKit scene integration
 * - GameTopBar.swift: Game interface top bar component
 * - StatsOverlayView.swift: Performance statistics display
 * - ScoreAnimationContainer.swift: Score animation effects
 * - NotificationCenter: Save warning notifications
 * - UserDefaults: Game mode persistence and settings
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - SpriteKit: Game development framework for scene integration
 * - Foundation: Core framework for notifications and data handling
 *
 * ARCHITECTURE ROLE:
 * Acts as the primary interface for the classic timed game mode,
 * coordinating between the game state, timed state management,
 * and user interface components to provide a complete timed
 * gameplay experience.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Timer state must be properly synchronized with game state
 * - Save game warnings require user confirmation before proceeding
 * - Game cleanup must occur on view disappearance
 * - Performance monitoring should be non-intrusive to gameplay
 * - Accessibility features must support timed gameplay mechanics
 */

import SwiftUI
import SpriteKit

struct ClassicTimedGameView: View {
    // MARK: - Properties
    @ObservedObject var gameState: GameState
    @StateObject private var timedState: ClassicTimedGameState
    @State private var showingSettings = false
    @State private var showingAchievements = false
    @State private var isPaused = false
    @Environment(\.dismiss) var dismiss
    @State private var scoreAnimator = ScoreAnimationContainer()
    @AppStorage("showStatsOverlay") private var showStatsOverlay = false
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
    @AppStorage("showTemperature") private var showTemperature = false
    @AppStorage("showDetailedTemperature") private var showDetailedTemperature = false
    @AppStorage("temperatureUnit") private var temperatureUnit = "Celsius"
    @State private var showingSaveWarning = false
    
    // MARK: - Initializers
    init(gameState: GameState) {
        self.gameState = gameState
        _timedState = StateObject(wrappedValue: ClassicTimedGameState(gameState: gameState))
    }
    
    // MARK: - Public Methods
    var body: some View {
        ZStack {
            GameSceneProvider(gameState: gameState)
            mainGameView
            overlays
            scoreAnimator
            
            // Game Over Overlay - positioned above everything else
            GameOverOverlay(
                isPresented: gameState.isGameOver,
                score: gameState.score,
                level: gameState.level,
                onRetry: {
                    gameState.resetGame()
                    Task {
                        await timedState.startNewLevel()
                    }
                },
                onMainMenu: {
                    dismiss()
                },
                onContinue: {
                    Task {
                        await timedState.handleTimeUp()
                    }
                },
                canContinue: !gameState.hasUsedContinueAd,
                isTimedMode: true,
                timeRemaining: timedState.timeRemaining,
                breakdown: gameState.getGameBreakdown()
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Game Over. Final Score: \(gameState.score), Level: \(gameState.level)")
            .zIndex(1000)
            
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
                                                dismiss()
                                            }
                                        } catch {
                                            Logger.shared.log("Error saving progress: \(error.localizedDescription)", category: .firebaseManager, level: .error)
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
        }
        .onAppear {
            UserDefaults.standard.set(true, forKey: "isTimedMode")
            
            // Ensure we start with a completely fresh game
            gameState.startNewGame()
            
            Task {
                await timedState.startNewLevel()
            }
            
            // Add observer for save warning
            NotificationCenter.default.addObserver(
                forName: .showSaveGameWarning,
                object: nil,
                queue: .main
            ) { _ in
                showingSaveWarning = true
            }
        }
        .onDisappear {
            UserDefaults.standard.set(false, forKey: "isTimedMode")
            Task {
                await gameState.cleanup()
            }
            
            // Remove observer
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: gameState.levelComplete) { isComplete in
            if isComplete {
                Task {
                    await timedState.startNewLevel()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private var mainGameView: some View {
        VStack(spacing: 0) {
            GameTopBar(showingSettings: $showingSettings, showingAchievements: $showingAchievements, isPaused: $isPaused, gameState: gameState)
                .onChange(of: isPaused) { newValue in
                    if newValue {
                        timedState.pauseGame()
                    } else {
                        timedState.resumeGame()
                    }
                }
            scoreLevelBar
            if showStatsOverlay && (showFPS || showMemory || showFrame || showCPU || showNetwork || showInput || showResolution || showPing || showBitrate || showJitter || showDecode || showPacketLoss || showTemperature) {
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
            timerView
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
            Text("\(gameState.temporaryScore)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("%d points", comment: "Score accessibility label"), gameState.temporaryScore))
    }
    
    private var timerView: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(NSLocalizedString("Time", comment: "Time label"))
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            Text("\(timedState.timeString)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(timedState.timeColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("%d seconds remaining", comment: "Time accessibility label"), timedState.remainingTime))
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
        ZStack {
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
                    timedState.resumeAfterLevelComplete()
                },
                isPerfectLevel: gameState.isPerfectLevel,
                linesCleared: gameState.linesCleared,
                blocksPlaced: gameState.blocksPlaced,
                currentChain: gameState.currentChain,
                breakdown: gameState.getCurrentLevelBreakdown()
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Level \(gameState.level) Complete! Score: \(gameState.score)")
            
            PauseMenuOverlay(
                isPresented: isPaused,
                onResume: {
                    isPaused = false
                    timedState.resumeGame()
                },
                onSave: {
                    Task {
                        do {
                            // Always save the current game state
                            try await gameState.forceSaveGame()
                            timedState.saveTimerState()
                            isPaused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        } catch {
                            Logger.shared.log("Error saving progress: \(error.localizedDescription)", category: .firebaseManager, level: .error)
                            isPaused = false
                        }
                    }
                },
                onRestart: {
                    gameState.resetGame()
                    Task {
                        await timedState.startNewLevel()
                    }
                    isPaused = false
                },
                onEndGame: {
                    gameState.resetGame()
                    dismiss()
                }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pause Menu")
        }
    }
}

// MARK: - Helpers
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
    @AppStorage("showTemperature") private var showTemperature = false
    @AppStorage("showDetailedTemperature") private var showDetailedTemperature = false
    @AppStorage("temperatureUnit") private var temperatureUnit = "Celsius"
    
    private var hasAnyStatsEnabled: Bool {
        showFPS || showMemory || showFrame || showCPU || showNetwork || showInput || showResolution || showPing || showBitrate || showJitter || showDecode || showPacketLoss || showTemperature
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
                    
                    // Temperature Row
                    if showTemperature {
                        HStack(spacing: 8) {
                            if showDetailedTemperature {
                                StatText("Temp: \(performanceMonitor.getDetailedTemperatureDescription())", color: performanceMonitor.getThermalStateColor())
                            } else {
                                StatText("Temp: \(performanceMonitor.getThermalStateDescription())", color: performanceMonitor.getThermalStateColor())
                            }
                            
                            StatText(performanceMonitor.getThermalStatePercentageString(), color: performanceMonitor.getThermalStateColor())
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
    let color: Color
    
    init(_ text: String, color: Color = .white) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(color)
    }
} 
