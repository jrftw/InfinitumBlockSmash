import Foundation
import FirebaseFirestore
import Combine

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
                resetDailyScores()
            }
        } else {
            // First time setup
            resetDailyScores()
        }
    }
    
    private func resetDailyScores() {
        Task {
            do {
                // Delete all daily scores
                let dailyScores = try await db.collection("classic_leaderboard")
                    .document("daily")
                    .collection("scores")
                    .getDocuments()
                
                for document in dailyScores.documents {
                    try await document.reference.delete()
                }
                
                // Update last reset date
                UserDefaults.standard.set(Date(), forKey: "lastDailyReset")
            } catch {
                print("[Leaderboard] Error resetting daily scores: \(error.localizedDescription)")
            }
        }
    }
    
    func updateLeaderboard(type: LeaderboardType, score: Int, username: String, userID: String) async throws {
        guard !userID.isEmpty, !username.isEmpty else {
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
                
                // For daily scores, always update if it's a new day
                if period == "daily" {
                    let calendar = Calendar.current
                    if let prevTimestamp = (snapshot.data()?["timestamp"] as? Timestamp)?.dateValue(),
                       !calendar.isDateInToday(prevTimestamp) {
                        try await docRef.setData([
                            "username": username,
                            type.scoreField: score,
                            "timestamp": Timestamp(date: now)
                        ])
                    } else if score > prevScore {
                        try await docRef.setData([
                            "username": username,
                            type.scoreField: score,
                            "timestamp": Timestamp(date: now)
                        ], merge: true)
                    }
                } else if score > prevScore {
                    // For other periods, only update if score is higher
                    try await docRef.setData([
                        "username": username,
                        type.scoreField: score,
                        "timestamp": Timestamp(date: now)
                    ], merge: true)
                }
            } catch {
                throw LeaderboardError.updateFailed(error)
            }
        }
    }
    
    func getLeaderboard(type: LeaderboardType, period: String) async throws -> [LeaderboardEntry] {
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
            
            return snapshot.documents.compactMap { document -> LeaderboardEntry? in
                guard let username = document.data()["username"] as? String,
                      let score = document.data()[type.scoreField] as? Int,
                      let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                return LeaderboardEntry(id: document.documentID, username: username, score: score, timestamp: timestamp)
            }
        } catch {
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
        }
    }
} 