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
                        Text("Game Over")
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
                                    Text("Final Score")
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
                                    Text("Level Reached")
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
                                        Text("Continue")
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
                                .accessibilityHint("Continue from where you left off")
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
                                    Text("Try Again")
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
                            .accessibilityHint("Start a new game")
                            
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
                                    Text("Main Menu")
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
                            .accessibilityHint("Return to the main menu")
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