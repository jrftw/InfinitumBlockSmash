import Foundation

enum GameDifficulty: String, CaseIterable {
    case easy
    case normal
    case hard
    case expert
    
    var scoreMultiplier: Double {
        switch self {
        case .easy: return 0.8
        case .normal: return 1.0
        case .hard: return 1.5
        case .expert: return 2.0
        }
    }
    
    var blockSpeed: Double {
        switch self {
        case .easy: return 0.8
        case .normal: return 1.0
        case .hard: return 1.2
        case .expert: return 1.5
        }
    }
    
    var availableShapes: [BlockShape] {
        switch self {
        case .easy:
            return [.bar2H, .bar2V, .square]
        case .normal:
            return [.bar2H, .bar2V, .square, .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight]
        case .hard:
            return [.bar2H, .bar2V, .square, .lUp, .lDown, .lLeft, .lRight, .tUp, .tDown, .tLeft, .tRight, .zShape]
        case .expert:
            return BlockShape.allCases
        }
    }
    
    var availableColors: [BlockColor] {
        switch self {
        case .easy:
            return [.red, .blue, .green]
        case .normal:
            return [.red, .blue, .green, .yellow, .purple]
        case .hard:
            return [.red, .blue, .green, .yellow, .purple, .orange, .pink]
        case .expert:
            return BlockColor.allCases
        }
    }
} 