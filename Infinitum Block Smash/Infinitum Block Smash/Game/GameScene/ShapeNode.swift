/******************************************************
 * FILE: ShapeNode.swift
 * MARK: SpriteKit Block Shape Visual Node
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides visual representation of block shapes in SpriteKit,
 * creating gradient-filled nodes with shadows and visual effects.
 *
 * KEY RESPONSIBILITIES:
 * - Create visual block shape nodes from Block data
 * - Apply gradient fills and color schemes
 * - Add shadow and shine visual effects
 * - Handle block size and positioning
 * - Generate gradient textures for blocks
 * - Support visual styling and theming
 *
 * MAJOR DEPENDENCIES:
 * - Block.swift: Block data model and properties
 * - SpriteKit: Core framework for visual nodes
 * - UIKit: Image generation and color handling
 * - CoreGraphics: Gradient creation and rendering
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SpriteKit: Game development framework for visual nodes
 * - UIKit: iOS UI framework for image processing
 * - CoreGraphics: Graphics framework for gradient creation
 *
 * ARCHITECTURE ROLE:
 * Acts as a visual rendering component that transforms
 * block data into attractive SpriteKit visual nodes.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Gradient textures must be generated efficiently
 * - Visual effects must be applied in correct order
 * - Block positioning must be accurate
 * - Memory management for textures must be handled
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify gradient texture generation performance
 * - Check visual effect rendering quality
 * - Test block positioning accuracy
 * - Validate memory usage for textures
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add animation support for shape changes
 * - Implement texture caching
 * - Add more visual effects
 ******************************************************/

import SpriteKit

class ShapeNode: SKNode {
    init(block: Block, blockSize: CGFloat) {
        super.init()
        for (dx, dy) in block.shape.cells {
            let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
            // Gradient fill
            let colors = [block.color.gradientColors.start, block.color.gradientColors.end]
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradientImage = ShapeNode.createGradientImage(size: CGSize(width: blockSize, height: blockSize), colors: colors, locations: locations) {
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
            cellNode.position = CGPoint(x: CGFloat(dx) * blockSize, y: CGFloat(dy) * blockSize)
            addChild(cellNode)
        }
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    static func createGradientImage(size: CGSize, colors: [CGColor], locations: [CGFloat]) -> UIImage? {
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
} 