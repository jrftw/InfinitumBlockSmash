/*
 * Block.swift
 * 
 * CORE GAME BLOCK DATA MODEL AND SHAPE SYSTEM
 * 
 * This file defines the fundamental data structures for the Infinitum Block Smash game,
 * including block properties, colors, shapes, and the complete shape system that
 * determines gameplay mechanics and visual representation.
 * 
 * KEY RESPONSIBILITIES:
 * - Block data structure definition and management
 * - Color system with gradients and visual effects
 * - Shape system with complexity levels and progression
 * - Block placement and positioning logic
 * - Shape availability based on game level
 * - Visual rendering properties and styling
 * - Game balance and difficulty progression
 * - Performance optimization for shape calculations
 * 
 * MAJOR DEPENDENCIES:
 * - GameState.swift: Block state management and game logic
 * - GameScene.swift: Visual rendering and block display
 * - BlockShapeView.swift: Shape-specific visual components
 * - AdaptiveDifficultyManager.swift: Dynamic difficulty adjustment
 * - GameConstants.swift: Game configuration constants
 * - SwiftUI: Color and visual property definitions
 * 
 * CORE DATA STRUCTURES:
 * - Block: Main block entity with color, shape, and position
 * - BlockColor: Color enumeration with gradient definitions
 * - BlockShape: Shape enumeration with cell layouts and properties
 * 
 * COLOR SYSTEM:
 * - 8 distinct colors (red, blue, green, yellow, purple, orange, pink, cyan)
 * - Gradient definitions for visual depth
 * - Shadow colors for 3D effects
 * - Color randomization for variety
 * - Accessibility considerations
 * 
 * SHAPE SYSTEM:
 * - 33 unique block shapes with varying complexity
 * - Level-based shape progression
 * - Cell-based layout definitions
 * - Complexity scoring for difficulty
 * - Shape categorization (basic, advanced, expert)
 * 
 * SHAPE CATEGORIES:
 * - Basic Shapes: Simple geometric forms (bars, squares, L-shapes)
 * - Advanced Shapes: Complex patterns (T-shapes, Z-shapes, crosses)
 * - Expert Shapes: Intricate designs (stars, diamonds, hexagons)
 * - Special Shapes: Unique patterns (spirals, zigzags)
 * 
 * LEVEL PROGRESSION:
 * - Shapes unlock progressively with level advancement
 * - Complexity increases with player skill
 * - Adaptive difficulty integration
 * - Balance considerations for fair gameplay
 * - Performance optimization for higher levels
 * 
 * PERFORMANCE FEATURES:
 * - Inline functions for critical calculations
 * - Efficient cell layout definitions
 * - Optimized shape filtering and selection
 * - Memory-efficient data structures
 * - Fast shape complexity calculations
 * 
 * GAMEPLAY INTEGRATION:
 * - Shape placement validation
 * - Line clearing detection
 * - Scoring system integration
 * - Achievement tracking
 * - Tutorial system support
 * 
 * VISUAL RENDERING:
 * - Gradient color definitions
 * - Shadow and lighting effects
 * - Shape-specific visual properties
 * - Animation support
 * - Theme integration
 * 
 * BALANCE AND DIFFICULTY:
 * - Shape complexity scoring
 * - Level-based availability
 * - Adaptive difficulty adjustment
 * - Player skill progression
 * - Fair gameplay mechanics
 * 
 * ARCHITECTURE ROLE:
 * This file serves as the foundation for the game's block system,
 * providing the data structures and logic that drive the core
 * gameplay mechanics and visual presentation.
 * 
 * THREADING CONSIDERATIONS:
 * - Immutable data structures for thread safety
 * - Efficient copying for state management
 * - Optimized calculations for performance
 * - Memory-efficient design patterns
 * 
 * INTEGRATION POINTS:
 * - Game state management
 * - Visual rendering system
 * - Difficulty adjustment
 * - Achievement system
 * - Analytics and tracking
 * - Tutorial and help systems
 */

import Foundation
import SwiftUI

// MARK: - Block
struct Block: Identifiable, Codable {
    var id: UUID
    let color: BlockColor
    let shape: BlockShape
    var position: CGPoint

    init(color: BlockColor, shape: BlockShape = .random(for: 1)) {
        self.id = UUID()
        self.position = .zero
        self.color = color
        self.shape = shape
    }

    init(color: BlockColor, shape: BlockShape, id: UUID) {
        self.id = id
        self.position = .zero
        self.color = color
        self.shape = shape
    }
}

// MARK: - BlockColor
enum BlockColor: String, CaseIterable, Codable {
    case red, blue, green, yellow, purple, orange, pink, cyan

