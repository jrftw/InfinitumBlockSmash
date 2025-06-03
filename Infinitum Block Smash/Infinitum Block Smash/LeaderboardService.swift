import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class LeaderboardService {
    static let shared = LeaderboardService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
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
                
                if score > prevScore {
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