import Foundation
import FirebaseFirestore
import FirebaseAuth

class ManualLeaderboardUpdate {
    static let shared = ManualLeaderboardUpdate()
    private let db = Firestore.firestore()
    
    private init() {}
    
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
                "score": finalScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "time": totalTime
            ]),
            ("classic_timed_leaderboard", [
                "userId": uid,
                "username": username,
                "score": finalScore,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUpdate": FieldValue.serverTimestamp(),
                "level": finalLevel,
                "time": totalTime
            ])
        ]
        
        // Update all leaderboard types
        for (collection, data) in leaderboards {
            do {
                let docRef = db.collection(collection)
                    .document("daily")
                    .collection("scores")
                    .document(uid)
                
                print("[ManualUpdate] 📝 Updating daily entry for \(collection)")
                print("[ManualUpdate] 📊 Data: \(data)")
                
                // Force update the daily entry regardless of existence
                try await docRef.setData(data, merge: true)
                print("[ManualUpdate] ✅ Successfully updated daily entry for \(collection)")
                
                // Invalidate cache for daily leaderboard
                LeaderboardCache.shared.invalidateCache(period: "daily")
                
            } catch {
                print("[ManualUpdate] ❌ Error updating \(collection): \(error.localizedDescription)")
                throw error
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
            let currentPoints = currentData["points"] as? Int ?? 0
            let newPoints = newData["points"] as? Int ?? 0
            return newPoints > currentPoints
            
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
        
        var data: [String: Any] = [
            "userId": userId,
            "username": username,
            "timestamp": FieldValue.serverTimestamp(),
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
}
