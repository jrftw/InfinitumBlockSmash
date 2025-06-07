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
    
    // Add caching
    private var lastSaveTime: Date?
    private var cachedProgress: GameProgress?
    private let minimumSaveInterval: TimeInterval = 30 // Only save every 30 seconds
    private let userDefaults = UserDefaults.standard
    private let lastSaveTimeKey = "lastFirebaseSaveTime"
    private let lastBackgroundSyncKey = "lastBackgroundSyncTime"
    
    private init() {
        // Load last save time from UserDefaults
        lastSaveTime = userDefaults.object(forKey: lastSaveTimeKey) as? Date
    }
    
    // Add background sync method
    func syncDataInBackground() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Check if we should sync based on last sync time
        let now = Date()
        if let lastSync = userDefaults.object(forKey: lastBackgroundSyncKey) as? Date,
           now.timeIntervalSince(lastSync) < 3600 { // Minimum 1 hour between syncs
            return
        }
        
        do {
            // Fetch latest data from Firestore
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else {
                return
            }
            
            // Update local cache with latest data
            let progress = GameProgress(
                score: data["score"] as? Int ?? 0,
                level: data["level"] as? Int ?? 1,
                blocksPlaced: data["blocksPlaced"] as? Int ?? 0,
                linesCleared: data["linesCleared"] as? Int ?? 0,
                gamesCompleted: data["gamesCompleted"] as? Int ?? 0,
                perfectLevels: data["perfectLevels"] as? Int ?? 0,
                totalPlayTime: data["totalPlayTime"] as? TimeInterval ?? 0,
                highScore: data["highScore"] as? Int ?? data["score"] as? Int ?? 0,
                highestLevel: data["highestLevel"] as? Int ?? data["level"] as? Int ?? 1
            )
            
            // Update cache and sync time
            cachedProgress = progress
            userDefaults.set(now, forKey: lastBackgroundSyncKey)
            
            // Update UserDefaults with latest high scores
            if let highScore = data["highScore"] as? Int {
                UserDefaults.standard.set(highScore, forKey: "highScore")
            }
            if let highestLevel = data["highestLevel"] as? Int {
                UserDefaults.standard.set(highestLevel, forKey: "highestLevel")
            }
            
        } catch {
            throw FirebaseError.loadFailed(error)
        }
    }
    
    func saveGameProgress(gameState: GameState) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Check if we should save based on time interval
        let now = Date()
        if let lastSave = lastSaveTime,
           now.timeIntervalSince(lastSave) < minimumSaveInterval {
            return // Skip save if not enough time has passed
        }
        
        do {
            // First, get existing data to ensure we don't overwrite with lower values
            let existingDoc = try await db.collection("users").document(userId).getDocument()
            let existingData = existingDoc.data() ?? [:]
            
            // Prepare new data with fallbacks to existing values
            let newData: [String: Any] = [
                "score": gameState.score,
                "level": gameState.level,
                "blocksPlaced": max(gameState.blocksPlaced, existingData["blocksPlaced"] as? Int ?? 0),
                "linesCleared": max(gameState.linesCleared, existingData["linesCleared"] as? Int ?? 0),
                "gamesCompleted": max(gameState.gamesCompleted, existingData["gamesCompleted"] as? Int ?? 0),
                "perfectLevels": max(gameState.perfectLevels, existingData["perfectLevels"] as? Int ?? 0),
                "totalPlayTime": max(gameState.totalPlayTime, existingData["totalPlayTime"] as? TimeInterval ?? 0),
                "highScore": max(
                    gameState.score > UserDefaults.standard.integer(forKey: "highScore") ? gameState.score : UserDefaults.standard.integer(forKey: "highScore"),
                    existingData["highScore"] as? Int ?? 0
                ),
                "highestLevel": max(
                    gameState.level > UserDefaults.standard.integer(forKey: "highestLevel") ? gameState.level : UserDefaults.standard.integer(forKey: "highestLevel"),
                    existingData["highestLevel"] as? Int ?? 1
                ),
                "lastUpdated": FieldValue.serverTimestamp()
            ]
            
            // Only save if data has changed
            if let cached = cachedProgress,
               cached.score == gameState.score,
               cached.level == gameState.level,
               cached.blocksPlaced == gameState.blocksPlaced,
               cached.linesCleared == gameState.linesCleared,
               cached.gamesCompleted == gameState.gamesCompleted,
               cached.perfectLevels == gameState.perfectLevels,
               cached.totalPlayTime == gameState.totalPlayTime {
                return // Skip save if no changes
            }
            
            try await db.collection("users").document(userId).setData(newData, merge: true)
            
            // Update cache and last save time
            cachedProgress = GameProgress(
                score: gameState.score,
                level: gameState.level,
                blocksPlaced: gameState.blocksPlaced,
                linesCleared: gameState.linesCleared,
                gamesCompleted: gameState.gamesCompleted,
                perfectLevels: gameState.perfectLevels,
                totalPlayTime: gameState.totalPlayTime,
                highScore: newData["highScore"] as? Int ?? 0,
                highestLevel: newData["highestLevel"] as? Int ?? 1
            )
            lastSaveTime = now
            userDefaults.set(now, forKey: lastSaveTimeKey)
            
        } catch {
            throw FirebaseError.saveFailed(error)
        }
    }
    
    func loadGameProgress() async throws -> GameProgress {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Return cached data if available and recent
        if let cached = cachedProgress,
           let lastSave = lastSaveTime,
           Date().timeIntervalSince(lastSave) < minimumSaveInterval {
            return cached
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else {
                return GameProgress()
            }
            
            // Handle backward compatibility by providing default values for missing fields
            let progress = GameProgress(
                score: data["score"] as? Int ?? 0,
                level: data["level"] as? Int ?? 1,
                blocksPlaced: data["blocksPlaced"] as? Int ?? 0,
                linesCleared: data["linesCleared"] as? Int ?? 0,
                gamesCompleted: data["gamesCompleted"] as? Int ?? 0,
                perfectLevels: data["perfectLevels"] as? Int ?? 0,
                totalPlayTime: data["totalPlayTime"] as? TimeInterval ?? 0,
                highScore: data["highScore"] as? Int ?? data["score"] as? Int ?? 0,
                highestLevel: data["highestLevel"] as? Int ?? data["level"] as? Int ?? 1
            )
            
            // Update cache
            cachedProgress = progress
            lastSaveTime = Date()
            userDefaults.set(lastSaveTime, forKey: lastSaveTimeKey)
            
            return progress
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

// Structure to hold all game progress data
struct GameProgress {
    let score: Int
    let level: Int
    let blocksPlaced: Int
    let linesCleared: Int
    let gamesCompleted: Int
    let perfectLevels: Int
    let totalPlayTime: TimeInterval
    let highScore: Int
    let highestLevel: Int
    
    init(
        score: Int = 0,
        level: Int = 1,
        blocksPlaced: Int = 0,
        linesCleared: Int = 0,
        gamesCompleted: Int = 0,
        perfectLevels: Int = 0,
        totalPlayTime: TimeInterval = 0,
        highScore: Int = 0,
        highestLevel: Int = 1
    ) {
        self.score = score
        self.level = level
        self.blocksPlaced = blocksPlaced
        self.linesCleared = linesCleared
        self.gamesCompleted = gamesCompleted
        self.perfectLevels = perfectLevels
        self.totalPlayTime = totalPlayTime
        self.highScore = highScore
        self.highestLevel = highestLevel
    }
} 