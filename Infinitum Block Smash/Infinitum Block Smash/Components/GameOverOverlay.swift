/******************************************************
 * FILE: GameOverOverlay.swift
 * MARK: Game Over Screen Interface
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Displays the game over screen when the game ends, showing final statistics
 * and providing navigation options for the player.
 *
 * KEY RESPONSIBILITIES:
 * - Display final score and level reached
 * - Provide retry, continue, and main menu options
 * - Show animated game over interface
 * - Handle user navigation decisions
 * - Play appropriate audio and haptic feedback
 * - Support accessibility features
 * - Manage overlay presentation and dismissal
 *
 * MAJOR DEPENDENCIES:
 * - AudioManager.swift: Sound effects for game over
 * - BlurView.swift: Background blur effect
 * - ScaleButtonStyle: Custom button animations
 * - SwiftUI: Core UI framework for overlay display
 * - UIKit: Haptic feedback generation
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - UIKit: iOS UI framework for haptic feedback
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as the game termination interface that provides
 * closure and navigation options when gameplay ends.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Must display above all game elements
 * - Audio and haptic feedback must trigger on appearance
 * - Animations must be smooth and engaging
 * - Button actions must be clearly defined and accessible
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify overlay animation smoothness and timing
 * - Check accessibility compliance for all buttons
 * - Test audio and haptic feedback functionality
 * - Validate score and level display accuracy
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add social sharing options for high scores
 * - Implement achievement notifications
 * - Add replay functionality for final moments
 ******************************************************/

import SwiftUI

struct GameOverOverlay: View {
    let isPresented: Bool
    let score: Int
    let level: Int
    let onRetry: () -> Void
    let onMainMenu: () -> Void
    let onContinue: () -> Void
    let canContinue: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var showStats = false
    
    var body: some View {
        if isPresented {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 24) {
                        // Game Over Text with Animation
                        Text(NSLocalizedString("Game Over", comment: "Game over title"))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .accessibilityAddTraits(.isHeader)
                        
                        // Stats Container
                        VStack(spacing: 16) {
                            // Score Display
                            HStack(spacing: 20) {
                                VStack(spacing: 8) {
                                    Text(NSLocalizedString("Final Score", comment: "Final score label"))
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                    if #available(iOS 16.0, *) {
                                        Text(String(format: NSLocalizedString("%d points", comment: "Final score value"), score))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .contentTransition(.numericText())
                                    } else {
                                        Text(String(format: NSLocalizedString("%d points", comment: "Final score value"), score))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(16)
                                
                                // Level Display
                                VStack(spacing: 8) {
                                    Text(NSLocalizedString("Level Reached", comment: "Level reached label"))
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                    if #available(iOS 16.0, *) {
                                        Text(String(format: NSLocalizedString("%d level", comment: "Level reached value"), level))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.yellow)
                                            .contentTransition(.numericText())
                                    } else {
                                        Text(String(format: NSLocalizedString("%d level", comment: "Level reached value"), level))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .padding()
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(16)
                            }
                        }
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            if canContinue {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        scale = 0.95
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            scale = 1.0
                                        }
                                        onContinue()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text(NSLocalizedString("Continue", comment: "Continue button"))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .accessibilityHint(NSLocalizedString("Continue from where you left off", comment: "Continue button accessibility hint"))
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    scale = 0.95
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        scale = 1.0
                                    }
                                    onRetry()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text(NSLocalizedString("Try Again", comment: "Try again button"))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityHint(NSLocalizedString("Start a new game", comment: "Try again button accessibility hint"))
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    scale = 0.95
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        scale = 1.0
                                    }
                                    onMainMenu()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "house.fill")
                                    Text(NSLocalizedString("Main Menu", comment: "Main menu button"))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityHint(NSLocalizedString("Return to the main menu", comment: "Main menu button accessibility hint"))
                        }
                    }
                    .padding(32)
                    .background(
                        BlurView(style: .systemUltraThinMaterialDark)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .cornerRadius(24)
                    .padding(40)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            scale = 1.0
                            opacity = 1.0
                        }
                        // Play game over sound
                        AudioManager.shared.playFailSound()
                        // Trigger haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
    }
} 