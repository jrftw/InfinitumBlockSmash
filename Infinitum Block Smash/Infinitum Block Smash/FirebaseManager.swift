import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case saveFailed(Error)
    case loadFailed(Error)
    case leaderboardUpdateFailed(Error)
    case networkError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load data: \(error.localizedDescription)"
        case .leaderboardUpdateFailed(let error):
            return "Failed to update leaderboard: \(error.localizedDescription)"
        case .networkError:
            return "Network connection error. Please check your internet connection"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func saveGameProgress(score: Int, level: Int) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        do {
            try await db.collection("users").document(userId).setData([
                "score": score,
                "level": level,
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            throw FirebaseError.saveFailed(error)
        }
    }
    
    func loadGameProgress() async throws -> (score: Int, level: Int) {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else {
                return (0, 1)
            }
            
            let score = data["score"] as? Int ?? 0
            let level = data["level"] as? Int ?? 1
            
            return (score, level)
        } catch {
            throw FirebaseError.loadFailed(error)
        }
    }
    
    func updateLeaderboard(score: Int, level: Int, username: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        do {
            try await db.collection("leaderboard").document(userId).setData([
                "score": score,
                "level": level,
                "username": username,
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            throw FirebaseError.leaderboardUpdateFailed(error)
        }
    }
    
    func getLeaderboard() async throws -> [(username: String, score: Int, level: Int)] {
        do {
            let snapshot = try await db.collection("leaderboard")
                .order(by: "score", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            return snapshot.documents.compactMap { document -> (String, Int, Int)? in
                guard let username = document.data()["username"] as? String,
                      let score = document.data()["score"] as? Int,
                      let level = document.data()["level"] as? Int else {
                    return nil
                }
                return (username, score, level)
            }
        } catch {
            throw FirebaseError.loadFailed(error)
        }
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
} 