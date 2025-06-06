import Foundation
import CoreGraphics
import UIKit

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let ball: UInt32 = 0b1
    static let block: UInt32 = 0b10
    static let paddle: UInt32 = 0b100
    static let wall: UInt32 = 0b1000
}

struct GameConstants {
    static let gridSize = 10
    static let blockSize: CGFloat = {
        #if os(iOS)
        let screenSize = UIScreen.main.bounds.size
        let minDimension = min(screenSize.width, screenSize.height)
        // Calculate block size to fit 10 blocks with some padding
        let baseSize = minDimension * 0.08 // 8% of screen width/height
        if UIDevice.current.userInterfaceIdiom == .pad {
            return min(baseSize, 54) // Cap at 54 for iPad
        } else {
            return min(baseSize, 34) // Cap at 34 for iPhone
        }
        #else
        return 34
        #endif
    }()
    static let blockWidth: CGFloat = 40
    static let blockHeight: CGFloat = 20
    static let blockSpacing: CGFloat = 2
    static let wallThickness: CGFloat = 20
} 