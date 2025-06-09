import Foundation
import GameKit

class GameCenterManager {
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
        
        // Group achievements
        static let group10 = "group_10"
        static let group20 = "group_20"
        static let group30 = "group_30"
        
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
    
    private init() {}
    
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
} 