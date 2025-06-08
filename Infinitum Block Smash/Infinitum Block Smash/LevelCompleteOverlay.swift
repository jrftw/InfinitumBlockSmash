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