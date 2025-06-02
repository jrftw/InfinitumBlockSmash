import SpriteKit
import GameplayKit
import SwiftUI

class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var gameState: GameState?
    
    private var paddle: SKShapeNode?
    private var ball: SKShapeNode?
    private var blocks: [Block] = []
    
    override func didMove(to view: SKView) {
        setupPhysics()
        setupPaddle()
        setupBall()
        setupWalls()
    }
    
    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }
    
    private func setupPaddle() {
        let paddleSize = CGSize(width: GameConstants.paddleWidth, height: GameConstants.paddleHeight)
        paddle = SKShapeNode(rectOf: paddleSize, cornerRadius: 5)
        
        guard let paddle = paddle else { return }
        paddle.fillColor = .white
        paddle.strokeColor = .gray
        paddle.lineWidth = 2
        paddle.position = CGPoint(x: frame.midX, y: frame.minY + 50)
        
        paddle.physicsBody = SKPhysicsBody(rectangleOf: paddleSize)
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle.physicsBody?.contactTestBitMask = PhysicsCategory.ball
        
        addChild(paddle)
    }
    
    private func setupBall() {
        ball = SKShapeNode(circleOfRadius: GameConstants.ballRadius)
        
        guard let ball = ball else { return }
        ball.fillColor = .white
        ball.strokeColor = .gray
        ball.lineWidth = 2
        ball.position = CGPoint(x: frame.midX, y: frame.minY + 100)
        
        ball.physicsBody = SKPhysicsBody(circleOfRadius: GameConstants.ballRadius)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.allowsRotation = false
        ball.physicsBody?.friction = 0
        ball.physicsBody?.restitution = 1
        ball.physicsBody?.linearDamping = 0
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.block | PhysicsCategory.paddle | PhysicsCategory.wall
        
        addChild(ball)
        launchBall()
    }
    
    private func setupWalls() {
        let wallSize = CGSize(width: frame.width, height: GameConstants.wallThickness)
        
        // Top wall
        let topWall = SKShapeNode(rectOf: wallSize)
        topWall.fillColor = .clear
        topWall.position = CGPoint(x: frame.midX, y: frame.maxY)
        topWall.physicsBody = SKPhysicsBody(rectangleOf: wallSize)
        topWall.physicsBody?.isDynamic = false
        topWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        addChild(topWall)
        
        // Left wall
        let leftWall = SKShapeNode(rectOf: CGSize(width: GameConstants.wallThickness, height: frame.height))
        leftWall.fillColor = .clear
        leftWall.position = CGPoint(x: frame.minX, y: frame.midY)
        leftWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GameConstants.wallThickness, height: frame.height))
        leftWall.physicsBody?.isDynamic = false
        leftWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        addChild(leftWall)
        
        // Right wall
        let rightWall = SKShapeNode(rectOf: CGSize(width: GameConstants.wallThickness, height: frame.height))
        rightWall.fillColor = .clear
        rightWall.position = CGPoint(x: frame.maxX, y: frame.midY)
        rightWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GameConstants.wallThickness, height: frame.height))
        rightWall.physicsBody?.isDynamic = false
        rightWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        addChild(rightWall)
    }
    
    private func launchBall() {
        guard let ball = ball else { return }
        let randomAngle = CGFloat.random(in: -CGFloat.pi/4...CGFloat.pi/4)
        let direction = CGVector(dx: cos(randomAngle), dy: sin(randomAngle))
        ball.physicsBody?.velocity = CGVector(
            dx: direction.dx * GameConstants.initialBallSpeed,
            dy: direction.dy * GameConstants.initialBallSpeed
        )
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Move paddle horizontally only
        paddle?.position.x = location.x
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == PhysicsCategory.ball | PhysicsCategory.block {
            handleBlockCollision(contact)
        }
    }
    
    private func handleBlockCollision(_ contact: SKPhysicsContact) {
        let blockNode = contact.bodyA.categoryBitMask == PhysicsCategory.block ? contact.bodyA.node : contact.bodyB.node
        
        if let block = blocks.first(where: { $0.node == blockNode }) {
            block.node?.removeFromParent()
            gameState?.removeBlock(block)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Check if ball is below paddle
        if let ball = ball, ball.position.y < frame.minY {
            gameState?.gameOver()
        }
    }
} 