    @inlinable
    var gradientColors: (start: CGColor, end: CGColor) {
        switch self {
        case .red: return Self.makeGradient(1.0, 0.2, 0.2, 0.8, 0.1, 0.1)
        case .blue: return Self.makeGradient(0.2, 0.4, 1.0, 0.1, 0.2, 0.8)
        case .green: return Self.makeGradient(0.2, 0.8, 0.2, 0.1, 0.6, 0.1)
        case .yellow: return Self.makeGradient(1.0, 0.9, 0.2, 0.9, 0.7, 0.1)
        case .purple: return Self.makeGradient(0.6, 0.2, 0.8, 0.4, 0.1, 0.6)
        case .orange: return Self.makeGradient(1.0, 0.6, 0.2, 0.9, 0.4, 0.1)
        case .pink: return Self.makeGradient(1.0, 0.4, 0.7, 0.8, 0.2, 0.5)
        case .cyan: return Self.makeGradient(0.2, 0.8, 0.8, 0.1, 0.6, 0.6)
        }
    }

    @inlinable
    var shadowColor: CGColor {
        switch self {
        case .red: return CGColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0)
        case .blue: return CGColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1.0)
        case .green: return CGColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1.0)
        case .yellow: return CGColor(red: 0.7, green: 0.6, blue: 0.1, alpha: 1.0)
        case .purple: return CGColor(red: 0.4, green: 0.1, blue: 0.5, alpha: 1.0)
        case .orange: return CGColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1.0)
        case .pink: return CGColor(red: 0.7, green: 0.2, blue: 0.4, alpha: 1.0)
        case .cyan: return CGColor(red: 0.1, green: 0.5, blue: 0.5, alpha: 1.0)
        }
    }

    @inlinable
    var color: Color {
        Color(cgColor: gradientColors.start)
    }

    static func random() -> BlockColor {
        allCases.randomElement() ?? .red
    }

    private static func makeGradient(_ r1: CGFloat, _ g1: CGFloat, _ b1: CGFloat,
                                     _ r2: CGFloat, _ g2: CGFloat, _ b2: CGFloat) -> (CGColor, CGColor) {
        (
            CGColor(red: r1, green: g1, blue: b1, alpha: 1.0),
            CGColor(red: r2, green: g2, blue: b2, alpha: 1.0)
        )
    }
}

// MARK: - BlockShape
enum BlockShape: String, CaseIterable, Codable {
    case single, tinyLUp, tinyLDown, tinyLLeft, tinyLRight, tinyI
    case bar2H, bar2V, bar3H, bar3V, bar4H, bar4V
    case square, rect2x3, rect3x2, rect3x3
    case lUp, lDown, lLeft, lRight
    case tUp, tDown, tLeft, tRight
    case zShape, plus, cross, uShape, vShape, wShape, xShape, yShape, zShape2
    case star, diamond, hexagon, spiral, zigzag

    // Cells (unchanged logic)
    @inline(__always)
    var cells: [(Int, Int)] {
        switch self {
        case .single: return [(0,0)]
        case .tinyLUp: return [(0,0), (0,1), (1,1)]
        case .tinyLDown: return [(1,0), (1,1), (0,1)]
        case .tinyLLeft: return [(0,0), (1,0), (1,1)]
        case .tinyLRight: return [(0,0), (0,1), (1,0)]
        case .tinyI: return [(0,0), (0,1), (0,2)]
        case .bar2H: return [(0,0), (1,0)]
        case .bar2V: return [(0,0), (0,1)]
        case .bar3H: return [(0,0), (1,0), (2,0)]
        case .bar3V: return [(0,0), (0,1), (0,2)]
        case .bar4H: return [(0,0), (1,0), (2,0), (3,0)]
        case .bar4V: return [(0,0), (0,1), (0,2), (0,3)]
        case .square: return [(0,0), (1,0), (0,1), (1,1)]
        case .rect2x3: return [(0,0), (1,0), (0,1), (1,1), (0,2), (1,2)]
        case .rect3x2: return [(0,0), (1,0), (2,0), (0,1), (1,1), (2,1)]
        case .rect3x3: return [(0,0), (1,0), (2,0), (0,1), (1,1), (2,1), (0,2), (1,2), (2,2)]
        case .lUp: return [(0,0), (0,1), (0,2), (1,2)]
        case .lDown: return [(1,0), (1,1), (1,2), (0,2)]
        case .lLeft: return [(0,0), (1,0), (2,0), (2,1)]
        case .lRight: return [(0,1), (1,1), (2,1), (2,0)]
        case .tUp: return [(0,0), (1,0), (2,0), (1,1)]
        case .tDown: return [(0,1), (1,1), (2,1), (1,0)]
        case .tLeft: return [(0,0), (0,1), (0,2), (1,1)]
        case .tRight: return [(1,0), (1,1), (1,2), (0,1)]
        case .zShape: return [(0,0), (1,0), (1,1), (2,1)]
        case .plus: return [(1,0), (0,1), (1,1), (2,1), (1,2)]
        case .cross: return [(0,0), (2,0), (1,1), (0,2), (2,2)]
        case .uShape: return [(0,0), (2,0), (0,1), (1,1), (2,1)]
        case .vShape: return [(0,0), (0,1), (1,1), (2,1), (2,2)]
        case .wShape: return [(0,0), (0,1), (1,1), (2,1), (2,2), (3,2)]
        case .xShape: return [(0,0), (2,0), (1,1), (0,2), (2,2)]
        case .yShape: return [(0,0), (0,1), (1,1), (0,2), (0,3)]
        case .zShape2: return [(0,0), (1,0), (2,0), (2,1), (2,2)]
        case .star, .diamond: return [(1,0), (3,0), (0,1), (2,1), (4,1), (1,2), (3,2), (2,3)]
        case .hexagon: return [(1,0), (2,0), (0,1), (3,1), (0,2), (3,2), (1,3), (2,3)]
        case .spiral: return [(0,0), (1,0), (2,0), (2,1), (2,2), (1,2), (0,2), (0,1)]
        case .zigzag: return [(0,0), (1,0), (1,1), (2,1), (2,2), (3,2)]
        }
    }

