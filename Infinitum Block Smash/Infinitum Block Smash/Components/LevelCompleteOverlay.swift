/******************************************************
 * FILE: LevelCompleteOverlay.swift
 * MARK: Level Completion Celebration Interface
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Displays a celebration overlay when a level is completed, showing
 * progress and providing continuation options for the player.
 *
 * KEY RESPONSIBILITIES:
 * - Display level completion celebration
 * - Show current score and level progress
 * - Provide continue button for next level
 * - Play success audio and haptic feedback
 * - Animate overlay appearance and interactions
 * - Support accessibility features
 * - Manage overlay presentation and dismissal
 *
 * MAJOR DEPENDENCIES:
 * - AudioManager.swift: Success sound effects
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
 * Acts as the level progression interface that celebrates
 * player achievements and facilitates continued gameplay.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Must display above all game elements
 * - Success feedback must trigger on appearance
 * - Animations must be celebratory and engaging
 * - Continue action must be clearly accessible
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify overlay animation smoothness and timing
 * - Check accessibility compliance for continue button
 * - Test audio and haptic feedback functionality
 * - Validate score and level display accuracy
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add confetti animation effects
 * - Implement level-specific celebrations
 * - Add achievement unlock notifications
 ******************************************************/

import SwiftUI
import UIKit

struct LevelCompleteOverlay: View {
    let isPresented: Bool
    let score: Int
    let level: Int
    let onContinue: () -> Void
    
    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        if isPresented {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 24) {
                        // Level Complete Text with Animation
                        Text("Level Complete!")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .scaleEffect(scale)
                            .opacity(opacity)
                        
                        // Score and Level Container
                        VStack(spacing: 16) {
                            HStack(spacing: 20) {
                                // Score Display
                                VStack(spacing: 8) {
                                    Text("Score")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                    if #available(iOS 16.0, *) {
                                        Text("\(score)")
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .contentTransition(.numericText())
                                    } else {
                                        Text("\(score)")
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(16)
                                
                                // Level Display
                                VStack(spacing: 8) {
                                    Text("Level")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                    if #available(iOS 16.0, *) {
                                        Text("\(level)")
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.yellow)
                                            .contentTransition(.numericText())
                                    } else {
                                        Text("\(level)")
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .padding()
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(16)
                            }
                        }
                        
                        // Continue Button with Animation
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
                                Text("Continue")
                                    .font(.headline)
                                Image(systemName: "arrow.right.circle.fill")
                                    .imageScale(.large)
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
                        .scaleEffect(scale)
                        .buttonStyle(ScaleButtonStyle())
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
                        // Play success sound
                        AudioManager.shared.playLevelCompleteSound()
                        // Trigger haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
    }
}

// Custom button style for scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
} 