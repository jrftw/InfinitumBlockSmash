/******************************************************
 * FILE: GameSceneExtension.swift
 * MARK: GameScene Extensions and Grid State Management System
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides comprehensive extensions for the GameScene class that handle grid state
 * management, visual updates, and atomic placement operations. This file implements
 * the GameStateDelegate protocol and ensures robust visual synchronization between
 * the game state and visual representation.
 *
 * KEY RESPONSIBILITIES:
 * - GameStateDelegate implementation for visual state synchronization
 * - Grid state validation and consistency checking
 * - Hard grid clearing with comprehensive residual node removal
 * - Atomic block placement and visual synchronization
 * - Incremental grid updates for performance optimization
 * - Block node creation with proper styling and effects
 * - Visual state consistency validation and error detection
 * - Memory-efficient node management and cleanup
 * - Debug logging and performance monitoring
 * - Error recovery and cleanup operations
 * - Texture caching and gradient management
 * - Shadow and visual effects implementation
 * - Performance optimization for large grids
 * - Memory leak prevention and cleanup
 *
 * MAJOR DEPENDENCIES:
 * - GameScene.swift: Core scene functionality and rendering
 * - GameState.swift: Source of truth for grid data and state
 * - NodePool.swift: Object pooling for performance optimization
 * - GameConstants.swift: Grid configuration and sizing constants
 * - Logger.swift: Debug logging and performance tracking
 * - MemorySystem.swift: Memory management and cleanup coordination
 * - Block.swift: Block data model and visual properties
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SpriteKit: Game development framework for visual rendering
 * - Foundation: Core framework for data structures and logging
 *
 * ARCHITECTURE ROLE:
 * Acts as the visual synchronization layer between the game state
 * and visual representation, ensuring consistent and performant
 * rendering while maintaining memory efficiency.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Visual updates must occur on main thread for consistency
 * - Grid clearing must be comprehensive to prevent artifacts
 * - Node cleanup must be atomic to prevent memory leaks
 * - Performance optimization requires incremental updates
 * - State validation must catch visual/data mismatches
 */

import SpriteKit
import Foundation

// MARK: - GameStateDelegate Extension
extension GameScene: GameStateDelegate {
    func gameStateDidUpdate() {
        Logger.shared.debug("gameStateDidUpdate called", category: .debugGameScene)
        
        print("[DEBUG] Visual update - clearing all placed block nodes")
        print("[DEBUG] Current placed block nodes count: \(placedBlockNodes.count)")
        print("[DEBUG] Grid node children before clear: \(gridNode.children.count)")
        
        // 1. Force clear all placed block nodes
        placedBlockNodes.values.forEach { node in
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        placedBlockNodes.removeAll()
        
        // 2. HARD CLEAR: Remove all children from gridNode except essential static nodes
        hardClearGridContainer()
        
        print("[DEBUG] Visual update - cleared all nodes, remaining grid children: \(gridNode.children.count)")
        
        // Clean up placed block nodes periodically
        cleanupPlacedBlockNodes()
        
        // Clear any highlight containers to prevent edge glow artifacts
        clearAllHighlightContainers()
        
        // Clean up textures to prevent black particle artifacts
        cleanupTexturesAndPreventArtifacts()
        
        // Update tray
        setupTray()
        
        // 3. Use incremental grid update instead of complete redraw
        updateGridIncrementally()
        
        print("[DEBUG] Visual update completed")
        print("[DEBUG] Final grid children count: \(gridNode.children.count)")
        print("[DEBUG] Final placed block nodes count: \(placedBlockNodes.count)")
        
        // Validate grid state consistency to catch any mismatches
        validateGridStateConsistency()
    }
    
    private func updateGridIncrementally() {
        guard let gameState = gameState else { return }
        
        let gridSize = GameConstants.gridSize
        
        print("[DEBUG] Updating grid incrementally - clearing existing nodes")
        print("[DEBUG] Grid data state: \(gameState.grid.flatMap { $0 }.compactMap { $0 }.count) blocks")
        
        // First, clear all existing block nodes to ensure no artifacts remain
        placedBlockNodes.values.forEach { node in
            // Ensure proper cleanup to prevent visual artifacts
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        placedBlockNodes.removeAll()
        
        // Clear any remaining nodes with the "placedBlock" name to prevent duplicates
        gridNode.children.forEach { node in
            if node.name == "placedBlock" {
                node.removeAllActions()
                node.removeAllChildren()
                node.removeFromParent()
            }
        }
        
        // Additional cleanup: remove any nodes that might have been missed
        gridNode.children.forEach { node in
            if node.name?.contains("block") == true || node.name?.contains("placed") == true {
                node.removeAllActions()
                node.removeAllChildren()
                node.removeFromParent()
            }
        }
        
        print("[DEBUG] Creating new block nodes for current grid state")
        
        // Update only changed positions instead of redrawing entire grid
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let currentColor = gameState.grid[row][col]
                
                if let currentColor = currentColor {
                    // Position has a block, create new node
                    let cellNode = createBlockNode(for: currentColor, at: (row: row, col: col))
                    trackPlacedBlockNode(cellNode, at: (row: row, col: col))
                    gridNode.addChild(cellNode)
                }
                // If currentColor is nil, no block should be displayed (already cleared above)
            }
        }
        
        print("[DEBUG] Grid update complete - placed \(placedBlockNodes.count) blocks")
    }
    
