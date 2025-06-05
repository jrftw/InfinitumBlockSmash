import SpriteKit
import GameplayKit
import AudioToolbox
import SwiftUI

class GameScene: SKScene, SKPhysicsContactDelegate {
    var gameState: GameState!
    private var gridNode: SKNode!
    private var trayNode: TrayNode!
    private var draggingBlock: Block?
    private var dragNode: SKNode?
    private var previewNode: SKNode?
    private var lastPlacementTime: TimeInterval = 0
    private let placementDebounceInterval: TimeInterval = 0.3 // 300ms debounce
    
    // Visual effects
    private var particleEmitter: SKEmitterNode?
    private var glowNode: SKNode?
    
    // MARK: - Properties
    private var blockNodes: [SKNode] = []
    private var scoreLabel: SKLabelNode?
    private var levelLabel: SKLabelNode?
    private var memoryWarningLabel: SKLabelNode?
    private var lastMemoryCheck: TimeInterval = 0
    private let memoryCheckInterval: TimeInterval = 5.0 // Check every 5 seconds
    
    // MARK: - Initialization
    init(size: CGSize, gameState: GameState) {
        self.gameState = gameState
        super.init(size: size)
        print("[DEBUG] GameScene init(size:) called")
        setupScene()
        
        // Set up memory critical notification handler
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: .memoryCritical,
            object: nil
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        print("[DEBUG] GameScene init(coder:) called")
    }
    
    override func didMove(to view: SKView) {
        print("[DEBUG] didMove(to:) called")
        guard gameState != nil else {
            print("[ERROR] GameState not initialized")
            return
        }
        
        if gridNode == nil {
            print("[DEBUG] Creating new gridNode")
            gridNode = SKNode()
            addChild(gridNode)
        }
        if trayNode == nil {
            print("[DEBUG] Creating new trayNode")
            let blockSize = GameConstants.blockSize
            let trayHeight = blockSize * 4.5
            let trayWidth = frame.width * 0.92
            trayNode = TrayNode(trayHeight: trayHeight, trayWidth: trayWidth)
            addChild(trayNode)
        }
        
        // Configure view for better performance
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.allowsTransparency = true
        
        // Set the frame size in GameState
        gameState.frameSize = size
        
        // Setup scene components
        setupScene()
        setupGrid()
        setupTray()
        setupUI()
        setupParticles()
        
        // Set delegate if not already set
        if gameState.delegate !== self {
            print("[DEBUG] Setting GameState delegate")
            gameState.delegate = self
        }
        
        print("[DEBUG] Scene setup complete. trayNode in parent: \(trayNode.parent != nil)")
    }
    
    deinit {
        print("[DEBUG] GameScene deinit called")
        // Cleanup
        gridNode?.removeFromParent()
        trayNode?.removeFromParent()
        particleEmitter?.removeFromParent()
        glowNode?.removeFromParent()
        // Clear any cached images
        autoreleasepool {
            gridNode = nil
            trayNode = nil
            particleEmitter = nil
            glowNode = nil
        }
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
        
        // Start memory monitoring
        startMemoryMonitoring()
    }
    
