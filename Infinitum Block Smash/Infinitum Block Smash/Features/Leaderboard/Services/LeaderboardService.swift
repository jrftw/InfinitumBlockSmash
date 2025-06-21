/*
 * LeaderboardService.swift
 * 
 * LEADERBOARD AND SCORE MANAGEMENT SERVICE
 * 
 * This service manages all leaderboard operations including score submission,
 * leaderboard retrieval, periodic resets, and real-time updates. It handles
 * multiple leaderboard types and time periods with automatic cleanup and
 * synchronization.
 * 
 * KEY RESPONSIBILITIES:
 * - Score submission and validation
 * - Leaderboard data retrieval and caching
 * - Periodic score resets (daily, weekly, monthly)
 * - Real-time leaderboard updates
 * - Score cleanup and maintenance
 * - Multiple leaderboard type management
 * - Time zone handling for resets
 * - Offline score queuing
 * - Anti-cheat measures and validation
 * 
 * MAJOR DEPENDENCIES:
 * - FirebaseManager.swift: Authentication and user data
 * - GameState.swift: Source of game scores and statistics
 * - LeaderboardView.swift: UI display of leaderboard data
 * - LeaderboardCache.swift: Local caching of leaderboard data
 * - LeaderboardModels.swift: Data structures for leaderboard entries
 * - Firebase Firestore: Backend data storage
 * 
 * LEADERBOARD TYPES:
 * - classic_leaderboard: Standard game scores
 * - achievement_leaderboard: Achievement-based points
 * - classic_timed_leaderboard: Time-based game scores
 * 
 * TIME PERIODS:
 * - daily: Resets every day at EST midnight
 * - weekly: Resets every week on Sunday EST
 * - monthly: Resets every month on the 1st EST
 * - alltime: Permanent cumulative scores
 * 
 * DATA STRUCTURES:
 * - LeaderboardEntry: Individual score entries
 * - LeaderboardType: Enumeration of leaderboard types
 * - TimeRange: Time period definitions
 * - Score validation and sanitization
 * 
 * PERIODIC RESETS:
 * - Automatic daily/weekly/monthly resets
 * - EST timezone-based reset timing
 * - Score regeneration from alltime data
 * - Cleanup of expired entries
 * - Reset timestamp tracking
 * 
 * REAL-TIME FEATURES:
 * - Live leaderboard updates
 * - Real-time score submissions
 * - Automatic cache invalidation
 * - Background synchronization
 * - Offline queue processing
 * 
 * PERFORMANCE OPTIMIZATIONS:
 * - Pagination for large datasets
 * - Caching of frequently accessed data
 * - Debounced score submissions
 * - Background cleanup operations
 * - Memory-efficient data structures
 * 
 * SECURITY FEATURES:
 * - Score validation and sanitization
 * - Anti-cheat measures
 * - Rate limiting for submissions
 * - User authentication verification
 * - App version tracking
 * 
 * ERROR HANDLING:
 * - Network error recovery
 * - Retry logic for failed operations
 * - Graceful degradation during outages
 * - Offline queue management
 * - Error logging and reporting
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central coordinator for all leaderboard-related
 * operations, providing a clean interface for score management and
 * leaderboard display.
 * 
 * THREADING MODEL:
 * - @MainActor ensures UI updates on main thread
 * - Background operations for data processing
 * - Async/await for Firebase operations
 * - Timer-based periodic operations
 * 
 * INTEGRATION POINTS:
 * - GameState for score submission
 * - Firebase for data persistence
 * - UI components for display
 * - Analytics for tracking
 * - Background tasks for cleanup
 */

import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth
import FirebaseAppCheck

