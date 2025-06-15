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
import GameKit

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
    case updateFailed(Error)
}

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    // MARK: - Properties
    private let auth = Auth.auth()
    private let db: Firestore
    private let storage = Storage.storage()
    private let functions = Functions.functions()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var lastActiveUpdateTimer: Timer?
    private var cachedProgress: GameProgress?
    private let rtdb = Database.database().reference()
    private var appCheckToken: String?
    
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
    
    private init() {
        // Configure Firestore settings first
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        self.db = Firestore.firestore()
        self.db.settings = settings
        
        // Configure App Check
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[FirebaseManager] Using debug App Check provider")
        #else
        let providerFactory = DeviceCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[FirebaseManager] Using DeviceCheck provider")
        #endif
        
        // Initialize App Check token
        Task {
            await refreshAppCheckToken()
        }
        
        // Keep RTDB synced
        rtdb.keepSynced(true)
        
        print("[FirebaseManager] Initializing...")
        setupAuthStateListener()
        
        if auth.currentUser == nil {
            print("[FirebaseManager] No user signed in, attempting anonymous sign in...")
            Task {
                do {
                    try await signInAnonymously()
                    print("[FirebaseManager] Anonymous sign in successful")
                } catch {
                    print("[FirebaseManager] Error signing in anonymously: \(error)")
                }
            }
        } else if let userId = auth.currentUser?.uid {
            print("[FirebaseManager] User already signed in: \(userId)")
            Task {
                await loadUserData(userId: userId)
            }
        }
        
        // Start the lastActive timer
        startLastActiveUpdates()
    }
    
    deinit {
        lastActiveUpdateTimer?.invalidate()
    }
    
    private func startLastActiveUpdates() {
        // Update lastActive every 30 seconds instead of 2 minutes
        lastActiveUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
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
            
            // Update Firestore
            try await db.collection("users").document(userId).updateData([
                "lastActive": FieldValue.serverTimestamp()
            ])
            
            // Update RTDB for real-time presence
            try await rtdb.child("online_users").child(userId).setValue(true)
            
            // Update daily stats
            let calendar = Calendar.current
            let lastResetSnapshot = try await rtdb.child("daily_stats").child("last_reset").getData()
            
            if let lastResetTimestamp = lastResetSnapshot.value as? TimeInterval {
                let lastResetDate = Date(timeIntervalSince1970: lastResetTimestamp)
                if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
                    // Reset the count for the new day
                    try await resetDailyPlayersCount()
                } else {
                    // Increment the daily players count
                    let currentCount = try await rtdb.child("daily_stats").child("players_today").getData()
                    if let count = currentCount.value as? Int {
                        try await rtdb.child("daily_stats").child("players_today").setValue(count + 1)
                    } else {
                        try await rtdb.child("daily_stats").child("players_today").setValue(1)
                    }
                }
            }
            
            print("[FirebaseManager] Successfully updated lastActive and presence for current user")
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
                    print("[FirebaseManager] User authenticated with ID: \(user.uid)")
                    // Wait a short moment to ensure auth is fully processed
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await self?.loadUserData(userId: user.uid)
                } else {
                    print("[FirebaseManager] No user authenticated")
                    // Try to sign in anonymously if no user is present
                    do {
                        try await self?.signInAnonymously()
                    } catch {
                        print("[FirebaseManager] Error signing in anonymously: \(error)")
                    }
                }
            }
        }
    }
    
    func signInAnonymously() async throws {
        do {
            print("[FirebaseManager] Starting anonymous sign in...")
            let result = try await auth.signInAnonymously()
            isGuest = true
            print("[FirebaseManager] Anonymous sign in successful for user: \(result.user.uid)")
            
            // Create or update user document with proper timestamps and username
            let userData: [String: Any] = [
                "deviceId": generateDeviceId(),
                "referralCode": generateReferralCode(),
                "createdAt": FieldValue.serverTimestamp(),
                "lastLogin": FieldValue.serverTimestamp(),
                "lastActive": FieldValue.serverTimestamp(),
                "userId": result.user.uid,
                "username": "Guest_\(result.user.uid.prefix(6))" // Add a unique guest username
            ]
            
            print("[FirebaseManager] Creating/updating user document...")
            try await db.collection("users").document(result.user.uid).setData(userData, merge: true)
            print("[FirebaseManager] User document created/updated successfully")
            
            // Update the user's profile with username
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = userData["username"] as? String
            try await changeRequest.commitChanges()
            
            // Wait a short moment to ensure document is created
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await loadUserData(userId: result.user.uid)
        } catch {
            print("[FirebaseManager] Error in signInAnonymously: \(error)")
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
    
    private func migrateUserData(userId: String) async throws {
        print("[FirebaseManager] Starting user data migration for: \(userId)")
        let userRef = db.collection("users").document(userId)
        let doc = try await userRef.getDocument()
        
        guard let data = doc.data() else {
            print("[FirebaseManager] No user data found to migrate")
            return
        }
        
        var updates: [String: Any] = [:]
        
        // Check and add missing fields
        if data["version"] == nil {
            updates["version"] = 1
        }
        
        if data["deviceId"] == nil {
            updates["deviceId"] = generateDeviceId()
        }
        
        if data["referralCode"] == nil {
            updates["referralCode"] = generateReferralCode()
        }
        
        if data["createdAt"] == nil {
            updates["createdAt"] = FieldValue.serverTimestamp()
        }
        
        // Check progress subcollection
        let progressDoc = try await userRef.collection("progress").document("data").getDocument()
        if !progressDoc.exists {
            let progressData: [String: Any] = [
                "blocksPlaced": data["blocksPlaced"] as? Int ?? 0,
                "gamesCompleted": data["gamesCompleted"] as? Int ?? 0,
                "gridSize": data["gridSize"] as? Int ?? 10,
                "highScore": data["highScore"] as? Int ?? 0,
                "highestLevel": data["highestLevel"] as? Int ?? 1,
                "level": data["level"] as? Int ?? 1,
                "linesCleared": data["linesCleared"] as? Int ?? 0,
                "perfectLevels": data["perfectLevels"] as? Int ?? 0,
                "score": data["score"] as? Int ?? 0,
                "totalPlayTime": data["totalPlayTime"] as? Double ?? 0,
                "lastSaveTime": FieldValue.serverTimestamp(),
                "lastUpdated": FieldValue.serverTimestamp()
            ]
            
            try await userRef.collection("progress").document("data").setData(progressData)
            print("[FirebaseManager] Created progress subcollection")
        }
        
        // Update main document if needed
        if !updates.isEmpty {
            try await userRef.updateData(updates)
            print("[FirebaseManager] Updated user document with missing fields")
        }
        
        print("[FirebaseManager] User data migration completed")
    }
    
    private func loadUserData(userId: String) async {
        do {
            print("[FirebaseManager] Loading user data for ID: \(userId)")
            let docRef = db.collection("users").document(userId)
            let document = try await docRef.getDocument()
            
            if let data = document.data() {
                print("[FirebaseManager] User data loaded successfully")
                await MainActor.run {
                    self.username = data["username"] as? String
                    self.referralCode = data["referralCode"] as? String
                    self.referredBy = data["referredBy"] as? String
                    self.purchasedHints = data["purchasedHints"] as? Int ?? 0
                    self.purchasedUndos = data["purchasedUndos"] as? Int ?? 0
                }
                
                // Run migration if needed
                if data["version"] as? Int != 1 {
                    try await migrateUserData(userId: userId)
                }
            } else {
                print("[FirebaseManager] No user document found, creating new one...")
                // Create new user document if it doesn't exist
                let newUserData: [String: Any] = [
                    "deviceId": generateDeviceId(),
                    "referralCode": generateReferralCode(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "lastActive": FieldValue.serverTimestamp(),
                    "userId": userId,
                    "version": 1
                ]
                try await docRef.setData(newUserData)
                print("[FirebaseManager] New user document created")
                
                // Load the newly created data
                await loadUserData(userId: userId)
            }
        } catch {
            print("[FirebaseManager] Error loading user data: \(error.localizedDescription)")
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
        let startOfDayTimestamp = Timestamp(date: startOfDay)
        
        print("[FirebaseManager] Getting daily players count since: \(startOfDay)")
        
        do {
            // First try to get from RTDB for faster response
            let rtdbSnapshot = try await rtdb.child("daily_stats").child("players_today").getData()
            if let count = rtdbSnapshot.value as? Int {
                // Check if the count needs to be reset (if it's from a previous day)
                let lastResetSnapshot = try await rtdb.child("daily_stats").child("last_reset").getData()
                if let lastResetTimestamp = lastResetSnapshot.value as? TimeInterval {
                    let lastResetDate = Date(timeIntervalSince1970: lastResetTimestamp)
                    if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
                        // Reset the count for the new day
                        print("[FirebaseManager] Resetting daily players count for new day")
                        try await resetDailyPlayersCount()
                        return 0
                    }
                }
                
                print("[FirebaseManager] Got daily players count from RTDB: \(count)")
                return count
            }
            
            // Fallback to Firestore if RTDB doesn't have the data
            print("[FirebaseManager] Falling back to Firestore for daily players count")
            let query = db.collection("users")
                .whereField("lastActive", isGreaterThan: startOfDayTimestamp)
            
            let snapshot = try await query.count.getAggregation(source: .server)
            let count = Int(truncating: snapshot.count)
            print("[FirebaseManager] Daily players count from Firestore: \(count)")
            
            // Update RTDB with the count and last reset time
            try await rtdb.child("daily_stats").child("players_today").setValue(count)
            try await rtdb.child("daily_stats").child("last_reset").setValue(Date().timeIntervalSince1970)
            
            return count
        } catch {
            print("[FirebaseManager] Error getting daily players count: \(error)")
            // Return 0 if there's an error, but log it
            return 0
        }
    }
    
    private func resetDailyPlayersCount() async throws {
        print("[FirebaseManager] Resetting daily players count")
        try await rtdb.child("daily_stats").child("players_today").setValue(0)
        try await rtdb.child("daily_stats").child("last_reset").setValue(Date().timeIntervalSince1970)
    }
    
    func getOnlineUsersCount() async throws -> Int {
        // Increase online window to 15 minutes
        let fifteenMinutesAgo = Timestamp(date: Date().addingTimeInterval(-900))
        print("[FirebaseManager] Getting online users count since: \(fifteenMinutesAgo.dateValue())")
        
        do {
            // First try to get from RTDB for faster response
            let rtdbSnapshot = try await rtdb.child("online_users").getData()
            if let onlineUsers = rtdbSnapshot.value as? [String: Bool] {
                let count = onlineUsers.filter { $0.value }.count
                print("[FirebaseManager] Got online users count from RTDB: \(count)")
                return count
            }
            
            // Fallback to Firestore if RTDB doesn't have the data
            print("[FirebaseManager] Falling back to Firestore for online users count")
            let snapshot = try await db.collection("users")
                .whereField("lastActive", isGreaterThan: fifteenMinutesAgo)
                .count
                .getAggregation(source: .server)
            
            let count = Int(truncating: snapshot.count)
            print("[FirebaseManager] Online users count from Firestore: \(count)")
            
            // Update RTDB with the count
            try await updateOnlineUsersInRTDB(count)
            
            return count
        } catch {
            print("[FirebaseManager] Error getting online users count: \(error)")
            return 0
        }
    }
    
    func getTotalPlayersCount() async throws -> Int {
        print("[FirebaseManager] Getting total players count")
        do {
            let snapshot = try await db.collection("users").count.getAggregation(source: .server)
            let count = Int(truncating: snapshot.count)
            print("[FirebaseManager] Total players count: \(count)")
            return count
        } catch {
            print("[FirebaseManager] Error getting total players count: \(error)")
            return 0
        }
    }
    
    private func updateOnlineUsersInRTDB(_ count: Int) async throws {
        print("[FirebaseManager] Updating online users count in RTDB: \(count)")
        // Get all users who have been active in the last 15 minutes
        let fifteenMinutesAgo = Timestamp(date: Date().addingTimeInterval(-900))
        let snapshot = try await db.collection("users")
            .whereField("lastActive", isGreaterThan: fifteenMinutesAgo)
            .getDocuments()
        
        // Create a dictionary of online users
        var onlineUsers: [String: Bool] = [:]
        for document in snapshot.documents {
            onlineUsers[document.documentID] = true
        }
        
        // Update RTDB
        try await rtdb.child("online_users").setValue(onlineUsers)
    }
    
    // MARK: - Leaderboard
    
    func submitScore(_ score: Int, level: Int? = nil, time: TimeInterval? = nil, type: LeaderboardType = .score) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Firebase] ❌ No authenticated user found")
            throw FirebaseError.notAuthenticated
        }
        
        // Get username from Firestore
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let username = userDoc.data()?["username"] as? String else {
            print("[Firebase] ❌ No username found for user: \(userId)")
            throw FirebaseError.invalidData
        }
        
        print("[Firebase] 📊 Submitting score: \(score) for user: \(userId)")
        
        // Get current time in UTC
        let now = Date()
        let calendar = Calendar.current
        
        // Define period boundaries
        let periods: [(name: String, startDate: Date)] = [
            ("daily", calendar.startOfDay(for: now)),
            ("weekly", calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!),
            ("monthly", calendar.date(from: calendar.dateComponents([.year, .month], from: now))!),
            ("alltime", Date.distantPast)
        ]
        
        for (period, startDate) in periods {
            do {
                print("[Firebase] 🔄 Attempting to update \(period) leaderboard for user \(userId)")
                
                let docRef = db.collection(type.collectionName)
                    .document(period)
                    .collection("scores")
                    .document(userId)
                
                let snapshot = try await docRef.getDocument()
                let currentScore = snapshot.data()?["score"] as? Int ?? 0
                
                // For achievement leaderboard, always update
                // For other leaderboards, update if no score exists or new score is higher
                let shouldUpdate = type == .achievement || 
                                 currentScore == 0 || 
                                 score > currentScore ||
                                 (type == .timed && time != nil && (currentScore == 0 || time! < TimeInterval(currentScore)))
                
                // Always write to daily and weekly if the score is from today/this week
                let isToday = calendar.isDateInToday(startDate)
                let isThisWeek = calendar.isDate(startDate, equalTo: now, toGranularity: .weekOfYear)
                
                if shouldUpdate || isToday || isThisWeek {
                    // Include all required fields with UTC timestamp
                    var data: [String: Any] = [
                        "username": username,
                        "score": score,
                        "timestamp": FieldValue.serverTimestamp(),
                        "lastUpdate": FieldValue.serverTimestamp(),
                        "userId": userId,
                        "periodStart": FieldValue.serverTimestamp()
                    ]
                    
                    if let level = level {
                        data["level"] = level
                    }
                    
                    if let time = time {
                        data["time"] = time
                    }
                    
                    print("[Firebase] 📝 Writing data to Firestore: \(data)")
                    print("[Firebase] 📝 Writing to path: \(type.collectionName)/\(period)/scores/\(userId)")
                    
                    try await docRef.setData(data)
                    print("[Firebase] ✅ Successfully updated \(period) leaderboard")
                    
                    // Invalidate cache for this leaderboard
                    LeaderboardCache.shared.invalidateCache(type: type, period: period)
                } else {
                    print("[Firebase] ⏭️ Skipping \(period) update - Score not better (Current: \(currentScore), New: \(score))")
                }
                
            } catch {
                print("[Firebase] ❌ Error updating \(period) leaderboard: \(error.localizedDescription)")
                print("[Firebase] ❌ Error details: \(error)")
                throw FirebaseError.updateFailed(error)
            }
        }
        
        print("[Firebase] ✅ Successfully submitted all scores")
    }
    
    func submitTimedScore(_ score: Int, level: Int? = nil, time: TimeInterval? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Firebase] ❌ No authenticated user found")
            throw FirebaseError.notAuthenticated
        }
        
        // Get username from Firestore
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let username = userDoc.data()?["username"] as? String else {
            print("[Firebase] ❌ No username found for user: \(userId)")
            throw FirebaseError.invalidData
        }
        
        // Use all periods
        let periods = ["daily", "weekly", "monthly", "alltime"]
        
        for period in periods {
            do {
                print("[Firebase] 🔄 Attempting to update \(period) leaderboard for user \(userId)")
                
                let docRef = db.collection("classic_timed_leaderboard")
                    .document(period)
                    .collection("scores")
                    .document(userId)
                
                let snapshot = try await docRef.getDocument()
                let currentScore = snapshot.data()?["score"] as? Int ?? 0
                
                if score <= currentScore {
                    print("[Firebase] ⏭️ Skipping \(period) update - Score not better")
                    continue
                }
                
                // Include all required fields
                var data: [String: Any] = [
                    "username": username,
                    "score": score,
                    "timestamp": FieldValue.serverTimestamp(),
                    "lastUpdate": FieldValue.serverTimestamp(),
                    "userId": userId
                ]
                
                if let level = level {
                    data["level"] = level
                }
                
                if let time = time {
                    data["time"] = time
                }
                
                print("[Firebase] 📝 Writing data to Firestore: \(data)")
                
                try await docRef.setData(data)
                print("[Firebase] ✅ Successfully updated \(period) leaderboard")
                
            } catch {
                print("[Firebase] ❌ Error updating \(period) leaderboard: \(error.localizedDescription)")
                print("[Firebase] ❌ Error details: \(error)")
                throw FirebaseError.updateFailed(error)
            }
        }
    }
    
    // Add function to submit achievement score
    func submitAchievementScore(_ score: Int, achievementId: String) async throws {
        guard let userId = currentUser?.uid,
              let username = username else { 
            throw FirebaseError.notAuthenticated 
        }
        
        try validateUserId(userId)
        
        // Submit to Firestore using LeaderboardService
        try await LeaderboardService.shared.updateLeaderboard(
            score: score,
            type: .achievement,
            username: username  // Pass the username to the updateLeaderboard function
        )
        print("[FirebaseManager] ✅ Successfully submitted achievement score for user: \(userId)")
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
                id: document.documentID,
                username: username,
                score: score,
                timestamp: timestamp,
                level: document.data()["level"] as? Int,
                time: document.data()["time"] as? TimeInterval
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
            
            // Create progress object with personal high score and highest level
            let progress = GameProgress(
                score: data["score"] as? Int ?? 0,
                level: data["level"] as? Int ?? 1,
                blocksPlaced: data["blocksPlaced"] as? Int ?? 0,
                linesCleared: data["linesCleared"] as? Int ?? 0,
                gamesCompleted: data["gamesCompleted"] as? Int ?? 0,
                perfectLevels: data["perfectLevels"] as? Int ?? 0,
                totalPlayTime: data["totalPlayTime"] as? Double ?? 0,
                highScore: data["personalHighScore"] as? Int ?? 0,  // Changed from highScore to personalHighScore
                highestLevel: data["personalHighestLevel"] as? Int ?? 1,  // Changed from highestLevel to personalHighestLevel
                grid: data["grid"] as? [[String]] ?? Array(repeating: Array(repeating: "nil", count: GameConstants.gridSize), count: GameConstants.gridSize),
                tray: [],  // Tray is not stored in Firebase
                lastSaveTime: (data["lastSaveTime"] as? Timestamp)?.dateValue() ?? Date()
            )
            
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
        
        // Ensure we're using the correct keys for personal high score and highest level
        progressData["personalHighScore"] = progress.highScore
        progressData["personalHighestLevel"] = progress.highestLevel
        
        // Save to Firestore
        let firestoreRef = db.collection("users").document(userId)
            .collection("progress")
            .document("data")
        try await firestoreRef.setData(progressData, merge: true)
        
        // Save to RTDB for real-time sync
        let rtdbRef = rtdb.child("users").child(userId)
            .child("progress")
            .child("data")
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
                
                // Update UserDefaults with personal high score and highest level
                UserDefaults.standard.set(cloudProgress.highScore, forKey: "personalHighScore")
                UserDefaults.standard.set(cloudProgress.highestLevel, forKey: "personalHighestLevel")
                UserDefaults.standard.set(cloudProgress.lastSaveTime, forKey: "lastSaveTime")
                UserDefaults.standard.synchronize()
            }
        } else {
            // No local data, use cloud data
            cacheGameProgress(cloudProgress)
            cachedProgress = cloudProgress
            
            // Update UserDefaults with personal high score and highest level
            UserDefaults.standard.set(cloudProgress.highScore, forKey: "personalHighScore")
            UserDefaults.standard.set(cloudProgress.highestLevel, forKey: "personalHighestLevel")
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
        
        // Get existing document to check if it's a new user
        let existingDoc = try await userRef.getDocument()
        let isNewUser = !existingDoc.exists
        
        // Base user data
        var userData: [String: Any] = [
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "lastLogin": FieldValue.serverTimestamp(),
            "lastActive": FieldValue.serverTimestamp(),
            "createdAt": isNewUser ? FieldValue.serverTimestamp() : (existingDoc.data()?["createdAt"] as? Timestamp ?? FieldValue.serverTimestamp()),
            "userId": userId,
            "deviceId": generateDeviceId(),
            "referralCode": existingDoc.data()?["referralCode"] as? String ?? generateReferralCode(),
            "version": 1
        ]
        
        // If new user, add default game progress fields
        if isNewUser {
            userData.merge([
                "blocksPlaced": 0,
                "gamesCompleted": 0,
                "gridSize": 10,
                "highScore": 0,
                "highestLevel": 1,
                "level": 1,
                "linesCleared": 0,
                "perfectLevels": 0,
                "score": 0,
                "totalPlayTime": 0,
                "lastSaveTime": FieldValue.serverTimestamp(),
                "lastUpdated": FieldValue.serverTimestamp()
            ]) { current, _ in current }
        }
        
        try await userRef.setData(userData, merge: true)
        
        // Create progress subcollection for new users
        if isNewUser {
            let progressData: [String: Any] = [
                "blocksPlaced": 0,
                "gamesCompleted": 0,
                "gridSize": 10,
                "highScore": 0,
                "highestLevel": 1,
                "level": 1,
                "linesCleared": 0,
                "perfectLevels": 0,
                "score": 0,
                "totalPlayTime": 0,
                "lastSaveTime": FieldValue.serverTimestamp(),
                "lastUpdated": FieldValue.serverTimestamp()
            ]
            
            try await userRef.collection("progress").document("data").setData(progressData)
        }
        
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

    func saveLeaderboardEntry(_ entry: LeaderboardEntry, type: LeaderboardType, period: String) async throws {
        let db = Firestore.firestore()
        
        var data: [String: Any] = [
            "username": entry.username,
            type.scoreField: entry.score,
            "timestamp": entry.timestamp
        ]
        
        if let level = entry.level {
            data["level"] = level
        }
        
        if let time = entry.time {
            data["time"] = time
        }
        
        try await db.collection(type.collectionName)
            .document(period)
            .collection("scores")
            .document(entry.id)
            .setData(data)
    }
    
    func getLeaderboardEntries(type: LeaderboardType, period: String) async throws -> [LeaderboardEntry] {
        print("[FirebaseManager] 🔄 Getting leaderboard entries for type: \(type), period: \(period)")
        
        // Get the collection name based on type
        let collectionName = type.collectionName
        print("[FirebaseManager] 📁 Using collection: \(collectionName)")
        
        // Get the score field based on type
        let scoreField = type.scoreField
        print("[FirebaseManager] 📊 Using score field: \(scoreField)")
        
        // Get the sort order based on type
        let sortOrder = type.sortOrder
        print("[FirebaseManager] 🔄 Using sort order: \(sortOrder)")
        
        // Calculate date filter
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        var filterDate: Date?
        
        switch period {
        case "daily":
            filterDate = startOfDay
        case "weekly":
            filterDate = calendar.date(byAdding: .day, value: -7, to: startOfDay)
        case "monthly":
            filterDate = calendar.date(byAdding: .month, value: -1, to: startOfDay)
        case "alltime":
            filterDate = nil
        default:
            filterDate = startOfDay
        }
        
        if let filterDate = filterDate {
            print("[FirebaseManager] 📅 Filtering from date: \(filterDate)")
        }
        
        // Get the entries
        var query = db.collection(collectionName)
            .document(period)
            .collection("scores")
            .order(by: scoreField, descending: sortOrder == "desc")
            .limit(to: 20)
        
        if let filterDate = filterDate {
            query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: filterDate))
        }
        
        print("[FirebaseManager] 🔍 Executing query")
        let snapshot = try await query.getDocuments()
        print("[FirebaseManager] 📊 Retrieved \(snapshot.documents.count) entries")
        
        // Parse the entries
        let entries = snapshot.documents.compactMap { document -> LeaderboardEntry? in
            let data = document.data()
            print("[FirebaseManager] 📄 Processing document: \(document.documentID)")
            print("[FirebaseManager] 📄 Document data: \(data)")
            
            guard let username = data["username"] as? String else {
                print("[FirebaseManager] ⚠️ Missing username in document")
                return nil
            }
            
            guard let score = data[scoreField] as? Int else {
                print("[FirebaseManager] ⚠️ Missing score in document")
                return nil
            }
            
            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let level = data["level"] as? Int
            let time = data["time"] as? TimeInterval
            let documentUserId = data["userId"] as? String ?? document.documentID
            
            let entry = LeaderboardEntry(
                id: documentUserId,
                username: username,
                score: score,
                timestamp: timestamp,
                level: level,
                time: time
            )
            
            print("[FirebaseManager] ✅ Successfully parsed entry: \(entry.username) - \(entry.score)")
            return entry
        }
        
        print("[FirebaseManager] 📊 Successfully parsed \(entries.count) entries")
        return entries
    }
    
    private func refreshAppCheckToken() async {
        do {
            let token = try await AppCheck.appCheck().token(forcingRefresh: true)
            appCheckToken = token.token
            print("[FirebaseManager] Successfully obtained new App Check token")
            
            // Set up token refresh
            Task {
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 30 minutes
                await refreshAppCheckToken()
            }
        } catch {
            print("[FirebaseManager] Failed to get App Check token: \(error)")
            // Retry after a short delay
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
            await refreshAppCheckToken()
        }
    }

    // MARK: - Account Management
    
    func mergeAccounts(gameCenterId: String, emailId: String) async throws {
        print("[FirebaseManager] Starting account merge between Game Center ID: \(gameCenterId) and Email ID: \(emailId)")
        
        // Get data from both accounts
        let gameCenterDoc = try await db.collection("users").document(gameCenterId).getDocument()
        let emailDoc = try await db.collection("users").document(emailId).getDocument()
        
        guard let gameCenterData = gameCenterDoc.data(),
              let emailData = emailDoc.data() else {
            throw FirebaseError.invalidData
        }
        
        // Get progress data from both accounts
        let gameCenterProgress = try await db.collection("users").document(gameCenterId).collection("progress").document("data").getDocument()
        let emailProgress = try await db.collection("users").document(emailId).collection("progress").document("data").getDocument()
        
        // Merge progress data, taking the highest values
        let mergedProgress: [String: Any] = [
            "score": max(gameCenterProgress.data()?["score"] as? Int ?? 0, emailProgress.data()?["score"] as? Int ?? 0),
            "level": max(gameCenterProgress.data()?["level"] as? Int ?? 1, emailProgress.data()?["level"] as? Int ?? 1),
            "blocksPlaced": max(gameCenterProgress.data()?["blocksPlaced"] as? Int ?? 0, emailProgress.data()?["blocksPlaced"] as? Int ?? 0),
            "linesCleared": max(gameCenterProgress.data()?["linesCleared"] as? Int ?? 0, emailProgress.data()?["linesCleared"] as? Int ?? 0),
            "gamesCompleted": max(gameCenterProgress.data()?["gamesCompleted"] as? Int ?? 0, emailProgress.data()?["gamesCompleted"] as? Int ?? 0),
            "perfectLevels": max(gameCenterProgress.data()?["perfectLevels"] as? Int ?? 0, emailProgress.data()?["perfectLevels"] as? Int ?? 0),
            "totalPlayTime": max(gameCenterProgress.data()?["totalPlayTime"] as? Double ?? 0, emailProgress.data()?["totalPlayTime"] as? Double ?? 0),
            "highScore": max(gameCenterProgress.data()?["highScore"] as? Int ?? 0, emailProgress.data()?["highScore"] as? Int ?? 0),
            "highestLevel": max(gameCenterProgress.data()?["highestLevel"] as? Int ?? 1, emailProgress.data()?["highestLevel"] as? Int ?? 1),
            "lastSaveTime": FieldValue.serverTimestamp()
        ]
        
        // Merge user data, preferring email account data for non-game stats
        let gameCenterTimestamp = gameCenterData["createdAt"] as? Timestamp
        let emailTimestamp = emailData["createdAt"] as? Timestamp
        let createdAt: Timestamp = {
            if let gcDate = gameCenterTimestamp?.dateValue(),
               let emailDate = emailTimestamp?.dateValue() {
                return gcDate.compare(emailDate) == .orderedAscending ? gameCenterTimestamp! : emailTimestamp!
            }
            return gameCenterTimestamp ?? emailTimestamp ?? Timestamp()
        }()
        
        let mergedUserData: [String: Any] = [
            "username": emailData["username"] as? String ?? gameCenterData["username"] as? String ?? "",
            "email": emailData["email"] as? String ?? "",
            "gameCenterId": gameCenterId,
            "lastActive": FieldValue.serverTimestamp(),
            "createdAt": createdAt as Any,
            "lastLogin": FieldValue.serverTimestamp()
        ]
        
        // Update the email account with merged data
        try await db.collection("users").document(emailId).setData(mergedUserData, merge: true)
        try await db.collection("users").document(emailId).collection("progress").document("data").setData(mergedProgress)
        
        // Delete the Game Center account
        try await db.collection("users").document(gameCenterId).delete()
        
        print("[FirebaseManager] Successfully merged accounts. Email account (\(emailId)) now contains merged data.")
    }

    private func handleAccountMergeIfNeeded() async throws {
        guard let currentUser = currentUser else { return }
        
        // Check if user has both Game Center and email accounts
        let gameCenterId = currentUser.providerData.first { $0.providerID == "gc.apple.com" }?.uid
        let emailId = currentUser.providerData.first { $0.providerID == "password" }?.uid
        
        if let gameCenterId = gameCenterId,
           let emailId = emailId,
           gameCenterId != emailId {
            print("[FirebaseManager] Detected multiple accounts for user. Starting merge process...")
            try await mergeAccounts(gameCenterId: gameCenterId, emailId: emailId)
        }
    }

    // Update the signIn method to handle account merging
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            currentUser = result.user
            isAuthenticated = true
            isGuest = false
            
            // Load user data
            await loadUserData(userId: result.user.uid)
            
            // Check for account merging
            try await handleAccountMergeIfNeeded()
            
            // Update last active
            await updateLastActive()
        } catch {
            print("[FirebaseManager] Error signing in: \(error)")
            throw error
        }
    }

    private func initializeLeaderboardEntries(for userId: String, username: String) async throws {
        print("[FirebaseManager] Initializing leaderboard entries for new user: \(userId)")
        
        // We no longer create initial entries with zero scores
        // Instead, we'll wait for the first actual score to be submitted
        print("[FirebaseManager] Skipping initial zero-score entries for user: \(userId)")
    }

    func signUpWithEmail(email: String, password: String, username: String) async throws {
        do {
            print("[FirebaseManager] Starting email sign up...")
            let result = try await auth.createUser(withEmail: email, password: password)
            let user = result.user
            
            // Update profile with username
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = username
            try await changeRequest.commitChanges()
            
            // Save user data to Firestore
            let userData: [String: Any] = [
                "username": username,
                "email": email,
                "timestamp": FieldValue.serverTimestamp(),
                "lastUsernameChange": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(user.uid).setData(userData)
            
            // Initialize leaderboard entries
            try await initializeLeaderboardEntries(for: user.uid, username: username)
            
            self.currentUser = user
            self.username = username
            self.isGuest = false
            
            print("[FirebaseManager] Email sign up successful for user: \(user.uid)")
        } catch {
            print("[FirebaseManager] Error during email sign up: \(error)")
            throw error
        }
    }

    func signInWithGameCenter() async throws {
        do {
            print("[FirebaseManager] Starting Game Center sign in...")
            let credential = try await GameCenterAuthProvider.getCredential()
            let result = try await auth.signIn(with: credential)
            let user = result.user
            
            // Get Game Center player info
            let localPlayer = GKLocalPlayer.local
            let gameCenterUsername = localPlayer.displayName
            
            // Check if this is a new user
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            
            if !userDoc.exists {
                print("[FirebaseManager] New Game Center user detected, creating user profile...")
                
                // Create user profile
                let userData: [String: Any] = [
                    "username": gameCenterUsername,
                    "gameCenterId": localPlayer.gamePlayerID,
                    "timestamp": FieldValue.serverTimestamp(),
                    "lastUsernameChange": FieldValue.serverTimestamp()
                ]
                
                try await db.collection("users").document(user.uid).setData(userData)
                
                // Initialize leaderboard entries
                try await initializeLeaderboardEntries(for: user.uid, username: gameCenterUsername)
            } else {
                // Update existing user's Game Center info
                try await db.collection("users").document(user.uid).updateData([
                    "gameCenterId": localPlayer.gamePlayerID,
                    "lastLogin": FieldValue.serverTimestamp()
                ])
            }
            
            self.currentUser = user
            self.username = gameCenterUsername
            self.isGuest = false
            
            print("[FirebaseManager] Game Center sign in successful for user: \(user.uid)")
        } catch {
            print("[FirebaseManager] Error during Game Center sign in: \(error)")
            throw error
        }
    }

    func clearGameProgress() async throws {
        guard let userId = currentUser?.uid else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        do {
            // Clear progress document
            let progressData: [String: Any] = [
                "blocksPlaced": 0,
                "gamesCompleted": 0,
                "gridSize": 10,
                "highScore": 0,
                "highestLevel": 1,
                "level": 1,
                "linesCleared": 0,
                "perfectLevels": 0,
                "score": 0,
                "totalPlayTime": 0,
                "lastSaveTime": FieldValue.serverTimestamp(),
                "lastUpdated": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(userId).collection("progress").document("data").setData(progressData)
            print("[FirebaseManager] Successfully cleared game progress")
        } catch {
            print("[FirebaseManager] Error clearing game progress: \(error)")
            throw error
        }
    }
}

// MARK: - Models

extension FirebaseManager {
    struct LeaderboardEntry: Identifiable, Codable {
        let id: String
        let username: String
        let score: Int
        let timestamp: Date
        let level: Int?
        let time: TimeInterval?
        
        init(id: String, username: String, score: Int, timestamp: Date, level: Int? = nil, time: TimeInterval? = nil) {
            self.id = id
            self.username = username
            self.score = score
            self.timestamp = timestamp
            self.level = level
            self.time = time
        }
    }
    
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
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
