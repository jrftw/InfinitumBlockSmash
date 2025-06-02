import SpriteKit
import GameplayKit
import AudioToolbox
import SwiftUI

class GameScene: SKScene, SKPhysicsContactDelegate {
    var gameState: GameState!
    private var gridNode: SKNode!
    private var trayNode: SKNode!
    private var draggingBlock: Block?
    private var dragNode: SKNode?
    
    // Visual effects
    private var particleEmitter: SKEmitterNode?
    private var glowNode: SKNode?
    
    override func didMove(to view: SKView) {
        // Configure view for better performance
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.allowsTransparency = true
        
        setupScene()
        setupGrid()
        setupTray()
        setupUI()
        setupParticles()
        // Set delegate if not already set
        if gameState.delegate !== self {
            gameState.delegate = self
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
    }
    
    private func setupGrid() {
        let blockSize = GameConstants.blockSize
        let gridSize = GameConstants.gridSize
        
        // Calculate total grid size
        let totalWidth = CGFloat(gridSize) * blockSize
        let totalHeight = CGFloat(gridSize) * blockSize
        
        // Calculate center position
        let centerX = frame.midX - totalWidth / 2
        let centerY = frame.midY - totalHeight / 2
        
        // Create grid background
        let gridBackground = SKShapeNode(rectOf: CGSize(width: totalWidth, height: totalHeight))
        gridBackground.fillColor = .black
        gridBackground.alpha = 0.3
        gridBackground.position = CGPoint(x: centerX + totalWidth / 2, y: centerY + totalHeight / 2)
        gridBackground.zPosition = -1
        addChild(gridBackground)
        
        // Draw grid lines
        for i in 0...gridSize {
            let x = centerX + CGFloat(i) * blockSize
            let y = centerY + CGFloat(i) * blockSize
            
            // Vertical line
            let verticalLine = SKShapeNode(rectOf: CGSize(width: 1, height: totalHeight))
            verticalLine.fillColor = .white
            verticalLine.alpha = 0.2
            verticalLine.position = CGPoint(x: x, y: centerY + totalHeight / 2)
            addChild(verticalLine)
            
            // Horizontal line
            let horizontalLine = SKShapeNode(rectOf: CGSize(width: totalWidth, height: 1))
            horizontalLine.fillColor = .white
            horizontalLine.alpha = 0.2
            horizontalLine.position = CGPoint(x: centerX + totalWidth / 2, y: y)
            addChild(horizontalLine)
        }
        
        // Ensure gridNode is initialized
        if gridNode == nil {
            gridNode = SKNode()
            gridNode.position = CGPoint(x: frame.midX, y: frame.midY)
            addChild(gridNode)
        }
    }
    
    private func setupTray() {
        let blockSize = GameConstants.blockSize
        let trayHeight = blockSize * 1.5
        let trayWidth = frame.width * 0.8
        
        // Create tray background
        let trayBackground = SKShapeNode(rectOf: CGSize(width: trayWidth, height: trayHeight))
        trayBackground.fillColor = .black
        trayBackground.alpha = 0.3
        // Move tray higher (about 22% of the screen height)
        let trayY = frame.height * 0.22
        trayBackground.position = CGPoint(x: frame.midX, y: trayY)
        trayBackground.zPosition = -1
        addChild(trayBackground)
        
        trayNode = SKNode()
        trayNode.position = CGPoint(x: frame.midX, y: trayY)
        addChild(trayNode)
        
        updateTray()
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
        
        for (dx, dy) in block.shape.cells {
            let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
            
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
            
            cellNode.addChild(shadowNode)
            cellNode.addChild(gradientNode)
            gradientNode.addChild(shineNode)
            
            cellNode.position = CGPoint(x: CGFloat(dx) * blockSize, y: CGFloat(dy) * blockSize)
            blockNode.addChild(cellNode)
        }
        
        return blockNode
    }
    
    private func createGradientImage(size: CGSize, colors: [CGColor], locations: [CGFloat]) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
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
        UIGraphicsEndImageContext()
        return image
    }
    
