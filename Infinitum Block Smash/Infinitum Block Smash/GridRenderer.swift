import SpriteKit
import SwiftUI

@MainActor
func renderGrid(gridNode: SKNode, gameState: GameState, blockSize: CGFloat) {
    // Clear existing grid and ensure all children are properly removed
    gridNode.removeAllChildren()
    
    // Create grid lines
    let gridSize = GameConstants.gridSize
    let totalSize = CGFloat(gridSize) * blockSize
    
    // Create vertical lines
    for i in 0...gridSize {
        let x = CGFloat(i) * blockSize
        let line = SKShapeNode(rectOf: CGSize(width: 1, height: totalSize))
        line.position = CGPoint(x: x, y: totalSize / 2)
        line.fillColor = .white
        line.strokeColor = .white
        line.alpha = 0.3
        line.zPosition = -1
        line.name = "gridLine"
        gridNode.addChild(line)
    }
    
    // Create horizontal lines
    for i in 0...gridSize {
        let y = CGFloat(i) * blockSize
        let line = SKShapeNode(rectOf: CGSize(width: totalSize, height: 1))
        line.position = CGPoint(x: totalSize / 2, y: y)
        line.fillColor = .white
        line.strokeColor = .white
        line.alpha = 0.3
        line.zPosition = -1
        line.name = "gridLine"
        gridNode.addChild(line)
    }
    
    // Draw all placed blocks
    for row in 0..<gridSize {
        for col in 0..<gridSize {
            if let block = gameState.grid[row][col] {
                let cellNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: blockSize * 0.18)
                cellNode.name = "block_\(row)_\(col)" // Add unique identifier for each block
                
                // Gradient fill
                let colors = [block.gradientColors.start, block.gradientColors.end]
                let locations: [CGFloat] = [0.0, 1.0]
                if let gradientImage = createGradientImage(size: CGSize(width: blockSize, height: blockSize), colors: colors, locations: locations) {
                    cellNode.fillTexture = SKTexture(image: gradientImage)
                    cellNode.fillColor = .white
                } else {
                    cellNode.fillColor = SKColor.from(Color(cgColor: block.gradientColors.start))
                }
                
                // Shadow
                let shadowNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
                shadowNode.fillColor = UIColor(cgColor: block.shadowColor)
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
                    x: CGFloat(col) * blockSize + blockSize / 2,
                    y: CGFloat(row) * blockSize + blockSize / 2
                )
                cellNode.zPosition = 1
                gridNode.addChild(cellNode)
            }
        }
    }
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