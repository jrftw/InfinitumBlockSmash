/*
 * FILE: GameDataVersion.swift
 * PURPOSE: Manages game data versioning and migration
 * DEPENDENCIES: None
 * AUTHOR: @jrftw
 * LAST UPDATED: 6/19/2025
 */

import Foundation

// MARK: - GameDataVersion
struct GameDataVersion {
    static let currentVersion = 1
    
    static func migrateIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(forKey: "gameDataVersion")
        
        if savedVersion < currentVersion {
            // Perform migrations based on version
            if savedVersion < 1 {
                // Initial version, no migration needed
            }
            
            // Update version after migration
            UserDefaults.standard.set(currentVersion, forKey: "gameDataVersion")
            UserDefaults.standard.synchronize()
        }
    }
    
    static func validateData(_ data: [String: Any]) -> Bool {
        // Add validation logic here
        guard let version = data["version"] as? Int else { return false }
        return version <= currentVersion
    }
} 