import Foundation
import SwiftUI
import SpriteKit

// MARK: - HintManager
@MainActor
class HintManager: ObservableObject {
    // MARK: - Properties
    @Published private(set) var hintsUsedThisGame: Int = 0
    private var lastHintTime: TimeInterval = 0
    private let hintCooldown: TimeInterval = 1.0 // 1 second cooldown
    private var cachedHint: (block: Block, position: (row: Int, col: Int))?
    
    // MARK: - Methods
    func showHint(gameState: GameState, delegate: GameStateDelegate?) {
        Task { @MainActor in
            let currentTime = CACurrentMediaTime()
            guard currentTime - lastHintTime >= hintCooldown else {
                print("[Hint] Hint on cooldown")
                return
            }
            
            let hasUnlimitedHints = await SubscriptionManager.shared.hasFeature(.hints)
            if hintsUsedThisGame >= 3 && !hasUnlimitedHints {
                return
            }
            
            print("[Hint] Attempting to show hint. Current hints used: \(hintsUsedThisGame)")
            
            // First check if there are any valid moves
            if !gameState.hasValidMoves() {
                print("[Hint] No valid moves found - game over state")
                gameState.checkGameOver()
                return
            }
            
            // Try to use cached hint first
            if let cached = cachedHint, gameState.canPlaceBlock(cached.block, at: CGPoint(x: cached.position.col, y: cached.position.row)) {
                delegate?.highlightHint(block: cached.block, at: cached.position)
                if !hasUnlimitedHints {
                    hintsUsedThisGame += 1
                }
                lastHintTime = currentTime
                return
            }
            
            // If no valid cached hint, find a new one
            if let (block, position) = await findBestMove(gameState: gameState) {
                cachedHint = (block, position)
                delegate?.highlightHint(block: block, at: position)
                if !hasUnlimitedHints {
                    hintsUsedThisGame += 1
                }
                lastHintTime = currentTime
            } else {
                print("[Hint] No valid moves found")
                gameState.checkGameOver()
            }
        }
    }
    
