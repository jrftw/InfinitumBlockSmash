import Foundation

struct GameProgress: Codable {
    let score: Int
    let level: Int
    let blocksPlaced: Int
    let linesCleared: Int
    let gamesCompleted: Int
    let perfectLevels: Int
    let totalPlayTime: TimeInterval
    let highScore: Int
    let highestLevel: Int
    let grid: [[BlockColor?]]
    let tray: [Block]
    
    init(
        score: Int = 0,
        level: Int = 1,
        blocksPlaced: Int = 0,
        linesCleared: Int = 0,
        gamesCompleted: Int = 0,
        perfectLevels: Int = 0,
        totalPlayTime: TimeInterval = 0,
        highScore: Int = 0,
        highestLevel: Int = 1,
        grid: [[BlockColor?]] = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize),
        tray: [Block] = []
    ) {
        self.score = score
        self.level = level
        self.blocksPlaced = blocksPlaced
        self.linesCleared = linesCleared
        self.gamesCompleted = gamesCompleted
        self.perfectLevels = perfectLevels
        self.totalPlayTime = totalPlayTime
        self.highScore = highScore
        self.highestLevel = highestLevel
        self.grid = grid
        self.tray = tray
    }
    
    // MARK: - Dictionary Conversion
    
    var dictionary: [String: Any] {
        return [
            "score": score,
            "level": level,
            "blocksPlaced": blocksPlaced,
            "linesCleared": linesCleared,
            "gamesCompleted": gamesCompleted,
            "perfectLevels": perfectLevels,
            "totalPlayTime": totalPlayTime,
            "highScore": highScore,
            "highestLevel": highestLevel,
            "grid": grid.map { row in row.map { $0?.rawValue ?? "nil" } },
            "tray": tray.map { block in
                [
                    "color": block.color.rawValue,
                    "shape": block.shape.rawValue
                ]
            }
        ]
    }
    
    init?(dictionary: [String: Any]) {
        guard let score = dictionary["score"] as? Int,
              let level = dictionary["level"] as? Int,
              let blocksPlaced = dictionary["blocksPlaced"] as? Int,
              let linesCleared = dictionary["linesCleared"] as? Int,
              let gamesCompleted = dictionary["gamesCompleted"] as? Int,
              let perfectLevels = dictionary["perfectLevels"] as? Int,
              let totalPlayTime = dictionary["totalPlayTime"] as? TimeInterval,
              let highScore = dictionary["highScore"] as? Int,
              let highestLevel = dictionary["highestLevel"] as? Int,
              let gridData = dictionary["grid"] as? [[String]],
              let trayData = dictionary["tray"] as? [[String: String]] else {
            return nil
        }
        
        // Convert grid data
        let grid = gridData.map { row in
            row.map { colorString in
                colorString == "nil" ? nil : BlockColor(rawValue: colorString)
            }
        }
        
        // Convert tray data
        let tray = trayData.compactMap { blockData -> Block? in
            guard let colorString = blockData["color"],
                  let shapeString = blockData["shape"],
                  let color = BlockColor(rawValue: colorString),
                  let shape = BlockShape(rawValue: shapeString) else {
                return nil
            }
            return Block(color: color, shape: shape)
        }
        
        self.init(
            score: score,
            level: level,
            blocksPlaced: blocksPlaced,
            linesCleared: linesCleared,
            gamesCompleted: gamesCompleted,
            perfectLevels: perfectLevels,
            totalPlayTime: totalPlayTime,
            highScore: highScore,
            highestLevel: highestLevel,
            grid: grid,
            tray: tray
        )
    }
} 