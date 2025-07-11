import Foundation
import FirebaseFirestore
import FirebaseAuth

class ReferralManager: ObservableObject {
    static let shared = ReferralManager()
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    @Published var referralCode: String = ""
    @Published var adFreeTimeRemaining: TimeInterval = 0
    @Published var totalReferrals: Int = 0
    
    private let adFreeTimePerReferral: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
    
    private init() {
        // Set up auth state listener
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            if let userID = user?.uid {
                self?.loadUserReferralData(userID: userID)
            } else {
                // Reset data when user signs out
                self?.referralCode = ""
                self?.adFreeTimeRemaining = 0
                self?.totalReferrals = 0
            }
        }
    }
    
    deinit {
        // Remove the auth state listener when the manager is deallocated
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func generateReferralCode() -> String {
        // Generate a random 6-character alphanumeric code
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    func loadUserReferralData(userID: String) {
        print("Loading referral data for user: \(userID)")
        db.collection("users").document(userID).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading referral data: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                let data = document.data()
                if let existingCode = data?["referralCode"] as? String {
                    // Use existing code
                    print("Found existing referral code: \(existingCode)")
                    self.referralCode = existingCode
                } else {
                    // Generate and save new code only if one doesn't exist
                    let newCode = self.generateReferralCode()
                    print("Generated new referral code: \(newCode)")
                    self.referralCode = newCode
                    self.saveUserReferralData(userID: userID)
                }
                
                self.totalReferrals = data?["totalReferrals"] as? Int ?? 0
                
                // Calculate remaining ad-free time
                if let adFreeUntil = data?["adFreeUntil"] as? Timestamp {
                    let remaining = adFreeUntil.dateValue().timeIntervalSinceNow
                    self.adFreeTimeRemaining = max(0, remaining)
                }
            } else {
                // Document doesn't exist, create new referral data
                let newCode = self.generateReferralCode()
                print("Created new user with referral code: \(newCode)")
                self.referralCode = newCode
                self.saveUserReferralData(userID: userID)
            }
        }
    }
    
    func saveUserReferralData(userID: String) {
        let data: [String: Any] = [
            "referralCode": referralCode,
            "totalReferrals": totalReferrals,
            "adFreeUntil": Timestamp(date: Date().addingTimeInterval(adFreeTimeRemaining))
        ]
        
        db.collection("users").document(userID).setData(data, merge: true) { error in
            if let error = error {
                print("Error saving referral data: \(error.localizedDescription)")
            } else {
                print("Successfully saved referral data for user: \(userID)")
            }
        }
    }
    
    func applyReferralCode(_ code: String, forUserID userID: String) async throws {
        // Check if this device has already used a referral code
        if try await DeviceManager.shared.hasUsedReferralCode() {
            throw NSError(domain: "ReferralError", code: 3, userInfo: [NSLocalizedDescriptionKey: "This device has already used a referral code"])
        }
        
        // Find user with this referral code
        let querySnapshot = try await db.collection("users")
            .whereField("referralCode", isEqualTo: code)
            .getDocuments()
        
        guard let referrerDoc = querySnapshot.documents.first else {
            throw NSError(domain: "ReferralError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid referral code"])
        }
        
        let referrerID = referrerDoc.documentID
        
        // Don't allow self-referral
        guard referrerID != userID else {
            throw NSError(domain: "ReferralError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot use your own referral code"])
        }
        
        // Update referrer's data
        let referrerData = referrerDoc.data()
        let currentAdFreeUntil = referrerData["adFreeUntil"] as? Timestamp ?? Timestamp(date: Date())
        let newAdFreeUntil = Timestamp(date: currentAdFreeUntil.dateValue().addingTimeInterval(self.adFreeTimePerReferral))
        let totalReferrals = (referrerData["totalReferrals"] as? Int ?? 0) + 1
        
        try await db.collection("users").document(referrerID).updateData([
            "adFreeUntil": newAdFreeUntil,
            "totalReferrals": totalReferrals
        ])
        
        // Update referred user's data
        try await db.collection("users").document(userID).updateData([
            "adFreeUntil": newAdFreeUntil,
            "referredBy": referrerID
        ])
        
        // Mark that this device has used a referral code
        try await DeviceManager.shared.markReferralCodeUsed()
        
        // Refresh local data
        await MainActor.run {
            self.loadUserReferralData(userID: userID)
        }
    }
    
    func hasAdFreeTime() -> Bool {
        return adFreeTimeRemaining > 0
    }
    
    func getAdFreeTimeRemaining() -> String {
        let hours = Int(adFreeTimeRemaining) / 3600
        let minutes = (Int(adFreeTimeRemaining) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
} 