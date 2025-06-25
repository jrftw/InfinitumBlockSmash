/******************************************************
 * FILE: GameSceneProvider.swift
 * MARK: SwiftUI SpriteKit Scene Integration Provider
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides a SwiftUI wrapper for the SpriteKit GameScene, enabling seamless
 * integration between SwiftUI and SpriteKit rendering systems. This component
 * manages the lifecycle, initialization, and state synchronization between
 * the modern SwiftUI interface and the SpriteKit game rendering engine.
 *
 * KEY RESPONSIBILITIES:
 * - Bridge SwiftUI and SpriteKit frameworks for seamless integration
 * - Manage GameScene lifecycle, initialization, and disposal
 * - Handle scene size and scaling configuration for different devices
 * - Provide SwiftUI view integration for SpriteKit rendering
 * - Support GameState observation and real-time updates
 * - Manage scene creation, configuration, and memory management
 * - Handle device-specific scene sizing and aspect ratios
 * - Coordinate scene state with SwiftUI view lifecycle
 * - Provide performance optimization for scene rendering
 * - Support scene debugging and logging integration
 *
 * MAJOR DEPENDENCIES:
 * - GameScene.swift: Core SpriteKit scene implementation and rendering
 * - GameState.swift: Game state management and data synchronization
 * - SwiftUI: Modern declarative UI framework for view integration
 * - SpriteKit: Game rendering framework for visual presentation
 * - Logger.swift: Debug logging and performance tracking
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - SpriteKit: Game development framework for rendering
 * - UIKit: iOS UI framework for screen size detection
 *
 * ARCHITECTURE ROLE:
 * Acts as a bridge layer that enables SwiftUI views to host and manage
 * SpriteKit game scenes seamlessly, providing the integration point
 * between modern UI frameworks and game rendering systems.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Scene must be properly initialized with correct device-specific size
 * - GameState must be available and synchronized before scene creation
 * - Scene lifecycle must be managed correctly for memory efficiency
 * - Memory management must be handled properly to prevent leaks
 * - Scene scaling must adapt to different device orientations
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify scene initialization and sizing
 * - Check memory management and cleanup
 * - Test GameState integration
 * - Validate scene lifecycle handling
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add scene configuration options
 * - Implement scene state persistence
 * - Add performance monitoring
 ******************************************************/

import SwiftUI
import SpriteKit

struct GameSceneProvider: View {
    @ObservedObject var gameState: GameState
    @State private var scene: GameScene? = nil
    @State private var isSceneActive = false
    
    var body: some View {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        let sceneSize = CGSize(width: width, height: height)
        
        SpriteView(scene: scene ?? GameScene(size: sceneSize, gameState: gameState))
            .ignoresSafeArea()
            .onAppear {
                Logger.shared.debug("GameSceneProvider onAppear", category: .debugGameProvider)
                
                // Perform cleanup before creating new scene
                Task {
                    await GameCleanupManager.cleanupForSceneTransition()
                }
                
                if scene == nil {
                    let newScene = GameScene(size: sceneSize, gameState: gameState)
                    newScene.scaleMode = .aspectFill
                    scene = newScene
                    isSceneActive = true
                    
                    Logger.shared.debug("New GameScene created", category: .debugGameProvider)
                }
            }
            .onDisappear {
                Logger.shared.debug("GameSceneProvider onDisappear", category: .debugGameProvider)
                
                // Cleanup scene when view disappears
                Task {
                    await cleanupScene()
                }
            }
            .onChange(of: gameState.isGameOver) { isGameOver in
                if isGameOver {
                    Logger.shared.debug("Game over detected, preparing cleanup", category: .debugGameProvider)
                    
                    // Perform cleanup when game ends
                    Task {
                        await GameCleanupManager.cleanupGameplaySession()
                    }
                }
            }
    }
    
    // MARK: - Private Methods
    
    private func cleanupScene() async {
        Logger.shared.debug("Cleaning up GameScene", category: .debugGameProvider)
        
        guard let currentScene = scene else {
            Logger.shared.debug("No scene to cleanup", category: .debugGameProvider)
            return
        }
        
        // Perform scene-specific cleanup
        await currentScene.prepareForSceneTransition()
        
        // Clear scene reference
        await MainActor.run {
            scene = nil
            isSceneActive = false
        }
        
        // Perform comprehensive cleanup
        await GameCleanupManager.cleanupForSceneTransition()
        
        Logger.shared.debug("GameScene cleanup completed", category: .debugGameProvider)
    }
} 