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
        // Base difficulty increases with level
        let baseMultiplier = 1.0 + (Double(level) * 0.01)
        
        // Adjust based on player performance
        let performanceMultiplier = calculatePerformanceMultiplier()
        
        // Create adjusted settings
        var adjustedSettings = difficultySettings
        adjustedSettings.shapeComplexityMultiplier *= baseMultiplier * performanceMultiplier
        adjustedSettings.randomShapeSpawnRate = min(0.5, baseMultiplier * performanceMultiplier * 0.1)
        adjustedSettings.timeLimitMultiplier = max(0.5, 2.0 - (baseMultiplier * performanceMultiplier))
        adjustedSettings.scoreRequirementMultiplier = baseMultiplier * performanceMultiplier
        adjustedSettings.chainBonusMultiplier = 1.0 + (performanceMultiplier * 0.5)
        adjustedSettings.mistakePenaltyMultiplier = 1.0 + (baseMultiplier * 0.2)
        
        return adjustedSettings
    }
    
    // MARK: - Private Methods
    private func calculatePerformanceScore() -> Double {
        let scoreWeight = 0.3
        let timeWeight = 0.2
        let chainWeight = 0.2
        let efficiencyWeight = 0.3
        
        let scoreComponent = min(1.0, playerStats.averageScorePerLevel / 10000.0)
        let timeComponent = min(1.0, playerStats.averageTimePerLevel / 300.0)
        let chainComponent = min(1.0, playerStats.averageChain / 10.0)
        let efficiencyComponent = (playerStats.colorMatchingEfficiency + playerStats.shapePlacementEfficiency) / 2
        
        return (scoreComponent * scoreWeight) +
               (timeComponent * timeWeight) +
               (chainComponent * chainWeight) +
               (efficiencyComponent * efficiencyWeight)
    }
    
    private func calculatePerformanceMultiplier() -> Double {
        guard !playerStats.recentPerformance.isEmpty else { return 1.0 }
        
        let averagePerformance = playerStats.recentPerformance.reduce(0.0, +) / Double(playerStats.recentPerformance.count)
        let trend = calculatePerformanceTrend()
        
        // Adjust multiplier based on both average performance and trend
        return (averagePerformance + trend) / 2
    }
    
    private func calculatePerformanceTrend() -> Double {
        guard playerStats.recentPerformance.count >= 2 else { return 0.0 }
        
        let recent = playerStats.recentPerformance.last!
        let previous = playerStats.recentPerformance[playerStats.recentPerformance.count - 2]
        
        // Return a value between -0.2 and 0.2 based on the trend
        return (recent - previous) * 0.2
    }
    
    private func updateDifficultySettings() {
        let performanceMultiplier = calculatePerformanceMultiplier()
        
        // Adjust settings based on performance
        difficultySettings.shapeComplexityMultiplier = 1.0 + (performanceMultiplier * 0.5)
        difficultySettings.randomShapeSpawnRate = min(0.5, performanceMultiplier * 0.1)
        difficultySettings.timeLimitMultiplier = max(0.5, 2.0 - performanceMultiplier)
        difficultySettings.scoreRequirementMultiplier = 1.0 + (performanceMultiplier * 0.3)
        difficultySettings.chainBonusMultiplier = 1.0 + (performanceMultiplier * 0.2)
        difficultySettings.mistakePenaltyMultiplier = 1.0 + (performanceMultiplier * 0.1)
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