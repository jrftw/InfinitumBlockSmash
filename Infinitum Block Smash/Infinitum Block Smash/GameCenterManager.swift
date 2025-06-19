import Foundation
import GameKit
import UserNotifications

@MainActor
class GameCenterManager: NSObject {
    static let shared = GameCenterManager()
    
    // Leaderboard IDs
    private enum LeaderboardID {
        // Classic Leaderboard IDs
        static let classicDaily = "com.infinitum.blocksmash.classic.daily"
        static let classicWeekly = "com.infinitum.blocksmash.classic.weekly"
        static let classicMonthly = "com.infinitum.blocksmash.classic.monthly"
        static let classicAllTime = "com.infinitum.blocksmash.classic.alltime"
        
        // Classic Timed Leaderboard IDs
        static let classicTimedDaily = "com.infinitum.blocksmash.classictimed.daily"
        static let classicTimedWeekly = "com.infinitum.blocksmash.classictimed.weekly"
        static let classicTimedMonthly = "com.infinitum.blocksmash.classictimed.monthly"
        static let classicTimedAllTime = "com.infinitum.blocksmash.classictimed.alltime"
        
        // Achievement Leaderboard IDs
        static let achievementDaily = "com.infinitum.blocksmash.achievement.daily"
        static let achievementWeekly = "com.infinitum.blocksmash.achievement.weekly"
        static let achievementMonthly = "com.infinitum.blocksmash.achievement.monthly"
        static let achievementAllTime = "com.infinitum.blocksmash.achievement.alltime"
    }
    
    // Achievement IDs
    private enum AchievementID {
        // Login achievements
        static let login1 = "login_1"
        static let login3 = "login_3"
        static let login7 = "login_7"
        static let login30 = "login_30"
        static let login100 = "login_100"
        static let dailyLogin = "daily_login"
        
        // Score achievements
        static let score1000 = "score_1000"
        static let score5000 = "score_5000"
        static let score10000 = "score_10000"
        static let score50000 = "score_50000"
        
        // Level achievements
        static let level5 = "level_5"
        static let level10 = "level_10"
        static let level20 = "level_20"
        static let level50 = "level_50"
        
        // Line clearing achievements
        static let firstClear = "first_clear"
        static let clear10 = "clear_10"
        static let clear50 = "clear_50"
        static let clear100 = "clear_100"
        
        // Combo achievements
        static let combo3 = "combo_3"
        static let combo5 = "combo_5"
        static let combo10 = "combo_10"
        
        // Block placement achievements
        static let place100 = "place_100"
        static let place500 = "place_500"
        static let place1000 = "place_1000"
        
        // Perfect level achievements
        static let perfectLevel = "perfect_level"
        static let perfectLevels3 = "perfect_levels_3"
        static let perfectLevels5 = "perfect_levels_5"
        
        // Special achievements
        static let colorMaster = "color_master"
        static let shapeMaster = "shape_master"
        static let rainbowClear = "rainbow_clear"
        static let shapeClear = "shape_clear"
        
        // Grid achievements
        static let gridQuarter = "grid_quarter"
        static let gridHalf = "grid_half"
        static let gridFull = "grid_full"
        
        // Chain achievements
        static let chain3 = "chain_3"
        static let chain5 = "chain_5"
        static let chain10 = "chain_10"
        
        // Time-based achievements
        static let play1h = "play_1h"
        static let play5h = "play_5h"
        static let play10h = "play_10h"
        
        // Daily achievements
        static let daily3 = "daily_3"
        static let daily7 = "daily_7"
        static let daily30 = "daily_30"
        
        // Game completion achievements
        static let firstGame = "first_game"
        static let games10 = "games_10"
        static let games50 = "games_50"
        static let games100 = "games_100"
        
        // Undo achievements
        static let undo5 = "undo_5"
        static let undo20 = "undo_20"
    }
    
