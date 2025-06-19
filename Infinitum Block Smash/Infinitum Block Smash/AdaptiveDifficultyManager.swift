/*
 * AdaptiveDifficultyManager.swift
 * 
 * MAIN PURPOSE:
 * Manages dynamic difficulty adjustment based on player performance and statistics.
 * Analyzes player behavior and adjusts game parameters to maintain optimal challenge level.
 * Currently uses fixed difficulty settings but has infrastructure for adaptive calculations.
 * 
 * KEY FUNCTIONALITY:
 * - Tracks comprehensive player statistics (scores, times, chains, mistakes, etc.)
 * - Calculates performance metrics and trends
 * - Provides difficulty settings for shape complexity, time limits, scoring
 * - Manages random shape spawn rates based on level progression
 * - Persists player stats using UserDefaults
 * - Supports both adaptive and fixed difficulty modes
 * 
 * DEPENDENCIES:
 * - Foundation: Core framework for data structures and persistence
 * - UserDefaults: Local data storage for player statistics
 * - JSONEncoder/JSONDecoder: Data serialization for persistence
 * 
 * FILES THAT USE THIS:
 * - GameScene.swift: Likely uses difficulty settings for game mechanics
 * - GameState.swift: May reference for level progression and scoring
 * - GameView.swift: Could use for UI adjustments based on difficulty
 * 
 * FILES THIS USES EXTENSIVELY:
 * - UserDefaults: For persistent storage of player statistics
 * - Foundation framework: For data structures and time calculations
 * 
 * DATA FLOW:
 * 1. Game calls updatePlayerStats() after each level completion
 * 2. Manager calculates and stores performance metrics
 * 3. Difficulty settings are updated based on performance
 * 4. Game requests adjusted difficulty via getAdjustedDifficulty()
 * 5. Settings are applied to game mechanics and UI
 * 
 * REVIEW NOTES:
 * 
 * POTENTIAL ISSUES:
 * - All adaptive calculation methods return fixed values (1.0, 0.0) - adaptive features disabled
 * - No validation for extreme performance values that could break calculations
 * - UserDefaults key "playerStats" could conflict with other components
 * - No error handling for JSON encoding/decoding failures
 * - Performance array limited to 5 entries may not provide enough data for trends
 * - No cleanup of old/stale statistics data
 * 
 * AREAS FOR IMPROVEMENT:
 * - Implement actual adaptive difficulty calculations
 * - Add data validation and sanitization
 * - Consider using Core Data for better data management
 * - Add difficulty reset functionality
 * - Implement difficulty presets (easy, normal, hard)
 * - Add analytics for difficulty effectiveness
 * - Consider machine learning for better adaptation
 * 
 * DEPENDENCY CONCERNS:
 * - Heavy reliance on UserDefaults for data persistence
 * - No dependency injection - tightly coupled to UserDefaults
 * - Performance calculations are currently disabled
 * - No interface for external difficulty overrides
 * 
 * DATE: 6/19/2025
 * AUTHOR: @jrftw
 */

import Foundation

class AdaptiveDifficultyManager {
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private var playerStats: PlayerStats
    private var difficultySettings: DifficultySettings
    
    // MARK: - Initialization
    init() {
        self.playerStats = PlayerStats()
        self.difficultySettings = DifficultySettings()
        loadPlayerStats()
    }
    
    // MARK: - Player Stats
    struct PlayerStats {
        var averageScorePerLevel: Double = 0
        var averageTimePerLevel: TimeInterval = 0
        var perfectLevels: Int = 0
        var consecutiveDays: Int = 0
        var highestChain: Int = 0
        var averageChain: Double = 0
        var mistakeRate: Double = 0
        var quickPlacementRate: Double = 0
        var colorMatchingEfficiency: Double = 0
        var shapePlacementEfficiency: Double = 0
        var recentPerformance: [Double] = []
    }
    
    // MARK: - Difficulty Settings
    struct DifficultySettings {
        var shapeComplexityMultiplier: Double = 1.0
        var randomShapeSpawnRate: Double = 0.0
        var timeLimitMultiplier: Double = 1.0
        var scoreRequirementMultiplier: Double = 1.0
        var chainBonusMultiplier: Double = 1.0
        var mistakePenaltyMultiplier: Double = 1.0
    }
    
