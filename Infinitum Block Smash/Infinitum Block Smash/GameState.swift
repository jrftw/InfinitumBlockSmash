import Foundation
import Combine
import SwiftUI

protocol GameStateDelegate: AnyObject {
    func gameStateDidUpdate()
    func gameStateDidClearLines(at positions: [(Int, Int)])
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
    
    init() {
        loadProgress()
        setupGame()
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
        guard canUndo else { return }
        print("[Undo] Undoing last move. Restoring previous grid, tray, score, and level.")
        grid = previousGrid.map { $0.map { $0 } }
        tray = previousTray.map { $0 }
        score = previousScore
        level = previousLevel
        canUndo = false
        delegate?.gameStateDidUpdate()
    }

    // In tryPlaceBlockFromTray, save state before placement and reset undo after
    func tryPlaceBlockFromTray(_ block: Block, at anchor: CGPoint) -> Bool {
        guard let trayIndex = tray.firstIndex(where: { $0.id == block.id }) else { return false }
        if canPlaceBlock(block, at: anchor) {
            print("[Placement] Placing block \(block.shape.rawValue) at \(anchor)")
            saveStateForUndo()
            placeBlock(block, at: anchor)
            tray.remove(at: trayIndex)
            refillTray()
            checkMatches()
            checkGameOver()
            delegate?.gameStateDidUpdate()
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
    
    private func placeBlock(_ block: Block, at anchor: CGPoint) {
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                var placedBlock = Block(color: block.color, shape: .bar2H)
                placedBlock.position = CGPoint(x: x, y: y)
                grid[y][x] = placedBlock
            }
        }
    }
    
    private func checkMatches() {
        var clearedPositions: [(Int, Int)] = []
        var linesCleared = 0
        for row in 0..<GameConstants.gridSize {
            if isRowFull(row) {
                let rowColors = grid[row].compactMap { $0?.color }
                let allSameColor = rowColors.allSatisfy { $0 == rowColors.first }
                for col in 0..<GameConstants.gridSize {
                    clearedPositions.append((row, col))
                }
                clearRow(row)
                addScore(100)
                print("[Clear] Row \(row) cleared. +100 points.")
                if allSameColor && !rowColors.isEmpty {
                    addScore(200)
                    print("[Bonus] Row \(row) all same color (\(rowColors.first!)). +200 bonus points!")
                }
                linesCleared += 1
            }
        }
        for col in 0..<GameConstants.gridSize {
            if isColumnFull(col) {
                let colColors = (0..<GameConstants.gridSize).compactMap { grid[$0][col]?.color }
                let allSameColor = colColors.allSatisfy { $0 == colColors.first }
                for row in 0..<GameConstants.gridSize {
                    clearedPositions.append((row, col))
                }
                clearColumn(col)
                addScore(100)
                print("[Clear] Column \(col) cleared. +100 points.")
                if allSameColor && !colColors.isEmpty {
                    addScore(200)
                    print("[Bonus] Column \(col) all same color (\(colColors.first!)). +200 bonus points!")
                }
                linesCleared += 1
            }
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
    
    func addScore(_ points: Int) {
        let oldScore = score
        score += points
        print("[Score] Added \(points) points (from \(oldScore) to \(score))")
        achievementsManager.updateAchievement(id: "score_1000", value: score)
        // Global high score
        if score > userDefaults.integer(forKey: scoreKey) {
            achievementsManager.updateAchievement(id: "high_score", value: score)
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
        let requiredScore = level * 1000
        if score >= requiredScore && !levelComplete {
            print("[Level] Score threshold met for level \(level). Level complete!")
            levelComplete = true
        }
    }
    
    func levelUp() {
        let requiredScore = level * 1000
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
        }
        let availableShapes = BlockShape.availableShapes(for: level)
        print("[Level] Level \(level) - Available shapes: \(availableShapes.map { String(describing: $0) }.joined(separator: ", "))")
        refillTray()
        levelComplete = false
        delegate?.gameStateDidUpdate()
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
        // Remove the top row check. Only end the game if none of the tray shapes can be placed.
        let canPlaceAny = tray.contains { canPlaceBlockAnywhere($0) }
        if !canPlaceAny {
            print("[GameOver] No available moves for any tray shape. Game over. Resetting to level 1.")
            isGameOver = true
            saveProgress()
            // Optionally, reset to level 1 automatically:
            // level = 1
            // score = 0
            // setupGame()
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
                        addScore(200)
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