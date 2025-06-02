import SpriteKit
import SwiftUI

func renderGrid(gridNode: SKNode, gameState: GameState, blockSize: CGFloat) {
    // Remove all previous placed block nodes (but not grid lines or background)
    for node in gridNode.children {
        if node.zPosition == 0 {
            node.removeFromParent()
        }
    }
    // Draw all placed blocks
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
                cellNode.zPosition = 0
                gridNode.addChild(cellNode)
            }
        }
    }
}

func createGradientImage(size: CGSize, colors: [CGColor], locations: [CGFloat]) -> UIImage? {
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