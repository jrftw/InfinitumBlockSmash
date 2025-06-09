import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

@MainActor
final class LeaderboardService {
    static let shared = LeaderboardService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var resetTimer: Timer?
    private let estTimeZone = TimeZone(identifier: "America/New_York")!
    private let pageSize = 20
    private let leaderboardLimit = 20
    
    private init() {
        Task {
            await setupPeriodResets()
            setupResetTimer()
        }
    }
    
    private func setupResetTimer() {
        // Calculate time until next midnight EST
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        // Get current date in EST
        let now = Date()
        let estDate = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
        
        // Get next midnight in EST
        guard let nextMidnight = calendar.nextDate(after: estDate,
                                                 matching: components,
                                                 matchingPolicy: .nextTime) else {
            return
        }
        
        // Convert back to local time for timer
        let localNextMidnight = nextMidnight.addingTimeInterval(-TimeInterval(estTimeZone.secondsFromGMT()))
        
        // Calculate time interval until next midnight
        let timeInterval = localNextMidnight.timeIntervalSince(now)
        
        // Create timer that fires at next midnight
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleMidnightReset()
                // Schedule next timer
                self?.setupResetTimer()
            }
        }
    }
    
    private func handleMidnightReset() async {
        print("[Leaderboard] Performing midnight EST reset")
        let now = Date()
        print("[Leaderboard] Current EST time: \(now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT())))")
        
        await resetPeriodScores(period: "daily", collection: "classic_leaderboard")
        await resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
        UserDefaults.standard.set(now, forKey: "lastDailyReset")
    }
    
    private func setupPeriodResets() async {
        let calendar = Calendar.current
        let now = Date()
        let estNow = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
        
        print("[Leaderboard] Setting up period resets - Current EST time: \(estNow)")
        
        // Daily reset
        if let lastDailyReset = UserDefaults.standard.object(forKey: "lastDailyReset") as? Date {
            let estLastReset = lastDailyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            if !calendar.isDateInToday(estLastReset) {
                print("[Leaderboard] Performing daily reset - Last reset: \(estLastReset)")
                await resetPeriodScores(period: "daily", collection: "classic_leaderboard")
                await resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastDailyReset")
            }
        } else {
            print("[Leaderboard] No previous daily reset found, performing initial reset")
            await resetPeriodScores(period: "daily", collection: "classic_leaderboard")
            await resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastDailyReset")
        }
        
        // Weekly reset
        if let lastWeeklyReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date {
            let estLastReset = lastWeeklyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            if !calendar.isDate(estNow, equalTo: estLastReset, toGranularity: .weekOfYear) {
                print("[Leaderboard] Performing weekly reset - Last reset: \(estLastReset)")
                await resetPeriodScores(period: "weekly", collection: "classic_leaderboard")
                await resetPeriodScores(period: "weekly", collection: "achievement_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
            }
        } else {
            print("[Leaderboard] No previous weekly reset found, performing initial reset")
            await resetPeriodScores(period: "weekly", collection: "classic_leaderboard")
            await resetPeriodScores(period: "weekly", collection: "achievement_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
        }
        
        // Monthly reset
        if let lastMonthlyReset = UserDefaults.standard.object(forKey: "lastMonthlyReset") as? Date {
            let estLastReset = lastMonthlyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            if !calendar.isDate(estNow, equalTo: estLastReset, toGranularity: .month) {
                print("[Leaderboard] Performing monthly reset - Last reset: \(estLastReset)")
                await resetPeriodScores(period: "monthly", collection: "classic_leaderboard")
                await resetPeriodScores(period: "monthly", collection: "achievement_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastMonthlyReset")
            }
        } else {
            print("[Leaderboard] No previous monthly reset found, performing initial reset")
            await resetPeriodScores(period: "monthly", collection: "classic_leaderboard")
            await resetPeriodScores(period: "monthly", collection: "achievement_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastMonthlyReset")
        }
    }
    
    private func resetPeriodScores(period: String, collection: String) async {
        do {
            let scores = try await db.collection(collection)
                .document(period)
                .collection("scores")
                .getDocuments()
            
            // Get current time in EST
            let now = Date()
            let calendar = Calendar.current
            let estNow = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            
            // Get start of current period in EST
            let startOfPeriod: Date
            switch period {
            case "daily":
                startOfPeriod = calendar.startOfDay(for: estNow)
            case "weekly":
                // Get start of week (Sunday) in EST
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: estNow)
                components.weekday = 1 // Sunday
                startOfPeriod = calendar.date(from: components) ?? now
            case "monthly":
                // Get start of month in EST with proper month boundary handling
                var components = calendar.dateComponents([.year, .month], from: estNow)
                components.day = 1
                components.hour = 0
                components.minute = 0
                components.second = 0
                startOfPeriod = calendar.date(from: components) ?? now
            default:
                startOfPeriod = now
            }
            
            print("[Leaderboard] Checking \(period) resets for \(collection) - Start of period: \(startOfPeriod)")
            
            for document in scores.documents {
                // Check if the entry needs to be reset based on EST time
                if let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() {
                    let estTimestamp = timestamp.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
                    
                    let shouldReset: Bool
                    switch period {
                    case "daily":
                        shouldReset = estTimestamp < startOfPeriod
                    case "weekly":
                        shouldReset = estTimestamp < startOfPeriod
                    case "monthly":
                        // For monthly, also check if we're in a new month
                        let estComponents = calendar.dateComponents([.year, .month], from: estTimestamp)
                        let currentComponents = calendar.dateComponents([.year, .month], from: estNow)
                        shouldReset = estTimestamp < startOfPeriod || 
                            estComponents.year != currentComponents.year || 
                            estComponents.month != currentComponents.month
                    default:
                        shouldReset = false
                    }
                    
                    if shouldReset {
                        print("[Leaderboard] Resetting \(period) score for user \(document.documentID) - Timestamp: \(estTimestamp)")
                        try await document.reference.delete()
                    }
                } else {
                    // For backward compatibility - if no timestamp exists, delete the entry
                    print("[Leaderboard] Resetting \(period) score for user \(document.documentID) - No timestamp found")
                    try await document.reference.delete()
                }
            }
        } catch {
            print("[Leaderboard] Error resetting \(period) scores for \(collection): \(error.localizedDescription)")
        }
    }
    
    func updateLeaderboard(type: LeaderboardType, score: Int, username: String, userID: String) async throws {
        print("[Leaderboard] Attempting to update leaderboard - Type: \(type), Score: \(score), User: \(username)")
        
        // Check if user is authenticated
        guard let currentUser = Auth.auth().currentUser else {
            print("[Leaderboard] User not authenticated")
            throw LeaderboardError.notAuthenticated
        }
        
        // Verify the userID matches the authenticated user
        guard currentUser.uid == userID else {
            print("[Leaderboard] UserID mismatch - Current: \(currentUser.uid), Provided: \(userID)")
            throw LeaderboardError.invalidUserData
        }
        
        guard !userID.isEmpty, !username.isEmpty else {
            print("[Leaderboard] Invalid user data - userID or username is empty")
            throw LeaderboardError.invalidUserData
        }
        
        let now = Date()
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        for period in periods {
            let docRef = db.collection(type.collectionName)
                .document(period)
                .collection("scores")
                .document(userID)
            
            do {
                let snapshot = try await docRef.getDocument()
                let prevScore = snapshot.data()?[type.scoreField] as? Int ?? 0
                
                print("[Leaderboard] Checking \(period) leaderboard - Previous score: \(prevScore), New score: \(score)")
                
                // For daily scores, always update if it's a new day in EST
                if period == "daily" {
                    let calendar = Calendar.current
                    if let prevTimestamp = (snapshot.data()?["timestamp"] as? Timestamp)?.dateValue() {
                        let estPrevTimestamp = prevTimestamp.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
                        if !calendar.isDateInToday(estPrevTimestamp) {
                            print("[Leaderboard] Updating daily score - New day in EST")
                            try await docRef.setData([
                                "username": username,
                                type.scoreField: score,
                                "timestamp": Timestamp(date: now)
                            ])
                            // Submit to Game Center
                            GameCenterManager.shared.submitScore(score, for: type, period: period)
                        } else if score > prevScore {
                            print("[Leaderboard] Updating daily score - Higher score")
                            try await docRef.setData([
                                "username": username,
                                type.scoreField: score,
                                "timestamp": Timestamp(date: now)
                            ], merge: true)
                            // Submit to Game Center
                            GameCenterManager.shared.submitScore(score, for: type, period: period)
                        }
                    } else {
                        // For backward compatibility - if no timestamp exists, create new entry
                        print("[Leaderboard] Creating new daily score entry")
                        try await docRef.setData([
                            "username": username,
                            type.scoreField: score,
                            "timestamp": Timestamp(date: now)
                        ])
                        // Submit to Game Center
                        GameCenterManager.shared.submitScore(score, for: type, period: period)
                    }
                } else if score > prevScore {
                    // For other periods, only update if score is higher
                    print("[Leaderboard] Updating \(period) score - Higher score")
                    try await docRef.setData([
                        "username": username,
                        type.scoreField: score,
                        "timestamp": Timestamp(date: now)
                    ], merge: true)
                    // Submit to Game Center
                    GameCenterManager.shared.submitScore(score, for: type, period: period)
                } else {
                    print("[Leaderboard] Skipping \(period) update - Score not higher")
                }
            } catch {
                print("[Leaderboard] Error updating \(period) leaderboard: \(error.localizedDescription)")
                throw LeaderboardError.updateFailed(error)
            }
        }
    }
    
    func getLeaderboard(type: LeaderboardType, period: String) async throws -> (entries: [LeaderboardEntry], totalUsers: Int) {
        print("[Leaderboard] Fetching \(period) leaderboard for type: \(type)")
        
        // Try to get cached data first
        if let cachedData = LeaderboardCache.shared.getCachedLeaderboard(type: type, period: period) {
            return (cachedData, cachedData.count)
        }
        
        do {
            let now = Date()
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            
            var startDate: Date?
            switch period {
            case "daily":
                startDate = startOfDay
            case "weekly":
                startDate = calendar.date(byAdding: .day, value: -7, to: now)
            case "monthly":
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            case "alltime":
                startDate = nil
            default:
                throw LeaderboardError.invalidPeriod
            }
            
            // Get total users count
            let totalUsersQuery = db.collection(type.collectionName)
                .document(period)
                .collection("scores")
            
            if let startDate = startDate {
                totalUsersQuery.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            }
            
            let totalUsersSnapshot = try await totalUsersQuery.count.getAggregation(source: .server)
            let totalUsers = Int(truncating: totalUsersSnapshot.count)
            
            // Get top 20 entries
            var query = db.collection(type.collectionName)
                .document(period)
                .collection("scores")
                .order(by: type.scoreField, descending: true)
                .limit(to: leaderboardLimit)
            
            if let startDate = startDate {
                query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            }
            
            let snapshot = try await query.getDocuments()
            print("[Leaderboard] Retrieved \(snapshot.documents.count) entries for \(period) leaderboard")
            
            let entries = snapshot.documents.compactMap { document -> LeaderboardEntry? in
                guard let username = document.data()["username"] as? String,
                      let score = document.data()[type.scoreField] as? Int,
                      let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() else {
                    print("[Leaderboard] Failed to parse entry: \(document.documentID)")
                    return nil
                }
                return LeaderboardEntry(id: document.documentID, username: username, score: score, timestamp: timestamp)
            }
            
            // Cache the results
            LeaderboardCache.shared.cacheLeaderboard(entries, type: type, period: period)
            
            return (entries, totalUsers)
        } catch {
            print("[Leaderboard] Error loading \(period) leaderboard: \(error.localizedDescription)")
            throw LeaderboardError.loadFailed(error)
        }
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
}

enum LeaderboardError: LocalizedError {
    case invalidUserData
    case updateFailed(Error)
    case loadFailed(Error)
    case invalidPeriod
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidUserData:
            return "Invalid user data"
        case .updateFailed(let error):
            return "Failed to update leaderboard: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load leaderboard: \(error.localizedDescription)"
        case .invalidPeriod:
            return "Invalid time period"
        case .notAuthenticated:
            return "User not authenticated"
        }
    }
} 