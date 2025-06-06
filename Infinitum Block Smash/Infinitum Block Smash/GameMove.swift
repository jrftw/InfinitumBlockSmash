import Foundation
import SwiftUI

// MARK: - Game Types
struct GameMove {
    let block: Block
    let position: CGPoint
    let timestamp: Date
    
    init(block: Block, position: CGPoint, timestamp: Date) {
        self.block = block
        self.position = position
        self.timestamp = timestamp
    }
} 