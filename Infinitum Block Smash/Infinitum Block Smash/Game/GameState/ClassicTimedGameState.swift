/******************************************************
 * FILE: ClassicTimedGameState.swift
 * MARK: Timed Game Mode State Management
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Manages the state and logic for the classic timed game mode,
 * providing time-based gameplay with adaptive difficulty and scoring.
 *
 * KEY RESPONSIBILITIES:
 * - Timer management and countdown functionality
 * - Time-based scoring and bonus calculations
 * - Adaptive difficulty based on level progression
 * - Pause/resume timer functionality
 * - Time limit calculations for different levels
 * - Integration with main game state
 * - Leaderboard submission for timed scores
 *
 * MAJOR DEPENDENCIES:
 * - GameState.swift: Main game state and logic
 * - AdaptiveDifficultyManager.swift: Dynamic difficulty adjustment
 * - LeaderboardService.swift: Score submission
 * - FirebaseFirestore: Cloud data persistence
 * - Combine: Reactive state management
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for timer and time management
 * - SwiftUI: Modern UI framework for state observation
 * - Combine: Reactive programming for state updates
 * - FirebaseFirestore: Cloud database for leaderboard
 * - FirebaseAuth: User authentication
 *
 * ARCHITECTURE ROLE:
 * Acts as a specialized game mode layer that extends the main
 * game state with time-based mechanics and scoring.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Timer must be properly managed to prevent memory leaks
 * - Time calculations must be accurate and synchronized
 * - State updates must occur on main thread
 * - Difficulty adjustments must be applied correctly
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify timer accuracy and synchronization
 * - Check memory management for timer objects
 * - Test difficulty adjustment calculations
 * - Validate leaderboard submission accuracy
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add time bonus multipliers
 * - Implement time extension power-ups
 * - Add time-based achievements
 ******************************************************/

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ClassicTimedGameState: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var isTimeRunning: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var score: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var highScore: Int = 0
    
    private var timer: Timer?
    private let gameState: GameState
    private let timePerLevel: TimeInterval = 60 // 1 minute per level
    
    private let adaptiveDifficultyManager = AdaptiveDifficultyManager()
    
    var timeString: String {
        if timeRemaining.isFinite && !timeRemaining.isNaN {
            let minutes = Int(max(0, timeRemaining)) / 60
            let seconds = Int(max(0, timeRemaining)) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return "00:00"
    }
    
    var timeColor: Color {
        if timeRemaining.isFinite && !timeRemaining.isNaN {
            return timeRemaining <= 30 ? .red : .white
        }
        return .white
    }
    
    var remainingTime: Int {
        if timeRemaining.isFinite && !timeRemaining.isNaN {
            return Int(max(0, timeRemaining))
        }
        return 0
    }
    
    init(gameState: GameState) {
        self.gameState = gameState
        setupObservers()
        loadTimerState()
        
        // Add observer for level completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLevelCompleted),
            name: .levelCompleted,
            object: nil
        )
    }
    
    private func setupObservers() {
        // Observe score changes from the main game state
        gameState.$temporaryScore
            .receive(on: RunLoop.main)
            .sink { [weak self] newScore in
                self?.score = newScore
            }
            .store(in: &cancellables)
    }
    
    private func getTimeLimit(for level: Int) -> TimeInterval {
        let baseTimeLimit: TimeInterval
        
        switch level {
        case 1...5:
            baseTimeLimit = 60 // 1 minute for first 5 levels
        case 6...10:
            baseTimeLimit = 90 // 1.5 minutes
        case 11...15:
            baseTimeLimit = 120 // 2 minutes
        case 16...20:
            baseTimeLimit = 150 // 2.5 minutes
        case 21...25:
            baseTimeLimit = 180 // 3 minutes
        case 26...30:
            baseTimeLimit = 210 // 3.5 minutes
        case 31...35:
            baseTimeLimit = 240 // 4 minutes
        case 36...40:
            baseTimeLimit = 270 // 4.5 minutes
        case 41...45:
            baseTimeLimit = 300 // 5 minutes
        default:
            baseTimeLimit = 300 // Cap at 5 minutes
        }
        
        // Get adjusted difficulty settings
        let adjustedDifficulty = adaptiveDifficultyManager.getAdjustedDifficulty(for: level)
        
        // Apply time limit multiplier
        return baseTimeLimit * adjustedDifficulty.timeLimitMultiplier
    }
    
    func resetGame() {
        timeRemaining = getTimeLimit(for: gameState.level)
        isTimeRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func startNewLevel() async {
        // Reset timer for new level
        timeRemaining = getTimeLimit(for: gameState.level)
        isTimeRunning = true
        startTimer()
        
        // Ensure score is properly initialized
        if gameState.level == 1 {
            gameState.addScore(-gameState.temporaryScore) // Reset score to 0 by subtracting current score
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    if self.timeRemaining <= 0 {
                        await self.handleTimeUp()
                    }
                }
            }
        }
    }
    
    func handleTimeUp() async {
        isTimeRunning = false
        timer?.invalidate()
        timer = nil
        
        // Save best time to leaderboard
        await saveBestTime()
        
        // Trigger game over
        gameState.gameOver()
    }
    
    private func saveBestTime() async {
        do {
            // Calculate the time score (higher is better for timed mode)
            let timeScore = Int(getTimeLimit(for: gameState.level) - timeRemaining)
            
            // Save to leaderboard with correct type and score
            try await LeaderboardService.shared.updateLeaderboard(
                score: timeScore,
                level: gameState.level,
                time: timeRemaining,
                type: .timed
            )
            print("[TimedMode] Successfully saved time score to leaderboard: \(timeScore)")
        } catch {
            print("[TimedMode] Error saving time score: \(error.localizedDescription)")
        }
    }
    
    func addTimeBonus() {
        let timeBonus = Int(timeRemaining * 10) // 10 points per second remaining
        gameState.addScore(timeBonus)
    }
    
    func cleanup() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Pause/Resume
    func pauseGame() {
        isTimeRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func resumeGame() {
        isTimeRunning = true
        startTimer()
    }
    
    func stopTimer() {
        isTimeRunning = false
        timer?.invalidate()
        timer = nil
        timeRemaining = 0
    }
    
    func saveTimerState() {
        // Only save timer state if there's no existing save
        if !UserDefaults.standard.bool(forKey: "hasSavedGame") {
            UserDefaults.standard.set(timeRemaining, forKey: "timedGame_timeRemaining")
            UserDefaults.standard.set(isTimeRunning, forKey: "timedGame_isTimeRunning")
        }
    }
    
    func confirmSaveTimerState() {
        // Save timer state regardless of existing save
        UserDefaults.standard.set(timeRemaining, forKey: "timedGame_timeRemaining")
        UserDefaults.standard.set(isTimeRunning, forKey: "timedGame_isTimeRunning")
    }
    
    func loadTimerState() {
        timeRemaining = UserDefaults.standard.double(forKey: "timedGame_timeRemaining")
        isTimeRunning = UserDefaults.standard.bool(forKey: "timedGame_isTimeRunning")
        if isTimeRunning {
            startTimer()
        }
    }
    
    @objc private func handleLevelCompleted() {
        // Pause the timer when level is complete
        pauseGame()
        addTimeBonus()
    }
    
    func resumeAfterLevelComplete() {
        // Get the new level's time limit
        let newLevelTimeLimit = getTimeLimit(for: gameState.level)
        // Add any remaining time from previous level, with safety checks
        if timeRemaining.isFinite && !timeRemaining.isNaN {
            timeRemaining = min(newLevelTimeLimit + timeRemaining, 3600) // Cap at 1 hour
        } else {
            timeRemaining = newLevelTimeLimit
        }
        isTimeRunning = true
        startTimer()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func updateLeaderboard() async {
        do {
            try await LeaderboardService.shared.updateLeaderboard(
                score: score,
                level: level,
                time: timeRemaining,
                type: .timed
            )
        } catch {
            print("[ClassicTimedGameState] Error updating leaderboard: \(error)")
        }
    }
} 