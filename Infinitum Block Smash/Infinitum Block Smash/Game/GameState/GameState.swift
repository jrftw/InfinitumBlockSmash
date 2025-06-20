/*
 * GameState.swift
 * 
 * CORE GAME STATE MANAGEMENT
 * 
 * This is the central state management class for the Infinitum Block Smash game.
 * It serves as the single source of truth for all game-related data and logic.
 * 
 * KEY RESPONSIBILITIES:
 * - Game state management (score, level, grid, tray, etc.)
 * - Game logic implementation (block placement, line clearing, scoring)
 * - Progress tracking and persistence
 * - Achievement system integration
 * - Undo/redo functionality
 * - Offline queue management for data sync
 * - Performance monitoring and FPS management
 * - Adaptive difficulty adjustment
 * - Analytics and statistics tracking
 * - Memory management and cleanup
 * 
 * MAJOR DEPENDENCIES:
 * - GameScene.swift: Visual representation and user interaction
 * - GameView.swift: SwiftUI wrapper for game presentation
 * - AchievementsManager.swift: Achievement tracking and notifications
 * - FirebaseManager.swift: Data persistence and cloud sync
 * - LeaderboardService.swift: Score submission and leaderboard data
 * - AdManager.swift: Advertisement integration for undos
 * - SubscriptionManager.swift: Premium features and purchases
 * - AnalyticsManager.swift: Game analytics and metrics
 * - AdaptiveDifficultyManager.swift: Dynamic difficulty adjustment
 * - HintManager.swift: Hint system for player assistance
 * - FPSManager.swift: Performance optimization
 * - MemorySystem.swift: Memory management and cleanup
 * 
 * CORE DATA STRUCTURES:
 * - grid: 2D array representing the game board
 * - tray: Array of available blocks for placement
 * - score: Current game score
 * - level: Current game level
 * - achievementsManager: Achievement tracking instance
 * - undoStack: Stack for undo/redo operations
 * - offlineChangesQueue: Queue for offline data changes
 * 
 * PUBLISHED PROPERTIES:
 * All game state is exposed through @Published properties to enable
 * reactive UI updates. The UI automatically updates when these properties change.
 * 
 * THREADING MODEL:
 * - @MainActor ensures all updates happen on the main thread
 * - Background operations use async/await for data persistence
 * - Offline queue uses dedicated dispatch queue for save operations
 * 
 * PERSISTENCE STRATEGY:
 * - Local: UserDefaults for basic game state
 * - Cloud: Firebase Firestore for cross-device sync
 * - Offline: Queue system for handling network interruptions
 * 
 * PERFORMANCE CONSIDERATIONS:
 * - Memory cleanup every 60 seconds
 * - Debounced save operations to prevent excessive writes
 * - Cached data management for frequently accessed values
 * - FPS monitoring and adaptive performance adjustment
 * 
 * ARCHITECTURE ROLE:
 * This class acts as the "Model" in the MVVM architecture, containing
 * all business logic and state management. It communicates with the
 * View layer through Combine publishers and delegate callbacks.
 */

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
    @Published private(set) var temporaryScore: Int = 0
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
    @Published private(set) var totalTime: TimeInterval = 0
    @Published var isPaused: Bool = false
    @Published var targetFPS: Int = FPSManager.shared.getDisplayFPS(for: FPSManager.shared.targetFPS)
    
    // Ad-related state
    @Published private(set) var levelsCompletedSinceLastAd = 0
    @Published private(set) var adsWatchedThisGame = 0
    @Published private(set) var hasUsedContinueAd = false
    
    // Add HintManager
    let hintManager = HintManager()
    
    // Add frame size property
    var frameSize: CGSize = .zero
    
    var delegate: GameStateDelegate? {
        didSet {
            Logger.shared.debug("GameState.delegate set to \(String(describing: delegate))", category: .debugGameState)
        }
    }
    
    private var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
    private let traySize = 3
    
    private let userDefaults = UserDefaults.standard
    private let scoreKey = "personalHighScore"  // Changed from "highScore" to be more specific
    private let levelKey = "personalHighestLevel"  // Changed from "highestLevel" to be more specific
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
    
    // Add difficulty-related properties
    private var levelScoreThreshold: Int = 1000
    private var randomShapesOnBoard: Int = 0
    private var requiredShapesToFit: Int = 3
    
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
    private let memoryCleanupInterval: TimeInterval = MemoryConfig.getIntervals().memoryCleanup
    private var cachedData: [String: Any] = [:]
    
    // Add leaderboard high score property
    @Published private(set) var leaderboardHighScore: Int = 0
    @Published private(set) var leaderboardHighestLevel: Int = 1
    
    // Add method to fetch leaderboard high score
    func fetchLeaderboardHighScore() async {
        do {
            let result = try await LeaderboardService.shared.getLeaderboard(type: .score, period: "alltime")
            if let userEntry = result.entries.first(where: { $0.username == username }) {
                leaderboardHighScore = userEntry.score
                if let level = userEntry.level {
                    leaderboardHighestLevel = level
                }
                // Update the published properties
                highScore = leaderboardHighScore
                highestLevel = leaderboardHighestLevel
                // Save to UserDefaults
                userDefaults.set(highScore, forKey: scoreKey)
                userDefaults.set(highestLevel, forKey: levelKey)
            }
        } catch {
            print("[Leaderboard] Error fetching leaderboard high score: \(error.localizedDescription)")
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
    
    // Add AdaptiveDifficultyManager
    private let adaptiveDifficultyManager = AdaptiveDifficultyManager()
    
    // Add tracking properties
    private var levelStartTime: Date?
    private var mistakes: Int = 0
    private var totalMoves: Int = 0
    private var quickPlacements: Int = 0
    private var colorMatches: Int = 0
    private var totalColors: Int = 0
    private var successfulShapePlacements: Int = 0
    private var totalShapePlacements: Int = 0
    
    // Add scoring breakdown tracking
    private var scoringBreakdown: [ScoringBreakdown.ScoreEntry] = []
    private var currentLevelBreakdown: [ScoringBreakdown.ScoreEntry] = []
    
    // Add debounce properties
    private var lastGameOverCheck: TimeInterval = 0
    private let gameOverCheckDebounce: TimeInterval = 0.5 // Half second debounce
    
    // Add cooldown tracking for game over ads
    private var lastGameOverAdTime: Date?
    private let gameOverAdCooldown: TimeInterval = 600 // 10 minutes between game over ads (changed from 2 minutes)
    
    // Add debounced update properties
    private var pendingUpdate: Bool = false
    private var updateTimer: Timer?
    private let updateDebounceInterval: TimeInterval = 0.016 // ~60fps max update rate
    
    private var lastUndoTime: TimeInterval = 0
    private let undoDebounceInterval: TimeInterval = 0.1 // Prevent rapid undo operations
    
    // MARK: - Initialization
    init() {
        // Run data migration if needed
        GameDataVersion.migrateIfNeeded()
        
        // Load personal high score and highest level from UserDefaults
        highScore = userDefaults.integer(forKey: scoreKey)
        highestLevel = userDefaults.integer(forKey: levelKey)
        
        // If no values exist yet, initialize them
        if highScore == 0 {
            highScore = 0
            userDefaults.set(highScore, forKey: scoreKey)
        }
        if highestLevel == 0 {
            highestLevel = 1
            userDefaults.set(highestLevel, forKey: levelKey)
        }
        
        // Load other statistics
        loadStatistics()
        
        // Reset session-specific stats
        resetSessionStats()
        
        // Setup initial game state
        setupInitialGame()
        setupSubscriptions()
        
        // Load last play date for consecutive days tracking
        loadLastPlayDate()
        
        // Start play time timer
        startPlayTimeTimer()
        
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
        playTimeTimer?.invalidate()
        playTimeTimer = nil
        Task { [weak self] in
            guard let self = self else { return }
            await cleanupMemory()
            await MainActor.run {
                self.cancellables.removeAll()
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
        DispatchQueue.main.async {
            self.playTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updatePlayTime()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupInitialGame() {
        print("[DEBUG] Setting up initial game - Level will be set to 1")
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray.removeAll(keepingCapacity: true)
        refillTray(skipGameStateCheck: true)
        level = 1
        print("[DEBUG] Initial game setup complete - Level: \(level), Tray count: \(tray.count)")
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
        
        // SAFETY CHECK: Ensure tray is properly filled
        if tray.count != 3 {
            print("[ERROR] Tray not properly filled after setup (\(tray.count)/3), refilling...")
            tray = []
            refillTray(skipGameStateCheck: true)
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
        print("[DEBUG] Resetting game - Level will be set to 1")
        
        // Delete any saved game first
        deleteSavedGame()
        
        #if DEBUG
        print("[Memory] Resetting game. Tray: \(tray.count), Grid blocks: \(grid.flatMap { $0 }.compactMap { $0 }.count)")
        #endif
        
        // Clear cloud state if user is logged in
        if !UserDefaults.standard.bool(forKey: "isGuest") {
            Task {
                do {
                    try await FirebaseManager.shared.clearGameProgress()
                } catch {
                    print("[GameState] Error clearing cloud game progress: \(error.localizedDescription)")
                }
            }
        }
        
        // Save current stats before resetting
        saveStatistics()
        
        // Reset ALL game state to fresh values
        score = 0
        temporaryScore = 0
        level = 1
        print("[DEBUG] Game reset complete - Level: \(level)")
        isGameOver = false
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        tray = []
        canUndo = false
        levelComplete = false
        adUndoCount = 3
        showingAchievementNotification = false
        currentAchievement = nil
        isPerfectLevel = true
        undoCount = 0
        isPaused = false
        
        // Reset session-specific stats
        resetSessionStats()
        
        // Reset ad-related state
        levelsCompletedSinceLastAd = 0
        adsWatchedThisGame = 0
        hasUsedContinueAd = false
        
        // Reset undo state
        undoStack.clear()
        unlimitedUndos = false
        
        // Reset hint state
        hintManager.reset()
        
        // Reset tracking properties
        currentChain = 0
        usedColors.removeAll()
        usedShapes.removeAll()
        totalTime = 0
        gameStartTime = Date()
        
        // Reset scoring breakdown
        scoringBreakdown.removeAll()
        currentLevelBreakdown.removeAll()
        
        // Set the seed for the new game
        setSeed(for: level)
        
        // Refill the tray with new blocks
        refillTray()
        
        // SAFETY CHECK: Ensure tray is properly filled
        if tray.count != 3 {
            print("[ERROR] Tray not properly filled after reset (\(tray.count)/3), refilling...")
            tray = []
            refillTray(skipGameStateCheck: true)
        }
        
        // Validate that grid is properly cleared
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    print("[ERROR] Grid cell (\(row), \(col)) still contains \(grid[row][col]?.rawValue ?? "unknown") after reset!")
                }
            }
        }
        
        // Force immediate visual update to clear any block remnants
        delegate?.gameStateDidUpdate()
        
        // Additional cleanup to ensure no visual artifacts remain
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.delegate?.gameStateDidUpdate()
        }
        
        print("[GameState] Game reset completed successfully - all state cleared")
    }
    
    func setSeed(for level: Int) {
        rng = SeededGenerator(seed: UInt64(level))
    }
    
    func nextBlockRandom() -> Block {
        // Get adjusted difficulty settings
        let adjustedDifficulty = adaptiveDifficultyManager.getAdjustedDifficulty(for: level)
        
        // Get available shapes with adjusted difficulty
        var availableShapes = BlockShape.availableShapes(for: level, adjustedDifficulty: adjustedDifficulty)
        
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
    
    func refillTray(skipGameStateCheck: Bool = false) {
        print("[DEBUG] Refilling tray - current count: \(tray.count), target: \(requiredShapesToFit)")
        
        // Only add new blocks if we have less than requiredShapesToFit
        while tray.count < requiredShapesToFit {
            let newBlock = nextBlockRandom()
            tray.append(newBlock)
            print("[DEBUG] Added block to tray: \(newBlock.shape)-\(newBlock.color)")
        }
        
        print("[DEBUG] Tray refilled - final count: \(tray.count)")
        
        // SAFETY CHECK: Ensure we have exactly the required number of blocks
        if tray.count != requiredShapesToFit {
            print("[ERROR] Tray has incorrect number of blocks after refill (\(tray.count)/\(requiredShapesToFit))")
            // Force correct number by removing excess or adding missing blocks
            while tray.count > requiredShapesToFit {
                tray.removeLast()
            }
            while tray.count < requiredShapesToFit {
                let newBlock = nextBlockRandom()
                tray.append(newBlock)
            }
            print("[DEBUG] Tray corrected - final count: \(tray.count)")
        }
        
        // Check for game over after refilling (skip during initialization)
        if !skipGameStateCheck {
            checkGameState()
        }
        
        // Schedule debounced update instead of immediate update
        scheduleUpdate()
    }
    
    private func checkCanPlaceBlock(_ block: Block) -> Bool {
        #if DEBUG
        print("[Placement] Checking if block \(block.shape)-\(block.color) can be placed anywhere")
        #endif
        
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if canPlaceBlock(block, at: CGPoint(x: col, y: row)) {
                    #if DEBUG
                    print("[Placement] Found valid position for block \(block.shape)-\(block.color)")
                    #endif
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
        let now = CACurrentMediaTime()
        guard now - lastUndoTime >= undoDebounceInterval else { return }
        lastUndoTime = now
        
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
        print("[Undo] Tray count before: \(tray.count), after: \(lastMove.previousTray.count)")
        
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
        
        print("[DEBUG] Tray before placement: \(tray.map { "\($0.shape)-\($0.color)" })")
        print("[DEBUG] Trying to place block: \(block.shape)-\(block.color) at (\(col), \(row))")
        
        guard row >= 0 && row < GameConstants.gridSize && col >= 0 && col < GameConstants.gridSize else {
            print("[Place] Invalid position: (\(row), \(col))")
            return false
        }
        
        // ATOMIC VALIDATION: Check if we can place the entire shape BEFORE making any changes
        for (dx, dy) in block.shape.cells {
            let x = col + dx
            let y = row + dy
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                print("[Place] Shape would go out of bounds at (\(x), \(y))")
                return false
            }
            if grid[y][x] != nil {
                print("[Place] Position (\(x), \(y)) already occupied by \(grid[y][x]?.rawValue ?? "unknown")")
                return false
            }
        }
        
        print("[DEBUG] Placement validation successful - proceeding with atomic placement")
        
        // Save state for undo BEFORE making any changes to ensure tray state is preserved
        saveStateForUndo(block: block, position: (row: row, col: col))
        
        // ATOMIC PLACEMENT: Place the block in grid first
        var currentShapePositions = Set<String>()
        for (dx, dy) in block.shape.cells {
            let x = col + dx
            let y = row + dy
            grid[y][x] = block.color
            currentShapePositions.insert("\(x),\(y)")
        }
        
        print("[DEBUG] Block successfully placed in grid at (\(col), \(row))")
        
        // ATOMIC REMOVAL: Remove the block from the tray AFTER successful grid placement
        if let index = tray.firstIndex(where: { $0.id == block.id }) {
            tray.remove(at: index)
            print("[DEBUG] Block removed from tray. Tray after: \(tray.map { "\($0.shape)-\($0.color)" })")
        } else {
            print("[ERROR] Block not found in tray after successful placement!")
            // This should never happen, but if it does, we need to clean up the grid
            for (dx, dy) in block.shape.cells {
                let x = col + dx
                let y = row + dy
                grid[y][x] = nil
            }
            return false
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
                addScoreWithBreakdown(
                    touchingCount * 10,
                    type: ScoringBreakdown.ScoreType.touchingBlocks,
                    description: "\(touchingCount) touching blocks",
                    count: touchingCount,
                    at: CGPoint(x: CGFloat(x) * GameConstants.blockSize, y: CGFloat(y) * GameConstants.blockSize)
                )
            }
        }
        
        // Multiple touches bonus
        if hasAnyTouches && totalTouchingPoints >= 3 {
            let bonusPoints = totalTouchingPoints * 2
            addScoreWithBreakdown(
                bonusPoints,
                type: ScoringBreakdown.ScoreType.multipleTouches,
                description: "Multiple touches bonus (\(totalTouchingPoints) total touches)",
                count: totalTouchingPoints,
                at: CGPoint(x: frameSize.width/2, y: frameSize.height/2)
            )
            #if DEBUG
            print("[Bonus] Multiple touches! +\(bonusPoints) bonus points!")
            #endif
        }
        
        // Check for matches and patterns
        Logger.shared.log("Checking for matches and line clears after block placement", category: .lineClear, level: .debug)
        checkMatches()
        
        // Refill tray if needed
        if tray.count < requiredShapesToFit {
            refillTray()
        } else {
            // Only check game state if we didn't refill the tray
            checkGameState()
        }
        
        // Schedule debounced update instead of immediate update
        scheduleUpdate()
        
        // VALIDATION: Ensure grid state consistency after placement
        validateGridStateAfterPlacement()
        
        print("[DEBUG] Placement completed successfully")
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
        let row = Int(anchor.y)
        let col = Int(anchor.x)
        
        // Debug logging for placement validation
        print("[DEBUG] Checking placement for block \(block.shape) at (\(col), \(row))")
        
        for (dx, dy) in block.shape.cells {
            let x = col + dx
            let y = row + dy
            if x < 0 || x >= GameConstants.gridSize || y < 0 || y >= GameConstants.gridSize {
                print("[DEBUG] Position (\(x), \(y)) out of bounds")
                return false
            }
            if grid[y][x] != nil {
                print("[DEBUG] Position (\(x), \(y)) already occupied by \(grid[y][x]?.rawValue ?? "unknown")")
                return false
            }
        }
        
        print("[DEBUG] Placement valid for block \(block.shape) at (\(col), \(row))")
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
    
    private func checkXPattern() -> Int {
        // Check for X pattern (10+ blocks in X formation)
        for row in 1..<GameConstants.gridSize-1 {
            for col in 1..<GameConstants.gridSize-1 {
                if let centerColor = grid[row][col] {
                    var xPatternCount = 1 // Count the center block
                    
                    // Check in all four diagonal directions
                    let directions = [(1,1), (1,-1), (-1,1), (-1,-1)]
                    for (dx, dy) in directions {
                        var currentRow = row + dx
                        var currentCol = col + dy
                        while currentRow >= 0 && currentRow < GameConstants.gridSize &&
                              currentCol >= 0 && currentCol < GameConstants.gridSize &&
                              grid[currentRow][currentCol] == centerColor {
                            xPatternCount += 1
                            currentRow += dx
                            currentCol += dy
                        }
                    }
                    
                    if xPatternCount >= 10 {
                        return 250
                    }
                }
            }
        }
        return 0
    }

    private func checkMatches() {
        var clearedPositions: [(Int, Int)] = []
        var linesClearedThisTurn = 0
        var achievementsToUpdate: [String: Int] = [:] // Track achievements to update
        
        Logger.shared.log("Starting line clear check", category: .lineClear, level: .debug)
        
        // Track rows and columns to clear in a single pass
        var rowsToClear = Set<Int>()
        var columnsToClear = Set<Int>()
        var rowCounts = Array(repeating: 0, count: GameConstants.gridSize)
        var columnCounts = Array(repeating: 0, count: GameConstants.gridSize)
        var rowColors = Array(repeating: Set<BlockColor>(), count: GameConstants.gridSize)
        var columnColors = Array(repeating: Set<BlockColor>(), count: GameConstants.gridSize)
        
        // Single pass through the grid to check both rows and columns
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if let color = grid[row][col] {
                    rowCounts[row] += 1
                    columnCounts[col] += 1
                    rowColors[row].insert(color)
                    columnColors[col].insert(color)
                }
            }
        }
        
        // Log the counts for debugging
        for i in 0..<GameConstants.gridSize {
            Logger.shared.log("Row \(i): \(rowCounts[i])/\(GameConstants.gridSize) blocks", category: .lineClear, level: .debug)
            Logger.shared.log("Column \(i): \(columnCounts[i])/\(GameConstants.gridSize) blocks", category: .lineClear, level: .debug)
        }
        
        // Check which rows and columns are full
        for i in 0..<GameConstants.gridSize {
            if rowCounts[i] == GameConstants.gridSize {
                rowsToClear.insert(i)
                clearedPositions.append((i, -1))  // -1 indicates entire row
                linesClearedThisTurn += 1
                Logger.shared.log("Row \(i) is full and will be cleared", category: .lineClear, level: .info)
                addScoreWithBreakdown(
                    100,
                    type: ScoringBreakdown.ScoreType.lineClear,
                    description: "Row \(i) cleared",
                    count: 1,
                    at: CGPoint(x: frameSize.width/2, y: CGFloat(i) * GameConstants.blockSize)
                )
                
                // Check for same color bonus (200 points if all blocks are the same color)
                if rowColors[i].count == 1 {
                    addScoreWithBreakdown(
                        200,
                        type: ScoringBreakdown.ScoreType.sameColorBonus,
                        description: "Same color row bonus",
                        count: 1,
                        at: CGPoint(x: frameSize.width/2, y: CGFloat(i) * GameConstants.blockSize)
                    )
                    Logger.shared.log("Same color row bonus! +200 points", category: .lineClear, level: .info)
                }
            }
            if columnCounts[i] == GameConstants.gridSize {
                columnsToClear.insert(i)
                clearedPositions.append((-1, i))  // -1 indicates entire column
                linesClearedThisTurn += 1
                Logger.shared.log("Column \(i) is full and will be cleared", category: .lineClear, level: .info)
                addScoreWithBreakdown(
                    100,
                    type: ScoringBreakdown.ScoreType.lineClear,
                    description: "Column \(i) cleared",
                    count: 1,
                    at: CGPoint(x: CGFloat(i) * GameConstants.blockSize, y: frameSize.height/2)
                )
                
                // Check for same color bonus (200 points if all blocks are the same color)
                if columnColors[i].count == 1 {
                    addScoreWithBreakdown(
                        200,
                        type: ScoringBreakdown.ScoreType.sameColorBonus,
                        description: "Same color column bonus",
                        count: 1,
                        at: CGPoint(x: CGFloat(i) * GameConstants.blockSize, y: frameSize.height/2)
                    )
                    Logger.shared.log("Same color column bonus! +200 points", category: .lineClear, level: .info)
                }
            }
        }
        
        Logger.shared.log("Found \(rowsToClear.count) rows and \(columnsToClear.count) columns to clear", category: .lineClear, level: .info)
        
        // Debug: Log grid state if lines are being cleared
        if !rowsToClear.isEmpty || !columnsToClear.isEmpty {
            debugGridState()
        }
        
        // Clear all rows and columns at once
        for row in rowsToClear {
            clearRow(row)
            Logger.shared.log("Cleared row \(row)", category: .lineClear, level: .info)
        }
        
        for col in columnsToClear {
            clearColumn(col)
            Logger.shared.log("Cleared column \(col)", category: .lineClear, level: .info)
        }
        
        // Validate that line clearing worked correctly
        if !rowsToClear.isEmpty || !columnsToClear.isEmpty {
            let validationPassed = validateLineClearing()
            if !validationPassed {
                Logger.shared.log("Line clearing validation failed!", category: .lineClear, level: .error)
            }
        }
        
        // Check for X pattern (10+ blocks in X formation)
        let xPatternScore = checkXPattern()
        if xPatternScore > 0 {
            addScoreWithBreakdown(
                xPatternScore,
                type: ScoringBreakdown.ScoreType.xPattern,
                description: "X pattern formed",
                count: 1,
                at: CGPoint(x: frameSize.width/2, y: frameSize.height/2)
            )
            Logger.shared.log("X pattern found! +\(xPatternScore) points", category: .lineClear, level: .info)
        }
        
        // Check for perfect level (grid completely empty)
        if isGridEmpty() && isPerfectLevel {
            let perfectBonus = 1000
            addScoreWithBreakdown(
                perfectBonus,
                type: ScoringBreakdown.ScoreType.perfectLevel,
                description: "Perfect level bonus",
                count: 1,
                at: CGPoint(x: frameSize.width/2, y: frameSize.height/2)
            )
            print("[Perfect] Perfect level! +\(perfectBonus) bonus points!")
            achievementsManager.updateAchievement(id: "perfect_level", value: 1)
            perfectLevels += 1
            achievementsManager.updateAchievement(id: "perfect_levels_3", value: perfectLevels)
            achievementsManager.updateAchievement(id: "perfect_levels_5", value: perfectLevels)
            
            // Mark level as complete
            levelComplete = true
            print("[DEBUG] Level complete - grid is empty and perfect")
        }
        
        // Update achievements
        if linesClearedThisTurn > 0 {
            achievementsToUpdate["clear_10"] = linesClearedThisTurn
            achievementsToUpdate["clear_50"] = linesClearedThisTurn
            achievementsToUpdate["clear_100"] = linesClearedThisTurn
        }
        
        // Batch update achievements
        if !achievementsToUpdate.isEmpty {
            achievementsManager.batchUpdateAchievements(achievementsToUpdate)
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
        guard row >= 0 && row < GameConstants.gridSize else {
            Logger.shared.log("Invalid row index for clearing: \(row)", category: .lineClear, level: .error)
            return
        }
        
        var clearedCount = 0
        for col in 0..<GameConstants.gridSize {
            if grid[row][col] != nil {
                grid[row][col] = nil
                clearedCount += 1
            }
        }
        
        Logger.shared.log("Cleared row \(row): removed \(clearedCount) blocks", category: .lineClear, level: .debug)
    }
    
    private func clearColumn(_ col: Int) {
        guard col >= 0 && col < GameConstants.gridSize else {
            Logger.shared.log("Invalid column index for clearing: \(col)", category: .lineClear, level: .error)
            return
        }
        
        var clearedCount = 0
        for row in 0..<GameConstants.gridSize {
            if grid[row][col] != nil {
                grid[row][col] = nil
                clearedCount += 1
            }
        }
        
        Logger.shared.log("Cleared column \(col): removed \(clearedCount) blocks", category: .lineClear, level: .debug)
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

        // Update personal high score
        if temporaryScore > highScore {
            highScore = temporaryScore
            userDefaults.set(highScore, forKey: scoreKey)
            achievementsManager.updateAchievement(id: "high_score", value: temporaryScore)
            print("[HighScore] New personal high score: \(temporaryScore)")
            // (Leaderboard submission removed here)
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
    
    // Add a new method for tracking specific score types
    func addScoreWithBreakdown(_ points: Int, type: ScoringBreakdown.ScoreType, description: String, count: Int = 1, at position: CGPoint? = nil) {
        addScoreEntry(type, points: points, description: description, count: count)
        addScore(points, at: position)
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
                    
                    // Refresh leaderboard high score - REMOVED: Only fetch at end of game or main menu
                    // await fetchLeaderboardHighScore()
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
        
        // Check if we need to show an ad (every 15th level)
        if levelsCompletedSinceLastAd >= 15 {
            if adsWatchedThisGame < 3 { // Maximum 3 ads per game
                // Check if user is on premium plan - skip ad if they are
                if !SubscriptionManager.shared.hasActiveSubscription && !UserDefaults.standard.bool(forKey: "hasRemovedAds") {
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
                    // Premium user - skip ad and continue
                    print("[GameState] Premium user - skipping level completion ad")
                    levelsCompletedSinceLastAd = 0
                    continueLevelUp()
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
        print("[DEBUG] Level up - clearing grid for level \(level + 1)")
        print("[DEBUG] Grid state before clear: \(grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        
        level += 1
        print("[Level] Level up! Now at level \(level)")
        setSeed(for: level)
        
        // 1. Clear the data model - THIS IS THE SINGLE SOURCE OF TRUTH
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        print("[DEBUG] Grid state after clear: \(grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        print("[DEBUG] Grid state validation - all cells should be nil")
        
        // Validate that grid is properly cleared
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    print("[ERROR] Grid cell (\(row), \(col)) still contains \(grid[row][col]?.rawValue ?? "unknown") after clear!")
                }
            }
        }
        
        tray = []
        
        // Update personal highest level
        if level > highestLevel {
            highestLevel = level
            userDefaults.set(highestLevel, forKey: levelKey)
        }
        
        // 2. Force immediate visual update to clear any block remnants
        delegate?.gameStateDidUpdate()
        
        // 3. Additional cleanup to ensure no visual artifacts remain
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.delegate?.gameStateDidUpdate()
        }
        
        // Final cleanup after a longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.delegate?.gameStateDidUpdate()
        }
        
        refillTray()
        levelComplete = false
    }
    
    func advanceToNextLevel() {
        print("[DEBUG] Level completion - clearing grid immediately")
        print("[DEBUG] Grid state before clear: \(grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        
        // 1. Clear the data model immediately - THIS IS THE SINGLE SOURCE OF TRUTH
        self.grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        print("[DEBUG] Grid state after clear: \(grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        print("[DEBUG] Grid state validation - all cells should be nil")
        
        // Validate that grid is properly cleared
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    print("[ERROR] Grid cell (\(row), \(col)) still contains \(grid[row][col]?.rawValue ?? "unknown") after clear!")
                }
            }
        }
        
        // 2. Force immediate visual update to clear any block remnants
        self.delegate?.gameStateDidUpdate()
        
        // Add a small delay before advancing to ensure the level complete overlay is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            print("[DEBUG] Advancing to next level - setting up new level")
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
            
            // 3. Force multiple grid updates to ensure no visual artifacts remain
            self.delegate?.gameStateDidUpdate()
            
            // Additional cleanup to ensure no block remnants
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.delegate?.gameStateDidUpdate()
            }
            
            // Final cleanup after a longer delay to catch any remaining artifacts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.delegate?.gameStateDidUpdate()
            }
        }
    }
    
    func checkGameState() {
        // Debounce game over checks
        let currentTime = Date().timeIntervalSinceReferenceDate
        if currentTime - lastGameOverCheck < gameOverCheckDebounce {
            #if DEBUG
            print("[GameState] Skipping game over check - too soon since last check")
            #endif
            return
        }
        lastGameOverCheck = currentTime
        
        #if DEBUG
        print("[GameState] Checking game state...")
        #endif
        
        let canPlaceAny = tray.contains { canPlaceBlockAnywhere($0) }
        #if DEBUG
        print("[GameState] Can place any current tray blocks: \(canPlaceAny)")
        print("[GameState] Current tray blocks: \(tray.map { "\($0.shape)-\($0.color)" })")
        #endif
        
        if !canPlaceAny {
            #if DEBUG
            print("[GameOver] No available moves for current tray blocks. Game over triggered.")
            print("[GameOver] Current grid state:")
            for (rowIndex, row) in grid.enumerated() {
                print("[GameOver] Row \(rowIndex): \(row.map { $0?.rawValue ?? "nil" })")
            }
            print("[GameOver] Dispatching game over handler...")
            #endif
            DispatchQueue.main.async {
                self.handleGameOver()
            }
        }
    }

    private func handleGameOver() {
        #if DEBUG
        print("[Memory] Game over. Tray: \(tray.count), Grid blocks: \(grid.flatMap { $0 }.compactMap { $0 }.count)")
        #endif
        print("[GameState] Handling game over")
        print("[GameState] Final score: \(score)")
        print("[GameState] Final level: \(level)")
        print("[GameState] Blocks placed: \(blocksPlaced)")
        print("[GameState] Lines cleared: \(linesCleared)")
        
        isGameOver = true

        // Transfer temporary score to main score
        score = temporaryScore

        // Submit final score to leaderboard once per game
        if !UserDefaults.standard.bool(forKey: "isGuest") && score > 0 {
            Task {
                do {
                    print("[Leaderboard] Submitting final score: \(score), level: \(level), time: \(totalPlayTime)")
                    try await LeaderboardService.shared.updateLeaderboard(
                        score: score,
                        level: level,
                        time: totalPlayTime,
                        type: .score
                    )
                    print("[Leaderboard] ✅ Final score submitted successfully")
                    await fetchLeaderboardHighScore()
                } catch {
                    print("[Leaderboard] ❌ Error submitting final score: \(error.localizedDescription)")
                }
            }
        } else {
            print("[Leaderboard] 👤 Guest user or zero score - skipping final score submission")
        }

        // Update achievements
        achievementsManager.updateAchievement(id: "score_1000", value: score)
        achievementsManager.updateAchievement(id: "score_5000", value: score)
        achievementsManager.updateAchievement(id: "score_10000", value: score)

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

        // Only increment gamesCompleted if the game was lost (not manually ended)
        if !isPaused {
            gamesCompleted += 1
            saveStatistics() // Save statistics when game is over
            print("[GameState] Game completed count incremented to: \(gamesCompleted)")
        }

        // Update play time
        playTimeTimer?.invalidate()
        Task { @MainActor in
            updatePlayTime() // Final update of play time
            try? await saveProgress()
        }

        // Post game over notification
        print("[GameState] Posting game over notification")
        NotificationCenter.default.post(name: .gameOver, object: nil)

        // Show interstitial ad when game is over, but don't wait for it
        Task {
            // Check if user is on premium plan - skip ad if they are
            guard !SubscriptionManager.shared.hasActiveSubscription && !UserDefaults.standard.bool(forKey: "hasRemovedAds") else {
                print("[GameState] Premium user - skipping game over ad")
                return
            }
            
            // Check cooldown before showing game over ad
            if let lastAdTime = lastGameOverAdTime {
                let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
                if timeSinceLastAd < gameOverAdCooldown {
                    print("[GameState] Skipping game over ad - cooldown active (\(Int(gameOverAdCooldown - timeSinceLastAd))s remaining)")
                    return
                }
            }
            
            if await AdManager.shared.isAdAvailable() {
                print("[GameState] Showing interstitial ad")
                lastGameOverAdTime = Date()
                await AdManager.shared.showInterstitial()
            }
        }
        
        // Clean up game state to free memory
        cleanupGameState()
        
        // Record session end for inactivity ad tracking
        AdManager.shared.recordSessionEnd()
    }
    
    
    // Award points for grouping 10 or more contiguous squares
    // REMOVED: Group formation bonuses have been removed
    /*
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
    */
    
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
        
        // Mark that user has played before to prevent first-time flow ads
        userDefaults.set(true, forKey: "hasPlayedBefore")
        
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
        // Use the consolidated game over handler with proper cooldown logic
        handleGameOver()
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
        print("[GameState] Ending game from settings")
        handleGameOver() // Use the consolidated game over handler
        // Note: No additional ad needed here since handleGameOver already shows an ad
        
        // Ensure leaderboard is submitted once if game is ended manually
        if !UserDefaults.standard.bool(forKey: "isGuest") && score > 0 {
            Task {
                do {
                    print("[Leaderboard] Submitting final score (manual end): \(score), level: \(level), time: \(totalPlayTime)")
                    try await LeaderboardService.shared.updateLeaderboard(
                        score: score,
                        level: level,
                        time: totalPlayTime,
                        type: .score
                    )
                    print("[Leaderboard] ✅ Final score submitted successfully (manual end)")
                    // Refresh leaderboard high score - REMOVED: Only fetch at end of game or main menu
                    // await fetchLeaderboardHighScore()
                } catch {
                    print("[Leaderboard] ❌ Error submitting final score (manual end): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func hasSavedGame() -> Bool {
        let hasFlag = userDefaults.bool(forKey: hasSavedGameKey)
        let hasData = userDefaults.data(forKey: progressKey) != nil
        
        // If we have both flag and data, validate the data
        if hasFlag && hasData {
            do {
                let decoder = JSONDecoder()
                let progress = try decoder.decode(GameProgress.self, from: userDefaults.data(forKey: progressKey)!)
                
                // Check if this is actually a valid game to resume (not a new game)
                return !progress.isNewGame
            } catch {
                print("[GameState] Error decoding saved game: \(error.localizedDescription)")
                // If we can't decode the data, clean up the invalid save
                deleteSavedGame()
                return false
            }
        }
        
        return false
    }
    
    /// Checks if there's a saved game that can be resumed
    func canResumeGame() -> Bool {
        return hasSavedGame()
    }
    
    func loadSavedGame() async throws {
        do {
            // First try to load from local storage
            if let data = userDefaults.data(forKey: progressKey) {
                let decoder = JSONDecoder()
                let progress = try decoder.decode(GameProgress.self, from: data)
                
                // Update state on main thread
                await MainActor.run {
                    self.restoreGameState(from: progress)
                }
                
                // Notify success
                NotificationCenter.default.post(name: .gameStateLoaded, object: nil)
                return
            }
            
            // If no local save, try to load from Firebase
            let progress = try await FirebaseManager.shared.loadGameProgress()
            
            // Update state on main thread
            await MainActor.run {
                self.restoreGameState(from: progress)
            }
            
            // Notify success
            NotificationCenter.default.post(name: .gameStateLoaded, object: nil)
        } catch {
            print("[GameState] Error loading game progress: \(error.localizedDescription)")
            // Notify failure
            NotificationCenter.default.post(name: .gameStateLoadFailed, object: error)
            throw GameError.loadFailed(error)
        }
    }
    
    // NEW: Centralized method to restore game state from GameProgress
    private func restoreGameState(from progress: GameProgress) {
        print("[GameState] Restoring game state from saved progress")
        print("[GameState] Progress details: score=\(progress.score), level=\(progress.level), blocksPlaced=\(progress.blocksPlaced)")
        print("[GameState] Grid has blocks: \(progress.grid.flatMap { $0 }.contains { $0 != "nil" })")
        print("[GameState] Tray count: \(progress.tray.count)")
        
        // Check if this is a new game (no saved progress) or resuming an existing game
        let isNewGame = progress.isNewGame
        print("[GameState] isNewGame: \(isNewGame)")
        
        if isNewGame {
            print("[DEBUG] New game detected - starting fresh")
            setupInitialGame()
            return
        }
        
        print("[DEBUG] Resuming saved game - level: \(progress.level)")
        
        // Restore core game state
        score = progress.score
        temporaryScore = progress.temporaryScore
        level = progress.level
        blocksPlaced = progress.blocksPlaced
        linesCleared = progress.linesCleared
        gamesCompleted = progress.gamesCompleted
        perfectLevels = progress.perfectLevels
        totalPlayTime = progress.totalPlayTime
        highScore = progress.highScore
        highestLevel = progress.highestLevel
        currentChain = progress.currentChain
        usedColors = progress.usedColorsSet
        usedShapes = progress.usedShapesSet
        isPerfectLevel = progress.isPerfectLevel
        undoCount = progress.undoCount
        adUndoCount = progress.adUndoCount
        hasUsedContinueAd = progress.hasUsedContinueAd
        levelsCompletedSinceLastAd = progress.levelsCompletedSinceLastAd
        adsWatchedThisGame = progress.adsWatchedThisGame
        isPaused = progress.isPaused
        targetFPS = progress.targetFPS
        gameStartTime = progress.gameStartTime
        lastPlayDate = progress.lastPlayDate
        consecutiveDays = progress.consecutiveDays
        totalTime = progress.totalTime
        
        print("[GameState] Restored core state: score=\(score), level=\(level), blocksPlaced=\(blocksPlaced)")
        
        // Convert serialized grid back to BlockColor array
        grid = progress.grid.map { row in
            row.map { colorString in
                colorString == "nil" ? nil : BlockColor(rawValue: colorString)
            }
        }
        
        print("[GameState] Restored grid with \(grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        
        // Restore tray - ensure it's valid
        if !progress.tray.isEmpty && progress.tray.count == 3 {
            tray = progress.tray
            print("[DEBUG] Using saved tray with \(tray.count) blocks")
        } else {
            print("[DEBUG] Invalid saved tray, refilling...")
            tray = []
            refillTray(skipGameStateCheck: true)
        }
        
        // SAFETY CHECK: Ensure tray always has the correct number of blocks
        if tray.count != 3 {
            print("[DEBUG] Tray has incorrect number of blocks (\(tray.count)), refilling...")
            tray = []
            refillTray(skipGameStateCheck: true)
        }
        
        // Restore undo stack
        undoStack.loadMoves(progress.undoStack)
        canUndo = !undoStack.isEmpty
        
        // Restore game state flags
        isGameOver = false
        levelComplete = false
        
        // Restore game settings to UserDefaults
        UserDefaults.standard.set(progress.previewEnabled, forKey: "previewEnabled")
        UserDefaults.standard.set(progress.previewHeightOffset, forKey: "previewHeightOffset")
        UserDefaults.standard.set(progress.isTimedMode, forKey: "isTimedMode")
        UserDefaults.standard.set(progress.soundEnabled, forKey: "soundEnabled")
        UserDefaults.standard.set(progress.hapticsEnabled, forKey: "hapticsEnabled")
        UserDefaults.standard.set(progress.musicVolume, forKey: "musicVolume")
        UserDefaults.standard.set(progress.sfxVolume, forKey: "sfxVolume")
        UserDefaults.standard.set(progress.difficulty, forKey: "difficulty")
        UserDefaults.standard.set(progress.theme, forKey: "theme")
        UserDefaults.standard.set(progress.autoSave, forKey: "autoSave")
        UserDefaults.standard.set(progress.placementPrecision, forKey: "placementPrecision")
        UserDefaults.standard.set(progress.blockDragOffset, forKey: "blockDragOffset")
        
        // Update the FPS in the game view
        delegate?.updateFPS(targetFPS)
        
        // Notify delegate of state update
        delegate?.gameStateDidUpdate()
        
        print("[GameState] Game state restoration completed successfully")
        print("[GameState] Final state: score=\(score), level=\(level), blocksPlaced=\(blocksPlaced), gridBlocks=\(grid.flatMap { $0 }.compactMap { $0 }.count)")
        
        // Validate the restored state
        if !validateLoadedGameState() {
            print("[GameState] WARNING: Restored game state validation failed, but continuing...")
        }
    }
    
    private func loadStatistics() {
        print("[GameState] Loading statistics from UserDefaults")
        
        // Load statistics from UserDefaults, defaulting to 0 if not found
        blocksPlaced = userDefaults.integer(forKey: blocksPlacedKey)
        linesCleared = userDefaults.integer(forKey: linesClearedKey)
        gamesCompleted = userDefaults.integer(forKey: gamesCompletedKey)
        perfectLevels = userDefaults.integer(forKey: perfectLevelsKey)
        totalPlayTime = userDefaults.double(forKey: totalPlayTimeKey)
        highScore = userDefaults.integer(forKey: scoreKey)
        highestLevel = userDefaults.integer(forKey: levelKey)
        
        print("[GameState] Loaded statistics - Blocks: \(blocksPlaced), Lines: \(linesCleared), Games: \(gamesCompleted), Perfect: \(perfectLevels), High Score: \(highScore), Highest Level: \(highestLevel)")

        // Load from Firebase if user is logged in and auto-sync is enabled
        if !UserDefaults.standard.bool(forKey: "isGuest") && autoSyncEnabled {
            Task {
                do {
                    let progress = try await FirebaseManager.shared.loadGameProgress()
                    
                    // Take the higher values between local and cloud data
                    blocksPlaced = max(blocksPlaced, progress.blocksPlaced)
                    linesCleared = max(linesCleared, progress.linesCleared)
                    gamesCompleted = max(gamesCompleted, progress.gamesCompleted)
                    perfectLevels = max(perfectLevels, progress.perfectLevels)
                    totalPlayTime = max(totalPlayTime, progress.totalPlayTime)
                    highScore = max(highScore, progress.highScore)
                    highestLevel = max(highestLevel, progress.highestLevel)
                    
                    // Save the updated values back to UserDefaults
                    saveStatisticsToUserDefaults()
                    
                    print("[GameState] Successfully loaded and merged statistics from Firebase")
                } catch {
                    print("[GameState] Error loading statistics from Firebase: \(error.localizedDescription)")
                }
            }
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
        
        // Only save game progress if the game is not over and not paused
        if !isGameOver && !isPaused {
            do {
                try await saveProgress()
                print("[GameState] Successfully saved game progress when app resigned active")
            } catch {
                print("[GameState] Error saving game progress when app resigned active: \(error.localizedDescription)")
            }
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
            // Convert grid to a format Firebase can handle
            let serializedGrid = grid.map { row in
                row.map { color in
                    color?.rawValue ?? "nil"
                }
            }
            
            // Get current UserDefaults values for settings
            let previewEnabled = UserDefaults.standard.bool(forKey: "previewEnabled")
            let previewHeightOffset = UserDefaults.standard.double(forKey: "previewHeightOffset")
            let isTimedMode = UserDefaults.standard.bool(forKey: "isTimedMode")
            let soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
            let hapticsEnabled = UserDefaults.standard.bool(forKey: "hapticsEnabled")
            let musicVolume = UserDefaults.standard.double(forKey: "musicVolume")
            let sfxVolume = UserDefaults.standard.double(forKey: "sfxVolume")
            let difficulty = UserDefaults.standard.string(forKey: "difficulty") ?? "normal"
            let theme = UserDefaults.standard.string(forKey: "theme") ?? "auto"
            let autoSave = UserDefaults.standard.bool(forKey: "autoSave")
            let placementPrecision = UserDefaults.standard.double(forKey: "placementPrecision")
            let blockDragOffset = UserDefaults.standard.double(forKey: "blockDragOffset")
            
            // Get undo stack (limit to last 5 moves for storage efficiency)
            let undoStackMoves = Array(undoStack.allMoves.suffix(5))
            
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
                tray: tray,
                lastSaveTime: Date(),
                // NEW: Additional game state
                temporaryScore: temporaryScore,
                currentChain: currentChain,
                usedColors: usedColors,
                usedShapes: usedShapes,
                isPerfectLevel: isPerfectLevel,
                undoCount: undoCount,
                adUndoCount: adUndoCount,
                hasUsedContinueAd: hasUsedContinueAd,
                levelsCompletedSinceLastAd: levelsCompletedSinceLastAd,
                adsWatchedThisGame: adsWatchedThisGame,
                isPaused: isPaused,
                targetFPS: targetFPS,
                gameStartTime: gameStartTime,
                lastPlayDate: lastPlayDate,
                consecutiveDays: consecutiveDays,
                totalTime: totalTime,
                previewEnabled: previewEnabled,
                previewHeightOffset: previewHeightOffset,
                isTimedMode: isTimedMode,
                soundEnabled: soundEnabled,
                hapticsEnabled: hapticsEnabled,
                musicVolume: musicVolume,
                sfxVolume: sfxVolume,
                difficulty: difficulty,
                theme: theme,
                autoSave: autoSave,
                placementPrecision: placementPrecision,
                blockDragOffset: blockDragOffset,
                undoStack: undoStackMoves
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
                let encoder = JSONEncoder()
                let data = try encoder.encode(progress)
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
    
    /// Force save the current game state (overwrites any existing save)
    func forceSaveGame() async throws {
        print("[GameState] Force saving game...")
        try await saveProgress()
    }
    
    /// Save game with confirmation if there's an existing save
    func saveGameWithConfirmation() async throws {
        if hasSavedGame() {
            // Show warning and let user decide
            NotificationCenter.default.post(name: .showSaveGameWarning, object: nil)
        } else {
            // No existing save, proceed normally
            try await saveProgress()
        }
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
        print("[DEBUG] Resetting game state - clearing grid")
        print("[DEBUG] Grid state before reset: \(grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        
        // 1. Clear the data model - THIS IS THE SINGLE SOURCE OF TRUTH
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        print("[DEBUG] Grid state after reset: \(grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        
        // Validate that grid is properly cleared
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    print("[ERROR] Grid cell (\(row), \(col)) still contains \(grid[row][col]?.rawValue ?? "unknown") after reset!")
                }
            }
        }
        
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
        
        // 2. Force immediate visual update to clear any block remnants
        delegate?.gameStateDidUpdate()
        
        // 3. Additional cleanup to ensure no visual artifacts remain
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.delegate?.gameStateDidUpdate()
        }
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
        hintManager.showHint(gameState: self, delegate: delegate)
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
        hasUsedContinueAd = false
    }
    
    private func updateLevelRequirements() {
        levelScoreThreshold = calculateRequiredScore()
        
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

    func calculatePlayerSkill() -> Int {
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
        Logger.shared.log("Handling critical memory situation", category: .systemMemory, level: .warning)
        
        // Clear any pending updates
        updateTimer?.invalidate()
        updateTimer = nil
        pendingUpdate = false
        
        // Force an immediate update to clear any pending changes
        forceUpdate()
        
        // Clear undo stack to free memory
        undoStack.clear()
        canUndo = false
        
        // Clear any cached data
        resetTrackingProperties()
        
        Logger.shared.log("Critical memory handling completed", category: .systemMemory, level: .info)
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
        
        Logger.shared.log("Checking lines for block at position: (\(col), \(row))", category: .lineClear, level: .debug)
        
        // Check if position is within bounds
        guard row >= 0 && row < GameConstants.gridSize && col >= 0 && col < GameConstants.gridSize else {
            Logger.shared.log("Position out of bounds: (\(col), \(row))", category: .lineClear, level: .warning)
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
                Logger.shared.log("Placed block cell at: (\(x), \(y))", category: .lineClear, level: .debug)
            } else {
                Logger.shared.log("Block cell would be out of bounds at: (\(x), \(y))", category: .lineClear, level: .warning)
            }
        }
        
        // Check for full rows and columns
        var rowsToClear = Set<Int>()
        var columnsToClear = Set<Int>()
        
        // Check rows
        for y in 0..<GameConstants.gridSize {
            var isRowFull = true
            var rowBlockCount = 0
            for x in 0..<GameConstants.gridSize {
                if tempGrid[y][x] != nil {
                    rowBlockCount += 1
                } else {
                    isRowFull = false
                }
            }
            if isRowFull {
                rowsToClear.insert(y)
                Logger.shared.log("Row \(y) would be cleared (has \(rowBlockCount) blocks)", category: .lineClear, level: .debug)
            } else {
                Logger.shared.log("Row \(y) is not full (has \(rowBlockCount)/\(GameConstants.gridSize) blocks)", category: .lineClear, level: .debug)
            }
        }
        
        // Check columns
        for x in 0..<GameConstants.gridSize {
            var isColumnFull = true
            var columnBlockCount = 0
            for y in 0..<GameConstants.gridSize {
                if tempGrid[y][x] != nil {
                    columnBlockCount += 1
                } else {
                    isColumnFull = false
                }
            }
            if isColumnFull {
                columnsToClear.insert(x)
                Logger.shared.log("Column \(x) would be cleared (has \(columnBlockCount) blocks)", category: .lineClear, level: .debug)
            } else {
                Logger.shared.log("Column \(x) is not full (has \(columnBlockCount)/\(GameConstants.gridSize) blocks)", category: .lineClear, level: .debug)
            }
        }
        
        Logger.shared.log("Found \(rowsToClear.count) rows and \(columnsToClear.count) columns to clear", category: .lineClear, level: .debug)
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
        
        // Update adaptive difficulty stats
        if let startTime = levelStartTime {
            let timeSpent = Date().timeIntervalSince(startTime)
            adaptiveDifficultyManager.updatePlayerStats(
                score: score,
                level: level,
                timeSpent: timeSpent,
                isPerfect: isPerfectLevel,
                chainCount: currentChain,
                mistakes: mistakes,
                totalMoves: totalMoves,
                quickPlacements: quickPlacements,
                colorMatches: colorMatches,
                totalColors: totalColors,
                successfulShapePlacements: successfulShapePlacements,
                totalShapePlacements: totalShapePlacements
            )
        }
        
        // Get adjusted difficulty for next level
        let adjustedDifficulty = adaptiveDifficultyManager.getAdjustedDifficulty(for: level + 1)
        
        // Calculate the next level's required score using the cumulative system
        let nextLevel = level + 1
        let nextLevelRequiredScore = calculateRequiredScoreForLevel(nextLevel)
        
        // Apply difficulty adjustments while ensuring we don't go below the base threshold
        let safeNextLevelScore = min(nextLevelRequiredScore, Int.max / 2) // Prevent overflow
        let safeMultiplier = min(max(adjustedDifficulty.scoreRequirementMultiplier, 0.1), 10.0)
        let adjustedScore = Double(safeNextLevelScore) * safeMultiplier
        
        // Ensure the final value is valid before converting to Int
        if adjustedScore.isFinite && !adjustedScore.isNaN {
            levelScoreThreshold = max(nextLevelRequiredScore, Int(adjustedScore))
        } else {
            // Fallback to base score if calculation results in invalid value
            levelScoreThreshold = nextLevelRequiredScore
        }
        
        // Apply other difficulty adjustments
        let adjustedRandomShapes = Double(randomShapesOnBoard) * adjustedDifficulty.randomShapeSpawnRate
        randomShapesOnBoard = max(0, Int(adjustedRandomShapes))
        
        let adjustedRequiredShapes = Double(requiredShapesToFit) * adjustedDifficulty.shapeComplexityMultiplier
        requiredShapesToFit = max(1, Int(adjustedRequiredShapes))
        
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
        
        // Reset tracking properties for next level
        resetTrackingProperties()
    }
    
    private func resetTrackingProperties() {
        levelStartTime = Date()
        mistakes = 0
        totalMoves = 0
        quickPlacements = 0
        colorMatches = 0
        totalColors = 0
        successfulShapePlacements = 0
        totalShapePlacements = 0
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
        return calculateRequiredScoreForLevel(level)
    }
    
    func calculateRequiredScoreForLevel(_ targetLevel: Int) -> Int {
        // Calculate the cumulative required score for the specified level
        // This represents the TOTAL score needed to reach this level
        
        // Calculate cumulative score by summing up all previous level requirements
        var cumulativeScore = 0
        
        // Calculate points needed for each level up to the target level
        for currentLevel in 1...targetLevel {
            let levelPoints: Int
            
            switch currentLevel {
            case 1:
                levelPoints = 1000
            case 2:
                levelPoints = 1100
            case 3:
                levelPoints = 1200
            case 4:
                levelPoints = 1300
            case 5:
                levelPoints = 1400
            case 6...10:
                // Levels 6-10: Increase by 150 per level
                levelPoints = 1400 + ((currentLevel - 5) * 150)
            case 11...25:
                // Levels 11-25: Increase by 200 per level
                levelPoints = 2150 + ((currentLevel - 10) * 200)
            case 26...50:
                // Levels 26-50: Increase by 250 per level
                levelPoints = 5150 + ((currentLevel - 25) * 250)
            case 51...100:
                // Levels 51-100: Increase by 300 per level
                levelPoints = 11350 + ((currentLevel - 50) * 300)
            case 101...200:
                // Levels 101-200: Increase by 350 per level
                levelPoints = 26350 + ((currentLevel - 100) * 350)
            case 201...300:
                // Levels 201-300: Increase by 400 per level
                levelPoints = 61350 + ((currentLevel - 200) * 400)
            case 301...500:
                // Levels 301-500: Increase by 450 per level
                levelPoints = 101350 + ((currentLevel - 300) * 450)
            case 501...:
                // Level 501+: Dynamic scaling
                let baseIncrease = 500
                let levelGroup = (currentLevel - 500) / 100
                let additionalIncrease = levelGroup * 50
                let pointsPerLevel = baseIncrease + additionalIncrease
                levelPoints = 191350 + ((currentLevel - 500) * pointsPerLevel)
            default:
                levelPoints = currentLevel * 1000
            }
            
            cumulativeScore += levelPoints
        }
        
        // Add bonus for perfect levels (this is additional to the cumulative score)
        let perfectBonus = perfectLevels * 500
        
        // Add bonus for consecutive days played (this is additional to the cumulative score)
        let streakBonus = consecutiveDays * 200
        
        let totalRequiredScore = cumulativeScore + perfectBonus + streakBonus
        
        return totalRequiredScore
    }
    
    // Debug function to verify cumulative scoring system
    func debugCumulativeScores() {
        print("=== CUMULATIVE SCORING SYSTEM DEBUG ===")
        print("Expected cumulative scores:")
        print("Level 1: 1,000 total points")
        print("Level 2: 2,100 total points (1,000 + 1,100)")
        print("Level 3: 3,300 total points (2,100 + 1,200)")
        print("Level 4: 4,600 total points (3,300 + 1,300)")
        print("Level 5: 6,000 total points (4,600 + 1,400)")
        print("Level 6: 7,550 total points (6,000 + 1,550)")
        print("Level 7: 9,250 total points (7,550 + 1,700)")
        print("Level 8: 11,100 total points (9,250 + 1,850)")
        print("Level 9: 13,100 total points (11,100 + 2,000)")
        print("Level 10: 15,250 total points (13,100 + 2,150)")
        print("")
        print("Actual calculated scores:")
        for i in 1...10 {
            let score = calculateRequiredScoreForLevel(i)
            print("Level \(i): \(score) total points")
        }
        print("=====================================")
    }
    
    // MARK: - Tray Management
    func removeBlockFromTray(_ block: Block) {
        if let index = tray.firstIndex(where: { $0.id == block.id }) {
            tray.remove(at: index)
            delegate?.gameStateDidUpdate()
        }
    }
    
    func addBlockToTray(_ block: Block) {
        print("[DEBUG] Adding block to tray: \(block.shape)-\(block.color)")
        print("[DEBUG] Tray before adding: \(tray.map { "\($0.shape)-\($0.color)" })")
        
        // Only add if we have less than 3 shapes
        if tray.count < 3 {
            tray.append(block)
            print("[DEBUG] Block added to tray successfully. Tray after: \(tray.map { "\($0.shape)-\($0.color)" })")
            delegate?.gameStateDidUpdate()
        } else {
            print("[ERROR] Cannot add block to tray - tray is full (\(tray.count)/3)")
        }
    }

    private func handleAchievement(id: String, value: Double) {
        // Update local achievement
        achievementsManager.updateAchievement(id: id, value: Int(value))
        
        // Update Game Center achievement
        Task {
            // Get current progress
            let currentProgress = await GameCenterManager.shared.getAchievementProgress(id: id)
            
            // Only update if the new value is higher
            if value > currentProgress {
                // Report to Game Center
                GameCenterManager.shared.reportAchievement(id: id, percentComplete: value)
                
                // Show notification if achievement is complete
                if value >= 100 {
                    GameCenterManager.shared.showAchievementUnlockNotification(id: id)
                }
            }
        }
    }
    
    private func handleScoreAchievement(score: Int) {
        // Score achievements
        if score >= 1000 {
            handleAchievement(id: "score_1000", value: min(100, Double(score) / 1000 * 100))
        }
        if score >= 5000 {
            handleAchievement(id: "score_5000", value: min(100, Double(score) / 5000 * 100))
        }
        if score >= 10000 {
            handleAchievement(id: "score_10000", value: min(100, Double(score) / 10000 * 100))
        }
        if score >= 50000 {
            handleAchievement(id: "score_50000", value: min(100, Double(score) / 50000 * 100))
        }
    }
    
    private func handleLevelAchievement(level: Int) {
        // Level achievements
        if level >= 5 {
            handleAchievement(id: "level_5", value: min(100, Double(level) / 5 * 100))
        }
        if level >= 10 {
            handleAchievement(id: "level_10", value: min(100, Double(level) / 10 * 100))
        }
        if level >= 20 {
            handleAchievement(id: "level_20", value: min(100, Double(level) / 20 * 100))
        }
        if level >= 50 {
            handleAchievement(id: "level_50", value: min(100, Double(level) / 50 * 100))
        }
    }
    
    private func handleLineClearAchievement(linesCleared: Int) {
        // Line clear achievements
        if linesCleared >= 1 {
            handleAchievement(id: "first_clear", value: 100)
        }
        if linesCleared >= 10 {
            handleAchievement(id: "clear_10", value: min(100, Double(linesCleared) / 10 * 100))
        }
        if linesCleared >= 50 {
            handleAchievement(id: "clear_50", value: min(100, Double(linesCleared) / 50 * 100))
        }
        if linesCleared >= 100 {
            handleAchievement(id: "clear_100", value: min(100, Double(linesCleared) / 100 * 100))
        }
    }
    
    private func handleComboAchievement(combo: Int) {
        // Combo achievements
        if combo >= 3 {
            handleAchievement(id: "combo_3", value: min(100, Double(combo) / 3 * 100))
        }
        if combo >= 5 {
            handleAchievement(id: "combo_5", value: min(100, Double(combo) / 5 * 100))
        }
        if combo >= 10 {
            handleAchievement(id: "combo_10", value: min(100, Double(combo) / 10 * 100))
        }
    }
    
    private func handleBlockPlacementAchievement(blocksPlaced: Int) {
        // Block placement achievements
        if blocksPlaced >= 100 {
            handleAchievement(id: "place_100", value: min(100, Double(blocksPlaced) / 100 * 100))
        }
        if blocksPlaced >= 500 {
            handleAchievement(id: "place_500", value: min(100, Double(blocksPlaced) / 500 * 100))
        }
        if blocksPlaced >= 1000 {
            handleAchievement(id: "place_1000", value: min(100, Double(blocksPlaced) / 1000 * 100))
        }
    }
    
    private func handleGroupAchievement(groupsCreated: Int) {
        // Group achievements - REMOVED: Group formation bonuses have been removed
        /*
        if groupsCreated >= 10 {
            handleAchievement(id: "group_10", value: min(100, Double(groupsCreated) / 10 * 100))
        }
        if groupsCreated >= 20 {
            handleAchievement(id: "group_20", value: min(100, Double(groupsCreated) / 20 * 100))
        }
        if groupsCreated >= 30 {
            handleAchievement(id: "group_30", value: min(100, Double(groupsCreated) / 30 * 100))
        }
        */
    }
    
    private func handlePerfectLevelAchievement(perfectLevels: Int) {
        // Perfect level achievements
        if perfectLevels >= 1 {
            handleAchievement(id: "perfect_level", value: 100)
        }
        if perfectLevels >= 3 {
            handleAchievement(id: "perfect_levels_3", value: min(100, Double(perfectLevels) / 3 * 100))
        }
        if perfectLevels >= 5 {
            handleAchievement(id: "perfect_levels_5", value: min(100, Double(perfectLevels) / 5 * 100))
        }
    }

    // Add this method to reset session-specific stats
    private func resetSessionStats() {
        blocksPlaced = 0
        linesCleared = 0
        gamesCompleted = 0
        perfectLevels = 0
        totalPlayTime = 0
        gameStartTime = Date()
    }

    func canPlaceAnyTrayBlock() -> Bool {
        print("[Placement] Checking if any tray blocks can be placed")
        for block in tray {
            if canPlaceBlockAnywhere(block) {
                print("[Placement] Found valid placement for tray block: \(block.shape)-\(block.color)")
                return true
            }
        }
        print("[Placement] No valid placements found for any tray blocks")
        return false
    }

    func canPlaceBlockAnywhere(_ block: Block) -> Bool {
        #if DEBUG
        print("[Placement] Checking if block \(block.shape)-\(block.color) can be placed anywhere")
        #endif
        var validPositions = 0
        
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if canPlaceBlock(block, at: CGPoint(x: col, y: row)) {
                    validPositions += 1
                }
            }
        }
        
        #if DEBUG
        print("[Placement] Found \(validPositions) valid positions for block \(block.shape)-\(block.color)")
        #endif
        return validPositions > 0
    }

    // MARK: - Debug Methods
    
    func debugGridState() {
        Logger.shared.log("=== GRID STATE DEBUG ===", category: .lineClear, level: .info)
        
        // Print grid state
        for row in (0..<GameConstants.gridSize).reversed() {
            var rowString = "Row \(row): "
            for col in 0..<GameConstants.gridSize {
                if let color = grid[row][col] {
                    rowString += "[\(color.rawValue)]"
                } else {
                    rowString += "[ ]"
                }
            }
            Logger.shared.log(rowString, category: .lineClear, level: .info)
        }
        
        // Count blocks in each row and column
        var rowCounts = Array(repeating: 0, count: GameConstants.gridSize)
        var columnCounts = Array(repeating: 0, count: GameConstants.gridSize)
        
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    rowCounts[row] += 1
                    columnCounts[col] += 1
                }
            }
        }
        
        Logger.shared.log("Row counts: \(rowCounts)", category: .lineClear, level: .info)
        Logger.shared.log("Column counts: \(columnCounts)", category: .lineClear, level: .info)
        
        // Check for full rows and columns
        var fullRows: [Int] = []
        var fullColumns: [Int] = []
        
        for i in 0..<GameConstants.gridSize {
            if rowCounts[i] == GameConstants.gridSize {
                fullRows.append(i)
            }
            if columnCounts[i] == GameConstants.gridSize {
                fullColumns.append(i)
            }
        }
        
        if !fullRows.isEmpty {
            Logger.shared.log("Full rows detected: \(fullRows)", category: .lineClear, level: .warning)
        }
        if !fullColumns.isEmpty {
            Logger.shared.log("Full columns detected: \(fullColumns)", category: .lineClear, level: .warning)
        }
        
        Logger.shared.log("=== END GRID STATE DEBUG ===", category: .lineClear, level: .info)
    }

    func validateLineClearing() -> Bool {
        Logger.shared.log("Validating line clearing logic...", category: .lineClear, level: .debug)
        
        var rowCounts = Array(repeating: 0, count: GameConstants.gridSize)
        var columnCounts = Array(repeating: 0, count: GameConstants.gridSize)
        
        // Count blocks in each row and column
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if grid[row][col] != nil {
                    rowCounts[row] += 1
                    columnCounts[col] += 1
                }
            }
        }
        
        // Check for any full rows or columns that shouldn't exist
        var issuesFound = false
        
        for i in 0..<GameConstants.gridSize {
            if rowCounts[i] == GameConstants.gridSize {
                Logger.shared.log("ERROR: Row \(i) is full but should have been cleared!", category: .lineClear, level: .error)
                issuesFound = true
            }
            if columnCounts[i] == GameConstants.gridSize {
                Logger.shared.log("ERROR: Column \(i) is full but should have been cleared!", category: .lineClear, level: .error)
                issuesFound = true
            }
        }
        
        if !issuesFound {
            Logger.shared.log("Line clearing validation passed - no full rows or columns found", category: .lineClear, level: .debug)
        }
        
        return !issuesFound
    }
    
    // MARK: - Debounced Updates
    
    private func scheduleUpdate() {
        guard !pendingUpdate else { return }
        
        pendingUpdate = true
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performUpdate()
            }
        }
    }
    
    private func performUpdate() {
        pendingUpdate = false
        updateTimer?.invalidate()
        updateTimer = nil
        delegate?.gameStateDidUpdate()
    }
    
    private func forceUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
        pendingUpdate = false
        delegate?.gameStateDidUpdate()
    }

    // MARK: - Game Cleanup
    
    func cleanupGameState() {
        Logger.shared.log("Cleaning up game state", category: .systemMemory, level: .info)
        
        // Clear any pending updates
        updateTimer?.invalidate()
        updateTimer = nil
        pendingUpdate = false
        
        // Clear undo stack
        undoStack.clear()
        canUndo = false
        
        // Clear tracking properties
        resetTrackingProperties()
        
        // Clear temporary data
        usedColors.removeAll()
        usedShapes.removeAll()
        
        // Reset game state flags
        isGameOver = false
        isPaused = false
        levelComplete = false
        
        Logger.shared.log("Game state cleanup completed", category: .systemMemory, level: .info)
    }
    
    // MARK: - Grid State Validation
    
    private func validateGridStateAfterPlacement() {
        let gridBlockCount = grid.flatMap { $0 }.compactMap { $0 }.count
        print("[DEBUG] Grid state validation - Total blocks in grid: \(gridBlockCount)")
        
        // Additional validation could be added here
        // For example, checking for orphaned blocks, invalid positions, etc.
        
        #if DEBUG
        // In debug builds, we could add more thorough validation
        // assert(gridBlockCount >= 0, "Grid block count should never be negative")
        #endif
    }
    
    // MARK: - Initialization Safety Check
    
    /// Ensures the game state is properly initialized for a new game
    func ensureProperInitialization() {
        print("[DEBUG] Ensuring proper game initialization...")
        
        // Check if level is correct
        if level != 1 {
            print("[DEBUG] Level is \(level), resetting to 1")
            level = 1
        }
        
        // Check if tray is properly filled
        if tray.count != 3 {
            print("[DEBUG] Tray has \(tray.count) blocks, refilling to 3")
            tray = []
            refillTray(skipGameStateCheck: true)
        }
        
        // Check if grid is empty
        let gridBlockCount = grid.flatMap { $0 }.compactMap { $0 }.count
        if gridBlockCount > 0 {
            print("[DEBUG] Grid has \(gridBlockCount) blocks, clearing")
            grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        }
        
        // Check if score is reset
        if score != 0 || temporaryScore != 0 {
            print("[DEBUG] Score not reset, clearing")
            score = 0
            temporaryScore = 0
        }
        
        // Check if game state flags are correct
        if isGameOver || levelComplete {
            print("[DEBUG] Game state flags incorrect, resetting")
            isGameOver = false
            levelComplete = false
        }
        
        print("[DEBUG] Game initialization check complete - Level: \(level), Tray: \(tray.count), Score: \(score)")
        
        // Notify delegate of any changes
        delegate?.gameStateDidUpdate()
    }
    
    // MARK: - Scoring Breakdown Methods
    
    private func addScoreEntry(_ type: ScoringBreakdown.ScoreType, points: Int, description: String, count: Int = 1) {
        let entry = ScoringBreakdown.ScoreEntry(type: type, points: points, description: description, count: count)
        currentLevelBreakdown.append(entry)
        scoringBreakdown.append(entry)
    }
    
    func getCurrentLevelBreakdown() -> ScoringBreakdown {
        return ScoringBreakdown(
            totalScore: temporaryScore,
            breakdown: currentLevelBreakdown,
            level: level,
            timestamp: Date()
        )
    }
    
    func getGameBreakdown() -> ScoringBreakdown {
        return ScoringBreakdown(
            totalScore: score,
            breakdown: scoringBreakdown,
            level: level,
            timestamp: Date()
        )
    }
    
    private func resetLevelBreakdown() {
        currentLevelBreakdown.removeAll()
    }
    
    // MARK: - New Game Management
    
    /// Starts a completely fresh new game, clearing all previous state
    func startNewGame() {
        print("[GameState] Starting new game - clearing all previous state")
        
        // Delete any existing saved game
        deleteSavedGame()
        
        // Clear cloud state if user is logged in
        if !UserDefaults.standard.bool(forKey: "isGuest") {
            Task {
                do {
                    try await FirebaseManager.shared.clearGameProgress()
                } catch {
                    print("[GameState] Error clearing cloud game progress: \(error.localizedDescription)")
                }
            }
        }
        
        // Reset to completely fresh state
        resetGame()
        
        // Ensure we start at exactly level 1 with no previous data
        level = 1
        score = 0
        temporaryScore = 0
        isGameOver = false
        isPaused = false
        levelComplete = false
        
        // Clear grid completely
        grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
        
        // Generate fresh tray
        tray = []
        refillTray(skipGameStateCheck: true)
        
        // Reset all game state flags
        canUndo = false
        adUndoCount = 3
        showingAchievementNotification = false
        currentAchievement = nil
        isPerfectLevel = true
        undoCount = 0
        currentChain = 0
        usedColors.removeAll()
        usedShapes.removeAll()
        totalTime = 0
        gameStartTime = Date()
        
        // Clear undo stack
        undoStack.clear()
        
        // Reset ad-related state
        levelsCompletedSinceLastAd = 0
        adsWatchedThisGame = 0
        hasUsedContinueAd = false
        
        // Reset hint state
        hintManager.reset()
        
        // Clear scoring breakdown
        scoringBreakdown.removeAll()
        currentLevelBreakdown.removeAll()
        
        // Set fresh seed for new game
        setSeed(for: level)
        
        // Validate fresh state
        validateNewGameState()
        
        // Notify delegate
        delegate?.gameStateDidUpdate()
        
        print("[GameState] New game started successfully - all state reset to fresh")
    }
    
    /// Validates that the new game state is properly initialized
    private func validateNewGameState() {
        // Validate level
        guard level == 1 else {
            print("[ERROR] New game level is not 1: \(level)")
            level = 1
            return
        }
        
        // Validate score
        guard score == 0 && temporaryScore == 0 else {
            print("[ERROR] New game score is not 0: score=\(score), temp=\(temporaryScore)")
            score = 0
            temporaryScore = 0
            return
        }
        
        // Validate grid is empty
        let gridBlockCount = grid.flatMap { $0 }.compactMap { $0 }.count
        guard gridBlockCount == 0 else {
            print("[ERROR] New game grid is not empty: \(gridBlockCount) blocks")
            grid = Array(repeating: Array(repeating: nil, count: GameConstants.gridSize), count: GameConstants.gridSize)
            return
        }
        
        // Validate tray has 3 blocks
        guard tray.count == 3 else {
            print("[ERROR] New game tray does not have 3 blocks: \(tray.count)")
            tray = []
            refillTray(skipGameStateCheck: true)
            return
        }
        
        // Validate game state flags
        guard !isGameOver && !isPaused && !levelComplete else {
            print("[ERROR] New game state flags are incorrect")
            isGameOver = false
            isPaused = false
            levelComplete = false
            return
        }
        
        print("[GameState] New game state validation passed")
    }
    
    // MARK: - Save/Load Validation and Safety
    
    /// Validates that the current game state is consistent and ready for saving
    private func validateGameStateForSave() -> Bool {
        print("[GameState] Validating game state for save...")
        
        // Check grid consistency
        let gridBlockCount = grid.flatMap { $0 }.compactMap { $0 }.count
        if gridBlockCount < 0 {
            print("[ERROR] Invalid grid block count: \(gridBlockCount)")
            return false
        }
        
        // Check tray consistency
        if tray.count != 3 {
            print("[ERROR] Invalid tray count: \(tray.count)")
            return false
        }
        
        // Check score consistency
        if score < 0 || temporaryScore < 0 {
            print("[ERROR] Invalid score values: score=\(score), temp=\(temporaryScore)")
            return false
        }
        
        // Check level consistency
        if level < 1 {
            print("[ERROR] Invalid level: \(level)")
            return false
        }
        
        // Check game state flags
        if isGameOver && !isPaused {
            print("[WARNING] Game is over but not paused - this might be intentional")
        }
        
        print("[GameState] Game state validation passed")
        return true
    }
    
    /// Validates that loaded game state is consistent
    private func validateLoadedGameState() -> Bool {
        print("[GameState] Validating loaded game state...")
        
        // Check grid consistency
        let gridBlockCount = grid.flatMap { $0 }.compactMap { $0 }.count
        if gridBlockCount < 0 {
            print("[ERROR] Invalid loaded grid block count: \(gridBlockCount)")
            return false
        }
        
        // Check tray consistency
        if tray.count != 3 {
            print("[ERROR] Invalid loaded tray count: \(tray.count)")
            return false
        }
        
        // Check score consistency
        if score < 0 || temporaryScore < 0 {
            print("[ERROR] Invalid loaded score values: score=\(score), temp=\(temporaryScore)")
            return false
        }
        
        // Check level consistency
        if level < 1 {
            print("[ERROR] Invalid loaded level: \(level)")
            return false
        }
        
        print("[GameState] Loaded game state validation passed")
        return true
    }
    
    /// Performs a comprehensive save with validation
    func saveProgressWithValidation() async throws {
        guard validateGameStateForSave() else {
            throw GameError.saveFailed(NSError(domain: "GameState", code: -1, userInfo: [NSLocalizedDescriptionKey: "Game state validation failed"]))
        }
        
        try await saveProgress()
    }
    
    /// Performs a comprehensive load with validation
    func loadSavedGameWithValidation() async throws {
        try await loadSavedGame()
        
        guard validateLoadedGameState() else {
            // If validation fails, reset to a safe state
            print("[GameState] Loaded state validation failed, resetting to safe state")
            startNewGame()
            throw GameError.loadFailed(NSError(domain: "GameState", code: -1, userInfo: [NSLocalizedDescriptionKey: "Loaded game state validation failed"]))
        }
    }
    
    /// Checks if the current game state can be safely saved
    func canSaveGame() -> Bool {
        let gridBlockCount = grid.flatMap { $0 }.compactMap { $0 }.count
        
        print("[GameState] canSaveGame check:")
        print("  - isGameOver: \(isGameOver)")
        print("  - score: \(score)")
        print("  - blocksPlaced: \(blocksPlaced)")
        print("  - gridBlockCount: \(gridBlockCount)")
        
        // Don't save if game is over and no progress was made
        if isGameOver && score == 0 && blocksPlaced == 0 {
            print("[GameState] Skipping save - game over with no progress")
            return false
        }
        
        // Don't save if game hasn't started
        if score == 0 && blocksPlaced == 0 && gridBlockCount == 0 {
            print("[GameState] Skipping save - game hasn't started (no blocks placed)")
            return false
        }
        
        print("[GameState] Game state is suitable for saving")
        return true
    }
    
    /// Gets a summary of the current game state for debugging
    func getGameStateSummary() -> String {
        let gridBlockCount = grid.flatMap { $0 }.compactMap { $0 }.count
        let trayCount = tray.count
        let hasValidMoves = tray.contains { canPlaceBlockAnywhere($0) }
        
        return """
        Game State Summary:
        - Level: \(level)
        - Score: \(score) (temp: \(temporaryScore))
        - Blocks Placed: \(blocksPlaced)
        - Lines Cleared: \(linesCleared)
        - Grid Blocks: \(gridBlockCount)
        - Tray Count: \(trayCount)
        - Can Place Any: \(hasValidMoves)
        - Is Game Over: \(isGameOver)
        - Is Paused: \(isPaused)
        - Level Complete: \(levelComplete)
        - Can Undo: \(canUndo)
        - Undo Count: \(undoCount)
        - Ad Undo Count: \(adUndoCount)
        - Has Used Continue Ad: \(hasUsedContinueAd)
        """
    }
}
