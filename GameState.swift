import Foundation
import Combine
import SwiftUI

class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var isGameOver: Bool = false
    @Published var level: Int = 1
    
    private var blocks: [Block] = []
    private var timer: Timer?
    
    init() {
        setupGame()
    }
    
    func setupGame() {
        score = 0
        isGameOver = false
        level = 1
        blocks = []
        startGame()
    }
    
    func startGame() {
        // Initialize game blocks
        generateBlocks()
    }
    
    func resetGame() {
        setupGame()
    }
    
    func generateBlocks() {
        // Generate initial blocks based on level
        let rows = 5 + (level - 1)
        let columns = 8
        
        for row in 0..<rows {
            for col in 0..<columns {
                let block = Block(
                    position: CGPoint(x: col * 50 + 25, y: row * 30 + 25),
                    color: BlockColor.random()
                )
                blocks.append(block)
            }
        }
    }
    
    func addScore(_ points: Int) {
        score += points
    }
    
    func removeBlock(_ block: Block) {
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks.remove(at: index)
            addScore(10)
            
            if blocks.isEmpty {
                levelUp()
            }
        }
    }
    
    func levelUp() {
        level += 1
        generateBlocks()
    }
    
    func gameOver() {
        isGameOver = true
        timer?.invalidate()
    }
} 