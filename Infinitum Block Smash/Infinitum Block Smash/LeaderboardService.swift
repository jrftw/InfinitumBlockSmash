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
        setupDailyReset()
    }
    
    private func setupDailyReset() {
        // Check if we need to reset daily scores
        if let lastReset = UserDefaults.standard.object(forKey: "lastDailyReset") as? Date {
            let calendar = Calendar.current
            if !calendar.isDateInToday(lastReset) {
                print("[Leaderboard] Resetting daily scores - last reset was: \(lastReset)")
                resetDailyScores()
            }
        } else {
            print("[Leaderboard] First time setup - resetting daily scores")
            resetDailyScores()
        }
    }
    
    private func resetDailyScores() {
        Task {
            do {
                print("[Leaderboard] Starting daily scores reset")
                // Delete all daily scores
                let dailyScores = try await db.collection("classic_leaderboard")
                    .document("daily")
                    .collection("scores")
                    .getDocuments()
                
                print("[Leaderboard] Found \(dailyScores.documents.count) daily scores to reset")
                
                for document in dailyScores.documents {
                    try await document.reference.delete()
                }
                
                // Update last reset date
                UserDefaults.standard.set(Date(), forKey: "lastDailyReset")
                print("[Leaderboard] Daily scores reset completed")
            } catch {
                print("[Leaderboard] Error resetting daily scores: \(error.localizedDescription)")
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
                .limit(to: 100)
            
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