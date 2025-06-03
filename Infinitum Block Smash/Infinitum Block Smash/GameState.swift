import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Game Types
struct GameMove {
    let block: Block
    let position: CGPoint
    let timestamp: Date
}

class GameBoard {
    var grid: [[Block?]]
    var tray: [Block]
    
    init() {
        self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        self.tray = []
    }
}

// MARK: - GameState
protocol GameStateDelegate: AnyObject {
    func gameStateDidUpdate()
    func gameStateDidClearLines(at positions: [(Int, Int)])
    func showScoreAnimation(points: Int, at position: CGPoint)
}

@MainActor
final class GameState: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var score: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var grid: [[BlockColor?]] = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
    @Published private(set) var tray: [Block] = []
    @Published private(set) var achievementsManager = AchievementsManager()
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var levelComplete: Bool = false
    @Published private(set) var adUndoCount: Int = 0
    @Published private(set) var showingAchievementNotification: Bool = false
    @Published private(set) var currentAchievement: Achievement?
    @Published private(set) var blocksPlaced: Int = 0
    @Published private(set) var linesCleared: Int = 0
    @Published private(set) var gameStartTime: Date?
    @Published private(set) var lastPlayDate: Date?
    @Published private(set) var consecutiveDays: Int = 0
    @Published private(set) var currentChain: Int = 0
    @Published private(set) var usedColors: Set<BlockColor> = []
    @Published private(set) var usedShapes: Set<BlockShape> = []
    @Published private(set) var perfectLevels: Int = 0
    @Published private(set) var isPerfectLevel: Bool = true
    @Published private(set) var gamesCompleted: Int = 0
    @Published private(set) var undoCount: Int = 0
    
    // Add frame size property
    var frameSize: CGSize = .zero
    
    var delegate: GameStateDelegate? {
        didSet {
            print("[DEBUG] GameState.delegate set to \(String(describing: delegate))")
        }
    }
    
    private var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
    private let traySize = 3
    
    private let userDefaults = UserDefaults.standard
    private let scoreKey = "highScore"
    private let levelKey = "highestLevel"
    private let progressKey = "gameProgress"
    
    // Undo support
    private var previousGrid: [[BlockColor?]] = []
    private var previousTray: [Block] = []
    private var previousScore: Int = 0
    private var previousLevel: Int = 1
    
    var canAdUndo: Bool { adUndoCount > 0 }
    
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var lastMove: GameMove?
    private var gameBoard: GameBoard
    private var currentShapes: [any Shape]
    
    // MARK: - Initialization
    init() {
        self.gameBoard = GameBoard()
        self.currentShapes = []
        setupSubscriptions()
        setupInitialGame()
        gameStartTime = Date()
        loadLastPlayDate()
    }
    
    // MARK: - Private Methods
    private func setupInitialGame() {
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        refillTray()
        level = 1
        score = 0
        isGameOver = false
        levelComplete = false
        canUndo = false
        adUndoCount = 0
        blocksPlaced = 0
        linesCleared = 0
        currentChain = 0
        usedColors.removeAll()
        usedShapes.removeAll()
        isPerfectLevel = true
    }
    
    private func setupSubscriptions() {
        // Only subscribe to necessary publishers
        $score
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] newScore in
                self?.checkAchievements(for: newScore)
            }
            .store(in: &cancellables)
    }
    
    private func checkAchievements(for score: Int) {
        Task {
            do {
                let newAchievements = try await achievementsManager.checkAchievementProgress(score: score, level: level)
                if let achievement = newAchievements.first {
                    await MainActor.run {
                        self.currentAchievement = achievement
                        self.showingAchievementNotification = true
                        
                        // Auto-hide achievement notification after 3 seconds
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            await MainActor.run {
                                self.showingAchievementNotification = false
                                self.currentAchievement = nil
                            }
                        }
                    }
                }
            } catch {
                print("Error checking achievements: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Methods
    func resetGame() {
        score = 0
        level = 1
        isGameOver = false
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        refillTray()
        levelComplete = false
        canUndo = false
        gameBoard = GameBoard()
        currentShapes = []
        lastMove = nil
        do {
            try saveProgress()
        } catch {
            print("[Reset] Error saving progress: \(error.localizedDescription)")
            // Continue with reset even if save fails
        }
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
    
    func refillTray() {
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
        guard !isGameOver && !levelComplete else {
            print("[DEBUG] Block placement prevented: isGameOver=", isGameOver, "levelComplete=", levelComplete)
            return false
        }
        guard let trayIndex = tray.firstIndex(where: { $0.id == block.id }) else { return false }
        guard canPlaceBlock(block, at: anchor) else { return false }
        // Final defensive check: ensure all cells are within bounds
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                print("[Placement] Block \(block.shape.rawValue) at \(anchor) would be out of bounds. Skipping placement.")
                return false
            }
        }
        print("[Placement] Placing block \(block.shape.rawValue) at \(anchor)")
        saveStateForUndo()
        placeBlock(block, at: anchor)
        tray.remove(at: trayIndex)
        // refillTray() will be called after UI update
        checkMatches()
        checkGameOver()
        adUndoCount = 2
        delegate?.gameStateDidUpdate()
        checkAchievements()
        return true
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
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                return false
            }
            if grid[y][x] != nil {
                return false
            }
        }
        return true
    }
    
    private func countTouchingBlocks(at x: Int, y: Int) -> Int {
        var touchingCount = 0
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)] // up, right, down, left
        
        for (dx, dy) in directions {
            let newX = x + dx
            let newY = y + dy
            
            // Only count if the adjacent position is within grid bounds AND contains a block
            if newX >= 0 && newX < GameConstants.gridSize && 
               newY >= 0 && newY < GameConstants.gridSize && 
               grid[newY][newX] != nil {
                touchingCount += 1
            }
        }
        return touchingCount
    }

    private func placeBlock(_ block: Block, at anchor: CGPoint) {
        var totalTouchingPoints = 0
        var hasAnyTouches = false
        
        // First check for touches before placing the block
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                let touchingCount = countTouchingBlocks(at: x, y: y)
                if touchingCount > 0 {
                    hasAnyTouches = true
                    totalTouchingPoints += touchingCount
                    let position = CGPoint(x: CGFloat(x) * GameConstants.blockSize, y: CGFloat(y) * GameConstants.blockSize)
                    addScore(touchingCount, at: position)
                    print("[Touch] Block at (\(x),\(y)) touches \(touchingCount) blocks. +\(touchingCount) points!")
                }
            }
        }
        
        // Then place the block
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                grid[y][x] = block.color
            }
        }
        
        // Only award bonus if the block actually touched other blocks
        if hasAnyTouches && totalTouchingPoints >= 3 {
            let bonusPoints = totalTouchingPoints * 2
            addScore(bonusPoints, at: CGPoint(x: frameSize.width/2, y: frameSize.height/2))
            print("[Bonus] Multiple touches! +\(bonusPoints) bonus points!")
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
                let rowColors = grid[row].compactMap { $0 }
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
                let colColors = (0..<GameConstants.gridSize).compactMap { grid[$0][col] }
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
            print("[Level] Grid empty, level complete!")
            levelComplete = true
            // Don't call levelUp here - let the UI handle it through the LevelCompleteOverlay
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
        for col in 0..<GameConstants.gridSize {
            grid[row][col] = nil
        }
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
            print("[DEBUG] Setting levelComplete = true due to score threshold. Score: \(score), Required: \(requiredScore)")
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
        // Add a small delay before advancing to ensure the level complete overlay is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.level += 1
            print("[Level] Advancing to level \(self.level)")
            self.setSeed(for: self.level)
            self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
            self.tray = []
            if self.level > UserDefaults.standard.integer(forKey: self.levelKey) {
                self.achievementsManager.updateAchievement(id: "highest_level", value: self.level)
            }
            let availableShapes = BlockShape.availableShapes(for: self.level)
            print("[Level] Level \(self.level) - Available shapes: \(availableShapes.map { String(describing: $0) }.joined(separator: ", "))")
            self.refillTray()
            self.levelComplete = false
            self.delegate?.gameStateDidUpdate()
        }
    }
    
    private func checkGameOver() {
        // End the game if none of the tray shapes can be placed anywhere
        let canPlaceAny = tray.contains { canPlaceBlockAnywhere($0) }
        if !canPlaceAny && !isGameOver {  // Only proceed if not already game over
            print("[GameOver] No available moves for any tray shape. Game over.")
            handleGameOver()
        }
    }
    
    private func handleGameOver() {
        // Ensure we only process game over once
        guard !isGameOver else { return }
        
        isGameOver = true
        gamesCompleted += 1
        
        // Update achievements
        achievementsManager.updateAchievement(id: "games_10", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_50", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_100", value: gamesCompleted)
        
        // Save game state and update leaderboard safely
        do {
            try saveProgress()
            if score > 0 {
                updateLeaderboard()
            }
        } catch {
            print("[GameOver] Error saving progress: \(error.localizedDescription)")
            // Continue with game over even if save fails
        }
        
        // Save last play date and check achievements
        saveLastPlayDate()
        checkAchievements()
        
        // Notify delegate of state change
        delegate?.gameStateDidUpdate()
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
        Task {
            do {
                try await LeaderboardService.shared.updateLeaderboard(
                    type: .score,
                    score: score,
                    username: username,
                    userID: userID
                )
            } catch {
                print("[Leaderboard] Error updating leaderboard: \(error.localizedDescription)")
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
        handleGameOver()
    }
    
    func saveProgress() throws {
        // Save high score and highest level
        if score > userDefaults.integer(forKey: scoreKey) {
            userDefaults.set(score, forKey: scoreKey)
            achievementsManager.updateAchievement(id: "high_score", value: score)
        }
        if level > userDefaults.integer(forKey: levelKey) {
            userDefaults.set(level, forKey: levelKey)
            achievementsManager.updateAchievement(id: "highest_level", value: level)
        }
        
        // Convert grid to a property list compatible format
        var gridData: [[String?]] = []
        for row in grid {
            let rowData: [String?] = row.map { color in
                if let color = color {
                    return String(describing: color.rawValue)
                }
                return nil
            }
            gridData.append(rowData)
        }
        
        // Convert tray to a property list compatible format
        let trayData = tray.map { block in
            [
                "color": String(describing: block.color.rawValue),
                "shape": String(describing: block.shape.rawValue),
                "id": block.id.uuidString
            ] as [String: String]
        }
        
        // Create a property list compatible dictionary
        let progress: [String: Any] = [
            "score": score,
            "level": level,
            "grid": gridData,
            "tray": trayData
        ]
        
        // Convert to Data first to ensure it's property list compatible
        guard let data = try? JSONSerialization.data(withJSONObject: progress) else {
            throw GameError.saveFailed(NSError(domain: "GameState", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize game state"]))
        }
        
        // Save the data
        userDefaults.set(data, forKey: progressKey)
        
        // Verify the save was successful
        guard userDefaults.synchronize() else {
            throw GameError.saveFailed(NSError(domain: "GameState", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to synchronize UserDefaults"]))
        }
    }
    
    func cleanup() {
        cancellables.removeAll()
        currentAchievement = nil
        lastMove = nil
    }
    
    func resetLevelComplete() {
        levelComplete = false
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

// MARK: - Error Handling
enum GameError: LocalizedError {
    case saveFailed(Error)
    case leaderboardUpdateFailed(Error)
    case invalidMove
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save game progress: \(error.localizedDescription)"
        case .leaderboardUpdateFailed(let error):
            return "Failed to update leaderboard: \(error.localizedDescription)"
        case .invalidMove:
            return "Invalid move"
        case .networkError:
            return "Network connection error. Please check your internet connection."
        }
    }
}