    private func createBlockNode(for color: BlockColor, at position: (row: Int, col: Int)) -> SKNode {
        let cellNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize), cornerRadius: GameConstants.blockSize * 0.18)
        
        // Create gradient fill
        let gradientNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize), cornerRadius: GameConstants.blockSize * 0.18)
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
            } else {
                // Fallback to solid color if gradient creation fails
                print("[DEBUG] Gradient creation failed for color \(color.rawValue), using fallback")
                gradientNode.fillColor = SKColor.from(color.color)
            }
        }
        
        // Add shadow effect
        let shadowNode = SKShapeNode(rectOf: CGSize(width: GameConstants.blockSize, height: GameConstants.blockSize), cornerRadius: GameConstants.blockSize * 0.18)
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
        let fpsManager = FPSManager.shared
        let thermalAwareFPS = fpsManager.getThermalAwareFPS()
        view?.preferredFramesPerSecond = thermalAwareFPS
        
        Logger.shared.debug("[Thermal] Updated FPS to \(thermalAwareFPS) (requested: \(newFPS))", category: .debugGameScene)
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
    
    // MARK: - Hard Grid Clearing
    
    private func hardClearGridContainer() {
        #if DEBUG
        print("[DEBUG] HARD CLEAR: Removing all children from grid container")
        print("[DEBUG] Grid children before hard clear: \(gridNode.children.count)")
        #endif
        
        // Remove all children except essential static nodes
        for child in gridNode.children {
            if let name = child.name {
                // Preserve only essential static nodes (grid lines, background)
                if name.contains("gridLine") || name.contains("gridTile") || name.contains("background") {
                    #if DEBUG
                    print("[DEBUG] Preserving static node: \(name)")
                    #endif
                    continue
                } else {
                    #if DEBUG
                    print("[DEBUG] Removing node: \(name)")
                    #endif
                    child.removeAllActions()
                    child.removeAllChildren()
                    child.removeFromParent()
                }
            } else {
                #if DEBUG
                print("[DEBUG] Removing unnamed node")
                #endif
                child.removeAllActions()
                child.removeAllChildren()
                child.removeFromParent()
            }
        }
        
        #if DEBUG
        print("[DEBUG] Grid children after hard clear: \(gridNode.children.count)")
        
        // Validate that only essential static nodes remain
        let remainingNodes = gridNode.children.compactMap { $0.name }
        print("[DEBUG] Remaining nodes after clear: \(remainingNodes)")
        
        // Ensure placedBlockNodes tracking is also cleared
        placedBlockNodes.removeAll()
        print("[DEBUG] Placed block nodes tracking cleared: \(placedBlockNodes.count) nodes")
        #endif
    }
    
    // MARK: - Grid State Validation
    
    private func validateGridStateConsistency() {
        guard let gameState = gameState else { return }
        
        #if DEBUG
        print("[DEBUG] Validating grid state consistency")
        #endif
        
        let gridSize = GameConstants.gridSize
        var visualBlockCount = 0
        var dataBlockCount = 0
        
        // Count blocks in visual state
        for (_, node) in placedBlockNodes {
            if node.parent != nil {
                visualBlockCount += 1
            }
        }
        
        // Count blocks in data state
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if gameState.grid[row][col] != nil {
                    dataBlockCount += 1
                }
            }
        }
        
        #if DEBUG
        print("[DEBUG] Visual blocks: \(visualBlockCount), Data blocks: \(dataBlockCount)")
        #endif
        
        if visualBlockCount != dataBlockCount {
            Logger.shared.log("Grid state mismatch! Visual: \(visualBlockCount), Data: \(dataBlockCount)", category: .debugGameScene, level: .error)
            
            // Log details of the mismatch
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    if gameState.grid[row][col] != nil {
                        let key = "\(row),\(col)"
                        if placedBlockNodes[key] == nil {
                            Logger.shared.log("Data has block at (\(row), \(col)) but no visual node", category: .debugGameScene, level: .error)
                        }
                    }
                }
            }
            
            for (key, node) in placedBlockNodes {
                if node.parent != nil {
                    let components = key.split(separator: ",")
                    if components.count == 2,
                       let row = Int(components[0]),
                       let col = Int(components[1]),
                       row >= 0 && row < gridSize && col >= 0 && col < gridSize {
                        if gameState.grid[row][col] == nil {
                            Logger.shared.log("Visual node at (\(row), \(col)) but no data", category: .debugGameScene, level: .error)
                        }
                    }
                }
            }
        } else {
            #if DEBUG
            print("[DEBUG] Grid state consistency validated successfully")
            #endif
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let memoryWarning = Notification.Name("memoryWarning")
    static let memoryCritical = Notification.Name("memoryCritical")
    // Removed duplicate gameOver declaration since it's already defined in GameState
} 
