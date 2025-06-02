private func updateTray() {
    trayNode.removeAllChildren()
    
    let blockSize = GameConstants.blockSize
    let spacing: CGFloat = 40 // Increased spacing for better visibility
    var currentX: CGFloat = 0
    
    // Calculate total width needed for all shapes
    var totalWidth: CGFloat = 0
    for block in gameState.tray {
        let shapeWidth = CGFloat(block.shape.cells.map { $0.0 }.max()! + 1) * blockSize
        totalWidth += shapeWidth + spacing
    }
    totalWidth -= spacing // Remove last spacing
    
    // Start position to center the tray
    currentX = -totalWidth / 2
    
    // Create a container node for better performance
    let containerNode = SKNode()
    containerNode.zPosition = 1
    
    for (index, block) in gameState.tray.enumerated() {
        let shapeWidth = CGFloat(block.shape.cells.map { $0.0 }.max()! + 1) * blockSize
        let blockNode = SKNode()
        blockNode.name = "tray_\(block.id.uuidString)"
        blockNode.zPosition = CGFloat(index) // Set zPosition based on index to prevent overlapping
        
        // Draw each cell of the block
        for (dx, dy) in block.shape.cells {
            let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
            cellNode.position = CGPoint(x: CGFloat(dx) * blockSize, y: CGFloat(dy) * blockSize)
            
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
        
        blockNode.position = CGPoint(x: currentX + shapeWidth/2, y: 0)
        containerNode.addChild(blockNode)
        currentX += shapeWidth + spacing
    }
    
    trayNode.addChild(containerNode)
}

private func playComboAnimation(at positions: [CGPoint]) {
    // Create a container node for better performance
    let containerNode = SKNode()
    containerNode.zPosition = 2
    
    for pos in positions {
        if let particles = SKEmitterNode(fileNamed: "ClearParticles") {
            particles.position = CGPoint(
                x: CGFloat(pos.x) * GameConstants.blockSize - CGFloat(GameConstants.gridSize) * GameConstants.blockSize/2,
                y: CGFloat(pos.y) * GameConstants.blockSize - CGFloat(GameConstants.gridSize) * GameConstants.blockSize/2
            )
            containerNode.addChild(particles)
        }
    }
    
    gridNode.addChild(containerNode)
    
    let wait = SKAction.wait(forDuration: 0.7)
    let remove = SKAction.removeFromParent()
    containerNode.run(SKAction.sequence([wait, remove]))
    
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
    // Remove only the placed block nodes, not the grid lines or background
    for node in gridNode.children {
        if node.name != "gridLine" && node.name != "gridBackground" {
            node.removeFromParent()
        }
    }
    
    // Create a container node for better performance
    let containerNode = SKNode()
    containerNode.zPosition = 1
    
    // Draw all placed blocks
    for row in 0..<GameConstants.gridSize {
        for col in 0..<GameConstants.gridSize {
            if let block = gameState.grid[row][col] {
                let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
                cellNode.name = "placedBlock"
                cellNode.position = CGPoint(x: CGFloat(col) * blockSize, y: CGFloat(row) * blockSize)
                
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
                
                containerNode.addChild(cellNode)
            }
        }
    }
    
    gridNode.addChild(containerNode)
} 