import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import StoreKit

// MARK: - OfflineQueueEntry
struct OfflineQueueEntry: Codable {
    let progress: GameProgress
    let timestamp: Date
}

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
    @Published private(set) var temporaryScore: Int = 0  // Add temporary score for tracking during gameplay
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
    
    // Add missing properties
    private let saveQueue = DispatchQueue(label: "com.infinitum.blocksmash.savequeue")
    private let saveSemaphore = DispatchSemaphore(value: 1)
    @Published var highScore: Int = 0
    @Published var highestLevel: Int = 1
    
    // Add auto-sync toggle
    @AppStorage("autoSyncEnabled") private var autoSyncEnabled: Bool = true
    
    // Add memory management properties
    private var lastMemoryCleanup: Date = Date()
    private let memoryCleanupInterval: TimeInterval = 60.0 // Cleanup every minute
    private var cachedData: [String: Any] = [:]
    
    // Add leaderboard high score property
    private var leaderboardHighScore: Int = 0
    
    // Add method to fetch leaderboard high score
    func fetchLeaderboardHighScore() async {
        do {
            let result = try await LeaderboardService.shared.getLeaderboard(type: .score, period: "alltime")
            if let topScore = result.entries.first?.score {
                await MainActor.run {
                    self.leaderboardHighScore = topScore
                    // Update highScore if leaderboard score is higher
                    if topScore > self.highScore {
                        self.highScore = topScore
                        self.userDefaults.set(topScore, forKey: self.scoreKey)
                    }
                }
            }
        } catch {
            print("[GameState] Error fetching leaderboard high score: \(error.localizedDescription)")
        }
    }
    
    // Add undo state tracking
    private var undoStack = GameMoveStack(maxSize: 10)
    private var unlimitedUndos: Bool = false
    @Published var purchasedUndos: Int = 0
    
    // Add constant for ad-based undos
    private let undosPerAd = 1
    
    // Add analytics manager
    private let analyticsManager = AnalyticsManager.shared
    
    // Add new properties for offline queue
    private var offlineChangesQueue: [OfflineQueueEntry] = []
    private let offlineQueueKey = "offlineChangesQueue"
    private let lastSyncAttemptKey = "lastSyncAttempt"
    
    // Add these properties at the top of the class
    private var lastHintTime: TimeInterval = 0
    private let hintCooldown: TimeInterval = 1.0 // 1 second cooldown
    private var cachedHint: (block: Block, position: (row: Int, col: Int))?
    
    // MARK: - Initialization
    init() {
        // Run data migration if needed
        GameDataVersion.migrateIfNeeded()
        
        // Load high score from UserDefaults first
        highScore = userDefaults.integer(forKey: scoreKey)
        highestLevel = userDefaults.integer(forKey: levelKey)
        
        // Load other statistics
        loadStatistics()
        
        // Setup initial game state
        setupInitialGame()
        setupSubscriptions()
        
        // Load last play date for consecutive days tracking
        loadLastPlayDate()
        
        // Start play time timer
        startPlayTimeTimer()
        
        // Fetch leaderboard high score
        Task {
            await fetchLeaderboardHighScore()
        }
        
        // Perform initial device sync if user is logged in and auto-sync is enabled
        Task {
            if !UserDefaults.standard.bool(forKey: "isGuest") && UserDefaults.standard.bool(forKey: "autoSyncEnabled") {
                do {
                    try await FirebaseManager.shared.performInitialDeviceSync()
                    print("[GameState] Successfully performed initial device sync")
                } catch {
                    print("[GameState] Error performing initial device sync: \(error.localizedDescription)")
                }
            }
        }
        
        // Retry any pending score submissions
        Task {
            await retryPendingScore()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { [weak self] in
            guard let self = self else { return }
            await cleanupMemory()
            await MainActor.run {
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
        Task {
            await cleanupMemory()
            await MainActor.run {
                self.saveStatistics()
            }
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
        temporaryScore = 0
        isGameOver = false
        levelComplete = false
        canUndo = false
        adUndoCount = 3
        blocksPlaced = 0
        linesCleared = 0
        currentChain = 0
        usedColors.removeAll(keepingCapacity: true)
        usedShapes.removeAll(keepingCapacity: true)
        isPerfectLevel = true
        gameStartTime = Date()
        
        // Reset undo state
        undoStack.clear()
        
        // Check subscription status for unlimited undos
        Task {
            await checkUndoAvailability()
        }
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
                // Only reset current game state, preserve statistics
                self.score = 0
                self.temporaryScore = 0
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
    private func saveStateForUndo(block: Block, position: (row: Int, col: Int)) {
        let move = GameMove(
            block: block,
            position: position,
            previousGrid: grid.map { $0.map { $0 } },
            previousTray: tray.map { $0 },
            previousScore: score,
            previousLevel: level,
            previousBlocksPlaced: blocksPlaced,
            previousLinesCleared: linesCleared,
            previousCurrentChain: currentChain,
            previousUsedColors: usedColors,
            previousUsedShapes: usedShapes,
            previousIsPerfectLevel: isPerfectLevel
        )
        undoStack.push(move)
        canUndo = true
    }

    func undo() async {
        guard canUndo else { return }
        
        // Check if we can use an undo
        if !unlimitedUndos {
            if subscriptionManager.purchasedUndos > 0 {
                subscriptionManager.purchasedUndos -= 1
                purchasedUndos = subscriptionManager.purchasedUndos
            } else if adUndoCount > 0 {
                adUndoCount -= 1
            } else {
                return
            }
        }
        
        // Get the last move from the stack
        guard let lastMove = undoStack.pop() else { return }
        
        print("[Undo] Restoring previous game state:")
        print("[Undo] Score: \(score) -> \(lastMove.previousScore)")
        print("[Undo] Level: \(level) -> \(lastMove.previousLevel)")
        print("[Undo] Blocks Placed: \(blocksPlaced) -> \(lastMove.previousBlocksPlaced)")
        print("[Undo] Lines Cleared: \(linesCleared) -> \(lastMove.previousLinesCleared)")
        print("[Undo] Current Chain: \(currentChain) -> \(lastMove.previousCurrentChain)")
        
        // Restore the previous state
        grid = lastMove.previousGrid
        tray = lastMove.previousTray
        score = lastMove.previousScore
        level = lastMove.previousLevel
        blocksPlaced = lastMove.previousBlocksPlaced
        linesCleared = lastMove.previousLinesCleared
        currentChain = lastMove.previousCurrentChain
        usedColors = lastMove.previousUsedColors
        usedShapes = lastMove.previousUsedShapes
        isPerfectLevel = lastMove.previousIsPerfectLevel
        
        // Update undo availability
        canUndo = !undoStack.isEmpty
        
        // Update undo count
        undoCount += 1
        
        // Update undo achievements
        achievementsManager.updateAchievement(id: "undo_5", value: undoCount)
        achievementsManager.updateAchievement(id: "undo_20", value: undoCount)
        
        // Notify delegate
        delegate?.gameStateDidUpdate()
        
        // Reset ad manager state for new game if needed
        await AdManager.shared.resetGameState()
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
        // Check if ad is available before showing
        guard await AdManager.shared.isAdAvailable() else {
            // If ad is not available, proceed without showing ad
            completion(true)
            return
        }
        
        // Show the rewarded interstitial ad
        await AdManager.shared.showRewardedInterstitial(onReward: {
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
        
        // Save state for undo before making any changes
        saveStateForUndo(block: block, position: (row: row, col: col))
        
        // Track the positions of the current shape
        var currentShapePositions = Set<String>()
        
        // Place the block
        for (dx, dy) in block.shape.cells {
            let x = col + dx
            let y = row + dy
            grid[y][x] = block.color
            currentShapePositions.insert("\(x),\(y)")
        }
        
        // Remove the block from the tray
        if let index = tray.firstIndex(where: { $0.id == block.id }) {
            tray.remove(at: index)
        }
        
        // Update game state
        blocksPlaced += 1
        usedColors.insert(block.color)
        usedShapes.insert(block.shape)
        
        // Check for touching blocks and award points
        var totalTouchingPoints = 0
        var hasAnyTouches = false
        
        for (dx, dy) in block.shape.cells {
            let x = col + dx
            let y = row + dy
            let touchingCount = countTouchingBlocks(at: (x, y), excluding: currentShapePositions)
            if touchingCount > 0 {
                hasAnyTouches = true
                totalTouchingPoints += touchingCount
                // Add base points for each touch
                addScore(touchingCount, at: CGPoint(x: CGFloat(x) * GameConstants.blockSize, y: CGFloat(y) * GameConstants.blockSize))
                print("[Touch] Block at (\(x),\(y)) touches \(touchingCount) blocks. +\(touchingCount) points!")
            }
        }
        
        // Award bonus points for multiple touches
        if hasAnyTouches && totalTouchingPoints >= 3 {
            let bonusPoints = totalTouchingPoints * 2
            addScore(bonusPoints, at: CGPoint(x: frameSize.width/2, y: frameSize.height/2))
            print("[Bonus] Multiple touches! +\(bonusPoints) bonus points!")
        }
        
        // Check for matches and patterns
        checkMatches()
        
        // Refill tray if needed
        if tray.count < requiredShapesToFit {
            refillTray()
        }
        
        // Check for game over
        checkGameOver()
        
        // Notify delegate
        delegate?.gameStateDidUpdate()
        
        return true
    }
    
    private func countTouchingBlocks(at position: (x: Int, y: Int), excluding currentShapePositions: Set<String>) -> Int {
        var count = 0
        let directions = [(-1,0), (1,0), (0,-1), (0,1)]
        
        for (dx, dy) in directions {
            let nx = position.x + dx
            let ny = position.y + dy
            
            if nx >= 0 && nx < GameConstants.gridSize && ny >= 0 && ny < GameConstants.gridSize {
                if grid[ny][nx] != nil && !currentShapePositions.contains("\(nx),\(ny)") {
                    count += 1
                }
            }
        }
        
        return count
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
        
        // First collect all lines that need to be cleared
        var rowsToClear: Set<Int> = []
        var columnsToClear: Set<Int> = []
        
        // Check rows
        for row in 0..<GameConstants.gridSize {
            if isRowFull(row) {
                rowsToClear.insert(row)
                clearedPositions.append((row, -1))  // -1 indicates entire row
                linesClearedThisTurn += 1
                addScore(100, at: CGPoint(x: frameSize.width/2, y: CGFloat(row) * GameConstants.blockSize))
            }
        }
        
        // Check columns
        for col in 0..<GameConstants.gridSize {
            if isColumnFull(col) {
                columnsToClear.insert(col)
                clearedPositions.append((-1, col))  // -1 indicates entire column
                linesClearedThisTurn += 1
                addScore(100, at: CGPoint(x: CGFloat(col) * GameConstants.blockSize, y: frameSize.height/2))
            }
        }
        
        // Clear all rows and columns at once
        for row in rowsToClear {
            clearRow(row)
        }
        
        for col in columnsToClear {
            clearColumn(col)
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
            
            // Check for quick clear achievement (within 5 seconds of game start)
            if let startTime = gameStartTime {
                let timeSinceStart = Date().timeIntervalSince(startTime)
                if timeSinceStart <= 5.0 {
                    achievementsManager.increment(id: "quick_clear")
                }
            }
            
            // Check for speed master achievement (5 lines within 30 seconds)
            if linesClearedThisTurn >= 5 {
                if let startTime = gameStartTime {
                    let timeSinceStart = Date().timeIntervalSince(startTime)
                    if timeSinceStart <= 30.0 {
                        achievementsManager.increment(id: "speed_master")
                    }
                }
            }
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
        
        // Track line clear event
        if linesClearedThisTurn > 0 {
            analyticsManager.trackEvent(.lineCleared(count: linesClearedThisTurn))
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
        
        let oldScore = temporaryScore
        temporaryScore += points
        print("[Score] Added \(points) points (from \(oldScore) to \(temporaryScore))")
        
        // Track score event
        analyticsManager.trackEvent(.levelComplete(level: level, score: temporaryScore))
        
        // Show score animation if position is provided
        if let position = position {
            delegate?.showScoreAnimation(points: points, at: position)
        }
        
        achievementsManager.updateAchievement(id: "score_1000", value: temporaryScore)
        
        // Update high scores locally and check against leaderboard
        if temporaryScore > highScore {
            highScore = temporaryScore
            userDefaults.set(highScore, forKey: scoreKey)
            achievementsManager.updateAchievement(id: "high_score", value: temporaryScore)
            print("[HighScore] New all-time high score: \(temporaryScore)")
            
            // Update high score achievement
            achievementsManager.increment(id: "high_score")
            
            // Check if this is a new leaderboard high score
            if temporaryScore > leaderboardHighScore {
                Task {
                    // Check network connectivity first
                    guard NetworkMonitor.shared.isConnected else {
                        print("[Leaderboard] No internet connection - will retry later")
                        return
                    }
                    
                    // Check if user is authenticated
                    guard Auth.auth().currentUser != nil else {
                        print("[Leaderboard] User not authenticated - will retry later")
                        return
                    }
                    
                    do {
                        print("[Leaderboard] Updating leaderboard with new high score: \(temporaryScore)")
                        try await LeaderboardService.shared.updateLeaderboard(
                            score: temporaryScore,
                            level: level,
                            type: .score
                        )
                        print("[Leaderboard] Successfully updated leaderboard with new high score")
                        
                        // Refresh leaderboard high score
                        await fetchLeaderboardHighScore()
                        
                        // Update Game Center leaderboard
                        GameCenterManager.shared.submitScore(temporaryScore, for: .score, period: "alltime")
                    } catch {
                        print("[Leaderboard] Error updating leaderboard: \(error.localizedDescription)")
                        // Store the score for later update
                        let pendingScore = PendingScore(score: temporaryScore, timestamp: Date())
                        userDefaults.set(try? JSONEncoder().encode(pendingScore), forKey: "pendingLeaderboardScore")
                    }
                }
            }
        }
        
        // Update level high score
        let levelHighScoreKey = "highScore_level_\(level)"
        let prevLevelHigh = userDefaults.integer(forKey: levelHighScoreKey)
        if temporaryScore > prevLevelHigh {
            userDefaults.set(temporaryScore, forKey: levelHighScoreKey)
            print("[HighScore] New high score for level \(level): \(temporaryScore)")
        }
        
        delegate?.gameStateDidUpdate()
        
        // Check for level up after every score change
        let requiredScore = calculateRequiredScore()
        if temporaryScore >= requiredScore && !levelComplete {
            handleLevelComplete()
        }
    }
    
    // Add this struct at the top of the file
    private struct PendingScore: Codable {
        let score: Int
        let timestamp: Date
    }
    
    // Add this function to handle pending score updates
    private func handlePendingScoreUpdates() {
        guard let pendingScoreData = userDefaults.data(forKey: "pendingLeaderboardScore"),
              let pendingScore = try? JSONDecoder().decode(PendingScore.self, from: pendingScoreData),
              NetworkMonitor.shared.isConnected else {
            return
        }
        
        Task {
            do {
                print("[Leaderboard] Attempting to update pending score: \(pendingScore.score)")
                try await LeaderboardService.shared.updateLeaderboard(
                    score: pendingScore.score,
                    type: .score
                )
                print("[Leaderboard] Successfully updated pending score")
                userDefaults.removeObject(forKey: "pendingLeaderboardScore")
            } catch {
                print("[Leaderboard] Error updating pending score: \(error.localizedDescription)")
            }
        }
    }

    private func updateLeaderboardAfterGameOver() {
        Task {
            do {
                // Only update if score is greater than 0
                if score > 0 {
                    print("[Leaderboard] Attempting to update leaderboard with score: \(score)")
                    try await LeaderboardService.shared.updateLeaderboard(
                        score: score,
                        level: level,
                        type: .score
                    )
                    print("[Leaderboard] Successfully updated leaderboard")
                    
                    // Refresh leaderboard high score
                    await fetchLeaderboardHighScore()
                } else {
                    print("[Leaderboard] Skipping update - score is 0")
                }
            } catch LeaderboardError.rateLimited {
                print("[Leaderboard] Rate limited - skipping update")
            } catch LeaderboardError.notAuthenticated {
                print("[Leaderboard] User not authenticated - skipping update")
            } catch {
                print("[Leaderboard] Error updating leaderboard: \(error.localizedDescription)")
            }
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
                // Check if ad is available before showing
                Task {
                    if await AdManager.shared.isAdAvailable() {
                        await AdManager.shared.showRewardedInterstitial(onReward: {
                            self.adsWatchedThisGame += 1
                            self.levelsCompletedSinceLastAd = 0
                            self.continueLevelUp()
                        })
                    } else {
                        // If ad is not available, proceed without showing ad
                        self.levelsCompletedSinceLastAd = 0
                        self.continueLevelUp()
                    }
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
            achievementsManager.increment(id: "highest_level")
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
        // Clear the grid immediately and notify delegate
        self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        self.delegate?.gameStateDidUpdate()
        
        // Add a small delay before advancing to ensure the level complete overlay is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.level += 1
            print("[Level] Advancing to level \(self.level)")
            self.setSeed(for: self.level)
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
        print("[GameState] 🎮 Game Over - Final Score: \(temporaryScore)")
        
        // Set game over state first
        isGameOver = true
        
        // Update the actual score with the temporary score
        score = temporaryScore
        
        // Update high score if needed
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "highScore")
            print("[GameState] 🏆 New High Score: \(highScore)")
        }
        
        // Update leaderboard only if not a guest user
        if !UserDefaults.standard.bool(forKey: "isGuest") {
            Task {
                do {
                    print("[GameState] 📊 Updating leaderboard with score: \(score)")
                    try await FirebaseManager.shared.submitScore(score, level: level, time: totalPlayTime)
                    print("[GameState] ✅ Leaderboard updated successfully")
                } catch {
                    print("[GameState] ❌ Failed to update leaderboard: \(error.localizedDescription)")
                }
            }
        } else {
            print("[GameState] 👤 Guest user - skipping leaderboard update")
        }
        
        // Update achievements
        print("[GameState] 🏅 Updating achievements")
        achievementsManager.updateAchievement(id: "games_10", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_50", value: gamesCompleted)
        achievementsManager.updateAchievement(id: "games_100", value: gamesCompleted)
        print("[GameState] ✅ Achievements updated successfully")
        
        // Notify observers
        NotificationCenter.default.post(name: .gameOver, object: nil)
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
                        
                        // Track pattern formation
                        let patternKey = "group_\(group.count)"
                        analyticsManager.trackEvent(.patternFormed(pattern: patternKey, score: 500))
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
        // Skip if user is a guest
        if UserDefaults.standard.bool(forKey: "isGuest") {
            print("[Leaderboard] 👤 Guest user - skipping leaderboard update")
            return
        }
        
        Task {
            do {
                // Only update if score is greater than 0
                if score > 0 {
                    print("[Leaderboard] Attempting to update leaderboard with score: \(score)")
                    try await LeaderboardService.shared.updateLeaderboard(
                        score: score,
                        level: level,
                        type: .score
                    )
                    print("[Leaderboard] Successfully updated leaderboard")
                    
                    // Refresh leaderboard high score
                    await fetchLeaderboardHighScore()
                } else {
                    print("[Leaderboard] Skipping update - score is 0")
                }
            } catch LeaderboardError.rateLimited {
                print("[Leaderboard] Rate limited - skipping update")
            } catch LeaderboardError.notAuthenticated {
                print("[Leaderboard] User not authenticated - skipping update")
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
            try? await saveProgress()
        }
    }
    
    // Add a new method to handle user confirmation of level completion
    func confirmLevelCompletion() {
        guard levelComplete else { return }
        
        // Notify that level is complete for timed mode
        if UserDefaults.standard.bool(forKey: "isTimedMode") {
            NotificationCenter.default.post(name: .levelCompleted, object: nil)
        }
        
        advanceToNextLevel()
    }
    
    // Add a new function for manually ending the game from settings
    func endGameFromSettings() {
        isGameOver = true
        saveStatistics() // Save statistics when game is ended from settings
        playTimeTimer?.invalidate()
        Task { @MainActor in
            updatePlayTime() // Final update of play time
            try? await saveProgress()
            
            // Update leaderboard if user is not guest
            if !UserDefaults.standard.bool(forKey: "isGuest") {
                do {
                    print("[Leaderboard] Updating leaderboard after manual end - Score: \(score)")
                    try await LeaderboardService.shared.updateLeaderboard(
                        score: score,
                        level: level,
                        type: .score
                    )
                    print("[Leaderboard] Successfully updated leaderboard after manual end")
                    
                    // Refresh leaderboard high score
                    await fetchLeaderboardHighScore()
                } catch {
                    print("[Leaderboard] Error updating leaderboard after manual end: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func hasSavedGame() -> Bool {
        let hasFlag = userDefaults.bool(forKey: hasSavedGameKey)
        let hasData = userDefaults.data(forKey: progressKey) != nil
        return hasFlag && hasData
    }
    
    func loadSavedGame() async throws {
        do {
            let progress = try await FirebaseManager.shared.loadGameProgress()
            
            // Update state on main thread
            await MainActor.run {
                self.score = progress.score
                self.level = progress.level
                self.blocksPlaced = progress.blocksPlaced
                self.linesCleared = progress.linesCleared
                self.gamesCompleted = progress.gamesCompleted
                self.perfectLevels = progress.perfectLevels
                self.totalPlayTime = progress.totalPlayTime
                self.highScore = progress.highScore
                self.highestLevel = progress.highestLevel
                
                // Convert serialized grid back to BlockColor array
                self.grid = progress.grid.map { row in
                    row.map { colorString in
                        colorString == "nil" ? nil : BlockColor(rawValue: colorString)
                    }
                }
                self.tray = progress.tray
                
                // Load FPS from UserDefaults
                if let data = self.userDefaults.data(forKey: self.progressKey),
                   let progressData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let savedFPS = progressData["targetFPS"] as? Int {
                    self.targetFPS = savedFPS
                    // Update the FPS in the game view
                    self.delegate?.updateFPS(savedFPS)
                }
            }
            
            // Notify success
            NotificationCenter.default.post(name: .gameStateLoaded, object: nil)
        } catch {
            // Notify failure
            NotificationCenter.default.post(name: .gameStateLoadFailed, object: error)
            throw GameError.loadFailed(error)
        }
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
        highScore = userDefaults.integer(forKey: scoreKey)
        highestLevel = userDefaults.integer(forKey: levelKey)
        
        print("[GameState] Loaded statistics - Blocks: \(blocksPlaced), Lines: \(linesCleared), Games: \(gamesCompleted), Perfect: \(perfectLevels), High Score: \(highScore), Highest Level: \(highestLevel)")

        // Load from Firebase if user is logged in and auto-sync is enabled
        Task {
            if !UserDefaults.standard.bool(forKey: "isGuest") && autoSyncEnabled {
                do {
                    let progress = try await FirebaseManager.shared.loadGameProgress()
                    
                    // Only update if Firebase data is more recent
                    if let localLastSave = userDefaults.object(forKey: "lastSaveTime") as? Date,
                       progress.lastSaveTime > localLastSave {
                        // Update local statistics with Firebase data
                        blocksPlaced = progress.blocksPlaced
                        linesCleared = progress.linesCleared
                        gamesCompleted = progress.gamesCompleted
                        perfectLevels = progress.perfectLevels
                        totalPlayTime = progress.totalPlayTime
                        
                        // Only update high score if Firebase has a higher score
                        if progress.highScore > highScore {
                            highScore = progress.highScore
                            userDefaults.set(highScore, forKey: scoreKey)
                        }
                        
                        // Only update highest level if Firebase has a higher level
                        if progress.highestLevel > highestLevel {
                            highestLevel = progress.highestLevel
                            userDefaults.set(highestLevel, forKey: levelKey)
                        }
                        
                        // Save all statistics to UserDefaults
                        saveStatisticsToUserDefaults()
                        
                        print("[GameState] Updated local statistics with Firebase data")
                    }
                } catch {
                    print("[GameState] Error loading statistics from Firebase: \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveStatisticsToUserDefaults() {
        userDefaults.set(blocksPlaced, forKey: blocksPlacedKey)
        userDefaults.set(linesCleared, forKey: linesClearedKey)
        userDefaults.set(gamesCompleted, forKey: gamesCompletedKey)
        userDefaults.set(perfectLevels, forKey: perfectLevelsKey)
        userDefaults.set(totalPlayTime, forKey: totalPlayTimeKey)
        userDefaults.set(highScore, forKey: scoreKey)
        userDefaults.set(highestLevel, forKey: levelKey)
        userDefaults.set(Date(), forKey: "lastSaveTime")
        
        // Save offline queue
        if let queueData = try? JSONEncoder().encode(offlineChangesQueue) {
            userDefaults.set(queueData, forKey: offlineQueueKey)
        }
        
        userDefaults.synchronize()
    }

    private func loadOfflineQueue() {
        if let queueData = userDefaults.data(forKey: offlineQueueKey),
           let queue = try? JSONDecoder().decode([OfflineQueueEntry].self, from: queueData) {
            offlineChangesQueue = queue
        }
    }

    @MainActor
    private func saveStatistics() {
        print("[GameState] Saving statistics to UserDefaults")
        
        // Save all statistics to UserDefaults
        saveStatisticsToUserDefaults()
        
        print("[GameState] Saved statistics - Blocks: \(blocksPlaced), Lines: \(linesCleared), Games: \(gamesCompleted), Perfect: \(perfectLevels), High Score: \(highScore), Highest Level: \(highestLevel)")

        // Create current progress
        let currentProgress = GameProgress(
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
            tray: tray,
            lastSaveTime: Date()
        )

        // Sync with Firebase if user is logged in and auto-sync is enabled
        Task {
            if !UserDefaults.standard.bool(forKey: "isGuest") && autoSyncEnabled {
                let now = Date()
                let lastSaveTime = userDefaults.object(forKey: "lastFirebaseSaveTime") as? Date ?? Date.distantPast
                
                // Only sync if at least 30 seconds have passed since last sync
                if now.timeIntervalSince(lastSaveTime) >= 30 {
                    do {
                        // Add to offline queue first
                        offlineChangesQueue.append(OfflineQueueEntry(progress: currentProgress, timestamp: now))
                        saveStatisticsToUserDefaults()
                        
                        // Try to sync with Firebase
                        try await FirebaseManager.shared.saveGameProgress(currentProgress)
                        
                        // If successful, clear the queue and update last sync time
                        offlineChangesQueue.removeAll()
                        userDefaults.set(now, forKey: "lastFirebaseSaveTime")
                        saveStatisticsToUserDefaults()
                        
                        print("[GameState] Successfully synced statistics with Firebase")
                    } catch {
                        print("[GameState] Error syncing statistics with Firebase: \(error.localizedDescription)")
                        // Keep the offline queue for later sync
                    }
                }
            }
        }
    }

    // Update offline queue sync method
    func syncOfflineQueue() async throws {
        guard !UserDefaults.standard.bool(forKey: "isGuest") && autoSyncEnabled else { return }
        
        // Load offline queue
        loadOfflineQueue()
        
        // Sort queue by timestamp to ensure chronological order
        offlineChangesQueue.sort { $0.timestamp < $1.timestamp }
        
        // Try to sync each queued change
        for entry in offlineChangesQueue {
            do {
                try await FirebaseManager.shared.saveGameProgress(entry.progress)
                offlineChangesQueue.removeFirst()
                saveStatisticsToUserDefaults()
            } catch {
                print("[GameState] Error syncing queued progress: \(error.localizedDescription)")
                throw error // Propagate the error
            }
        }
    }

    // Add conflict resolution method
    private func resolveConflicts(localProgress: GameProgress, cloudProgress: GameProgress) -> GameProgress {
        // Take the higher values for statistics
        let resolvedProgress = GameProgress(
            score: max(localProgress.score, cloudProgress.score),
            level: max(localProgress.level, cloudProgress.level),
            blocksPlaced: max(localProgress.blocksPlaced, cloudProgress.blocksPlaced),
            linesCleared: max(localProgress.linesCleared, cloudProgress.linesCleared),
            gamesCompleted: max(localProgress.gamesCompleted, cloudProgress.gamesCompleted),
            perfectLevels: max(localProgress.perfectLevels, cloudProgress.perfectLevels),
            totalPlayTime: max(localProgress.totalPlayTime, cloudProgress.totalPlayTime),
            highScore: max(localProgress.highScore, cloudProgress.highScore),
            highestLevel: max(localProgress.highestLevel, cloudProgress.highestLevel),
            grid: localProgress.grid, // Keep local grid state
            tray: localProgress.tray, // Keep local tray state
            lastSaveTime: Date()
        )
        return resolvedProgress
    }

    func handleAppWillResignActive() async {
        // Save statistics before app goes to background
        saveStatistics()
        
        do {
            try await saveProgress()
            print("[GameState] Successfully saved game progress when app resigned active")
        } catch {
            print("[GameState] Error saving game progress when app resigned active: \(error.localizedDescription)")
        }
    }
    
    func loadCloudData() async {
        do {
            let progress = try await FirebaseManager.shared.loadGameProgress()
            // Since we're @MainActor, we don't need MainActor.run
            self.score = progress.score
            self.level = progress.level
            self.blocksPlaced = progress.blocksPlaced
            self.linesCleared = progress.linesCleared
            self.gamesCompleted = progress.gamesCompleted
            self.perfectLevels = progress.perfectLevels
            self.totalPlayTime = progress.totalPlayTime
            self.highScore = progress.highScore
            self.highestLevel = progress.highestLevel
            print("[GameState] Successfully loaded cloud data")
        } catch {
            print("[GameState] Error loading cloud data: \(error.localizedDescription)")
        }
    }
    
    func saveProgress() async throws {
        do {
            // Check if there's a saved game and show warning if needed
            if userDefaults.bool(forKey: hasSavedGameKey) {
                // Post notification to show warning
                NotificationCenter.default.post(name: .showSaveGameWarning, object: nil)
                return
            }
            
            // Convert grid to a format Firebase can handle
            let serializedGrid = grid.map { row in
                row.map { color in
                    color?.rawValue ?? "nil"
                }
            }
            
            let progress = GameProgress(
                score: score,
                level: level,
                blocksPlaced: blocksPlaced,
                linesCleared: linesCleared,
                gamesCompleted: gamesCompleted,
                perfectLevels: perfectLevels,
                totalPlayTime: totalPlayTime,
                highScore: highScore,
                highestLevel: highestLevel,
                grid: serializedGrid,
                tray: tray
            )
            
            // Try to save to Firebase, but continue with local save even if it fails
            do {
                try await FirebaseManager.shared.saveGameProgress(progress)
            } catch {
                print("[GameState] Firebase save failed: \(error.localizedDescription)")
                // Continue with local save even if Firebase save fails
            }
            
            // Update local storage on main actor
            try await MainActor.run {
                let progressData: [String: Any] = [
                    "score": progress.score,
                    "level": progress.level,
                    "blocksPlaced": progress.blocksPlaced,
                    "linesCleared": progress.linesCleared,
                    "gamesCompleted": progress.gamesCompleted,
                    "perfectLevels": progress.perfectLevels,
                    "totalPlayTime": progress.totalPlayTime,
                    "highScore": progress.highScore,
                    "highestLevel": progress.highestLevel,
                    "targetFPS": targetFPS,
                    "grid": serializedGrid,
                    "tray": tray.map { block in
                        [
                            "color": block.color.rawValue,
                            "shape": block.shape.rawValue
                        ]
                    },
                    "isTimedMode": UserDefaults.standard.bool(forKey: "isTimedMode")
                ]
                let data = try JSONSerialization.data(withJSONObject: progressData)
                self.userDefaults.set(data, forKey: self.progressKey)
                self.userDefaults.set(true, forKey: self.hasSavedGameKey)
                self.userDefaults.synchronize()
                
                // Notify success
                NotificationCenter.default.post(name: .gameStateSaved, object: nil)
            }
        } catch {
            // Notify failure
            NotificationCenter.default.post(name: .gameStateSaveFailed, object: error)
            throw GameError.saveFailed(error)
        }
    }
    
    func confirmSaveOverwrite() async throws {
        // Delete existing save first
        deleteSavedGame()
        // Then save new game
        try await saveProgress()
    }

    func deleteSavedGame() {
        userDefaults.removeObject(forKey: progressKey)
        userDefaults.set(false, forKey: hasSavedGameKey)
        userDefaults.synchronize()
    }
    
    func cleanup() async {
        await MemorySystem.shared.cleanupMemory()
    }
    
    func resetLevelComplete() {
        levelComplete = false
    }
    
    func reset() {
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        score = 0
        temporaryScore = 0
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
            let currentTime = CACurrentMediaTime()
            guard currentTime - lastHintTime >= hintCooldown else {
                print("[Hint] Hint on cooldown")
                return
            }
            
            let hasUnlimitedHints = await subscriptionManager.hasFeature(.hints)
            if hintsUsedThisGame >= 3 && !hasUnlimitedHints {
                return
            }
            
            print("[Hint] Attempting to show hint. Current hints used: \(hintsUsedThisGame)")
            
            // Try to use cached hint first
            if let cached = cachedHint, canPlaceBlock(cached.block, at: CGPoint(x: cached.position.col, y: cached.position.row)) {
                delegate?.highlightHint(block: cached.block, at: cached.position)
                if !hasUnlimitedHints {
                    hintsUsedThisGame += 1
                }
                lastHintTime = currentTime
                return
            }
            
            // If no valid cached hint, find a new one
            if let (block, position) = findValidMove() {
                cachedHint = (block, position)
                delegate?.highlightHint(block: block, at: position)
                if !hasUnlimitedHints {
                    hintsUsedThisGame += 1
                }
                lastHintTime = currentTime
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
                            touchingCount += countTouchingBlocks(at: (x, y), excluding: currentShapePositions)
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
        
        // Dynamic difficulty adjustment based on player performance
        let playerSkill = calculatePlayerSkill()
        
        // Update random shapes on board with dynamic adjustment
        if level >= 350 {
            randomShapesOnBoard = max(0, 5 - playerSkill)
            requiredShapesToFit = 3
        } else if level >= 150 {
            randomShapesOnBoard = max(0, 4 - playerSkill)
            requiredShapesToFit = 3
        } else if level >= 100 {
            randomShapesOnBoard = max(0, 3 - playerSkill)
            requiredShapesToFit = 3
        } else if level >= 75 {
            randomShapesOnBoard = max(0, 2 - playerSkill)
            requiredShapesToFit = 3
        } else if level >= 60 {
            randomShapesOnBoard = max(0, 1 - playerSkill)
            requiredShapesToFit = 3
        } else {
            randomShapesOnBoard = 0
            requiredShapesToFit = 3
        }
        
        // Adjust shape complexity based on player skill
        adjustShapeComplexity(playerSkill: playerSkill)
    }

    private func calculatePlayerSkill() -> Int {
        // Calculate player skill based on various factors
        let perfectLevelsWeight = perfectLevels * 2
        let chainBonusWeight = currentChain
        let averageScorePerLevel = Double(score) / Double(max(1, level))
        let scoreWeight = Int(averageScorePerLevel / 1000)
        
        return min(5, (perfectLevelsWeight + chainBonusWeight + scoreWeight) / 3)
    }

    private func adjustShapeComplexity(playerSkill: Int) {
        // Adjust shape complexity based on player skill
        let baseComplexity = level / 10
        let adjustedComplexity = baseComplexity + playerSkill
        
        // Update available shapes based on adjusted complexity
        if adjustedComplexity >= 50 {
            // All shapes available
            return
        } else if adjustedComplexity >= 40 {
            // Most complex shapes available
            return
        } else if adjustedComplexity >= 30 {
            // Complex shapes available
            return
        } else if adjustedComplexity >= 20 {
            // Medium complexity shapes available
            return
        } else if adjustedComplexity >= 10 {
            // Basic shapes available
            return
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
        
        // Cleanup before spawning new shapes
        Task {
            await cleanupMemory()
        }
        
        spawnRandomShapesOnBoard()
        refillTray()
        levelComplete = false
        isPerfectLevel = true
        
        // Track game start
        analyticsManager.trackEvent(.levelStart(level: level))
    }
    
    private func cleanupMemory() async {
        // Clear cached data that's older than 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        cachedData = cachedData.filter { key, value in
            if let timestamp = value as? Date, timestamp < fiveMinutesAgo {
                return false
            }
            return true
        }
        
        // Clear any temporary data
        previousGrid = nil
        previousTray = nil
        lastMove = nil
        
        // Clear offline queue if it's too large
        if offlineChangesQueue.count > 100 {
            offlineChangesQueue = Array(offlineChangesQueue.suffix(100))
        }
        
        // Force garbage collection of unused resources
        autoreleasepool {
            // Clear any temporary arrays or dictionaries
            usedColors.removeAll()
            usedShapes.removeAll()
        }
        
        // Call the shared memory system cleanup
        await MemorySystem.shared.cleanupMemory()
    }
    
    private func setupMemoryManagement() {
        // Subscribe to memory status updates
        Task { @MainActor in
            // Convert publisher to async sequence
            let memoryStatusStream = MemorySystem.shared.memoryStatus.values
            
            for await status in memoryStatusStream {
                switch status {
                case .critical:
                    await handleCriticalMemory()
                case .warning:
                    await handleMemoryWarning()
                case .normal:
                    break
                }
            }
        }
        
        // Add memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarningNotification),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarningNotification() {
        Task { @MainActor in
            await handleMemoryWarning()
        }
    }
    
    internal func handleCriticalMemory() async {
        // Clear all temporary data
        previousGrid = nil
        previousTray = nil
        lastMove = nil
        previousScore = 0
        previousLevel = 1
        
        // Clear offline queue
        offlineChangesQueue.removeAll()
        
        // Clear any temporary arrays
        usedColors.removeAll()
        usedShapes.removeAll()
        
        // Clear cached data
        cachedData.removeAll()
        
        // Notify delegate to clear any cached resources
        delegate?.gameStateDidUpdate()
    }
    
    private func handleMemoryWarning() async {
        // Clear temporary data
        previousGrid = nil
        previousTray = nil
        lastMove = nil
        
        // Clear offline queue if it's too large
        if offlineChangesQueue.count > 100 {
            offlineChangesQueue = Array(offlineChangesQueue.suffix(100))
        }
        
        // Clear any temporary arrays
        usedColors.removeAll()
        usedShapes.removeAll()
        
        // Clear old cached data
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        cachedData = cachedData.filter { key, value in
            if let timestamp = value as? Date, timestamp < fiveMinutesAgo {
                return false
            }
            return true
        }
        
        // Notify delegate to clear any cached resources
        delegate?.gameStateDidUpdate()
    }
    
    private func checkMemoryUsage() async {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastMemoryCleanup) > memoryCleanupInterval {
            await cleanupMemory()
            lastMemoryCleanup = currentTime
        }
    }
    
    // Add memory check to update method
    func update() async {
        await checkMemoryUsage()
        // ... rest of update logic ...
    }
    
    private func checkUndoAvailability() async {
        // Check if user has unlimited undos from subscription or Remove Ads purchase
        let hasEliteSubscription = await subscriptionManager.hasFeature(.unlimitedUndos)
        let hasRemovedAds = await subscriptionManager.hasFeature(.noAds)
        unlimitedUndos = hasEliteSubscription || hasRemovedAds
        
        // Get purchased undos
        purchasedUndos = subscriptionManager.purchasedUndos
        
        // Update canUndo state
        await MainActor.run {
            canUndo = !undoStack.isEmpty && (unlimitedUndos || adUndoCount > 0 || purchasedUndos > 0)
        }
    }
    
    func addMoveToUndoStack(_ move: GameMove) {
        // Add move to stack
        undoStack.push(move)
        
        // Update undo availability
        Task {
            await checkUndoAvailability()
        }
    }
    
    // Update the move method to track moves for undo
    func move(_ block: Block, to position: (row: Int, col: Int)) {
        // Save current state for undo
        let move = GameMove(
            block: block,
            position: position,
            previousGrid: grid,
            previousTray: tray,
            previousScore: score,
            previousLevel: level,
            previousBlocksPlaced: blocksPlaced,
            previousLinesCleared: linesCleared,
            previousCurrentChain: currentChain,
            previousUsedColors: usedColors,
            previousUsedShapes: usedShapes,
            previousIsPerfectLevel: isPerfectLevel
        )
        
        // Add to undo stack
        addMoveToUndoStack(move)
        
        // Track block placement
        analyticsManager.trackEvent(.blockPlaced(color: block.color, position: (position.row, position.col)))
    }
    
    func startGame() {
        // ... existing code ...
        
        // Track game start
        analyticsManager.trackEvent(.levelStart(level: level))
        
        // ... rest of existing code ...
    }
    
    func endGame() {
        // ... existing code ...
        
        // Track game end
        analyticsManager.trackEvent(.sessionEnd)
        
        // ... rest of existing code ...
    }

    func wouldClearLines(block: Block, at position: CGPoint) -> (rows: Set<Int>, columns: Set<Int>) {
        let row = Int(position.y)
        let col = Int(position.x)
        
        print("[LineClear] Checking lines for block at position: (\(col), \(row))")
        
        // Check if position is within bounds
        guard row >= 0 && row < GameConstants.gridSize && col >= 0 && col < GameConstants.gridSize else {
            print("[LineClear] Position out of bounds: (\(col), \(row))")
            return (Set<Int>(), Set<Int>())
        }
        
        // Create a temporary grid to simulate the placement
        var tempGrid = grid
        
        // Place the block in the temporary grid
        for (dx, dy) in block.shape.cells {
            let x = col + dx
            let y = row + dy
            if x >= 0 && x < GameConstants.gridSize && y >= 0 && y < GameConstants.gridSize {
                tempGrid[y][x] = block.color
                print("[LineClear] Placed block cell at: (\(x), \(y))")
            }
        }
        
        // Check for full rows and columns
        var rowsToClear = Set<Int>()
        var columnsToClear = Set<Int>()
        
        // Check rows
        for y in 0..<GameConstants.gridSize {
            var isRowFull = true
            for x in 0..<GameConstants.gridSize {
                if tempGrid[y][x] == nil {
                    isRowFull = false
                    break
                }
            }
            if isRowFull {
                rowsToClear.insert(y)
                print("[LineClear] Row \(y) would be cleared")
            }
        }
        
        // Check columns
        for x in 0..<GameConstants.gridSize {
            var isColumnFull = true
            for y in 0..<GameConstants.gridSize {
                if tempGrid[y][x] == nil {
                    isColumnFull = false
                    break
                }
            }
            if isColumnFull {
                columnsToClear.insert(x)
                print("[LineClear] Column \(x) would be cleared")
            }
        }
        
        print("[LineClear] Found \(rowsToClear.count) rows and \(columnsToClear.count) columns to clear")
        return (rowsToClear, columnsToClear)
    }
    
    // Add this method to preload settings resources
    func preloadSettingsResources() async {
        // Preload any heavy resources needed for settings
        await subscriptionManager.preloadSubscriptionStatus()
        await achievementsManager.preloadAchievements()
    }
    
    private func handleLevelComplete() {
        print("[Level] Score threshold met for level \(level). Level complete!")
        levelComplete = true
        
        // Transfer temporary score to main score
        score = temporaryScore
        
        // Update achievements
        achievementsManager.updateAchievement(id: "level_complete", value: level)
        achievementsManager.updateAchievement(id: "score_1000", value: score)
        
        // Update high scores
        if score > highScore {
            highScore = score
            userDefaults.set(highScore, forKey: scoreKey)
            achievementsManager.updateAchievement(id: "high_score", value: score)
            print("[HighScore] New all-time high score: \(score)")
        }
        
        // Update level high score
        let levelHighScoreKey = "highScore_level_\(level)"
        let prevLevelHigh = userDefaults.integer(forKey: levelHighScoreKey)
        if score > prevLevelHigh {
            userDefaults.set(score, forKey: levelHighScoreKey)
            print("[HighScore] New high score for level \(level): \(score)")
        }
        
        // Update leaderboard only if not a guest user
        if !UserDefaults.standard.bool(forKey: "isGuest") {
            Task {
                do {
                    print("[Leaderboard] Updating leaderboard after level completion - Score: \(score)")
                    try await LeaderboardService.shared.updateLeaderboard(
                        score: score,
                        level: level,
                        type: .score
                    )
                    print("[Leaderboard] Successfully updated leaderboard after level completion")
                    
                    // Refresh leaderboard high score
                    await fetchLeaderboardHighScore()
                    
                    // Post level completed notification
                    NotificationCenter.default.post(name: .levelCompleted, object: nil)
                } catch {
                    print("[Leaderboard] Error updating leaderboard after level completion: \(error.localizedDescription)")
                }
            }
        } else {
            print("[Leaderboard] 👤 Guest user - skipping leaderboard update")
            // Still post level completed notification
            NotificationCenter.default.post(name: .levelCompleted, object: nil)
        }
        
        // Notify delegate
        delegate?.gameStateDidUpdate()
    }
    
    private func saveGameState() async throws {
        // ... existing save code ...
        
        do {
            // Save to UserDefaults
            let gameProgress = GameProgress(
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
                tray: tray,
                lastSaveTime: Date()
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(gameProgress)
            userDefaults.set(data, forKey: progressKey)
            userDefaults.set(true, forKey: hasSavedGameKey)
            
            // Post save success notification
            NotificationCenter.default.post(name: .gameStateSaved, object: nil)
        } catch {
            print("[GameState] Error saving game state: \(error.localizedDescription)")
            // Post save failure notification
            NotificationCenter.default.post(name: .gameStateSaveFailed, object: nil)
            throw GameError.saveFailed(error)
        }
    }
    
    private func loadGameState() async throws {
        guard let data = userDefaults.data(forKey: progressKey) else {
            print("[GameState] No saved game found")
            // Post load failure notification
            NotificationCenter.default.post(name: .gameStateLoadFailed, object: nil)
            throw GameError.loadFailed(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No saved game found"]))
        }
        
        do {
            let decoder = JSONDecoder()
            let gameProgress = try decoder.decode(GameProgress.self, from: data)
            
            // Update game state
            score = gameProgress.score
            level = gameProgress.level
            grid = gameProgress.grid.map { row in
                row.map { colorString in
                    BlockColor(rawValue: colorString)
                }
            }
            tray = gameProgress.tray
            blocksPlaced = gameProgress.blocksPlaced
            linesCleared = gameProgress.linesCleared
            gamesCompleted = gameProgress.gamesCompleted
            perfectLevels = gameProgress.perfectLevels
            totalPlayTime = gameProgress.totalPlayTime
            highScore = gameProgress.highScore
            highestLevel = gameProgress.highestLevel
            
            // Post load success notification
            NotificationCenter.default.post(name: .gameStateLoaded, object: nil)
        } catch {
            print("[GameState] Error loading game state: \(error.localizedDescription)")
            // Post load failure notification
            NotificationCenter.default.post(name: .gameStateLoadFailed, object: nil)
            throw GameError.loadFailed(error)
        }
    }
    
    private func checkForExistingSave() {
        if userDefaults.bool(forKey: hasSavedGameKey) {
            // Post save game warning notification
            NotificationCenter.default.post(name: .showSaveGameWarning, object: nil)
        }
    }
    
    // ... existing code ...
    private func retryPendingScore() async {
        guard let pendingScoreData = userDefaults.data(forKey: "pendingLeaderboardScore"),
              let pendingScore = try? JSONDecoder().decode(PendingScore.self, from: pendingScoreData) else {
            return
        }
        
        print("[Leaderboard] Attempting to retry pending score submission")
        do {
            try await LeaderboardService.shared.updateLeaderboard(
                score: pendingScore.score,
                type: .score
            )
            print("[Leaderboard] Successfully submitted pending score")
            // Clear the pending score after successful submission
            userDefaults.removeObject(forKey: "pendingLeaderboardScore")
        } catch {
            print("[Leaderboard] Failed to submit pending score: \(error.localizedDescription)")
        }
    }

    func calculateRequiredScore() -> Int {
        // Enhanced scoring system with dynamic thresholds
        let baseScore = if level <= 5 {
            level * 1000
        } else if level <= 10 {
            level * 2000
        } else if level <= 50 {
            level * 3000
        } else if level <= 100 {
            level * 5000
        } else {
            level * 10000
        }
        
        // Add bonus for perfect levels
        let perfectBonus = perfectLevels * 500
        
        // Add bonus for consecutive days played
        let streakBonus = consecutiveDays * 200
        
        return baseScore + perfectBonus + streakBonus
    }
}

// MARK: - Extensions and Supporting Types

// Deterministic seeded random generator
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

// MARK: - BlockColor Extension
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

// MARK: - Notification Names
extension Notification.Name {
    static let gameStateSaved = Notification.Name("gameStateSaved")
    static let gameStateSaveFailed = Notification.Name("gameStateSaveFailed")
    static let gameStateLoaded = Notification.Name("gameStateLoaded")
    static let gameStateLoadFailed = Notification.Name("gameStateLoadFailed")
    static let showSaveGameWarning = Notification.Name("showSaveGameWarning")
    static let levelCompleted = Notification.Name("levelCompleted")
    static let gameOver = Notification.Name("gameOver")
}
