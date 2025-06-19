/*
 * File: AchievementsManager.swift
 * Purpose: Complete achievement system manager for tracking, unlocking, and syncing achievements across platforms
 * Author: @jrftw
 * Date: 6/19/2025
 * Dependencies: Foundation, Combine, SwiftUI, FirebaseFirestore, FirebaseAuth, GameKit
 * Related Files: GameState.swift, FirebaseManager.swift, GameCenterManager.swift, AchievementNotificationOverlay.swift, AchievementsView.swift, LeaderboardService.swift
 */

/*
 * AchievementsManager.swift
 * 
 * ACHIEVEMENT SYSTEM MANAGER
 * 
 * This file contains the complete achievement system for Infinitum Block Smash,
 * including achievement definitions, progress tracking, unlocking logic, and
 * integration with Game Center and Firebase for cross-platform achievement sync.
 * 
 * KEY RESPONSIBILITIES:
 * - Achievement definition and categorization
 * - Progress tracking and milestone monitoring
 * - Achievement unlocking and notification
 * - Game Center integration for achievements
 * - Firebase synchronization of achievement data
 * - Points system management
 * - Achievement UI and notification display
 * - Progress persistence and cloud sync
 * 
 * MAJOR DEPENDENCIES:
 * - GameState.swift: Source of game events and statistics
 * - FirebaseManager.swift: Achievement data persistence
 * - GameCenterManager.swift: Game Center achievement submission
 * - AchievementNotificationOverlay.swift: Visual achievement notifications
 * - AchievementsView.swift: Achievement display UI
 * - LeaderboardService.swift: Points submission to leaderboards
 * 
 * ACHIEVEMENT CATEGORIES:
 * - Daily Login: Consecutive login streaks
 * - Score-based: Milestone score achievements
 * - Level-based: Progress through game levels
 * - Line Clearing: Line clearing milestones
 * - Combo: Multi-line clearing achievements
 * - Block Placement: Total blocks placed
 * - Perfect Levels: Flawless level completion
 * - Speed: Time-based achievements
 * - Special: Unique game events
 * - Undo: Undo usage milestones
 * 
 * PROGRESS TRACKING:
 * - Real-time monitoring of game events
 * - Automatic progress updates
 * - Milestone detection and triggering
 * - Progress persistence across sessions
 * - Cloud synchronization of achievements
 * 
 * NOTIFICATION SYSTEM:
 * - Achievement unlock notifications
 * - Progress milestone alerts
 * - Game Center achievement submission
 * - Visual feedback and animations
 * - Sound effects for achievements
 * 
 * POINTS SYSTEM:
 * - Achievement-based point rewards
 * - Points accumulation tracking
 * - Leaderboard integration
 * - Daily login bonus points
 * - Special event point multipliers
 * 
 * GAME CENTER INTEGRATION:
 * - Automatic achievement submission
 * - Progress synchronization
 * - Leaderboard integration
 * - Cross-device achievement sync
 * - Offline achievement queuing
 * 
 * FIREBASE INTEGRATION:
 * - Achievement data persistence
 * - Cross-device synchronization
 * - Offline queue management
 * - User achievement history
 * - Analytics tracking
 * 
 * PERFORMANCE FEATURES:
 * - Efficient progress tracking
 * - Debounced achievement checks
 * - Memory-efficient data structures
 * - Background synchronization
 * - Cached achievement data
 * 
 * ARCHITECTURE ROLE:
 * This class acts as a specialized manager for the achievement system,
 * providing a clean interface for achievement tracking and management.
 * It integrates with multiple systems to provide a comprehensive
 * achievement experience.
 * 
 * THREADING CONSIDERATIONS:
 * - Achievement checks run on background queues
 * - UI updates occur on main thread
 * - Firebase operations use async/await
 * - Game Center operations are thread-safe
 * 
 * INTEGRATION POINTS:
 * - GameState for event monitoring
 * - Firebase for data persistence
 * - Game Center for platform achievements
 * - UI components for display
 * - Analytics for tracking
 */

// Achievement.swift

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import GameKit

// Core achievement data structure with progress tracking and notification state
// Supports Codable for persistence and Equatable for comparison operations
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
    
    // Custom equality comparison for achievement objects
    // Compares all relevant fields to determine if achievements are equivalent
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
    
    // Complete list of all available achievements in the game
    // Organized by category with appropriate goals and point rewards
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
    
    // Custom initializer for creating achievement instances
    // Sets default values for optional parameters
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

// Main achievement management class with Firebase and Game Center integration
// Handles all achievement tracking, unlocking, and synchronization operations
@MainActor
class AchievementsManager: ObservableObject {
    // Published properties for SwiftUI binding and reactive updates
    @Published private var achievements: [String: Achievement] = [:]
    @Published var totalPoints: Int = 0
    
