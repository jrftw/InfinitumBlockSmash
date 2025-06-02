// Achievement.swift

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

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
        let db = Firestore.firestore()
        let now = Date()
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        guard let userID = UserDefaults.standard.string(forKey: "userID"),
              let username = UserDefaults.standard.string(forKey: "username"),
              !userID.isEmpty, !username.isEmpty else { return }
        
        for period in periods {
            let docRef = db.collection("achievement_leaderboard").document(period).collection("scores").document(userID)
            docRef.getDocument { snapshot, error in
                let prevPoints = snapshot?.data()?["points"] as? Int ?? 0
                if self.totalPoints > prevPoints {
                    docRef.setData([
                        "username": username,
                        "points": self.totalPoints,
                        "timestamp": Timestamp(date: now)
                    ], merge: true)
                }
            }
        }
    }
}
