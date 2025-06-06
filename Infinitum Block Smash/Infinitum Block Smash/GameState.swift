import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import StoreKit

// MARK: - GameState
protocol GameStateDelegate: AnyObject {
    func gameStateDidUpdate()
    func gameStateDidClearLines(at positions: [(Int, Int)])
    func showScoreAnimation(points: Int, at position: CGPoint)
    func highlightHint(at position: (row: Int, col: Int))
    func highlightHint(block: Block, at position: (row: Int, col: Int))
    func updateFPS(_ newFPS: Int)
}

@MainActor
final class GameState: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var score: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var grid: [[BlockColor?]] = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
    @Published private(set) var tray: [Block] = []
    @Published private(set) var achievementsManager = AchievementsManager()
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var levelComplete: Bool = false
    @Published private(set) var adUndoCount: Int = 3  // Start with 3 undos per game
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
    @Published var isPaused: Bool = false
    @Published var targetFPS: Int = FPSManager.shared.getDisplayFPS(for: FPSManager.shared.targetFPS)
    
    // Ad-related state
    @Published private(set) var levelsCompletedSinceLastAd = 0
    @Published private(set) var adsWatchedThisGame = 0
    @Published private(set) var hintsUsedThisGame = 0
    @Published private(set) var hasUsedContinueAd = false
    
    // Add frame size property
    var frameSize: CGSize = .zero
    
    var delegate: GameStateDelegate? {
        didSet {
            print("[DEBUG] GameState.delegate set to \(String(describing: delegate))")
        }
    }
    
    private var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
    private let traySize = 3
    
    private let userDefaults = UserDefaults.standard
    private let scoreKey = "highScore"
    private let levelKey = "highestLevel"
    private let progressKey = "gameProgress"
    private let hasSavedGameKey = "hasSavedGame"
    
    // Statistics keys
    private let blocksPlacedKey = "blocksPlaced"
    private let linesClearedKey = "linesCleared"
    private let gamesCompletedKey = "gamesCompleted"
    private let perfectLevelsKey = "perfectLevels"
    private let totalPlayTimeKey = "totalPlayTime"
    
    // Undo support - use weak references to prevent memory leaks
    private var previousGrid: [[BlockColor?]]?
    private var previousTray: [Block]?
    private var lastMove: GameMove?
    private var previousScore: Int = 0
    private var previousLevel: Int = 1
    
    var canAdUndo: Bool { adUndoCount > 0 }
    
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var totalPlayTime: TimeInterval = 0
    private var playTimeTimer: Timer?
    
    #if DEBUG
    private var isTestFlightOrSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
    #else
    private var isTestFlightOrSimulator: Bool = false
    #endif
    
    private let adManager = AdManager.shared
    
    // New properties for level-based shape spawning
    private var randomShapesOnBoard: Int = 0
    private var requiredShapesToFit: Int = 3
    private var levelScoreThreshold: Int = 1000
    
    private let subscriptionManager = SubscriptionManager.shared
    
    // MARK: - Initialization
    init() {
        print("[GameState] Initializing GameState")
        // Load saved statistics
        loadStatistics()
        
        self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        self.tray = []
        refillTray()
        setupSubscriptions()
        setupInitialGame()
        gameStartTime = Date()
        loadLastPlayDate()
        startPlayTimeTimer()
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { [weak self] in
            guard let self = self else { return }
            await MainActor.run {
                MemoryManager.shared.cleanupMemory()
                self.cancellables.removeAll()
                self.playTimeTimer?.invalidate()
            }
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        print("[GameState] App became active - loading statistics")
        loadStatistics()
    }
    
    @objc private func handleAppWillResignActive() {
        print("[GameState] App will resign active - saving statistics")
        saveStatistics()
        do {
            try saveProgress()
            print("[GameState] Successfully saved progress before resigning active")
        } catch {
            print("[GameState] Failed to save progress before resigning active: \(error)")
        }
    }
    
    private func startPlayTimeTimer() {
        playTimeTimer?.invalidate()
        playTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlayTime()
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupInitialGame() {
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray.removeAll(keepingCapacity: true)
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
        usedColors.removeAll(keepingCapacity: true)
        usedShapes.removeAll(keepingCapacity: true)
        isPerfectLevel = true
        gameStartTime = Date()
    }
    
    private func setupSubscriptions() {
        // Only subscribe to necessary publishers
        $score
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] newScore in
                self?.checkAchievements(for: newScore)
            }
            .store(in: &cancellables)
    }
    
    private func updatePlayTime() {
        guard let startTime = gameStartTime else { return }
        let currentTime = Date()
        totalPlayTime += currentTime.timeIntervalSince(startTime)
        gameStartTime = currentTime
        
        // Update time-based achievements
        let playTimeInSeconds = Int(totalPlayTime)
        achievementsManager.updateAchievement(id: "play_1h", value: playTimeInSeconds)
        achievementsManager.updateAchievement(id: "play_5h", value: playTimeInSeconds)
        achievementsManager.updateAchievement(id: "play_10h", value: playTimeInSeconds)
    }
    
    private func checkAchievements(for score: Int) {
        updatePlayTime()
        Task {
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
        Task { [weak self] in
            guard let self = self else { return }
            await MainActor.run {
                self.score = 0
                self.level = 1
                self.isGameOver = false
                self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
                self.tray.removeAll(keepingCapacity: true)
                self.levelComplete = false
                self.canUndo = false
                self.lastMove = nil
                self.blocksPlaced = 0
                self.linesCleared = 0
                self.currentChain = 0
                self.usedColors.removeAll(keepingCapacity: true)
                self.usedShapes.removeAll(keepingCapacity: true)
                self.isPerfectLevel = true
                self.gameStartTime = Date()
                
                // Set the seed for the new game
                self.setSeed(for: self.level)
                
                // Delete any saved game
                self.deleteSavedGame()
                
                // Refill tray after all state is reset
                self.refillTray()
                
                // Reset ad-related state
                self.resetAdState()
                
                // Notify delegate of state change
                self.delegate?.gameStateDidUpdate()
            }
        }
    }
    
    func setSeed(for level: Int) {
        rng = SeededGenerator(seed: UInt64(level))
    }
    
    func nextBlockRandom() -> Block {
        var availableShapes = BlockShape.availableShapes(for: level)
        
        // Remove single blocks and tiny shapes from base available shapes
        if level <= 25 {
            availableShapes = availableShapes.filter { $0 != .single }
            // 1% chance for single block
            if Double.random(in: 0...1, using: &rng) < 0.01 {
                availableShapes = [.single]
            }
        }
        
        if level <= 35 {
            let tinyShapes: [BlockShape] = [.tinyLUp, .tinyLDown, .tinyLLeft, .tinyLRight, .tinyI]
            availableShapes = availableShapes.filter { !tinyShapes.contains($0) }
            // 1% chance for tiny shapes
            if Double.random(in: 0...1, using: &rng) < 0.01 {
                availableShapes = [tinyShapes.randomElement(using: &rng) ?? .tinyLUp]
            }
        }
        
        // Filter out shapes that are already in the tray
        if !tray.isEmpty {
            let existingShapes = Set(tray.map { $0.shape })
            availableShapes = availableShapes.filter { !existingShapes.contains($0) }
        }
        
        // If this is the first spawn (tray is empty), ensure we don't get 3 of the same shape
        if tray.isEmpty {
            // Remove shapes that would result in 3 of the same
            let shapesToRemove = Set(availableShapes.filter { shape in
                availableShapes.filter { $0 == shape }.count >= 3
            })
            availableShapes = availableShapes.filter { !shapesToRemove.contains($0) }
        }
        
        // If we somehow filtered out all shapes, fall back to basic shapes
        if availableShapes.isEmpty {
            availableShapes = [.bar2H, .bar2V, .bar3H, .bar3V, .square]
        }
        
        let shape = availableShapes.randomElement(using: &rng) ?? .bar2H
        let color = BlockColor.availableColors(for: level).randomElement(using: &rng) ?? .red
        return Block(color: color, shape: shape)
    }
    
    func refillTray() {
        // Only add new blocks if we have less than requiredShapesToFit
        while tray.count < requiredShapesToFit {
            let newBlock = nextBlockRandom()
            tray.append(newBlock)
        }
        
        // Check for game over after refilling
        checkGameOver()
        
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

    func undo() {
        guard canUndo else { return }
        
        Task { @MainActor in
            let hasUnlimitedUndos = await subscriptionManager.hasFeature(.unlimitedUndos)
            if !hasUnlimitedUndos {
                undoCount += 1
            }
            
            guard let previousGrid = previousGrid,
                  let previousTray = previousTray else {
                return
            }
            
            grid = previousGrid
            tray = previousTray
            score = previousScore
            level = previousLevel
            canUndo = false
            delegate?.gameStateDidUpdate()
        }
    }
    
    private func performUndo() {
        guard let prevGrid = previousGrid else { return }
        
        print("[Undo] Undoing last move. Restoring previous grid, tray, score, and level.")
        grid = prevGrid
        if let prevTray = previousTray {
            tray = prevTray
        }
        score = previousScore
        level = previousLevel
        canUndo = false
        
        if !isTestFlightOrSimulator {
            adUndoCount -= 1
        }
        
        undoCount += 1
        
        // Update undo achievements
        achievementsManager.updateAchievement(id: "undo_5", value: undoCount)
        achievementsManager.updateAchievement(id: "undo_20", value: undoCount)
        
        isPerfectLevel = false
        delegate?.gameStateDidUpdate()
        checkAchievements()
    }
    
    private func showVideoAd(completion: @escaping (Bool) -> Void) async {
        // Show the rewarded interstitial ad
        await adManager.showRewardedInterstitial(onReward: {
            completion(true)
        })
    }

    // In tryPlaceBlockFromTray, save state before placement and reset undo after
    func tryPlaceBlockFromTray(_ block: Block, at position: CGPoint) -> Bool {
        let row = Int(position.y)
        let col = Int(position.x)
        
        guard row >= 0 && row < GameConstants.gridSize && col >= 0 && col < GameConstants.gridSize else {
            print("[Place] Invalid position: (\(row), \(col))")
            return false
        }
        
        // Check if we can place the entire shape
        for (dx, dy) in block.shape.cells {
            let x = col + dx
            let y = row + dy
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                print("[Place] Shape would go out of bounds at (\(x), \(y))")
                return false
            }
            if grid[y][x] != nil {
                print("[Place] Position (\(x), \(y)) already occupied")
                return false
            }
        }
        
        // Save state for undo before making changes
        saveStateForUndo()
        
        // Use placeBlock to handle scoring and placement
        placeBlock(block, at: position)
        
        // Remove block from tray
        if let index = tray.firstIndex(where: { $0.id == block.id }) {
            tray.remove(at: index)
        }
        
        // Check for matches
        checkMatches()
        
        // Check for game over after placement
        checkGameOver()
        
        delegate?.gameStateDidUpdate()
        return true
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
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                return false
            }
            if grid[y][x] != nil {
                return false
            }
        }
        return true
    }
    
    private func countTouchingBlocks(at x: Int, y: Int, excluding currentShapePositions: Set<String>) -> Int {
        var touchingCount = 0
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)] // up, right, down, left
        
        for (dx, dy) in directions {
            let newX = x + dx
            let newY = y + dy
            
            // Only count if the adjacent position is within grid bounds AND contains a block
            // AND is not part of the current shape
            if newX >= 0 && newX < GameConstants.gridSize && 
               newY >= 0 && newY < GameConstants.gridSize && 
               grid[newY][newX] != nil &&
               !currentShapePositions.contains("\(newX),\(newY)") {
                touchingCount += 1
            }
        }
        return touchingCount
    }

    private func placeBlock(_ block: Block, at anchor: CGPoint) {
        // Track the positions of the current shape
        var currentShapePositions = Set<String>()
        
        // First place the block
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                grid[y][x] = block.color
                currentShapePositions.insert("\(x),\(y)")
            }
        }
        
        // Then check for touches after placing
        var totalTouchingPoints = 0
        var hasAnyTouches = false
        
        for (dx, dy) in block.shape.cells {
            let x = Int(anchor.x) + dx
            let y = Int(anchor.y) + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                let touchingCount = countTouchingBlocks(at: x, y: y, excluding: currentShapePositions)
                if touchingCount > 0 {
                    hasAnyTouches = true
                    totalTouchingPoints += touchingCount
                    let position = CGPoint(x: CGFloat(x) * GameConstants.blockSize, y: CGFloat(y) * GameConstants.blockSize)
                    addScore(touchingCount, at: position)
                    print("[Touch] Block at (\(x),\(y)) touches \(touchingCount) blocks. +\(touchingCount) points!")
                }
            }
        }
        
        // Award bonus if the block touched other blocks
        if hasAnyTouches && totalTouchingPoints >= 3 {
            let bonusPoints = totalTouchingPoints * 2
            addScore(bonusPoints, at: CGPoint(x: frameSize.width/2, y: frameSize.height/2))
            print("[Bonus] Multiple touches! +\(bonusPoints) bonus points!")
        }
        
        blocksPlaced += 1
        usedColors.insert(block.color)
        usedShapes.insert(block.shape)
        
        // Check for color and shape achievements
        if usedColors.count == BlockColor.allCases.count {
            achievementsManager.increment(id: "color_master")
        }
        if usedShapes.count == BlockShape.allCases.count {
            achievementsManager.increment(id: "shape_master")
        }
        
        isPerfectLevel = false
        checkAchievements()
    }
    
    private func checkDiagonalPattern() -> [(Int, Int)]? {
        // Check forward diagonal (/)
        var forwardDiagonal: [(Int, Int)] = []
        var forwardColor: BlockColor? = nil
        var isForwardValid = true
        
        // Check backward diagonal (\)
        var backwardDiagonal: [(Int, Int)] = []
        var backwardColor: BlockColor? = nil
        var isBackwardValid = true
        
        for i in 0..<GameConstants.gridSize {
            // Check forward diagonal (/)
            let forwardRow = GameConstants.gridSize - 1 - i
            let forwardCol = i
            if let color = grid[forwardRow][forwardCol] {
                if forwardColor == nil {
                    forwardColor = color
                } else if color != forwardColor {
                    isForwardValid = false
                }
                forwardDiagonal.append((forwardRow, forwardCol))
            } else {
                isForwardValid = false
            }
            
            // Check backward diagonal (\)
            if let color = grid[i][i] {
                if backwardColor == nil {
                    backwardColor = color
                } else if color != backwardColor {
                    isBackwardValid = false
                }
                backwardDiagonal.append((i, i))
            } else {
                isBackwardValid = false
            }
        }
        
        // Return the valid diagonal pattern if found
        if isForwardValid && forwardDiagonal.count == GameConstants.gridSize {
            return forwardDiagonal
        }
        if isBackwardValid && backwardDiagonal.count == GameConstants.gridSize {
            return backwardDiagonal
        }
        return nil
    }
    
    private func checkXPattern() -> [(Int, Int)]? {
        var xPattern: [(Int, Int)] = []
        var xColor: BlockColor? = nil
        var isValid = true
        
        // Check if we have a valid X pattern
        for i in 0..<GameConstants.gridSize {
            // Check both diagonals
            let forwardRow = GameConstants.gridSize - 1 - i
            let forwardCol = i
            let backwardRow = i
            let backwardCol = i
            
            // Check forward diagonal (/)
            if let color = grid[forwardRow][forwardCol] {
                if xColor == nil {
                    xColor = color
                } else if color != xColor {
                    isValid = false
                }
                xPattern.append((forwardRow, forwardCol))
            } else {
                isValid = false
            }
            
            // Check backward diagonal (\) if it's not the center point
            if !(forwardRow == backwardRow && forwardCol == backwardCol) {
                if let color = grid[backwardRow][backwardCol] {
                    if color != xColor {
                        isValid = false
                    }
                    xPattern.append((backwardRow, backwardCol))
                } else {
                    isValid = false
                }
            }
        }
        
        return isValid && xPattern.count == (GameConstants.gridSize * 2 - 1) ? xPattern : nil
    }

    private func checkMatches() {
        var clearedPositions: [(Int, Int)] = []
        var linesClearedThisTurn = 0
        var diagonalPatternsFound = Set<String>() // Track which diagonal patterns we've found
        var achievementsToUpdate: [String: Int] = [:] // Track achievements to update
        
        // Check rows
        for row in 0..<GameConstants.gridSize {
            if isRowFull(row) {
                clearRow(row)
                clearedPositions.append((row, -1))  // -1 indicates entire row
                linesClearedThisTurn += 1
                addScore(100, at: CGPoint(x: frameSize.width/2, y: CGFloat(row) * GameConstants.blockSize))
            }
        }
        
        // Check columns
        for col in 0..<GameConstants.gridSize {
            if isColumnFull(col) {
                clearColumn(col)
                clearedPositions.append((-1, col))  // -1 indicates entire column
                linesClearedThisTurn += 1
                addScore(100, at: CGPoint(x: CGFloat(col) * GameConstants.blockSize, y: frameSize.height/2))
            }
        }
        
        // Check for X pattern (10+ blocks in X formation)
        for row in 1..<GameConstants.gridSize-1 {
            for col in 1..<GameConstants.gridSize-1 {
                if let centerColor = grid[row][col] {
                    var xPatternCount = 1 // Count the center block
                    var positions = [(row, col)]
                    
                    // Check in all four diagonal directions
                    let directions = [(1,1), (1,-1), (-1,1), (-1,-1)]
                    for (dx, dy) in directions {
                        var currentRow = row + dx
                        var currentCol = col + dy
                        while currentRow >= 0 && currentRow < GameConstants.gridSize &&
                              currentCol >= 0 && currentCol < GameConstants.gridSize &&
                              grid[currentRow][currentCol] == centerColor {
                            xPatternCount += 1
                            positions.append((currentRow, currentCol))
                            currentRow += dx
                            currentCol += dy
                        }
                    }
                    
                    if xPatternCount >= 10 {
                        addScore(1000, at: CGPoint(x: CGFloat(col) * GameConstants.blockSize, y: CGFloat(row) * GameConstants.blockSize))
                        print("[Bonus] X pattern with \(xPatternCount) blocks found! +1000 points!")
                    }
                }
            }
        }
        
        // Check for diagonal patterns (10+ blocks in a row)
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if let startColor = grid[row][col] {
                    // Check forward diagonal (/)
                    var forwardCount = 1
                    var currentRow = row - 1
                    var currentCol = col + 1
                    while currentRow >= 0 && currentCol < GameConstants.gridSize &&
                          grid[currentRow][currentCol] == startColor {
                        forwardCount += 1
                        currentRow -= 1
                        currentCol += 1
                    }
                    
                    if forwardCount >= 10 {
                        let patternKey = "forward_\(row),\(col)"
                        if !diagonalPatternsFound.contains(patternKey) {
                            diagonalPatternsFound.insert(patternKey)
                            addScore(500, at: CGPoint(x: CGFloat(col) * GameConstants.blockSize, y: CGFloat(row) * GameConstants.blockSize))
                            print("[Bonus] Forward diagonal with \(forwardCount) blocks found! +500 points!")
                        }
                    }
                    
                    // Check backward diagonal (\)
                    var backwardCount = 1
                    currentRow = row - 1
                    currentCol = col - 1
                    while currentRow >= 0 && currentCol >= 0 &&
                          grid[currentRow][currentCol] == startColor {
                        backwardCount += 1
                        currentRow -= 1
                        currentCol -= 1
                    }
                    
                    if backwardCount >= 10 {
                        let patternKey = "backward_\(row),\(col)"
                        if !diagonalPatternsFound.contains(patternKey) {
                            diagonalPatternsFound.insert(patternKey)
                            addScore(500, at: CGPoint(x: CGFloat(col) * GameConstants.blockSize, y: CGFloat(row) * GameConstants.blockSize))
                            print("[Bonus] Backward diagonal with \(backwardCount) blocks found! +500 points!")
                        }
                    }
                }
            }
        }
        
        // Check for groups after clearing lines
        checkGroups()
        
        // Update chain bonus only for line clears
        if linesClearedThisTurn > 0 {
            currentChain += 1
            let chainBonus = currentChain * 100
            addScore(chainBonus, at: CGPoint(x: frameSize.width/2, y: frameSize.height/2))
            print("[Chain] Chain \(currentChain)! +\(chainBonus) bonus points!")
            // Update total lines cleared
            linesCleared += linesClearedThisTurn
        } else {
            currentChain = 0
        }
        
        // Update achievements in batch
        if linesClearedThisTurn > 0 {
            achievementsToUpdate["clear_10"] = linesClearedThisTurn
            achievementsToUpdate["clear_50"] = linesClearedThisTurn
            achievementsToUpdate["clear_100"] = linesClearedThisTurn
        }
        
        // Batch update achievements
        if !achievementsToUpdate.isEmpty {
            achievementsManager.batchUpdateAchievements(achievementsToUpdate)
        }
        
        // Check for perfect level
        if isGridEmpty() && isPerfectLevel {
            let perfectBonus = 1000
            addScore(perfectBonus, at: CGPoint(x: frameSize.width/2, y: frameSize.height/2))
            print("[Perfect] Perfect level! +\(perfectBonus) bonus points!")
            achievementsManager.updateAchievement(id: "perfect_level", value: 1)
            perfectLevels += 1
            achievementsManager.updateAchievement(id: "perfect_levels_3", value: perfectLevels)
            achievementsManager.updateAchievement(id: "perfect_levels_5", value: perfectLevels)
        }
        
        delegate?.gameStateDidUpdate()
    }
    
    private func isRowFull(_ row: Int) -> Bool {
        return !grid[row].contains(where: { $0 == nil })
    }
    
    private func isColumnFull(_ col: Int) -> Bool {
        return !grid.map({ $0[col] }).contains(where: { $0 == nil })
    }
    
    private func clearRow(_ row: Int) {
        for col in 0..<GameConstants.gridSize {
            grid[row][col] = nil
        }
    }
    
    private func clearColumn(_ col: Int) {
        for row in 0..<GameConstants.gridSize {
            grid[row][col] = nil
        }
    }
    
    private func isTopRowOccupied() -> Bool {
        return !grid[0].contains(where: { $0 == nil })
    }
    
    private func isGridEmpty() -> Bool {
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    return false
                }
            }
        }
        return true
    }
    
    func addScore(_ points: Int, at position: CGPoint? = nil) {
        // Don't add score if level is already complete
        guard !levelComplete else { return }
        
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
            // Remove leaderboard update from here
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
            print("[DEBUG] Setting levelComplete = true due to score threshold. Score: \(score), Required: \(requiredScore)")
            print("[Level] Score threshold met for level \(level). Level complete!")
            levelComplete = true
            // Don't automatically advance - wait for user interaction
            delegate?.gameStateDidUpdate()
        }
        checkAchievements()
    }
    
    func calculateRequiredScore() -> Int {
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
        
        levelsCompletedSinceLastAd += 1
        
        // Check if we need to show an ad
        if levelsCompletedSinceLastAd >= 7 {
            if adsWatchedThisGame < 3 {
                // Show ad with skip option
                Task {
                    await AdManager.shared.showRewardedInterstitial(onReward: {
                        self.adsWatchedThisGame += 1
                        self.levelsCompletedSinceLastAd = 0
                        self.continueLevelUp()
                    })
                }
            } else {
                // Skip ad after 3 ads watched
                levelsCompletedSinceLastAd = 0
                continueLevelUp()
            }
        } else {
            continueLevelUp()
        }
    }
    
    private func continueLevelUp() {
        level += 1
        print("[Level] Level up! Now at level \(level)")
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
        // Add a small delay before advancing to ensure the level complete overlay is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.level += 1
            print("[Level] Advancing to level \(self.level)")
            self.setSeed(for: self.level)
            self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
            self.tray = []
            if self.level > UserDefaults.standard.integer(forKey: self.levelKey) {
                self.achievementsManager.updateAchievement(id: "highest_level", value: self.level)
            }
            let availableShapes = BlockShape.availableShapes(for: self.level)
            print("[Level] Level \(self.level) - Available shapes: \(availableShapes.map { String(describing: $0) }.joined(separator: ", "))")
            self.refillTray()
            self.levelComplete = false
            self.delegate?.gameStateDidUpdate()
        }
    }
    
    private func checkGameOver() {
        // End the game if none of the tray shapes can be placed anywhere
        let canPlaceAny = tray.contains { canPlaceBlockAnywhere($0) }
        if !canPlaceAny && !isGameOver {  // Only proceed if not already game over
            print("[GameOver] No available moves for any tray shape. Game over.")
            handleGameOver()
        }
    }
    
    private func handleGameOver() {
        // Ensure we only process game over once
        guard !isGameOver else { return }
        
        isGameOver = true
        gamesCompleted += 1
        
        // Update achievements
        achievementsManager.updateAchievement(id: "games_10", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_50", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_100", value: gamesCompleted)
        
        // Delete saved game and update leaderboard safely
        deleteSavedGame()
        if score > 0 {
            updateLeaderboard()
        }
        
        // Save last play date and check achievements
        saveLastPlayDate()
        checkAchievements()
        
        #if DEBUG
        // In debug/simulator, skip ad
        print("[GameOver] Debug mode - skipping ad")
        delegate?.gameStateDidUpdate()
        #else
        // In production, check if we're in TestFlight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            print("[GameOver] TestFlight mode - skipping ad")
            delegate?.gameStateDidUpdate()
        } else {
            // In production, show ad automatically
            Task {
                await AdManager.shared.showRewardedInterstitial(onReward: {
                    self.continueGame()
                })
            }
        }
        #endif
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
        var currentShapePositions = Set<String>()
        
        // First mark all positions of the current shape as visited
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    currentShapePositions.insert("\(col),\(row)")
                }
            }
        }
        
        // Only check for groups among existing blocks
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if let _ = grid[row][col], !visited[row][col] && !currentShapePositions.contains("\(col),\(row)") {
                    let group = floodFill(row: row, col: col, visited: &visited)
                    if group.count >= 10 {
                        addScore(500, at: CGPoint(x: frameSize.width/2, y: CGFloat(row) * GameConstants.blockSize))
                        print("[Bonus] Group of \(group.count) contiguous blocks at (\(row),\(col)). +500 bonus points!")
                        
                        // Track group achievements
                        if group.count >= 10 {
                            achievementsManager.increment(id: "group_10")
                        }
                        if group.count >= 20 {
                            achievementsManager.increment(id: "group_20")
                        }
                        if group.count >= 30 {
                            achievementsManager.increment(id: "group_30")
                        }
                    }
                }
            }
        }
    }

    private func floodFill(row: Int, col: Int, visited: inout [[Bool]]) -> [(Int, Int)] {
        let directions = [(-1,0),(1,0),(0,-1),(0,1)]
        var queue = [(row, col)]
        var group = [(row, col)]
        visited[row][col] = true
        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            for (dr, dc) in directions {
                let nr = r + dr, nc = c + dc
                if nr >= 0 && nr < GameConstants.gridSize && nc >= 0 && nc < GameConstants.gridSize {
                    if let _ = grid[nr][nc], !visited[nr][nc] {
                        visited[nr][nc] = true
                        queue.append((nr, nc))
                        group.append((nr, nc))
                    }
                }
            }
        }
        return group
    }
    
    private func updateLeaderboard() {
        // Check if user is a guest
        if UserDefaults.standard.bool(forKey: "isGuest") {
            print("[Leaderboard] Skipping leaderboard update for guest user")
            return
        }
        
        // Check if username is set
        guard let username = UserDefaults.standard.string(forKey: "username"),
              !username.isEmpty else {
            print("[Leaderboard] Error: Username not set")
            return
        }
        
        Task {
            do {
                guard let userID = UserDefaults.standard.string(forKey: "userID") else {
                    print("[Leaderboard] Error: Missing userID")
                    return
                }
                
                // Check if user is authenticated
                guard Auth.auth().currentUser != nil else {
                    print("[Leaderboard] Error: User not authenticated")
                    return
                }
                
                // Only update if score is greater than 0
                if score > 0 {
                    try await LeaderboardService.shared.updateLeaderboard(
                        type: .score,
                        score: score,
                        username: username,
                        userID: userID
                    )
                    print("[Leaderboard] Successfully updated leaderboard")
                } else {
                    print("[Leaderboard] Skipping update - score is 0")
                }
            } catch {
                print("[Leaderboard] Error updating leaderboard: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadLastPlayDate() {
        if let savedDate = userDefaults.object(forKey: "lastPlayDate") as? Date {
            lastPlayDate = savedDate
            let calendar = Calendar.current
            if let days = calendar.dateComponents([.day], from: savedDate, to: Date()).day {
                if days == 1 {
                    consecutiveDays += 1
                    achievementsManager.updateAchievement(id: "login_\(consecutiveDays)", value: consecutiveDays)
                    achievementsManager.updateAchievement(id: "daily_\(consecutiveDays)", value: consecutiveDays)
                    // Award daily login points
                    achievementsManager.updateAchievement(id: "daily_login", value: 1)
                } else if days > 1 {
                    consecutiveDays = 0
                }
            }
        } else {
            // First time playing
            achievementsManager.updateAchievement(id: "login_1", value: 1)
            achievementsManager.updateAchievement(id: "daily_login", value: 1)
        }
    }
    
    private func saveLastPlayDate() {
        lastPlayDate = Date()
        userDefaults.set(lastPlayDate, forKey: "lastPlayDate")
        
        // Update login achievements
        if consecutiveDays > 0 {
            achievementsManager.updateAchievement(id: "login_\(consecutiveDays)", value: consecutiveDays)
        }
    }
    
    private func showAchievementNotification(_ achievement: Achievement) {
        // Only show notification if the achievement hasn't been notified before
        if !achievement.wasNotified {
            currentAchievement = achievement
            showingAchievementNotification = true
            
            // Mark the achievement as notified immediately
            achievementsManager.markAsNotified(id: achievement.id)
            
            // Hide notification after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.showingAchievementNotification = false
                self?.currentAchievement = nil
            }
        }
    }
    
    private func checkAchievements() {
        updatePlayTime()
        Task {
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
    
    func gameOver() {
        isGameOver = true
        // Only increment gamesCompleted if the game was lost (not manually ended)
        if !isPaused {
            gamesCompleted += 1
            saveStatistics() // Save statistics when game is over
        }
        playTimeTimer?.invalidate()
        Task { @MainActor in
            updatePlayTime() // Final update of play time
            try? saveProgress()
        }
    }
    
    // Add a new method to handle user confirmation of level completion
    func confirmLevelCompletion() {
        guard levelComplete else { return }
        advanceToNextLevel()
    }
    
    // Add a new function for manually ending the game from settings
    func endGameFromSettings() {
        isGameOver = true
        saveStatistics() // Save statistics when game is ended from settings
        playTimeTimer?.invalidate()
        Task { @MainActor in
            updatePlayTime() // Final update of play time
            try? saveProgress()
            
            // Update leaderboard if user is not guest and has a username
            if !UserDefaults.standard.bool(forKey: "isGuest") {
                if let username = UserDefaults.standard.string(forKey: "username"), !username.isEmpty {
                    updateLeaderboard()
                } else {
                    print("[GameState] Cannot update leaderboard: Username not set")
                }
            }
        }
    }
    
    func hasSavedGame() -> Bool {
        return userDefaults.bool(forKey: hasSavedGameKey)
    }
    
    func loadSavedGame() throws {
        guard let data = userDefaults.data(forKey: progressKey) else {
            throw GameError.loadFailed(NSError(domain: "GameState", code: -1, userInfo: [NSLocalizedDescriptionKey: "No saved game found"]))
        }
        
        guard let progress = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let score = progress["score"] as? Int,
              let level = progress["level"] as? Int,
              let gridData = progress["grid"] as? [[String?]],
              let trayData = progress["tray"] as? [[String: String]] else {
            throw GameError.loadFailed(NSError(domain: "GameState", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid saved game data"]))
        }
        
        // Load total play time if available
        if let savedPlayTime = progress["totalPlayTime"] as? TimeInterval {
            totalPlayTime = savedPlayTime
        }
        
        // Set the seed for the current level first
        setSeed(for: level)
        
        // Initialize grid with saved data
        var newGrid: [[BlockColor?]] = []
        for row in gridData {
            let rowData: [BlockColor?] = row.map { colorStr in
                if let colorStr = colorStr,
                   let color = BlockColor(rawValue: colorStr) {
                    return color
                }
                return nil
            }
            newGrid.append(rowData)
        }
        
        // Initialize tray with saved data
        var newTray: [Block] = []
        for blockData in trayData {
            guard let colorStr = blockData["color"],
                  let shapeStr = blockData["shape"],
                  let idStr = blockData["id"],
                  let color = BlockColor(rawValue: colorStr),
                  let shape = BlockShape(rawValue: shapeStr),
                  let id = UUID(uuidString: idStr) else {
                continue
            }
            let block = Block(color: color, shape: shape, id: id)
            newTray.append(block)
        }
        
        // Update game state
        self.grid = newGrid
        self.tray = newTray
        self.score = score
        self.level = level
        self.isGameOver = false
        self.isPaused = false
        self.blocksPlaced = 0
        self.linesCleared = 0
        self.currentChain = 0
        self.usedColors.removeAll(keepingCapacity: true)
        self.usedShapes.removeAll(keepingCapacity: true)
        self.isPerfectLevel = true
        self.gameStartTime = Date()
        
        // Notify delegate of state change
        delegate?.gameStateDidUpdate()
    }
    
    private func loadStatistics() {
        print("[GameState] Loading statistics from UserDefaults")
        // Load statistics from UserDefaults
        blocksPlaced = userDefaults.integer(forKey: blocksPlacedKey)
        linesCleared = userDefaults.integer(forKey: linesClearedKey)
        gamesCompleted = userDefaults.integer(forKey: gamesCompletedKey)
        perfectLevels = userDefaults.integer(forKey: perfectLevelsKey)
        totalPlayTime = userDefaults.double(forKey: totalPlayTimeKey)
        
        // Load high score and highest level
        if let savedScore = userDefaults.object(forKey: scoreKey) as? Int {
            score = savedScore
        }
        if let savedLevel = userDefaults.object(forKey: levelKey) as? Int {
            level = savedLevel
        }
        
        print("[GameState] Loaded statistics - Blocks: \(blocksPlaced), Lines: \(linesCleared), Games: \(gamesCompleted), Perfect: \(perfectLevels)")
    }
    
    private func saveStatistics() {
        print("[GameState] Saving statistics to UserDefaults")
        // Save statistics to UserDefaults
        userDefaults.set(blocksPlaced, forKey: blocksPlacedKey)
        userDefaults.set(linesCleared, forKey: linesClearedKey)
        userDefaults.set(gamesCompleted, forKey: gamesCompletedKey)
        userDefaults.set(perfectLevels, forKey: perfectLevelsKey)
        userDefaults.set(totalPlayTime, forKey: totalPlayTimeKey)
        
        // Save high score and highest level
        if score > userDefaults.integer(forKey: scoreKey) {
            userDefaults.set(score, forKey: scoreKey)
        }
        if level > userDefaults.integer(forKey: levelKey) {
            userDefaults.set(level, forKey: levelKey)
        }
        
        userDefaults.synchronize() // Force immediate save
        print("[GameState] Saved statistics - Blocks: \(blocksPlaced), Lines: \(linesCleared), Games: \(gamesCompleted), Perfect: \(perfectLevels)")
    }

    func saveProgress() throws {
        print("[GameState] Saving game progress")
        // Save high score and highest level
        if score > userDefaults.integer(forKey: scoreKey) {
            userDefaults.set(score, forKey: scoreKey)
            achievementsManager.updateAchievement(id: "high_score", value: score)
        }
        if level > userDefaults.integer(forKey: levelKey) {
            userDefaults.set(level, forKey: levelKey)
            achievementsManager.updateAchievement(id: "highest_level", value: level)
        }
        
        // Save statistics
        saveStatistics()
        
        // Sync with Firebase if user is logged in
        Task {
            do {
                try await FirebaseManager.shared.saveGameProgress(gameState: self)
                print("[GameState] Successfully synced with Firebase")
            } catch {
                print("[GameState] Failed to sync with Firebase: \(error)")
            }
        }
        
        // Convert grid to a property list compatible format
        var gridData: [[String]] = []
        for row in grid {
            let rowData: [String] = row.map { color in
                if let color = color {
                    return String(describing: color.rawValue)
                }
                return "empty" // Use "empty" instead of nil
            }
            gridData.append(rowData)
        }
        
        // Convert tray to a property list compatible format
        let trayData = tray.map { block in
            [
                "color": String(describing: block.color.rawValue),
                "shape": String(describing: block.shape.rawValue),
                "id": block.id.uuidString
            ] as [String: String]
        }
        
        // Create a property list compatible dictionary
        let progress: [String: Any] = [
            "score": score,
            "level": level,
            "grid": gridData,
            "tray": trayData,
            "blocksPlaced": blocksPlaced,
            "linesCleared": linesCleared,
            "gamesCompleted": gamesCompleted,
            "perfectLevels": perfectLevels,
            "totalPlayTime": totalPlayTime
        ]
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: progress, format: .binary, options: 0)
            userDefaults.set(data, forKey: progressKey)
            userDefaults.set(true, forKey: hasSavedGameKey)
            userDefaults.synchronize() // Ensure data is written immediately
            print("[GameState] Successfully saved game progress")
        } catch {
            print("[GameState] Failed to save game progress: \(error)")
            throw error
        }
    }
    
    func deleteSavedGame() {
        userDefaults.removeObject(forKey: progressKey)
        userDefaults.set(false, forKey: hasSavedGameKey)
        userDefaults.synchronize()
    }
    
    func cleanup() {
        MemoryManager.shared.cleanup()
    }
    
    func resetLevelComplete() {
        levelComplete = false
    }
    
    func reset() {
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        score = 0
        level = 1
        isGameOver = false
        isPaused = false
        previousGrid = nil
        previousTray = nil
        lastMove = nil
        refillTray()
    }
    
    // Add this method to handle continuing the game after watching an ad
    func continueGame() {
        guard !hasUsedContinueAd else { return }
        
        // Save current state
        let currentScore = score
        let currentLevel = level
        let currentGrid = grid
        let currentTray = tray
        
        // Reset game state
        resetGame()
        
        // Restore previous state
        score = currentScore
        level = currentLevel
        grid = currentGrid
        tray = currentTray
        hasUsedContinueAd = true
        isGameOver = false
        
        delegate?.gameStateDidUpdate()
    }
    
    // Add this method to handle hints
    func showHint() {
        Task { @MainActor in
            let hasUnlimitedHints = await subscriptionManager.hasFeature(.hints)
            if hintsUsedThisGame >= 3 && !hasUnlimitedHints {
                return
            }
            
            print("[Hint] Attempting to show hint. Current hints used: \(hintsUsedThisGame)")
            
            if let (block, position) = findValidMove() {
                delegate?.highlightHint(block: block, at: position)
                if !hasUnlimitedHints {
                    hintsUsedThisGame += 1
                }
            } else {
                print("[Hint] No valid moves found")
            }
        }
    }
    
    private func findValidMove() -> (block: Block, position: (row: Int, col: Int))? {
        // First check if we have any blocks in the tray
        guard !tray.isEmpty else { return nil }
        
        // Try each block in the tray
        for block in tray {
            // Try each position in the grid
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    // Check if we can place the block at this position
                    if canPlaceBlock(block, at: CGPoint(x: col, y: row)) {
                        // Count how many blocks this placement would touch
                        var touchingCount = 0
                        var currentShapePositions = Set<String>()
                        
                        // Add current shape positions to the set
                        for (dx, dy) in block.shape.cells {
                            let x = col + dx
                            let y = row + dy
                            currentShapePositions.insert("\(x),\(y)")
                        }
                        
                        // Count touches for each cell in the shape
                        for (dx, dy) in block.shape.cells {
                            let x = col + dx
                            let y = row + dy
                            touchingCount += countTouchingBlocks(at: x, y: y, excluding: currentShapePositions)
                        }
                        
                        // If this placement touches at least one block, it's a good hint
                        if touchingCount > 0 {
                            return (block, (row, col))
                        }
                    }
                }
            }
        }
        
        // If no touching placements found, return any valid placement
        for block in tray {
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    if canPlaceBlock(block, at: CGPoint(x: col, y: row)) {
                        return (block, (row, col))
                    }
                }
            }
        }
        
        return nil
    }
    
    // Add this to resetGame to reset ad-related state
    private func resetAdState() {
        levelsCompletedSinceLastAd = 0
        adsWatchedThisGame = 0
        hintsUsedThisGame = 0
        hasUsedContinueAd = false
    }
    
    private func getLevelScoreThreshold() -> Int {
        switch level {
        case 1...5:
            return 1000
        case 6...10:
            return 2000
        case 11...50:
            return 3000
        case 51...99:
            return 5000
        case 100...:
            return 10000
        default:
            return 5000
        }
    }
    
    private func updateLevelRequirements() {
        levelScoreThreshold = getLevelScoreThreshold()
        
        // Update random shapes on board
        if level >= 350 {
            randomShapesOnBoard = 0
            requiredShapesToFit = 3
        } else if level >= 150 {
            randomShapesOnBoard = 4
            requiredShapesToFit = 3
        } else if level >= 100 {
            randomShapesOnBoard = 3
            requiredShapesToFit = 3
        } else if level >= 75 {
            randomShapesOnBoard = 2
            requiredShapesToFit = 3
        } else if level >= 60 {
            randomShapesOnBoard = 1
            requiredShapesToFit = 3
        } else {
            randomShapesOnBoard = 0
            requiredShapesToFit = 3
        }
    }
    
    private func spawnRandomShapesOnBoard() {
        guard randomShapesOnBoard > 0 else { return }
        
        for _ in 0..<randomShapesOnBoard {
            let newBlock = nextBlockRandom()
            // Find a random empty position on the grid
            var emptyPositions: [(Int, Int)] = []
            for row in 0..<GameConstants.gridSize {
                for col in 0..<GameConstants.gridSize {
                    if grid[row][col] == nil {
                        emptyPositions.append((row, col))
                    }
                }
            }
            
            if let randomPosition = emptyPositions.randomElement() {
                grid[randomPosition.0][randomPosition.1] = newBlock.color
            }
        }
    }
    
    func startNewLevel() {
        level += 1
        updateLevelRequirements()
        spawnRandomShapesOnBoard()
        refillTray()
        levelComplete = false
        isPerfectLevel = true
    }
    
    // Add new method to load cloud data
    func loadCloudData() async {
        do {
            let progress = try await FirebaseManager.shared.loadGameProgress()
            
            // Update local statistics with cloud data
            await MainActor.run {
                blocksPlaced = progress.blocksPlaced
                linesCleared = progress.linesCleared
                gamesCompleted = progress.gamesCompleted
                perfectLevels = progress.perfectLevels
                totalPlayTime = progress.totalPlayTime
                
                // Update high score and highest level if cloud data is higher
                if progress.highScore > userDefaults.integer(forKey: scoreKey) {
                    userDefaults.set(progress.highScore, forKey: scoreKey)
                }
                if progress.highestLevel > userDefaults.integer(forKey: levelKey) {
                    userDefaults.set(progress.highestLevel, forKey: levelKey)
                }
                
                // Save updated values to UserDefaults
                userDefaults.set(blocksPlaced, forKey: blocksPlacedKey)
                userDefaults.set(linesCleared, forKey: linesClearedKey)
                userDefaults.set(gamesCompleted, forKey: gamesCompletedKey)
                userDefaults.set(perfectLevels, forKey: perfectLevelsKey)
                userDefaults.set(totalPlayTime, forKey: totalPlayTimeKey)
                userDefaults.synchronize()
            }
        } catch {
            print("[Error] Failed to load cloud data: \(error)")
        }
    }
    
    func updateTargetFPS(_ newFPS: Int) {
        targetFPS = newFPS
        delegate?.updateFPS(newFPS)
    }
    
    func showContinueAd(completion: @escaping (Bool) -> Void) {
        Task {
            await adManager.showRewardedInterstitial(onReward: {
                completion(true)
            })
        }
    }
    
    func showUndoAd(completion: @escaping (Bool) -> Void) {
        Task {
            await adManager.showRewardedInterstitial(onReward: {
                completion(true)
            })
        }
    }
}