@MainActor
final class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20
    private let leaderboardLimit = 20
    private var listeners: [String: ListenerRegistration] = [:]
    
    // Add flag to prevent concurrent updates
    private static var isUpdatingLeaderboard = false
    
    @Published var leaderboardUpdates: [String: [FirebaseManager.LeaderboardEntry]] = [:]
    
    private init() {
        Task {
            // Remove automatic reset setup - Firebase function handles this now
            // await setupPeriodResets()
            // setupResetTimer()
            // Run cleanup once during initialization
            await cleanupZeroScores()
        }
    }
    
    deinit {
        // Remove all listeners when service is deallocated
        listeners.values.forEach { $0.remove() }
    }
    
    // Remove the reset timer setup - Firebase function handles resets now
    // private func setupResetTimer() {
    //     // Check for resets every minute
    //     resetTimer?.invalidate()
    //     resetTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    //         Task {
    //             await self?.checkAndPerformResets()
    //         }
    //     }
    // }
    
    // Remove the automatic reset checking - Firebase function handles this now
    // private func checkAndPerformResets() async {
    //     // ... existing reset logic removed
    // }
    
    // Remove the period reset setup - Firebase function handles this now
    // private func setupPeriodResets() async {
    //     // ... existing setup logic removed
    // }
    
    private func setupRealTimeListener(type: LeaderboardType, period: String) {
        let key = "\(type.collectionName)_\(period)"
        
        // Remove existing listener if any
        listeners[key]?.remove()
        
        // Create new listener with where clause to filter out zero scores
        let query = db.collection(type.collectionName)
            .document(period)
            .collection("scores")
            .whereField(type.scoreField, isGreaterThan: 0)  // Only show scores greater than 0
            .order(by: type.scoreField, descending: type.sortOrder == "desc")
            .limit(to: leaderboardLimit)
        
        let listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[Leaderboard] ❌ Real-time listener error: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("[Leaderboard] ❌ No documents in real-time update")
                return
            }
            
            let entries = documents.compactMap { document -> FirebaseManager.LeaderboardEntry? in
                let data = document.data()
                guard let username = data["username"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                // Handle different score fields based on leaderboard type
                let score: Int
                if type == .timed {
                    // For timed leaderboard, convert time to milliseconds for consistent comparison
                    if let time = data["time"] as? TimeInterval {
                        score = Int(time * 1000)
                    } else if let time = data["time"] as? Int {  // Backward compatibility for Int time
                        score = time
                    } else {
                        return nil
                    }
                } else {
                    // For score and achievement leaderboards
                    if let value = data[type.scoreField] as? Int {
                        score = value
                    } else if let value = data[type.scoreField] as? Double {  // Backward compatibility for Double scores
                        score = Int(value)
                    } else {
                        return nil
                    }
                }
                
                // Double check that score is greater than 0
                guard score > 0 else { return nil }
                
                return FirebaseManager.LeaderboardEntry(
                    id: document.documentID,
                    username: username,
                    score: score,
                    timestamp: timestamp,
                    level: data["level"] as? Int,
                    time: data["time"] as? TimeInterval
                )
            }
            
            // Update the leaderboard with new entries
            self.leaderboardUpdates[key] = entries
            
            // Update cache with new data
            LeaderboardCache.shared.cacheLeaderboard(entries, type: type, period: period)
        }
        
        listeners[key] = listener
    }
    
    func startListening(type: LeaderboardType, period: String) {
        setupRealTimeListener(type: type, period: period)
    }
    
    func stopListening(type: LeaderboardType, period: String) {
        let key = "\(type.collectionName)_\(period)"
        listeners[key]?.remove()
        listeners.removeValue(forKey: key)
    }
    
    func updateLeaderboard(score: Int, level: Int? = nil, time: TimeInterval? = nil, type: LeaderboardType = .score, username: String? = nil) async throws {
        // Check if already updating
        guard !Self.isUpdatingLeaderboard else {
            print("[Leaderboard] ⏭️ Skipping update - another update in progress")
            return
        }
        
        // Set flag to prevent concurrent updates
        Self.isUpdatingLeaderboard = true
        defer { Self.isUpdatingLeaderboard = false }
        
        print("[Leaderboard] 🔄 Starting leaderboard update")
        print("[Leaderboard] 📊 Score: \(score), Level: \(level ?? -1), Type: \(type)")
        print("[Leaderboard] 👤 User: \(Auth.auth().currentUser?.uid ?? "unknown")")
        
        // Check if user is guest
        let isGuest = UserDefaults.standard.bool(forKey: "isGuest")
        if isGuest {
            print("[Leaderboard] 👤 User is guest - storing score locally")
            // Store score locally for guest users
            let guestScore = GuestScore(score: score, timestamp: Date(), level: level, time: time)
            if var guestScores = UserDefaults.standard.array(forKey: "guestScores") as? [Data] {
                guestScores.append(try JSONEncoder().encode(guestScore))
                UserDefaults.standard.set(guestScores, forKey: "guestScores")
            } else {
                UserDefaults.standard.set([try JSONEncoder().encode(guestScore)], forKey: "guestScores")
            }
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Leaderboard] ❌ No authenticated user found")
            throw LeaderboardError.notAuthenticated
        }
        
        let username = username ?? UserDefaults.standard.string(forKey: "username") ?? "unknown"
        
        // Validate username length before writing to leaderboard
        guard username.count >= 3 else {
            print("[Leaderboard] ❌ Username too short (\(username.count) chars) - skipping leaderboard update")
            throw LeaderboardError.invalidData
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Define periods and their start dates
        let periods: [(String, Date)] = [
            ("daily", calendar.startOfDay(for: now)),
            ("weekly", calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now),
            ("monthly", calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now),
            ("alltime", Date.distantPast)
        ]

        for (period, _) in periods {
            do {
                print("[Leaderboard] 🔄 Attempting to update \(period) leaderboard for user \(userId)")

                let docRef = db.collection(type.collectionName)
                    .document(period)
                    .collection("scores")
                    .document(userId)

                // Get current score from server
                let doc = try await docRef.getDocument(source: .server)
                let currentScore = doc.data()?[type.scoreField] as? Int ?? -1

                if !doc.exists {
                    print("[Leaderboard] ✅ No previous score exists — writing new \(period) score")
                }

                let shouldUpdate: Bool
                if type == .achievement {
                    shouldUpdate = score > currentScore
                } else if type == .timed, let newTime = time {
                    shouldUpdate = currentScore == -1 || newTime < TimeInterval(currentScore) || score > currentScore
                } else {
                    shouldUpdate = currentScore == -1 || score > currentScore
                }

                if shouldUpdate {
                    var data: [String: Any] = [
                        "username": username,
                        "timestamp": FieldValue.serverTimestamp(),
                        "userId": userId,
                        "lastUpdate": FieldValue.serverTimestamp(),
                        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                        "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    ]

                    if type == .achievement {
                        data["points"] = score
                    } else {
                        data["score"] = score
                    }

                    if let level = level {
                        data["level"] = level
                    }

                    if let time = time {
                        data["time"] = time
                    }

                    print("[Leaderboard] 📝 Writing data to Firestore: \(data)")
                    print("[Leaderboard] 📝 Writing to path: \(type.collectionName)/\(period)/scores/\(userId)")

                    try await docRef.setData(data, merge: true)
                    print("[Leaderboard] ✅ Successfully updated \(period) leaderboard")
                    
                    // Track analytics only when score actually improves
                    #if DEBUG
                    await MainActor.run {
                        AnalyticsManager.shared.trackEvent(.performanceMetric(
                            name: "leaderboard_update",
                            value: Double(score)
                        ))
                    }
                    #else
                    // In release builds, only track significant score improvements
                    let scoreImprovement = score - currentScore
                    if scoreImprovement > 100 { // Only track improvements of 100+ points
                        await MainActor.run {
                            AnalyticsManager.shared.trackEvent(.performanceMetric(
                                name: "leaderboard_significant_improvement",
                                value: Double(scoreImprovement)
                            ))
                        }
                    }
                    #endif

                    if !(try await verifyScoreUpdate(userId: userId, type: type, period: period, expectedScore: score)) {
                        print("[Leaderboard] ⚠️ Score verification failed - scheduling retry")
                        await handleFailedUpdate(userId: userId, type: type, period: period, score: score, level: level, time: time)
                    }
                } else {
                    print("[Leaderboard] ❌ Skipping \(period) update — existing score (\(currentScore)) >= new score (\(score))")
                    
                    // Track skipped updates in debug mode only
                    #if DEBUG
                    await MainActor.run {
                        AnalyticsManager.shared.trackEvent(.performanceMetric(
                            name: "leaderboard_skip",
                            value: Double(currentScore - score)
                        ))
                    }
                    #endif
                }
            } catch {
                print("[Leaderboard] ❌ Error updating \(period) leaderboard: \(error.localizedDescription)")
                print("[Leaderboard] ❌ Error details: \(error)")
                throw LeaderboardError.updateFailed(error)
            }
        }

        print("[Leaderboard] ✅ Successfully submitted all scores")
    }
    
    func getLeaderboard(type: LeaderboardType, period: String) async throws -> (entries: [FirebaseManager.LeaderboardEntry], totalUsers: Int) {
        print("[Leaderboard] 🔄 Starting leaderboard fetch")
        print("[Leaderboard] 📊 Type: \(type), Period: \(period)")
        
        // Check authentication state first
        guard let currentUser = Auth.auth().currentUser else {
            print("[Leaderboard] ❌ User not authenticated")
            throw LeaderboardError.notAuthenticated
        }
        print("[Leaderboard] ✅ User authenticated: \(currentUser.uid)")
        
        // Try to get cached data first
        if let cachedData = LeaderboardCache.shared.getCachedLeaderboard(type: type, period: period) {
            print("[Leaderboard] 📦 Using cached data for \(period) leaderboard")
            print("[Leaderboard] 📦 Cached entries count: \(cachedData.count)")
            
            // For All Time, return total players count; for other periods, return entries count
            let countToReturn: Int
            if period == "alltime" {
                countToReturn = try await FirebaseManager.shared.getTotalPlayersCount()
            } else {
                countToReturn = cachedData.count
            }
            
            return (cachedData, countToReturn)
        }
        
        do {
            // Determine query start date for period filtering
            let queryStartDate: Date?
            let calendar = Calendar.current
            let now = Date()
            
            switch period {
            case "daily":
                queryStartDate = calendar.startOfDay(for: now)
            case "weekly":
                queryStartDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            case "monthly":
                queryStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            case "alltime":
                queryStartDate = nil
            default:
                queryStartDate = nil
            }
            
            if let queryStartDate = queryStartDate {
                print("[Leaderboard] 📅 Filtering from date: \(queryStartDate)")
            }
            
            // Get top 20 entries
            var query = db.collection(type.collectionName)
                .document(period)
                .collection("scores")
                .order(by: type.scoreField, descending: type.sortOrder == "desc")
                .limit(to: leaderboardLimit)
            
            if let queryStartDate = queryStartDate {
                query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: queryStartDate))
            }
            
            print("[Leaderboard] 🔍 Executing entries query")
            let snapshot = try await query.getDocuments()
            print("[Leaderboard] 📊 Retrieved \(snapshot.documents.count) entries")
            
            let entries = snapshot.documents.compactMap { document -> FirebaseManager.LeaderboardEntry? in
                let data = document.data()
                print("[Leaderboard] 📄 Processing document: \(document.documentID)")
                print("[Leaderboard] 📄 Document data: \(data)")
                
                guard let username = data["username"] as? String,
                      let score = data[type.scoreField] as? Int,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    print("[Leaderboard] ❌ Failed to parse entry: \(document.documentID)")
                    return nil
                }
                
                let entry = FirebaseManager.LeaderboardEntry(
                    id: document.documentID,
                    username: username,
                    score: score,
                    timestamp: timestamp,
                    level: data["level"] as? Int,
                    time: data["time"] as? TimeInterval
                )
                print("[Leaderboard] ✅ Successfully parsed entry: \(entry.username) - \(entry.score)")
                return entry
            }
            
            print("[Leaderboard] 📊 Successfully parsed \(entries.count) entries")
            
            // Cache the results
            LeaderboardCache.shared.cacheLeaderboard(entries, type: type, period: period)
            
            // For All Time, return total players count; for other periods, return entries count
            let countToReturn: Int
            if period == "alltime" {
                countToReturn = try await FirebaseManager.shared.getTotalPlayersCount()
                print("[Leaderboard] 👥 Total players count: \(countToReturn)")
            } else {
                countToReturn = entries.count
                print("[Leaderboard] 📊 Entries count: \(countToReturn)")
            }
            
            return (entries, countToReturn)
        } catch {
            print("[Leaderboard] ❌ Error loading \(period) leaderboard: \(error.localizedDescription)")
            print("[Leaderboard] ❌ Error details: \(error)")
            // Try to get cached data as fallback
            if let cachedData = LeaderboardCache.shared.getCachedLeaderboard(type: type, period: period) {
                print("[Leaderboard] 📦 Using cached data after error")
                
                // For All Time, return total players count; for other periods, return entries count
                let countToReturn: Int
                if period == "alltime" {
                    countToReturn = try await FirebaseManager.shared.getTotalPlayersCount()
                } else {
                    countToReturn = cachedData.count
                }
                
                return (cachedData, countToReturn)
            }
            throw LeaderboardError.loadFailed(error)
        }
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
    
    // Add new function to check and update ad-free status
    func updateAdFreeStatus() async throws {
        print("[Leaderboard] 🔄 Starting ad-free status update")
        
        // Get top 3 players from alltime leaderboard
        let snapshot = try await db.collection("classic_leaderboard")
            .document("alltime")
            .collection("scores")
            .order(by: "score", descending: true)
            .limit(to: 3)
            .getDocuments()
        
        print("[Leaderboard] 📊 Found \(snapshot.documents.count) top players")
        
        // Get all user IDs that should have ad-free status
        let adFreeUserIds = snapshot.documents.compactMap { $0.documentID }
        print("[Leaderboard] 👥 Ad-free users: \(adFreeUserIds)")
        
        // Update ad-free status for all users
        let batch = db.batch()
        
        // First, remove ad-free status from all users
        let allUsers = try await db.collection("users").getDocuments()
        for user in allUsers.documents {
            batch.updateData(["isAdFree": false], forDocument: user.reference)
        }
        
        // Then, grant ad-free status to top 3
        for userId in adFreeUserIds {
            let userRef = db.collection("users").document(userId)
            batch.updateData(["isAdFree": true], forDocument: userRef)
            print("[Leaderboard] ✅ Granted ad-free status to user: \(userId)")
        }
        
        try await batch.commit()
        print("[Leaderboard] ✅ Successfully updated ad-free status for top 3 players")
        
        // Notify AdManager to update its state
        Task { @MainActor in
            await AdManager.shared.checkTopThreeStatus()
        }
    }
    
    func clearAllLeaderboards() async throws {
        print("[Leaderboard] Clearing all leaderboards")
        
        let collections = ["classic_leaderboard", "achievement_leaderboard", "classic_timed_leaderboard"]
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        for collection in collections {
            for period in periods {
                do {
                    let scores = try await db.collection(collection)
                        .document(period)
                        .collection("scores")
                        .getDocuments()
                    
                    for document in scores.documents {
                        try await document.reference.delete()
                    }
                    print("[Leaderboard] Cleared \(period) scores for \(collection)")
                } catch {
                    print("[Leaderboard] Error clearing \(period) scores for \(collection): \(error.localizedDescription)")
                }
            }
        }
        
        // Clear local cache
        LeaderboardCache.shared.clearCache()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "pendingLeaderboardScore")
        UserDefaults.standard.removeObject(forKey: "lastDailyReset")
        UserDefaults.standard.removeObject(forKey: "lastWeeklyReset")
        UserDefaults.standard.removeObject(forKey: "lastMonthlyReset")
        
        print("[Leaderboard] All leaderboards cleared successfully")
    }
    
    // Add this function to handle pending scores
    func handlePendingScores() async {
        print("[Leaderboard] Checking for pending scores")
        
        // Handle guest scores first
        if let guestScoresData = UserDefaults.standard.array(forKey: "guestScores") as? [Data] {
            print("[Leaderboard] Found \(guestScoresData.count) guest scores")
            for scoreData in guestScoresData {
                if let guestScore = try? JSONDecoder().decode(GuestScore.self, from: scoreData) {
                    do {
                        try await updateLeaderboard(
                            score: guestScore.score,
                            level: guestScore.level,
                            time: guestScore.time
                        )
                        print("[Leaderboard] Successfully submitted guest score: \(guestScore.score)")
                    } catch {
                        print("[Leaderboard] Failed to submit guest score: \(error.localizedDescription)")
                        continue
                    }
                }
            }
            // Clear guest scores after processing
            UserDefaults.standard.removeObject(forKey: "guestScores")
        }
        
        // Handle pending leaderboard scores
        if let pendingScoreData = UserDefaults.standard.data(forKey: "pendingLeaderboardScore"),
           let pendingScore = try? JSONDecoder().decode(PendingScore.self, from: pendingScoreData) {
            print("[Leaderboard] Found pending score: \(pendingScore.score)")
            do {
                try await updateLeaderboard(
                    score: pendingScore.score,
                    level: pendingScore.level,
                    time: pendingScore.time
                )
                print("[Leaderboard] Successfully submitted pending score")
                UserDefaults.standard.removeObject(forKey: "pendingLeaderboardScore")
            } catch {
                print("[Leaderboard] Failed to submit pending score: \(error.localizedDescription)")
            }
        }
    }
    
    // Add this function to validate and fix leaderboard data
    func validateAndFixLeaderboardData() async throws {
        print("[Leaderboard] Validating leaderboard data")
        
        let collections = ["classic_leaderboard", "achievement_leaderboard", "classic_timed_leaderboard"]
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        for collection in collections {
            for period in periods {
                do {
                    let scores = try await db.collection(collection)
                        .document(period)
                        .collection("scores")
                        .getDocuments()
                    
                    for document in scores.documents {
                        let data = document.data()
                        
                        // Check for required fields
                        guard let _ = data["username"] as? String,
                              let score = data["score"] as? Int,
                              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                            print("[Leaderboard] Found invalid entry in \(collection)/\(period) - deleting")
                            try await document.reference.delete()
                            continue
                        }
                        
                        // Validate score is non-negative
                        if score < 0 {
                            print("[Leaderboard] Found negative score in \(collection)/\(period) - deleting")
                            try await document.reference.delete()
                            continue
                        }
                        
                        // Validate timestamp is not in the future
                        if timestamp > Date() {
                            print("[Leaderboard] Found future timestamp in \(collection)/\(period) - fixing")
                            try await document.reference.updateData([
                                "timestamp": Timestamp(date: Date())
                            ])
                        }
                    }
                } catch {
                    print("[Leaderboard] Error validating \(period) scores for \(collection): \(error.localizedDescription)")
                }
            }
        }
        
        print("[Leaderboard] Leaderboard data validation complete")
    }
    
    // For testing purposes
    func forceResetPeriod(period: String) async {
        print("[Leaderboard] 🔄 Force resetting \(period) leaderboards")
        // Note: resetPeriodScores has been moved to Firebase functions
        // This function is now only for testing and cache invalidation
        
        // Update last reset time
        UserDefaults.standard.set(Date(), forKey: "last\(period.capitalized)Reset")
        
        // Invalidate cache for all leaderboard types
        LeaderboardCache.shared.invalidateCache(period: period)
    }
    
    // Add a function to clean up zero scores for backward compatibility
    private func cleanupZeroScores() async {
        print("[Leaderboard] Starting cleanup of zero scores for backward compatibility")
        
        let collections = ["classic_leaderboard", "achievement_leaderboard", "classic_timed_leaderboard"]
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        for collection in collections {
            for period in periods {
                do {
                    let snapshot = try await db.collection(collection)
                        .document(period)
                        .collection("scores")
                        .getDocuments()
                    
                    for document in snapshot.documents {
                        let data = document.data()
                        let scoreField = collection == "achievement_leaderboard" ? "points" :
                                       collection == "classic_timed_leaderboard" ? "time" : "score"
                        
                        if let score = data[scoreField] as? Int, score == 0 {
                            print("[Leaderboard] Removing zero score entry for user \(document.documentID) in \(collection)/\(period)")
                            try await document.reference.delete()
                        }
                    }
                } catch {
                    print("[Leaderboard] Error cleaning up zero scores for \(collection)/\(period): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Add this function to verify score updates
    private func verifyScoreUpdate(userId: String, type: LeaderboardType, period: String, expectedScore: Int) async throws -> Bool {
        print("[Leaderboard] 🔍 Verifying score update for user \(userId)")
        
        let docRef = db.collection(type.collectionName)
            .document(period)
            .collection("scores")
            .document(userId)
        
        let doc = try await docRef.getDocument(source: .server)
        guard let data = doc.data(),
              let actualScore = data[type.scoreField] as? Int else {
            print("[Leaderboard] ❌ Verification failed - No score found")
            return false
        }
        
        let isCorrect = actualScore == expectedScore
        print("[Leaderboard] \(isCorrect ? "✅" : "❌") Score verification: Expected \(expectedScore), Got \(actualScore)")
        
        return isCorrect
    }

    // Update the PendingScore struct to include all fields
    private struct PendingScore: Codable {
        let score: Int
        let timestamp: Date
        let level: Int?
        let time: TimeInterval?
        
        init(score: Int, timestamp: Date, level: Int? = nil, time: TimeInterval? = nil) {
            self.score = score
            self.timestamp = timestamp
            self.level = level
            self.time = time
        }
    }

    // Update the handleFailedUpdate function to include all parameters
    private func handleFailedUpdate(userId: String, type: LeaderboardType, period: String, score: Int, level: Int? = nil, time: TimeInterval? = nil) async {
        print("[Leaderboard] ⚠️ Handling failed update for user \(userId)")
        
        // Store the failed update in UserDefaults for retry
        let pendingScore = PendingScore(score: score, timestamp: Date(), level: level, time: time)
        if let encoded = try? JSONEncoder().encode(pendingScore) {
            UserDefaults.standard.set(encoded, forKey: "pendingLeaderboardScore")
            print("[Leaderboard] ✅ Stored pending score for retry")
        }
        
        // Schedule a retry
        Task {
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                try await updateLeaderboard(score: score, level: level, time: time, type: type)
                print("[Leaderboard] ✅ Retry successful")
            } catch {
                print("[Leaderboard] ❌ Retry failed: \(error.localizedDescription)")
            }
        }
    }
}

enum LeaderboardError: LocalizedError {
    case invalidUserData
    case updateFailed(Error)
    case loadFailed(Error)
    case invalidPeriod
    case notAuthenticated
    case rateLimited
    case invalidData
    
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
        case .rateLimited:
            return "Rate limited"
        case .invalidData:
            return "Invalid data"
        }
    }
}

// Add these structs at the top of the file
private struct GuestScore: Codable {
    let score: Int
    let timestamp: Date
    let level: Int?
    let time: TimeInterval?
}

private struct PendingScore: Codable {
    let score: Int
    let timestamp: Date
    let level: Int?
    let time: TimeInterval?
    
    init(score: Int, timestamp: Date, level: Int? = nil, time: TimeInterval? = nil) {
        self.score = score
        self.timestamp = timestamp
        self.level = level
        self.time = time
    }
} 
