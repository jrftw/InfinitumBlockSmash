import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine
import Network
import SwiftUI
import FirebaseDatabase
import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics
import AuthenticationServices
import CryptoKit
import FirebaseFunctions

// Network monitoring class
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published private(set) var isConnected = false
    @Published private(set) var connectionType: NWInterface.InterfaceType = .other
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type ?? .other
                
                if path.status == .satisfied {
                    print("[NetworkMonitor] Connected via \(self?.connectionType.description ?? "unknown")")
                } else {
                    print("[NetworkMonitor] Not connected. Status: \(path.status)")
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    func checkConnection() async -> Bool {
        return isConnected
    }
}

extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
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
    case invalidCredential
}

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var username: String?
    @Published private(set) var deviceId: String?
    @Published private(set) var isGuest = false
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?
    @Published private(set) var referralCode: String?
    @Published private(set) var referredBy: String?
    @Published private(set) var purchasedHints: Int = 0
    @Published var purchasedUndos: Int = 0
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cachedProgress: GameProgress?
    private var lastActiveUpdateTimer: Timer?
    private let rtdb = Database.database().reference()
    
    private init() {
        // Keep RTDB synced
        rtdb.keepSynced(true)
    }
    
    deinit {
        lastActiveUpdateTimer?.invalidate()
    }
    
    private func startLastActiveUpdates() {
        // Update lastActive every 2 minutes
        lastActiveUpdateTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task {
                await self?.updateLastActive()
            }
        }
        // Initial update
        Task {
            await updateLastActive()
        }
    }
    
    private func updateLastActive() async {
        guard let userId = currentUser?.uid else {
            print("[FirebaseManager] Cannot update lastActive: No current user")
            return
        }
        do {
            print("[FirebaseManager] Updating lastActive for current user: \(userId)")
            try await db.collection("users").document(userId).updateData([
                "lastActive": FieldValue.serverTimestamp()
            ])
            print("[FirebaseManager] Successfully updated lastActive for current user")
            
            // Verify the update
            let doc = try await db.collection("users").document(userId).getDocument()
            if let lastActive = doc.data()?["lastActive"] as? Timestamp {
                print("[FirebaseManager] Verified lastActive timestamp: \(lastActive.dateValue())")
            }
        } catch {
            print("[FirebaseManager] Error updating lastActive: \(error)")
        }
    }
    
    // MARK: - Authentication
    
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                self?.currentUser = user
                if let user = user {
                    await self?.loadUserData(userId: user.uid)
                }
            }
        }
    }
    
    func signInAnonymously() async throws {
        do {
            let result = try await auth.signInAnonymously()
            isGuest = true
            
            // Create or update user document with proper timestamps
            let userData: [String: Any] = [
                "deviceId": generateDeviceId(),
                "referralCode": generateReferralCode(),
                "createdAt": FieldValue.serverTimestamp(),
                "lastLogin": FieldValue.serverTimestamp(),
                "lastActive": FieldValue.serverTimestamp(),
                "userId": result.user.uid
            ]
            
            try await db.collection("users").document(result.user.uid).setData(userData, merge: true)
            await loadUserData(userId: result.user.uid)
        } catch {
            print("Error signing in anonymously: \(error)")
            throw error
        }
    }
    
    private func signInWithApple() async throws {
        let nonce = randomNonceString()
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = SignInWithAppleDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
        
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw FirebaseError.invalidCredential
        }
        
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        let authResult = try await Auth.auth().signIn(with: credential)
        currentUser = authResult.user
        
        // Create or update user document
        try await createOrUpdateUserDocument(user: authResult.user)
    }
    
    func signOut() throws {
        try auth.signOut()
        isGuest = false
        currentUser = nil
        username = nil
    }
    
    // MARK: - User Data
    
    private func loadUserData(userId: String) async {
        do {
            let docRef = db.collection("users").document(userId)
            let document = try await docRef.getDocument()
            
            if let data = document.data() {
                await MainActor.run {
                    self.username = data["displayName"] as? String
                    self.referralCode = data["referralCode"] as? String
                    self.referredBy = data["referredBy"] as? String
                    self.purchasedHints = data["purchasedHints"] as? Int ?? 0
                    self.purchasedUndos = data["purchasedUndos"] as? Int ?? 0
                }
            } else {
                // Create new user document if it doesn't exist
                let newUserData: [String: Any] = [
                    "deviceId": generateDeviceId(),
                    "referralCode": generateReferralCode(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "lastActive": FieldValue.serverTimestamp(),
                    "userId": userId
                ]
                try await docRef.setData(newUserData)
                
                // Load the newly created data
                await loadUserData(userId: userId)
            }
        } catch {
            print("Error loading user data: \(error.localizedDescription)")
        }
    }
    
    func updateUsername(_ newUsername: String) async throws {
        guard let userId = currentUser?.uid else { return }
        
        // Check if username is already taken
        let querySnapshot = try await db.collection("users")
            .whereField("username", isEqualTo: newUsername)
            .getDocuments()
        
        if !querySnapshot.documents.isEmpty {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Username already taken"])
        }
        
        try await db.collection("users").document(userId).updateData([
            "username": newUsername
        ])
        
        username = newUsername
    }
    
    // MARK: - Device ID Management
    
    private func loadDeviceId() {
        if let savedDeviceId = UserDefaults.standard.string(forKey: "deviceId") {
            deviceId = savedDeviceId
        } else {
            deviceId = generateDeviceId()
            UserDefaults.standard.set(deviceId, forKey: "deviceId")
        }
    }
    
    private func generateDeviceId() -> String {
        return UUID().uuidString
    }
    
    // MARK: - Data Synchronization
    
    func syncUserData() async {
        guard let userId = currentUser?.uid else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Sync game progress
            let progress = GameProgress(
                score: UserDefaults.standard.integer(forKey: "score"),
                level: UserDefaults.standard.integer(forKey: "level"),
                blocksPlaced: UserDefaults.standard.integer(forKey: "blocksPlaced"),
                linesCleared: UserDefaults.standard.integer(forKey: "linesCleared"),
                gamesCompleted: UserDefaults.standard.integer(forKey: "gamesCompleted"),
                perfectLevels: UserDefaults.standard.integer(forKey: "perfectLevels"),
                totalPlayTime: UserDefaults.standard.double(forKey: "totalPlayTime"),
                highScore: UserDefaults.standard.integer(forKey: "highScore"),
                highestLevel: UserDefaults.standard.integer(forKey: "highestLevel")
            )
            
            try await db.collection("users").document(userId).collection("progress").document("data").setData(progress.dictionary)
            
            // Sync settings
            let settings: [String: Any] = [
                "soundEnabled": UserDefaults.standard.bool(forKey: "soundEnabled"),
                "musicEnabled": UserDefaults.standard.bool(forKey: "musicEnabled"),
                "vibrationEnabled": UserDefaults.standard.bool(forKey: "vibrationEnabled"),
                "theme": UserDefaults.standard.string(forKey: "theme") ?? "default",
                "difficulty": UserDefaults.standard.string(forKey: "difficulty") ?? "normal"
            ]
            
            try await db.collection("users").document(userId).collection("settings").document("data").setData(settings)
            
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
            print("Error syncing user data: \(error)")
        }
        
        isSyncing = false
    }
    
    func loadSyncedData() async {
        guard let userId = currentUser?.uid else { return }
        
        do {
            // Load game progress
            let progressDoc = try await db.collection("users").document(userId).collection("progress").document("data").getDocument()
            if let progressData = progressDoc.data() {
                UserDefaults.standard.set(progressData["score"] as? Int ?? 0, forKey: "score")
                UserDefaults.standard.set(progressData["level"] as? Int ?? 1, forKey: "level")
                UserDefaults.standard.set(progressData["blocksPlaced"] as? Int ?? 0, forKey: "blocksPlaced")
                UserDefaults.standard.set(progressData["linesCleared"] as? Int ?? 0, forKey: "linesCleared")
                UserDefaults.standard.set(progressData["gamesCompleted"] as? Int ?? 0, forKey: "gamesCompleted")
                UserDefaults.standard.set(progressData["perfectLevels"] as? Int ?? 0, forKey: "perfectLevels")
                UserDefaults.standard.set(progressData["totalPlayTime"] as? Double ?? 0, forKey: "totalPlayTime")
                UserDefaults.standard.set(progressData["highScore"] as? Int ?? 0, forKey: "highScore")
                UserDefaults.standard.set(progressData["highestLevel"] as? Int ?? 1, forKey: "highestLevel")
                UserDefaults.standard.synchronize()
            }
            
            // Load settings
            let settingsDoc = try await db.collection("users").document(userId).collection("settings").document("data").getDocument()
            if let settingsData = settingsDoc.data() {
                UserDefaults.standard.set(settingsData["soundEnabled"] as? Bool ?? true, forKey: "soundEnabled")
                UserDefaults.standard.set(settingsData["musicEnabled"] as? Bool ?? true, forKey: "musicEnabled")
                UserDefaults.standard.set(settingsData["vibrationEnabled"] as? Bool ?? true, forKey: "vibrationEnabled")
                UserDefaults.standard.set(settingsData["theme"] as? String ?? "default", forKey: "theme")
                UserDefaults.standard.set(settingsData["difficulty"] as? String ?? "normal", forKey: "difficulty")
                UserDefaults.standard.synchronize()
            }
        } catch {
            print("Error loading synced data: \(error)")
        }
    }
    
    // MARK: - Background Sync
    
    func syncDataInBackground() async throws {
        guard let userId = currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Get local data
        let localProgress = GameProgress(
            score: UserDefaults.standard.integer(forKey: "score"),
            level: UserDefaults.standard.integer(forKey: "level"),
            blocksPlaced: UserDefaults.standard.integer(forKey: "blocksPlaced"),
            linesCleared: UserDefaults.standard.integer(forKey: "linesCleared"),
            gamesCompleted: UserDefaults.standard.integer(forKey: "gamesCompleted"),
            perfectLevels: UserDefaults.standard.integer(forKey: "perfectLevels"),
            totalPlayTime: UserDefaults.standard.double(forKey: "totalPlayTime"),
            highScore: UserDefaults.standard.integer(forKey: "highScore"),
            highestLevel: UserDefaults.standard.integer(forKey: "highestLevel")
        )
        
        // Get cloud data
        let progressDoc = try await db.collection("users").document(userId).collection("progress").document("data").getDocument()
        let cloudProgress = progressDoc.data()
        
        // Compare timestamps and merge data
        if let cloudData = cloudProgress,
           let cloudLastSave = cloudData["lastSaveTime"] as? Timestamp,
           let localLastSave = UserDefaults.standard.object(forKey: "lastSaveTime") as? Date {
            
            if localLastSave > cloudLastSave.dateValue() {
                // Local data is newer, upload it
                try await db.collection("users").document(userId).collection("progress").document("data").setData(localProgress.dictionary)
            } else if cloudLastSave.dateValue() > localLastSave {
                // Cloud data is newer, update local
                UserDefaults.standard.set(cloudData["score"] as? Int ?? 0, forKey: "score")
                UserDefaults.standard.set(cloudData["level"] as? Int ?? 1, forKey: "level")
                UserDefaults.standard.set(cloudData["blocksPlaced"] as? Int ?? 0, forKey: "blocksPlaced")
                UserDefaults.standard.set(cloudData["linesCleared"] as? Int ?? 0, forKey: "linesCleared")
                UserDefaults.standard.set(cloudData["gamesCompleted"] as? Int ?? 0, forKey: "gamesCompleted")
                UserDefaults.standard.set(cloudData["perfectLevels"] as? Int ?? 0, forKey: "perfectLevels")
                UserDefaults.standard.set(cloudData["totalPlayTime"] as? Double ?? 0, forKey: "totalPlayTime")
                UserDefaults.standard.set(cloudData["highScore"] as? Int ?? 0, forKey: "highScore")
                UserDefaults.standard.set(cloudData["highestLevel"] as? Int ?? 1, forKey: "highestLevel")
                UserDefaults.standard.synchronize()
            }
        } else {
            // No cloud data, upload local
            try await db.collection("users").document(userId).collection("progress").document("data").setData(localProgress.dictionary)
        }
        
        // Update last active timestamp
        try await db.collection("users").document(userId).updateData([
            "lastActive": FieldValue.serverTimestamp()
        ])
        
        lastSyncDate = Date()
    }
    
    // MARK: - Statistics Methods
    
    func getDailyPlayersCount() async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        print("[FirebaseManager] Getting daily players count since: \(startOfDay)")
        
        let query = db.collection("users")
            .whereField("lastActive", isGreaterThan: startOfDay)
        
        let snapshot = try await query.count.getAggregation(source: .server)
        let count = Int(truncating: snapshot.count)
        print("[FirebaseManager] Daily players count: \(count)")
        return count
    }
    
    func getOnlineUsersCount() async throws -> Int {
        let fiveMinutesAgo = Timestamp(date: Date().addingTimeInterval(-300))
        print("[FirebaseManager] Getting online users count since: \(fiveMinutesAgo.dateValue())")
        
        let snapshot = try await db.collection("users")
            .whereField("lastActive", isGreaterThan: fiveMinutesAgo)
            .count
            .getAggregation(source: .server)
        
        let count = Int(truncating: snapshot.count)
        print("[FirebaseManager] Online users count: \(count)")
        return count
    }
    
    // MARK: - Leaderboard
    
    func submitScore(_ score: Int, level: Int) async throws {
        guard let userId = currentUser?.uid,
              let username = username else { 
            throw FirebaseError.notAuthenticated 
        }
        
        try validateUserId(userId)
        
        let scoreData: [String: Any] = [
            "userId": userId,
            "score": score,
            "level": level,
            "username": username,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        // Submit to global leaderboard
        try await db.collection("leaderboard").addDocument(data: scoreData)
        
        // Submit to daily leaderboard
        try await db.collection("classic_leaderboard")
            .document("daily")
            .collection("scores")
            .document(userId)
            .setData(scoreData, merge: true)
        
        // Submit to weekly leaderboard
        try await db.collection("classic_leaderboard")
            .document("weekly")
            .collection("scores")
            .document(userId)
            .setData(scoreData, merge: true)
        
        // Submit to monthly leaderboard
        try await db.collection("classic_leaderboard")
            .document("monthly")
            .collection("scores")
            .document(userId)
            .setData(scoreData, merge: true)
        
        // Submit to Realtime Database
        let rtdbRef = rtdb.child("leaderboards").childByAutoId()
        try await rtdbRef.setValue([
            "userId": userId,
            "score": score,
            "timestamp": ServerValue.timestamp()
        ])
        
        print("[FirebaseManager] Successfully submitted score for user: \(userId)")
    }
    
    // Add function to submit achievement score
    func submitAchievementScore(_ score: Int, achievementId: String) async throws {
        guard let userId = currentUser?.uid,
              let username = username else { 
            throw FirebaseError.notAuthenticated 
        }
        
        try validateUserId(userId)
        
        let scoreData: [String: Any] = [
            "userId": userId,
            "score": score,
            "achievementId": achievementId,
            "username": username,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        // Submit to daily achievement leaderboard
        try await db.collection("achievement_leaderboard")
            .document("daily")
            .collection("scores")
            .document(userId)
            .setData(scoreData, merge: true)
        
        // Submit to weekly achievement leaderboard
        try await db.collection("achievement_leaderboard")
            .document("weekly")
            .collection("scores")
            .document(userId)
            .setData(scoreData, merge: true)
        
        // Submit to monthly achievement leaderboard
        try await db.collection("achievement_leaderboard")
            .document("monthly")
            .collection("scores")
            .document(userId)
            .setData(scoreData, merge: true)
        
        print("[FirebaseManager] Successfully submitted achievement score for user: \(userId)")
    }
    
    // Add function to get current leaderboard timeframes
    func getCurrentLeaderboardTimeframes() async throws -> [String: [String: Date]] {
        let functions = Functions.functions()
        let result = try await functions.httpsCallable("getCurrentLeaderboardTimeframe").call()
        
        guard let data = result.data as? [String: [String: Any]] else {
            throw FirebaseError.invalidData
        }
        
        var timeframes: [String: [String: Date]] = [:]
        
        if let daily = data["daily"] {
            let startDate = (daily["start"] as? [String: Any])?["_seconds"] as? TimeInterval
            let endDate = (daily["end"] as? [String: Any])?["_seconds"] as? TimeInterval
            
            timeframes["daily"] = [
                "start": startDate.map { Date(timeIntervalSince1970: $0) } ?? Date(),
                "end": endDate.map { Date(timeIntervalSince1970: $0) } ?? Date()
            ]
        }
        
        if let weekly = data["weekly"] {
            let startDate = (weekly["start"] as? [String: Any])?["_seconds"] as? TimeInterval
            let endDate = (weekly["end"] as? [String: Any])?["_seconds"] as? TimeInterval
            
            timeframes["weekly"] = [
                "start": startDate.map { Date(timeIntervalSince1970: $0) } ?? Date(),
                "end": endDate.map { Date(timeIntervalSince1970: $0) } ?? Date()
            ]
        }
        
        if let monthly = data["monthly"] {
            let startDate = (monthly["start"] as? [String: Any])?["_seconds"] as? TimeInterval
            let endDate = (monthly["end"] as? [String: Any])?["_seconds"] as? TimeInterval
            
            timeframes["monthly"] = [
                "start": startDate.map { Date(timeIntervalSince1970: $0) } ?? Date(),
                "end": endDate.map { Date(timeIntervalSince1970: $0) } ?? Date()
            ]
        }
        
        return timeframes
    }
    
    // Add caching for frequently accessed data
    private var leaderboardCache: (entries: [LeaderboardEntry], timestamp: Date)?
    
    func loadLeaderboardData(limit: Int = 100, forceRefresh: Bool = false) async throws -> [LeaderboardEntry] {
        // Check cache first if not forcing refresh
        if !forceRefresh, let cachedData = leaderboardCache, Date().timeIntervalSince(cachedData.timestamp) < 300 {
            return cachedData.entries
        }
        
        let snapshot = try await db.collection("leaderboard")
            .order(by: "score", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let entries = snapshot.documents.compactMap { document -> LeaderboardEntry? in
            guard let username = document.data()["username"] as? String,
                  let score = document.data()["score"] as? Int,
                  let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() else {
                return nil
            }
            return LeaderboardEntry(
                userId: document.documentID,
                username: username,
                score: score,
                level: document.data()["level"] as? Int ?? 1,
                timestamp: timestamp
            )
        }
        
        // Update cache
        leaderboardCache = (entries: entries, timestamp: Date())
        
        return entries
    }
    
    // MARK: - Referral Code Management
    
    func applyReferralCode(_ code: String) async throws {
        guard let currentUserId = currentUser?.uid else { return }
        
        // Check if the referral code exists
        let querySnapshot = try await db.collection("users")
            .whereField("referralCode", isEqualTo: code)
            .getDocuments()
        
        guard let referrerDoc = querySnapshot.documents.first else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid referral code"])
        }
        
        let referrerId = referrerDoc.documentID
        
        // Don't allow self-referral
        guard referrerId != currentUserId else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot use your own referral code"])
        }
        
        // Update user's referredBy field
        try await db.collection("users").document(currentUserId).updateData([
            "referredBy": referrerId
        ])
        
        referredBy = referrerId
        
        // Update referrer's stats
        try await db.collection("users").document(referrerId).updateData([
            "referrals": FieldValue.increment(Int64(1))
        ])
    }
    
    private func generateReferralCode() -> String {
        // Generate a 6-character alphanumeric code
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Game Progress Methods
    
    func loadGameProgress() async throws -> GameProgress {
        guard let userId = currentUser?.uid else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        do {
            let doc = try await db.collection("users").document(userId).collection("progress").document("data").getDocument()
            
            guard let data = doc.data() else {
                return GameProgress() // Return empty progress if no data exists
            }
            
            guard let progress = GameProgress(dictionary: data) else {
                throw NSError(domain: "FirebaseManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid progress data"])
            }
            
            return progress
        } catch {
            print("Error loading game progress: \(error)")
            throw error
        }
    }
    
    func saveGameProgress(_ progress: GameProgress) async throws {
        let userId = try validateUserId()
        
        // Add metadata to progress data
        var progressData = progress.dictionary
        progressData["userId"] = userId
        progressData["deviceId"] = UIDevice.current.identifierForVendor?.uuidString ?? ""
        progressData["lastUpdate"] = Date().timeIntervalSince1970
        progressData["lastSaveTime"] = Date().timeIntervalSince1970
        
        // Save to Firestore
        let firestoreRef = db.collection("users").document(userId)
            .collection("progress")
            .document("current")
        try await firestoreRef.setData(progressData, merge: true)
        
        // Save to RTDB for real-time sync
        let rtdbRef = rtdb.child("users").child(userId)
            .child("progress")
        try await rtdbRef.setValue(progressData)
        
        print("[Firebase] Game progress saved for user: \(userId)")
    }
    
    func performInitialDeviceSync() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Get local data
        let localProgress = getCachedGameProgress()
        
        // Get cloud data
        let cloudProgress = try await loadGameProgress()
        
        // Compare timestamps and merge data
        if let local = localProgress {
            if local.lastSaveTime > cloudProgress.lastSaveTime {
                // Local data is newer, upload it
                try await saveGameProgress(local)
            } else if cloudProgress.lastSaveTime > local.lastSaveTime {
                // Cloud data is newer, update local
                cacheGameProgress(cloudProgress)
                cachedProgress = cloudProgress
                
                // Update UserDefaults
                UserDefaults.standard.set(cloudProgress.highScore, forKey: "highScore")
                UserDefaults.standard.set(cloudProgress.highestLevel, forKey: "highestLevel")
                UserDefaults.standard.set(cloudProgress.lastSaveTime, forKey: "lastSaveTime")
                UserDefaults.standard.synchronize()
            }
        } else {
            // No local data, use cloud data
            cacheGameProgress(cloudProgress)
            cachedProgress = cloudProgress
            
            // Update UserDefaults
            UserDefaults.standard.set(cloudProgress.highScore, forKey: "highScore")
            UserDefaults.standard.set(cloudProgress.highestLevel, forKey: "highestLevel")
            UserDefaults.standard.set(cloudProgress.lastSaveTime, forKey: "lastSaveTime")
            UserDefaults.standard.synchronize()
        }
        
        // Sync achievements with the current user ID
        try await syncAchievements(userId: userId)
    }
    
    private func getCachedGameProgress() -> GameProgress? {
        return cachedProgress
    }
    
    private func cacheGameProgress(_ progress: GameProgress) {
        cachedProgress = progress
    }
    
    private func syncAchievements(userId: String) async throws {
        try validateUserId(userId)
        
        let userRef = db.collection("users").document(userId)
        
        // Get local achievements
        let localAchievements = try? await userRef
            .collection("achievements")
            .getDocuments()
        
        // Get cloud achievements
        let cloudAchievements = try await userRef
            .collection("achievements")
            .getDocuments()
        
        // Merge achievements
        var mergedAchievements: [String: [String: Any]] = [:]
        
        // Add local achievements
        localAchievements?.documents.forEach { doc in
            mergedAchievements[doc.documentID] = doc.data()
        }
        
        // Add or update with cloud achievements
        cloudAchievements.documents.forEach { doc in
            let cloudData = doc.data()
            if let localData = mergedAchievements[doc.documentID],
               let localTimestamp = localData["lastUpdated"] as? Timestamp,
               let cloudTimestamp = cloudData["lastUpdated"] as? Timestamp {
                // Keep the more recent version
                if cloudTimestamp.dateValue() > localTimestamp.dateValue() {
                    mergedAchievements[doc.documentID] = cloudData
                }
            } else {
                mergedAchievements[doc.documentID] = cloudData
            }
        }
        
        // Save merged achievements with metadata
        for (id, data) in mergedAchievements {
            let achievementData = addMetadata(data, userId: userId)
            
            try await userRef
                .collection("achievements")
                .document(id)
                .setData(achievementData, merge: true)
        }
        
        // Update last sync time
        try await userRef.updateData([
            "lastAchievementSync": FieldValue.serverTimestamp(),
            "lastActive": FieldValue.serverTimestamp(),
            "lastSync": FieldValue.serverTimestamp()
        ])
        
        print("[FirebaseManager] Successfully synced achievements for user: \(userId)")
    }
    
    private func createOrUpdateUserDocument(user: User) async throws {
        let userId = user.uid
        let userRef = db.collection("users").document(userId)
        let userData: [String: Any] = [
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "lastLogin": FieldValue.serverTimestamp(),
            "lastActive": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp(),
            "userId": userId,
            "deviceId": generateDeviceId(),
            "referralCode": generateReferralCode()
        ]
        
        try await userRef.setData(userData, merge: true)
        
        // Load user data after creating/updating document
        await loadUserData(userId: userId)
    }
    
    // MARK: - Analytics Methods
    
    func saveAnalyticsData(_ data: [String: Any]) async throws {
        let userId = try validateUserId()
        
        // Add metadata to analytics data
        var analyticsData = data
        analyticsData["userId"] = userId
        analyticsData["deviceId"] = UIDevice.current.identifierForVendor?.uuidString ?? ""
        analyticsData["timestamp"] = FieldValue.serverTimestamp()
        
        // Save to Firestore
        try await db.collection("users").document(userId)
            .collection("analytics")
            .addDocument(data: analyticsData)
        
        print("[Firebase] Analytics data saved for user: \(userId)")
    }
    
    func loadAnalyticsData(timeRange: TimeRange) async throws -> [String: Any] {
        guard let userId = currentUser?.uid else { return [:] }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch timeRange {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .allTime:
            // Use a reasonable past date instead of Date.distantPast
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        do {
            // First check if we have permission to read
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard userDoc.exists else {
                throw FirebaseError.permissionDenied
            }
            
            // Then try to get analytics data
            let query = db.collection("users")
                .document(userId)
                .collection("analytics")
                .whereField("timestamp", isGreaterThan: startDate)
                .order(by: "timestamp", descending: true)
                .limit(to: 1) // Only get the most recent data
            
            let snapshot = try await query.getDocuments()
            return snapshot.documents.first?.data() ?? [:]
        } catch let error as NSError {
            if error.domain == FirestoreErrorDomain {
                switch error.code {
                case 7: // Permission denied
                    throw FirebaseError.permissionDenied
                case 13: // Resource exhausted
                    throw FirebaseError.retryLimitExceeded
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    func getAnalyticsHistory(timeRange: TimeRange) async throws -> [[String: Any]] {
        guard let userId = currentUser?.uid else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch timeRange {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .allTime:
            startDate = Date.distantPast
        }
        
        let query = db.collection("users")
            .document(userId)
            .collection("analytics")
            .whereField("timestamp", isGreaterThan: startDate)
            .order(by: "timestamp", descending: true)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { $0.data()["data"] as? [String: Any] }
    }
    
    // Add method to check sync status
    func checkSyncStatus() async -> Bool {
        guard currentUser?.uid != nil else { return false }
        
        do {
            let doc = try await db.collection("users").document(currentUser!.uid).collection("progress").document("data").getDocument()
            return doc.exists
        } catch {
            print("[FirebaseManager] Error checking sync status: \(error)")
            return false
        }
    }
    
    private func validateUserId(_ userId: String) throws {
        guard !userId.isEmpty else {
            throw FirebaseError.invalidData
        }
        guard userId == currentUser?.uid else {
            throw FirebaseError.permissionDenied
        }
    }

    private func addMetadata(_ data: [String: Any], userId: String) -> [String: Any] {
        var metadata = data
        metadata["userId"] = userId
        metadata["deviceId"] = deviceId
        metadata["lastUpdate"] = FieldValue.serverTimestamp()
        metadata["lastModified"] = FieldValue.serverTimestamp()
        metadata["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        metadata["buildNumber"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return metadata
    }

    // MARK: - User ID Validation
    private func validateUserId() throws -> String {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            throw FirebaseError.notAuthenticated
        }
        return userId
    }
}

// MARK: - Models

extension FirebaseManager {
    struct LeaderboardEntry: Identifiable {
        let id = UUID()
        let userId: String
        let username: String
        let score: Int
        let level: Int
        let timestamp: Date
    }
}

// MARK: - Sign In With Apple Delegate

private class SignInWithAppleDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
} 
