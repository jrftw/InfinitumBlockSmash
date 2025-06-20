/******************************************************
 * FILE: GameTopBar.swift
 * MARK: Game Interface Top Navigation Bar
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides the top navigation bar for the game interface, containing
 * essential game controls, settings access, and navigation elements.
 *
 * KEY RESPONSIBILITIES:
 * - Display pause button for game control
 * - Show hint button with ad integration
 * - Provide access to achievements and leaderboard
 * - Include settings button for game configuration
 * - Handle responsive design for different screen sizes
 * - Implement accessibility features for all buttons
 * - Manage button states and visual feedback
 *
 * MAJOR DEPENDENCIES:
 * - GameState.swift: Game state management and hint system
 * - LeaderboardView.swift: Leaderboard display
 * - SwiftUI: Core UI framework for interface elements
 * - UIKit: Screen size detection and accessibility
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - UIKit: iOS UI framework for screen detection
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as the primary navigation interface for the game,
 * providing access to all major game features and controls.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Must be displayed above all game elements (zIndex: 100)
 * - Button tap targets must meet accessibility standards (44pt minimum)
 * - Hint button must be disabled after 3 uses per game
 * - Responsive design must work across all device sizes
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify accessibility compliance for all buttons
 * - Check responsive design on different screen sizes
 * - Test button tap targets and press animations
 * - Validate hint button state management
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add haptic feedback for button presses
 * - Implement button state persistence
 * - Add more game control options
 ******************************************************/

import SwiftUI

struct GameTopBar: View {
    @Binding var showingSettings: Bool
    @Binding var showingAchievements: Bool
    @Binding var isPaused: Bool
    @ObservedObject var gameState: GameState
    @State private var showingLeaderboard = false
    
    // Minimum tap target size for better touch response
    private let minimumTapSize: CGFloat = 44
    
    @inline(__always)
    private var isSmallScreen: Bool {
        UIScreen.main.bounds.width <= 390 // 6.1" iPhone width
    }
    
    private struct MinimumTapButtonStyle: ButtonStyle {
        let size: CGFloat
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: size, height: size)
                .contentShape(Rectangle()) // Ensures the entire frame is tappable
                .scaleEffect(configuration.isPressed ? 0.9 : 1.0) // Add press animation
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    private func iconButton(systemName: String, action: @escaping () -> Void, foreground: Color) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundColor(foreground)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1) // Add shadow for better visibility
        }
        .buttonStyle(MinimumTapButtonStyle(size: minimumTapSize))
    }
    
    var body: some View {
        HStack {
            // Pause Button
            Button(action: { isPaused = true }) {
                Image(systemName: "pause.circle.fill")
                    .font(isSmallScreen ? .title3 : .title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(MinimumTapButtonStyle(size: minimumTapSize))
            .padding(.trailing, 8)
            
            if !isSmallScreen {
                Text("Block Smash")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Hint Button
                Button(action: {
                    gameState.showHint()
                }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(MinimumTapButtonStyle(size: minimumTapSize))
                .disabled(gameState.hintManager.hintsUsedThisGame >= 3)
                .opacity(gameState.hintManager.hintsUsedThisGame >= 3 ? 0.5 : 1.0)
                .accessibilityLabel("Get Hint (Watch Ad)")
                
                // Achievements Button
                iconButton(systemName: "rosette", action: { showingAchievements = true }, foreground: .yellow)
                    .accessibilityLabel("Achievements")
                
                // Leaderboard Button
                iconButton(systemName: "trophy.fill", action: { showingLeaderboard = true }, foreground: .yellow)
                    .accessibilityLabel("Leaderboard")
                
                // Settings Button
                iconButton(systemName: "gearshape.fill", action: { showingSettings = true }, foreground: .white)
                    .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .zIndex(100) // Ensure top bar is always on top
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
    }
} 
