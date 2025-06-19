/*
 * GameStateEXT.swift
 * 
 * GAME STATE EXTENSIONS AND SUPPORTING TYPES
 * 
 * This file contains all extensions and supporting types for GameState.swift
 * to keep the main GameState class focused on core functionality.
 * 
 * CONTENTS:
 * - SeededGenerator: Deterministic random number generator
 * - BlockColor Extension: Color availability methods
 * - GameError: Error handling enum
 * - Notification.Name Extension: Game state notification names
 * 
 * DEPENDENCIES:
 * - GameState.swift: Main game state class
 * - Block.swift: BlockColor enum
 * - Foundation: Notification.Name
 */

import Foundation

// MARK: - Extensions and Supporting Types

// Deterministic seeded random generator
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

// MARK: - BlockColor Extension
extension BlockColor {
    static func availableColors(for level: Int) -> [BlockColor] {
        return [.red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan]
    }
}

// MARK: - Error Handling
enum GameError: LocalizedError {
    case saveFailed(Error)
    case leaderboardUpdateFailed(Error)
    case invalidMove
    case networkError
    case loadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save game progress: \(error.localizedDescription)"
        case .leaderboardUpdateFailed(let error):
            return "Failed to update leaderboard: \(error.localizedDescription)"
        case .invalidMove:
            return "Invalid move"
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .loadFailed(let error):
            return "Failed to load saved game: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gameStateSaved = Notification.Name("gameStateSaved")
    static let gameStateSaveFailed = Notification.Name("gameStateSaveFailed")
    static let gameStateLoaded = Notification.Name("gameStateLoaded")
    static let gameStateLoadFailed = Notification.Name("gameStateLoadFailed")
    static let showSaveGameWarning = Notification.Name("showSaveGameWarning")
    static let levelCompleted = Notification.Name("levelCompleted")
    static let gameOver = Notification.Name("gameOver")
} 