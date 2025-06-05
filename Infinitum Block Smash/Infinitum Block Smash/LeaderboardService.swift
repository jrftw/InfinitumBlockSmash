import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

@MainActor
final class LeaderboardService {
    static let shared = LeaderboardService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupPeriodResets()
    }
    
    private func setupPeriodResets() {
        let calendar = Calendar.current
        let now = Date()
        // Daily reset
        if let lastDailyReset = UserDefaults.standard.object(forKey: "lastDailyReset") as? Date {
            if !calendar.isDateInToday(lastDailyReset) {
                resetPeriodScores(period: "daily", collection: "classic_leaderboard")
                resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastDailyReset")
            }
        } else {
            resetPeriodScores(period: "daily", collection: "classic_leaderboard")
            resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastDailyReset")
        }
        // Weekly reset
        if let lastWeeklyReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date {
            if !calendar.isDate(now, equalTo: lastWeeklyReset, toGranularity: .weekOfYear) {
                resetPeriodScores(period: "weekly", collection: "classic_leaderboard")
                resetPeriodScores(period: "weekly", collection: "achievement_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
            }
        } else {
            resetPeriodScores(period: "weekly", collection: "classic_leaderboard")
            resetPeriodScores(period: "weekly", collection: "achievement_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
        }
        // Monthly reset
        if let lastMonthlyReset = UserDefaults.standard.object(forKey: "lastMonthlyReset") as? Date {
            if !calendar.isDate(now, equalTo: lastMonthlyReset, toGranularity: .month) {
                resetPeriodScores(period: "monthly", collection: "classic_leaderboard")
                resetPeriodScores(period: "monthly", collection: "achievement_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastMonthlyReset")
            }
        } else {
            resetPeriodScores(period: "monthly", collection: "classic_leaderboard")
            resetPeriodScores(period: "monthly", collection: "achievement_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastMonthlyReset")
        }
    }
    
    private func resetPeriodScores(period: String, collection: String) {
        Task {
            do {
                let scores = try await db.collection(collection)
                    .document(period)
                    .collection("scores")
                    .getDocuments()
                for document in scores.documents {
                    try await document.reference.delete()
                }
            } catch {
                print("[Leaderboard] Error resetting \(period) scores for \(collection): \(error.localizedDescription)")
            }
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
                
                // For daily scores, always update if it's a new day
                if period == "daily" {
                    let calendar = Calendar.current
                    if let prevTimestamp = (snapshot.data()?["timestamp"] as? Timestamp)?.dateValue(),
                       !calendar.isDateInToday(prevTimestamp) {
                        print("[Leaderboard] Updating daily score - New day")
                        try await docRef.setData([
                            "username": username,
                            type.scoreField: score,
                            "timestamp": Timestamp(date: now)
                        ])
                    } else if score > prevScore {
                        print("[Leaderboard] Updating daily score - Higher score")
                        try await docRef.setData([
                            "username": username,
                            type.scoreField: score,
                            "timestamp": Timestamp(date: now)
                        ], merge: true)
                    }
                } else if score > prevScore {
                    // For other periods, only update if score is higher
                    print("[Leaderboard] Updating \(period) score - Higher score")
                    try await docRef.setData([
                        "username": username,
                        type.scoreField: score,
                        "timestamp": Timestamp(date: now)
                    ], merge: true)
                } else {
                    print("[Leaderboard] Skipping \(period) update - Score not higher")
                }
            } catch {
                print("[Leaderboard] Error updating \(period) leaderboard: \(error.localizedDescription)")
                throw LeaderboardError.updateFailed(error)
            }
        }
    }
    
    func getLeaderboard(type: LeaderboardType, period: String) async throws -> [LeaderboardEntry] {
        print("[Leaderboard] Fetching \(period) leaderboard for type: \(type)")
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
            
            var query = db.collection(type.collectionName)
                .document(period)
                .collection("scores")
                .order(by: type.scoreField, descending: true)
                .limit(to: 10)
            
            if let startDate = startDate {
                query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            }
            
            let snapshot = try await query.getDocuments()
            print("[Leaderboard] Retrieved \(snapshot.documents.count) entries for \(period) leaderboard")
            
            return snapshot.documents.compactMap { document -> LeaderboardEntry? in
                guard let username = document.data()["username"] as? String,
                      let score = document.data()[type.scoreField] as? Int,
                      let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() else {
                    print("[Leaderboard] Failed to parse entry: \(document.documentID)")
                    return nil
                }
                return LeaderboardEntry(id: document.documentID, username: username, score: score, timestamp: timestamp)
            }
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