    private func findBestMove(gameState: GameState) async -> (block: Block, position: (row: Int, col: Int))? {
        var bestMove: (block: Block, position: (row: Int, col: Int), score: Int)?
        
        // First check if we have any blocks in the tray
        guard !gameState.tray.isEmpty else { return nil }
        
        // Try each block in the tray
        for block in gameState.tray {
            // Try each position in the grid
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    // Check if we can place the block at this position
                    if gameState.canPlaceBlock(block, at: CGPoint(x: col, y: row)) {
                        let moveScore = await evaluateMove(block: block, at: (row, col), gameState: gameState)
                        
                        if let currentBest = bestMove {
                            if moveScore > currentBest.score {
                                bestMove = (block, (row, col), moveScore)
                            }
                        } else {
                            bestMove = (block, (row, col), moveScore)
                        }
                    }
                }
            }
        }
        
        // If no valid moves found in the tray, check for game over
        if bestMove == nil {
            await MainActor.run {
                gameState.checkGameOver()
            }
        }
        
        return bestMove.map { ($0.block, $0.position) }
    }
    
    private func evaluateMove(block: Block, at position: (row: Int, col: Int), gameState: GameState) async -> Int {
        var score = 0
        
        // 1. Check for line clearing potential
        let linesToClear = await checkLinesToClear(block: block, at: position, gameState: gameState)
        score += linesToClear * 100 // Prioritize moves that clear lines
        
        // 2. Check for pattern creation
        let patternScore = await checkPatternCreation(block: block, at: position, gameState: gameState)
        score += patternScore
        
        // 3. Check for touching blocks (basic connectivity)
        let touchingBlocks = await countTouchingBlocks(at: position, block: block, gameState: gameState)
        score += touchingBlocks * 20 // Reward moves that connect with existing blocks
        
        // 4. Check for chain reaction potential
        let chainPotential = await checkChainPotential(block: block, at: position, gameState: gameState)
        score += chainPotential * 50
        
        // 5. Check for space efficiency
        let spaceEfficiency = await checkSpaceEfficiency(block: block, at: position, gameState: gameState)
        score += spaceEfficiency * 30
        
        // 6. Check for color matching
        let colorMatchScore = await checkColorMatching(block: block, at: position, gameState: gameState)
        score += colorMatchScore * 25
        
        return score
    }
    
    private func checkLinesToClear(block: Block, at position: (row: Int, col: Int), gameState: GameState) async -> Int {
        var linesToClear = 0
        var tempGrid = gameState.grid
        
        // Simulate placing the block
        for (dx, dy) in block.shape.cells {
            let x = position.col + dx
            let y = position.row + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                tempGrid[y][x] = block.color
            }
        }
        
        // Check rows
        for row in 0..<GameConstants.gridSize {
            if tempGrid[row].allSatisfy({ $0 != nil }) {
                linesToClear += 1
            }
        }
        
        // Check columns
        for col in 0..<GameConstants.gridSize {
            if (0..<GameConstants.gridSize).allSatisfy({ row in tempGrid[row][col] != nil }) {
                linesToClear += 1
            }
        }
        
        return linesToClear
    }
    
    private func checkPatternCreation(block: Block, at position: (row: Int, col: Int), gameState: GameState) async -> Int {
        var score = 0
        var tempGrid = gameState.grid
        
        // Simulate placing the block
        for (dx, dy) in block.shape.cells {
            let x = position.col + dx
            let y = position.row + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                tempGrid[y][x] = block.color
            }
        }
        
        // Check for diagonal patterns
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if let color = tempGrid[row][col] {
                    // Check forward diagonal (/)
                    var forwardCount = 1
                    var currentRow = row - 1
                    var currentCol = col + 1
                    while currentRow >= 0 && currentCol < GameConstants.gridSize &&
                          tempGrid[currentRow][currentCol] == color {
                        forwardCount += 1
                        currentRow -= 1
                        currentCol += 1
                    }
                    
                    if forwardCount >= 5 {
                        score += 100
                    }
                    
                    // Check backward diagonal (\)
                    var backwardCount = 1
                    currentRow = row - 1
                    currentCol = col - 1
                    while currentRow >= 0 && currentCol >= 0 &&
                          tempGrid[currentRow][currentCol] == color {
                        backwardCount += 1
                        currentRow -= 1
                        currentCol -= 1
                    }
                    
                    if backwardCount >= 5 {
                        score += 100
                    }
                }
            }
        }
        
        return score
    }
    
    private func countTouchingBlocks(at position: (row: Int, col: Int), block: Block, gameState: GameState) async -> Int {
        var count = 0
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)] // up, right, down, left
        
        for (dx, dy) in block.shape.cells {
            let x = position.col + dx
            let y = position.row + dy
            
            for (dirX, dirY) in directions {
                let newX = x + dirX
                let newY = y + dirY
                
                if newX >= 0 && newX < GameConstants.gridSize && newY >= 0 && newY < GameConstants.gridSize {
                    if gameState.grid[newY][newX] != nil {
                        count += 1
                    }
                }
            }
        }
        
        return count
    }
    
    private func checkChainPotential(block: Block, at position: (row: Int, col: Int), gameState: GameState) async -> Int {
        var score = 0
        var tempGrid = gameState.grid
        
        // Simulate placing the block
        for (dx, dy) in block.shape.cells {
            let x = position.col + dx
            let y = position.row + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                tempGrid[y][x] = block.color
            }
        }
        
        // Check for potential chain reactions
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if tempGrid[row][col] != nil {
                    // Check if this block is part of a potential chain
                    let chainLength = await findChainLength(at: (row, col), in: tempGrid)
                    if chainLength >= 3 {
                        score += chainLength * 10
                    }
                }
            }
        }
        
        return score
    }
    
    private func findChainLength(at position: (row: Int, col: Int), in grid: [[BlockColor?]]) async -> Int {
        var visited = Set<String>()
        var chainLength = 0
        let color = grid[position.row][position.col]
        
        func dfs(row: Int, col: Int) {
            let key = "\(row),\(col)"
            guard !visited.contains(key),
                  row >= 0 && row < GameConstants.gridSize,
                  col >= 0 && col < GameConstants.gridSize,
                  grid[row][col] == color else {
                return
            }
            
            visited.insert(key)
            chainLength += 1
            
            let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
            for (dx, dy) in directions {
                dfs(row: row + dy, col: col + dx)
            }
        }
        
        dfs(row: position.row, col: position.col)
        return chainLength
    }
    
    private func checkSpaceEfficiency(block: Block, at position: (row: Int, col: Int), gameState: GameState) async -> Int {
        var score = 0
        var tempGrid = gameState.grid
        
        // Simulate placing the block
        for (dx, dy) in block.shape.cells {
            let x = position.col + dx
            let y = position.row + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                tempGrid[y][x] = block.color
            }
        }
        
        // Count isolated empty spaces
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if tempGrid[row][col] == nil {
                    var isIsolated = true
                    let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
                    
                    for (dx, dy) in directions {
                        let newX = col + dx
                        let newY = row + dy
                        if newX >= 0 && newX < GameConstants.gridSize && newY >= 0 && newY < GameConstants.gridSize {
                            if tempGrid[newY][newX] != nil {
                                isIsolated = false
                                break
                            }
                        }
                    }
                    
                    if isIsolated {
                        score -= 5 // Penalize moves that create isolated spaces
                    }
                }
            }
        }
        
        return score
    }
    
    private func checkColorMatching(block: Block, at position: (row: Int, col: Int), gameState: GameState) async -> Int {
        var score = 0
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        
        for (dx, dy) in block.shape.cells {
            let x = position.col + dx
            let y = position.row + dy
            
            for (dirX, dirY) in directions {
                let newX = x + dirX
                let newY = y + dirY
                
                if newX >= 0 && newX < GameConstants.gridSize && newY >= 0 && newY < GameConstants.gridSize {
                    if let adjacentColor = gameState.grid[newY][newX], adjacentColor == block.color {
                        score += 10 // Reward moves that match colors
                    }
                }
            }
        }
        
        return score
    }
    
    func reset() {
        hintsUsedThisGame = 0
        lastHintTime = 0
        cachedHint = nil
    }
} 