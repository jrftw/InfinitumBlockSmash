/*
 * FILE: GameMove.swift
 * PURPOSE: Defines game move data structures and undo/redo functionality
 * DEPENDENCIES:
 *    - Block.swift (for block definitions)
 *    - GameState.swift (for game state integration)
 * AUTHOR: @jrftw
 * LAST UPDATED: 6/19/2025
 */

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

// MARK: - Scoring Breakdown
struct ScoringBreakdown: Codable {
    let totalScore: Int
    let breakdown: [ScoreEntry]
    let level: Int
    let timestamp: Date
    
    struct ScoreEntry: Codable, Identifiable {
        let id: UUID
        let type: ScoreType
        let points: Int
        let description: String
        let count: Int
        
        init(type: ScoreType, points: Int, description: String, count: Int) {
            self.id = UUID()
            self.type = type
            self.points = points
            self.description = description
            self.count = count
        }
        
        // Custom Codable implementation to handle the id property
        enum CodingKeys: String, CodingKey {
            case type, points, description, count
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.type = try container.decode(ScoreType.self, forKey: .type)
            self.points = try container.decode(Int.self, forKey: .points)
            self.description = try container.decode(String.self, forKey: .description)
            self.count = try container.decode(Int.self, forKey: .count)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(points, forKey: .points)
            try container.encode(description, forKey: .description)
            try container.encode(count, forKey: .count)
        }
        
        var displayName: String {
            switch self.type {
            case .blockPlacement:
                return "Block Placements"
            case .touchingBlocks:
                return "Touching Blocks"
            case .multipleTouches:
                return "Multiple Touches"
            case .lineClear:
                return "Lines Cleared"
            case .sameColorBonus:
                return "Same Color Bonus"
            case .xPattern:
                return "X Pattern"
            case .perfectLevel:
                return "Perfect Level"
            case .groupBonus:
                return "Group Bonus"
            case .timeBonus:
                return "Time Bonus"
            case .chainBonus:
                return "Chain Bonus"
            }
        }
        
        var icon: String {
            switch self.type {
            case .blockPlacement:
                return "square.grid.3x3"
            case .touchingBlocks:
                return "link"
            case .multipleTouches:
                return "network"
            case .lineClear:
                return "line.3.horizontal"
            case .sameColorBonus:
                return "paintpalette"
            case .xPattern:
                return "xmark"
            case .perfectLevel:
                return "star.fill"
            case .groupBonus:
                return "circle.grid.3x3"
            case .timeBonus:
                return "clock"
            case .chainBonus:
                return "link.badge.plus"
            }
        }
        
        var color: String {
            switch self.type {
            case .blockPlacement:
                return "blue"
            case .touchingBlocks:
                return "green"
            case .multipleTouches:
                return "purple"
            case .lineClear:
                return "orange"
            case .sameColorBonus:
                return "pink"
            case .xPattern:
                return "red"
            case .perfectLevel:
                return "yellow"
            case .groupBonus:
                return "indigo"
            case .timeBonus:
                return "cyan"
            case .chainBonus:
                return "mint"
            }
        }
    }
    
    enum ScoreType: String, Codable, CaseIterable {
        case blockPlacement = "block_placement"
        case touchingBlocks = "touching_blocks"
        case multipleTouches = "multiple_touches"
        case lineClear = "line_clear"
        case sameColorBonus = "same_color_bonus"
        case xPattern = "x_pattern"
        case perfectLevel = "perfect_level"
        case groupBonus = "group_bonus"
        case timeBonus = "time_bonus"
        case chainBonus = "chain_bonus"
    }
    
    var totalEntries: Int {
        breakdown.count
    }
    
    var totalPoints: Int {
        breakdown.reduce(0) { $0 + $1.points }
    }
} 
