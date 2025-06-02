import Foundation
import SwiftUI

struct Block: Identifiable {
    let id = UUID()
    let color: BlockColor
    let shape: BlockShape
    var position: CGPoint
    
    init(color: BlockColor, shape: BlockShape = BlockShape.random(for: 1)) {
        self.position = .zero
        self.color = color
        self.shape = shape
    }
}

enum BlockColor: String, CaseIterable {
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
enum BlockShape: String, CaseIterable {
    // I (bar) shapes
    case bar2H, bar2V
    case bar3H, bar3V
    case bar4H, bar4V
    // Square
    case square
    // L shapes (4 rotations)
    case lUp, lDown, lLeft, lRight
    // T shapes (4 rotations)
    case tUp, tDown, tLeft, tRight
    // ... other shapes as before
    case zShape, plus, cross, uShape, vShape, wShape, xShape, yShape, zShape2
    
    var cells: [(Int, Int)] {
        switch self {
        // I (bar) shapes
        case .bar2H: return [(0,0), (1,0)]
        case .bar2V: return [(0,0), (0,1)]
        case .bar3H: return [(0,0), (1,0), (2,0)]
        case .bar3V: return [(0,0), (0,1), (0,2)]
        case .bar4H: return [(0,0), (1,0), (2,0), (3,0)]
        case .bar4V: return [(0,0), (0,1), (0,2), (0,3)]
        // Square
        case .square: return [(0,0), (1,0), (0,1), (1,1)]
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
        }
    }
    
    // Level at which this shape becomes available
    var requiredLevel: Int {
        switch self {
        case .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square: return 1
        case .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight: return 2
        case .zShape, .plus, .cross: return 3
        case .uShape, .vShape: return 4
        case .wShape, .xShape: return 5
        case .yShape, .zShape2: return 6
        }
    }
    
    static func random(for level: Int) -> BlockShape {
        let availableShapes = BlockShape.allCases.filter { $0.requiredLevel <= level }
        return availableShapes.randomElement() ?? .bar2H
    }
} 
