/*
 * GameSceneEXT.swift
 * 
 * EXTENSIONS FOR GAMESCENE
 * 
 * This file contains all extensions for the GameScene class, including:
 * - GameStateDelegate implementation
 * - Notification.Name extensions
 * 
 * These extensions were moved from GameScene.swift to improve code organization
 * and maintainability.
 */

import SpriteKit
import Foundation

// MARK: - GameStateDelegate Extension
extension GameScene: GameStateDelegate {
    func gameStateDidUpdate() {
        Logger.shared.debug("gameStateDidUpdate called", category: .debugGameScene)
        
        // Clean up placed block nodes periodically
        cleanupPlacedBlockNodes()
        
        // Update tray
        setupTray()
        
        // Use incremental grid update instead of complete redraw
        updateGridIncrementally()
    }
    
    private func updateGridIncrementally() {
        guard let gameState = gameState else { return }
        
        let gridSize = GameConstants.gridSize
        
        // Update only changed positions instead of redrawing entire grid
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let key = "\(row),\(col)"
                let currentColor = gameState.grid[row][col]
                
                if let existingNode = placedBlockNodes[key] {
                    // Node exists, check if it needs updating
                    if currentColor == nil {
                        // Position is now empty, remove the node
                        cleanupNode(existingNode)
                        placedBlockNodes.removeValue(forKey: key)
                    } else {
                        // Position has a block, update if color changed
                        if let cellNode = existingNode.children.first as? SKShapeNode,
                           let gradientNode = cellNode.children.first as? SKShapeNode {
                            if let currentColor = currentColor {
                                let newColor = SKColor.from(currentColor.color)
                                if gradientNode.fillColor != newColor {
                                    updateBlockNodeColor(existingNode, to: currentColor)
                                }
                            }
                        }
                    }
                } else if currentColor != nil {
                    // No node exists but position has a block, create new node
                    let cellNode = createBlockNode(for: currentColor!, at: (row: row, col: col))
                    trackPlacedBlockNode(cellNode, at: (row: row, col: col))
                    gridNode.addChild(cellNode)
                }
            }
        }
    }
    
    private func createBlockNode(for color: BlockColor, at position: (row: Int, col: Int)) -> SKNode {
        let cellNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
        
        // Create gradient fill
        let gradientNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
        gradientNode.fillColor = .clear
        gradientNode.strokeColor = .clear
        
        // Use cached gradient texture if available
        if let cachedTexture = getCachedGradientTexture(for: color) {
            gradientNode.fillTexture = cachedTexture
            gradientNode.fillColor = .white
        } else {
            // Create new gradient texture and cache it
            let colors = [color.gradientColors.start, color.gradientColors.end]
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradientImage = createGradientImage(size: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize),
                                                     colors: colors,
                                                     locations: locations) {
                let texture = SKTexture(image: gradientImage)
                gradientNode.fillTexture = texture
                gradientNode.fillColor = .white
                cacheGradientTexture(texture, for: color)
            }
        }
        
        // Add shadow effect
        let shadowNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize))
        shadowNode.fillColor = UIColor(cgColor: color.shadowColor)
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
        
        // Position the block
        let totalWidth = CGFloat(GameConstants.gridSize) * GameConstants.blockSize
        let totalHeight = CGFloat(GameConstants.gridSize) * GameConstants.blockSize
        let xOffset = -totalWidth / 2 + CGFloat(position.col) * GameConstants.blockSize + GameConstants.blockSize / 2
        let yOffset = -totalHeight / 2 + CGFloat(position.row) * GameConstants.blockSize + GameConstants.blockSize / 2
        cellNode.position = CGPoint(x: xOffset, y: yOffset)
        
        cellNode.name = "placedBlock"
        cellNode.zPosition = 1
        
        return cellNode
    }
    
    private func updateBlockNodeColor(_ node: SKNode, to color: BlockColor) {
        guard let cellNode = node.children.first as? SKShapeNode,
              let gradientNode = cellNode.children.first as? SKShapeNode else { return }
        
        // Update gradient texture
        let colors = [color.gradientColors.start, color.gradientColors.end]
        let locations: [CGFloat] = [0.0, 1.0]
        if let gradientImage = createGradientImage(size: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize),
                                                 colors: colors,
                                                 locations: locations) {
            gradientNode.fillTexture = SKTexture(image: gradientImage)
        }
        
        // Update shadow color
        if let shadowNode = cellNode.children.first(where: { $0.zPosition == -1 }) as? SKShapeNode {
            shadowNode.fillColor = UIColor(cgColor: color.shadowColor)
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
    
    func updateFPS(_ newFPS: Int) {
        view?.preferredFramesPerSecond = newFPS
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let memoryWarning = Notification.Name("memoryWarning")
    static let memoryCritical = Notification.Name("memoryCritical")
    // Removed duplicate gameOver declaration since it's already defined in GameState
} 