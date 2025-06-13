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
    private var resetTimer: Timer?
    private let estTimeZone = TimeZone(identifier: "America/New_York")!
    private let pageSize = 20
    private let leaderboardLimit = 20
    private var listeners: [String: ListenerRegistration] = [:]
    
    @Published var leaderboardUpdates: [String: [FirebaseManager.LeaderboardEntry]] = [:]
    
    private init() {
        Task {
            await setupPeriodResets()
            setupResetTimer()
        }
    }
    
    deinit {
        // Remove all listeners when service is deallocated
        listeners.values.forEach { $0.remove() }
    }
    
    private func setupResetTimer() {
        // Check for resets every minute
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.checkAndPerformResets()
            }
        }
    }
    
    private func checkAndPerformResets() async {
        let calendar = Calendar.current
        let now = Date()
        let estNow = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
        
        // Daily reset
        if let lastDailyReset = UserDefaults.standard.object(forKey: "lastDailyReset") as? Date {
            let estLastReset = lastDailyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            if !calendar.isDateInToday(estLastReset) {
                print("[Leaderboard] Performing daily reset - Last reset: \(estLastReset)")
                await resetPeriodScores(period: "daily", collection: "classic_leaderboard")
                await resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
                await resetPeriodScores(period: "daily", collection: "classic_timed_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastDailyReset")
            }
        } else {
            print("[Leaderboard] No previous daily reset found, performing initial reset")
            await resetPeriodScores(period: "daily", collection: "classic_leaderboard")
            await resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
            await resetPeriodScores(period: "daily", collection: "classic_timed_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastDailyReset")
        }
        
        // Weekly reset
        if let lastWeeklyReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date {
            let estLastReset = lastWeeklyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            let estComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: estLastReset)
            let currentComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: estNow)
            
            if estComponents.yearForWeekOfYear != currentComponents.yearForWeekOfYear ||
               estComponents.weekOfYear != currentComponents.weekOfYear {
                print("[Leaderboard] Performing weekly reset - Last reset: \(estLastReset)")
                await resetPeriodScores(period: "weekly", collection: "classic_leaderboard")
                await resetPeriodScores(period: "weekly", collection: "achievement_leaderboard")
                await resetPeriodScores(period: "weekly", collection: "classic_timed_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
            }
        } else {
            print("[Leaderboard] No previous weekly reset found, performing initial reset")
            await resetPeriodScores(period: "weekly", collection: "classic_leaderboard")
            await resetPeriodScores(period: "weekly", collection: "achievement_leaderboard")
            await resetPeriodScores(period: "weekly", collection: "classic_timed_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
        }
        
        // Monthly reset
        if let lastMonthlyReset = UserDefaults.standard.object(forKey: "lastMonthlyReset") as? Date {
            let estLastReset = lastMonthlyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            let estComponents = calendar.dateComponents([.year, .month], from: estLastReset)
            let currentComponents = calendar.dateComponents([.year, .month], from: estNow)
            
            if estComponents.year != currentComponents.year ||
               estComponents.month != currentComponents.month {
                print("[Leaderboard] Performing monthly reset - Last reset: \(estLastReset)")
                await resetPeriodScores(period: "monthly", collection: "classic_leaderboard")
                await resetPeriodScores(period: "monthly", collection: "achievement_leaderboard")
                await resetPeriodScores(period: "monthly", collection: "classic_timed_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastMonthlyReset")
            }
        } else {
            print("[Leaderboard] No previous monthly reset found, performing initial reset")
            await resetPeriodScores(period: "monthly", collection: "classic_leaderboard")
            await resetPeriodScores(period: "monthly", collection: "achievement_leaderboard")
            await resetPeriodScores(period: "monthly", collection: "classic_timed_leaderboard")
            UserDefaults.standard.set(now, forKey: "lastMonthlyReset")
        }
    }
    
    private func setupPeriodResets() async {
        let now = Date()
        let estNow = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
        
        print("[Leaderboard] Setting up period resets - Current EST time: \(estNow)")
        
        // Setup periodic reset checks
        setupResetTimer()
        
        // Perform initial reset checks
        await checkAndPerformResets()
    }
    
    private func resetPeriodScores(period: String, collection: String) async {
        print("[Leaderboard] 🔄 Starting score reset for \(collection)/\(period)")
        
        do {
            let snapshot = try await db.collection(collection)
                .document(period)
                .collection("scores")
                .getDocuments()
            
            for document in snapshot.documents {
                if let timestamp = document.data()["timestamp"] as? Timestamp {
                    let estTimestamp = timestamp.dateValue()
                    let shouldReset = shouldResetScore(for: period, timestamp: estTimestamp)
                    
                    if shouldReset {
                        print("[Leaderboard] Resetting \(period) score for user \(document.documentID) - Timestamp: \(estTimestamp)")
                        try await document.reference.delete()
                        
                        // After deletion, check if we need to regenerate the score
                        let documentData = document.data()
                        if let userId = documentData["userId"] as? String,
                           let username = documentData["username"] as? String {
                            // Get the latest score from the alltime leaderboard
                            let alltimeDocRef = db.collection(collection)
                                .document("alltime")
                                .collection("scores")
                                .document(userId)
                            
                            let alltimeDoc = try await alltimeDocRef.getDocument()
                            
                            if let alltimeData = alltimeDoc.data() {
                                // Regenerate the score for the current period
                                var newData: [String: Any] = [
                                    "username": username,
                                    "timestamp": FieldValue.serverTimestamp(),
                                    "userId": userId,
                                    "lastUpdate": FieldValue.serverTimestamp()
                                ]
                                
                                // Handle different score fields based on collection type
                                if collection == "achievement_leaderboard" {
                                    if let points = alltimeData["points"] as? Int {
                                        newData["points"] = points
                                    }
                                } else if collection == "classic_timed_leaderboard" {
                                    if let time = alltimeData["time"] as? Int {
                                        newData["time"] = time
                                    }
                                } else {
                                    if let score = alltimeData["score"] as? Int {
                                        newData["score"] = score
                                    }
                                }
                                
                                try await document.reference.setData(newData)
                                print("[Leaderboard] Regenerated \(period) score for user \(userId)")
                            }
                        }
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
    
    private func setupRealTimeListener(type: LeaderboardType, period: String) {
        let key = "\(type.collectionName)_\(period)"
        
        // Remove existing listener if any
        listeners[key]?.remove()
        
        // Create new listener
        let listener = db.collection(type.collectionName)
            .document(period)
            .collection("scores")
            .order(by: type.scoreField, descending: type.sortOrder == "desc")
            .limit(to: leaderboardLimit)
            .addSnapshotListener { [weak self] snapshot, error in
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
                        } else {
                            return nil
                        }
                    } else {
                        // For score and achievement leaderboards
                        if let value = data[type.scoreField] as? Int {
                            score = value
                        } else {
                            return nil
                        }
                    }
                    
                    return FirebaseManager.LeaderboardEntry(
                        id: document.documentID,
                        username: username,
                        score: score,
                        timestamp: timestamp
                    )
                }
                
                print("[Leaderboard] 📊 Real-time update received: \(entries.count) entries")
                
                // Only update if the data is newer than what we have
                if let currentEntries = self.leaderboardUpdates[key],
                   let currentLatestTimestamp = currentEntries.first?.timestamp,
                   let newLatestTimestamp = entries.first?.timestamp,
                   newLatestTimestamp <= currentLatestTimestamp {
                    print("[Leaderboard] ⏭️ Skipping update - data is not newer")
                    return
                }
                
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
        print("[Leaderboard] 🔄 Starting leaderboard update")
        print("[Leaderboard] 📊 Score: \(score), Level: \(level ?? -1), Type: \(type)")
        
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
        
        print("[Leaderboard] ✅ User authenticated: \(userId)")
        
        // Get username from user profile
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        // Get username in this order:
        // 1. Use passed username if provided
        // 2. Get from Firestore user document
        // 3. Get from Firebase Auth displayName
        // 4. Fall back to "Anonymous" if all else fails
        let username = username ?? 
                      userDoc.data()?["username"] as? String ??
                      Auth.auth().currentUser?.displayName ??
                      "Anonymous"
        
        // Use all periods
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        for period in periods {
            do {
                print("[Leaderboard] 📝 Updating \(period) leaderboard")
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
                
                // For achievement leaderboard, always update
                // For other leaderboards, update if no score exists or new score is higher
                if type == .achievement || currentScore == -1 || score > currentScore {
                    // Create base data dictionary
                    var data: [String: Any] = [
                        "username": username,
                        "timestamp": FieldValue.serverTimestamp(),
                        "userId": userId,
                        "lastUpdate": FieldValue.serverTimestamp()
                    ]
                    
                    // Add score/points based on leaderboard type
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
                    
                    // Write the document with merge
                    try await docRef.setData(data, merge: true)
                    print("[Leaderboard] ✅ Successfully updated \(period) leaderboard")
                    
                    // Invalidate cache for this leaderboard
                    LeaderboardCache.shared.invalidateCache(type: type, period: period)
                    
                    // Force refresh real-time listener
                    setupRealTimeListener(type: type, period: period)
                } else {
                    print("[Leaderboard] ⏭️ Skipping \(period) update - Score not better")
                }
                
            } catch {
                print("[Leaderboard] ❌ Error updating \(period) leaderboard: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("[Leaderboard] ✅ Completed all leaderboard updates")
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
            return (cachedData, cachedData.count)
        }
        
        do {
            // Check if we're in simulator or test flight
            #if targetEnvironment(simulator)
            print("[Leaderboard] 📱 Running in simulator - skipping security checks")
            #else
            if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
                print("[Leaderboard] 📱 Running in TestFlight - skipping security checks")
            } else {
                // In production, try to verify App Check but don't fail if it's not available
                do {
                    try await AppCheck.appCheck().token(forcingRefresh: false)
                    print("[Leaderboard] ✅ App Check verification successful")
                } catch {
                    print("[Leaderboard] ⚠️ App Check verification failed, but continuing: \(error.localizedDescription)")
                }
            }
            #endif
            
            let now = Date()
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            
            var startDate: Date?
            switch period {
            case "daily":
                startDate = startOfDay
            case "weekly":
                // Get start of current week (Sunday)
                let weekday = calendar.component(.weekday, from: now)
                let daysToSubtract = (weekday + 6) % 7 // Convert to Sunday-based week
                startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay)
            case "monthly":
                // Get start of current month
                let components = calendar.dateComponents([.year, .month], from: now)
                startDate = calendar.date(from: components)
            case "alltime":
                startDate = nil
            default:
                throw LeaderboardError.invalidPeriod
            }
            
            if let startDate = startDate {
                print("[Leaderboard] 📅 Filtering from date: \(startDate)")
            }
            
            // Get total users count
            let totalUsersQuery = db.collection(type.collectionName)
                .document(period)
                .collection("scores")
            
            if let startDate = startDate {
                totalUsersQuery.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            }
            
            print("[Leaderboard] 🔍 Executing total users query")
            let totalUsersSnapshot = try await totalUsersQuery.count.getAggregation(source: .server)
            let totalUsers = Int(truncating: totalUsersSnapshot.count)
            print("[Leaderboard] 👥 Total users: \(totalUsers)")
            
            // Get top 20 entries
            var query = db.collection(type.collectionName)
                .document(period)
                .collection("scores")
                .order(by: type.scoreField, descending: type.sortOrder == "desc")
                .limit(to: leaderboardLimit)
            
            if let startDate = startDate {
                query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
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
                    timestamp: timestamp
                )
                print("[Leaderboard] ✅ Successfully parsed entry: \(entry.username) - \(entry.score)")
                return entry
            }
            
            print("[Leaderboard] 📊 Successfully parsed \(entries.count) entries")
            
            // Cache the results
            LeaderboardCache.shared.cacheLeaderboard(entries, type: type, period: period)
            
            return (entries, totalUsers)
        } catch {
            print("[Leaderboard] ❌ Error loading \(period) leaderboard: \(error.localizedDescription)")
            print("[Leaderboard] ❌ Error details: \(error)")
            // Try to get cached data as fallback
            if let cachedData = LeaderboardCache.shared.getCachedLeaderboard(type: type, period: period) {
                print("[Leaderboard] 📦 Using cached data after error")
                return (cachedData, cachedData.count)
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
        await resetPeriodScores(period: period, collection: "classic_leaderboard")
        await resetPeriodScores(period: period, collection: "achievement_leaderboard")
        await resetPeriodScores(period: period, collection: "classic_timed_leaderboard")
        
        // Update last reset time
        UserDefaults.standard.set(Date(), forKey: "last\(period.capitalized)Reset")
        
        // Invalidate cache for all leaderboard types
        LeaderboardCache.shared.invalidateCache(period: period)
    }
    
    private func shouldResetScore(for period: String, timestamp: Date) -> Bool {
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
        
        print("[Leaderboard] Checking reset for \(period) - Start of period: \(startOfPeriod)")
        
        // Convert timestamp to EST for comparison
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
        
        return shouldReset
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
} 