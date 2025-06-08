import Foundation
import SwiftUI

// MARK: - Game Types
struct GameMove {
    let block: Block
    let position: (row: Int, col: Int)
    let previousGrid: [[BlockColor?]]
    let previousTray: [Block]
    let previousScore: Int
    let previousLevel: Int
    let previousBlocksPlaced: Int
    let previousLinesCleared: Int
    let previousCurrentChain: Int
    let previousUsedColors: Set<BlockColor>
    let previousUsedShapes: Set<BlockShape>
    let previousIsPerfectLevel: Bool
    let timestamp: Date?
    
    init(block: Block, position: (row: Int, col: Int), previousGrid: [[BlockColor?]], previousTray: [Block], previousScore: Int, previousLevel: Int, previousBlocksPlaced: Int, previousLinesCleared: Int, previousCurrentChain: Int, previousUsedColors: Set<BlockColor>, previousUsedShapes: Set<BlockShape>, previousIsPerfectLevel: Bool, timestamp: Date? = Date()) {
        self.block = block
        self.position = position
        self.previousGrid = previousGrid
        self.previousTray = previousTray
        self.previousScore = previousScore
        self.previousLevel = previousLevel
        self.previousBlocksPlaced = previousBlocksPlaced
        self.previousLinesCleared = previousLinesCleared
        self.previousCurrentChain = previousCurrentChain
        self.previousUsedColors = previousUsedColors
        self.previousUsedShapes = previousUsedShapes
        self.previousIsPerfectLevel = previousIsPerfectLevel
        self.timestamp = timestamp
    }
}

// MARK: - GameMoveStack
class GameMoveStack {
    private var moves: [GameMove] = []
    private let maxSize: Int
    
    init(maxSize: Int = 10) {
        self.maxSize = maxSize
    }
    
    func push(_ move: GameMove) {
        moves.append(move)
        if moves.count > maxSize {
            moves.removeFirst()
        }
    }
    
    func pop() -> GameMove? {
        return moves.popLast()
    }
    
    var isEmpty: Bool {
        return moves.isEmpty
    }
    
    var count: Int {
        return moves.count
    }
    
    func clear() {
        moves.removeAll()
    }
} 