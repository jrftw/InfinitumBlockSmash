/*
 * GameScene.swift
 * 
 * SPRITEKIT GAME SCENE - VISUAL LAYER
 * 
 * This is the SpriteKit scene that handles all visual rendering, user interactions,
 * and animations for the Infinitum Block Smash game. It serves as the bridge between
 * the game logic (GameState) and the visual presentation.
 * 
 * KEY RESPONSIBILITIES:
 * - Visual rendering of game grid and blocks
 * - Touch handling and drag-and-drop interactions
 * - Animation management (particles, transitions, effects)
 * - Performance optimization and memory management
 * - Theme and visual styling
 * - Audio feedback and haptic responses
 * - FPS management and performance monitoring
 * - Node pooling and texture caching
 * 
 * MAJOR DEPENDENCIES:
 * - GameState.swift: Source of truth for game data and logic
 * - TrayNode.swift: Visual representation of the block tray
 * - Block.swift: Block data model and properties
 * - NodePool.swift: Object pooling for performance optimization
 * - ThemeManager.swift: Visual theming and styling
 * - AudioManager.swift: Sound effects and audio feedback
 * - FPSManager.swift: Performance monitoring and FPS control
 * - MemorySystem.swift: Memory management and cleanup
 * - GameConstants.swift: Game configuration constants
 * 
 * CORE COMPONENTS:
 * - gridNode: Container for all grid-based visual elements
 * - trayNode: Visual representation of the block tray
 * - blockNodes: Array of all visual block representations
 * - particleEmitter: Visual effects and animations
 * - scoreLabel/levelLabel: UI elements for game information
 * 
 * PERFORMANCE FEATURES:
 * - Object pooling via NodePool.shared
 * - Texture caching and optimization
 * - Memory cleanup every 30 seconds
 * - Touch throttling for smooth interactions
 * - Background animation management
 * - Particle emitter limiting
 * 
 * INTERACTION MODEL:
 * - Drag-and-drop block placement
 * - Touch throttling for responsive UI
 * - Debounced placement to prevent rapid-fire actions
 * - Visual feedback for valid/invalid placements
 * - Haptic feedback for successful actions
 * 
 * MEMORY MANAGEMENT:
 * - Automatic cleanup of unused nodes
 * - Texture cache size limiting
 * - Particle emitter lifecycle management
 * - Background animation pausing during heavy operations
 * - Memory warning handling and response
 * 
 * THEME INTEGRATION:
 * - Dynamic theme switching
 * - Color scheme adaptation
 * - Visual style updates based on user preferences
 * - Background animation theming
 * 
 * ARCHITECTURE ROLE:
 * This class acts as the "View" layer in the MVVM architecture, specifically
 * handling the SpriteKit rendering and user interaction. It observes GameState
 * changes and updates the visual representation accordingly.
 * 
 * THREADING CONSIDERATIONS:
 * - All visual updates must occur on the main thread
 * - Background operations use async/await for memory management
 * - Touch handling is optimized for responsiveness
 * 
 * INTEGRATION POINTS:
 * - GameView.swift: SwiftUI wrapper that hosts this scene
 * - GameState.swift: Data source and logic controller
 * - Various manager classes for specialized functionality
 */

import SpriteKit
import GameplayKit
import AudioToolbox
import SwiftUI
class GameScene: SKScene, SKPhysicsContactDelegate {
    var gameState: GameState!
    var gridNode: SKNode!
    private var trayNode: TrayNode!
    private var draggingBlock: Block?
    private var dragNode: SKNode?
    private var previewNode: SKNode?
    private var lastPlacementTime: CFTimeInterval = 0
    private let placementDebounceInterval: CFTimeInterval = 0.1 // Reduced from previous value
    // Touch throttling properties
    private var lastTouchMoveUpdate: TimeInterval = 0
    private let touchUpdateThrottle: TimeInterval = 0.008 // ~120fps for maximum responsiveness
    private var isHeavyOperationActive: Bool = false
    private var lastGridPosition: CGPoint = CGPoint.zero // Track last grid position for optimization
    // Visual effects
    private var particleEmitter: SKEmitterNode?
    private var glowNode: SKNode?
    private var activeParticleEmitters: [SKEmitterNode] = [] // Track active particle emitters
    private let maxParticleEmitters = 2 // Reduced from 3 to prevent memory buildup
    // MARK: - Properties
    private var blockNodes: [SKNode] = []
    private var scoreLabel: SKLabelNode?
    private var levelLabel: SKLabelNode?
    private var memoryWarningLabel: SKLabelNode?
    private var lastMemoryCheck: TimeInterval = 0
    private let memoryCheckInterval: TimeInterval = MemoryConfig.getIntervals().memoryCheck
    // Add this property to track hint highlight
    private var hintHighlight: SKNode?
    // Add memory management properties
    private var lastMemoryCleanup: TimeInterval = 0
    private let memoryCleanupInterval: TimeInterval = MemoryConfig.getIntervals().memoryCleanup * 2 // Double the interval to reduce overhead
    private var cachedNodes: [String: SKNode] = [:]
    // Add theme observation property
    private var themeObserver: NSObjectProtocol?
    // MARK: - Object Pooling
    // Removed local pooling properties - now using NodePool.shared
    // MARK: - Texture Management
    private var activeTextures: Set<SKTexture> = []
    private var gradientTextureCache: [String: SKTexture] = [:] // Cache gradient textures by color
    private let maxGradientCacheSize = 5 // Reduced from 10 to prevent memory buildup
    
    func getCachedGradientTexture(for color: BlockColor) -> SKTexture? {
        let key = color.rawValue
        return gradientTextureCache[key]
    }
    
    func cacheGradientTexture(_ texture: SKTexture, for color: BlockColor) {
        let key = color.rawValue
        
        // Limit cache size with LRU eviction
        if gradientTextureCache.count >= maxGradientCacheSize {
            // Remove oldest entry (first key in dictionary)
            if let oldestKey = gradientTextureCache.keys.first {
                gradientTextureCache.removeValue(forKey: oldestKey)
            }
        }
        
        gradientTextureCache[key] = texture
    }
    