    // Storage and database references
    private let userDefaults = UserDefaults.standard
    private let db = Firestore.firestore()
    
    // Computed property to access all achievements as array
    // Used by UI components to display achievement lists
    var allAchievements: [Achievement] {
        Array(achievements.values)
    }
    
    // Initialization method that loads achievements and syncs with cloud
    // Sets up the achievement system and calculates initial point totals
    init() {
        loadAchievements()
        calculateTotalPoints()
        Task {
            await syncAchievementsWithFirebase()
        }
    }
    
    // Calculates total points from all unlocked achievements
    // Updates leaderboard when point total changes
    private func calculateTotalPoints() {
        let newTotal = achievements.values.filter { $0.unlocked }.reduce(0) { $0 + $1.points }
        if newTotal != totalPoints {
            totalPoints = newTotal
            updateAchievementLeaderboard()
        }
    }
    
    // Loads achievement data from local storage
    // Creates default achievements if no saved data exists
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
    
    // Saves individual achievement to local storage and syncs with cloud
    // Handles Game Center and Firebase synchronization in background
    private func saveAchievement(_ achievement: Achievement) {
        achievements[achievement.id] = achievement
        if let encoded = try? JSONEncoder().encode(achievement) {
            userDefaults.set(encoded, forKey: achievement.id)
            userDefaults.synchronize()  // Force immediate save
        }
        calculateTotalPoints()
        objectWillChange.send()
        
        // Combine Game Center and Firebase sync into a single Task
        Task {
            if achievement.unlocked {
                let percentComplete = Double(achievement.progress) / Double(achievement.goal) * 100.0
                GameCenterManager.shared.reportAchievement(id: achievement.id, percentComplete: percentComplete)
            }
            await syncAchievementToFirebase(achievement)
        }
    }
    
    // Syncs individual achievement data to Firebase
    // Updates user's achievement collection with latest progress
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
    
    // Syncs all achievements with Firebase data
    // Merges local and cloud data, preferring higher progress values
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
    
    // Updates achievement progress by specified value
    // Checks for completion and triggers notifications
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
    
    // Batch updates multiple achievements simultaneously
    // More efficient than individual updates for multiple achievements
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
    
    // Increments achievement progress by 1
    // Convenience method for simple progress updates
    func increment(id: String) {
        guard var achievement = achievements[id] else { return }
        
        // Increment progress
        achievement.progress += 1
        
        // Check if achievement should be unlocked
        if !achievement.unlocked && achievement.progress >= achievement.goal {
            achievement.unlocked = true
            achievement.wasNotified = false
            NotificationCenter.default.post(name: .achievementUnlocked, object: nil, userInfo: ["achievement": achievement])
        }
        
        // Save progress
        achievements[id] = achievement
        saveAchievements()
    }
    
    // Sets achievement progress to specific value
    // Useful for achievements that track absolute values rather than increments
    func setProgress(id: String, progress: Int) {
        guard var achievement = achievements[id] else { return }
        
        // Set progress with goal limit
        achievement.progress = min(progress, achievement.goal)
        
        // Check if achievement should be unlocked
        if !achievement.unlocked && achievement.progress >= achievement.goal {
            achievement.unlocked = true
            achievement.wasNotified = false
            NotificationCenter.default.post(name: .achievementUnlocked, object: nil, userInfo: ["achievement": achievement])
        }
        
        // Save progress
        achievements[id] = achievement
        saveAchievements()
    }
    
    // Gets achievement by ID
    // Returns nil if achievement doesn't exist
    func getAchievement(id: String) -> Achievement? {
        return achievements[id]
    }
    
    // Gets all achievements as array
    // Used by UI components for display
    func getAllAchievements() -> [Achievement] {
        return Array(achievements.values)
    }
    
    // Gets unlocked achievements only
    // Used for statistics and display purposes
    func getUnlockedAchievements() -> [Achievement] {
        return achievements.values.filter { $0.unlocked }
    }
    
    // Gets locked achievements only
    // Used for progress tracking and display
    func getLockedAchievements() -> [Achievement] {
        return achievements.values.filter { !$0.unlocked }
    }
    
    // Gets achievements by category
    // Useful for organizing achievements in UI
    func getAchievementsByCategory(_ category: String) -> [Achievement] {
        return achievements.values.filter { $0.id.hasPrefix(category) }
    }
    
    // Checks if achievement is unlocked
    // Convenience method for quick status checks
    func isUnlocked(id: String) -> Bool {
        return achievements[id]?.unlocked ?? false
    }
    
