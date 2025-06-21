/******************************************************
 * FILE: GameProgress.swift
 * MARK: Game Progress Data Model and Persistence System
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Defines the comprehensive game progress data structure for persistence,
 * cloud synchronization, and game state restoration. This file manages
 * all aspects of game state that need to be saved and restored across
 * sessions and devices.
 *
 * KEY RESPONSIBILITIES:
 * - Complete game state data structure definition
 * - Game progress persistence and restoration
 * - Cloud synchronization data management
 * - Version control and data migration
 * - Undo stack state preservation
 * - User preferences and settings storage
 * - Performance metrics and statistics tracking
 * - Cross-device data compatibility
 * - Data validation and integrity checking
 * - Memory-efficient data serialization
 *
 * MAJOR DEPENDENCIES:
 * - Block.swift: Block data model and properties
 * - GameDataVersion.swift: Version management and migration
 * - GameConstants.swift: Game configuration constants
 * - GameMove.swift: Undo stack and move history
 * - Foundation: Core framework for data structures and Codable
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for data structures and serialization
 * - Codable: Data persistence and cloud synchronization
 *
 * ARCHITECTURE ROLE:
 * Acts as the central data model for game persistence, providing
 * a complete snapshot of game state that can be saved, restored,
 * and synchronized across devices and sessions.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Version control ensures data compatibility across app updates
 * - Grid data serialization optimizes storage efficiency
 * - Undo stack limits prevent excessive storage usage
 * - Data validation maintains state integrity
 * - Cross-device compatibility requires careful data formatting
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
    
    // NEW: Additional game state components
    let temporaryScore: Int
    let currentChain: Int
    let usedColors: [String] // Serialized Set<BlockColor>
    let usedShapes: [String] // Serialized Set<BlockShape>
    let isPerfectLevel: Bool
    let undoCount: Int
    let adUndoCount: Int
    let hasUsedContinueAd: Bool
    let levelsCompletedSinceLastAd: Int
    let adsWatchedThisGame: Int
    let isPaused: Bool
    let targetFPS: Int
    let gameStartTime: Date?
    let lastPlayDate: Date?
    let consecutiveDays: Int
    let totalTime: TimeInterval
    
    // NEW: Preview placement state
    let previewEnabled: Bool
    let previewHeightOffset: Double
    
    // NEW: Game-specific settings and flags
    let isTimedMode: Bool
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let musicVolume: Double
    let sfxVolume: Double
    let difficulty: String
    let theme: String
    let autoSave: Bool
    let placementPrecision: Double
    let blockDragOffset: Double
    
    // NEW: Undo stack state (limited to prevent excessive storage)
    let undoStack: [GameMove] // Limited to last 5 moves for storage efficiency
    
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
        lastSaveTime: Date = Date(),
        // NEW: Additional parameters
        temporaryScore: Int = 0,
        currentChain: Int = 0,
        usedColors: Set<BlockColor> = [],
        usedShapes: Set<BlockShape> = [],
        isPerfectLevel: Bool = true,
        undoCount: Int = 0,
        adUndoCount: Int = 3,
        hasUsedContinueAd: Bool = false,
        levelsCompletedSinceLastAd: Int = 0,
        adsWatchedThisGame: Int = 0,
        isPaused: Bool = false,
        targetFPS: Int = 60,
        gameStartTime: Date? = nil,
        lastPlayDate: Date? = nil,
        consecutiveDays: Int = 0,
        totalTime: TimeInterval = 0,
        previewEnabled: Bool = true,
        previewHeightOffset: Double = 0.0,
        isTimedMode: Bool = false,
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        musicVolume: Double = 1.0,
        sfxVolume: Double = 1.0,
        difficulty: String = "normal",
        theme: String = "auto",
        autoSave: Bool = true,
        placementPrecision: Double = 0.15,
        blockDragOffset: Double = 0.4,
        undoStack: [GameMove] = []
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
        
        // NEW: Set additional properties
        self.temporaryScore = temporaryScore
        self.currentChain = currentChain
        self.usedColors = usedColors.map { $0.rawValue }
        self.usedShapes = usedShapes.map { $0.rawValue }
        self.isPerfectLevel = isPerfectLevel
        self.undoCount = undoCount
        self.adUndoCount = adUndoCount
        self.hasUsedContinueAd = hasUsedContinueAd
        self.levelsCompletedSinceLastAd = levelsCompletedSinceLastAd
        self.adsWatchedThisGame = adsWatchedThisGame
        self.isPaused = isPaused
        self.targetFPS = targetFPS
        self.gameStartTime = gameStartTime
        self.lastPlayDate = lastPlayDate
        self.consecutiveDays = consecutiveDays
        self.totalTime = totalTime
        self.previewEnabled = previewEnabled
        self.previewHeightOffset = previewHeightOffset
        self.isTimedMode = isTimedMode
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.musicVolume = musicVolume
        self.sfxVolume = sfxVolume
        self.difficulty = difficulty
        self.theme = theme
        self.autoSave = autoSave
        self.placementPrecision = placementPrecision
        self.blockDragOffset = blockDragOffset
        self.undoStack = undoStack
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
            "lastSaveTime": lastSaveTime.timeIntervalSince1970,
            // NEW: Additional properties
            "temporaryScore": temporaryScore,
            "currentChain": currentChain,
            "usedColors": usedColors,
            "usedShapes": usedShapes,
            "isPerfectLevel": isPerfectLevel,
            "undoCount": undoCount,
            "adUndoCount": adUndoCount,
            "hasUsedContinueAd": hasUsedContinueAd,
            "levelsCompletedSinceLastAd": levelsCompletedSinceLastAd,
            "adsWatchedThisGame": adsWatchedThisGame,
            "isPaused": isPaused,
            "targetFPS": targetFPS,
            "gameStartTime": gameStartTime?.timeIntervalSince1970 as Any,
            "lastPlayDate": lastPlayDate?.timeIntervalSince1970 as Any,
            "consecutiveDays": consecutiveDays,
            "totalTime": totalTime,
            "previewEnabled": previewEnabled,
            "previewHeightOffset": previewHeightOffset,
            "isTimedMode": isTimedMode,
            "soundEnabled": soundEnabled,
            "hapticsEnabled": hapticsEnabled,
            "musicVolume": musicVolume,
            "sfxVolume": sfxVolume,
            "difficulty": difficulty,
            "theme": theme,
            "autoSave": autoSave,
            "placementPrecision": placementPrecision,
            "blockDragOffset": blockDragOffset,
            "undoStack": undoStack.map { move in
                [
                    "block": [
                        "color": move.block.color.rawValue,
                        "shape": move.block.shape.rawValue
                    ],
                    "position": ["row": move.position.row, "col": move.position.col],
                    "previousGridSize": GameConstants.gridSize,
                    "previousGridData": move.previousGrid.flatMap { row in
                        row.map { color in
                            color?.rawValue ?? "nil"
                        }
                    },
                    "previousTray": move.previousTray.map { block in
                        [
                            "color": block.color.rawValue,
                            "shape": block.shape.rawValue
                        ]
                    },
                    "previousScore": move.previousScore,
                    "previousLevel": move.previousLevel,
                    "previousBlocksPlaced": move.previousBlocksPlaced,
                    "previousLinesCleared": move.previousLinesCleared,
                    "previousCurrentChain": move.previousCurrentChain,
                    "previousUsedColors": move.previousUsedColors.map { $0.rawValue },
                    "previousUsedShapes": move.previousUsedShapes.map { $0.rawValue },
                    "previousIsPerfectLevel": move.previousIsPerfectLevel,
                    "timestamp": move.timestamp?.timeIntervalSince1970 as Any
                ]
            }
        ]
    }
    
    init?(dictionary: [String: Any]) {
        print("[GameProgress] Attempting to parse dictionary: \(dictionary)")
        
        // Validate data version
        guard GameDataVersion.validateData(dictionary) else { 
            print("[GameProgress] Data validation failed")
            return nil 
        }
        
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
              let lastSaveTime = dictionary["lastSaveTime"] as? TimeInterval else {
            print("[GameProgress] Failed to parse required fields from dictionary")
            print("[GameProgress] version: \(dictionary["version"] as? Int ?? -1)")
            print("[GameProgress] score: \(dictionary["score"] as? Int ?? -1)")
            print("[GameProgress] level: \(dictionary["level"] as? Int ?? -1)")
            print("[GameProgress] blocksPlaced: \(dictionary["blocksPlaced"] as? Int ?? -1)")
            print("[GameProgress] gridSize: \(dictionary["gridSize"] as? Int ?? -1)")
            print("[GameProgress] gridData: \(dictionary["gridData"] as? [String] ?? [])")
            print("[GameProgress] trayData: \(dictionary["tray"] as? [[String: Any]] ?? [])")
            print("[GameProgress] lastSaveTime: \(dictionary["lastSaveTime"] as? TimeInterval ?? -1)")
            return nil
        }
        
        print("[GameProgress] Successfully parsed all required fields")
        
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
        
        self.tray = trayData.compactMap { blockData -> Block? in
            guard let colorString = blockData["color"] as? String,
                  let shapeString = blockData["shape"] as? String,
                  let color = BlockColor(rawValue: colorString),
                  let shape = BlockShape(rawValue: shapeString) else {
                return nil
            }
            return Block(color: color, shape: shape)
        }
        self.lastSaveTime = Date(timeIntervalSince1970: lastSaveTime)
        
        // NEW: Load additional properties with defaults
        self.temporaryScore = dictionary["temporaryScore"] as? Int ?? 0
        self.currentChain = dictionary["currentChain"] as? Int ?? 0
        let usedColorsStrings = dictionary["usedColors"] as? [String] ?? []
        self.usedColors = usedColorsStrings
        let usedShapesStrings = dictionary["usedShapes"] as? [String] ?? []
        self.usedShapes = usedShapesStrings
        self.isPerfectLevel = dictionary["isPerfectLevel"] as? Bool ?? true
        self.undoCount = dictionary["undoCount"] as? Int ?? 0
        self.adUndoCount = dictionary["adUndoCount"] as? Int ?? 3
        self.hasUsedContinueAd = dictionary["hasUsedContinueAd"] as? Bool ?? false
        self.levelsCompletedSinceLastAd = dictionary["levelsCompletedSinceLastAd"] as? Int ?? 0
        self.adsWatchedThisGame = dictionary["adsWatchedThisGame"] as? Int ?? 0
        self.isPaused = dictionary["isPaused"] as? Bool ?? false
        self.targetFPS = dictionary["targetFPS"] as? Int ?? 60
        self.gameStartTime = {
            if let timeInterval = dictionary["gameStartTime"] as? TimeInterval {
                return Date(timeIntervalSince1970: timeInterval)
            }
            return nil
        }()
        self.lastPlayDate = {
            if let timeInterval = dictionary["lastPlayDate"] as? TimeInterval {
                return Date(timeIntervalSince1970: timeInterval)
            }
            return nil
        }()
        self.consecutiveDays = dictionary["consecutiveDays"] as? Int ?? 0
        self.totalTime = dictionary["totalTime"] as? TimeInterval ?? 0
        self.previewEnabled = dictionary["previewEnabled"] as? Bool ?? true
        self.previewHeightOffset = dictionary["previewHeightOffset"] as? Double ?? 0.0
        self.isTimedMode = dictionary["isTimedMode"] as? Bool ?? false
        self.soundEnabled = dictionary["soundEnabled"] as? Bool ?? true
        self.hapticsEnabled = dictionary["hapticsEnabled"] as? Bool ?? true
        self.musicVolume = dictionary["musicVolume"] as? Double ?? 1.0
        self.sfxVolume = dictionary["sfxVolume"] as? Double ?? 1.0
        self.difficulty = dictionary["difficulty"] as? String ?? "normal"
        self.theme = dictionary["theme"] as? String ?? "auto"
        self.autoSave = dictionary["autoSave"] as? Bool ?? true
        self.placementPrecision = dictionary["placementPrecision"] as? Double ?? 0.15
        self.blockDragOffset = dictionary["blockDragOffset"] as? Double ?? 0.4
        
        // Load undo stack
        let undoStackData = dictionary["undoStack"] as? [[String: Any]] ?? []
        self.undoStack = undoStackData.compactMap { moveData -> GameMove? in
            guard let blockData = moveData["block"] as? [String: Any],
                  let colorString = blockData["color"] as? String,
                  let shapeString = blockData["shape"] as? String,
                  let color = BlockColor(rawValue: colorString),
                  let shape = BlockShape(rawValue: shapeString),
                  let positionData = moveData["position"] as? [String: Any],
                  let row = positionData["row"] as? Int,
                  let col = positionData["col"] as? Int,
                  let previousGridSize = moveData["previousGridSize"] as? Int,
                  let previousGridData = moveData["previousGridData"] as? [String],
                  let previousTrayData = moveData["previousTray"] as? [[String: Any]],
                  let previousScore = moveData["previousScore"] as? Int,
                  let previousLevel = moveData["previousLevel"] as? Int,
                  let previousBlocksPlaced = moveData["previousBlocksPlaced"] as? Int,
                  let previousLinesCleared = moveData["previousLinesCleared"] as? Int,
                  let previousCurrentChain = moveData["previousCurrentChain"] as? Int,
                  let previousUsedColorsData = moveData["previousUsedColors"] as? [String],
                  let previousUsedShapesData = moveData["previousUsedShapes"] as? [String],
                  let previousIsPerfectLevel = moveData["previousIsPerfectLevel"] as? Bool else {
                return nil
            }
            
            let block = Block(color: color, shape: shape)
            let position = (row: row, col: col)
            
            // Reconstruct the previousGrid from flat array
            var reconstructedPreviousGrid: [[BlockColor?]] = []
            for i in 0..<previousGridSize {
                let start = i * previousGridSize
                let end = start + previousGridSize
                let row = Array(previousGridData[start..<end]).map { colorString in
                    colorString == "nil" ? nil : BlockColor(rawValue: colorString)
                }
                reconstructedPreviousGrid.append(row)
            }
            
            let previousTray = previousTrayData.compactMap { blockData -> Block? in
                guard let colorString = blockData["color"] as? String,
                      let shapeString = blockData["shape"] as? String,
                      let color = BlockColor(rawValue: colorString),
                      let shape = BlockShape(rawValue: shapeString) else {
                    return nil
                }
                return Block(color: color, shape: shape)
            }
            
            let previousUsedColors = Set(previousUsedColorsData.compactMap { BlockColor(rawValue: $0) })
            let previousUsedShapes = Set(previousUsedShapesData.compactMap { BlockShape(rawValue: $0) })
            let timestamp: Date?
            if let timestampInterval = moveData["timestamp"] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: timestampInterval)
            } else {
                timestamp = nil
            }
            
            return GameMove(
                block: block,
                position: position,
                previousGrid: reconstructedPreviousGrid,
                previousTray: previousTray,
                previousScore: previousScore,
                previousLevel: previousLevel,
                previousBlocksPlaced: previousBlocksPlaced,
                previousLinesCleared: previousLinesCleared,
                previousCurrentChain: previousCurrentChain,
                previousUsedColors: previousUsedColors,
                previousUsedShapes: previousUsedShapes,
                previousIsPerfectLevel: previousIsPerfectLevel,
                timestamp: timestamp
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns the used colors as a Set<BlockColor>
    var usedColorsSet: Set<BlockColor> {
        Set(usedColors.compactMap { BlockColor(rawValue: $0) })
    }
    
    /// Returns the used shapes as a Set<BlockShape>
    var usedShapesSet: Set<BlockShape> {
        Set(usedShapes.compactMap { BlockShape(rawValue: $0) })
    }
    
    /// Checks if this represents a new game (no progress)
    var isNewGame: Bool {
        // Check if there's any actual game progress
        let hasScore = score > 0
        let hasBlocksPlaced = blocksPlaced > 0
        let hasGridBlocks = grid.flatMap { $0 }.contains { $0 != "nil" }
        let hasTrayBlocks = !tray.isEmpty
        
        // A game is considered "new" only if there's no meaningful progress
        // Having tray blocks counts as progress since it means the game has started
        // Having any score, blocks placed, or grid blocks also counts as progress
        return !hasScore && !hasBlocksPlaced && !hasGridBlocks && !hasTrayBlocks && level == 1
    }
    
    /// Creates a fresh game progress for new games
    static func newGame() -> GameProgress {
        return GameProgress()
    }
} 