    private func setupGrid() {
        let blockSize = GameConstants.blockSize
        let gridSize = GameConstants.gridSize
        
        // Calculate total grid size
        let totalWidth = CGFloat(gridSize) * blockSize
        let totalHeight = CGFloat(gridSize) * blockSize
        
        // Center the grid in the frame
        gridNode.position = CGPoint(x: frame.midX, y: frame.midY)
        gridNode.zPosition = 0 // Set base z-position for grid
        print("[DEBUG] GridNode position: \(gridNode.position), totalWidth: \(totalWidth), totalHeight: \(totalHeight), frame: \(frame)")
        gridNode.removeAllChildren()
        
        // Create grid background with a slight padding
        let padding: CGFloat = 2
        let gridBackground = SKShapeNode(rectOf: CGSize(width: totalWidth + padding, height: totalHeight + padding))
        gridBackground.fillColor = .black
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
            debugBorder.strokeColor = .red
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
            verticalLine.fillColor = .white
            verticalLine.alpha = 0.2
            verticalLine.position = CGPoint(x: x, y: 0)
            verticalLine.zPosition = 2
            verticalLine.name = "gridLine"
            gridNode.addChild(verticalLine)
            // Horizontal line
            let horizontalLine = SKShapeNode(rectOf: CGSize(width: totalWidth, height: 1))
            horizontalLine.fillColor = .white
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
    
    private func setupTray() {
        let blockSize = GameConstants.blockSize
        let trayHeight = blockSize * 4.5
        trayNode.position = CGPoint(x: frame.midX, y: frame.midY - CGFloat(GameConstants.gridSize) * blockSize / 2 - trayHeight / 2 - blockSize * 1.2)
        trayNode.zPosition = 10
        trayNode.updateBlocks(gameState.tray, blockSize: blockSize)
    }
    
    private func setupUI() {
        // No-op: Score/level handled by SwiftUI overlay
    }
    
    private func setupParticles() {
        if let particles = SKEmitterNode(fileNamed: "BackgroundParticles") {
            particles.position = CGPoint(x: size.width/2, y: size.height/2)
            particles.zPosition = -1
            addChild(particles)
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
        let blockSize = GameConstants.blockSize
        let blockNode = SKNode()
        
        // Reuse existing nodes if possible
        if let existingNode = blockNodes.first(where: { $0.parent == nil }) {
            existingNode.removeAllChildren()
            blockNode.addChild(existingNode)
        }
        
        for (dx, dy) in block.shape.cells {
            let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
            
            // Create gradient fill
            let gradientNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
            gradientNode.fillColor = .clear
            gradientNode.strokeColor = .clear
            
            // Add gradient effect
            let colors = [block.color.gradientColors.start, block.color.gradientColors.end]
            let locations: [CGFloat] = [0.0, 1.0]
            
            if let gradientImage = createGradientImage(size: CGSize(width: blockSize, height: blockSize), colors: colors, locations: locations) {
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
            
            cellNode.addChild(shadowNode)
            cellNode.addChild(gradientNode)
            gradientNode.addChild(shineNode)
            
            cellNode.position = CGPoint(x: CGFloat(dx) * blockSize, y: CGFloat(dy) * blockSize)
            blockNode.addChild(cellNode)
        }
        
        blockNodes.append(blockNode)
        return blockNode
    }
    
    private func createGradientImage(size: CGSize, colors: [CGColor], locations: [CGFloat]) -> UIImage? {
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
        
        return UIGraphicsGetImageFromCurrentImageContext()
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
        if let node = nodesAtPoint.first(where: { $0.name?.starts(with: "trayShape_") == true }),
           let blockIdString = node.name?.replacingOccurrences(of: "trayShape_", with: ""),
           let block = gameState.tray.first(where: { $0.id.uuidString == blockIdString }) {
            draggingBlock = block
            // Create drag node at full grid size
            dragNode = ShapeNode(block: block, blockSize: GameConstants.blockSize)
            let touchLocation = touch.location(in: self)
            let blockDragOffset = UserDefaults.standard.double(forKey: "blockDragOffset")
            dragNode?.position = CGPoint(x: touchLocation.x, y: touchLocation.y + GameConstants.blockSize * blockDragOffset)
            dragNode?.alpha = 0.7
            dragNode?.zPosition = 50
            addChild(dragNode!)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let dragNode = dragNode,
              let draggingBlock = draggingBlock else { return }
        
        let touchPoint = touch.location(in: self)
        let gridPoint = convertToGridCoordinates(touchPoint)
        
        // Update drag node position to follow touch more precisely
        let blockDragOffset = UserDefaults.standard.double(forKey: "blockDragOffset")
        dragNode.position = CGPoint(x: touchPoint.x, y: touchPoint.y + GameConstants.blockSize * blockDragOffset)
        
        // Remove any existing preview
        previewNode?.removeFromParent()
        previewNode = nil
        
        // Only show preview if placement is valid
        if gameState.canPlaceBlock(draggingBlock, at: gridPoint) {
            // Create preview node for the entire shape
            let preview = SKNode()
            preview.zPosition = 1 // Set preview z-position just above grid
            
            // Create preview for each cell in the shape
            for (dx, dy) in draggingBlock.shape.cells {
                let cellNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
                cellNode.fillColor = SKColor.from(draggingBlock.color.color)
                cellNode.strokeColor = .clear
                cellNode.alpha = 0.5
                
                // Position each cell relative to the shape's anchor point
                cellNode.position = CGPoint(
                    x: CGFloat(dx) * GameConstants.blockSize,
                    y: CGFloat(dy) * GameConstants.blockSize
                )
                preview.addChild(cellNode)
            }
            
            // Calculate the preview position relative to the grid
            let blockSize = GameConstants.blockSize
            let gridSize = GameConstants.gridSize
            let totalWidth = CGFloat(gridSize) * blockSize
            let totalHeight = CGFloat(gridSize) * blockSize
            
            // Position the entire preview at the grid position with precise alignment
            let previewPosition = CGPoint(
                x: -totalWidth / 2 + CGFloat(gridPoint.x) * blockSize + blockSize / 2,
                y: -totalHeight / 2 + CGFloat(gridPoint.y) * blockSize + blockSize / 2
            )
            preview.position = previewPosition
            
            // Add preview to grid node
            gridNode.addChild(preview)
            previewNode = preview
            
            // Make dragged shape more transparent
            dragNode.alpha = 0.7
        } else {
            // Make dragged shape more opaque when placement is invalid
            dragNode.alpha = 1.0
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let dragNode = dragNode,
              let draggingBlock = draggingBlock else { return }
        
        // Check if enough time has passed since last placement
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastPlacementTime >= placementDebounceInterval else {
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
        
        // Try to place the block
        if gameState.tryPlaceBlockFromTray(draggingBlock, at: gridPoint) {
            // Update last placement time
            lastPlacementTime = currentTime
            // Play placement sound
            run(SKAction.playSoundFileNamed("place.mp3", waitForCompletion: false))
        } else {
            // Play error sound
            run(SKAction.playSoundFileNamed("error.mp3", waitForCompletion: false))
        }
        
        // Clean up
        dragNode.removeFromParent()
        previewNode?.removeFromParent()
        self.dragNode = nil
        self.draggingBlock = nil
        self.previewNode = nil
    }
    
    private func convertToGridCoordinates(_ point: CGPoint) -> CGPoint {
        // Calculate the grid cell size
        let cellSize = GameConstants.blockSize
        let gridSize = GameConstants.gridSize
        
        // Calculate the grid's origin (top-left corner)
        let gridOrigin = CGPoint(
            x: frame.midX - (CGFloat(gridSize) * cellSize) / 2,
            y: frame.midY - (CGFloat(gridSize) * cellSize) / 2
        )
        
        // Calculate the relative position within the grid
        let relativeX = point.x - gridOrigin.x
        let relativeY = point.y - gridOrigin.y
        
        // Calculate the exact grid position without any snapping
        let exactCol = relativeX / cellSize
        let exactRow = relativeY / cellSize
        
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
            x: max(0, min(gridSize - 1, finalCol)),
            y: max(0, min(gridSize - 1, finalRow))
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
        AudioManager.shared.playSound("placement")
        playHaptic(style: .medium)
    }

    private func playComboAnimation(at positions: [CGPoint]) {
        for pos in positions {
            if let particles = SKEmitterNode(fileNamed: "ClearParticles") {
                particles.position = CGPoint(
                    x: CGFloat(pos.x) * GameConstants.blockSize - CGFloat(GameConstants.gridSize) * GameConstants.blockSize/2,
                    y: CGFloat(pos.y) * GameConstants.blockSize - CGFloat(GameConstants.gridSize) * GameConstants.blockSize/2
                )
                gridNode.addChild(particles)
                let wait = SKAction.wait(forDuration: 0.7)
                let remove = SKAction.removeFromParent()
                particles.run(SKAction.sequence([wait, remove]))
            }
        }
        AudioManager.shared.playSound("combo")
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
    private func startMemoryMonitoring() {
        // Check memory usage periodically
        let checkMemory = SKAction.run { [weak self] in
            self?.checkMemoryUsage()
        }
        let wait = SKAction.wait(forDuration: memoryCheckInterval)
        let sequence = SKAction.sequence([checkMemory, wait])
        run(SKAction.repeatForever(sequence), withKey: "memoryMonitoring")
    }
    
    private func checkMemoryUsage() {
        let status = MemoryMonitor.shared.checkMemoryUsage()
        switch status {
        case .critical:
            handleCriticalMemory()
        case .warning:
            handleMemoryWarning()
        case .normal:
            hideMemoryWarning()
        }
    }
    
    @objc private func handleMemoryWarning() {
        // Show warning
        memoryWarningLabel?.text = "⚠️ High Memory Usage"
        memoryWarningLabel?.isHidden = false
        
        // Clear any cached resources
        removeAllActions()
        removeAllChildren()
        
        // Reload essential game elements
        setupScene()
        setupGrid()
        setupTray()
        setupUI()
        setupParticles()
        
        // Notify the game state to clean up any cached data
        gameState.cleanupMemory()
        
        // Log memory usage
        MemoryMonitor.shared.logMemoryUsage()
    }
    
    private func handleCriticalMemory() {
        // Show warning
        memoryWarningLabel?.text = "⚠️ Memory Critical"
        memoryWarningLabel?.isHidden = false
        
        // Force cleanup
        handleMemoryWarning()
        
        // Notify user
        NotificationCenter.default.post(name: .memoryCritical, object: nil)
    }
    
    private func hideMemoryWarning() {
        memoryWarningLabel?.isHidden = true
    }
    
    private func cleanupMemory() {
        // Remove unused nodes
        blockNodes.removeAll(where: { $0.parent == nil })
        
        // Clear any cached textures
        SKTexture.preload([]) { [weak self] in
            self?.removeAllActions()
        }
        
        // Clear any cached images
        UIGraphicsEndImageContext()
        
        // Log memory usage
        MemoryMonitor.shared.logMemoryUsage()
    }
}

extension GameScene: GameStateDelegate {
    func gameStateDidUpdate() {
        print("[DEBUG] gameStateDidUpdate called")
        print("[DEBUG] trayNode in parent before update: \(trayNode.parent != nil)")
        
        // Update tray
        setupTray()
        
        // Update grid
        let blockSize = GameConstants.blockSize
        let gridSize = GameConstants.gridSize
        let totalWidth = CGFloat(gridSize) * blockSize
        let totalHeight = CGFloat(gridSize) * blockSize
        
        // Find or create block container
        var blockContainer = gridNode.childNode(withName: "blockContainer")
        if blockContainer == nil {
            blockContainer = SKNode()
            blockContainer?.name = "blockContainer"
            blockContainer?.zPosition = 1
            gridNode.addChild(blockContainer!)
        }
        
        // Remove existing blocks
        blockContainer?.removeAllChildren()
        
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
                    blockContainer?.addChild(cellNode)
                }
            }
        }
        
        print("[DEBUG] trayNode in parent after update: \(trayNode.parent != nil)")
        
        // Refill tray if needed (after UI update)
        if gameState.tray.count < 3 {
            gameState.refillTray()
        }
    }
    
    func gameStateDidClearLines(at positions: [(Int, Int)]) {
        let points = positions.map { CGPoint(x: $0.1, y: $0.0) }
        playComboAnimation(at: points)
        gameStateDidUpdate() // Use the same update logic
    }
    
    func showScoreAnimation(points: Int, at position: CGPoint) {
        // Create a label node for the score animation
        let scoreLabel = SKLabelNode(text: "+\(points)")
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.position = position
        scoreLabel.zPosition = 100
        scoreLabel.alpha = 0
        
        // Add the label to the scene
        addChild(scoreLabel)
        
        // Create the animation sequence
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let moveUp = SKAction.moveBy(x: 0, y: 50, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        // Combine the actions
        let sequence = SKAction.sequence([
            fadeIn,
            moveUp,
            fadeOut,
            remove
        ])
        
        // Run the animation
        scoreLabel.run(sequence)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let memoryCritical = Notification.Name("memoryCritical")
} 