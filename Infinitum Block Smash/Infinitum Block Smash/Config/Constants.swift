/*
 * Constants.swift
 * 
 * GAME CONSTANTS AND CONFIGURATION
 * 
 * This file defines all the core constants and configuration values used throughout
 * the Infinitum Block Smash game. It includes physics categories, grid dimensions,
 * and dynamic block sizing based on device characteristics.
 * 
 * KEY RESPONSIBILITIES:
 * - Game physics category definitions
 * - Dynamic block size calculation
 * - Grid configuration constants
 * - Device-specific sizing optimization
 * - Cross-device compatibility settings
 * - Performance optimization parameters
 * 
 * PHYSICS CATEGORIES:
 * - none: Default physics category (0)
 * - ball: Ball physics interactions (1)
 * - block: Block physics interactions (2)
 * - paddle: Paddle physics interactions (4)
 * - wall: Wall physics interactions (8)
 * 
 * DYNAMIC BLOCK SIZING:
 * - Responsive sizing based on screen dimensions
 * - Device-specific optimization
 * - iPad vs iPhone differentiation
 * - Screen size-based scaling
 * - Performance-optimized sizing
 * 
 * GRID CONFIGURATION:
 * - Standard 10x10 grid size
 * - Dynamic block spacing
 * - Wall thickness definitions
 * - Block dimension constants
 * 
 * DEVICE OPTIMIZATION:
 * - Small screen optimization (≤375px width)
 * - Large screen optimization (≥428px width)
 * - iPad-specific sizing
 * - iPhone-specific sizing
 * - Performance-based limits
 * 
 * PERFORMANCE FEATURES:
 * - Efficient size calculations
 * - Device-specific optimization
 * - Memory-efficient constants
 * - Cross-platform compatibility
 * 
 * ARCHITECTURE ROLE:
 * This file serves as the central configuration hub, providing
 * all game constants and device-specific optimizations in one
 * location for easy maintenance and updates.
 * 
 * THREADING CONSIDERATIONS:
 * - All constants are thread-safe
 * - Static initialization for performance
 * - Immutable configuration values
 * - Safe concurrent access
 * 
 * INTEGRATION POINTS:
 * - GameScene for visual rendering
 * - GameState for grid management
 * - Physics system for collision detection
 * - Device-specific optimizations
 * - Performance monitoring systems
 */

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
        let screenWidth = screenSize.width
        
        // Calculate base size
        let baseSize = minDimension * 0.08 // 8% of screen width/height
        
        // Adjust for specific screen sizes
        if screenWidth <= 375 { // iPhone SE, iPhone 8, etc. (5.4" and smaller)
            return min(baseSize * 0.85, 28) // Scale down by 15% and cap at 28
        } else if screenWidth >= 428 { // iPhone 12 Pro Max, iPhone 14 Pro Max, etc. (6.9" and larger)
            return min(baseSize * 1.15, 38) // Scale up by 15% and cap at 38
        } else {
            // Default scaling for other screen sizes
            if UIDevice.current.userInterfaceIdiom == .pad {
                return min(baseSize, 54) // Cap at 54 for iPad
            } else {
                return min(baseSize, 34) // Cap at 34 for iPhone
            }
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