    private func updateTray() {
        trayNode.removeAllChildren()
        
        let blockSize = GameConstants.blockSize
        let spacing: CGFloat = 32 // Slightly more spacing for 3 shapes
        var currentX: CGFloat = 0
        
        // Calculate total width needed for all shapes
        var totalWidth: CGFloat = 0
        for block in gameState.tray {
            let shapeWidth = CGFloat(block.shape.cells.map { $0.0 }.max()! + 1) * blockSize
            totalWidth += shapeWidth + spacing;
        }
        totalWidth -= spacing // Remove last spacing
        
        // Start position to center the tray
        currentX = -totalWidth / 2
        
        for block in gameState.tray {
            let shapeWidth = CGFloat(block.shape.cells.map { $0.0 }.max()! + 1) * blockSize
            let blockNode = SKNode()
            blockNode.name = "tray_\(block.id.uuidString)"
            // Draw each cell of the block
            for (dx, dy) in block.shape.cells {
                let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
                // Gradient fill
                let colors = [block.color.gradientColors.start, block.color.gradientColors.end]
                let locations: [CGFloat] = [0.0, 1.0]
                if let gradientImage = createGradientImage(size: CGSize(width: blockSize, height: blockSize), colors: colors, locations: locations) {
                    cellNode.fillTexture = SKTexture(image: gradientImage)
                    cellNode.fillColor = .white
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
                cellNode.lineWidth = 1
                // Shine
                let shineNode = SKShapeNode(rectOf: CGSize(width: blockSize * 0.3, height: blockSize * 0.3))
                shineNode.fillColor = .white
                shineNode.alpha = 0.3
                shineNode.position = CGPoint(x: -blockSize * 0.25, y: blockSize * 0.25)
                shineNode.zRotation = .pi / 4
                cellNode.addChild(shineNode)
                // Position cell
                cellNode.position = CGPoint(x: CGFloat(dx) * blockSize, y: CGFloat(dy) * blockSize)
                blockNode.addChild(cellNode)
            }
            // Center the block shape vertically in the tray
            blockNode.position = CGPoint(x: currentX + shapeWidth / 2, y: 0)
            trayNode.addChild(blockNode)
            currentX += shapeWidth + spacing
        }
        animateTrayRefill()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: trayNode)
        if let node = trayNode.nodes(at: location).first(where: { $0.name?.starts(with: "tray_") == true }),
           let blockId = node.name?.split(separator: "_").last,
           let block = gameState.tray.first(where: { $0.id.uuidString == blockId }) {
            draggingBlock = block
            dragNode = createBlockNode(for: block)
            dragNode?.position = touch.location(in: self)
            dragNode?.alpha = 0.7
            addChild(dragNode!)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let dragNode = dragNode else { return }
        dragNode.position = touch.location(in: self)
        
        // Update preview validity
        let gridLocation = convertToGridCoordinates(touch.location(in: gridNode))
        let isValid = gameState.canPlaceBlock(draggingBlock!, at: gridLocation)
        dragNode.alpha = isValid ? 0.7 : 0.3
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let draggingBlock = draggingBlock else { return }
        let gridLocation = convertToGridCoordinates(touch.location(in: gridNode))
        
        if gameState.tryPlaceBlockFromTray(draggingBlock, at: gridLocation) {
            playPlacementAnimation(at: gridLocation)
            renderGrid()
        }
        
        dragNode?.removeFromParent()
        dragNode = nil
        self.draggingBlock = nil
    }
    
    private func convertToGridCoordinates(_ point: CGPoint) -> CGPoint {
        let cellSize = GameConstants.blockSize
        let col = Int((point.x + CGFloat(GameConstants.gridSize) * cellSize/2) / cellSize)
        let row = Int((point.y + CGFloat(GameConstants.gridSize) * cellSize/2) / cellSize)
        return CGPoint(x: col, y: row)
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
    private func renderGrid() {
        guard let gridNode = gridNode else { return }
        // Remove all previous placed block nodes (but not grid lines)
        gridNode.removeAllChildren()
        // Draw all placed blocks
        let blockSize = GameConstants.blockSize
        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                if let block = gameState.grid[row][col] {
                    let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
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
                    cellNode.lineWidth = 1
                    // Shine
                    let shineNode = SKShapeNode(rectOf: CGSize(width: blockSize * 0.3, height: blockSize * 0.3))
                    shineNode.fillColor = .white
                    shineNode.alpha = 0.3
                    shineNode.position = CGPoint(x: -blockSize * 0.25, y: blockSize * 0.25)
                    shineNode.zRotation = .pi / 4
                    cellNode.addChild(shineNode)
                    // Position cell in the grid
                    cellNode.position = CGPoint(
                        x: CGFloat(col) * blockSize - CGFloat(GameConstants.gridSize) * blockSize / 2 + blockSize / 2,
                        y: CGFloat(row) * blockSize - CGFloat(GameConstants.gridSize) * blockSize / 2 + blockSize / 2
                    )
                    gridNode.addChild(cellNode)
                }
            }
        }
    }
}

extension GameScene: GameStateDelegate {
    func gameStateDidUpdate() {
        updateTray()
        renderGrid()
    }
    
    func gameStateDidClearLines(at positions: [(Int, Int)]) {
        let points = positions.map { CGPoint(x: $0.1, y: $0.0) }
        playComboAnimation(at: points)
        renderGrid()
    }
}

extension SKColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    static func from(_ color: Color) -> SKColor {
        #if os(iOS)
        if let cgColor = color.cgColor {
            return SKColor(cgColor: cgColor)
        }
        #endif
        return SKColor.white
    }
} 