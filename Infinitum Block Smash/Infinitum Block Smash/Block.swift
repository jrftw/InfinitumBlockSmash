import Foundation
import SwiftUI

struct Block: Identifiable, Codable {
    var id: UUID
    let color: BlockColor
    let shape: BlockShape
    var position: CGPoint
    
    init(color: BlockColor, shape: BlockShape = BlockShape.random(for: 1)) {
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

enum BlockColor: String, CaseIterable, Codable {
    case red = "red"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case purple = "purple"
    case orange = "orange"
    case pink = "pink"
    case cyan = "cyan"
    
    var gradientColors: (start: CGColor, end: CGColor) {
        switch self {
        case .red:
            return (
                CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),
                CGColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)
            )
        case .blue:
            return (
                CGColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0),
                CGColor(red: 0.1, green: 0.2, blue: 0.8, alpha: 1.0)
            )
        case .green:
            return (
                CGColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0),
                CGColor(red: 0.1, green: 0.6, blue: 0.1, alpha: 1.0)
            )
        case .yellow:
            return (
                CGColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1.0),
                CGColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0)
            )
        case .purple:
            return (
                CGColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0),
                CGColor(red: 0.4, green: 0.1, blue: 0.6, alpha: 1.0)
            )
        case .orange:
            return (
                CGColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
                CGColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1.0)
            )
        case .pink:
            return (
                CGColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0),
                CGColor(red: 0.8, green: 0.2, blue: 0.5, alpha: 1.0)
            )
        case .cyan:
            return (
                CGColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0),
                CGColor(red: 0.1, green: 0.6, blue: 0.6, alpha: 1.0)
            )
        }
    }
    
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
    
    var color: Color {
        Color(cgColor: gradientColors.start)
    }
    
    static func random() -> BlockColor {
        return allCases.randomElement() ?? .red
    }
}

// BlockShape: defines the arrangement of cells for a block
enum BlockShape: String, CaseIterable, Codable {
    // Single block
    case single
    // Tiny L shapes (3 blocks)
    case tinyLUp, tinyLDown, tinyLLeft, tinyLRight
    // Tiny I shapes (3 blocks)
    case tinyI
    // I (bar) shapes
    case bar2H, bar2V
    case bar3H, bar3V
    case bar4H, bar4V
    // Square
    case square
    // Rectangles
    case rect2x3, rect3x2, rect3x3
    // L shapes (4 rotations)
    case lUp, lDown, lLeft, lRight
    // T shapes (4 rotations)
    case tUp, tDown, tLeft, tRight
    // ... other shapes as before
    case zShape, plus, cross, uShape, vShape, wShape, xShape, yShape, zShape2
    // Master shapes
    case star, diamond, hexagon, spiral, zigzag
    
    var cells: [(Int, Int)] {
        switch self {
        // Single block
        case .single: return [(0,0)]
        // Tiny L shapes
        case .tinyLUp: return [(0,0), (0,1), (1,1)]
        case .tinyLDown: return [(1,0), (1,1), (0,1)]
        case .tinyLLeft: return [(0,0), (1,0), (1,1)]
        case .tinyLRight: return [(0,0), (0,1), (1,0)]
        // Tiny I shape
        case .tinyI: return [(0,0), (0,1), (0,2)]
        // I (bar) shapes
        case .bar2H: return [(0,0), (1,0)]
        case .bar2V: return [(0,0), (0,1)]
        case .bar3H: return [(0,0), (1,0), (2,0)]
        case .bar3V: return [(0,0), (0,1), (0,2)]
        case .bar4H: return [(0,0), (1,0), (2,0), (3,0)]
        case .bar4V: return [(0,0), (0,1), (0,2), (0,3)]
        // Square
        case .square: return [(0,0), (1,0), (0,1), (1,1)]
        // Rectangles
        case .rect2x3: return [(0,0), (1,0), (0,1), (1,1), (0,2), (1,2)]
        case .rect3x2: return [(0,0), (1,0), (2,0), (0,1), (1,1), (2,1)]
        case .rect3x3: return [(0,0), (1,0), (2,0), (0,1), (1,1), (2,1), (0,2), (1,2), (2,2)]
        // L shapes
        case .lUp:    return [(0,0), (0,1), (0,2), (1,2)]
        case .lDown:  return [(1,0), (1,1), (1,2), (0,2)]
        case .lLeft:  return [(0,0), (1,0), (2,0), (2,1)]
        case .lRight: return [(0,1), (1,1), (2,1), (2,0)]
        // T shapes
        case .tUp:    return [(0,0), (1,0), (2,0), (1,1)]
        case .tDown:  return [(0,1), (1,1), (2,1), (1,0)]
        case .tLeft:  return [(0,0), (0,1), (0,2), (1,1)]
        case .tRight: return [(1,0), (1,1), (1,2), (0,1)]
        // ... other shapes as before
        case .zShape: return [(0,0), (1,0), (1,1), (2,1)]
        case .plus: return [(1,0), (0,1), (1,1), (2,1), (1,2)]
        case .cross: return [(0,0), (2,0), (1,1), (0,2), (2,2)]
        case .uShape: return [(0,0), (2,0), (0,1), (1,1), (2,1)]
        case .vShape: return [(0,0), (0,1), (1,1), (2,1), (2,2)]
        case .wShape: return [(0,0), (0,1), (1,1), (2,1), (2,2), (3,2)]
        case .xShape: return [(0,0), (2,0), (1,1), (0,2), (2,2)]
        case .yShape: return [(0,0), (0,1), (1,1), (0,2), (0,3)]
        case .zShape2: return [(0,0), (1,0), (2,0), (2,1), (2,2)]
        // Master shapes
        case .star: return [
            (1,0), (3,0),  // Top points
            (0,1), (2,1), (4,1),  // Middle row
            (1,2), (3,2),  // Bottom points
            (2,3)  // Bottom center
        ]
        case .diamond: return [
            (1,0), (3,0),  // Top points
            (0,1), (2,1), (4,1),  // Middle row
            (1,2), (3,2),  // Bottom points
            (2,3)  // Bottom center
        ]
        case .hexagon: return [
            (1,0), (2,0),  // Top
            (0,1), (3,1),  // Upper sides
            (0,2), (3,2),  // Lower sides
            (1,3), (2,3)   // Bottom
        ]
        case .spiral: return [
            (0,0), (1,0), (2,0),  // Top row
            (2,1), (2,2),  // Right side
            (1,2), (0,2),  // Bottom row
            (0,1)  // Left side
        ]
        case .zigzag: return [
            (0,0), (1,0),  // First zig
            (1,1), (2,1),  // First zag
            (2,2), (3,2)   // Second zig
        ]
        }
    }
    
    // Level at which this shape becomes available
    var requiredLevel: Int {
        switch self {
        case .single: return 1
        case .tinyLUp, .tinyLDown, .tinyLLeft, .tinyLRight, .tinyI: return 1
        case .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square: return 1
        case .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight: return 2
        case .zShape, .plus, .cross: return 3
        case .uShape, .vShape: return 4
        case .wShape, .xShape: return 5
        case .yShape, .zShape2: return 6
        case .rect2x3, .rect3x2: return 10
        case .rect3x3: return 15
        // Master shapes
        case .star: return 125
        case .diamond: return 200
        case .hexagon: return 300
        case .spiral: return 400
        case .zigzag: return 500
        }
    }
    
    static func random(for level: Int) -> BlockShape {
        let availableShapes = BlockShape.allCases.filter { $0.requiredLevel <= level }
        return availableShapes.randomElement() ?? .bar2H
    }
} 
