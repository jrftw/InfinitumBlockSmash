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
        // Remove old nodes
        for node in blockNodes { node.removeFromParent() }
        blockNodes.removeAll()

        guard !blocks.isEmpty else { return }

        // 1. Compute union bounding box for all shapes
        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
        let blockBounds: [(minX: Int, maxX: Int, minY: Int, maxY: Int)] = blocks.map { block in
            let bx = block.shape.cells.map { $0.0 }
            let by = block.shape.cells.map { $0.1 }
            let bminX = bx.min() ?? 0
            let bmaxX = bx.max() ?? 0
            let bminY = by.min() ?? 0
            let bmaxY = by.max() ?? 0
            minX = min(minX, bminX)
            maxX = max(maxX, bmaxX)
            minY = min(minY, bminY)
            maxY = max(maxY, bmaxY)
            return (bminX, bmaxX, bminY, bmaxY)
        }

        // 2. Compute total width (shapes + spacing) and max height
        let shapeWidths = blockBounds.map { CGFloat($0.maxX - $0.minX + 1) * blockSize }
        let shapeHeights = blockBounds.map { CGFloat($0.maxY - $0.minY + 1) * blockSize }
        let totalWidth = shapeWidths.reduce(0, +) + baseSpacing * CGFloat(max(blocks.count - 1, 0))
        let maxHeight = shapeHeights.max() ?? 0

        // 3. Compute scale - make tray shapes smaller than grid shapes
        let scaleX = availableWidth / totalWidth
        let scaleY = availableHeight / maxHeight
        let scale = min(0.6, scaleX, scaleY)
        lastScale = scale
        lastBlockSize = blockSize * scale
        let scaledSpacing = baseSpacing * scale
        let scaledTotalWidth = shapeWidths.reduce(0, +) * scale + scaledSpacing * CGFloat(max(blocks.count - 1, 0))

        // 4. Center all shapes as a group
        var xOffset: CGFloat = -scaledTotalWidth / 2
        for (i, block) in blocks.enumerated() {
            let shapeWidth = shapeWidths[i] * scale
            let shapeHeight = shapeHeights[i] * scale
            let node = ShapeNode(block: block, blockSize: blockSize * scale)
            
            // Center each shape vertically and horizontally
            let verticalOffset = -shapeHeight / 2 + blockSize * scale / 2
            node.position = CGPoint(x: xOffset + shapeWidth / 2, y: verticalOffset)
            node.setScale(1.0)
            node.name = "trayShape_\(block.id.uuidString)"
            node.zPosition = CGFloat(i) // Set zPosition based on index to prevent overlapping
            addChild(node)
            blockNodes.append(node)
            xOffset += shapeWidth + scaledSpacing
        }
    }

    // Helper for GameScene to get the current scale for drag-and-drop
    func currentTrayBlockScale() -> CGFloat { lastScale }
    func currentTrayBlockSize() -> CGFloat { lastBlockSize }
} 