// Achievement.swift

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import GameKit

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let earnedDescription: String
    var unlocked: Bool
    var progress: Int
    var goal: Int
    var wasNotified: Bool
    let points: Int // Points awarded for unlocking this achievement
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.earnedDescription == rhs.earnedDescription &&
        lhs.unlocked == rhs.unlocked &&
        lhs.progress == rhs.progress &&
        lhs.goal == rhs.goal &&
        lhs.wasNotified == rhs.wasNotified &&
        lhs.points == rhs.points
    }
    
    static let allAchievements: [Achievement] = [
        // Daily login achievements
        Achievement(id: "login_1", name: "First Login", 
                   description: "Log in for the first time", 
                   earnedDescription: "You've taken your first step into the world of Infinitum Block Smash!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "login_3", name: "Regular Login", 
                   description: "Log in for 3 consecutive days", 
                   earnedDescription: "You're becoming a regular player! Keep up the streak!",
                   unlocked: false, progress: 0, goal: 3, wasNotified: false, points: 25),
        Achievement(id: "login_7", name: "Weekly Login", 
                   description: "Log in for 7 consecutive days", 
                   earnedDescription: "A full week of dedication! You're truly committed!",
                   unlocked: false, progress: 0, goal: 7, wasNotified: false, points: 50),
        Achievement(id: "login_30", name: "Monthly Login", 
                   description: "Log in for 30 consecutive days", 
                   earnedDescription: "A month of dedication! You're a true Infinitum master!",
                   unlocked: false, progress: 0, goal: 30, wasNotified: false, points: 100),
        Achievement(id: "login_100", name: "Dedicated Player", 
                   description: "Log in for 100 days", 
                   earnedDescription: "100 days of dedication! You're a legend of Infinitum!",
                   unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 250),
        Achievement(id: "daily_login", name: "Daily Login", 
                   description: "Log in daily to earn 5 points", 
                   earnedDescription: "Daily dedication pays off! Keep coming back for more!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 5),
        
        // Score-based achievements
        Achievement(id: "score_1000", name: "Score Hunter", 
                   description: "Reach 1,000 points", 
                   earnedDescription: "You've mastered the basics! Your score hunting journey begins!",
                   unlocked: false, progress: 0, goal: 1000, wasNotified: false, points: 10),
        Achievement(id: "score_5000", name: "Score Master", 
                   description: "Reach 5,000 points", 
                   earnedDescription: "You're becoming a true score master! Keep pushing your limits!",
                   unlocked: false, progress: 0, goal: 5000, wasNotified: false, points: 25),
        Achievement(id: "score_10000", name: "Score Legend", 
                   description: "Reach 10,000 points", 
                   earnedDescription: "You've reached legendary status! Your name will be remembered!",
                   unlocked: false, progress: 0, goal: 10000, wasNotified: false, points: 50),
        Achievement(id: "score_50000", name: "Score God", 
                   description: "Reach 50,000 points", 
                   earnedDescription: "You've ascended to godhood! The ultimate score master!",
                   unlocked: false, progress: 0, goal: 50000, wasNotified: false, points: 100),
        
        // Level-based achievements
        Achievement(id: "level_5", name: "Rising Star", 
                   description: "Reach level 5", 
                   earnedDescription: "You're rising through the ranks! A star is born!",
                   unlocked: false, progress: 0, goal: 5, wasNotified: false, points: 10),
        Achievement(id: "level_10", name: "Level Expert", 
                   description: "Reach level 10", 
                   earnedDescription: "You've become an expert! Your skills are truly impressive!",
                   unlocked: false, progress: 0, goal: 10, wasNotified: false, points: 25),
        Achievement(id: "level_20", name: "Level Master", 
                   description: "Reach level 20", 
                   earnedDescription: "You've mastered the game! A true level master!",
                   unlocked: false, progress: 0, goal: 20, wasNotified: false, points: 50),
        Achievement(id: "level_50", name: "Level Legend", 
                   description: "Reach level 50", 
                   earnedDescription: "You've reached legendary status! The ultimate level master!",
                   unlocked: false, progress: 0, goal: 50, wasNotified: false, points: 100),
        
        // Line clearing achievements
        Achievement(id: "first_clear", name: "First Clear", 
                   description: "Clear your first line", 
                   earnedDescription: "Your first line clear! The beginning of your clearing journey!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "clear_10", name: "Line Clearer", 
                   description: "Clear 10 lines", 
                   earnedDescription: "You're becoming a skilled line clearer! Keep up the good work!",
                   unlocked: false, progress: 0, goal: 10, wasNotified: false, points: 25),
        Achievement(id: "clear_50", name: "Line Master", 
                   description: "Clear 50 lines", 
                   earnedDescription: "You've mastered line clearing! A true line master!",
                   unlocked: false, progress: 0, goal: 50, wasNotified: false, points: 50),
        Achievement(id: "clear_100", name: "Line Legend", 
                   description: "Clear 100 lines", 
                   earnedDescription: "You've cleared 100 lines! A legendary achievement!",
                   unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 100),
        
        // Combo achievements
        Achievement(id: "combo_3", name: "Combo Master", 
                   description: "Clear 3 or more lines at once", 
                   earnedDescription: "You've mastered the art of combos! A true combo master!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "combo_5", name: "Combo Expert", 
                   description: "Clear 5 or more lines at once", 
                   earnedDescription: "You've become a combo expert! Your skills are impressive!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "combo_10", name: "Combo Legend", 
                   description: "Clear 10 or more lines at once", 
                   earnedDescription: "You've achieved legendary combo status! Unbelievable skill!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Block placement achievements
        Achievement(id: "place_100", name: "Block Placer", 
                   description: "Place 100 blocks", 
                   earnedDescription: "You've placed 100 blocks! Your journey as a block placer begins!",
                   unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 10),
        Achievement(id: "place_500", name: "Block Master", 
                   description: "Place 500 blocks", 
                   earnedDescription: "You've become a block master! Your precision is impressive!",
                   unlocked: false, progress: 0, goal: 500, wasNotified: false, points: 25),
        Achievement(id: "place_1000", name: "Block Legend", 
                   description: "Place 1,000 blocks", 
                   earnedDescription: "You've placed 1,000 blocks! A legendary achievement!",
                   unlocked: false, progress: 0, goal: 1000, wasNotified: false, points: 50),
        
        // Group achievements
        Achievement(id: "group_10", name: "Group Creator", 
                   description: "Create a group of 10 or more blocks", 
                   earnedDescription: "You've created a massive group! Your strategic mind is impressive!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "group_20", name: "Group Master", 
                   description: "Create a group of 20 or more blocks", 
                   earnedDescription: "You've mastered group creation! Your strategic skills are legendary!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "group_30", name: "Group Legend", 
                   description: "Create a group of 30 or more blocks", 
                   earnedDescription: "You've created a legendary group! Unbelievable strategy!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Perfect level achievements
        Achievement(id: "perfect_level", name: "Perfect Level", 
                   description: "Complete a level without any mistakes", 
                   earnedDescription: "Perfect execution! You've completed a level flawlessly!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "perfect_levels_3", name: "Perfect Streak", 
                   description: "Complete 3 levels perfectly", 
                   earnedDescription: "Three perfect levels! You're on fire!",
                   unlocked: false, progress: 0, goal: 3, wasNotified: false, points: 25),
        Achievement(id: "perfect_levels_5", name: "Perfect Master", 
                   description: "Complete 5 levels perfectly", 
                   earnedDescription: "Five perfect levels! You're a true perfectionist!",
                   unlocked: false, progress: 0, goal: 5, wasNotified: false, points: 50),
        
        // Speed achievements
        Achievement(id: "quick_clear", name: "Quick Clear", 
                   description: "Clear a line within 5 seconds of starting", 
                   earnedDescription: "Lightning fast! You've cleared a line in record time!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "speed_master", name: "Speed Master", 
                   description: "Clear 5 lines within 30 seconds", 
                   earnedDescription: "Speed demon! You've mastered the art of quick clearing!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        
        // Special achievements
        Achievement(id: "high_score", name: "High Score Champion", 
                   description: "Achieve a new high score", 
                   earnedDescription: "New high score! You're the champion!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "highest_level", name: "Level Master", 
                   description: "Reach a new highest level", 
                   earnedDescription: "New highest level! You're pushing the boundaries!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "first_game", name: "First Game", 
                   description: "Complete your first game", 
                   earnedDescription: "Your first game completed! The beginning of your journey!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "games_10", name: "Regular Player", 
                   description: "Complete 10 games", 
                   earnedDescription: "10 games completed! You're becoming a regular!",
                   unlocked: false, progress: 0, goal: 10, wasNotified: false, points: 25),
        Achievement(id: "games_50", name: "Dedicated Player", 
                   description: "Complete 50 games", 
                   earnedDescription: "50 games completed! You're truly dedicated!",
                   unlocked: false, progress: 0, goal: 50, wasNotified: false, points: 50),
        Achievement(id: "games_100", name: "Veteran Player", 
                   description: "Complete 100 games", 
                   earnedDescription: "100 games completed! You're a true veteran!",
                   unlocked: false, progress: 0, goal: 100, wasNotified: false, points: 100),
        
        // Undo achievements
        Achievement(id: "undo_5", name: "Second Chance", 
                   description: "Use undo 5 times", 
                   earnedDescription: "You've learned the value of second chances!",
                   unlocked: false, progress: 0, goal: 5, wasNotified: false, points: 10),
        Achievement(id: "undo_20", name: "Time Turner", 
                   description: "Use undo 20 times", 
                   earnedDescription: "You've mastered the art of time manipulation!",
                   unlocked: false, progress: 0, goal: 20, wasNotified: false, points: 25),
        
        // Color achievements
        Achievement(id: "color_master", name: "Color Master", 
                   description: "Use all available colors in a single game", 
                   earnedDescription: "You've mastered all colors! A true color master!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "shape_master", name: "Shape Master", 
                   description: "Use all available shapes in a single game", 
                   earnedDescription: "You've mastered all shapes! A true shape master!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        
        // Grid achievements
        Achievement(id: "grid_quarter", name: "Grid Quarter", 
                   description: "Fill 25% of the grid", 
                   earnedDescription: "You've filled a quarter of the grid! Your journey begins!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "grid_half", name: "Grid Half", 
                   description: "Fill 50% of the grid", 
                   earnedDescription: "You've filled half the grid! Halfway to mastery!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "grid_full", name: "Grid Master", 
                   description: "Fill 75% of the grid", 
                   earnedDescription: "You've almost filled the entire grid! A true grid master!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Chain achievements
        Achievement(id: "chain_3", name: "Chain Starter", 
                   description: "Create a chain of 3 moves", 
                   earnedDescription: "You've started your chain journey! A chain starter!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "chain_5", name: "Chain Master", 
                   description: "Create a chain of 5 moves", 
                   earnedDescription: "You've mastered the art of chaining! A chain master!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 25),
        Achievement(id: "chain_10", name: "Chain Legend", 
                   description: "Create a chain of 10 moves", 
                   earnedDescription: "You've created a legendary chain! Unbelievable skill!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 50),
        
        // Special combinations
        Achievement(id: "rainbow_clear", name: "Rainbow Clear", 
                   description: "Clear lines with all colors in one move", 
                   earnedDescription: "A rainbow of colors cleared! A spectacular achievement!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        Achievement(id: "shape_clear", name: "Shape Clear", 
                   description: "Clear lines with all shapes in one move", 
                   earnedDescription: "All shapes cleared! A masterful combination!",
                   unlocked: false, progress: 0, goal: 1, wasNotified: false, points: 10),
        
        // Time-based achievements
        Achievement(id: "play_1h", name: "Hour Player", 
                   description: "Play for 1 hour", 
                   earnedDescription: "An hour of dedication! Your journey continues!",
                   unlocked: false, progress: 0, goal: 3600, wasNotified: false, points: 10),
        Achievement(id: "play_5h", name: "Dedicated Hour", 
                   description: "Play for 5 hours", 
                   earnedDescription: "Five hours of dedication! You're truly committed!",
                   unlocked: false, progress: 0, goal: 18000, wasNotified: false, points: 25),
        Achievement(id: "play_10h", name: "Time Master", 
                   description: "Play for 10 hours", 
                   earnedDescription: "Ten hours of mastery! A true time master!",
                   unlocked: false, progress: 0, goal: 36000, wasNotified: false, points: 50),
        
        // Daily achievements
        Achievement(id: "daily_3", name: "Daily Player", 
                   description: "Play for 3 consecutive days", 
                   earnedDescription: "Three days of dedication! You're becoming a regular!",
                   unlocked: false, progress: 0, goal: 3, wasNotified: false, points: 10),
        Achievement(id: "daily_7", name: "Weekly Player", 
                   description: "Play for 7 consecutive days", 
                   earnedDescription: "A full week of dedication! You're truly committed!",
                   unlocked: false, progress: 0, goal: 7, wasNotified: false, points: 25),
        Achievement(id: "daily_30", name: "Monthly Player", 
                   description: "Play for 30 consecutive days", 
                   earnedDescription: "A month of dedication! You're a true Infinitum master!",
                   unlocked: false, progress: 0, goal: 30, wasNotified: false, points: 50)
    ]
    
    init(id: String, name: String, description: String, earnedDescription: String, unlocked: Bool = false, progress: Int = 0, goal: Int, wasNotified: Bool = false, points: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.earnedDescription = earnedDescription
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
    private let db = Firestore.firestore()
    
    var allAchievements: [Achievement] {
        Array(achievements.values)
    }
    
    init() {
        loadAchievements()
        calculateTotalPoints()
        Task {
            await syncAchievementsWithFirebase()
        }
    }
    
    private func calculateTotalPoints() {
        let newTotal = achievements.values.filter { $0.unlocked }.reduce(0) { $0 + $1.points }
        if newTotal != totalPoints {
            totalPoints = newTotal
            updateLeaderboard()
        }
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
        
        // Report to Game Center if achievement is unlocked
        if achievement.unlocked {
            let percentComplete = Double(achievement.progress) / Double(achievement.goal) * 100.0
            GameCenterManager.shared.reportAchievement(id: achievement.id, percentComplete: percentComplete)
        }
        
        // Sync with Firebase
        Task {
            await syncAchievementToFirebase(achievement)
        }
    }
    
    private func syncAchievementToFirebase(_ achievement: Achievement) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let achievementData: [String: Any] = [
                "id": achievement.id,
                "name": achievement.name,
                "description": achievement.description,
                "earnedDescription": achievement.earnedDescription,
                "unlocked": achievement.unlocked,
                "progress": achievement.progress,
                "goal": achievement.goal,
                "wasNotified": achievement.wasNotified,
                "points": achievement.points,
                "lastUpdated": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(userId)
                .collection("achievements")
                .document(achievement.id)
                .setData(achievementData, merge: true)
            
            print("[Achievements] Successfully synced achievement \(achievement.id) to Firebase")
        } catch {
            print("[Achievements] Error syncing achievement to Firebase: \(error.localizedDescription)")
        }
    }
    
    private func syncAchievementsWithFirebase() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("achievements")
                .getDocuments()
            
            var hasUpdates = false
            
            for document in snapshot.documents {
                let data = document.data()
                if let id = data["id"] as? String,
                   let name = data["name"] as? String,
                   let description = data["description"] as? String,
                   let earnedDescription = data["earnedDescription"] as? String,
                   let unlocked = data["unlocked"] as? Bool,
                   let progress = data["progress"] as? Int,
                   let goal = data["goal"] as? Int,
                   let wasNotified = data["wasNotified"] as? Bool,
                   let points = data["points"] as? Int {
                    
                    let firebaseAchievement = Achievement(
                        id: id,
                        name: name,
                        description: description,
                        earnedDescription: earnedDescription,
                        unlocked: unlocked,
                        progress: progress,
                        goal: goal,
                        wasNotified: wasNotified,
                        points: points
                    )
                    
                    // Only update if Firebase data is more recent or has higher progress
                    if let localAchievement = achievements[id] {
                        if firebaseAchievement.progress > localAchievement.progress ||
                           (firebaseAchievement.unlocked && !localAchievement.unlocked) {
                            achievements[id] = firebaseAchievement
                            hasUpdates = true
                        }
                    } else {
                        achievements[id] = firebaseAchievement
                        hasUpdates = true
                    }
                }
            }
            
            if hasUpdates {
                // Save updated achievements to UserDefaults
                saveAchievements()
                calculateTotalPoints()
                objectWillChange.send()
            }
            
            print("[Achievements] Successfully synced achievements with Firebase")
        } catch {
            print("[Achievements] Error syncing achievements with Firebase: \(error.localizedDescription)")
        }
    }
    
    func updateAchievement(id: String, value: Int) {
        guard var achievement = achievements[id] else { return }
        
        // Update progress with maximum value check
        let maxProgress = min(Int.max - achievement.progress, value)
        achievement.progress = min(achievement.progress + maxProgress, achievement.goal)
        
        // Check if achievement is completed
        if !achievement.unlocked && achievement.progress >= achievement.goal {
            achievement.unlocked = true
            achievement.wasNotified = false  // Reset notification flag when newly unlocked
            NotificationCenter.default.post(name: .achievementUnlocked, object: nil, userInfo: ["achievement": achievement])
        }
        
        // Save progress
        achievements[id] = achievement
        saveAchievements()
    }
    
    func batchUpdateAchievements(_ updates: [String: Int]) {
        var anyCompleted = false
        var updatedAchievements: [Achievement] = []
        
        for (id, value) in updates {
            guard var achievement = achievements[id] else { continue }
            
            // Update progress
            achievement.progress = min(achievement.progress + value, achievement.goal)
            
            // Check if achievement is completed
            if !achievement.unlocked && achievement.progress >= achievement.goal {
                achievement.unlocked = true
                achievement.wasNotified = false  // Reset notification flag when newly unlocked
                anyCompleted = true
                updatedAchievements.append(achievement)
            }
            
            // Update the achievement in the dictionary
            achievements[id] = achievement
        }
        
        // Only post notification if any achievement was completed
        if anyCompleted {
            NotificationCenter.default.post(name: .achievementUnlocked, object: nil, userInfo: ["achievements": updatedAchievements])
        }
        
        // Save progress
        saveAchievements()
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
        // Check if user is a guest
        if UserDefaults.standard.bool(forKey: "isGuest") {
            print("[Achievement Leaderboard] Skipping leaderboard update for guest user")
            return
        }
        
        // Only update if there are new achievements unlocked
        let hasNewAchievements = achievements.values.contains { $0.unlocked && !$0.wasNotified }
        guard hasNewAchievements else {
            print("[Achievement Leaderboard] No new achievements to update")
            return
        }
        
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
            
        // High score achievements
        case "high_score":
            return score > UserDefaults.standard.integer(forKey: "highScore")
            
        // Highest level achievements
        case "highest_level":
            return level > UserDefaults.standard.integer(forKey: "highestLevel")
            
        // Speed achievements
        case "quick_clear":
            return achievement.progress >= 1  // Will be updated by GameState
            
        case "speed_master":
            return achievement.progress >= 1  // Will be updated by GameState
            
        default:
            return false
        }
    }
    
    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(Array(achievements.values)) {
            userDefaults.set(encoded, forKey: "achievements")
            userDefaults.synchronize()
        }
    }
    
    // Add method to preload achievements
    func preloadAchievements() async {
        loadAchievements()
        calculateTotalPoints()
        await syncAchievementsWithFirebase()
    }
}

// Add at the top of the file with other extensions
extension Notification.Name {
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}