    @inline(__always)
    var requiredLevel: Int {
        switch self {
        case .single, .tinyLUp, .tinyLDown, .tinyLLeft, .tinyLRight, .tinyI,
             .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square: return 1
        case .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight: return 2
        case .zShape, .plus, .cross: return 3
        case .uShape, .vShape: return 4
        case .wShape, .xShape: return 5
        case .yShape, .zShape2: return 6
        case .rect2x3, .rect3x2: return 10
        case .rect3x3: return 15
        case .star: return 125
        case .diamond: return 200
        case .hexagon: return 300
        case .spiral: return 400
        case .zigzag: return 500
        }
    }

    static func random(for level: Int) -> BlockShape {
        allCases.lazy.filter { $0.requiredLevel <= level }.randomElement() ?? .bar2H
    }

    var isBasicShape: Bool {
        switch self {
        case .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square,
             .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight:
            return true
        default:
            return false
        }
    }

    @inline(__always)
    var complexity: Int {
        switch self {
        case .single, .tinyLUp, .tinyLDown, .tinyLLeft, .tinyLRight, .tinyI: return 1
        case .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square: return 2
        case .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight: return 3
        case .zShape, .plus, .cross: return 4
        case .uShape, .vShape, .wShape: return 5
        case .xShape, .yShape, .zShape2: return 6
        case .rect2x3, .rect3x2: return 7
        case .rect3x3: return 8
        case .star, .diamond: return 9
        case .hexagon, .spiral: return 10
        case .zigzag: return 11
        }
    }

    static func availableShapes(for level: Int, adjustedDifficulty: AdaptiveDifficultyManager.DifficultySettings? = nil) -> [BlockShape] {
        var result: [BlockShape] = []
        result.reserveCapacity(33)
        
        // Base shape availability based on level
        if level <= 25 { result.append(.single) }
        if level <= 35 { result += [.tinyLUp, .tinyLDown, .tinyLLeft, .tinyLRight, .tinyI] }
        
        result += [
            .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square,
            .lUp, .lDown, .lLeft, .lRight,
            .tUp, .tDown, .tLeft, .tRight
        ]
        
        if level >= 10 { result += [.plus] }
        if level >= 15 { result += [.zShape] }
        if level >= 20 { result += [.cross, .uShape, .vShape, .wShape] }
        if level >= 30 { result += [.xShape, .yShape, .zShape2] }
        if level >= 50 { result += [.rect2x3, .rect3x2] }
        if level >= 75 { result.append(.rect3x3) }
        if level >= 100 { result.append(.star) }
        if level >= 125 { result.append(.diamond) }
        if level >= 150 { result.append(.hexagon) }
        if level >= 200 { result.append(.spiral) }
        if level >= 300 { result.append(.zigzag) }
        
        // Apply adaptive difficulty adjustments if available
        if let difficulty = adjustedDifficulty {
            // Filter shapes based on complexity multiplier
            let maxComplexity = Int(11.0 * difficulty.shapeComplexityMultiplier)
            result = result.filter { $0.complexity <= maxComplexity }
            
            // Ensure we have at least some basic shapes available
            if result.isEmpty {
                result = [.bar2H, .bar2V, .bar3H, .bar3V, .square]
            }
        }
        
        return result
    }
}
