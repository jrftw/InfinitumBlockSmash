import Foundation
import CoreGraphics

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let ball: UInt32 = 0b1
    static let block: UInt32 = 0b10
    static let paddle: UInt32 = 0b100
    static let wall: UInt32 = 0b1000
}

struct GameConstants {
    static let gridSize = 10
    static let blockSize: CGFloat = 34
    static let blockWidth: CGFloat = 40
    static let blockHeight: CGFloat = 20
    static let blockSpacing: CGFloat = 2
    static let wallThickness: CGFloat = 20
} 