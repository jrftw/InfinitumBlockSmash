import Foundation
import FirebaseFirestore
import UIKit

class DeviceManager {
    static let shared = DeviceManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Get the device identifier
    private func getDeviceIdentifier() -> String {
        if let identifier = UIDevice.current.identifierForVendor?.uuidString {
            return identifier
        }
        return "unknown"
    }
    
    // Track a new account creation for this device
    func trackAccountCreation(userID: String) async throws {
        let deviceID = getDeviceIdentifier()
        let deviceRef = db.collection("devices").document(deviceID)
        
        // First check if this user already exists in any device
        let existingDevices = try await db.collection("devices")
            .whereField("accounts", arrayContains: userID)
            .getDocuments()
        
        // If user exists in another device, copy the referral status
        if let existingDevice = existingDevices.documents.first,
           let hasUsedReferral = existingDevice.data()["hasUsedReferral"] as? Bool {
            try await deviceRef.setData([
                "accounts": FieldValue.arrayUnion([userID]),
                "hasUsedReferral": hasUsedReferral,
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
        } else {
            // Check if user has been referred before
            let userDoc = try await db.collection("users").document(userID).getDocument()
            if let data = userDoc.data(),
               let referredBy = data["referredBy"] as? String,
               !referredBy.isEmpty {
                // User was previously referred, mark this device as having used a referral
                try await deviceRef.setData([
                    "accounts": FieldValue.arrayUnion([userID]),
                    "hasUsedReferral": true,
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
            } else {
                // New user, no previous referral
                try await deviceRef.setData([
                    "accounts": FieldValue.arrayUnion([userID]),
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
            }
        }
    }
    
    // Get all accounts associated with this device
    func getDeviceAccounts() async throws -> [String] {
        let deviceID = getDeviceIdentifier()
        let deviceDoc = try await db.collection("devices").document(deviceID).getDocument()
        
        if let data = deviceDoc.data(),
           let accounts = data["accounts"] as? [String] {
            return accounts
        }
        return []
    }
    
    // Check if this device has already used a referral code
    func hasUsedReferralCode() async throws -> Bool {
        let deviceID = getDeviceIdentifier()
        let deviceDoc = try await db.collection("devices").document(deviceID).getDocument()
        
        if let data = deviceDoc.data(),
           let hasUsedReferral = data["hasUsedReferral"] as? Bool {
            return hasUsedReferral
        }
        
        // For backwards compatibility, check if any account on this device has been referred
        let accounts = try await getDeviceAccounts()
        for accountID in accounts {
            let userDoc = try await db.collection("users").document(accountID).getDocument()
            if let data = userDoc.data(),
               let referredBy = data["referredBy"] as? String,
               !referredBy.isEmpty {
                // Found a referred account, mark this device as having used a referral
                try await markReferralCodeUsed()
                return true
            }
        }
        
        return false
    }
    
    // Mark that this device has used a referral code
    func markReferralCodeUsed() async throws {
        let deviceID = getDeviceIdentifier()
        try await db.collection("devices").document(deviceID).setData([
            "hasUsedReferral": true,
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }
} 