import Foundation
import SwiftUI

// MARK: - Memory Management
class MemoryManager {
    static let shared = MemoryManager()
    
    private init() {}
    
    func cleanupMemory() {
        // Clear cached data
        autoreleasepool {
            // Additional cleanup if needed
        }
    }
    
    func cleanup() {
        cleanupMemory()
    }
} 