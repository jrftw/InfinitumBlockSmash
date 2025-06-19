import Foundation
import FirebaseFirestore
import FirebaseAuth

class ReferralMigration {
    private let db = Firestore.firestore()
    
    func migrateAllUsers() async {
        print("Starting referral code migration...")
        
        do {
            // Get all users
            let snapshot = try await db.collection("users").getDocuments()
            print("Found \(snapshot.documents.count) users to migrate")
            
            var successCount = 0
            var errorCount = 0
            
            // Process each user
            for document in snapshot.documents {
                let userID = document.documentID
                let data = document.data()
                
                // Skip if user already has a referral code
                if let existingCode = data["referralCode"] as? String {
                    print("User \(userID) already has referral code: \(existingCode)")
                    continue
                }
                
                // Generate new referral code
                let newCode = generateReferralCode()
                
                // Update user document
                do {
                    let updateData: [String: Any] = [
                        "referralCode": newCode,
                        "totalReferrals": data["totalReferrals"] as? Int ?? 0,
                        "adFreeUntil": data["adFreeUntil"] as? Timestamp ?? Timestamp(date: Date())
                    ]
                    
                    try await db.collection("users").document(userID).updateData(updateData)
                    print("Successfully set referral code \(newCode) for user \(userID)")
                    successCount += 1
                } catch {
                    print("Error updating user \(userID): \(error.localizedDescription)")
                    errorCount += 1
                }
            }
            
            print("Migration completed:")
            print("- Successfully migrated: \(successCount) users")
            print("- Errors encountered: \(errorCount) users")
            print("- Skipped (already had codes): \(snapshot.documents.count - successCount - errorCount) users")
            
        } catch {
            print("Error fetching users: \(error.localizedDescription)")
        }
    }
    
    private func generateReferralCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

// Usage:
// let migration = ReferralMigration()
// Task {
//     await migration.migrateAllUsers()
// } 