    // Gets achievement progress
    // Returns current progress value for tracking
    func getProgress(id: String) -> Int {
        return achievements[id]?.progress ?? 0
    }
    
    // Resets all achievements to initial state
    // Used for testing or account reset scenarios
    func resetAllAchievements() {
        for achievement in Achievement.allAchievements {
            var resetAchievement = achievement
            resetAchievement.unlocked = false
            resetAchievement.progress = 0
            resetAchievement.wasNotified = false
            achievements[achievement.id] = resetAchievement
        }
        saveAchievements()
        calculateTotalPoints()
    }
    
    // Marks achievement as notified
    // Prevents duplicate notifications for same achievement
    func markAsNotified(id: String) {
        guard var achievement = achievements[id] else { return }
        achievement.wasNotified = true
        achievements[id] = achievement
        saveAchievements()
    }
    
    // Updates achievement leaderboard with current point total
    // Syncs points to Firebase leaderboard system
    private func updateAchievementLeaderboard() {
        Task {
            do {
                print("[Achievement Leaderboard] 🔄 Starting leaderboard update")
                print("[Achievement Leaderboard] 📊 Total points: \(totalPoints)")
                
                // Get username from user profile
                guard let userId = Auth.auth().currentUser?.uid else {
                    print("[Achievement Leaderboard] ❌ No authenticated user found")
                    return
                }
                
                let db = Firestore.firestore()
                let userDoc = try await db.collection("users").document(userId).getDocument()
                let username = userDoc.data()?["username"] as? String ?? Auth.auth().currentUser?.displayName ?? "Anonymous"
                
                print("[Achievement Leaderboard] 👤 Using username: \(username)")
                
                // Update all time periods
                let periods = ["daily", "weekly", "monthly", "alltime"]
                for period in periods {
                    do {
                        print("[Achievement Leaderboard] 📝 Updating \(period) leaderboard")
                        let docRef = db.collection("achievement_leaderboard")
                            .document(period)
                            .collection("scores")
                            .document(userId)
                        
                        // Get current score from server
                        let doc = try await docRef.getDocument(source: .server)
                        let currentPoints = doc.data()?["points"] as? Int ?? 0
                        
                        // Only update if new score is higher
                        if totalPoints > currentPoints {
                            let data: [String: Any] = [
                                "username": username,
                                "points": totalPoints,
                                "timestamp": FieldValue.serverTimestamp(),
                                "userId": userId,
                                "lastUpdate": FieldValue.serverTimestamp()
                            ]
                            
                            print("[Achievement Leaderboard] 📝 Writing data to Firestore: \(data)")
                            print("[Achievement Leaderboard] 📝 Writing to path: achievement_leaderboard/\(period)/scores/\(userId)")
                            
                            try await docRef.setData(data)
                            print("[Achievement Leaderboard] ✅ Successfully updated \(period) leaderboard")
                            
                            // Track analytics only for significant improvements
                            #if DEBUG
                            await MainActor.run {
                                AnalyticsManager.shared.trackEvent(.performanceMetric(
                                    name: "achievement_leaderboard_update",
                                    value: Double(totalPoints)
                                ))
                            }
                            #else
                            // In release builds, only track significant improvements
                            let pointsImprovement = totalPoints - currentPoints
                            if pointsImprovement > 25 {
                                await MainActor.run {
                                    AnalyticsManager.shared.trackEvent(.performanceMetric(
                                        name: "achievement_leaderboard_significant_improvement",
                                        value: Double(pointsImprovement)
                                    ))
                                }
                            }
                            #endif
                        } else {
                            print("[Achievement Leaderboard] ⏭️ Skipping \(period) update - Current score (\(currentPoints)) is higher than new score (\(totalPoints))")
                            
                            // Track skipped updates in debug mode only
                            #if DEBUG
                            await MainActor.run {
                                AnalyticsManager.shared.trackEvent(.performanceMetric(
                                    name: "achievement_leaderboard_skip",
                                    value: Double(currentPoints - totalPoints)
                                ))
                            }
                            #endif
                        }
                        
                    } catch {
                        print("[Achievement Leaderboard] ❌ Error updating \(period) leaderboard: \(error.localizedDescription)")
                        print("[Achievement Leaderboard] ❌ Error details: \(error)")
                    }
                }
                
                print("[Achievement Leaderboard] ✅ Successfully updated all leaderboards")
            } catch {
                print("[Achievement Leaderboard] ❌ Error getting user data: \(error.localizedDescription)")
            }
        }
    }
    
    // Checks achievement progress based on current game state
    // Evaluates all achievements against current score and level
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
    
