import Foundation
import FirebaseFirestore
import FirebaseAuth

class BackupService {
    private let db = Firestore.firestore()
    private let backupQueue = DispatchQueue(label: "com.infinitum.backup", qos: .background)
    
    // Backup frequency in hours
    private let backupFrequency: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // Maximum number of backups to keep
    private let maxBackups = 7 // Keep 1 week of daily backups
    
    func scheduleBackups() {
        // Schedule daily backup
        Timer.scheduledTimer(withTimeInterval: backupFrequency, repeats: true) { [weak self] _ in
            self?.performBackup()
        }
    }
    
    private func performBackup() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        backupQueue.async { [weak self] in
            self?.backupUserData(userId: userId)
        }
    }
    
    private func backupUserData(userId: String) {
        let backupRef = db.collection("backups").document(userId)
        let timestamp = Date()
        
        // Create backup document
        let backupData: [String: Any] = [
            "timestamp": timestamp,
            "status": "in_progress"
        ]
        
        backupRef.setData(backupData) { [weak self] error in
            if let error = error {
                print("Error creating backup: \(error)")
                return
            }
            
            // Backup user profile
            self?.backupUserProfile(userId: userId, backupRef: backupRef)
            
            // Backup game progress
            self?.backupGameProgress(userId: userId, backupRef: backupRef)
            
            // Backup achievements
            self?.backupAchievements(userId: userId, backupRef: backupRef)
            
            // Backup settings
            self?.backupSettings(userId: userId, backupRef: backupRef)
            
            // Update backup status
            backupRef.updateData([
                "status": "completed",
                "completedAt": Date()
            ])
            
            // Clean up old backups
            self?.cleanupOldBackups(userId: userId)
        }
    }
    
    private func backupUserProfile(userId: String, backupRef: DocumentReference) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                backupRef.collection("profile").document("data").setData(document.data() ?? [:])
            }
        }
    }
    
    private func backupGameProgress(userId: String, backupRef: DocumentReference) {
        let progressRef = db.collection("users").document(userId).collection("progress")
        
        progressRef.getDocuments { (snapshot, error) in
            if let documents = snapshot?.documents {
                for document in documents {
                    backupRef.collection("progress").document(document.documentID).setData(document.data())
                }
            }
        }
    }
    
    private func backupAchievements(userId: String, backupRef: DocumentReference) {
        let achievementsRef = db.collection("users").document(userId).collection("achievements")
        
        achievementsRef.getDocuments { (snapshot, error) in
            if let documents = snapshot?.documents {
                for document in documents {
                    backupRef.collection("achievements").document(document.documentID).setData(document.data())
                }
            }
        }
    }
    
    private func backupSettings(userId: String, backupRef: DocumentReference) {
        let settingsRef = db.collection("settings").document(userId)
        
        settingsRef.getDocument { (document, error) in
            if let document = document, document.exists {
                backupRef.collection("settings").document("data").setData(document.data() ?? [:])
            }
        }
    }
    
    private func cleanupOldBackups(userId: String) {
        let backupsRef = db.collection("backups").document(userId)
        
        backupsRef.collection("backups")
            .order(by: "timestamp", descending: true)
            .limit(to: self.maxBackups)
            .getDocuments { [weak self] (snapshot, error) in
                if let documents = snapshot?.documents,
                   let maxBackups = self?.maxBackups {
                    let oldBackups = documents[maxBackups...]
                    for document in oldBackups {
                        document.reference.delete()
                    }
                }
            }
    }
    
    // Restore from backup
    func restoreFromBackup(backupId: String, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "BackupService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        let backupRef = db.collection("backups").document(userId).collection("backups").document(backupId)
        
        backupRef.getDocument { [weak self] (document, error) in
            if let error = error {
                completion(error)
                return
            }
            
            guard let document = document, document.exists else {
                completion(NSError(domain: "BackupService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Backup not found"]))
                return
            }
            
            self?.restoreUserData(from: backupRef, completion: completion)
        }
    }
    
    private func restoreUserData(from backupRef: DocumentReference, completion: @escaping (Error?) -> Void) {
        let group = DispatchGroup()
        var restoreError: Error?
        
        // Restore profile
        group.enter()
        backupRef.collection("profile").document("data").getDocument { (document, error) in
            if let document = document, document.exists {
                self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "").setData(document.data() ?? [:])
            }
            if let error = error {
                restoreError = error
            }
            group.leave()
        }
        
        // Restore progress
        group.enter()
        backupRef.collection("progress").getDocuments { (snapshot, error) in
            if let documents = snapshot?.documents {
                for document in documents {
                    self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "").collection("progress").document(document.documentID).setData(document.data())
                }
            }
            if let error = error {
                restoreError = error
            }
            group.leave()
        }
        
        // Restore achievements
        group.enter()
        backupRef.collection("achievements").getDocuments { (snapshot, error) in
            if let documents = snapshot?.documents {
                for document in documents {
                    self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "").collection("achievements").document(document.documentID).setData(document.data())
                }
            }
            if let error = error {
                restoreError = error
            }
            group.leave()
        }
        
        // Restore settings
        group.enter()
        backupRef.collection("settings").document("data").getDocument { (document, error) in
            if let document = document, document.exists {
                self.db.collection("settings").document(Auth.auth().currentUser?.uid ?? "").setData(document.data() ?? [:])
            }
            if let error = error {
                restoreError = error
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(restoreError)
        }
    }
} 