    // MARK: - Public Methods
    func updatePlayerStats(
        score: Int,
        level: Int,
        timeSpent: TimeInterval,
        isPerfect: Bool,
        chainCount: Int,
        mistakes: Int,
        totalMoves: Int,
        quickPlacements: Int,
        colorMatches: Int,
        totalColors: Int,
        successfulShapePlacements: Int,
        totalShapePlacements: Int
    ) {
        // Update average score
        let newScore = Double(score) / Double(level)
        playerStats.averageScorePerLevel = (playerStats.averageScorePerLevel + newScore) / 2
        
        // Update average time
        playerStats.averageTimePerLevel = (playerStats.averageTimePerLevel + timeSpent) / 2
        
        // Update perfect levels
        if isPerfect {
            playerStats.perfectLevels += 1
        }
        
        // Update chain stats
        playerStats.highestChain = max(playerStats.highestChain, chainCount)
        playerStats.averageChain = (playerStats.averageChain + Double(chainCount)) / 2
        
        // Update mistake rate
        let newMistakeRate = Double(mistakes) / Double(totalMoves)
        playerStats.mistakeRate = (playerStats.mistakeRate + newMistakeRate) / 2
        
        // Update quick placement rate
        let newQuickPlacementRate = Double(quickPlacements) / Double(totalMoves)
        playerStats.quickPlacementRate = (playerStats.quickPlacementRate + newQuickPlacementRate) / 2
        
        // Update color matching efficiency
        let newColorEfficiency = Double(colorMatches) / Double(totalColors)
        playerStats.colorMatchingEfficiency = (playerStats.colorMatchingEfficiency + newColorEfficiency) / 2
        
        // Update shape placement efficiency
        let newShapeEfficiency = Double(successfulShapePlacements) / Double(totalShapePlacements)
        playerStats.shapePlacementEfficiency = (playerStats.shapePlacementEfficiency + newShapeEfficiency) / 2
        
        // Update recent performance (last 5 levels)
        let performance = calculatePerformanceScore()
        playerStats.recentPerformance.append(performance)
        if playerStats.recentPerformance.count > 5 {
            playerStats.recentPerformance.removeFirst()
        }
        
        // Save updated stats
        savePlayerStats()
        
        // Update difficulty settings
        updateDifficultySettings()
    }
    
    func getAdjustedDifficulty(for level: Int) -> DifficultySettings {
        // Return fixed difficulty settings instead of calculated ones
        var fixedSettings = DifficultySettings()
        fixedSettings.shapeComplexityMultiplier = 1.0
        fixedSettings.timeLimitMultiplier = 1.0
        fixedSettings.scoreRequirementMultiplier = 1.0
        fixedSettings.chainBonusMultiplier = 1.0
        fixedSettings.mistakePenaltyMultiplier = 1.0
        
        // Fixed number of random shapes based on level ranges
        switch level {
        case 1...99:
            fixedSettings.randomShapeSpawnRate = 0.0 // No random shapes before level 100
        case 100...199:
            fixedSettings.randomShapeSpawnRate = 1.0 // 1 random shape
        case 200...299:
            fixedSettings.randomShapeSpawnRate = 2.0 // 2 random shapes
        default:
            fixedSettings.randomShapeSpawnRate = 3.0 // 3 random shapes for level 300+
        }
        
        return fixedSettings
    }
    
    // MARK: - Private Methods
    private func calculatePerformanceScore() -> Double {
        return 1.0 // Return fixed value
    }
    
    private func calculatePerformanceMultiplier() -> Double {
        return 1.0 // Return fixed value
    }
    
    private func calculatePerformanceTrend() -> Double {
        return 0.0 // Return fixed value
    }
    
    private func updateDifficultySettings() {
        // Set fixed difficulty settings
        difficultySettings.shapeComplexityMultiplier = 1.0
        difficultySettings.randomShapeSpawnRate = 0.0
        difficultySettings.timeLimitMultiplier = 1.0
        difficultySettings.scoreRequirementMultiplier = 1.0
        difficultySettings.chainBonusMultiplier = 1.0
        difficultySettings.mistakePenaltyMultiplier = 1.0
    }
    
    private func savePlayerStats() {
        if let encoded = try? JSONEncoder().encode(playerStats) {
            userDefaults.set(encoded, forKey: "playerStats")
        }
    }
    
    private func loadPlayerStats() {
        if let data = userDefaults.data(forKey: "playerStats"),
           let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            playerStats = decoded
        }
    }
}

// MARK: - Extensions
extension AdaptiveDifficultyManager.PlayerStats: Codable {}
extension AdaptiveDifficultyManager.DifficultySettings: Codable {} 