    // Determines if achievement should be unlocked based on current game state
    // Contains logic for all achievement types and their unlock conditions
    private func checkIfAchievementShouldUnlock(_ achievement: Achievement, score: Int, level: Int) -> Bool {
        func isProgressAtLeast(_ target: Int) -> Bool {
            return achievement.progress >= target
        }
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
            return isProgressAtLeast(10)
        case "clear_50":
            return isProgressAtLeast(50)
        case "clear_100":
            return isProgressAtLeast(100)

        // Combo achievements
        case "combo_3":
            fallthrough
        case "combo_5":
            fallthrough
        case "combo_10":
            return isProgressAtLeast(1)

        // Block placement achievements
        case "place_100":
            return isProgressAtLeast(100)
        case "place_500":
            return isProgressAtLeast(500)
        case "place_1000":
            return isProgressAtLeast(1000)

        // Perfect level achievements
        case "perfect_level":
            return isProgressAtLeast(1)
        case "perfect_levels_3":
            return isProgressAtLeast(3)
        case "perfect_levels_5":
            return isProgressAtLeast(5)

        // Special achievements
        case "color_master":
            fallthrough
        case "shape_master":
            fallthrough
        case "rainbow_clear":
            fallthrough
        case "shape_clear":
            return isProgressAtLeast(1)

        // Grid achievements
        case "grid_quarter":
            fallthrough
        case "grid_half":
            fallthrough
        case "grid_full":
            return isProgressAtLeast(1)

        // Chain achievements
        case "chain_3":
            fallthrough
        case "chain_5":
            fallthrough
        case "chain_10":
            return isProgressAtLeast(1)

        // Time-based achievements
        case "play_1h":
            return isProgressAtLeast(3600)
        case "play_5h":
            return isProgressAtLeast(18000)
        case "play_10h":
            return isProgressAtLeast(36000)

        // Daily achievements
        case "daily_3":
            return isProgressAtLeast(3)
        case "daily_7":
            return isProgressAtLeast(7)
        case "daily_30":
            return isProgressAtLeast(30)

        // Login achievements
        case "login_1":
            fallthrough
        case "login_3":
            fallthrough
        case "login_7":
            fallthrough
        case "login_30":
            fallthrough
        case "login_100":
            return isProgressAtLeast(achievement.goal)

        // Game completion achievements
        case "first_game":
            fallthrough
        case "games_10":
            fallthrough
        case "games_50":
            fallthrough
        case "games_100":
            return isProgressAtLeast(achievement.goal)

        // Undo achievements
        case "undo_5":
            return isProgressAtLeast(5)
        case "undo_20":
            return isProgressAtLeast(20)

        // High score achievements
        case "high_score":
            return score > UserDefaults.standard.integer(forKey: "highScore")

        // Highest level achievements
        case "highest_level":
            return level > UserDefaults.standard.integer(forKey: "highestLevel")

        // Speed achievements
        case "quick_clear":
            fallthrough
        case "speed_master":
            return isProgressAtLeast(1)  // Will be updated by GameState

        default:
            return false
        }
    }
    
    // Saves all achievements to local storage
    // Encodes achievement array and stores in UserDefaults
    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(Array(achievements.values)) {
            userDefaults.set(encoded, forKey: "achievements")
            userDefaults.synchronize()
        }
    }
    
    // Preloads achievements from storage and syncs with cloud
    // Used during app startup to ensure achievement data is current
    func preloadAchievements() async {
        loadAchievements()
        calculateTotalPoints()
        await syncAchievementsWithFirebase()
    }
}

// Notification name for achievement unlock events
// Used by UI components to respond to achievement unlocks
extension Notification.Name {
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}

// REVIEW NOTES:
// - Large switch statement in checkIfAchievementShouldUnlock could be refactored for maintainability
// - Hard-coded achievement IDs throughout the code - consider using constants
// - No error handling for Firebase sync failures beyond logging
// - UserDefaults synchronization calls may impact performance
// - Achievement progress overflow protection is basic - could be more robust
// - No validation of achievement data from Firebase
// - Game Center integration assumes GameCenterManager.shared exists
// - No retry mechanism for failed Firebase operations
// - Achievement unlock logic is duplicated in multiple methods
// - No cleanup of old achievement data

// FUTURE IDEAS:
// - Refactor achievement unlock logic into separate strategy classes
// - Add achievement categories and filtering system
// - Implement achievement progress analytics
// - Add achievement sharing functionality
// - Create achievement templates for easy addition of new achievements
// - Add achievement rarity system
// - Implement achievement streaks and multipliers
// - Add achievement progress visualization
// - Create achievement comparison features
// - Add achievement export/import functionality
// - Implement achievement-based rewards beyond points
// - Add achievement progress notifications
// - Create achievement leaderboards by category