    // Add new properties for caching
    private var leaderboardCache: [String: (entries: [GKLeaderboard.Entry], timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // Add achievement descriptions
    private let achievementDescriptions: [String: (title: String, description: String, icon: String)] = [
        "login_1": ("First Login", "Sign in for the first time", "person.fill"),
        "login_3": ("Regular Player", "Sign in for 3 consecutive days", "person.2.fill"),
        "login_7": ("Dedicated Player", "Sign in for 7 consecutive days", "person.3.fill"),
        "login_30": ("Loyal Player", "Sign in for 30 consecutive days", "person.crop.circle.fill"),
        "login_100": ("Master Player", "Sign in for 100 consecutive days", "person.crop.circle.badge.checkmark"),
        "daily_login": ("Daily Player", "Sign in today", "calendar"),
        "score_1000": ("Getting Started", "Reach 1,000 points", "star.fill"),
        "score_5000": ("Rising Star", "Reach 5,000 points", "star.circle.fill"),
        "score_10000": ("Block Master", "Reach 10,000 points", "star.square.fill"),
        "score_50000": ("Block Legend", "Reach 50,000 points", "star.square.on.square.fill"),
        "level_5": ("Level 5", "Reach level 5", "5.circle.fill"),
        "level_10": ("Level 10", "Reach level 10", "10.circle.fill"),
        "level_20": ("Level 20", "Reach level 20", "20.circle.fill"),
        "level_50": ("Level 50", "Reach level 50", "50.circle.fill"),
        "first_clear": ("First Clear", "Clear your first line", "line.3.horizontal"),
        "clear_10": ("Line Master", "Clear 10 lines", "line.3.horizontal.decrease"),
        "clear_50": ("Line Expert", "Clear 50 lines", "line.3.horizontal.decrease.circle"),
        "clear_100": ("Line Legend", "Clear 100 lines", "line.3.horizontal.decrease.circle.fill"),
        "combo_3": ("Combo Starter", "Get a 3x combo", "bolt.fill"),
        "combo_5": ("Combo Master", "Get a 5x combo", "bolt.circle.fill"),
        "combo_10": ("Combo Legend", "Get a 10x combo", "bolt.square.fill"),
        "place_100": ("Block Placer", "Place 100 blocks", "square.fill"),
        "place_500": ("Block Expert", "Place 500 blocks", "square.grid.2x2.fill"),
        "place_1000": ("Block Master", "Place 1,000 blocks", "square.grid.3x3.fill"),
        "perfect_level": ("Perfect Level", "Complete a level perfectly", "checkmark.circle.fill"),
        "perfect_levels_3": ("Perfect Expert", "Complete 3 levels perfectly", "checkmark.circle.badge.checkmark"),
        "perfect_levels_5": ("Perfect Master", "Complete 5 levels perfectly", "checkmark.circle.badge.xmark"),
        "color_master": ("Color Master", "Use all colors in one game", "paintpalette.fill"),
        "shape_master": ("Shape Master", "Use all shapes in one game", "square.on.circle.fill"),
        "rainbow_clear": ("Rainbow Clear", "Clear a rainbow line", "rainbow"),
        "shape_clear": ("Shape Clear", "Clear a shape line", "square.grid.3x3.fill.square"),
        "grid_quarter": ("Quarter Grid", "Fill a quarter of the grid", "square.grid.2x2"),
        "grid_half": ("Half Grid", "Fill half of the grid", "square.grid.3x3"),
        "grid_full": ("Full Grid", "Fill the entire grid", "square.grid.4x3.fill")
    ]
    
    private override init() {}
    
    func submitScore(_ score: Int, for type: LeaderboardType, period: String) {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("[GameCenter] Player not authenticated")
            return
        }
        
        let leaderboardID: String
        switch (type, period) {
        case (.score, "daily"):
            leaderboardID = LeaderboardID.classicDaily
        case (.score, "weekly"):
            leaderboardID = LeaderboardID.classicWeekly
        case (.score, "monthly"):
            leaderboardID = LeaderboardID.classicMonthly
        case (.score, "alltime"):
            leaderboardID = LeaderboardID.classicAllTime
        case (.score, "dailyTimed"):
            leaderboardID = LeaderboardID.classicTimedDaily
        case (.score, "weeklyTimed"):
            leaderboardID = LeaderboardID.classicTimedWeekly
        case (.score, "monthlyTimed"):
            leaderboardID = LeaderboardID.classicTimedMonthly
        case (.score, "alltimeTimed"):
            leaderboardID = LeaderboardID.classicTimedAllTime
        case (.achievement, "daily"):
            leaderboardID = LeaderboardID.achievementDaily
        case (.achievement, "weekly"):
            leaderboardID = LeaderboardID.achievementWeekly
        case (.achievement, "monthly"):
            leaderboardID = LeaderboardID.achievementMonthly
        case (.achievement, "alltime"):
            leaderboardID = LeaderboardID.achievementAllTime
        default:
            print("[GameCenter] Invalid leaderboard type or period")
            return
        }
        
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { error in
            if let error = error {
                print("[GameCenter] Error submitting score: \(error.localizedDescription)")
            } else {
                print("[GameCenter] Successfully submitted score to \(leaderboardID)")
            }
        }
    }
    
    func reportAchievement(id: String, percentComplete: Double) {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("[GameCenter] Player not authenticated")
            return
        }
        
        Task {
            do {
                let achievement = GKAchievement(identifier: id)
                achievement.percentComplete = percentComplete
                try await GKAchievement.report([achievement])
                print("[GameCenter] Successfully reported achievement \(id) with \(percentComplete)% completion")
            } catch {
                print("[GameCenter] Error reporting achievement: \(error.localizedDescription)")
            }
        }
    }
    
