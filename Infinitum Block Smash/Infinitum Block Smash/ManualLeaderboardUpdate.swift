// This is not a implementation for the app this is a manually toggle for me to use don't update this as the core leaderboard logic update


import Foundation
import FirebaseFirestore
import FirebaseAuth

class ManualLeaderboardUpdate {
    static let shared = ManualLeaderboardUpdate()
    private let db = Firestore.firestore()
    
    // Add a flag to control leaderboard updates
    private var isLeaderboardUpdateEnabled = false
    
    private init() {}
    
    // Function to toggle leaderboard updates
    func setLeaderboardUpdateEnabled(_ enabled: Bool) {
        isLeaderboardUpdateEnabled = enabled
        print("[ManualUpdate] 🔄 Leaderboard updates \(enabled ? "enabled" : "disabled")")
    }
    
    // Function to check if leaderboard updates are enabled
    func isLeaderboardUpdatesEnabled() -> Bool {
        return isLeaderboardUpdateEnabled
    }
    
    // Add validation function
    private func validateUserData(userId: String, username: String) throws {
        guard !userId.isEmpty else {
            throw LeaderboardError.invalidData
        }
        
        guard username.count >= 3 && username.count <= 20 else {
            throw LeaderboardError.invalidData
        }
    }
    
    // Add function to get current user data
    private func getCurrentUserData() throws -> (userId: String, username: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[ManualUpdate] ❌ No authenticated user found")
            throw LeaderboardError.notAuthenticated
        }
        
        let username = UserDefaults.standard.string(forKey: "username") ?? "Anonymous"
        try validateUserData(userId: userId, username: username)
        
