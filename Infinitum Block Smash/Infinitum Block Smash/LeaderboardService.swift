import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

@MainActor
final class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var resetTimer: Timer?
    private let estTimeZone = TimeZone(identifier: "America/New_York")!
    private let pageSize = 20
    private let leaderboardLimit = 20
    
    private init() {
        Task {
            await setupPeriodResets()
            setupResetTimer()
        }
    }
    
    private func setupResetTimer() {
        // Calculate time until next reset in EST
        let calendar = Calendar.current
        let now = Date()
        let estNow = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
        
        // Get next midnight in EST
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let nextMidnight = calendar.nextDate(after: estNow,
                                                 matching: components,
                                                 matchingPolicy: .nextTime) else {
            return
        }
        
        // Convert back to local time for timer
        let localNextMidnight = nextMidnight.addingTimeInterval(-TimeInterval(estTimeZone.secondsFromGMT()))
        let timeInterval = localNextMidnight.timeIntervalSince(now)
        
        // Create timer that fires at next midnight
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleMidnightReset()
                // Schedule next timer
                self?.setupResetTimer()
            }
        }
        
        print("[Leaderboard] Next reset scheduled in \(timeInterval) seconds")
    }
    
    private func handleMidnightReset() async {
        print("[Leaderboard] Performing midnight EST reset")
        let now = Date()
        let estNow = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
        print("[Leaderboard] Current EST time: \(estNow)")
        
        // Check if we need to perform any resets
        let calendar = Calendar.current
        
        // Check daily reset
        if let lastDailyReset = UserDefaults.standard.object(forKey: "lastDailyReset") as? Date {
            let estLastReset = lastDailyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
            if !calendar.isDateInToday(estLastReset) {
                print("[Leaderboard] Performing daily reset")
                await resetPeriodScores(period: "daily", collection: "classic_leaderboard")
                await resetPeriodScores(period: "daily", collection: "achievement_leaderboard")
                await resetPeriodScores(period: "daily", collection: "classic_timed_leaderboard")
                UserDefaults.standard.set(now, forKey: "lastDailyReset")
            }
        }
        
        // Check weekly reset (Sunday)
        if calendar.component(.weekday, from: estNow) == 1 { // Sunday
            if let lastWeeklyReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date {
                let estLastReset = lastWeeklyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
                if !calendar.isDate(estNow, equalTo: estLastReset, toGranularity: .weekOfYear) {
                    print("[Leaderboard] Performing weekly reset")
                    await resetPeriodScores(period: "weekly", collection: "classic_leaderboard")
                    await resetPeriodScores(period: "weekly", collection: "achievement_leaderboard")
                    await resetPeriodScores(period: "weekly", collection: "classic_timed_leaderboard")
                    UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
                }
            }
        }
        
        // Check monthly reset
        if calendar.component(.day, from: estNow) == 1 { // First day of month
            if let lastMonthlyReset = UserDefaults.standard.object(forKey: "lastMonthlyReset") as? Date {
                let estLastReset = lastMonthlyReset.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
                if !calendar.isDate(estNow, equalTo: estLastReset, toGranularity: .month) {
                    print("[Leaderboard] Performing monthly reset")
                    await resetPeriodScores(period: "monthly", collection: "classic_leaderboard")
                    await resetPeriodScores(period: "monthly", collection: "achievement_leaderboard")
                    await resetPeriodScores(period: "monthly", collection: "classic_timed_leaderboard")
                    UserDefaults.standard.set(now, forKey: "lastMonthlyReset")
                }
            }
        }
    }
    
    private func setupPeriodResets() async {
        let calendar = Calendar.current
        let now = Date()
        let estNow = now.addingTimeInterval(TimeInterval(estTimeZone.secondsFromGMT()))
        
        print("[Leaderboard] Setting up period resets - Current EST time: \(estNow)")
        
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
    
    private func resetPeriodScores(period: String, collection: String) async {
        do {
            let scores = try await db.collection(collection)
                .document(period)
                .collection("scores")
                .getDocuments()
            
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
            
            print("[Leaderboard] Checking \(period) resets for \(collection) - Start of period: \(startOfPeriod)")
            
            for document in scores.documents {
                // Check if the entry needs to be reset based on EST time
                if let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() {
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
                    
                    if shouldReset {
                        print("[Leaderboard] Resetting \(period) score for user \(document.documentID) - Timestamp: \(estTimestamp)")
                        try await document.reference.delete()
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
        
        print("[Leaderboard] 👤 Using username: \(username)")
        
        // Validate score
        guard score >= 0 else {
            print("[Leaderboard] ❌ Invalid score: \(score)")
            throw LeaderboardError.invalidData
        }
        
        // Use all periods
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        for period in periods {
            do {
                print("[Leaderboard] 📝 Updating \(period) leaderboard")
                let docRef = db.collection(type.collectionName)
                    .document(period)
                    .collection("scores")
                    .document(userId)
                
                // Get current score if it exists
                let currentDoc = try await docRef.getDocument()
                let currentScore = currentDoc.data()?[type.scoreField] as? Int ?? 0
                
                // For achievement leaderboard, always update
                // For other leaderboards, only update if score is better
                if type == .achievement || score > currentScore {
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
                    
                    // Validate data against security rules
                    print("[Leaderboard] 🔍 Validating data against security rules:")
                    print("[Leaderboard] - Score valid: \(score >= 0)")
                    print("[Leaderboard] - Username valid: \(username.count >= 3 && username.count <= 20)")
                    print("[Leaderboard] - UserId matches: \(userId == Auth.auth().currentUser?.uid)")
                    print("[Leaderboard] - Period valid: \(periods.contains(period))")
                    print("[Leaderboard] - Data fields: \(data.keys.joined(separator: ", "))")
                    
                    print("[Leaderboard] 📝 Writing data to Firestore: \(data)")
                    print("[Leaderboard] 📝 Writing to path: \(type.collectionName)/\(period)/scores/\(userId)")
                    
                    // Try to write the document
                    do {
                        try await docRef.setData(data)
                        print("[Leaderboard] ✅ Successfully updated \(period) leaderboard")
                    } catch let error as NSError {
                        print("[Leaderboard] ❌ Firestore error: \(error.localizedDescription)")
                        print("[Leaderboard] ❌ Error domain: \(error.domain)")
                        print("[Leaderboard] ❌ Error code: \(error.code)")
                        print("[Leaderboard] ❌ Error user info: \(error.userInfo)")
                        throw error
                    }
                } else {
                    print("[Leaderboard] ⏭️ Skipping \(period) update - Score not better")
                }
                
            } catch {
                print("[Leaderboard] ❌ Error updating \(period) leaderboard: \(error.localizedDescription)")
                print("[Leaderboard] ❌ Error details: \(error)")
                // Store score for later submission
                let pendingScore = PendingScore(score: score, timestamp: Date(), level: level, time: time)
                UserDefaults.standard.set(try? JSONEncoder().encode(pendingScore), forKey: "pendingLeaderboardScore")
            }
        }
        
        // Update ad-free status for top 3 players
        if type == .score {
            print("[Leaderboard] 🔄 Updating ad-free status for top 3 players")
            try await updateAdFreeStatus()
        }
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