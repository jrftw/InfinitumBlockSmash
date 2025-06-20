/******************************************************
 * FILE: GameSceneProvider.swift
 * MARK: SwiftUI SpriteKit Scene Provider
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides a SwiftUI wrapper for the SpriteKit GameScene, enabling
 * seamless integration between SwiftUI and SpriteKit rendering.
 *
 * KEY RESPONSIBILITIES:
 * - Bridge SwiftUI and SpriteKit frameworks
 * - Manage GameScene lifecycle and initialization
 * - Handle scene size and scaling configuration
 * - Provide SwiftUI view integration for SpriteKit
 * - Support GameState observation and updates
 * - Manage scene creation and disposal
 *
 * MAJOR DEPENDENCIES:
 * - GameScene.swift: SpriteKit scene implementation
 * - GameState.swift: Game state management
 * - SwiftUI: Modern UI framework for view integration
 * - SpriteKit: Game rendering framework
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - SpriteKit: Game development framework
 *
 * ARCHITECTURE ROLE:
 * Acts as a bridge layer that enables SwiftUI views to host
 * and manage SpriteKit game scenes seamlessly.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Scene must be properly initialized with correct size
 * - GameState must be available before scene creation
 * - Scene lifecycle must be managed correctly
 * - Memory management must be handled properly
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
    
    var body: some View {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        let sceneSize = CGSize(width: width, height: height)
        SpriteView(scene: scene ?? GameScene(size: sceneSize, gameState: gameState))
            .ignoresSafeArea()
            .onAppear {
                Logger.shared.debug("GameSceneProvider onAppear", category: .debugGameProvider)
                if scene == nil {
                    let newScene = GameScene(size: sceneSize, gameState: gameState)
                    newScene.scaleMode = .aspectFill
                    scene = newScene
                }
            }
    }
} 