// Deterministic seeded random generator
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
} 

extension BlockShape {
    static func availableShapes(for level: Int) -> [BlockShape] {
        // Basic shapes available from the start
        let basicShapes: [BlockShape] = [
            .bar2H, .bar2V, .bar3H, .bar3V, .bar4H, .bar4V, .square,
            .lUp, .lDown, .lLeft, .lRight,
            .tUp, .tDown, .tLeft, .tRight
        ]
        
        // Single block (very rare, only up to level 25)
        let singleBlock: [BlockShape] = level <= 25 ? [.single] : []
        
        // Tiny L and I shapes (very rare, only up to level 35)
        let tinyShapes: [BlockShape] = level <= 35 ? [.tinyLUp, .tinyLDown, .tinyLLeft, .tinyLRight, .tinyI] : []
        
        // Plus shape
        let plusShape: [BlockShape] = [.plus]
        
        // Z shape
        let zShape: [BlockShape] = [.zShape]
        
        // Medium complexity shapes
        let mediumShapes: [BlockShape] = [.cross, .uShape, .vShape, .wShape]
        
        // Complex shapes
        let complexShapes: [BlockShape] = [.xShape, .yShape, .zShape2]
        
        // Master shapes (for very high levels)
        let starShape: [BlockShape] = [.star]      // 5-pointed star
        let diamondShape: [BlockShape] = [.diamond] // Diamond shape
        let hexagonShape: [BlockShape] = [.hexagon] // Hexagonal shape
        let spiralShape: [BlockShape] = [.spiral]   // Spiral pattern
        let zigzagShape: [BlockShape] = [.zigzag]   // Zigzag pattern
        
        if level <= 1 {
            return basicShapes + singleBlock + tinyShapes
        }
        if level <= 15 {
            return basicShapes + singleBlock + tinyShapes
        }
        if level <= 25 {
            return basicShapes + singleBlock + tinyShapes + plusShape
        }
        if level <= 35 {
            return basicShapes + tinyShapes + plusShape + zShape
        }
        if level <= 40 {
            return basicShapes + plusShape + zShape
        }
        if level <= 60 {
            return basicShapes + plusShape + zShape + mediumShapes
        }
        if level <= 100 {
            return basicShapes + plusShape + zShape + mediumShapes + complexShapes
        }
        if level <= 125 {
            return basicShapes + plusShape + zShape + mediumShapes + complexShapes
        }
        if level <= 200 {
            return basicShapes + plusShape + zShape + mediumShapes + complexShapes + starShape
        }
        if level <= 300 {
            return basicShapes + plusShape + zShape + mediumShapes + complexShapes + starShape + diamondShape
        }
        if level <= 400 {
            return basicShapes + plusShape + zShape + mediumShapes + complexShapes + starShape + diamondShape + hexagonShape
        }
        if level <= 500 {
            return basicShapes + plusShape + zShape + mediumShapes + complexShapes + starShape + diamondShape + hexagonShape + spiralShape
        }
        // Level 501+: All shapes available
        return basicShapes + plusShape + zShape + mediumShapes + complexShapes + starShape + diamondShape + hexagonShape + spiralShape + zigzagShape
    }
}

extension BlockColor {
    static func availableColors(for level: Int) -> [BlockColor] {
        return [.red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan]
    }
}

// MARK: - Error Handling
enum GameError: LocalizedError {
    case saveFailed(Error)
    case leaderboardUpdateFailed(Error)
    case invalidMove
    case networkError
    case loadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save game progress: \(error.localizedDescription)"
        case .leaderboardUpdateFailed(let error):
            return "Failed to update leaderboard: \(error.localizedDescription)"
        case .invalidMove:
            return "Invalid move"
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .loadFailed(let error):
            return "Failed to load saved game: \(error.localizedDescription)"
        }
    }
}