import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import Network
import SwiftUI

// Network monitoring class
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private(set) var isConnected = false
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// Firebase error types
enum FirebaseError: Error {
    case notAuthenticated
    case invalidData
    case networkError
    case offlineMode
    case retryLimitExceeded
}

@MainActor
final class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    // Cache keys
    private enum CacheKey {
        static let gameProgress = "gameProgress"
        static let leaderboard = "leaderboard"
        static let userData = "userData"
    }
    
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
    
    // MARK: - Enhanced Caching Methods
    
    private func cacheGameProgress(_ progress: GameProgress) {
        // Cache on disk only since GameProgress is a struct
        try? CacheManager.shared.setDiskCache(progress, forKey: CacheKey.gameProgress)
    }
    
    private func getCachedGameProgress() -> GameProgress? {
        // Get from disk cache since GameProgress is a struct
        if let cached: GameProgress = try? CacheManager.shared.getDiskCache(forKey: CacheKey.gameProgress) {
            return cached
        }
        return nil
    }
    
    private func cacheLeaderboard(_ entries: [LeaderboardEntry]) {
        // Cache in memory
        let array = entries as NSArray
        CacheManager.shared.setMemoryCache(array, forKey: CacheKey.leaderboard)
        
        // Cache on disk
        try? CacheManager.shared.setDiskCache(entries, forKey: CacheKey.leaderboard)
    }
    
    private func getCachedLeaderboard() -> [LeaderboardEntry]? {
        // Try memory cache first
        if let cached: NSArray = CacheManager.shared.getMemoryCache(forKey: CacheKey.leaderboard) {
            return cached as? [LeaderboardEntry]
        }
        
        // Try disk cache
        if let cached: [LeaderboardEntry] = try? CacheManager.shared.getDiskCache(forKey: CacheKey.leaderboard) {
            return cached
        }
        return nil
    }
    
    // MARK: - Updated Network Methods
    
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
        
        try await retryOperation { [self] in
            // Fetch latest data from Firestore
            let document = try await self.db.collection("users").document(userId).getDocument()
            guard let data = document.data() else {
                throw FirebaseError.invalidData
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
            
            // Update all caches
            cacheGameProgress(progress)
            self.cachedProgress = progress
            self.userDefaults.set(now, forKey: self.lastBackgroundSyncKey)
            
            // Update UserDefaults with latest high scores
            if let highScore = data["highScore"] as? Int {
                UserDefaults.standard.set(highScore, forKey: "highScore")
            }
            if let highestLevel = data["highestLevel"] as? Int {
                UserDefaults.standard.set(highestLevel, forKey: "highestLevel")
            }
        }
    }
    
    func loadGameProgress() async throws -> GameProgress {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Try to get from cache first
        if let cached = getCachedGameProgress() {
            return cached
        }
        
        return try await retryOperation { [self] in
            let document = try await self.db.collection("users").document(userId).getDocument()
            guard let data = document.data() else {
                throw FirebaseError.invalidData
            }
            
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
            
            // Update all caches
            cacheGameProgress(progress)
            self.cachedProgress = progress
            self.lastSaveTime = Date()
            self.userDefaults.set(self.lastSaveTime, forKey: self.lastSaveTimeKey)
            
            return progress
        }
    }
    
    func getLeaderboard() async throws -> [LeaderboardEntry] {
        // Try to get from cache first
        if let cached = getCachedLeaderboard() {
            return cached
        }
        
        return try await retryOperation { [self] in
            let snapshot = try await self.db.collection("leaderboard")
                .order(by: "score", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let leaderboard = snapshot.documents.compactMap { document -> LeaderboardEntry? in
                guard let username = document.data()["username"] as? String,
                      let score = document.data()["score"] as? Int else {
                    return nil
                }
                return LeaderboardEntry(
                    id: document.documentID,
                    username: username,
                    score: score,
                    timestamp: (document.data()["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            
            // Cache the leaderboard
            cacheLeaderboard(leaderboard)
            
            return leaderboard
        }
    }
    
    func cleanup() {
        cancellables.removeAll()
        NetworkMonitor.shared.stopMonitoring()
        CacheManager.shared.clearAllCaches()
    }
    
    // Helper method for retrying operations
    private func retryOperation<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                // Check network connectivity
                guard NetworkMonitor.shared.isConnected else {
                    throw FirebaseError.offlineMode
                }
                
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry if it's not a network-related error
                if !(error is URLError) && !(error is FirebaseError) {
                    throw error
                }
                
                // Wait before retrying
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? FirebaseError.retryLimitExceeded
    }
    
    // MARK: - Game Progress Methods
    
    func saveGameProgress(_ progress: GameProgress) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Check if we should save based on minimum interval
        let now = Date()
        if let lastSave = lastSaveTime,
           now.timeIntervalSince(lastSave) < minimumSaveInterval {
            return
        }
        
        try await retryOperation { [self] in
            // Update Firestore
            try await self.db.collection("users").document(userId).setData([
                "score": progress.score,
                "level": progress.level,
                "blocksPlaced": progress.blocksPlaced,
                "linesCleared": progress.linesCleared,
                "gamesCompleted": progress.gamesCompleted,
                "perfectLevels": progress.perfectLevels,
                "totalPlayTime": progress.totalPlayTime,
                "highScore": progress.highScore,
                "highestLevel": progress.highestLevel,
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Update local cache
            cacheGameProgress(progress)
            self.cachedProgress = progress
            self.lastSaveTime = now
            self.userDefaults.set(now, forKey: self.lastSaveTimeKey)
        }
    }
} 