        return (userId, username)
    }
    
    // Updated function to handle all leaderboard types with force update for daily
    func updateAllLeaderboardsWithData(finalScore: Int, finalLevel: Int, totalTime: Double, shouldWrite: Bool = true) async throws {
        print("[ManualUpdate] 🏆 Handling all leaderboard updates")
        
        guard shouldWrite else {
            print("[ManualUpdate] ⏭️ Skipping write - shouldWrite is false")
            return
        }
        
        let uid = Auth.auth().currentUser?.uid ?? "unknown"
        let username = UserDefaults.standard.string(forKey: "username") ?? "jrftw"
        
        // Define all leaderboard types and their data
        let leaderboards: [(collection: String, data: [String: Any])] = [
            ("classic_leaderboard", [
                "userId": uid,
                "username": username,
                "score": finalScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "time": totalTime
            ]),
            ("achievement_leaderboard", [
                "userId": uid,
                "username": username,
                "points": finalScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "time": totalTime
            ]),
            ("classic_timed_leaderboard", [
                "userId": uid,
                "username": username,
                "time": totalTime,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "score": finalScore
            ])
        ]
        
        // Define all periods
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        // Update all leaderboard types
        for (collection, data) in leaderboards {
            for period in periods {
                do {
                    let docRef = db.collection(collection)
                        .document(period)
                        .collection("scores")
                        .document(uid)
                    
                    // Check if document exists
                    let currentDoc = try await docRef.getDocument()
                    
                    if !currentDoc.exists {
                        // Create new leaderboard entry
                        print("[ManualUpdate] 📝 Creating new \(period) entry for \(collection)")
                        try await docRef.setData(data)
                        print("[ManualUpdate] ✅ Created new \(period) entry for \(collection)")
                    } else {
                        // Update existing entry if score is better
                        let currentData = currentDoc.data()
                        let currentScore = currentData?["score"] as? Int ?? 0
                        let currentTime = currentData?["time"] as? Double ?? 0
                        
                        let shouldUpdate = collection == "achievement_leaderboard" ? true :
                                         collection == "classic_timed_leaderboard" ? totalTime < currentTime :
                                         finalScore > currentScore
                        
                        if shouldUpdate {
                            print("[ManualUpdate] 📝 Updating existing \(period) entry for \(collection)")
                            try await docRef.setData(data, merge: true)
                            print("[ManualUpdate] ✅ Updated existing \(period) entry for \(collection)")
                        } else {
                            print("[ManualUpdate] ⏭️ Skipping update - current score is better")
                        }
                    }
                    
                    // Invalidate cache for this leaderboard
                    LeaderboardCache.shared.invalidateCache(period: period)
                    
                } catch {
                    print("[ManualUpdate] ❌ Error updating \(collection)/\(period): \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        print("[ManualUpdate] ✅ Completed all leaderboard updates")
    }
    
    // New function to handle game end updates
    func handleGameEnd(score: Int, level: Int, time: Double) async throws {
        print("[ManualUpdate] 🎮 Handling game end update")
        
        // Get and validate user data
        let (userId, username) = try getCurrentUserData()
        
        // Create data for each leaderboard type
        let leaderboardData: [(collection: String, data: [String: Any])] = [
            ("classic_leaderboard", [
                "userId": userId,
                "username": username,
                "score": score,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": level
            ]),
            ("achievement_leaderboard", [
                "userId": userId,
                "username": username,
                "points": score,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": level
            ]),
            ("classic_timed_leaderboard", [
                "userId": userId,
                "username": username,
                "time": time,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": level
            ])
        ]
        
        // Update daily scores for all leaderboard types
        for (collection, data) in leaderboardData {
            do {
                let docRef = db.collection(collection)
                    .document("daily")
                    .collection("scores")
                    .document(userId)
                
                print("[ManualUpdate] 📝 Updating daily score for \(collection)")
                print("[ManualUpdate] 📊 Data: \(data)")
                
                try await docRef.setData(data, merge: true)
                print("[ManualUpdate] ✅ Successfully updated daily score for \(collection)")
                
                // Invalidate cache for daily leaderboard
                LeaderboardCache.shared.invalidateCache(period: "daily")
                
            } catch {
                print("[ManualUpdate] ❌ Error updating daily score for \(collection): \(error.localizedDescription)")
                throw error
            }
        }
        
        print("[ManualUpdate] ✅ Completed game end updates")
    }
    
    func updateAllLeaderboards(shouldWrite: Bool = false) async throws {
        // Get and validate user data
        let (userId, username) = try getCurrentUserData()
        
        // Get current game state with validation
        let currentScore = max(0, UserDefaults.standard.integer(forKey: "highScore"))
        let currentLevel = max(1, UserDefaults.standard.integer(forKey: "highestLevel"))
        let currentTime = max(0, UserDefaults.standard.double(forKey: "bestTime"))
        
        // Define all leaderboard types and their data
        let leaderboards: [(collection: String, data: [String: Any])] = [
            // Classic Leaderboard
            ("classic_leaderboard", [
                "userId": userId,
                "username": username,
                "score": currentScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": currentLevel
            ]),
            
            // Achievement Leaderboard
            ("achievement_leaderboard", [
                "userId": userId,
                "username": username,
                "points": currentScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": currentLevel
            ]),
            
            // Classic Timed Leaderboard
            ("classic_timed_leaderboard", [
                "userId": userId,
                "username": username,
                "time": currentTime,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": currentLevel
            ])
        ]
        
        // Define all periods
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        if shouldWrite {
            print("[ManualUpdate] 📝 Starting manual update for all leaderboards")
            
            for (collection, data) in leaderboards {
                for period in periods {
                    do {
                        let docRef = db.collection(collection)
                            .document(period)
                            .collection("scores")
                            .document(userId)
                        
                        // Check if document exists and get current data
                        let currentDoc = try await docRef.getDocument()
                        let currentData = currentDoc.data()
                        
                        // Only update if new data is better or no data exists
                        let shouldUpdate = shouldUpdateScore(
                            collection: collection,
                            currentData: currentData,
                            newData: data
                        )
                        
                        if shouldUpdate {
                            print("[ManualUpdate] 📝 Updating \(collection)/\(period) for user \(userId)")
                            print("[ManualUpdate] 📊 Data: \(data)")
                            
                            try await docRef.setData(data, merge: true)
                            print("[ManualUpdate] ✅ Successfully updated \(collection)/\(period)")
                            
                            // Invalidate cache for this leaderboard
                            LeaderboardCache.shared.invalidateCache(period: period)
                        } else {
                            print("[ManualUpdate] ⏭️ Skipping update - current score is better")
                        }
                        
                    } catch {
                        print("[ManualUpdate] ❌ Error updating \(collection)/\(period): \(error.localizedDescription)")
                        throw error
                    }
                }
            }
            
            print("[ManualUpdate] ✅ Completed manual update for all leaderboards")
        } else {
            print("[ManualUpdate] ⏭️ Skipping write - shouldWrite is false")
            print("[ManualUpdate] 📊 Would have written the following data:")
            for (collection, data) in leaderboards {
                print("[ManualUpdate] 📝 \(collection): \(data)")
            }
        }
    }
    
    // Helper function to determine if score should be updated
    private func shouldUpdateScore(collection: String, currentData: [String: Any]?, newData: [String: Any]) -> Bool {
        guard let currentData = currentData else { return true }
        
        switch collection {
        case "classic_leaderboard":
            let currentScore = currentData["score"] as? Int ?? 0
            let newScore = newData["score"] as? Int ?? 0
            return newScore > currentScore
            
        case "achievement_leaderboard":
            // Always update achievement scores
            return true
            
        case "classic_timed_leaderboard":
            let currentTime = currentData["time"] as? Double ?? Double.infinity
            let newTime = newData["time"] as? Double ?? Double.infinity
            return newTime < currentTime // Lower time is better
            
        default:
            return true
        }
    }
    
    // Helper function to update a specific leaderboard type
    func updateSpecificLeaderboard(type: LeaderboardType, shouldWrite: Bool = false) async throws {
        // Get and validate user data
        let (userId, username) = try getCurrentUserData()
        
        // Get current game state with validation
        let currentScore = max(0, UserDefaults.standard.integer(forKey: "highScore"))
        let currentLevel = max(1, UserDefaults.standard.integer(forKey: "highestLevel"))
        let currentTime = max(0, UserDefaults.standard.double(forKey: "bestTime"))
        
        let collection = type.collectionName
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        // Get current time in EST
        let now = Date()
        let calendar = Calendar.current
        let estNow = now.addingTimeInterval(TimeInterval(TimeZone(identifier: "America/New_York")!.secondsFromGMT()))
        
        // Create base data dictionary with UTC timestamp
        var data: [String: Any] = [
            "username": username,
            "timestamp": FieldValue.serverTimestamp(),
            "userId": userId,
            "lastUpdate": FieldValue.serverTimestamp(),
            "level": currentLevel
        ]
        
        // Add appropriate score field based on leaderboard type
        switch type {
        case .achievement:
            data["points"] = currentScore
        case .timed:
            data["time"] = currentTime
        case .score:
            data["score"] = currentScore
        }
        
        if shouldWrite {
            print("[ManualUpdate] 📝 Starting manual update for \(collection)")
            
            for period in periods {
                do {
                    // Calculate period start date
                    let startDate: Date
                    switch period {
                    case "daily":
                        startDate = calendar.startOfDay(for: estNow)
                    case "weekly":
                        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: estNow)
                        components.weekday = 1 // Sunday
                        startDate = calendar.date(from: components) ?? now
                    case "monthly":
                        var components = calendar.dateComponents([.year, .month], from: estNow)
                        components.day = 1
                        components.hour = 0
                        components.minute = 0
                        components.second = 0
                        startDate = calendar.date(from: components) ?? now
                    default:
                        startDate = Date.distantPast
                    }
                    
                    // Add periodStart to data
                    data["periodStart"] = Timestamp(date: startDate)
                    
                    let docRef = db.collection(collection)
                        .document(period)
                        .collection("scores")
                        .document(userId)
                    
                    // Check if document exists and get current data
                    let currentDoc = try await docRef.getDocument()
                    let currentData = currentDoc.data()
                    
                    // Only update if new data is better or no data exists
                    let shouldUpdate = shouldUpdateScore(
                        collection: collection,
                        currentData: currentData,
                        newData: data
                    )
                    
                    if shouldUpdate {
                        print("[ManualUpdate] 📝 Updating \(collection)/\(period) for user \(userId)")
                        print("[ManualUpdate] 📊 Data: \(data)")
                        
                        try await docRef.setData(data, merge: true)
                        print("[ManualUpdate] ✅ Successfully updated \(collection)/\(period)")
                        
                        // Invalidate cache for this leaderboard
                        LeaderboardCache.shared.invalidateCache(type: type, period: period)
                    } else {
                        print("[ManualUpdate] ⏭️ Skipping update - current score is better")
                    }
                    
                } catch {
                    print("[ManualUpdate] ❌ Error updating \(collection)/\(period): \(error.localizedDescription)")
                    throw error
                }
            }
            
            print("[ManualUpdate] ✅ Completed manual update for \(collection)")
        } else {
            print("[ManualUpdate] ⏭️ Skipping write - shouldWrite is false")
            print("[ManualUpdate] 📊 Would have written the following data for \(collection):")
            print("[ManualUpdate] 📝 \(data)")
        }
    }
    
    // Add test function to verify updates
    func testLeaderboardUpdate() async {
        print("[ManualUpdate] 🧪 Starting leaderboard update test")
        
        do {
            // Get current user data
            guard let userId = Auth.auth().currentUser?.uid else {
                print("[ManualUpdate] ❌ Test failed - No authenticated user")
                return
            }
            
            let username = UserDefaults.standard.string(forKey: "username") ?? "jrftw"
            let testScore = 1000
            let testLevel = 1
            let testTime = 60.0
            
            print("[ManualUpdate] 🧪 Test data:")
            print("[ManualUpdate] - User ID: \(userId)")
            print("[ManualUpdate] - Username: \(username)")
            print("[ManualUpdate] - Score: \(testScore)")
            print("[ManualUpdate] - Level: \(testLevel)")
            print("[ManualUpdate] - Time: \(testTime)")
            
            // Try to update all leaderboards
            try await updateAllLeaderboardsWithData(
                finalScore: testScore,
                finalLevel: testLevel,
                totalTime: testTime,
                shouldWrite: true
            )
            
            // Verify the updates
            let periods = ["daily", "weekly", "monthly", "alltime"]
            for period in periods {
                let docRef = db.collection("classic_leaderboard")
                    .document(period)
                    .collection("scores")
                    .document(userId)
                
                let document = try await docRef.getDocument()
                if document.exists {
                    let data = document.data()
                    print("[ManualUpdate] ✅ Verified \(period) update:")
                    print("[ManualUpdate] - Score: \(data?["score"] ?? "nil")")
                    print("[ManualUpdate] - Username: \(data?["username"] ?? "nil")")
                    print("[ManualUpdate] - Level: \(data?["level"] ?? "nil")")
                } else {
                    print("[ManualUpdate] ❌ Failed to verify \(period) update - Document doesn't exist")
                }
            }
            
            print("[ManualUpdate] 🧪 Test completed")
            
        } catch {
            print("[ManualUpdate] ❌ Test failed with error: \(error.localizedDescription)")
        }
    }
    
    // New function for toggleable leaderboard updates
    func updateLeaderboardWithToggle(finalScore: Int, finalLevel: Int, totalTime: Double) async throws {
        guard isLeaderboardUpdateEnabled else {
            print("[ManualUpdate] ⏭️ Leaderboard updates are disabled - skipping update")
            return
        }
        
        print("[ManualUpdate] 🏆 Starting leaderboard update with toggle")
        
        let uid = Auth.auth().currentUser?.uid ?? "unknown"
        let username = UserDefaults.standard.string(forKey: "username") ?? "jrftw"
        
        // Define all leaderboard types and their data
        let leaderboards: [(collection: String, data: [String: Any])] = [
            ("classic_leaderboard", [
                "userId": uid,
                "username": username,
                "score": finalScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "time": totalTime
            ]),
            ("achievement_leaderboard", [
                "userId": uid,
                "username": username,
                "points": finalScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "time": totalTime
            ]),
            ("classic_timed_leaderboard", [
                "userId": uid,
                "username": username,
                "time": totalTime,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "score": finalScore
            ])
        ]
        
        // Define all periods
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        // Update all leaderboard types
        for (collection, data) in leaderboards {
            for period in periods {
                do {
                    let docRef = db.collection(collection)
                        .document(period)
                        .collection("scores")
                        .document(uid)
                    
                    // Check if document exists
                    let currentDoc = try await docRef.getDocument()
                    
                    if !currentDoc.exists {
                        // Create new leaderboard entry
                        print("[ManualUpdate] 📝 Creating new \(period) entry for \(collection)")
                        try await docRef.setData(data)
                        print("[ManualUpdate] ✅ Created new \(period) entry for \(collection)")
                    } else {
                        // Update existing entry if score is better
                        let currentData = currentDoc.data()
                        let currentScore = currentData?["score"] as? Int ?? 0
                        let currentTime = currentData?["time"] as? Double ?? 0
                        
                        let shouldUpdate = collection == "achievement_leaderboard" ? true :
                                         collection == "classic_timed_leaderboard" ? totalTime < currentTime :
                                         finalScore > currentScore
                        
                        if shouldUpdate {
                            print("[ManualUpdate] 📝 Updating existing \(period) entry for \(collection)")
                            try await docRef.setData(data, merge: true)
                            print("[ManualUpdate] ✅ Updated existing \(period) entry for \(collection)")
                        } else {
                            print("[ManualUpdate] ⏭️ Skipping update - current score is better")
                        }
                    }
                    
                    // Invalidate cache for this leaderboard
                    LeaderboardCache.shared.invalidateCache(period: period)
                    
                } catch {
                    print("[ManualUpdate] ❌ Error updating \(collection)/\(period): \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        print("[ManualUpdate] ✅ Completed all leaderboard updates")
    }
    
    // Add function to regenerate deleted entries
    func regenerateDeletedEntries() async throws {
        print("[ManualUpdate] 🔄 Starting regeneration of deleted entries")
        
        let uid = Auth.auth().currentUser?.uid ?? "unknown"
        let username = UserDefaults.standard.string(forKey: "username") ?? "jrftw"
        
        // Get current scores from UserDefaults
        let currentScore = max(0, UserDefaults.standard.integer(forKey: "highScore"))
        let currentLevel = max(1, UserDefaults.standard.integer(forKey: "highestLevel"))
        let currentTime = max(0, UserDefaults.standard.double(forKey: "bestTime"))
        
        // Define all leaderboard types and their data
        let leaderboards: [(collection: String, data: [String: Any])] = [
            ("classic_leaderboard", [
                "userId": uid,
                "username": username,
                "score": currentScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": currentLevel,
                "time": currentTime
            ]),
            ("achievement_leaderboard", [
                "userId": uid,
                "username": username,
                "points": currentScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": currentLevel,
                "time": currentTime
            ]),
            ("classic_timed_leaderboard", [
                "userId": uid,
                "username": username,
                "time": currentTime,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": currentLevel,
                "score": currentScore
            ])
        ]
        
        // Define all periods
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        // Check and regenerate entries for all leaderboard types
        for (collection, data) in leaderboards {
            for period in periods {
                do {
                    let docRef = db.collection(collection)
                        .document(period)
                        .collection("scores")
                        .document(uid)
                    
                    // Check if document exists
                    let currentDoc = try await docRef.getDocument()
                    
                    if !currentDoc.exists {
                        print("[ManualUpdate] 🔄 Regenerating deleted entry for \(collection)/\(period)")
                        try await docRef.setData(data)
                        print("[ManualUpdate] ✅ Successfully regenerated entry for \(collection)/\(period)")
                        
                        // Invalidate cache for this leaderboard
                        LeaderboardCache.shared.invalidateCache(period: period)
                    } else {
                        print("[ManualUpdate] ⏭️ Entry exists for \(collection)/\(period) - skipping regeneration")
                    }
                } catch {
                    print("[ManualUpdate] ❌ Error regenerating entry for \(collection)/\(period): \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        print("[ManualUpdate] ✅ Completed regeneration of deleted entries")
    }
}
