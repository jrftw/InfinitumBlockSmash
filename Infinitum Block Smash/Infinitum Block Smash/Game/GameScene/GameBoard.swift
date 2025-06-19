/*
 * FILE: GameBoard.swift
 * PURPOSE: Defines the game board data structure
 * DEPENDENCIES:
 *    - Block.swift (for block definitions)
 *    - GameConstants.swift (for grid size)
 * AUTHOR: @jrftw
 * LAST UPDATED: 6/19/2025
 */

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