import Foundation

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let ball: UInt32 = 0b1
    static let block: UInt32 = 0b10
    static let paddle: UInt32 = 0b100
    static let wall: UInt32 = 0b1000
}

struct GameConstants {
    static let ballRadius: CGFloat = 10
    static let paddleWidth: CGFloat = 100
    static let paddleHeight: CGFloat = 20
    static let initialBallSpeed: CGFloat = 400
    static let maxBallSpeed: CGFloat = 800
    static let ballSpeedIncrease: CGFloat = 50
    
    static let blockWidth: CGFloat = 40
    static let blockHeight: CGFloat = 20
    static let blockSpacing: CGFloat = 5
    
    static let wallThickness: CGFloat = 20
} 