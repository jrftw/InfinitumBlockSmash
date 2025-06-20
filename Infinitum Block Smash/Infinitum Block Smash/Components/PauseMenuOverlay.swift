/******************************************************
 * FILE: PauseMenuOverlay.swift
 * MARK: Game Pause Menu Interface
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides a pause menu overlay that allows players to control game flow,
 * save progress, and navigate between different game states.
 *
 * KEY RESPONSIBILITIES:
 * - Display pause menu options
 * - Handle resume, save, restart, and navigation actions
 * - Provide game state management controls
 * - Support accessibility features
 * - Manage overlay presentation and dismissal
 * - Handle game flow control
 *
 * MAJOR DEPENDENCIES:
 * - BlurView.swift: Background blur effect
 * - SwiftUI: Core UI framework for overlay display
 * - Game state management: Pause/resume functionality
 * - Navigation system: Menu and home navigation
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - UIKit: iOS UI framework for overlay management
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as the game pause interface that provides
 * control over game flow and state management.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Must display above all game elements
 * - Game state must be properly paused when shown
 * - Button actions must be clearly defined
 * - Resume functionality must restore game state
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify pause functionality works correctly
 * - Check accessibility compliance for all buttons
 * - Test game state preservation during pause
 * - Validate navigation actions work properly
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add settings access from pause menu
 * - Implement quick save/load functionality
 * - Add pause menu customization options
 ******************************************************/

import SwiftUI
import UIKit

struct PauseMenuOverlay: View {
    let isPresented: Bool
    let onResume: () -> Void
    let onSave: () -> Void
    let onRestart: () -> Void
    let onEndGame: () -> Void
    var body: some View {
        if isPresented {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 24) {
                        Text("Paused")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Button(action: onResume) {
                            Text("Resume")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        Button(action: onSave) {
                            Text("Save Game")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        Button(action: onEndGame) {
                            Text("End Game")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                        Button(action: onRestart) {
                            Text("Restart")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding(32)
                    .background(BlurView(style: .systemUltraThinMaterialDark))
                    .cornerRadius(24)
                    .padding(40)
                )
        }
    }
} 