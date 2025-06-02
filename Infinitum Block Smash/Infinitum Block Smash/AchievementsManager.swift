// Achievement.swift

import Foundation
import Combine
import SwiftUI

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    var unlocked: Bool
    var progress: Int
    var goal: Int
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.unlocked == rhs.unlocked &&
        lhs.progress == rhs.progress &&
        lhs.goal == rhs.goal
    }
    
    static let allAchievements: [Achievement] = [
        Achievement(id: "high_score", name: "High Score Champion", description: "Achieve a new high score", unlocked: false, progress: 0, goal: 1),
        Achievement(id: "highest_level", name: "Level Master", description: "Reach a new highest level", unlocked: false, progress: 0, goal: 1),
        Achievement(id: "first_clear", name: "First Clear", description: "Clear your first line", unlocked: false, progress: 0, goal: 1),
        Achievement(id: "combo_3", name: "Combo Master", description: "Clear 3 or more lines at once", unlocked: false, progress: 0, goal: 1),
        Achievement(id: "score_1000", name: "Score Hunter", description: "Reach 1000 points", unlocked: false, progress: 0, goal: 1000)
    ]
}

// AchievementsManager.swift

import Foundation
import Combine

class AchievementsManager: ObservableObject {
    @Published private var achievements: [String: Achievement] = [:]
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadAchievements()
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
        }
        objectWillChange.send()
    }
    
    func updateAchievement(id: String, value: Int) {
        guard var achievement = achievements[id] else { return }
        achievement.progress = value
        if value >= achievement.goal {
            achievement.unlocked = true
        }
        saveAchievement(achievement)
    }
    
    func increment(id: String) {
        guard var achievement = achievements[id] else { return }
        achievement.progress += 1
        if achievement.progress >= achievement.goal {
            achievement.unlocked = true
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
}
