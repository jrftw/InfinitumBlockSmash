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
    
    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var timeColor: Color {
        timeRemaining <= 30 ? .red : .white
    }
    
    var remainingTime: Int {
        Int(timeRemaining)
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
    
    // Time limits for different level ranges
    private func getTimeLimit(for level: Int) -> TimeInterval {
        switch level {
        case 1...5:
            return 60 // 1 minute for first 5 levels
        case 6...10:
            return 90 // 1.5 minutes
        case 11...15:
            return 120 // 2 minutes
        case 16...20:
            return 150 // 2.5 minutes
        case 21...25:
            return 180 // 3 minutes
        case 26...30:
            return 210 // 3.5 minutes
        case 31...35:
            return 240 // 4 minutes
        case 36...40:
            return 270 // 4.5 minutes
        case 41...45:
            return 300 // 5 minutes
        default:
            return 300 // Cap at 5 minutes
        }
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
        // Add any remaining time from previous level
        timeRemaining = newLevelTimeLimit + timeRemaining
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