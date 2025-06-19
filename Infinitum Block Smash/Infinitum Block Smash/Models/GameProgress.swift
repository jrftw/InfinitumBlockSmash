/*
 * FILE: GameProgress.swift
 * PURPOSE: Defines game progress data structure for persistence and cloud sync
 * DEPENDENCIES:
 *    - Block.swift (for block definitions)
 *    - GameDataVersion.swift (for version management)
 *    - GameConstants.swift (for grid size)
 * AUTHOR: @jrftw
 * LAST UPDATED: 6/19/2025
 */

import Foundation

// MARK: - GameProgress
struct GameProgress: Codable {
    let version: Int
    let score: Int
    let level: Int
    let blocksPlaced: Int
    let linesCleared: Int
    let gamesCompleted: Int
    let perfectLevels: Int
    let totalPlayTime: Double
    let highScore: Int
    let highestLevel: Int
    let grid: [[String]]
    let tray: [Block]
    let lastSaveTime: Date
    
    init(
        score: Int = 0,
        level: Int = 1,
        blocksPlaced: Int = 0,
        linesCleared: Int = 0,
        gamesCompleted: Int = 0,
        perfectLevels: Int = 0,
        totalPlayTime: Double = 0,
        highScore: Int = 0,
        highestLevel: Int = 1,
        grid: Any = Array(repeating: Array(repeating: "nil", count: GameConstants.gridSize), count: GameConstants.gridSize),
        tray: [Block] = [],
        lastSaveTime: Date = Date()
    ) {
        self.version = GameDataVersion.currentVersion
        self.score = score
        self.level = level
        self.blocksPlaced = blocksPlaced
        self.linesCleared = linesCleared
        self.gamesCompleted = gamesCompleted
        self.perfectLevels = perfectLevels
        self.totalPlayTime = totalPlayTime
        self.highScore = highScore
        self.highestLevel = highestLevel
        
        // Handle both grid formats
        if let stringGrid = grid as? [[String]] {
            self.grid = stringGrid
        } else if let blockGrid = grid as? [[BlockColor?]] {
            self.grid = blockGrid.map { row in
                row.map { color in
                    color?.rawValue ?? "nil"
                }
            }
        } else {
            self.grid = Array(repeating: Array(repeating: "nil", count: GameConstants.gridSize), count: GameConstants.gridSize)
        }
        
        self.tray = tray
        self.lastSaveTime = lastSaveTime
    }
    
    // MARK: - Dictionary Conversion
    
    var dictionary: [String: Any] {
        // Flatten the grid into a single array of strings
        let flattenedGrid = grid.flatMap { $0 }
        
        return [
            "version": version,
            "score": score,
            "level": level,
            "blocksPlaced": blocksPlaced,
            "linesCleared": linesCleared,
            "gamesCompleted": gamesCompleted,
            "perfectLevels": perfectLevels,
            "totalPlayTime": totalPlayTime,
            "highScore": highScore,
            "highestLevel": highestLevel,
            "gridSize": GameConstants.gridSize,  // Store the size to reconstruct the grid
            "gridData": flattenedGrid,  // Store as flat array
            "tray": tray.map { block in
                [
                    "color": block.color.rawValue,
                    "shape": block.shape.rawValue
                ]
            },
            "lastSaveTime": lastSaveTime
        ]
    }
    
    init?(dictionary: [String: Any]) {
        // Validate data version
        guard GameDataVersion.validateData(dictionary) else { return nil }
        
        guard let version = dictionary["version"] as? Int,
              let score = dictionary["score"] as? Int,
              let level = dictionary["level"] as? Int,
              let blocksPlaced = dictionary["blocksPlaced"] as? Int,
              let linesCleared = dictionary["linesCleared"] as? Int,
              let gamesCompleted = dictionary["gamesCompleted"] as? Int,
              let perfectLevels = dictionary["perfectLevels"] as? Int,
              let totalPlayTime = dictionary["totalPlayTime"] as? Double,
              let highScore = dictionary["highScore"] as? Int,
              let highestLevel = dictionary["highestLevel"] as? Int,
              let gridSize = dictionary["gridSize"] as? Int,
              let gridData = dictionary["gridData"] as? [String],
              let trayData = dictionary["tray"] as? [[String: Any]],
              let lastSaveTime = dictionary["lastSaveTime"] as? Date else {
            return nil
        }
        
        self.version = version
        self.score = score
        self.level = level
        self.blocksPlaced = blocksPlaced
        self.linesCleared = linesCleared
        self.gamesCompleted = gamesCompleted
        self.perfectLevels = perfectLevels
        self.totalPlayTime = totalPlayTime
        self.highScore = highScore
        self.highestLevel = highestLevel
        
        // Reconstruct the grid from flat array
        var reconstructedGrid: [[String]] = []
        for i in 0..<gridSize {
            let start = i * gridSize
            let end = start + gridSize
            reconstructedGrid.append(Array(gridData[start..<end]))
        }
        self.grid = reconstructedGrid
        
        self.tray = trayData.compactMap { blockData in
            guard let colorString = blockData["color"] as? String,
                  let shapeString = blockData["shape"] as? String,
                  let color = BlockColor(rawValue: colorString),
                  let shape = BlockShape(rawValue: shapeString) else {
                return nil
            }
            return Block(color: color, shape: shape)
        }
        self.lastSaveTime = lastSaveTime
    }
} 