    func loadLeaderboard(type: LeaderboardType, period: String, completion: @escaping ([GKLeaderboard.Entry]?, Error?) -> Void) {
        guard GKLocalPlayer.local.isAuthenticated else {
            completion(nil, NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not authenticated"]))
            return
        }
        
        let leaderboardID: String
        switch (type, period) {
        case (.score, "daily"):
            leaderboardID = LeaderboardID.classicDaily
        case (.score, "weekly"):
            leaderboardID = LeaderboardID.classicWeekly
        case (.score, "monthly"):
            leaderboardID = LeaderboardID.classicMonthly
        case (.score, "alltime"):
            leaderboardID = LeaderboardID.classicAllTime
        case (.score, "dailyTimed"):
            leaderboardID = LeaderboardID.classicTimedDaily
        case (.score, "weeklyTimed"):
            leaderboardID = LeaderboardID.classicTimedWeekly
        case (.score, "monthlyTimed"):
            leaderboardID = LeaderboardID.classicTimedMonthly
        case (.score, "alltimeTimed"):
            leaderboardID = LeaderboardID.classicTimedAllTime
        case (.achievement, "daily"):
            leaderboardID = LeaderboardID.achievementDaily
        case (.achievement, "weekly"):
            leaderboardID = LeaderboardID.achievementWeekly
        case (.achievement, "monthly"):
            leaderboardID = LeaderboardID.achievementMonthly
        case (.achievement, "alltime"):
            leaderboardID = LeaderboardID.achievementAllTime
        default:
            completion(nil, NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid leaderboard type or period"]))
            return
        }
        
        GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { leaderboards, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let leaderboard = leaderboards?.first else {
                completion(nil, NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Leaderboard not found"]))
                return
            }
            
            leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 10)) { localPlayerEntry, entries, totalPlayerCount, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                completion(entries, nil)
            }
        }
    }
    
    // Add method to present Game Center UI
    func presentGameCenterUI() {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("[GameCenter] Player not authenticated")
            return
        }
        
        Task { @MainActor in
            let gcVC = GKGameCenterViewController()
            gcVC.gameCenterDelegate = self
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(gcVC, animated: true)
            }
        }
    }
    
    // Update method to present achievements UI
    func presentAchievementsUI() {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("[GameCenter] Player not authenticated")
            return
        }
        
        if #available(iOS 14.0, *) {
            // Use the new API for iOS 14+
            Task { @MainActor in
                let achievementVC = GKGameCenterViewController()
                achievementVC.gameCenterDelegate = self
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.present(achievementVC, animated: true)
                }
            }
        } else {
            // Fallback for older iOS versions
            Task { @MainActor in
                let gcVC = GKGameCenterViewController()
                gcVC.gameCenterDelegate = self
                gcVC.viewState = .achievements
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.present(gcVC, animated: true)
                }
            }
        }
    }
    
    // Add method to get achievement progress
    func getAchievementProgress(id: String) async -> Double {
        guard GKLocalPlayer.local.isAuthenticated else { return 0 }
        
        do {
            let achievements = try await GKAchievement.loadAchievements()
            if let achievement = achievements.first(where: { $0.identifier == id }) {
                return achievement.percentComplete
            }
        } catch {
            print("[GameCenter] Error loading achievement progress: \(error.localizedDescription)")
        }
        return 0
    }
    
    // Add method to get achievement description
    func getAchievementDescription(id: String) -> (title: String, description: String, icon: String)? {
        return achievementDescriptions[id]
    }
    
    // Add method to show achievement unlock notification
    func showAchievementUnlockNotification(id: String) {
        guard let description = achievementDescriptions[id] else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked!"
        content.subtitle = description.title
        content.body = description.description
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Add method to load leaderboard with caching
    func loadLeaderboardWithCache(type: LeaderboardType, period: String, completion: @escaping ([GKLeaderboard.Entry]?, Error?) -> Void) {
        let cacheKey = "\(type)_\(period)"
        
        // Check cache first
        if let cachedData = leaderboardCache[cacheKey],
           Date().timeIntervalSince(cachedData.timestamp) < cacheExpirationInterval {
            completion(cachedData.entries, nil)
            return
        }
        
        // If not in cache or expired, load from Game Center
        loadLeaderboard(type: type, period: period) { [weak self] entries, error in
            if let entries = entries {
                // Update cache
                self?.leaderboardCache[cacheKey] = (entries: entries, timestamp: Date())
            }
            completion(entries, error)
        }
    }
    
    // Add method to load leaderboard with pagination
    func loadLeaderboardWithPagination(type: LeaderboardType, period: String, range: NSRange, completion: @escaping ([GKLeaderboard.Entry]?, Error?) -> Void) {
        guard GKLocalPlayer.local.isAuthenticated else {
            completion(nil, NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not authenticated"]))
            return
        }
        
        let leaderboardID: String
        switch (type, period) {
        case (.score, "daily"):
            leaderboardID = LeaderboardID.classicDaily
        case (.score, "weekly"):
            leaderboardID = LeaderboardID.classicWeekly
        case (.score, "monthly"):
            leaderboardID = LeaderboardID.classicMonthly
        case (.score, "alltime"):
            leaderboardID = LeaderboardID.classicAllTime
        case (.score, "dailyTimed"):
            leaderboardID = LeaderboardID.classicTimedDaily
        case (.score, "weeklyTimed"):
            leaderboardID = LeaderboardID.classicTimedWeekly
        case (.score, "monthlyTimed"):
            leaderboardID = LeaderboardID.classicTimedMonthly
        case (.score, "alltimeTimed"):
            leaderboardID = LeaderboardID.classicTimedAllTime
        case (.achievement, "daily"):
            leaderboardID = LeaderboardID.achievementDaily
        case (.achievement, "weekly"):
            leaderboardID = LeaderboardID.achievementWeekly
        case (.achievement, "monthly"):
            leaderboardID = LeaderboardID.achievementMonthly
        case (.achievement, "alltime"):
            leaderboardID = LeaderboardID.achievementAllTime
        default:
            completion(nil, NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid leaderboard type or period"]))
            return
        }
        
        GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { leaderboards, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let leaderboard = leaderboards?.first else {
                completion(nil, NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Leaderboard not found"]))
                return
            }
            
            leaderboard.loadEntries(for: .global, timeScope: .allTime, range: range) { localPlayerEntry, entries, totalPlayerCount, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                completion(entries, nil)
            }
        }
    }
}

// Update Game Center delegate
extension GameCenterManager: GKGameCenterControllerDelegate {
    @preconcurrency
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }
} 
