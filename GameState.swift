import Foundation
import Combine
import SwiftUI

class GameState: ObservableObject, Codable {
    @Published var score: Int = 0
    @Published var isGameOver: Bool = false
    @Published var level: Int = 1
    @Published var blocks: [Block] = []
    
    private var timer: Timer?
    
    enum CodingKeys: String, CodingKey {
        case score, isGameOver, level, blocks
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Int.self, forKey: .score)
        isGameOver = try container.decode(Bool.self, forKey: .isGameOver)
        level = try container.decode(Int.self, forKey: .level)
        blocks = try container.decode([Block].self, forKey: .blocks)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(score, forKey: .score)
        try container.encode(isGameOver, forKey: .isGameOver)
        try container.encode(level, forKey: .level)
        try container.encode(blocks, forKey: .blocks)
    }
    
    init() {
        setupGame()
    }
    
    func setupGame() {
        score = 0
        isGameOver = false
        level = 1
        blocks = []
        startGame()
    }
    
    func startGame() {
        // Initialize game blocks
        generateBlocks()
    }
    
    func resetGame() {
        setupGame()
    }
    
    func generateBlocks() {
        // Generate initial blocks based on level
        let rows = 5 + (level - 1)
        let columns = 8
        
        for row in 0..<rows {
            for col in 0..<columns {
                let block = Block(
                    position: CGPoint(x: col * 50 + 25, y: row * 30 + 25),
                    color: BlockColor.random()
                )
                blocks.append(block)
            }
        }
    }
    
    func addScore(_ points: Int, at position: CGPoint? = nil) {
        let oldScore = score
        score += points
        print("[Score] Added \(points) points (from \(oldScore) to \(score))")
        
        // Show score animation if position is provided
        if let position = position {
            delegate?.showScoreAnimation(points: points, at: position)
        }
        
        achievementsManager.updateAchievement(id: "score_1000", value: score)
        
        // Update leaderboard for any score change in daily mode
        updateLeaderboard()
        
        // Global high score
        if score > userDefaults.integer(forKey: scoreKey) {
            achievementsManager.updateAchievement(id: "high_score", value: score)
            userDefaults.set(score, forKey: scoreKey)
        }
        
        // Per-level high score
        let levelHighScoreKey = "highScore_level_\(level)"
        let prevLevelHigh = userDefaults.integer(forKey: levelHighScoreKey)
        if score > prevLevelHigh {
            userDefaults.set(score, forKey: levelHighScoreKey)
            print("[HighScore] New high score for level \(level): \(score)")
        }
        
        delegate?.gameStateDidUpdate()
        
        // Check for level up after every score change
        let requiredScore = calculateRequiredScore()
        if score >= requiredScore && !levelComplete {
            print("[Level] Score threshold met for level \(level). Level complete!")
            levelComplete = true
        }
        checkAchievements()
    }
    
    func removeBlock(_ block: Block) {
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks.remove(at: index)
            addScore(10)
            
            if blocks.isEmpty {
                levelUp()
            }
        }
    }
    
    func levelUp() {
        level += 1
        generateBlocks()
    }
    
    func gameOver() {
        isGameOver = true
        timer?.invalidate()
    }
    
    private func updateLeaderboard() {
        Task {
            do {
                guard let userID = UserDefaults.standard.string(forKey: "userID"),
                      let username = UserDefaults.standard.string(forKey: "username") else {
                    print("[Leaderboard] Missing user ID or username")
                    return
                }
                
                try await LeaderboardService.shared.updateLeaderboard(
                    type: .score,
                    score: score,
                    username: username,
                    userID: userID
                )
                print("[Leaderboard] Successfully updated leaderboard with score: \(score)")
            } catch {
                print("[Leaderboard] Error updating leaderboard: \(error.localizedDescription)")
            }
        }
    }
    
    // Error handling
    enum GameError: Error {
        case invalidState
        case saveFailed
        case loadFailed
        
        var localizedDescription: String {
            switch self {
            case .invalidState:
                return "Game state is invalid"
            case .saveFailed:
                return "Failed to save game state"
            case .loadFailed:
                return "Failed to load game state"
            }
        }
    }
} 