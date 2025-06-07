import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import Network
import SwiftUI
import FirebaseDatabase
import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics

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
    case permissionDenied
}

@MainActor
final class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    private var lastError: Error?
    
    // Free tier limits
    private let maxBatchSize = 500 // Firestore free tier limit
    private let maxDocumentSize = 1 * 1024 * 1024 // 1MB limit
    private let maxDailyWrites = 20000 // Free tier limit
    private var dailyWriteCount = 0
    private var lastWriteCountReset = Date()
    private var onlineUsersRef: DatabaseReference?
    private var onlineUsersCount = 0
    private var onlineUsersObserver: DatabaseHandle?
    private var dailyStatsRef: DatabaseReference?
    private var dailyPlayersCount = 0
    private var dailyStatsObserver: DatabaseHandle?
    
    // Cache keys
    private enum CacheKey {
        static let gameProgress = "gameProgress"
        static let leaderboard = "leaderboard"
        static let userData = "userData"
        static let lastSyncTime = "lastSyncTime"
        static let offlineChanges = "offlineChanges"
    }
    
    // Add caching
    private var lastSaveTime: Date?
    private var cachedProgress: GameProgress?
    private let minimumSaveInterval: TimeInterval = 90 // Only save every 90 seconds
    private let userDefaults = UserDefaults.standard
    private let lastSaveTimeKey = "lastFirebaseSaveTime"
    private let lastBackgroundSyncKey = "lastBackgroundSyncTime"
    private var offlineChanges: [String: Any] = [:]
    private let offlineQueue = DispatchQueue(label: "com.infinitum.blocksmash.offlinequeue")
    
    private static var isConfigured = false
    
    private func setupFirebase() {
        // Skip if already configured
        guard !Self.isConfigured else { return }
        
        // Get Firestore instance
        let db = Firestore.firestore()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        #if swift(>=5.5)
        if #available(iOS 15.0, *) {
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        } else {
            // Fallback for older iOS versions
            settings.isPersistenceEnabled = true
            settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        }
        #else
        // Fallback for older Swift versions
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        #endif
        
        // Set Firestore settings
        db.settings = settings
        
        // Enable offline persistence
        db.enableNetwork { error in
            if let error = error {
                print("[Firebase] Error enabling network: \(error.localizedDescription)")
            }
        }
        
        // Load offline changes
        loadOfflineChanges()
        
        // Set up Crashlytics user identifier if user is logged in
        if let userId = Auth.auth().currentUser?.uid {
            Crashlytics.crashlytics().setUserID(userId)
        }
        
        Self.isConfigured = true
    }
    
    private func verifyPermissions() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        let db = Firestore.firestore()
        
        // Try to read user document to verify permissions
        do {
            let _ = try await db.collection("users").document(userId).getDocument()
        } catch {
            print("[Firebase] Permission verification failed: \(error.localizedDescription)")
            throw FirebaseError.permissionDenied
        }
    }
    
    private func setupOnlineUsersTracking() {
        guard Auth.auth().currentUser != nil else { return }
        
        // Get reference to online users
        onlineUsersRef = Database.database().reference().child("online_users")
        
        // Set user as online
        onlineUsersRef?.child(Auth.auth().currentUser!.uid).setValue(true)
        
        // Remove user when they go offline
        onlineUsersRef?.child(Auth.auth().currentUser!.uid).onDisconnectSetValue(false)
        
        // Observe total online users
        onlineUsersRef?.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            self.onlineUsersCount = Int(snapshot.childrenCount)
            NotificationCenter.default.post(name: .onlineUsersCountDidChange, object: nil)
        }
    }
    
    private func setupDailyStatsTracking() {
        guard Auth.auth().currentUser != nil else { return }
        
        // Get reference to daily stats
        dailyStatsRef = Database.database().reference().child("daily_stats")
        
        // Check if we need to reset the counter
        dailyStatsRef?.child("last_reset").observeSingleEvent(of: .value) { [weak self] snapshot in
            if self == nil { return }
            let lastReset = snapshot.value as? TimeInterval ?? 0
            let now = Date().timeIntervalSince1970
            let calendar = Calendar.current
            
            // If it's a new day, reset the counter
            if !calendar.isDateInToday(Date(timeIntervalSince1970: lastReset)) {
                self?.dailyStatsRef?.updateChildValues([
                    "players_today": 0,
                    "last_reset": now
                ])
            }
        }
        
        // Increment daily players count
        dailyStatsRef?.child("players_today").runTransactionBlock { (currentData) -> TransactionResult in
            var count = currentData.value as? Int ?? 0
            count += 1
            currentData.value = count
            return TransactionResult.success(withValue: currentData)
        }
        
        // Observe daily players count
        dailyStatsRef?.child("players_today").observe(.value) { snapshot in
            self.dailyPlayersCount = snapshot.value as? Int ?? 0
            NotificationCenter.default.post(name: .dailyPlayersCountDidChange, object: nil)
        }
    }
    
    func getOnlineUsersCount() -> Int {
        return onlineUsersCount
    }
    
    func getDailyPlayersCount() -> Int {
        return dailyPlayersCount
    }
    
    // MARK: - Enhanced Caching Methods
    
    private func cacheGameProgress(_ progress: GameProgress) {
        // Cache on disk with compression
        try? CacheManager.shared.setDiskCache(progress, forKey: CacheKey.gameProgress, compress: true)
        
        // Store in memory as a dictionary instead of NSObject
        let progressDict = progress.dictionary
        CacheManager.shared.setMemoryCache(progressDict as NSDictionary, forKey: CacheKey.gameProgress)
    }
    
    private func getCachedGameProgress() -> GameProgress? {
        // Try memory cache first
        if let cached: NSDictionary = CacheManager.shared.getMemoryCache(forKey: CacheKey.gameProgress),
           let dict = cached as? [String: Any],
           let progress = GameProgress(dictionary: dict) {
            return progress
        }
        
        // Try disk cache
        if let cached: GameProgress = try? CacheManager.shared.getDiskCache(forKey: CacheKey.gameProgress) {
            // Update memory cache
            let progressDict = cached.dictionary
            CacheManager.shared.setMemoryCache(progressDict as NSDictionary, forKey: CacheKey.gameProgress)
            return cached
        }
        return nil
    }
    
    private func cacheLeaderboard(_ entries: [LeaderboardEntry]) {
        // Cache in memory with cost based on size
        let array = entries as NSArray
        CacheManager.shared.setMemoryCache(array, forKey: CacheKey.leaderboard, cost: entries.count)
        
        // Cache on disk with compression
        try? CacheManager.shared.setDiskCache(entries, forKey: CacheKey.leaderboard, compress: true)
    }
    
    private func getCachedLeaderboard() -> [LeaderboardEntry]? {
        // Try memory cache first
        if let cached: NSArray = CacheManager.shared.getMemoryCache(forKey: CacheKey.leaderboard) {
            return cached as? [LeaderboardEntry]
        }
        
        // Try disk cache
        if let cached: [LeaderboardEntry] = try? CacheManager.shared.getDiskCache(forKey: CacheKey.leaderboard) {
            // Update memory cache
            CacheManager.shared.setMemoryCache(cached as NSArray, forKey: CacheKey.leaderboard, cost: cached.count)
            return cached
        }
        return nil
    }
    
    // MARK: - Offline Support
    
    private func loadOfflineChanges() {
        if let data = userDefaults.data(forKey: CacheKey.offlineChanges),
           let changes = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            offlineQueue.sync {
                self.offlineChanges = changes
            }
        }
    }
    
    private func saveOfflineChanges() {
        offlineQueue.sync {
            if let data = try? JSONSerialization.data(withJSONObject: offlineChanges) {
                userDefaults.set(data, forKey: CacheKey.offlineChanges)
            }
        }
    }
    
    private func addOfflineChange(_ change: [String: Any], forKey key: String) {
        offlineQueue.sync {
            offlineChanges[key] = change
            saveOfflineChanges()
        }
    }
    
    private func clearOfflineChanges() {
        offlineQueue.sync {
            offlineChanges.removeAll()
            saveOfflineChanges()
        }
    }
    
    private func syncOfflineChanges() async throws {
        guard NetworkMonitor.shared.isConnected else { return }
        
        // Get a copy of the changes to process
        let changes = offlineQueue.sync { [offlineChanges] in offlineChanges }
        guard !changes.isEmpty else { return }
        
        for (key, change) in changes {
            do {
                try await db.collection("users").document(key).setData(change as! [String: Any], merge: true)
                _ = offlineQueue.sync {
                    offlineChanges.removeValue(forKey: key)
                }
            } catch {
                print("[Firebase] Error syncing offline change: \(error.localizedDescription)")
            }
        }
        
        saveOfflineChanges()
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
        
        try await retryOperation {
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
            self.cacheGameProgress(progress)
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
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw FirebaseError.networkError
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    func saveGameProgress(_ progress: GameProgress) async throws {
        // Verify permissions first
        try await verifyPermissions()
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Always cache locally first
        self.cacheGameProgress(progress)
        self.cachedProgress = progress
        
        // If offline, just cache and return
        guard NetworkMonitor.shared.isConnected else {
            throw FirebaseError.offlineMode
        }
        
        // Check if we should save based on minimum interval
        let now = Date()
        if let lastSave = self.lastSaveTime,
           now.timeIntervalSince(lastSave) < self.minimumSaveInterval {
            return
        }
        
        // Reset daily write count if it's a new day
        if Calendar.current.isDateInToday(lastWriteCountReset) == false {
            dailyWriteCount = 0
            lastWriteCountReset = now
        }
        
        // Check if we've exceeded daily write limit
        guard dailyWriteCount < maxDailyWrites else {
            throw FirebaseError.retryLimitExceeded
        }
        
        var attempt = 0
        while attempt < self.maxRetries {
            do {
                return try await withTimeout(seconds: 10) {
                    let db = Firestore.firestore()
                    
                    // Create a copy of progressData without the server timestamp for size checking
                    let sizeCheckData: [String: Any] = [
                        "score": progress.score,
                        "level": progress.level,
                        "blocksPlaced": progress.blocksPlaced,
                        "linesCleared": progress.linesCleared,
                        "gamesCompleted": progress.gamesCompleted,
                        "perfectLevels": progress.perfectLevels,
                        "totalPlayTime": progress.totalPlayTime,
                        "highScore": progress.highScore,
                        "highestLevel": progress.highestLevel,
                        "lastUpdated": Date().timeIntervalSince1970
                    ]
                    
                    // Check document size using the regular timestamp version
                    let dataSize = try JSONSerialization.data(withJSONObject: sizeCheckData).count
                    guard dataSize <= self.maxDocumentSize else {
                        throw FirebaseError.invalidData
                    }
                    
                    // Create the actual Firestore data with server timestamp
                    let progressData: [String: Any] = [
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
                    ]
                    
                    // Update Firestore
                    try await db.collection("users").document(userId).setData(progressData, merge: true)
                    
                    // Update write count
                    self.dailyWriteCount += 1
                    
                    // Update local cache
                    self.lastSaveTime = now
                    self.userDefaults.set(now, forKey: self.lastSaveTimeKey)
                }
            } catch {
                self.lastError = error
                
                if !(error is URLError) && !(error is FirebaseError) {
                    throw error
                }
                
                if attempt < self.maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(self.retryDelay * Double(attempt) * 1_000_000_000))
                }
                attempt += 1
            }
        }
        
        throw self.lastError ?? FirebaseError.retryLimitExceeded
    }
    
    func loadGameProgress() async throws -> GameProgress {
        // Try to get from cache first
        if let cached = getCachedGameProgress() {
            return cached
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // If offline, return cached data or throw error
        guard NetworkMonitor.shared.isConnected else {
            if let cached = getCachedGameProgress() {
                return cached
            }
            throw FirebaseError.offlineMode
        }
        
        var attempt = 0
        while attempt < maxRetries {
            do {
                return try await withTimeout(seconds: 10) {
                    let db = Firestore.firestore()
                    let document = try await db.collection("users").document(userId).getDocument()
                    
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
                    
                    // Cache the progress
                    self.cacheGameProgress(progress)
                    self.cachedProgress = progress
                    
                    return progress
                }
            } catch {
                lastError = error
                
                if !(error is URLError) && !(error is FirebaseError) {
                    throw error
                }
                
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
                }
                attempt += 1
            }
        }
        
        // If all retries failed, try to return cached data
        if let cached = getCachedGameProgress() {
            return cached
        }
        
        throw lastError ?? FirebaseError.retryLimitExceeded
    }
    
    func getLeaderboard() async throws -> [LeaderboardEntry] {
        // Try to get from cache first
        if let cached = getCachedLeaderboard() {
            return cached
        }
        
        return try await retryOperation {
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
            self.cacheLeaderboard(leaderboard)
            
            return leaderboard
        }
    }
    
    func cleanup() {
        cancellables.removeAll()
        NetworkMonitor.shared.stopMonitoring()
        MemorySystem.shared.clearAllCaches()
        
        // Cleanup online users tracking
        if let userId = Auth.auth().currentUser?.uid {
            onlineUsersRef?.child(userId).removeValue()
        }
        if let observer = onlineUsersObserver {
            onlineUsersRef?.removeObserver(withHandle: observer)
        }
        
        // Cleanup daily stats tracking
        if let observer = dailyStatsObserver {
            dailyStatsRef?.removeObserver(withHandle: observer)
        }
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
    
    // Initialize FirebaseManager
    init() {
        // Load last save time from UserDefaults
        lastSaveTime = userDefaults.object(forKey: lastSaveTimeKey) as? Date
        
        // Setup Firebase first
        setupFirebase()
        
        // Then setup other features
        setupOnlineUsersTracking()
        setupDailyStatsTracking()
    }
} 
