// Achievement.swift

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    var unlocked: Bool
    var progress: Int
    var goal: Int
    var wasNotified: Bool
    let points: Int // Points awarded for unlocking this achievement
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.unlocked == rhs.unlocked &&
        lhs.progress == rhs.progress &&
        lhs.goal == rhs.goal &&
        lhs.wasNotified == rhs.wasNotified &&
        lhs.points == rhs.points
    }
    
    static let allAchievements: [Achievement] = [
        // Daily login achievements
        Achievement(id: "login_1", name: "First Login", description: "Log in for the first time", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "login_3", name: "Regular Login", description: "Log in for 3 consecutive days", unlocked: false, progress: 0, goal: 3, wasNotified: false, points: 25),
        Achievement(id: "login_7", name: "Weekly Login", description: "Log in for 7 consecutive days", unlocked: false, progress: 0, goal: 7, wasNotified: false, points: 50),
        Achievement(id: "login_30", name: "Monthly Login", description: "Log in for 30 consecutive days", unlocked: false, progress: 0, goal: 30, wasNotified: false, points: 100),
        Achievement(id: "login_100", name: "Dedicated Player", description: "Log in for 100 days", unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 250),
        Achievement(id: "daily_login", name: "Daily Login", description: "Log in daily to earn 5 points", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 5),
        
        // Score-based achievements
        Achievement(id: "score_1000", name: "Score Hunter", description: "Reach 1,000 points", unlocked: false, progress: 0, goal: 1000, wasNotified: false, points: 10),
        Achievement(id: "score_5000", name: "Score Master", description: "Reach 5,000 points", unlocked: false, progress: 0, goal: 5000, wasNotified: false, points: 25),
        Achievement(id: "score_10000", name: "Score Legend", description: "Reach 10,000 points", unlocked: false, progress: 0, goal: 10000, wasNotified: false, points: 50),
        Achievement(id: "score_50000", name: "Score God", description: "Reach 50,000 points", unlocked: false, progress: 0, goal: 50000, wasNotified: false, points: 100),
        
        // Level-based achievements
        Achievement(id: "level_5", name: "Rising Star", description: "Reach level 5", unlocked: false, progress: 0, goal: 5, wasNotified: false, points: 10),
        Achievement(id: "level_10", name: "Level Expert", description: "Reach level 10", unlocked: false, progress: 0, goal: 10, wasNotified: false, points: 25),
        Achievement(id: "level_20", name: "Level Master", description: "Reach level 20", unlocked: false, progress: 0, goal: 20, wasNotified: false, points: 50),
        Achievement(id: "level_50", name: "Level Legend", description: "Reach level 50", unlocked: false, progress: 0, goal: 50, wasNotified: false, points: 100),
        
        // Line clearing achievements
        Achievement(id: "first_clear", name: "First Clear", description: "Clear your first line", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "clear_10", name: "Line Clearer", description: "Clear 10 lines", unlocked: false, progress: 0, goal: 10, wasNotified: false, points: 25),
        Achievement(id: "clear_50", name: "Line Master", description: "Clear 50 lines", unlocked: false, progress: 0, goal: 50, wasNotified: false, points: 50),
        Achievement(id: "clear_100", name: "Line Legend", description: "Clear 100 lines", unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 100),
        
        // Combo achievements
        Achievement(id: "combo_3", name: "Combo Master", description: "Clear 3 or more lines at once", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "combo_5", name: "Combo Expert", description: "Clear 5 or more lines at once", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "combo_10", name: "Combo Legend", description: "Clear 10 or more lines at once", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Block placement achievements
        Achievement(id: "place_100", name: "Block Placer", description: "Place 100 blocks", unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 10),
        Achievement(id: "place_500", name: "Block Master", description: "Place 500 blocks", unlocked: false, progress: 0, goal: 500, wasNotified: false, points: 25),
        Achievement(id: "place_1000", name: "Block Legend", description: "Place 1,000 blocks", unlocked: false, progress: 0, goal: 1000, wasNotified: false, points: 50),
        
        // Group achievements
        Achievement(id: "group_10", name: "Group Creator", description: "Create a group of 10 or more blocks", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "group_20", name: "Group Master", description: "Create a group of 20 or more blocks", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "group_30", name: "Group Legend", description: "Create a group of 30 or more blocks", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Perfect level achievements
        Achievement(id: "perfect_level", name: "Perfect Level", description: "Complete a level without any mistakes", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "perfect_levels_3", name: "Perfect Streak", description: "Complete 3 levels perfectly", unlocked: false, progress: 0, goal: 3, wasNotified: false, points: 25),
        Achievement(id: "perfect_levels_5", name: "Perfect Master", description: "Complete 5 levels perfectly", unlocked: false, progress: 0, goal: 5, wasNotified: false, points: 50),
        
        // Speed achievements
        Achievement(id: "quick_clear", name: "Quick Clear", description: "Clear a line within 5 seconds of starting", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "speed_master", name: "Speed Master", description: "Clear 5 lines within 30 seconds", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        
        // Special achievements
        Achievement(id: "high_score", name: "High Score Champion", description: "Achieve a new high score", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "highest_level", name: "Level Master", description: "Reach a new highest level", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "first_game", name: "First Game", description: "Complete your first game", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "games_10", name: "Regular Player", description: "Complete 10 games", unlocked: false, progress: 0, goal: 10, wasNotified: false, points: 25),
        Achievement(id: "games_50", name: "Dedicated Player", description: "Complete 50 games", unlocked: false, progress: 0, goal: 50, wasNotified: false, points: 50),
        Achievement(id: "games_100", name: "Veteran Player", description: "Complete 100 games", unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 100),
        
        // Undo achievements
        Achievement(id: "undo_5", name: "Second Chance", description: "Use undo 5 times", unlocked: false, progress: 0, goal: 5, wasNotified: false, points: 10),
        Achievement(id: "undo_20", name: "Time Turner", description: "Use undo 20 times", unlocked: false, progress: 0, goal: 20, wasNotified: false, points: 25),
        
        // Color achievements
        Achievement(id: "color_master", name: "Color Master", description: "Use all available colors in a single game", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "shape_master", name: "Shape Master", description: "Use all available shapes in a single game", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        
        // Grid achievements
        Achievement(id: "grid_quarter", name: "Grid Quarter", description: "Fill 25% of the grid", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "grid_half", name: "Grid Half", description: "Fill 50% of the grid", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "grid_full", name: "Grid Master", description: "Fill 75% of the grid", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Chain achievements
        Achievement(id: "chain_3", name: "Chain Starter", description: "Create a chain of 3 moves", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "chain_5", name: "Chain Master", description: "Create a chain of 5 moves", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "chain_10", name: "Chain Legend", description: "Create a chain of 10 moves", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Special combinations
        Achievement(id: "rainbow_clear", name: "Rainbow Clear", description: "Clear lines with all colors in one move", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "shape_clear", name: "Shape Clear", description: "Clear lines with all shapes in one move", unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        
        // Time-based achievements
        Achievement(id: "play_1h", name: "Hour Player", description: "Play for 1 hour", unlocked: false, progress: 0, goal: 3600, wasNotified: false, points: 10),
        Achievement(id: "play_5h", name: "Dedicated Hour", description: "Play for 5 hours", unlocked: false, progress: 0, goal: 18000, wasNotified: false, points: 25),
        Achievement(id: "play_10h", name: "Time Master", description: "Play for 10 hours", unlocked: false, progress: 0, goal: 36000, wasNotified: false, points: 50),
        
        // Daily achievements
        Achievement(id: "daily_3", name: "Daily Player", description: "Play for 3 consecutive days", unlocked: false, progress: 0, goal: 3, wasNotified: false, points: 10),
        Achievement(id: "daily_7", name: "Weekly Player", description: "Play for 7 consecutive days", unlocked: false, progress: 0, goal: 7, wasNotified: false, points: 25),
        Achievement(id: "daily_30", name: "Monthly Player", description: "Play for 30 consecutive days", unlocked: false, progress: 0, goal: 30, wasNotified: false, points: 50)
    ]
    
    init(id: String, name: String, description: String, unlocked: Bool = false, progress: Int = 0, goal: Int, wasNotified: Bool = false, points: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.unlocked = unlocked
        self.progress = progress
        self.goal = goal
        self.wasNotified = wasNotified
        self.points = points
    }
}

// AchievementsManager.swift

import Foundation
import Combine

class AchievementsManager: ObservableObject {
    @Published private var achievements: [String: Achievement] = [:]
    @Published var totalPoints: Int = 0
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadAchievements()
        calculateTotalPoints()
    }
    
    private func calculateTotalPoints() {
        totalPoints = achievements.values.filter { $0.unlocked }.reduce(0) { $0 + $1.points }
    }
    
    private func loadAchievements() {
        for achievement in Achievement.allAchievements {
            if let savedData = userDefaults.data(forKey: achievement.id),
               let savedAchievement = try? JSONDecoder().decode(Achievement.self, from: savedData) {
                achievements[achievement.id] = savedAchievement
            } else {
                achievements[achievement.id] = achievement
            }
        }
    }
    
    private func saveAchievement(_ achievement: Achievement) {
        achievements[achievement.id] = achievement
        if let encoded = try? JSONEncoder().encode(achievement) {
            userDefaults.set(encoded, forKey: achievement.id)
            userDefaults.synchronize()  // Force immediate save
        }
        calculateTotalPoints()
        objectWillChange.send()
    }
    
    func updateAchievement(id: String, value: Int) {
        guard var achievement = achievements[id] else { return }
        
        // Update progress
        achievement.progress = value
        
        // Check if achievement should be unlocked
        if value >= achievement.goal && !achievement.unlocked {
            achievement.unlocked = true
            achievement.wasNotified = false  // Reset notification flag when newly unlocked
            updateLeaderboard()
        }
        
        saveAchievement(achievement)
    }
    
    func increment(id: String) {
        guard var achievement = achievements[id] else { return }
        
        // Increment progress
        achievement.progress += 1
        
        // Check if achievement should be unlocked
        if achievement.progress >= achievement.goal && !achievement.unlocked {
            achievement.unlocked = true
            achievement.wasNotified = false  // Reset notification flag when newly unlocked
            updateLeaderboard()
        }
        
        saveAchievement(achievement)
    }
    
    func setProgress(id: String, to value: Int) {
        updateAchievement(id: id, value: value)
    }
    
    func getProgress(for id: String) -> Int {
        return achievements[id]?.progress ?? 0
    }
    
    func isUnlocked(id: String) -> Bool {
        return achievements[id]?.unlocked ?? false
    }
    
    func getAllAchievements() -> [Achievement] {
        return Array(achievements.values)
    }
    
    func markAsNotified(id: String) {
        guard var achievement = achievements[id] else { return }
        achievement.wasNotified = true
        saveAchievement(achievement)
    }
    
    private func updateLeaderboard() {
        Task {
            do {
                guard let userID = UserDefaults.standard.string(forKey: "userID"),
                      let username = UserDefaults.standard.string(forKey: "username") else {
                    print("[Achievement Leaderboard] Error: Missing userID or username")
                    return
                }
                
                // Check if user is authenticated
                guard Auth.auth().currentUser != nil else {
                    print("[Achievement Leaderboard] Error: User not authenticated")
                    return
                }
                
                try await LeaderboardService.shared.updateLeaderboard(
                    type: .achievement,
                    score: totalPoints,
                    username: username,
                    userID: userID
                )
                print("[Achievement Leaderboard] Successfully updated leaderboard")
            } catch {
                print("[Achievement Leaderboard] Error updating leaderboard: \(error.localizedDescription)")
            }
        }
    }
    
    func checkAchievementProgress(score: Int, level: Int) async throws -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        
        for achievement in getAllAchievements() {
            if !achievement.unlocked {
                let shouldUnlock = checkIfAchievementShouldUnlock(achievement, score: score, level: level)
                if shouldUnlock {
                    var updatedAchievement = achievement
                    updatedAchievement.unlocked = true
                    updatedAchievement.wasNotified = false
                    newlyUnlocked.append(updatedAchievement)
                    saveAchievement(updatedAchievement)
                }
            }
        }
        
        return newlyUnlocked
    }
    
    private func checkIfAchievementShouldUnlock(_ achievement: Achievement, score: Int, level: Int) -> Bool {
        switch achievement.id {
        // Score achievements
        case "score_1000":
            return score >= 1000
        case "score_5000":
            return score >= 5000
        case "score_10000":
            return score >= 10000
        case "score_50000":
            return score >= 50000
            
        // Level achievements
        case "level_5":
            return level >= 5
        case "level_10":
            return level >= 10
        case "level_20":
            return level >= 20
        case "level_50":
            return level >= 50
            
        // Line clearing achievements
        case "clear_10":
            return achievement.progress >= 10
        case "clear_50":
            return achievement.progress >= 50
        case "clear_100":
            return achievement.progress >= 100
            
        // Combo achievements
        case "combo_3", "combo_5", "combo_10":
            return achievement.progress >= 1
            
        // Block placement achievements
        case "place_100":
            return achievement.progress >= 100
        case "place_500":
            return achievement.progress >= 500
        case "place_1000":
            return achievement.progress >= 1000
            
        // Group achievements
        case "group_10", "group_20", "group_30":
            return achievement.progress >= 1
            
        // Perfect level achievements
        case "perfect_level":
            return achievement.progress >= 1
        case "perfect_levels_3":
            return achievement.progress >= 3
        case "perfect_levels_5":
            return achievement.progress >= 5
            
        // Special achievements
        case "color_master", "shape_master", "rainbow_clear", "shape_clear":
            return achievement.progress >= 1
            
        // Grid achievements
        case "grid_quarter", "grid_half", "grid_full":
            return achievement.progress >= 1
            
        // Chain achievements
        case "chain_3", "chain_5", "chain_10":
            return achievement.progress >= 1
            
        // Time-based achievements
        case "play_1h":
            return achievement.progress >= 3600
        case "play_5h":
            return achievement.progress >= 18000
        case "play_10h":
            return achievement.progress >= 36000
            
        // Daily achievements
        case "daily_3":
            return achievement.progress >= 3
        case "daily_7":
            return achievement.progress >= 7
        case "daily_30":
            return achievement.progress >= 30
            
        // Login achievements
        case "login_1", "login_3", "login_7", "login_30", "login_100":
            return achievement.progress >= achievement.goal
            
        // Game completion achievements
        case "first_game", "games_10", "games_50", "games_100":
            return achievement.progress >= achievement.goal
            
        // Undo achievements
        case "undo_5":
            return achievement.progress >= 5
        case "undo_20":
            return achievement.progress >= 20
            
        default:
            return false
        }
    }
    
    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(Array(achievements.values)) {
            userDefaults.set(encoded, forKey: "achievements")
        }
    }
}
