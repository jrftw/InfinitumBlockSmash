import Foundation
import SwiftUI

// MARK: - Game Board
class GameBoard {
    var grid: [[Block?]]
    var tray: [Block]
    
    init() {
        self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        self.tray = []
    }
} 