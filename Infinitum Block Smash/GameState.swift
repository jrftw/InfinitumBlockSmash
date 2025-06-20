@MainActor
final class GameState: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var score: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var grid: [[Block?]] = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
    @Published private(set) var tray: [Block] = []
    @Published private(set) var achievementsManager = AchievementsManager()
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var levelComplete: Bool = false
    @Published private(set) var adUndoCount: Int = 0
    @Published private(set) var showingAchievementNotification: Bool = false
    @Published private(set) var currentAchievement: Achievement?
    @Published private(set) var blocksPlaced: Int = 0
    @Published private(set) var linesCleared: Int = 0
    @Published private(set) var gameStartTime: Date?
    @Published private(set) var lastPlayDate: Date?
    @Published private(set) var consecutiveDays: Int = 0
    @Published private(set) var currentChain: Int = 0
    @Published private(set) var usedColors: Set<BlockColor> = []
    @Published private(set) var usedShapes: Set<BlockShape> = []
    @Published private(set) var perfectLevels: Int = 0
    @Published private(set) var isPerfectLevel: Bool = true
    @Published private(set) var gamesCompleted: Int = 0
    @Published private(set) var undoCount: Int = 0
    
    // Add frame size property
    var frameSize: CGSize = .zero
    
    weak var delegate: GameStateDelegate?
    private var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
    private let traySize = 3
    
    private let userDefaults = UserDefaults.standard
    private let scoreKey = "highScore"
    private let levelKey = "highestLevel"
    private let progressKey = "gameProgress"
    
    // Undo support
    private var previousGrid: [[Block?]] = []
    private var previousTray: [Block] = []
    private var previousScore: Int = 0
    private var previousLevel: Int = 1
    
    var canAdUndo: Bool { adUndoCount > 0 }
    
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var lastMove: GameMove?
    private var gameBoard: GameBoard
    private var currentShapes: [any Shape]
    private var achievementCheckTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init() {
        self.gameBoard = GameBoard()
        self.currentShapes = []
        setupSubscriptions()
        setupInitialGame()
        gameStartTime = Date()
        loadLastPlayDate()
    }
    
    // MARK: - Private Methods
    private func setupInitialGame() {
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        refillTray()
        level = 1
        score = 0
        isGameOver = false
        levelComplete = false
        canUndo = false
        adUndoCount = 0
        blocksPlaced = 0
        linesCleared = 0
        currentChain = 0
        usedColors.removeAll()
        usedShapes.removeAll()
        isPerfectLevel = true
    }
    
    private func setupSubscriptions() {
        // Only subscribe to necessary publishers with debounce
        $score
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] newScore in
                self?.checkAchievements(for: newScore)
            }
            .store(in: &cancellables)
    }
    
    private func checkAchievements(for score: Int) {
        // Cancel any existing achievement check task
        achievementCheckTask?.cancel()
        
        // Create new task for achievement check
        achievementCheckTask = Task {
            do {
                let newAchievements = try await achievementsManager.checkAchievementProgress(score: score, level: level)
                if let achievement = newAchievements.first {
                    await MainActor.run {
                        self.currentAchievement = achievement
                        self.showingAchievementNotification = true
                        
                        // Auto-hide achievement notification after 3 seconds
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            await MainActor.run {
                                self.showingAchievementNotification = false
                                self.currentAchievement = nil
                            }
                        }
                    }
                }
            } catch {
                print("Error checking achievements: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Methods
    func resetGame() {
        // Cancel any ongoing tasks
        achievementCheckTask?.cancel()
        
        score = 0
        level = 1
        isGameOver = false
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        refillTray()
        levelComplete = false
        canUndo = false
        gameBoard = GameBoard()
        currentShapes = []
        lastMove = nil
        saveProgress()
        delegate?.gameStateDidUpdate()
    }
    
    func setSeed(for level: Int) {
        rng = SeededGenerator(seed: UInt64(level))
    }
    
    func nextBlockRandom() -> Block {
        let shape = BlockShape.availableShapes(for: level).randomElement(using: &rng) ?? .bar2H
        let color = BlockColor.availableColors(for: level).randomElement(using: &rng) ?? .red
        return Block(color: color, shape: shape)
    }
    
    private func refillTray() {
        // Keep 3 shapes in the tray, using nextBlockRandom for proper shape/level
        while tray.count < traySize {
            let newBlock = nextBlockRandom()
            tray.append(newBlock)
        }
        delegate?.gameStateDidUpdate()
    }
    
    func canPlaceBlockAnywhere(_ block: Block) -> Bool {
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if canPlaceBlock(block, at: CGPoint(x: col, y: row)) {
                    return true
                }
            }
        }
        return false
    }
    
    // Call this before placing a block
    private func saveStateForUndo() {
        previousGrid = grid.map { $0.map { $0 } }
        previousTray = tray.map { $0 }
        previousScore = score
        previousLevel = level
        canUndo = true
    }

    func undoLastMove() {
        guard canUndo && adUndoCount > 0 else { return }
        print("[Undo] Undoing last move. Restoring previous grid, tray, score, and level.")
        grid = previousGrid.map { $0.map { $0 } }
        tray = previousTray.map { $0 }
        score = previousScore
        level = previousLevel
        canUndo = false
        adUndoCount -= 1
        undoCount += 1
        isPerfectLevel = false
        delegate?.gameStateDidUpdate()
        checkAchievements()
    }

    // In tryPlaceBlockFromTray, save state before placement and reset undo after
    func tryPlaceBlockFromTray(_ block: Block, at anchor: CGPoint) -> Bool {
        // Don't allow placing blocks if game is over
        guard !isGameOver else { return false }
        
        guard let trayIndex = tray.firstIndex(where: { $0.id == block.id }) else { return false }
        if canPlaceBlock(block, at: anchor) {
            print("[Placement] Placing block \(block.shape.rawValue) at \(anchor)")
            saveStateForUndo()
            placeBlock(block, at: anchor)
            tray.remove(at: trayIndex)
            refillTray()
            checkMatches()
            checkGameOver()
            adUndoCount = 2 // Reset ad-based undos for this placement
            delegate?.gameStateDidUpdate()
            checkAchievements()
            return true
        }
        return false
    }
    
    private func anyTrayBlockFits() -> Bool {
        for block in tray {
            if canPlaceBlockAnywhere(block) {
                return true
            }
        }
        return false
    }
    
    func canPlaceBlock(_ block: Block, at anchor: CGPoint) -> Bool {
        // Check if any part of the shape would be outside the grid
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            
            // Check if the position is within grid bounds
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                return false
            }
            
            // Check if the position is already occupied
            if grid[y][x] != nil {
                return false
            }
        }
        
        // If we get here, the placement is valid
        return true
    }
    
    private func placeBlock(_ block: Block, at anchor: CGPoint) {
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                var placedBlock = Block(color: block.color, shape: block.shape)
                placedBlock.position = CGPoint(x: x, y: y)
                grid[y][x] = placedBlock
            }
        }
        blocksPlaced += 1
        usedColors.insert(block.color)
        usedShapes.insert(block.shape)
        isPerfectLevel = false
        checkAchievements()
    }
    
    private func checkMatches() {
        var clearedPositions: [(Int, Int)] = []
        var linesCleared = 0
        var colorMatchCount = 0
        
        // Check rows
        for row in 0..<GameConstants.gridSize {
            if isRowFull(row) {
                let rowColors = grid[row].compactMap { $0?.color }
                let allSameColor = rowColors.allSatisfy { $0 == rowColors.first }
                for col in 0..<GameConstants.gridSize {
                    clearedPositions.append((row, col))
                }
                clearRow(row)
                let position = CGPoint(x: frameSize.width/2, y: CGFloat(row) * GameConstants.blockSize)
                addScore(100, at: position)
                print("[Clear] Row \(row) cleared. +100 points.")
                if allSameColor && !rowColors.isEmpty {
                    colorMatchCount += 1
                    addScore(500, at: position) // Increased from 200 to 500 for color match
                    print("[Bonus] Row \(row) all same color (\(rowColors.first!)). +500 bonus points!")
                }
                linesCleared += 1
            }
        }
        
        // Check columns
        for col in 0..<GameConstants.gridSize {
            if isColumnFull(col) {
                let colColors = (0..<GameConstants.gridSize).compactMap { grid[$0][col]?.color }
                let allSameColor = colColors.allSatisfy { $0 == colColors.first }
                for row in 0..<GameConstants.gridSize {
                    clearedPositions.append((row, col))
                }
                clearColumn(col)
                let position = CGPoint(x: CGFloat(col) * GameConstants.blockSize, y: frameSize.height/2)
                addScore(100, at: position)
                print("[Clear] Column \(col) cleared. +100 points.")
                if allSameColor && !colColors.isEmpty {
                    colorMatchCount += 1
                    addScore(500, at: position) // Increased from 200 to 500 for color match
                    print("[Bonus] Column \(col) all same color (\(colColors.first!)). +500 bonus points!")
                }
                linesCleared += 1
            }
        }
        
        // Additional bonus for multiple color matches
        if colorMatchCount >= 2 {
            let multiMatchBonus = colorMatchCount * 1000
            addScore(multiMatchBonus, at: CGPoint(x: frameSize.width/2, y: frameSize.height/2))
            print("[Super Bonus] \(colorMatchCount) color matches! +\(multiMatchBonus) bonus points!")
        }
        
        if !clearedPositions.isEmpty {
            print("[Clear] Total lines cleared: \(linesCleared)")
            delegate?.gameStateDidClearLines(at: clearedPositions)
            achievementsManager.increment(id: "first_clear")
            if linesCleared >= 3 {
                achievementsManager.increment(id: "combo_3")
            }
            checkGroups()
        }
        
        if isGridEmpty() {
            print("[Level] Grid empty, leveling up.")
            levelUp()
        }
        
        linesCleared += linesCleared
        currentChain += 1
        checkAchievements()
    }
    
    func addScore(_ points: Int, at position: CGPoint? = nil) {
        let oldScore = score
        score += points
        print("[Score] Added \(points) points (from \(oldScore) to \(score))")
        
        // Show score animation if position is provided
        if let position = position {
            delegate?.showScoreAnimation(points: points, at: position)
        }
        
        achievementsManager.updateAchievement(id: "score_1000", value: score)
        // Global high score
        if score > userDefaults.integer(forKey: scoreKey) {
            achievementsManager.updateAchievement(id: "high_score", value: score)
            // Update leaderboard when new high score is achieved
            updateLeaderboard()
        }
        // Per-level high score
        let levelHighScoreKey = "highScore_level_\(level)"
        let prevLevelHigh = userDefaults.integer(forKey: levelHighScoreKey)
        if score > prevLevelHigh {
            userDefaults.set(score, forKey: levelHighScoreKey)
            print("[HighScore] New high score for level \(level): \(score)")
        }
        delegate?.gameStateDidUpdate()
        // Check for level up after every score change
        let requiredScore = calculateRequiredScore()
        if score >= requiredScore && !levelComplete {
            print("[Level] Score threshold met for level \(level). Level complete!")
            levelComplete = true
        }
        checkAchievements()
    }
    
    private func calculateRequiredScore() -> Int {
        if level <= 5 {
            return level * 1000
        } else if level <= 10 {
            return level * 2000
        } else if level <= 50 {
            return level * 3000
        } else {
            return level * 5000
        }
    }
    
    func levelUp() {
        let requiredScore = calculateRequiredScore()
        guard score >= requiredScore else {
            print("[Level] Not enough score to level up. Required: \(requiredScore), Current: \(score)")
            return
        }
        level += 1
        print("[Level] Level up! Now at level \(level)")
        setSeed(for: level)
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        if level > userDefaults.integer(forKey: levelKey) {
            achievementsManager.updateAchievement(id: "highest_level", value: level)
            // Update leaderboard when new highest level is achieved
            updateLeaderboard()
        }
        let availableShapes = BlockShape.availableShapes(for: level)
        print("[Level] Level \(level) - Available shapes: \(availableShapes.map { String(describing: $0) }.joined(separator: ", "))")
        refillTray()
        levelComplete = false
        if isPerfectLevel {
            perfectLevels += 1
        }
        isPerfectLevel = true
        currentChain = 0
        usedColors.removeAll()
        usedShapes.removeAll()
        delegate?.gameStateDidUpdate()
        checkAchievements()
    }
    
    func advanceToNextLevel() {
        level += 1
        print("[Level] Advancing to level \(level)")
        setSeed(for: level)
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        if level > userDefaults.integer(forKey: levelKey) {
            achievementsManager.updateAchievement(id: "highest_level", value: level)
        }
        let availableShapes = BlockShape.availableShapes(for: level)
        print("[Level] Level \(level) - Available shapes: \(availableShapes.map { String(describing: $0) }.joined(separator: ", "))")
        refillTray()
        levelComplete = false
        delegate?.gameStateDidUpdate()
    }
    
    private func checkGameOver() {
        // End the game if none of the tray shapes can be placed anywhere
        let canPlaceAny = tray.contains { canPlaceBlockAnywhere($0) }
        if !canPlaceAny {
            print("[GameOver] No available moves for any tray shape. Game over.")
            isGameOver = true
            saveProgress()
            if score > 0 { updateLeaderboard() }
            gameOver()
        }
    }
    
    private func hasValidMoves() -> Bool {
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] == nil {
                    return true
                }
            }
        }
        return false
    }
    
    // Award points for grouping 10 or more contiguous squares
    private func checkGroups() {
        var visited = Array(repeating: Array(repeating: false, count: GameConstants.gridSize), count: GameConstants.gridSize)
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if let _ = grid[row][col], !visited[row][col] {
                    let group = floodFill(row: row, col: col, visited: &visited)
                    if group.count >= 10 {
                        addScore(200, at: CGPoint(x: frameSize.width/2, y: CGFloat(row) * GameConstants.blockSize))
                        print("[Bonus] Group of \(group.count) contiguous blocks at (\(row),\(col)). +200 bonus points!")
                    }
                }
            }
        }
    }
    
    func gameOver() {
        isGameOver = true
        gamesCompleted += 1
        achievementsManager.updateAchievement(id: "games_10", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_50", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_100", value: gamesCompleted)
        
        saveLastPlayDate()
        checkAchievements()
    }
    
    func saveProgress() {
        // Save high score and highest level
        if score > userDefaults.integer(forKey: scoreKey) {
            userDefaults.set(score, forKey: scoreKey)
            achievementsManager.updateAchievement(id: "high_score", value: score)
        }
        
        if level > userDefaults.integer(forKey: levelKey) {
            userDefaults.set(level, forKey: levelKey)
            achievementsManager.updateAchievement(id: "highest_level", value: level)
        }
        
        // Save current game state
        var gridData: [[[String: Any]]] = []
        for row in grid {
            var rowData: [[String: Any]] = []
            for cell in row {
                if let block = cell {
                    rowData.append([
                        "color": block.color.rawValue,
                        "shape": block.shape.rawValue
                    ])
                } else {
                    rowData.append([:])
                }
            }
            gridData.append(rowData)
        }
        
        let trayData = tray.map { block in
            [
                "color": block.color.rawValue,
                "shape": block.shape.rawValue
            ]
        }
        
        let progress: [String: Any] = [
            "score": score,
            "level": level,
            "grid": gridData,
            "tray": trayData
        ]
        
        userDefaults.set(progress, forKey: progressKey)
    }
    
    func cleanup() {
        // Cancel any ongoing tasks
        achievementCheckTask?.cancel()
        cancellables.removeAll()
        currentAchievement = nil
        lastMove = nil
    }
} 