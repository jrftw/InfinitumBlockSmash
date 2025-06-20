/******************************************************
 * FILE: TrayNode.swift
 * MARK: Block Tray Visual Container
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides visual representation of the block tray, managing the display
 * and layout of available blocks for player selection.
 *
 * KEY RESPONSIBILITIES:
 * - Display available blocks in a visual tray
 * - Handle block scaling and positioning
 * - Manage tray layout and spacing
 * - Support drag-and-drop interactions
 * - Provide visual feedback for block selection
 * - Handle tray resizing and adaptation
 *
 * MAJOR DEPENDENCIES:
 * - Block.swift: Block data model and properties
 * - ShapeNode.swift: Visual block representation
 * - SpriteKit: Core framework for visual nodes
 * - GameConstants.swift: Layout and sizing constants
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SpriteKit: Game development framework for visual nodes
 * - CoreGraphics: Graphics framework for layout calculations
 *
 * ARCHITECTURE ROLE:
 * Acts as a visual container that displays available blocks
 * in an organized and accessible layout for player interaction.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Block scaling must maintain aspect ratios
 * - Tray layout must be responsive to different screen sizes
 * - Block positioning must be accurate for drag-and-drop
 * - Visual feedback must be immediate and clear
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify tray layout on different screen sizes
 * - Check block scaling and positioning accuracy
 * - Test drag-and-drop interaction precision
 * - Validate visual feedback responsiveness
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add tray animation effects
 * - Implement block highlighting
 * - Add tray customization options
 ******************************************************/

import SpriteKit

class TrayNode: SKNode {
    private let trayHeight: CGFloat
    private let trayHorizontalPadding: CGFloat = 16
    private let trayVerticalPadding: CGFloat = 8
    private let baseSpacing: CGFloat = 40
    private let backgroundNode: SKShapeNode
    private var blockNodes: [ShapeNode] = []
    private var trayWidth: CGFloat = 0
    private var availableWidth: CGFloat = 0
    private var availableHeight: CGFloat = 0
    private var lastScale: CGFloat = 1.0
    private var lastBlockSize: CGFloat = 0

    init(trayHeight: CGFloat, trayWidth: CGFloat) {
        self.trayHeight = trayHeight
        self.trayWidth = trayWidth
        self.availableWidth = trayWidth - trayHorizontalPadding * 2
        self.availableHeight = trayHeight - trayVerticalPadding * 2
        self.backgroundNode = SKShapeNode(rectOf: CGSize(width: trayWidth, height: trayHeight), cornerRadius: 18)
        super.init()
        backgroundNode.fillColor = .black
        backgroundNode.alpha = 0.3
        backgroundNode.position = .zero
        backgroundNode.zPosition = -1
        backgroundNode.name = "trayBackground"
        addChild(backgroundNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBlocks(_ blocks: [Block], blockSize: CGFloat) {
        // Remove old nodes with proper cleanup
        for node in blockNodes { 
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        blockNodes.removeAll(keepingCapacity: true)

        guard !blocks.isEmpty else { return }

        // 1. Compute union bounding box for all shapes
        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
        let blockBounds: [(minX: Int, maxX: Int, minY: Int, maxY: Int)] = blocks.map { block in
            let xs = block.shape.cells.map { (x, _) in x }
            let ys = block.shape.cells.map { (_, y) in y }
            let bminX = xs.min() ?? 0
            let bmaxX = xs.max() ?? 0
            let bminY = ys.min() ?? 0
            let bmaxY = ys.max() ?? 0
            minX = min(minX, bminX)
            maxX = max(maxX, bmaxX)
            minY = min(minY, bminY)
            maxY = max(maxY, bmaxY)
            return (bminX, bmaxX, bminY, bmaxY)
        }

        // 2. Compute total width (shapes + spacing) and max height
        let shapeWidths = blockBounds.map { CGFloat($0.maxX - $0.minX + 1) * blockSize }
        let shapeHeights = blockBounds.map { CGFloat($0.maxY - $0.minY + 1) * blockSize }
        guard let maxHeight = shapeHeights.max(), maxHeight > 0 else { return }

        // 3. Calculate scale to fit height first, with a maximum scale of 0.7
        let scaleY = availableHeight / maxHeight
        let scale = min(0.7, scaleY)
        lastScale = scale
        let scaledBlockSize = blockSize * scale
        lastBlockSize = scaledBlockSize

        // 4. Calculate scaled widths and total width needed for shapes
        let scaledShapeWidths = shapeWidths.map { $0 * scale }
        let totalShapesWidth = scaledShapeWidths.reduce(0, +)
        
        // 5. Calculate optimal spacing to use entire tray width
        let totalSpacing = availableWidth - totalShapesWidth
        let spacingBetweenShapes = totalSpacing / CGFloat(blocks.count + 1)
        
        // 6. Position shapes with proper spacing and z-ordering
        var xOffset: CGFloat = -availableWidth / 2 + spacingBetweenShapes
        for (i, block) in blocks.enumerated() {
            let shapeWidth = scaledShapeWidths[i]
            let shapeHeight = shapeHeights[i] * scale
            let node = ShapeNode(block: block, blockSize: scaledBlockSize)
            
            // Center each shape vertically in the tray, accounting for the shape's origin
            let verticalOffset = -shapeHeight / 2 + scaledBlockSize / 2
            
            node.position = CGPoint(x: xOffset + shapeWidth / 2, y: verticalOffset)
            node.setScale(1.0)
            node.name = "trayShape_\(block.id.uuidString)"
            node.zPosition = CGFloat(i) // Ensure proper z-ordering
            addChild(node)
            blockNodes.append(node)
            
            // Move to next position, adding shape width and spacing
            xOffset += shapeWidth + spacingBetweenShapes
        }
    }

    // Helper for GameScene to get the current scale for drag-and-drop
    func currentTrayBlockScale() -> CGFloat { lastScale }
    func currentTrayBlockSize() -> CGFloat { lastBlockSize }
} 
