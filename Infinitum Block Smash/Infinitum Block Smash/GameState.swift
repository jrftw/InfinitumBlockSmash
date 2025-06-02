import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

protocol GameStateDelegate: AnyObject {
    func gameStateDidUpdate()
    func gameStateDidClearLines(at positions: [(Int, Int)])
    func showScoreAnimation(points: Int, at position: CGPoint)
}

class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var isGameOver: Bool = false
    @Published var grid: [[Block?]] = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
    @Published var tray: [Block] = []
    @Published var achievementsManager = AchievementsManager()
    @Published var canUndo: Bool = false
    @Published var levelComplete: Bool = false
    @Published var adUndoCount: Int = 0 // Number of ad-based undos left for current placement
    @Published var showingAchievementNotification = false
    @Published var currentAchievement: Achievement?
    @Published var blocksPlaced: Int = 0
    @Published var linesCleared: Int = 0
    @Published var gameStartTime: Date?
    @Published var lastPlayDate: Date?
    @Published var consecutiveDays: Int = 0
    @Published var currentChain: Int = 0
    @Published var usedColors: Set<BlockColor> = []
    @Published var usedShapes: Set<BlockShape> = []
    @Published var perfectLevels: Int = 0
    @Published var isPerfectLevel: Bool = true
    @Published var gamesCompleted: Int = 0
    @Published var undoCount: Int = 0
    
    // Add frame size property
    var frameSize: CGSize = .zero
    
    weak var delegate: GameStateDelegate?
    private var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
    private let traySize = 3
    
    private let userDefaults = UserDefaults.standard
    private let scoreKey = "highScore"
    private let levelKey = "highestLevel"
    private let progressKey = "gameProgress"
    
    // Undo support
    private var previousGrid: [[Block?]] = []
    private var previousTray: [Block] = []
    private var previousScore: Int = 0
    private var previousLevel: Int = 1
    
    var canAdUndo: Bool { adUndoCount > 0 }
    
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    
    init() {
        loadProgress()
        setupGame()
        gameStartTime = Date()
        loadLastPlayDate()
    }
    
    private func loadProgress() {
        // Load high score and highest level
        let highScore = userDefaults.integer(forKey: scoreKey)
        let highestLevel = userDefaults.integer(forKey: levelKey)
        
        // Load saved progress if exists
        if let savedProgress = userDefaults.dictionary(forKey: progressKey) {
            score = savedProgress["score"] as? Int ?? 0
            level = savedProgress["level"] as? Int ?? 1
            
            // Load grid state
            if let gridData = savedProgress["grid"] as? [[[String: Any]]] {
                for (row, rowData) in gridData.enumerated() {
                    for (col, cellData) in rowData.enumerated() {
                        if let colorName = cellData["color"] as? String,
                           let shapeName = cellData["shape"] as? String,
                           let color = BlockColor(rawValue: colorName),
                           let shape = BlockShape(rawValue: shapeName) {
                            grid[row][col] = Block(color: color, shape: shape)
                        }
                    }
                }
            }
            
            // Load tray state
            if let trayData = savedProgress["tray"] as? [[String: Any]] {
                tray = trayData.compactMap { blockData -> Block? in
                    guard let colorName = blockData["color"] as? String,
                          let shapeName = blockData["shape"] as? String,
                          let color = BlockColor(rawValue: colorName),
                          let shape = BlockShape(rawValue: shapeName) else {
                        return nil
                    }
                    return Block(color: color, shape: shape)
                }
            }
        }
        
        // Update achievements
        achievementsManager.updateAchievement(id: "high_score", value: highScore)
        achievementsManager.updateAchievement(id: "highest_level", value: highestLevel)
    }
    
    func saveProgress() {
        // Save high score and highest level
        if score > userDefaults.integer(forKey: scoreKey) {
            userDefaults.set(score, forKey: scoreKey)
            achievementsManager.updateAchievement(id: "high_score", value: score)
        }
        
        if level > userDefaults.integer(forKey: levelKey) {
            userDefaults.set(level, forKey: levelKey)
            achievementsManager.updateAchievement(id: "highest_level", value: level)
        }
        
        // Save current game state
        var gridData: [[[String: Any]]] = []
        for row in grid {
            var rowData: [[String: Any]] = []
            for cell in row {
                if let block = cell {
                    rowData.append([
                        "color": block.color.rawValue,
                        "shape": block.shape.rawValue
                    ])
                } else {
                    rowData.append([:])
                }
            }
            gridData.append(rowData)
        }
        
        let trayData = tray.map { block in
            [
                "color": block.color.rawValue,
                "shape": block.shape.rawValue
            ]
        }
        
        let progress: [String: Any] = [
            "score": score,
            "level": level,
            "grid": gridData,
            "tray": trayData
        ]
        
        userDefaults.set(progress, forKey: progressKey)
    }
    
    func setupGame() {
        score = 0
        level = 1
        isGameOver = false
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        setSeed(for: level)
        tray = []
        refillTray()
        delegate?.gameStateDidUpdate()
    }
    
    func resetGame() {
        score = 0
        level = 1
        isGameOver = false
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        refillTray()
        saveProgress()
        delegate?.gameStateDidUpdate()
    }
    
    func setSeed(for level: Int) {
        rng = SeededGenerator(seed: UInt64(level))
    }
    
    func nextBlockRandom() -> Block {
        let shape = BlockShape.availableShapes(for: level).randomElement(using: &rng) ?? .bar2H
        let color = BlockColor.availableColors(for: level).randomElement(using: &rng) ?? .red
        return Block(color: color, shape: shape)
    }
    
    private func refillTray() {
        // Keep 3 shapes in the tray, using nextBlockRandom for proper shape/level
        while tray.count < traySize {
            let newBlock = nextBlockRandom()
            tray.append(newBlock)
        }
        delegate?.gameStateDidUpdate()
    }
    
    func canPlaceBlockAnywhere(_ block: Block) -> Bool {
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if canPlaceBlock(block, at: CGPoint(x: col, y: row)) {
                    return true
                }
            }
        }
        return false
    }
    
    // Call this before placing a block
    private func saveStateForUndo() {
        previousGrid = grid.map { $0.map { $0 } }
        previousTray = tray.map { $0 }
        previousScore = score
        previousLevel = level
        canUndo = true
    }

    func undoLastMove() {
        guard canUndo && adUndoCount > 0 else { return }
        print("[Undo] Undoing last move. Restoring previous grid, tray, score, and level.")
        grid = previousGrid.map { $0.map { $0 } }
        tray = previousTray.map { $0 }
        score = previousScore
        level = previousLevel
        canUndo = false
        adUndoCount -= 1
        undoCount += 1
        isPerfectLevel = false
        delegate?.gameStateDidUpdate()
        checkAchievements()
    }

    // In tryPlaceBlockFromTray, save state before placement and reset undo after
    func tryPlaceBlockFromTray(_ block: Block, at anchor: CGPoint) -> Bool {
        // Don't allow placing blocks if game is over
        guard !isGameOver else { return false }
        
        guard let trayIndex = tray.firstIndex(where: { $0.id == block.id }) else { return false }
        if canPlaceBlock(block, at: anchor) {
            print("[Placement] Placing block \(block.shape.rawValue) at \(anchor)")
            saveStateForUndo()
            placeBlock(block, at: anchor)
            tray.remove(at: trayIndex)
            refillTray()
            checkMatches()
            checkGameOver()
            adUndoCount = 2 // Reset ad-based undos for this placement
            delegate?.gameStateDidUpdate()
            checkAchievements()
            return true
        }
        return false
    }
    
    private func anyTrayBlockFits() -> Bool {
        for block in tray {
            if canPlaceBlockAnywhere(block) {
                return true
            }
        }
        return false
    }
    
    func canPlaceBlock(_ block: Block, at anchor: CGPoint) -> Bool {
        // Check if any part of the shape would be outside the grid
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            
            // Check if the position is within grid bounds
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                return false
            }
            
            // Check if the position is already occupied
            if grid[y][x] != nil {
                return false
            }
        }
        
        // If we get here, the placement is valid
        return true
    }
    
    private func placeBlock(_ block: Block, at anchor: CGPoint) {
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                var placedBlock = Block(color: block.color, shape: block.shape)
                placedBlock.position = CGPoint(x: x, y: y)
                grid[y][x] = placedBlock
            }
        }
        blocksPlaced += 1
        usedColors.insert(block.color)
        usedShapes.insert(block.shape)
        isPerfectLevel = false
        checkAchievements()
    }
    
    private func checkMatches() {
        var clearedPositions: [(Int, Int)] = []
        var linesCleared = 0
        var colorMatchCount = 0
        
        // Check rows
        for row in 0..<GameConstants.gridSize {
            if isRowFull(row) {
                let rowColors = grid[row].compactMap { $0?.color }
                let allSameColor = rowColors.allSatisfy { $0 == rowColors.first }
                for col in 0..<GameConstants.gridSize {
                    clearedPositions.append((row, col))
                }
                clearRow(row)
                let position = CGPoint(x: frameSize.width/2, y: CGFloat(row) * GameConstants.blockSize)
                addScore(100, at: position)
                print("[Clear] Row \(row) cleared. +100 points.")
                if allSameColor && !rowColors.isEmpty {
                    colorMatchCount += 1
                    addScore(500, at: position) // Increased from 200 to 500 for color match
                    print("[Bonus] Row \(row) all same color (\(rowColors.first!)). +500 bonus points!")
                }
                linesCleared += 1
            }
        }
        
        // Check columns
        for col in 0..<GameConstants.gridSize {
            if isColumnFull(col) {
                let colColors = (0..<GameConstants.gridSize).compactMap { grid[$0][col]?.color }
                let allSameColor = colColors.allSatisfy { $0 == colColors.first }
                for row in 0..<GameConstants.gridSize {
                    clearedPositions.append((row, col))
                }
                clearColumn(col)
                let position = CGPoint(x: CGFloat(col) * GameConstants.blockSize, y: frameSize.height/2)
                addScore(100, at: position)
                print("[Clear] Column \(col) cleared. +100 points.")
                if allSameColor && !colColors.isEmpty {
                    colorMatchCount += 1
                    addScore(500, at: position) // Increased from 200 to 500 for color match
                    print("[Bonus] Column \(col) all same color (\(colColors.first!)). +500 bonus points!")
                }
                linesCleared += 1
            }
        }
        
        // Additional bonus for multiple color matches
        if colorMatchCount >= 2 {
            let multiMatchBonus = colorMatchCount * 1000
            addScore(multiMatchBonus, at: CGPoint(x: frameSize.width/2, y: frameSize.height/2))
            print("[Super Bonus] \(colorMatchCount) color matches! +\(multiMatchBonus) bonus points!")
        }
        
        if !clearedPositions.isEmpty {
            print("[Clear] Total lines cleared: \(linesCleared)")
            delegate?.gameStateDidClearLines(at: clearedPositions)
            achievementsManager.increment(id: "first_clear")
            if linesCleared >= 3 {
                achievementsManager.increment(id: "combo_3")
            }
            checkGroups()
        }
        
        if isGridEmpty() {
            print("[Level] Grid empty, leveling up.")
            levelUp()
        }
        
        linesCleared += linesCleared
        currentChain += 1
        checkAchievements()
    }
    
    private func isRowFull(_ row: Int) -> Bool {
        return !grid[row].contains(where: { $0 == nil })
    }
    
    private func isColumnFull(_ col: Int) -> Bool {
        return !grid.map({ $0[col] }).contains(where: { $0 == nil })
    }
    
    private func clearRow(_ row: Int) {
        grid[row] = Array(repeating: nil, count: GameConstants.gridSize)
    }
    
    private func clearColumn(_ col: Int) {
        for row in 0..<GameConstants.gridSize {
            grid[row][col] = nil
        }
    }
    
    private func isTopRowOccupied() -> Bool {
        return !grid[0].contains(where: { $0 == nil })
    }
    
    private func isGridEmpty() -> Bool {
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    return false
                }
            }
        }
        return true
    }
    
    func addScore(_ points: Int, at position: CGPoint? = nil) {
        let oldScore = score
        score += points
        print("[Score] Added \(points) points (from \(oldScore) to \(score))")
        
        // Show score animation if position is provided
        if let position = position {
            delegate?.showScoreAnimation(points: points, at: position)
        }
        
        achievementsManager.updateAchievement(id: "score_1000", value: score)
        // Global high score
        if score > userDefaults.integer(forKey: scoreKey) {
            achievementsManager.updateAchievement(id: "high_score", value: score)
            // Update leaderboard when new high score is achieved
            updateLeaderboard()
        }
        // Per-level high score
        let levelHighScoreKey = "highScore_level_\(level)"
        let prevLevelHigh = userDefaults.integer(forKey: levelHighScoreKey)
        if score > prevLevelHigh {
            userDefaults.set(score, forKey: levelHighScoreKey)
            print("[HighScore] New high score for level \(level): \(score)")
        }
        delegate?.gameStateDidUpdate()
        // Check for level up after every score change
        let requiredScore = calculateRequiredScore()
        if score >= requiredScore && !levelComplete {
            print("[Level] Score threshold met for level \(level). Level complete!")
            levelComplete = true
        }
        checkAchievements()
    }
    
    private func calculateRequiredScore() -> Int {
        if level <= 5 {
            return level * 1000
        } else if level <= 10 {
            return level * 2000
        } else if level <= 50 {
            return level * 3000
        } else {
            return level * 5000
        }
    }
    
    func levelUp() {
        let requiredScore = calculateRequiredScore()
        guard score >= requiredScore else {
            print("[Level] Not enough score to level up. Required: \(requiredScore), Current: \(score)")
            return
        }
        level += 1
        print("[Level] Level up! Now at level \(level)")
        setSeed(for: level)
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        if level > userDefaults.integer(forKey: levelKey) {
            achievementsManager.updateAchievement(id: "highest_level", value: level)
            // Update leaderboard when new highest level is achieved
            updateLeaderboard()
        }
        let availableShapes = BlockShape.availableShapes(for: level)
        print("[Level] Level \(level) - Available shapes: \(availableShapes.map { String(describing: $0) }.joined(separator: ", "))")
        refillTray()
        levelComplete = false
        if isPerfectLevel {
            perfectLevels += 1
        }
        isPerfectLevel = true
        currentChain = 0
        usedColors.removeAll()
        usedShapes.removeAll()
        delegate?.gameStateDidUpdate()
        checkAchievements()
    }
    
    func advanceToNextLevel() {
        level += 1
        print("[Level] Advancing to level \(level)")
        setSeed(for: level)
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        if level > userDefaults.integer(forKey: levelKey) {
            achievementsManager.updateAchievement(id: "highest_level", value: level)
        }
        let availableShapes = BlockShape.availableShapes(for: level)
        print("[Level] Level \(level) - Available shapes: \(availableShapes.map { String(describing: $0) }.joined(separator: ", "))")
        refillTray()
        levelComplete = false
        delegate?.gameStateDidUpdate()
    }
    
    private func checkGameOver() {
        // End the game if none of the tray shapes can be placed anywhere
        let canPlaceAny = tray.contains { canPlaceBlockAnywhere($0) }
        if !canPlaceAny {
            print("[GameOver] No available moves for any tray shape. Game over.")
            isGameOver = true
            saveProgress()
            if score > 0 { updateLeaderboard() }
            gameOver()
        }
    }
    
    private func hasValidMoves() -> Bool {
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] == nil {
                    return true
                }
            }
        }
        return false
    }
    
    // Award points for grouping 10 or more contiguous squares
    private func checkGroups() {
        var visited = Array(repeating: Array(repeating: false, count: GameConstants.gridSize), count: GameConstants.gridSize)
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if let _ = grid[row][col], !visited[row][col] {
                    let group = floodFill(row: row, col: col, visited: &visited)
                    if group.count >= 10 {
                        addScore(200, at: CGPoint(x: frameSize.width/2, y: CGFloat(row) * GameConstants.blockSize))
                        print("[Bonus] Group of \(group.count) contiguous blocks at (\(row),\(col)). +200 bonus points!")
                    }
                }
            }
        }
    }

    private func floodFill(row: Int, col: Int, visited: inout [[Bool]]) -> [(Int, Int)] {
        let directions = [(-1,0),(1,0),(0,-1),(0,1)]
        var queue = [(row, col)]
        var group = [(row, col)]
        visited[row][col] = true
        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            for (dr, dc) in directions {
                let nr = r + dr, nc = c + dc
                if nr >= 0 && nr < GameConstants.gridSize && nc >= 0 && nc < GameConstants.gridSize {
                    if let _ = grid[nr][nc], !visited[nr][nc] {
                        visited[nr][nc] = true
                        queue.append((nr, nc))
                        group.append((nr, nc))
                    }
                }
            }
        }
        return group
    }
    
    private func updateLeaderboard() {
        let db = Firestore.firestore()
        let now = Date()
        let periods = [
            "daily",
            "weekly",
            "yearly",
            "alltime"
        ]
        
        // Add debug logging
        print("[Leaderboard] Attempting to update leaderboard")
        print("[Leaderboard] UserID: \(userID)")
        print("[Leaderboard] Username: \(username)")
        print("[Leaderboard] Current Score: \(score)")
        
        // Only write to leaderboard if user is not a guest and has a username
        guard !userID.isEmpty, !username.isEmpty else {
            print("[Leaderboard] Update failed - Missing userID or username")
            return
        }
        
        for period in periods {
            let periodKey = period
            let docRef = db.collection("classic_leaderboard").document(periodKey).collection("scores").document(userID)
            
            docRef.getDocument { snapshot, error in
                if let error = error {
                    print("[Leaderboard] Error fetching previous score: \(error.localizedDescription)")
                    return
                }
                
                let prevScore = snapshot?.data()?["score"] as? Int ?? 0
                print("[Leaderboard] Previous score for \(period): \(prevScore)")
                
                if self.score > prevScore {
                    print("[Leaderboard] Updating score for \(period) - New score: \(self.score)")
                    docRef.setData([
                        "username": self.username,
                        "score": self.score,
                        "timestamp": Timestamp(date: now)
                    ], merge: true) { error in
                        if let error = error {
                            print("[Leaderboard] Error updating score: \(error.localizedDescription)")
                        } else {
                            print("[Leaderboard] Successfully updated score for \(period)")
                        }
                    }
                } else {
                    print("[Leaderboard] Score not updated for \(period) - Current score (\(self.score)) not higher than previous (\(prevScore))")
                }
            }
        }
    }
    
    private func loadLastPlayDate() {
        if let savedDate = userDefaults.object(forKey: "lastPlayDate") as? Date {
            lastPlayDate = savedDate
            let calendar = Calendar.current
            if let days = calendar.dateComponents([.day], from: savedDate, to: Date()).day {
                if days == 1 {
                    consecutiveDays += 1
                    achievementsManager.updateAchievement(id: "login_\(consecutiveDays)", value: consecutiveDays)
                    achievementsManager.updateAchievement(id: "daily_\(consecutiveDays)", value: consecutiveDays)
                } else if days > 1 {
                    consecutiveDays = 0
                }
            }
        } else {
            // First time playing
            achievementsManager.updateAchievement(id: "login_1", value: 1)
        }
    }
    
    private func saveLastPlayDate() {
        lastPlayDate = Date()
        userDefaults.set(lastPlayDate, forKey: "lastPlayDate")
        
        // Update login achievements
        if consecutiveDays > 0 {
            achievementsManager.updateAchievement(id: "login_\(consecutiveDays)", value: consecutiveDays)
        }
    }
    
    private func showAchievementNotification(_ achievement: Achievement) {
        // Only show notification if the achievement hasn't been notified before
        if !achievement.wasNotified {
            currentAchievement = achievement
            showingAchievementNotification = true
            
            // Mark the achievement as notified immediately
            achievementsManager.markAsNotified(id: achievement.id)
            
            // Hide notification after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.showingAchievementNotification = false
                self?.currentAchievement = nil
            }
        }
    }
    
    private func checkAchievements() {
        // Score achievements
        achievementsManager.updateAchievement(id: "score_1000", value: score)
        achievementsManager.updateAchievement(id: "score_5000", value: score)
        achievementsManager.updateAchievement(id: "score_10000", value: score)
        achievementsManager.updateAchievement(id: "score_50000", value: score)
        
        // Level achievements
        achievementsManager.updateAchievement(id: "level_5", value: level)
        achievementsManager.updateAchievement(id: "level_10", value: level)
        achievementsManager.updateAchievement(id: "level_20", value: level)
        achievementsManager.updateAchievement(id: "level_50", value: level)
        
        // Lines cleared achievements
        achievementsManager.updateAchievement(id: "lines_10", value: linesCleared)
        achievementsManager.updateAchievement(id: "lines_50", value: linesCleared)
        achievementsManager.updateAchievement(id: "lines_100", value: linesCleared)
        
        // Blocks placed achievements
        achievementsManager.updateAchievement(id: "blocks_50", value: blocksPlaced)
        achievementsManager.updateAchievement(id: "blocks_200", value: blocksPlaced)
        achievementsManager.updateAchievement(id: "blocks_500", value: blocksPlaced)
        
        // Chain achievements
        achievementsManager.updateAchievement(id: "chain_3", value: currentChain)
        achievementsManager.updateAchievement(id: "chain_5", value: currentChain)
        achievementsManager.updateAchievement(id: "chain_10", value: currentChain)
        
        // Color achievements
        achievementsManager.updateAchievement(id: "colors_5", value: usedColors.count)
        achievementsManager.updateAchievement(id: "colors_8", value: usedColors.count)
        
        // Grid fill achievements
        let gridFillPercentage = Double(blocksPlaced) / Double(GameConstants.gridSize * GameConstants.gridSize) * 100
        achievementsManager.updateAchievement(id: "grid_25", value: Int(gridFillPercentage))
        achievementsManager.updateAchievement(id: "grid_50", value: Int(gridFillPercentage))
        achievementsManager.updateAchievement(id: "grid_75", value: Int(gridFillPercentage))
        
        // Perfect level achievements
        if isPerfectLevel {
            achievementsManager.updateAchievement(id: "perfect_level", value: 1)
        }
        achievementsManager.updateAchievement(id: "perfect_3", value: perfectLevels)
        
        // Undo achievements
        achievementsManager.updateAchievement(id: "undo_5", value: undoCount)
        achievementsManager.updateAchievement(id: "undo_20", value: undoCount)
        
        // Daily login achievements
        achievementsManager.updateAchievement(id: "login_3", value: consecutiveDays)
        achievementsManager.updateAchievement(id: "login_7", value: consecutiveDays)
        achievementsManager.updateAchievement(id: "login_30", value: consecutiveDays)
        
        // Games completed achievements
        achievementsManager.updateAchievement(id: "games_10", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_50", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_100", value: gamesCompleted)
        
        // Check for newly unlocked achievements and show notifications
        for achievement in achievementsManager.getAllAchievements() {
            if achievement.unlocked && !achievement.wasNotified {
                showAchievementNotification(achievement)
            }
        }
    }
    
    func gameOver() {
        isGameOver = true
        gamesCompleted += 1
        achievementsManager.updateAchievement(id: "games_10", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_50", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_100", value: gamesCompleted)
        
        saveLastPlayDate()
        checkAchievements()
    }
}

// Deterministic seeded random generator
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
} 

extension BlockShape {
    static func availableShapes(for level: Int) -> [BlockShape] {
        // Level 1: I, L, T, and square shapes (all rotations)
        let all: [BlockShape] = [
            .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square,
            .lUp, .lDown, .lLeft, .lRight,
            .tUp, .tDown, .tLeft, .tRight,
            .zShape, .plus, .cross, .uShape, .vShape, .wShape, .xShape, .yShape, .zShape2
        ]
        if level <= 1 {
            return [.bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square, .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight]
        }
        if level <= 3 {
            return [.bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square, .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight, .zShape]
        }
        if level <= 5 {
            return [.bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square, .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight, .zShape, .plus]
        }
        if level <= 10 { return Array(all.prefix(18)) }
        if level <= 20 { return Array(all.prefix(20)) }
        if level <= 50 { return Array(all.prefix(22)) }
        return all
    }
}

extension BlockColor {
    static func availableColors(for level: Int) -> [BlockColor] {
        return [.red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan]
    }
}