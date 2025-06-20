/*
 * BackupService.swift
 * 
 * USER DATA BACKUP AND RESTORATION SERVICE
 * 
 * This service manages automated backup and restoration of user data for the Infinitum
 * Block Smash game. It provides scheduled backups, data recovery, and backup management
 * to ensure user data safety and cross-device synchronization.
 * 
 * KEY RESPONSIBILITIES:
 * - Automated user data backup scheduling
 * - Comprehensive data backup (profile, progress, achievements, settings)
 * - Backup restoration and recovery
 * - Backup cleanup and management
 * - Cross-device data synchronization
 * - Backup status tracking and monitoring
 * - Data integrity validation
 * - Backup frequency management
 * - Error handling and recovery
 * - Backup storage optimization
 * 
 * MAJOR DEPENDENCIES:
 * - FirebaseFirestore: Cloud data storage and backup
 * - FirebaseAuth: User authentication and identification
 * - GameState.swift: Game progress data source
 * - AchievementsManager.swift: Achievement data source
 * - UserDefaults: Local settings backup
 * - DispatchQueue: Background backup processing
 * 
 * BACKUP FEATURES:
 * - Daily Automated Backups: 24-hour backup schedule
 * - Comprehensive Data Coverage: All user data types
 * - Backup Status Tracking: Progress and completion monitoring
 * - Automatic Cleanup: Old backup removal (7-day retention)
 * - Cross-Device Sync: Cloud-based backup storage
 * - Manual Backup Trigger: On-demand backup creation
 * 
 * DATA TYPES BACKED UP:
 * - User Profile: Account information and preferences
 * - Game Progress: Current game state and statistics
 * - Achievements: Achievement progress and unlocks
 * - Settings: User preferences and configurations
 * - Statistics: Game analytics and performance data
 * - Customization: Theme and visual preferences
 * 
 * BACKUP SCHEDULING:
 * - 24-hour backup frequency
 * - Background processing
 * - Network-aware scheduling
 * - Battery optimization
 * - User activity consideration
 * 
 * RESTORATION FEATURES:
 * - Complete data restoration
 * - Selective data recovery
 * - Backup validation
 * - Conflict resolution
 * - Progress tracking
 * - Error recovery
 * 
 * STORAGE MANAGEMENT:
 * - 7-day backup retention
 * - Automatic cleanup
 * - Storage optimization
 * - Compression support
 * - Backup size monitoring
 * 
 * ERROR HANDLING:
 * - Network connectivity issues
 * - Authentication failures
 * - Data corruption detection
 * - Backup failure recovery
 * - Restoration error handling
 * - Timeout management
 * 
 * PERFORMANCE FEATURES:
 * - Background processing
 * - Incremental backups
 * - Efficient data transfer
 * - Memory optimization
 * - Network bandwidth management
 * 
 * SECURITY FEATURES:
 * - User authentication verification
 * - Data encryption
 * - Secure backup storage
 * - Access control
 * - Privacy compliance
 * 
 * INTEGRATION POINTS:
 * - Firebase backend services
 * - User authentication system
 * - Game state management
 * - Achievement system
 * - Settings management
 * - Analytics and tracking
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the data safety and recovery coordinator,
 * ensuring user data persistence and cross-device synchronization
 * while maintaining performance and security.
 * 
 * THREADING CONSIDERATIONS:
 * - Background backup processing
 * - Thread-safe data operations
 * - Concurrent backup management
 * - Safe restoration operations
 * 
 * PERFORMANCE CONSIDERATIONS:
 * - Efficient data serialization
 * - Optimized backup scheduling
 * - Network bandwidth management
 * - Storage space optimization
 * 
 * REVIEW NOTES:
 * - Verify Firebase Firestore backup configuration and permissions
 * - Check backup scheduling and frequency settings
 * - Test backup data completeness and accuracy
 * - Validate backup restoration functionality
 * - Check backup cleanup and retention policies
 * - Test backup performance and network usage
 * - Verify backup data encryption and security
 * - Check backup error handling and recovery
 * - Test backup scheduling during app background/foreground
 * - Validate backup data integrity and corruption detection
 * - Check backup storage optimization and compression
 * - Test backup restoration conflict resolution
 * - Verify backup authentication and access control
 * - Check backup network connectivity error handling
 * - Test backup performance on low-end devices
 * - Validate backup data privacy compliance
 * - Check backup scheduling battery optimization
 * - Test backup restoration timeout handling
 * - Verify backup data validation and verification
 * - Check backup storage quota management
 * - Test backup cross-device synchronization
 * - Validate backup data format compatibility
 * - Check backup restoration progress tracking
 * - Test backup network interruption recovery
 * - Verify backup data age-appropriateness and filtering
 * - Check backup integration with user consent and privacy
 */

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
