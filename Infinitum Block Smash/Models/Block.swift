import Foundation
import SpriteKit
import UIKit

enum BlockColor: CaseIterable {
    case red, blue, green, yellow, purple
    
    var color: UIColor {
        switch self {
        case .red: return .systemRed
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .purple: return .systemPurple
        }
    }
    
    static func random() -> BlockColor {
        BlockColor.allCases.randomElement() ?? .red
    }
}

class Block: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: BlockColor
    var node: SKShapeNode?
    
    init(position: CGPoint, color: BlockColor) {
        self.position = position
        self.color = color
        createNode()
    }
    
    private func createNode() {
        let size = CGSize(width: 40, height: 20)
        node = SKShapeNode(rectOf: size, cornerRadius: 5)
        node?.fillColor = color.color
        node?.strokeColor = .white
        node?.lineWidth = 2
        node?.position = position
        node?.physicsBody = SKPhysicsBody(rectangleOf: size)
        node?.physicsBody?.isDynamic = false
        node?.physicsBody?.categoryBitMask = PhysicsCategory.block
        node?.physicsBody?.contactTestBitMask = PhysicsCategory.ball
    }
} 