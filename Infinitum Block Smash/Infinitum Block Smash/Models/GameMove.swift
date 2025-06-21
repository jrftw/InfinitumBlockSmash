/******************************************************
 * FILE: GameMove.swift
 * MARK: Game Move Data Model and Undo/Redo System
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Defines the core data structures for game moves, undo/redo functionality,
 * and scoring breakdown. This file manages the complete state capture
 * required for game history and move reversal operations.
 *
 * KEY RESPONSIBILITIES:
 * - Game move data structure definition and management
 * - Complete game state snapshot capture for undo operations
 * - Undo/redo stack management with size limits
 * - Move persistence and restoration for saved games
 * - Scoring breakdown and detailed score tracking
 * - Custom Codable implementation for complex data structures
 * - Move validation and state integrity checking
 * - Performance optimization for move storage
 *
 * MAJOR DEPENDENCIES:
 * - Block.swift: Block data model and properties
 * - GameState.swift: Game state integration and validation
 * - Foundation: Core framework for data structures and Codable
 * - SwiftUI: UI framework for score display components
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for data structures and serialization
 * - SwiftUI: Modern UI framework for score components
 *
 * ARCHITECTURE ROLE:
 * Acts as the data persistence layer for game moves and history,
 * providing the foundation for undo/redo functionality and
 * detailed scoring analysis.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Move snapshots must capture complete game state
 * - Undo stack size limits prevent memory issues
 * - Custom Codable implementation handles complex data types
 * - Move validation ensures state integrity
 * - Performance optimization for frequent move operations
 */

import Foundation
import SwiftUI

// MARK: - Game Types
struct GameMove: Codable {
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
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case block, position, previousGrid, previousTray, previousScore, previousLevel
        case previousBlocksPlaced, previousLinesCleared, previousCurrentChain
        case previousUsedColors, previousUsedShapes, previousIsPerfectLevel, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        block = try container.decode(Block.self, forKey: .block)
        
        // Decode position tuple
        let positionData = try container.decode([String: Int].self, forKey: .position)
        guard let row = positionData["row"], let col = positionData["col"] else {
            throw DecodingError.dataCorruptedError(forKey: .position, in: container, debugDescription: "Invalid position data")
        }
        position = (row: row, col: col)
        
        // Decode grid
        let gridData = try container.decode([[String]].self, forKey: .previousGrid)
        previousGrid = gridData.map { row in
            row.map { colorString in
                colorString == "nil" ? nil : BlockColor(rawValue: colorString)
            }
        }
        
        previousTray = try container.decode([Block].self, forKey: .previousTray)
        previousScore = try container.decode(Int.self, forKey: .previousScore)
        previousLevel = try container.decode(Int.self, forKey: .previousLevel)
        previousBlocksPlaced = try container.decode(Int.self, forKey: .previousBlocksPlaced)
        previousLinesCleared = try container.decode(Int.self, forKey: .previousLinesCleared)
        previousCurrentChain = try container.decode(Int.self, forKey: .previousCurrentChain)
        
        // Decode sets
        let usedColorsData = try container.decode([String].self, forKey: .previousUsedColors)
        previousUsedColors = Set(usedColorsData.compactMap { BlockColor(rawValue: $0) })
        
        let usedShapesData = try container.decode([String].self, forKey: .previousUsedShapes)
        previousUsedShapes = Set(usedShapesData.compactMap { BlockShape(rawValue: $0) })
        
        previousIsPerfectLevel = try container.decode(Bool.self, forKey: .previousIsPerfectLevel)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(block, forKey: .block)
        
        // Encode position tuple
        try container.encode(["row": position.row, "col": position.col], forKey: .position)
        
        // Encode grid
        let gridData = previousGrid.map { row in
            row.map { color in
                color?.rawValue ?? "nil"
            }
        }
        try container.encode(gridData, forKey: .previousGrid)
        
        try container.encode(previousTray, forKey: .previousTray)
        try container.encode(previousScore, forKey: .previousScore)
        try container.encode(previousLevel, forKey: .previousLevel)
        try container.encode(previousBlocksPlaced, forKey: .previousBlocksPlaced)
        try container.encode(previousLinesCleared, forKey: .previousLinesCleared)
        try container.encode(previousCurrentChain, forKey: .previousCurrentChain)
        
        // Encode sets
        try container.encode(previousUsedColors.map { $0.rawValue }, forKey: .previousUsedColors)
        try container.encode(previousUsedShapes.map { $0.rawValue }, forKey: .previousUsedShapes)
        
        try container.encode(previousIsPerfectLevel, forKey: .previousIsPerfectLevel)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
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
    
    // NEW: Get all moves for saving
    var allMoves: [GameMove] {
        return moves
    }
    
    // NEW: Load moves from saved data
    func loadMoves(_ moves: [GameMove]) {
        self.moves = moves
        if self.moves.count > maxSize {
            self.moves = Array(self.moves.suffix(maxSize))
        }
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