    func createGradientImage(size: CGSize, colors: [CGColor], locations: [CGFloat]) -> UIImage? {
        // Use a smaller scale factor for better memory usage
        let scale: CGFloat = 1.0
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: colors as CFArray,
                                        locations: locations) else { return nil }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: size.width, y: size.height),
                                   options: [])
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        // Optimize the image by reducing its size if needed
        if let image = image, image.size.width > 256 || image.size.height > 256 {
            let newSize = CGSize(width: min(image.size.width, 256), height: min(image.size.height, 256))
            UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let optimizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return optimizedImage
        }
        return image
    }
    // MARK: - Texture Management
    private var textureCache: [String: SKTexture] = [:]
    private let maxTextureCacheSize = 50
    // MARK: - Node Management
    private var activeNodes: Set<SKNode> = []
    private let maxActiveNodes = 1000
    // MARK: - Node Management
    var placedBlockNodes: [String: SKNode] = [:] // Track placed block nodes by position
    private var lastCleanupTime: TimeInterval = 0
    private let cleanupInterval: TimeInterval = 5.0 // Cleanup every 5 seconds
    // MARK: - Initialization
    init(size: CGSize, gameState: GameState) {
        self.gameState = gameState
        super.init(size: size)
        Logger.shared.debug("GameScene init(size:) called", category: .debugGameScene)
        
        // Track for memory leaks
        #if DEBUG
        MemoryLeakDetector.shared.trackGameScene(self)
        MemoryLeakDetector.shared.trackGameState(gameState)
        #endif
        
        setupScene()
    }
    required init?(coder aDecoder: NSCoder) {
        // Create a new GameState instance for coder initialization
        self.gameState = GameState()
        super.init(coder: aDecoder)
        Logger.shared.debug("GameScene init(coder:) called", category: .debugGameScene)
        setupScene()
    }
    override func didMove(to view: SKView) {
        Logger.shared.debug("didMove(to:) called", category: .debugGameScene)
        // Optimize textures
        optimizeTextures()
        if gridNode == nil {
            Logger.shared.debug("Creating new gridNode", category: .debugGameScene)
            gridNode = SKNode()
            addChild(gridNode)
        }
        if trayNode == nil {
            Logger.shared.debug("Creating new trayNode", category: .debugGameScene)
            let blockSize = GameConstants.blockSize
            let trayHeight = blockSize * 4.5
            let trayWidth = frame.width * 0.92
            trayNode = TrayNode(trayHeight: trayHeight, trayWidth: trayWidth)
            addChild(trayNode)
        }
        // Configure view for better performance with thermal awareness
        let fpsManager = FPSManager.shared
        let thermalAwareFPS = fpsManager.getThermalAwareFPS()
        view.preferredFramesPerSecond = thermalAwareFPS
        view.ignoresSiblingOrder = true
        view.allowsTransparency = true
        
        Logger.shared.debug("[Thermal] Set FPS to \(thermalAwareFPS) (base: \(fpsManager.getDisplayFPS(for: fpsManager.targetFPS)))", category: .debugGameScene)
        
        // Set the frame size in GameState
        gameState.frameSize = size
        // Setup scene components
        setupGrid()
        setupTray()
        setupUI()
        setupParticles()
        // Set delegate if not already set
        if gameState.delegate !== self {
            Logger.shared.debug("Setting GameState delegate", category: .debugGameScene)
            gameState.delegate = self
        }
        // Add notification observers
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMemoryWarningNotification),
                                               name: .memoryWarning,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMemoryCriticalNotification),
                                               name: .memoryCritical,
                                               object: nil)
        // Start periodic memory cleanup
        Task {
            await setupMemoryManagement()
        }
        Logger.shared.debug("Scene setup complete. trayNode in parent: \(trayNode?.parent != nil)", category: .debugGameScene)
        super.didMove(to: view)
        setBackgroundAnimationsActive(true)
        // Set up notification observer for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: NSNotification.Name("ThemeDidChange"),
            object: nil
        )
        // Initial theme setup
        updateTheme()
        // Add observer for game over notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGameOverNotification),
            name: Notification.Name.gameOver,
            object: nil
        )
        
        // Start thermal state monitoring
        startThermalStateMonitoring()
    }
    deinit {
        Logger.shared.debug("GameScene deinit called", category: .debugGameScene)
        
        // Stop memory leak tracking
        #if DEBUG
        MemoryLeakDetector.shared.stopTracking(self, type: "GameScene")
        #endif
        
        // Cleanup
        gridNode?.children.forEach { cleanupNode($0) }
        trayNode?.children.forEach { cleanupNode($0) }
        particleEmitter?.removeFromParent()
        glowNode?.removeFromParent()
        // Cleanup all particle emitters
        activeParticleEmitters.forEach { cleanupNode($0) }
        activeParticleEmitters.removeAll()
        // Local pooling functions removed - now using NodePool.shared for all pooling operations
        // Clear any cached images
        autoreleasepool {
            gridNode = nil
            trayNode = nil
            particleEmitter = nil
            glowNode = nil
        }
        // Clear node pools
        NodePool.shared.clearAllPools()
        NotificationCenter.default.removeObserver(self)
    }
    private func setupScene() {
        // Set up physics world
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        // Configure scene
        backgroundColor = SKColor(hex: "#1a1a2e")
        scaleMode = .aspectFit
        // Add subtle background animation
        let backgroundNode = SKSpriteNode(color: .clear, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.name = "backgroundNode"  // Add name for reference
        addChild(backgroundNode)
        let backgroundAnimation = SKAction.sequence([
            SKAction.colorize(with: SKColor(hex: "#16213e"), colorBlendFactor: 1.0, duration: 2.0),
            SKAction.colorize(with: SKColor(hex: "#1a1a2e"), colorBlendFactor: 1.0, duration: 2.0)
        ])
        backgroundNode.run(SKAction.repeatForever(backgroundAnimation))
        // Setup memory warning label
        memoryWarningLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        if let label = memoryWarningLabel {
            label.fontSize = 14
            label.fontColor = .red
            label.position = CGPoint(x: size.width - 100, y: size.height - 20)
            label.isHidden = true
            addChild(label)
        }
    }
    // Add method to manage background animations
    private func setBackgroundAnimationsActive(_ active: Bool) {
        // Check thermal state before enabling animations
        let fpsManager = FPSManager.shared
        let shouldPauseForThermal = fpsManager.thermalState == .serious || fpsManager.thermalState == .critical
        let shouldPauseForBattery = fpsManager.batteryLevel < 0.2 || fpsManager.isLowPowerMode
        
        let shouldPause = shouldPauseForThermal || shouldPauseForBattery
        
        // Pause/resume background color animation
        if let backgroundNode = childNode(withName: "backgroundNode") {
            if active && !shouldPause {
                backgroundNode.isPaused = false
            } else {
                backgroundNode.isPaused = true
                if shouldPauseForThermal {
                    Logger.shared.debug("[Thermal] Background animations paused due to thermal state: \(fpsManager.thermalState)", category: .debugGameScene)
                }
                if shouldPauseForBattery {
                    Logger.shared.debug("[Battery] Background animations paused due to battery conditions", category: .debugGameScene)
                }
            }
        }
        
        // Pause/resume particle effects
        enumerateChildNodes(withName: "//") { node, _ in
            if let emitter = node as? SKEmitterNode {
                emitter.isPaused = shouldPause
            }
        }
    }
    private func setupGrid() {
        let blockSize = GameConstants.blockSize
        let gridSize = GameConstants.gridSize
        // Calculate total grid size
        let totalWidth = CGFloat(gridSize) * blockSize
        let totalHeight = CGFloat(gridSize) * blockSize
        // Get screen width for size-specific adjustments
        let screenWidth = UIScreen.main.bounds.width
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        // Calculate available space with size-specific adjustments
        let availableWidth: CGFloat
        let availableHeight: CGFloat
        if isIPad {
            // iPad-specific adjustments
            availableWidth = frame.width * 0.8 // Use 80% of screen width
            availableHeight = frame.height * 0.5 // Use 50% of screen height
        } else if screenWidth <= 375 { // iPhone SE, iPhone 8, etc. (5.4" and smaller)
            availableWidth = frame.width * 0.85 // Use 85% of screen width
            availableHeight = frame.height * 0.6 // Use 60% of screen height
        } else if screenWidth >= 428 { // iPhone 12 Pro Max, iPhone 14 Pro Max, etc. (6.9" and larger)
            availableWidth = frame.width * 0.95 // Use 95% of screen width
            availableHeight = frame.height * 0.7 // Use 70% of screen height
        } else {
            availableWidth = frame.width * 0.9 // Use 90% of screen width
            availableHeight = frame.height * 0.65 // Use 65% of screen height
        }
        // Calculate scale to fit the grid within available space
        let scaleX = availableWidth / totalWidth
        let scaleY = availableHeight / totalHeight
        let scale = min(scaleX, scaleY)
        // Apply scale to grid node
        gridNode.setScale(scale)
        // Center the grid in the frame with size-specific vertical offset
        let verticalOffset: CGFloat
        if isIPad {
            verticalOffset = frame.height * 0.08 // Reduced from 0.15 to 0.08 for iPad
        } else if screenWidth <= 375 {
            verticalOffset = frame.height * 0.05 // 5% offset for smaller screens
        } else if screenWidth >= 428 {
            verticalOffset = frame.height * -0.02 // -2% offset for larger screens
        } else {
            verticalOffset = 0 // No offset for medium screens
        }
        gridNode.position = CGPoint(x: frame.midX, y: frame.midY + verticalOffset)
        gridNode.zPosition = 0
        print("[DEBUG] GridNode position: \(gridNode.position), totalWidth: \(totalWidth), totalHeight: \(totalHeight), frame: \(frame)")
        gridNode.removeAllChildren()
        // Create grid background with a slight padding
        let padding: CGFloat = 2
        let gridBackground = SKShapeNode(rectOf: CGSize(width: totalWidth + padding, height: totalHeight + padding))
        let theme = ThemeManager.shared.getCurrentTheme()
        gridBackground.fillColor = SKColor.from(theme.colors.background)
        gridBackground.alpha = 0.3
        gridBackground.position = CGPoint(x: 0, y: 0)
        gridBackground.zPosition = -2
        gridBackground.name = "gridBackground"
        gridNode.addChild(gridBackground)
        // Optional: Add a visible debug border for the grid
#if DEBUG
        // Only show debug border if there are no blocks placed
        let hasBlocks = gameState.grid.contains { row in
            row.contains { $0 != nil }
        }
        if !hasBlocks {
            let debugBorder = SKShapeNode(rectOf: CGSize(width: totalWidth, height: totalHeight))
            debugBorder.strokeColor = SKColor.from(theme.colors.primary)
            debugBorder.lineWidth = 2
            debugBorder.zPosition = 10
            debugBorder.name = "debugBorder"
            gridNode.addChild(debugBorder)
        }
#endif
        // Draw grid lines (as children of gridNode)
        for i in 0...gridSize {
            let x = -totalWidth / 2 + CGFloat(i) * blockSize
            let y = -totalHeight / 2 + CGFloat(i) * blockSize
            // Vertical line
            let verticalLine = SKShapeNode(rectOf: CGSize(width: 1, height: totalHeight))
            verticalLine.fillColor = SKColor.from(theme.colors.secondary)
            verticalLine.alpha = 0.2
            verticalLine.position = CGPoint(x: x, y: 0)
            verticalLine.zPosition = 2
            verticalLine.name = "gridLine"
            gridNode.addChild(verticalLine)
            // Horizontal line
            let horizontalLine = SKShapeNode(rectOf: CGSize(width: totalWidth, height: 1))
            horizontalLine.fillColor = SKColor.from(theme.colors.secondary)
            horizontalLine.alpha = 0.2
            horizontalLine.position = CGPoint(x: 0, y: y)
            horizontalLine.zPosition = 2
            horizontalLine.name = "gridLine"
            gridNode.addChild(horizontalLine)
        }
        // Create container for blocks
        let containerNode = SKNode()
        containerNode.zPosition = 1
        containerNode.name = "blockContainer"
        gridNode.addChild(containerNode)
        // Draw all placed blocks
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if let color = gameState.grid[row][col] {
                    let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
                    // Gradient fill
                    let colors = [color.gradientColors.start, color.gradientColors.end]
                    let locations: [CGFloat] = [0.0, 1.0]
                    if let gradientImage = createGradientImage(size: CGSize(width: blockSize, height: blockSize), colors: colors, locations: locations) {
                        cellNode.fillTexture = SKTexture(image: gradientImage)
                        cellNode.fillColor = .white
                    } else {
                        cellNode.fillColor = SKColor.from(color.color)
                    }
                    // Shadow
                    let shadowNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
                    shadowNode.fillColor = UIColor(cgColor: color.shadowColor)
                    shadowNode.alpha = 0.3
                    shadowNode.position = CGPoint(x: 2, y: -2)
                    shadowNode.zPosition = -1
                    cellNode.addChild(shadowNode)
                    // Border
                    cellNode.strokeColor = .white
                    cellNode.lineWidth = 1
                    // Shine
                    let shineNode = SKShapeNode(rectOf: CGSize(width: blockSize * 0.3, height: blockSize * 0.3))
                    shineNode.fillColor = .white
                    shineNode.alpha = 0.3
                    shineNode.position = CGPoint(x: -blockSize * 0.25, y: blockSize * 0.25)
                    shineNode.zRotation = .pi / 4
                    cellNode.addChild(shineNode)
                    // Position cell in the grid
                    let x = -totalWidth / 2 + CGFloat(col) * blockSize + blockSize / 2
                    let y = -totalHeight / 2 + CGFloat(row) * blockSize + blockSize / 2
                    cellNode.position = CGPoint(x: x, y: y)
                    containerNode.addChild(cellNode)
                }
            }
        }
    }
    func setupTray() {
        let blockSize = GameConstants.blockSize
        let trayHeight = blockSize * 4.5
        // Calculate the bottom of the grid
        let gridBottom = frame.midY - CGFloat(GameConstants.gridSize) * blockSize / 2
        // Add a buffer space between grid and tray
        let bufferSpace = blockSize * 1.5
        // Position tray below the grid with buffer
        trayNode.position = CGPoint(
            x: frame.midX,
            y: gridBottom - trayHeight / 2 - bufferSpace
        )
        trayNode.zPosition = 10
        trayNode.updateBlocks(gameState.tray, blockSize: blockSize)
    }
    private func setupUI() {
        // No-op: Score/level handled by SwiftUI overlay
    }
    private func setupParticles() {
        let adaptiveQuality = AdaptiveQualityManager.shared
        
        // Check if background animations should be enabled
        guard adaptiveQuality.shouldEnableBackgroundAnimations() else {
            Logger.shared.debug("[Quality] Background particles disabled due to quality settings", category: .debugGameScene)
            return
        }
        
        if let particles = SKEmitterNode(fileNamed: "BackgroundParticles") {
            particles.position = CGPoint(x: size.width/2, y: size.height/2)
            particles.zPosition = -1
            
            // Apply quality intensity
            let intensity = adaptiveQuality.getAnimationIntensity()
            particles.particleBirthRate *= intensity
            particles.particleAlpha *= intensity
            
            addChild(particles)
            
            Logger.shared.debug("[Quality] Background particles enabled with intensity: \(String(format: "%.2f", intensity))", category: .debugGameScene)
        }
    }
    private func drawBlock(_ block: Block, at position: CGPoint) {
        let blockSize = GameConstants.blockSize
        let blockNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
        // Create gradient fill
        let gradientNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
        gradientNode.fillColor = .clear
        gradientNode.strokeColor = .clear
        // Add gradient effect
        let colors = [block.color.gradientColors.start, block.color.gradientColors.end]
        let locations: [CGFloat] = [0.0, 1.0]
        if let gradientImage = createGradientImage(size: CGSize(width: blockSize, height: blockSize),
                                                   colors: colors,
                                                   locations: locations) {
            gradientNode.fillTexture = SKTexture(image: gradientImage)
            gradientNode.fillColor = .white
        }
        // Add shadow effect
        let shadowNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
        shadowNode.fillColor = UIColor(cgColor: block.color.shadowColor)
        shadowNode.alpha = 0.3
        shadowNode.position = CGPoint(x: 2, y: -2)
        shadowNode.zPosition = -1
        // Add subtle border
        gradientNode.strokeColor = .white
        gradientNode.lineWidth = 1
        // Add shine effect
        let shineNode = SKShapeNode(rectOf: CGSize(width: blockSize * 0.3, height: blockSize * 0.3))
        shineNode.fillColor = .white
        shineNode.alpha = 0.3
        shineNode.position = CGPoint(x: -blockSize * 0.25, y: blockSize * 0.25)
        shineNode.zRotation = .pi / 4
        blockNode.addChild(shadowNode)
        blockNode.addChild(gradientNode)
        gradientNode.addChild(shineNode)
        // Position the block
        let x = position.x * blockSize + blockSize / 2
        let y = position.y * blockSize + blockSize / 2
        blockNode.position = CGPoint(x: x, y: y)
        addChild(blockNode)
    }
    private func createBlockNode(for block: Block) -> SKNode {
        let blockNode = NodePool.shared.getBlockNode()
        for (dx, dy) in block.shape.cells {
            let cellNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
            // Create gradient fill
            let gradientNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
            gradientNode.fillColor = .clear
            gradientNode.strokeColor = .clear
            // Add gradient effect
            let colors = [block.color.gradientColors.start, block.color.gradientColors.end]
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradientImage = createGradientImage(size: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize),
                                                       colors: colors,
                                                       locations: locations) {
                gradientNode.fillTexture = SKTexture(image: gradientImage)
                gradientNode.fillColor = .white
            }
            // Add shadow effect
            let shadowNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
            shadowNode.fillColor = UIColor(cgColor: block.color.shadowColor)
            shadowNode.alpha = 0.3
            shadowNode.position = CGPoint(x: 2, y: -2)
            shadowNode.zPosition = -1
            // Add subtle border
            gradientNode.strokeColor = .white
            gradientNode.lineWidth = 1
            // Add shine effect
            let shineNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize * 0.3, height: GameConstants.blockSize * 0.3))
            shineNode.fillColor = .white
            shineNode.alpha = 0.3
            shineNode.position = CGPoint(x: -GameConstants.blockSize * 0.25, y: GameConstants.blockSize * 0.25)
            shineNode.zRotation = .pi / 4
            cellNode.addChild(shadowNode)
            cellNode.addChild(gradientNode)
            gradientNode.addChild(shineNode)
            cellNode.position = CGPoint(x: CGFloat(dx) * GameConstants.blockSize, y: CGFloat(dy) * GameConstants.blockSize)
            blockNode.addChild(cellNode)
        }
        return blockNode
    }
    private func updateTray(trayHeight: CGFloat, trayWidth: CGFloat, shapeWidths: [CGFloat], spacing: CGFloat) {
        trayNode.removeAllChildren()
        let blockSize = GameConstants.blockSize
        let totalWidth = shapeWidths.reduce(0, +) + spacing * CGFloat(max(gameState.tray.count - 1, 0))
        let startX = -totalWidth / 2
        var currentX = startX
        let containerNode = SKNode()
        containerNode.zPosition = 1
        for (index, block) in gameState.tray.enumerated() {
            let shapeWidth = shapeWidths[index]
            let shapeHeight = CGFloat(block.shape.cells.map { $0.1 }.max()! + 1) * blockSize
            let blockNode = SKNode()
            blockNode.name = "tray_\(block.id.uuidString)"
            blockNode.zPosition = CGFloat(index)
            // Vertically center the shape in the tray
            let verticalOffset = (trayHeight - shapeHeight) / 2
            for (dx, dy) in block.shape.cells {
                let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
                cellNode.position = CGPoint(x: CGFloat(dx) * blockSize, y: CGFloat(dy) * blockSize - shapeHeight / 2 + blockSize / 2 + verticalOffset)
                // Gradient fill
                let colors = [block.color.gradientColors.start, block.color.gradientColors.end]
                let locations: [CGFloat] = [0.0, 1.0]
                if let gradientImage = createGradientImage(size: CGSize(width: blockSize, height: blockSize), colors: colors, locations: locations) {
                    cellNode.fillTexture = SKTexture(image: gradientImage)
                    cellNode.fillColor = .white
                } else {
                    cellNode.fillColor = SKColor.from(block.color.color)
                }
                // Shadow
                let shadowNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
                shadowNode.fillColor = UIColor(cgColor: block.color.shadowColor)
                shadowNode.alpha = 0.3
                shadowNode.position = CGPoint(x: 2, y: -2)
                shadowNode.zPosition = -1
                cellNode.addChild(shadowNode)
                // Border
                cellNode.strokeColor = .white
                cellNode.lineWidth = 2
                blockNode.addChild(cellNode)
            }
            // Center each blockNode horizontally in its shape width
            blockNode.position = CGPoint(x: currentX + shapeWidth / 2, y: 0)
            containerNode.addChild(blockNode)
            currentX += shapeWidth + spacing
        }
        trayNode.addChild(containerNode)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: trayNode)
        let nodesAtPoint = trayNode.nodes(at: location)
        // Record input event for latency tracking
        PerformanceMonitor.shared.recordInputEvent()
        if let node = nodesAtPoint.first(where: { $0.name?.starts(with: "trayShape_") == true }),
           let blockIdString = node.name?.replacingOccurrences(of: "trayShape_", with: ""),
           let block = gameState.tray.first(where: { $0.id.uuidString == blockIdString }) {
            draggingBlock = block
            // Clean up existing drag node before creating new one
            if let existing = dragNode {
                existing.removeAllActions()
                existing.removeAllChildren()
                existing.removeFromParent()
                dragNode = nil
            }
            // Create drag node at full grid size and apply the grid's scale
            dragNode = ShapeNode(block: block, blockSize: GameConstants.blockSize)
            dragNode?.setScale(gridNode.xScale) // Apply the same scale as the grid
            let touchLocation = touch.location(in: self)
            let blockDragOffset = UserDefaults.standard.double(forKey: "blockDragOffset")
            dragNode?.position = CGPoint(x: touchLocation.x, y: touchLocation.y + GameConstants.blockSize * blockDragOffset)
            dragNode?.alpha = 0.7
            dragNode?.zPosition = 50
            addChild(dragNode!)
            // FIXED: Don't remove the block from tray until placement is successful
            // gameState.removeBlockFromTray(block) - REMOVED
            // Update the tray display
            setupTray()
            // Visually indicate the block is being dragged by reducing opacity
            if let trayBlockNode = trayNode.childNode(withName: "trayShape_\(block.id.uuidString)") {
                trayBlockNode.alpha = 0.3
            }
        }
    }
    private func createLineHighlight(for row: Int, isRow: Bool, color: SKColor, blockSize: CGFloat) -> SKShapeNode {
        let gridSize = GameConstants.gridSize
        let totalSize = CGFloat(gridSize) * blockSize
        let highlight: SKShapeNode
        if isRow {
            highlight = SKShapeNode(rectOf: CGSize(width: totalSize, height: blockSize), cornerRadius: blockSize * 0.18)
            highlight.position = CGPoint(
                x: 0,
                y: CGFloat(row) * blockSize - totalSize / 2 + blockSize / 2
            )
        } else {
            highlight = SKShapeNode(rectOf: CGSize(width: blockSize, height: totalSize), cornerRadius: blockSize * 0.18)
            highlight.position = CGPoint(
                x: CGFloat(row) * blockSize - totalSize / 2 + blockSize / 2,
                y: 0
            )
        }
        // Create gradient fill
        let colors = [color.withAlphaComponent(0.8).cgColor, color.withAlphaComponent(0.4).cgColor]
        let locations: [CGFloat] = [0.0, 1.0]
        if let gradientImage = createGradientImage(size: highlight.frame.size, colors: colors, locations: locations) {
            highlight.fillTexture = SKTexture(image: gradientImage)
            highlight.fillColor = .white
        } else {
            highlight.fillColor = color.withAlphaComponent(0.6)
        }
        // Add border (removed glow effect to prevent unintended edge glow)
        highlight.strokeColor = .white
        highlight.lineWidth = 2
        // Add shine effect
        let shineNode = SKShapeNode(rectOf: CGSize(width: blockSize * 0.3, height: blockSize * 0.3))
        shineNode.fillColor = .white
        shineNode.alpha = 0.3
        shineNode.position = CGPoint(x: -blockSize * 0.25, y: blockSize * 0.25)
        shineNode.zRotation = .pi / 4
        highlight.addChild(shineNode)
        highlight.zPosition = 10
        // Add pulsing animation
        let pulse = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.4, duration: 0.5),
                SKAction.scale(to: 0.95, duration: 0.5)
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.8, duration: 0.5),
                SKAction.scale(to: 1.05, duration: 0.5)
            ])
        ])
        highlight.run(SKAction.repeatForever(pulse))
        return highlight
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let dragNode = dragNode,
              let draggingBlock = draggingBlock else { return }
        
        // Enhanced throttling for performance
        let now = CACurrentMediaTime()
        if now - lastTouchMoveUpdate < touchUpdateThrottle {
            return
        }
        lastTouchMoveUpdate = now
        
        let touchPoint = touch.location(in: self)
        let gridPoint = convertToGridCoordinates(touchPoint)
        
        // Record input event for latency tracking
        PerformanceMonitor.shared.recordInputEvent()
        
        // Update drag node position to follow touch more precisely
        let blockDragOffset = UserDefaults.standard.double(forKey: "blockDragOffset")
        dragNode.position = CGPoint(x: touchPoint.x, y: touchPoint.y + GameConstants.blockSize * blockDragOffset)
        
        // Only update preview/highlights if grid position changed or if no preview exists
        let positionChanged = gridPoint != lastGridPosition
        let needsPreviewUpdate = previewNode == nil || positionChanged
        
        if needsPreviewUpdate {
            lastGridPosition = gridPoint
            isHeavyOperationActive = true
            
            // VALIDATION: Check placement validity BEFORE any visual updates
            let canPlace = gameState.canPlaceBlock(draggingBlock, at: gridPoint)
            print("[DEBUG] Drag validation for \(draggingBlock.shape)-\(draggingBlock.color) at (\(gridPoint.x), \(gridPoint.y)): \(canPlace)")
            
            // Reuse existing preview node instead of creating new one
            if let existingPreview = previewNode {
                // Update existing preview instead of recreating
                updatePreviewNode(existingPreview, for: draggingBlock, at: gridPoint)
            } else {
                // Get preview node from pool
                let preview = NodePool.shared.getPreviewNode()
                preview.name = "preview_block"
                preview.zPosition = 5
                
                // Safety check: ensure the preview node doesn't already have a parent
                if preview.parent != nil {
                    print("[DEBUG] Preview node already has parent, removing before reuse")
                    preview.removeFromParent()
                }
                
                setupPreviewNode(preview, for: draggingBlock, at: gridPoint)
                gridNode.addChild(preview)
                previewNode = preview
                print("[DEBUG] Created new preview node for block: \(draggingBlock.id)")
            }
            
            // Reuse existing highlight container instead of creating new one
            let existingHighlightContainer = gridNode.children.first { $0.name == "highlight_container" }
            if let highlightContainer = existingHighlightContainer {
                // Update existing highlights
                updateHighlightContainer(highlightContainer, for: draggingBlock, at: gridPoint)
            } else {
                // Get highlight container from pool
                let highlightContainer = NodePool.shared.getHighlightNode()
                highlightContainer.name = "highlight_container"
                highlightContainer.zPosition = 10
                
                // Safety check: ensure the highlight container doesn't already have a parent
                if highlightContainer.parent != nil {
                    highlightContainer.removeFromParent()
                }
                
                setupHighlightContainer(highlightContainer, for: draggingBlock, at: gridPoint)
                gridNode.addChild(highlightContainer)
            }
            
            // Update drag node alpha based on placement validity
            dragNode.alpha = canPlace ? 0.7 : 1.0
            
            isHeavyOperationActive = false
        }
    }
    
    // MARK: - Preview Node Management
    private func setupPreviewNode(_ preview: SKNode, for block: Block, at gridPoint: CGPoint) {
        // Clear any existing children
        preview.removeAllChildren()
        
        // Check if preview is enabled
        let previewEnabled = UserDefaults.standard.bool(forKey: "previewEnabled")
        if !previewEnabled {
            preview.alpha = 0.0
            return
        }
        
        // Check placement validity BEFORE creating preview
        guard gameState.canPlaceBlock(block, at: gridPoint) else {
            preview.alpha = 0.0
            return
        }
        
        // Create preview for each cell in the shape
        for (dx, dy) in block.shape.cells {
            let cellNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
            cellNode.fillColor = SKColor.from(block.color.color)
            cellNode.strokeColor = .clear
            cellNode.alpha = 0.5
            cellNode.name = "preview_cell"
            
            // Position each cell relative to the shape's anchor point
            cellNode.position = CGPoint(
                x: CGFloat(dx) * GameConstants.blockSize,
                y: CGFloat(dy) * GameConstants.blockSize
            )
            preview.addChild(cellNode)
        }
        
        // Position the preview at the grid point with height offset
        let totalWidth = CGFloat(GameConstants.gridSize) * GameConstants.blockSize
        let totalHeight = CGFloat(GameConstants.gridSize) * GameConstants.blockSize
        let previewHeightOffset = UserDefaults.standard.double(forKey: "previewHeightOffset")
        
        // Snap the offset to grid spaces to ensure perfect alignment
        let gridAlignedOffset = round(previewHeightOffset) * GameConstants.blockSize
        
        preview.position = CGPoint(
            x: -totalWidth / 2 + CGFloat(gridPoint.x) * GameConstants.blockSize + GameConstants.blockSize / 2,
            y: -totalHeight / 2 + CGFloat(gridPoint.y) * GameConstants.blockSize + GameConstants.blockSize / 2 + gridAlignedOffset
        )
        
        // Show the preview since placement is valid
        preview.alpha = 1.0
    }
    
    private func updatePreviewNode(_ preview: SKNode, for block: Block, at gridPoint: CGPoint) {
        // Check if preview is enabled
        let previewEnabled = UserDefaults.standard.bool(forKey: "previewEnabled")
        if !previewEnabled {
            preview.alpha = 0.0
            return
        }
        
        // Check placement validity first
        let canPlace = gameState.canPlaceBlock(block, at: gridPoint)
        
        if canPlace {
            // Clear existing children and recreate preview cells
            preview.removeAllChildren()
            
            // Create preview for each cell in the shape
            for (dx, dy) in block.shape.cells {
                let cellNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
                cellNode.fillColor = SKColor.from(block.color.color)
                cellNode.strokeColor = .clear
                cellNode.alpha = 0.5
                cellNode.name = "preview_cell"
                
                // Position each cell relative to the shape's anchor point
                cellNode.position = CGPoint(
                    x: CGFloat(dx) * GameConstants.blockSize,
                    y: CGFloat(dy) * GameConstants.blockSize
                )
                preview.addChild(cellNode)
            }
            
            // Update position with height offset
            let totalWidth = CGFloat(GameConstants.gridSize) * GameConstants.blockSize
            let totalHeight = CGFloat(GameConstants.gridSize) * GameConstants.blockSize
            let previewHeightOffset = UserDefaults.standard.double(forKey: "previewHeightOffset")
            
            // Snap the offset to grid spaces to ensure perfect alignment
            let gridAlignedOffset = round(previewHeightOffset) * GameConstants.blockSize
            
            preview.position = CGPoint(
                x: -totalWidth / 2 + CGFloat(gridPoint.x) * GameConstants.blockSize + GameConstants.blockSize / 2,
                y: -totalHeight / 2 + CGFloat(gridPoint.y) * GameConstants.blockSize + GameConstants.blockSize / 2 + gridAlignedOffset
            )
            preview.alpha = 1.0
        } else {
            // Hide preview for invalid placement
            preview.alpha = 0.0
        }
    }
    
    // MARK: - Highlight Container Management
    private func setupHighlightContainer(_ container: SKNode, for block: Block, at gridPoint: CGPoint) {
        // Clear any existing children
        container.removeAllChildren()
        
        // Only show highlights if placement is valid
        guard gameState.canPlaceBlock(block, at: gridPoint) else { 
            container.alpha = 0.0
            return 
        }
        
        // Check which lines would be cleared
        let (rowsToClear, columnsToClear) = gameState.wouldClearLines(block: block, at: gridPoint)
        let highlightColor = SKColor.from(block.color.color)
        
        // Create highlights for rows and columns that would be cleared
        for row in rowsToClear {
            let highlight = createLineHighlight(for: row, isRow: true, color: highlightColor, blockSize: GameConstants.blockSize)
            highlight.name = "highlight_row_\(row)"
            container.addChild(highlight)
        }
        
        for col in columnsToClear {
            let highlight = createLineHighlight(for: col, isRow: false, color: highlightColor, blockSize: GameConstants.blockSize)
            highlight.name = "highlight_column_\(col)"
            container.addChild(highlight)
        }
        
        container.alpha = 1.0
    }
    
    private func clearAllHighlightContainers() {
        // Clear any existing highlight containers to prevent edge glow artifacts
        gridNode.children.forEach { node in
            if node.name?.hasPrefix("highlight_") == true {
                node.removeAllActions()
                node.removeAllChildren()
                node.removeFromParent()
                NodePool.shared.returnHighlightNode(node)
            }
        }
    }
    
    private func updateHighlightContainer(_ container: SKNode, for block: Block, at gridPoint: CGPoint) {
        // Only update highlights if placement is valid
        if gameState.canPlaceBlock(block, at: gridPoint) {
            // Check if highlights need to change
            let (rowsToClear, columnsToClear) = gameState.wouldClearLines(block: block, at: gridPoint)
            
            // Update existing highlights or create new ones
            updateLineHighlights(container, rowsToClear: Array(rowsToClear), columnsToClear: Array(columnsToClear), color: SKColor.from(block.color.color))
        } else {
            // Hide highlights for invalid placement
            container.alpha = 0.0
        }
    }
    
    private func updateLineHighlights(_ container: SKNode, rowsToClear: [Int], columnsToClear: [Int], color: SKColor) {
        // Remove old highlights that are no longer needed
        container.children.forEach { child in
            if let name = child.name {
                if name.hasPrefix("highlight_row_") {
                    let row = Int(name.replacingOccurrences(of: "highlight_row_", with: "")) ?? -1
                    if !rowsToClear.contains(row) {
                        child.removeFromParent()
                    }
                } else if name.hasPrefix("highlight_column_") {
                    let col = Int(name.replacingOccurrences(of: "highlight_column_", with: "")) ?? -1
                    if !columnsToClear.contains(col) {
                        child.removeFromParent()
                    }
                }
            }
        }
        
        // Add new highlights that are needed
        let existingRows = container.children.compactMap { child -> Int? in
            guard let name = child.name, name.hasPrefix("highlight_row_") else { return nil }
            return Int(name.replacingOccurrences(of: "highlight_row_", with: ""))
        }
        
        let existingColumns = container.children.compactMap { child -> Int? in
            guard let name = child.name, name.hasPrefix("highlight_column_") else { return nil }
            return Int(name.replacingOccurrences(of: "highlight_column_", with: ""))
        }
        
        // Add missing row highlights
        for row in rowsToClear where !existingRows.contains(row) {
            let highlight = createLineHighlight(for: row, isRow: true, color: color, blockSize: GameConstants.blockSize)
            highlight.name = "highlight_row_\(row)"
            container.addChild(highlight)
        }
        
        // Add missing column highlights
        for col in columnsToClear where !existingColumns.contains(col) {
            let highlight = createLineHighlight(for: col, isRow: false, color: color, blockSize: GameConstants.blockSize)
            highlight.name = "highlight_column_\(col)"
            container.addChild(highlight)
        }
        
        container.alpha = 1.0
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let dragNode = dragNode,
              let draggingBlock = draggingBlock else { return }
        
        print("[DEBUG] Touch ended - handling placement for block: \(draggingBlock.shape)-\(draggingBlock.color)")
        
        // Record input event for latency tracking
        PerformanceMonitor.shared.recordInputEvent()
        
        // Check if enough time has passed since last placement
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastPlacementTime >= placementDebounceInterval else {
            print("[DEBUG] Placement debounced - too soon since last placement")
            // Too soon since last placement, ignore this touch
            dragNode.removeFromParent()
            previewNode?.removeFromParent()
            self.dragNode = nil
            self.draggingBlock = nil
            self.previewNode = nil
            return
        }
        
        let touchPoint = touch.location(in: self)
        let gridPoint = convertToGridCoordinates(touchPoint)
        
        print("[DEBUG] Touch point: \(touchPoint), Grid point: \(gridPoint)")
        
        // ATOMIC VALIDATION: Check placement validity before attempting placement
        let canPlace = gameState.canPlaceBlock(draggingBlock, at: gridPoint)
        print("[DEBUG] Can place block: \(canPlace)")
        
        if canPlace {
            // ATOMIC PLACEMENT: Try to place the block
            if gameState.tryPlaceBlockFromTray(draggingBlock, at: gridPoint) {
                print("[DEBUG] Block placement successful")
                // Update last placement time
                lastPlacementTime = currentTime
                // Force a complete grid redraw to ensure all blocks are properly rendered
                renderGrid(gridNode: gridNode, gameState: gameState, blockSize: GameConstants.blockSize)
                // Play placement sound
                AudioManager.shared.playPlacementSound()
                // Refill tray after successful placement
                if gameState.tray.count < 3 {
                    gameState.refillTray()
                }
            } else {
                print("[ERROR] Block placement failed despite validation!")
                // Play error sound
                AudioManager.shared.playFailSound()
                // FIXED: Don't add block back to tray since it was never removed
                // gameState.addBlockToTray(draggingBlock) - REMOVED
            }
        } else {
            print("[DEBUG] Invalid placement - returning block to tray")
            // Play error sound
            AudioManager.shared.playFailSound()
            // FIXED: Don't add block back to tray since it was never removed
            // gameState.addBlockToTray(draggingBlock) - REMOVED
        }
        
        // Clean up all temporary nodes and return them to pool
        if let existing = self.dragNode {
            existing.removeAllActions()
            existing.removeAllChildren()
            existing.removeFromParent()
            self.dragNode = nil
        }
        
        if let existing = self.previewNode {
            existing.removeAllActions()
            existing.removeAllChildren()
            existing.removeFromParent()
            NodePool.shared.returnPreviewNode(existing)
            self.previewNode = nil
        }
        
        // FIXED: Restore tray block opacity after drag ends
        if let draggingBlock = self.draggingBlock {
            if let trayBlockNode = trayNode.childNode(withName: "trayShape_\(draggingBlock.id.uuidString)") {
                trayBlockNode.alpha = 1.0
            }
        }
        
        // Return highlight containers to pool instead of destroying them
        clearAllHighlightContainers()
        
        self.draggingBlock = nil
        lastGridPosition = CGPoint.zero // Reset position tracking
        
        print("[DEBUG] Touch handling completed")
    }
    
    // MARK: - Robust Drag Management
    
    private func cancelDragAndReturnToTray() {
        guard let draggingBlock = draggingBlock else { return }
        
        print("[DEBUG] Cancelling drag and returning block to tray: \(draggingBlock.shape)-\(draggingBlock.color)")
        
        // FIXED: Don't add block back to tray since it was never removed
        // gameState.addBlockToTray(draggingBlock) - REMOVED
        
        // Clean up visual nodes
        if let existing = self.dragNode {
            existing.removeAllActions()
            existing.removeAllChildren()
            existing.removeFromParent()
            self.dragNode = nil
        }
        
        if let existing = self.previewNode {
            existing.removeAllActions()
            existing.removeAllChildren()
            existing.removeFromParent()
            NodePool.shared.returnPreviewNode(existing)
            self.previewNode = nil
        }
        
        // Clear highlights
        clearAllHighlightContainers()
        
        // Reset state
        self.draggingBlock = nil
        lastGridPosition = CGPoint.zero
        
        print("[DEBUG] Drag cancellation completed")
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("[DEBUG] Touch cancelled - returning block to tray")
        cancelDragAndReturnToTray()
    }
    
    private func convertToGridCoordinates(_ point: CGPoint) -> CGPoint {
        // Get the grid's scale
        let gridScale = gridNode.xScale
        // Calculate the grid's total size
        let totalWidth = CGFloat(GameConstants.gridSize) * GameConstants.blockSize * gridScale
        let totalHeight = CGFloat(GameConstants.gridSize) * GameConstants.blockSize * gridScale
        // Calculate the grid's origin (top-left corner)
        let gridOrigin = CGPoint(
            x: gridNode.position.x - totalWidth / 2,
            y: gridNode.position.y - totalHeight / 2
        )
        // Calculate the relative position within the grid
        let relativeX = point.x - gridOrigin.x
        let relativeY = point.y - gridOrigin.y
        // Calculate the exact grid position without any snapping
        let exactCol = relativeX / (GameConstants.blockSize * gridScale)
        let exactRow = relativeY / (GameConstants.blockSize * gridScale)
        // Calculate the remainder to determine how close we are to cell centers
        let remainderX = abs(exactCol.truncatingRemainder(dividingBy: 1))
        let remainderY = abs(exactRow.truncatingRemainder(dividingBy: 1))
        // Get the placement precision from UserDefaults
        let snapThreshold = UserDefaults.standard.double(forKey: "placementPrecision")
        // Determine final grid position
        let finalCol: Int
        let finalRow: Int
        if remainderX < snapThreshold {
            // Snap to nearest cell center horizontally
            finalCol = Int(round(exactCol))
        } else {
            // Use exact position for more precise placement
            finalCol = Int(exactCol)
        }
        if remainderY < snapThreshold {
            // Snap to nearest cell center vertically
            finalRow = Int(round(exactRow))
        } else {
            // Use exact position for more precise placement
            finalRow = Int(exactRow)
        }
        // Ensure we stay within grid bounds
        return CGPoint(
            x: max(0, min(GameConstants.gridSize - 1, finalCol)),
            y: max(0, min(GameConstants.gridSize - 1, finalRow))
        )
    }
    private func playPlacementAnimation(at position: CGPoint) {
        let cellSize = GameConstants.blockSize
        let node = SKSpriteNode(color: .white, size: CGSize(width: cellSize, height: cellSize))
        node.position = CGPoint(
            x: CGFloat(position.x) * cellSize - CGFloat(GameConstants.gridSize) * cellSize/2,
            y: CGFloat(position.y) * cellSize - CGFloat(GameConstants.gridSize) * cellSize/2
        )
        node.alpha = 0.5
        gridNode.addChild(node)
        // Pop animation
        let scaleAction = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.12),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ])
        node.run(scaleAction)
        // Play sound and haptic
        AudioManager.shared.playPlacementSound()
        playHaptic(style: .medium)
    }
    func playComboAnimation(at positions: [CGPoint]) {
        let adaptiveQuality = AdaptiveQualityManager.shared
        
        // Check if particles should be enabled
        guard adaptiveQuality.shouldEnableParticles() else {
            // Play audio and haptic feedback without particles
            AudioManager.shared.playLevelCompleteSound()
            playHaptic(style: .heavy)
            return
        }
        
        cleanupParticleEffects()
        let remainingSlots = maxParticleEmitters - activeParticleEmitters.count
        let positionsToAnimate = Array(positions.prefix(remainingSlots))
        
        for pos in positionsToAnimate {
            let particles = NodePool.shared.getParticleEmitter()
            
            // Track for memory leaks
            #if DEBUG
            MemoryLeakDetector.shared.trackParticleEmitter(particles)
            #endif
            
            particles.position = CGPoint(
                x: CGFloat(pos.x) * GameConstants.blockSize - CGFloat(GameConstants.gridSize) * GameConstants.blockSize/2,
                y: CGFloat(pos.y) * GameConstants.blockSize - CGFloat(GameConstants.gridSize) * GameConstants.blockSize/2
            )
            
            // Optimize particle emitter with quality settings
            optimizeParticleEmitter(particles)
            
            // Apply quality intensity
            let intensity = adaptiveQuality.getParticleIntensity()
            particles.particleBirthRate *= intensity
            particles.particleAlpha *= intensity
            
            gridNode.addChild(particles)
            activeParticleEmitters.append(particles)
            
            let wait = SKAction.wait(forDuration: 0.5)
            let remove = SKAction.run { [weak self] in
                particles.removeFromParent()
                self?.activeParticleEmitters.removeAll { $0 === particles }
                
                // Stop memory leak tracking
                #if DEBUG
                MemoryLeakDetector.shared.stopTracking(particles, type: "SKEmitterNode")
                #endif
                
                NodePool.shared.returnParticleEmitter(particles)
            }
            particles.run(SKAction.sequence([wait, remove]))
        }
        
        AudioManager.shared.playLevelCompleteSound()
        playHaptic(style: .heavy)
    }
    private func animateTrayRefill() {
        let moveUp = SKAction.moveBy(x: 0, y: 20, duration: 0.12)
        let moveDown = SKAction.moveBy(x: 0, y: -20, duration: 0.18)
        trayNode.run(SKAction.sequence([moveUp, moveDown]))
        AudioManager.shared.playSound("placement")
    }
    private func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
#if os(iOS)
        if UserDefaults.standard.bool(forKey: "hapticsEnabled") {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
#endif
    }
    // MARK: - Grid Rendering
    private func renderGrid(gridNode: SKNode, gameState: GameState, blockSize: CGFloat) {
        for node in gridNode.children {
            if node.name != "gridLine" && node.name != "gridBackground" {
                node.removeFromParent()
            }
        }
        let gridSize = GameConstants.gridSize
        let containerNode = SKNode()
        containerNode.zPosition = 1
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if let color = gameState.grid[row][col] {
                    let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
                    // Gradient fill
                    let colors = [color.gradientColors.start, color.gradientColors.end]
                    let locations: [CGFloat] = [0.0, 1.0]
                    if let gradientImage = createGradientImage(size: CGSize(width: blockSize, height: blockSize), colors: colors, locations: locations) {
                        cellNode.fillTexture = SKTexture(image: gradientImage)
                        cellNode.fillColor = .white
                    } else {
                        cellNode.fillColor = SKColor.from(color.color)
                    }
                    // Shadow
                    let shadowNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
                    shadowNode.fillColor = UIColor(cgColor: color.shadowColor)
                    shadowNode.alpha = 0.3
                    shadowNode.position = CGPoint(x: 2, y: -2)
                    shadowNode.zPosition = -1
                    cellNode.addChild(shadowNode)
                    // Border
                    cellNode.strokeColor = .white
                    cellNode.lineWidth = 1
                    // Shine
                    let shineNode = SKShapeNode(rectOf: CGSize(width: blockSize * 0.3, height: blockSize * 0.3))
                    shineNode.fillColor = .white
                    shineNode.alpha = 0.3
                    shineNode.position = CGPoint(x: -blockSize * 0.25, y: blockSize * 0.25)
                    shineNode.zRotation = .pi / 4
                    cellNode.addChild(shineNode)
                    cellNode.position = CGPoint(
                        x: CGFloat(col) * blockSize - CGFloat(gridSize) * blockSize / 2 + blockSize / 2,
                        y: CGFloat(row) * blockSize - CGFloat(gridSize) * blockSize / 2 + blockSize / 2
                    )
                    cellNode.name = "placedBlock"
                    cellNode.zPosition = 1
                    containerNode.addChild(cellNode)
                }
            }
        }
        gridNode.addChild(containerNode)
    }
    // MARK: - Memory Management
    private func setupMemoryManagement() async {
        // Start periodic memory monitoring with significantly reduced frequency
        Timer.scheduledTimer(withTimeInterval: MemoryConfig.getIntervals().memoryCheck * 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndCleanupMemory()
            }
        }
    }
    private func checkAndCleanupMemory() async {
        let status = MemorySystem.shared.checkMemoryStatus()
        // Update warning label
        if let label = memoryWarningLabel {
            switch status {
            case .critical:
                label.text = "MEMORY CRITICAL"
                label.isHidden = false
                await performAggressiveCleanup()
            case .warning:
                label.text = "MEMORY WARNING"
                label.isHidden = false
                performNormalCleanup()
            case .normal:
                label.isHidden = true
            }
        }
    }
    private func performAggressiveCleanup() async {
        Logger.shared.debug("[Memory] Performing aggressive cleanup", category: .debugGameScene)
        
        // Clear all placed block nodes
        clearAllPlacedBlockNodes()
        
        // Clear any remaining cached nodes
        cachedNodes.values.forEach { cleanupNode($0) }
        cachedNodes.removeAll()
        
        // Clear any remaining block nodes
        blockNodes.forEach { cleanupNode($0) }
        blockNodes.removeAll()
        
        // Clear any remaining preview or drag nodes
        if let preview = previewNode {
            preview.removeAllActions()
            preview.removeAllChildren()
            preview.removeFromParent()
            previewNode = nil
        }
        if let drag = dragNode {
            drag.removeAllActions()
            drag.removeAllChildren()
            drag.removeFromParent()
            dragNode = nil
        }
        
        // Clear any remaining hint highlights
        if let hint = hintHighlight {
            hint.removeAllActions()
            hint.removeAllChildren()
            hint.removeFromParent()
            hintHighlight = nil
        }
        
        // Clear gradient texture cache
        gradientTextureCache.removeAll()
        
        // Clear node pools
        NodePool.shared.clearAllPools()
        
        // Notify GameState
        await gameState.handleCriticalMemory()
        
        // Clear textures in separate operation to reduce memory pressure
        await clearAllTextures()
    }
    private func performNormalCleanup() {
        Logger.shared.debug("[Memory] Performing normal cleanup", category: .debugGameScene)
        
        // Clear any remaining cached nodes
        cachedNodes.values.forEach { cleanupNode($0) }
        cachedNodes.removeAll()
        
        // Clear any remaining block nodes
        blockNodes.forEach { cleanupNode($0) }
        blockNodes.removeAll()
        
        // Clear any remaining preview or drag nodes
        if let preview = previewNode {
            preview.removeAllActions()
            preview.removeAllChildren()
            preview.removeFromParent()
            previewNode = nil
        }
        if let drag = dragNode {
            drag.removeAllActions()
            drag.removeAllChildren()
            drag.removeFromParent()
            dragNode = nil
        }
        
        // Clear any remaining hint highlights
        if let hint = hintHighlight {
            hint.removeAllActions()
            hint.removeAllChildren()
            hint.removeFromParent()
            hintHighlight = nil
        }
        
        // Clear any remaining temporary nodes in the scene
        children.forEach { node in
            if node.name?.hasPrefix("temp_") == true {
                cleanupNode(node)
            }
        }
        
        // Clean up placed block nodes
        cleanupPlacedBlockNodes()
        
        // Clear gradient texture cache if it's getting too large
        if gradientTextureCache.count > maxGradientCacheSize / 2 {
            gradientTextureCache.removeAll()
        }
        
        // Clear node pools
        NodePool.shared.clearAllPools()
    }
    @objc private func handleMemoryWarningNotification() {
        Task { @MainActor in
            Logger.shared.debug("[Memory] Received memory warning", category: .debugGameScene)
            // Clear textures
            await clearAllTextures()
            // Cleanup node pools
            NodePool.shared.cleanupPools()
            // Perform normal cleanup
            performNormalCleanup()
        }
    }
    @objc private func handleMemoryCriticalNotification() {
        Task { @MainActor in
            Logger.shared.debug("[Memory] Received critical memory warning", category: .debugGameScene)
            // Clear all textures
            await clearAllTextures()
            // Clear all node pools
            NodePool.shared.clearAllPools()
            // Perform aggressive cleanup
            await performAggressiveCleanup()
        }
    }
    private func cleanupMemory() async {
        performNormalCleanup()
    }
    override func update(_ currentTime: TimeInterval) {
        // Check for memory cleanup
        if currentTime - lastMemoryCleanup >= memoryCleanupInterval {
            Task { @MainActor in
                Logger.shared.debug("[Memory] Performing periodic memory cleanup", category: .debugGameScene)
                await cleanupMemory()
                lastMemoryCleanup = currentTime
            }
        }
        // Update game state
        Task {
            await gameState.update()
        }
    }
    private func handleGameOver() {
        // Play fail sound
        AudioManager.shared.playFailSound()
        // Create a container node for the game over overlay
        let overlayNode = SKNode()
        overlayNode.zPosition = 1000
        // Create a semi-transparent black background
        let background = SKShapeNode(rectOf: size)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .clear
        overlayNode.addChild(background)
        // Create game over text
        let gameOverLabel = SKLabelNode(text: "Game Over")
        gameOverLabel.fontName = "AvenirNext-Bold"
        gameOverLabel.fontSize = 36
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: 0, y: 50)
        overlayNode.addChild(gameOverLabel)
        // Create score text
        let scoreLabel = SKLabelNode(text: "Final Score: \(gameState.score)")
        scoreLabel.fontName = "AvenirNext-Regular"
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 0, y: 0)
        overlayNode.addChild(scoreLabel)
        // Create level text
        let levelLabel = SKLabelNode(text: "Level Reached: \(gameState.level)")
        levelLabel.fontName = "AvenirNext-Regular"
        levelLabel.fontSize = 20
        levelLabel.fontColor = .yellow
        levelLabel.position = CGPoint(x: 0, y: -30)
        overlayNode.addChild(levelLabel)
        // Create Try Again button
        let tryAgainButton = SKLabelNode(text: "Try Again")
        tryAgainButton.fontName = "AvenirNext-Bold"
        tryAgainButton.fontSize = 24
        tryAgainButton.fontColor = .white
        tryAgainButton.position = CGPoint(x: 0, y: -80)
        tryAgainButton.name = "tryAgainButton"
        overlayNode.addChild(tryAgainButton)
        // Create Main Menu button
        let mainMenuButton = SKLabelNode(text: "Main Menu")
        mainMenuButton.fontName = "AvenirNext-Bold"
        mainMenuButton.fontSize = 24
        mainMenuButton.fontColor = .white
        mainMenuButton.position = CGPoint(x: 0, y: -120)
        mainMenuButton.name = "mainMenuButton"
        overlayNode.addChild(mainMenuButton)
        // Add the overlay to the scene
        addChild(overlayNode)
    }
    // Add this method to handle hint highlighting
    func highlightHint(block: Block, at position: (row: Int, col: Int)) {
        Logger.shared.debug("[Hint] Highlighting hint for block \(block.shape) at position: row \(position.row), col \(position.col)", category: .debugGameScene)
        // Remove existing hint highlight if any
        if hintHighlight != nil {
            Logger.shared.debug("[Hint] Removing existing hint highlight", category: .debugGameScene)
            hintHighlight?.removeAllActions()
            hintHighlight?.removeAllChildren()
            hintHighlight?.removeFromParent()
            hintHighlight = nil
        }
        // Create new hint highlight container
        let highlightContainer = SKNode()
        highlightContainer.zPosition = 5 // Higher than grid but lower than UI
        // Create new hint highlight for each cell in the shape
        let blockSize = GameConstants.blockSize
        let gridSize = GameConstants.gridSize
        let totalWidth = CGFloat(gridSize) * blockSize
        let totalHeight = CGFloat(gridSize) * blockSize
        // Create highlight for each cell in the shape
        for (dx, dy) in block.shape.cells {
            let x = -totalWidth / 2 + CGFloat(position.col + dx) * blockSize + blockSize / 2
            let y = -totalHeight / 2 + CGFloat(position.row + dy) * blockSize + blockSize / 2
            Logger.shared.debug("[Hint] Creating highlight cell at grid position: x \(x), y \(y)", category: .debugGameScene)
            let highlight = SKShapeNode(rectOf: CGSize(width: blockSize * 0.9, height: blockSize * 0.9))
            highlight.fillColor = .clear
            highlight.strokeColor = .yellow
            highlight.lineWidth = 3
            highlight.position = CGPoint(x: x, y: y)
            highlight.alpha = 0.7
            // Add pulsing animation
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.5),
                SKAction.fadeAlpha(to: 0.7, duration: 0.5)
            ])
            highlight.run(SKAction.repeatForever(pulse))
            highlightContainer.addChild(highlight)
        }
        // Add to grid node
        gridNode.addChild(highlightContainer)
        hintHighlight = highlightContainer
        Logger.shared.debug("[Hint] Hint highlight added to grid node", category: .debugGameScene)
        // Remove highlight after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            Logger.shared.debug("[Hint] Removing hint highlight after timeout", category: .debugGameScene)
            if let existing = self?.hintHighlight {
                existing.removeAllActions()
                existing.removeAllChildren()
                existing.removeFromParent()
            }
            self?.hintHighlight = nil
        }
    }
    // Add the old method for backward compatibility
    func highlightHint(at position: (row: Int, col: Int)) {
        // This is kept for backward compatibility but should not be used
        Logger.shared.debug("[Hint] Warning: Using deprecated highlightHint method", category: .debugGameScene)
    }
    private func updateTheme() {
        // Get the current theme
        let theme = ThemeManager.shared.getCurrentTheme()
        // Update grid appearance
        if let gridBackground = gridNode.childNode(withName: "gridBackground") as? SKShapeNode {
            gridBackground.fillColor = SKColor.from(theme.colors.background)
        }
        // Update grid lines
        gridNode.children.forEach { node in
            if node.name == "gridLine", let line = node as? SKShapeNode {
                line.fillColor = SKColor.from(theme.colors.secondary)
            }
        }
        // Update debug border if present
        if let debugBorder = gridNode.childNode(withName: "debugBorder") as? SKShapeNode {
            debugBorder.strokeColor = SKColor.from(theme.colors.primary)
        }
        // Update all blocks with new theme colors
        gridNode.children.forEach { node in
            if let blockNode = node as? SKShapeNode, blockNode.name?.hasPrefix("block_") == true {
                // Update block appearance based on the current theme
                if let nodeName = blockNode.name,
                   let components = nodeName.split(separator: "_").dropFirst().first,
                   let row = Int(components),
                   let col = Int(nodeName.split(separator: "_").dropFirst().dropFirst().first ?? ""),
                   row < gameState.grid.count && col < gameState.grid[row].count,
                   let block = gameState.grid[row][col] {
                    // Update gradient fill
                    let colors = [block.gradientColors.start, block.gradientColors.end]
                    let locations: [CGFloat] = [0.0, 1.0]
                    if let gradientImage = createGradientImage(size: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize),
                                                               colors: colors,
                                                               locations: locations) {
                        blockNode.fillTexture = SKTexture(image: gradientImage)
                        blockNode.fillColor = .white
                    } else {
                        blockNode.fillColor = SKColor.from(Color(cgColor: block.gradientColors.start))
                    }
                    // Update shadow
                    if let shadowNode = blockNode.children.first(where: { $0.zPosition == -1 }) as? SKShapeNode {
                        shadowNode.fillColor = UIColor(cgColor: block.shadowColor)
                    }
                }
            }
        }
        // Redraw grid to ensure all elements are updated
        renderGrid(gridNode: gridNode, gameState: gameState, blockSize: GameConstants.blockSize)
    }
    @objc private func handleThemeChange() {
        updateTheme()
    }
    private func cleanupParticleEffects() {
        // Remove old particle emitters
        while activeParticleEmitters.count > maxParticleEmitters {
            if let oldestEmitter = activeParticleEmitters.first {
                oldestEmitter.removeFromParent()
                NodePool.shared.returnParticleEmitter(oldestEmitter)
                activeParticleEmitters.removeFirst()
            }
        }
        // Clean up any finished particle emitters
        activeParticleEmitters = activeParticleEmitters.filter { emitter in
            if emitter.particleBirthRate == 0 && emitter.particleLifetime == 0 {
                emitter.removeFromParent()
                NodePool.shared.returnParticleEmitter(emitter)
                return false
            }
            return true
        }
    }
    private func optimizeParticleEmitter(_ emitter: SKEmitterNode) {
        let fpsManager = FPSManager.shared
        
        // Determine reduction factor based on thermal and battery conditions
        var reductionFactor: CGFloat = 1.0
        
        // Apply thermal state adjustments
        switch fpsManager.thermalState {
        case .critical:
            reductionFactor = 0.2 // Reduce by 80% for critical thermal state
        case .serious:
            reductionFactor = 0.4 // Reduce by 60% for serious thermal state
        case .fair:
            reductionFactor = 0.7 // Reduce by 30% for fair thermal state
        case .nominal:
            reductionFactor = 0.8 // Reduce by 20% for nominal thermal state
        @unknown default:
            reductionFactor = 0.8
        }
        
        // Apply battery level adjustments
        if fpsManager.batteryLevel < 0.1 { // Below 10%
            reductionFactor *= 0.3
        } else if fpsManager.batteryLevel < 0.2 { // Below 20%
            reductionFactor *= 0.5
        } else if fpsManager.batteryLevel < 0.3 { // Below 30%
            reductionFactor *= 0.7
        }
        
        // Apply low power mode adjustment
        if fpsManager.isLowPowerMode {
            reductionFactor *= 0.6
        }
        
        // Apply device-specific adjustments
        let deviceSimulator = DeviceSimulator.shared
        if deviceSimulator.isLowEndDevice() {
            reductionFactor *= 0.7 // Additional reduction for low-end devices
        }
        
        // Apply the reduction factor to particle properties
        emitter.particleBirthRate = min(emitter.particleBirthRate * reductionFactor, 15) // Max 15 particles per second
        emitter.particleLifetime = min(emitter.particleLifetime * reductionFactor, 0.5) // Max 0.5 seconds
        emitter.particleSize = CGSize(
            width: min(emitter.particleSize.width * reductionFactor, 4), // Max 4x4 pixels
            height: min(emitter.particleSize.height * reductionFactor, 4)
        )
        emitter.particleAlpha = min(emitter.particleAlpha * reductionFactor, 0.4) // Max 40% opacity
        emitter.particleSpeed = min(emitter.particleSpeed * reductionFactor, 40) // Max 40 speed
        emitter.particleSpeedRange = min(emitter.particleSpeedRange * reductionFactor, 20) // Max 20 speed range
        emitter.emissionAngleRange = min(emitter.emissionAngleRange * reductionFactor, .pi / 8) // Max pi/8 angle range
        emitter.numParticlesToEmit = min(emitter.numParticlesToEmit, Int(10 * reductionFactor)) // Max 10 particles total
        
        // Log optimization if significant reduction was applied
        if reductionFactor < 0.5 {
            Logger.shared.debug("[Particles] Applied aggressive optimization (factor: \(String(format: "%.2f", reductionFactor))) due to thermal/battery conditions", category: .debugGameScene)
        }
    }
    private func addParticleEffect(at position: CGPoint) {
        let adaptiveQuality = AdaptiveQualityManager.shared
        
        // Check if particles should be enabled
        guard adaptiveQuality.shouldEnableParticles() else {
            return
        }
        
        cleanupParticleEffects()
        guard activeParticleEmitters.count < maxParticleEmitters else { return }
        
        let emitter = NodePool.shared.getParticleEmitter()
        emitter.position = position
        emitter.zPosition = 100
        
        // Optimize particle emitter with quality settings
        optimizeParticleEmitter(emitter)
        
        // Apply quality intensity
        let intensity = adaptiveQuality.getParticleIntensity()
        emitter.particleBirthRate *= intensity
        emitter.particleAlpha *= intensity
        
        addChild(emitter)
        activeParticleEmitters.append(emitter)
        
        let wait = SKAction.wait(forDuration: emitter.particleLifetime + 0.1)
        let remove = SKAction.run { [weak self] in
            emitter.removeFromParent()
            self?.activeParticleEmitters.removeAll { $0 === emitter }
            NodePool.shared.returnParticleEmitter(emitter)
        }
        emitter.run(SKAction.sequence([wait, remove]))
    }
    private func manageCachedNodes() {
        // Limit cache size to 50 nodes
        if cachedNodes.count > 50 {
            // Remove oldest entries
            let excessCount = cachedNodes.count - 50
            let keysToRemove = Array(cachedNodes.keys.prefix(excessCount))
            for key in keysToRemove {
                cachedNodes[key]?.removeFromParent()
                cachedNodes.removeValue(forKey: key)
            }
        }
    }
    private func cacheNode(_ node: SKNode, forKey key: String) {
        manageCachedNodes()
        cachedNodes[key] = node
    }
    private func getCachedNode(forKey key: String) -> SKNode? {
        return cachedNodes[key]
    }
    private func clearNodeCache() {
        cachedNodes.values.forEach { $0.removeFromParent() }
        cachedNodes.removeAll()
    }
    private func optimizeTextures() {
        // Preload and optimize textures
        let textureNames = ["block", "particle", "background"]
        for name in textureNames {
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            texture.usesMipmaps = true
        }
    }
    private func optimizeTexture(_ texture: SKTexture) {
        // Set texture filtering
        texture.filteringMode = .linear
        // Enable mipmapping
        texture.usesMipmaps = true
    }
    private func cleanupResources() async {
        // Clear shared node pools
        NodePool.shared.clearAllPools()
        // Clear texture cache
        clearTextureCache()
        // Clear active nodes
        activeNodes.forEach { cleanupNode($0) }
        activeNodes.removeAll()
        // Clear any remaining nodes
        children.forEach { cleanupNode($0) }
    }
    private func cleanupUnusedNodes() {
        // Remove unused grid nodes
        gridNode.children.forEach { node in
            if !node.isUserInteractionEnabled && node.name?.hasPrefix("block_") == true {
                node.removeFromParent()
            }
        }
        // Remove unused tray nodes
        trayNode.children.forEach { node in
            if !node.isUserInteractionEnabled && node.name?.hasPrefix("tray_") == true {
                node.removeFromParent()
            }
        }
    }
    private func cleanupTextures() async {
        // Remove textures that are no longer in use
        activeTextures.forEach { texture in
            if texture.description.contains("unused") {
                activeTextures.remove(texture)
            }
        }
        // Force texture cleanup
        await SKTextureAtlas.preloadTextureAtlases([])
        await SKTexture.preload([])
    }
    private func clearAllTextures() async {
        activeTextures.removeAll()
        // Force texture cleanup
        await SKTextureAtlas.preloadTextureAtlases([])
        await SKTexture.preload([])
    }
    private func cleanupAudio() {
        // Stop all sounds
        AudioManager.shared.stopBackgroundMusic()
        // Clear sound effects
        AudioManager.shared.cleanupSoundEffects()
    }
    private func cleanupTemporaryData() {
        // Clear temporary nodes
        if let existing = dragNode {
            existing.removeAllActions()
            existing.removeAllChildren()
            existing.removeFromParent()
            dragNode = nil
        }
        if let existing = previewNode {
            existing.removeAllActions()
            existing.removeAllChildren()
            existing.removeFromParent()
            previewNode = nil
        }
        if let existing = hintHighlight {
            existing.removeAllActions()
            existing.removeAllChildren()
            existing.removeFromParent()
            hintHighlight = nil
        }
        // Clear temporary arrays
        blockNodes.removeAll()
        activeParticleEmitters.removeAll()
        // Local pooling functions removed - now using NodePool.shared for all pooling operations
    }
    private func prepareForSceneTransition() async {
        // Stop all animations
        setBackgroundAnimationsActive(false)
        // Remove all particle effects
        cleanupParticleEffects()
        // Clear node cache
        clearNodeCache()
        // Remove unused nodes
        cleanupUnusedNodes()
        // Clear textures
        await clearAllTextures()
        // Clear audio resources
        cleanupAudio()
        // Clear temporary data
        cleanupTemporaryData()
        // Clear any remaining nodes
        autoreleasepool {
            gridNode?.children.forEach { cleanupNode($0) }
            trayNode?.children.forEach { cleanupNode($0) }
        }
    }
    private func reviewAndCleanupLongLivedReferences() {
        Logger.shared.debug("[Memory] Reviewing long-lived references", category: .debugGameScene)
        // Review and cleanup block nodes
        let blockNodesCount = blockNodes.count
        blockNodes = blockNodes.filter { node in
            if node.parent == nil {
                Logger.shared.debug("[Memory] Removing orphaned block node", category: .debugGameScene)
                return false
            }
            return true
        }
        if blockNodes.count != blockNodesCount {
            Logger.shared.debug("[Memory] Removed \(blockNodesCount - blockNodes.count) orphaned block nodes", category: .debugGameScene)
        }
        // Review and cleanup particle emitters
        let emitterCount = activeParticleEmitters.count
        activeParticleEmitters = activeParticleEmitters.filter { emitter in
            if emitter.parent == nil {
                Logger.shared.debug("[Memory] Removing orphaned particle emitter", category: .debugGameScene)
                return false
            }
            return true
        }
        if activeParticleEmitters.count != emitterCount {
            Logger.shared.debug("[Memory] Removed \(emitterCount - activeParticleEmitters.count) orphaned particle emitters", category: .debugGameScene)
        }
        // Review and cleanup cached nodes
        let cachedNodesCount = cachedNodes.count
        cachedNodes = cachedNodes.filter { key, node in
            if node.parent == nil {
                Logger.shared.debug("[Memory] Removing orphaned cached node: \(key)", category: .debugGameScene)
                return false
            }
            return true
        }
        if cachedNodes.count != cachedNodesCount {
            Logger.shared.debug("[Memory] Removed \(cachedNodesCount - cachedNodes.count) orphaned cached nodes", category: .debugGameScene)
        }
        // Review and cleanup temporary nodes
        if let dragNode = dragNode, dragNode.parent == nil {
            Logger.shared.debug("[Memory] Removing orphaned drag node", category: .debugGameScene)
            dragNode.removeAllActions()
            dragNode.removeAllChildren()
            self.dragNode = nil
        }
        if let previewNode = previewNode, previewNode.parent == nil {
            Logger.shared.debug("[Memory] Removing orphaned preview node", category: .debugGameScene)
            previewNode.removeAllActions()
            previewNode.removeAllChildren()
            self.previewNode = nil
        }
        if let hintHighlight = hintHighlight, hintHighlight.parent == nil {
            Logger.shared.debug("[Memory] Removing orphaned hint highlight", category: .debugGameScene)
            hintHighlight.removeAllActions()
            hintHighlight.removeAllChildren()
            self.hintHighlight = nil
        }
    }
    // MARK: - Node Cleanup
    func cleanupNode(_ node: SKNode) {
        if let previewNode = node as? SKShapeNode {
            NodePool.shared.returnPreviewNode(previewNode)
        } else if let highlightNode = node as? SKShapeNode {
            NodePool.shared.returnHighlightNode(highlightNode)
        } else {
            node.removeFromParent()
            untrackNode(node)
        }
    }
    private func createPreviewNode() -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
        node.fillColor = .clear
        node.strokeColor = .white
        node.lineWidth = 2
        node.alpha = 0.5
        trackNode(node)
        return node
    }
    private func createHighlightNode() -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
        node.fillColor = .clear
        node.strokeColor = .yellow
        node.lineWidth = 2
        node.alpha = 0.5
        trackNode(node)
        return node
    }
    private func trackNode(_ node: SKNode) {
        activeNodes.insert(node)
        if activeNodes.count > maxActiveNodes {
            // Remove oldest nodes if we exceed the limit
            let excess = activeNodes.count - maxActiveNodes
            let nodesToRemove = Array(activeNodes.prefix(excess))
            nodesToRemove.forEach { cleanupNode($0) }
        }
    }
    private func untrackNode(_ node: SKNode) {
        activeNodes.remove(node)
    }
    private func loadBlockTexture(for block: Block) -> SKTexture {
        let textureName = "block_\(block.shape.rawValue)_\(block.color.rawValue)"
        return getTexture(named: textureName)
    }
    private func getTexture(named name: String) -> SKTexture {
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        let texture = SKTexture(imageNamed: name)
        if textureCache.count >= maxTextureCacheSize {
            // Remove oldest texture if cache is full
            textureCache.removeValue(forKey: textureCache.keys.first!)
        }
        textureCache[name] = texture
        return texture
    }
    private func clearTextureCache() {
        textureCache.removeAll()
    }
    @objc private func handleGameOverNotification() {
        handleGameOver()
    }
    // MARK: - Placed Block Node Management
    
    func trackPlacedBlockNode(_ node: SKNode, at position: (row: Int, col: Int)) {
        let key = "\(position.row),\(position.col)"
        // Clean up any existing node at this position
        if let existingNode = placedBlockNodes[key] {
            cleanupNode(existingNode)
        }
        placedBlockNodes[key] = node
    }
    
    func cleanupPlacedBlockNodes() {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastCleanupTime >= cleanupInterval else { return }
        
        lastCleanupTime = currentTime
        
        // Clean up orphaned nodes (nodes without parents)
        let orphanedKeys = placedBlockNodes.keys.filter { key in
            guard let node = placedBlockNodes[key] else { return true }
            return node.parent == nil
        }
        
        for key in orphanedKeys {
            if let node = placedBlockNodes[key] {
                cleanupNode(node)
            }
            placedBlockNodes.removeValue(forKey: key)
        }
        
        // Limit the number of tracked nodes to prevent memory buildup
        if placedBlockNodes.count > 200 { // Max 200 placed block nodes
            let excessCount = placedBlockNodes.count - 200
            let keysToRemove = Array(placedBlockNodes.keys.prefix(excessCount))
            for key in keysToRemove {
                if let node = placedBlockNodes[key] {
                    cleanupNode(node)
                }
                placedBlockNodes.removeValue(forKey: key)
            }
        }
    }
    
    private func clearAllPlacedBlockNodes() {
        placedBlockNodes.values.forEach { cleanupNode($0) }
        placedBlockNodes.removeAll()
    }
    
    func cleanupTexturesAndPreventArtifacts() {
        // Clear gradient texture cache if it's getting too large
        if gradientTextureCache.count > maxGradientCacheSize / 2 {
            print("[DEBUG] Clearing gradient texture cache to prevent artifacts")
            gradientTextureCache.removeAll()
        }
        
        // Clear any corrupted or unused textures
        activeTextures = activeTextures.filter { texture in
            // Remove textures that might be corrupted
            if texture.description.contains("nil") || texture.description.contains("invalid") {
                print("[DEBUG] Removing potentially corrupted texture")
                return false
            }
            return true
        }
    }
    
    // MARK: - Thermal State Monitoring
    
    private func startThermalStateMonitoring() {
        // Check thermal state every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAndAdjustForThermalState()
        }
        
        // Observe quality settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQualitySettingsChange),
            name: .qualitySettingsDidChange,
            object: nil
        )
    }
    
    @objc private func handleQualitySettingsChange(_ notification: Notification) {
        guard let settings = notification.userInfo?["settings"] as? AdaptiveQualityManager.QualitySettings else { return }
        
        // Apply quality settings
        applyAdaptiveQualitySettings(settings)
    }
    
    private func applyAdaptiveQualitySettings(_ settings: AdaptiveQualityManager.QualitySettings) {
        // Update FPS
        if let view = self.view {
            let fpsManager = FPSManager.shared
            let thermalAwareFPS = min(settings.maxFPS, fpsManager.getThermalAwareFPS())
            view.preferredFramesPerSecond = thermalAwareFPS
            
            Logger.shared.debug("[Quality] Applied quality settings: \(settings.maxFPS) FPS, particles: \(settings.enableParticles), animations: \(settings.enableBackgroundAnimations)", category: .debugGameScene)
        }
        
        // Update background animations
        setBackgroundAnimationsActive(settings.enableBackgroundAnimations)
        
        // Update particle effects
        updateParticleEffectsForQuality(settings)
    }
    
    private func updateParticleEffectsForQuality(_ settings: AdaptiveQualityManager.QualitySettings) {
        // Disable all particle effects if particles are disabled
        if !settings.enableParticles {
            cleanupParticleEffects()
            return
        }
        
        // Update existing particle emitters with new intensity
        activeParticleEmitters.forEach { emitter in
            emitter.particleBirthRate *= settings.particleIntensity
            emitter.particleAlpha *= settings.particleIntensity
        }
    }
    
    private func checkAndAdjustForThermalState() {
        let fpsManager = FPSManager.shared
        
        // Check if performance should be reduced
        if fpsManager.shouldReducePerformance {
            // Adjust FPS if needed
            if let view = self.view {
                let thermalAwareFPS = fpsManager.getThermalAwareFPS()
                if view.preferredFramesPerSecond != thermalAwareFPS {
                    view.preferredFramesPerSecond = thermalAwareFPS
                    Logger.shared.debug("[Thermal] Adjusted FPS to \(thermalAwareFPS) due to thermal/battery conditions", category: .debugGameScene)
                }
            }
            
            // Pause background animations if needed
            setBackgroundAnimationsActive(true)
            
            // Log thermal state if it's serious or critical
            if fpsManager.thermalState == .serious || fpsManager.thermalState == .critical {
                Logger.shared.debug("[Thermal] High thermal state detected: \(fpsManager.thermalState). Performance reduced.", category: .debugGameScene)
            }
            
            // Log battery conditions if low
            if fpsManager.batteryLevel < 0.2 {
                Logger.shared.debug("[Battery] Low battery detected: \(Int(fpsManager.batteryLevel * 100))%. Performance reduced.", category: .debugGameScene)
            }
        } else {
            // Restore normal performance if conditions have improved
            if let view = self.view {
                let normalFPS = fpsManager.getDisplayFPS(for: fpsManager.targetFPS)
                if view.preferredFramesPerSecond != normalFPS {
                    view.preferredFramesPerSecond = normalFPS
                    Logger.shared.debug("[Thermal] Restored FPS to \(normalFPS) - thermal/battery conditions improved", category: .debugGameScene)
                }
            }
            
            // Resume background animations
            setBackgroundAnimationsActive(true)
        }
    }
}
