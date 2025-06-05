import SwiftUI

struct GameOverOverlay: View {
    let isPresented: Bool
    let score: Int
    let level: Int
    let onRetry: () -> Void
    let onMainMenu: () -> Void
    let onContinue: () -> Void
    let canContinue: Bool
    
    var body: some View {
        if isPresented {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 24) {
                        Text("Game Over")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .accessibilityAddTraits(.isHeader)
                        
                        VStack(spacing: 8) {
                            Text("Final Score: \(score)")
                                .font(.title2)
                                .foregroundColor(.white)
                                .accessibilityLabel("Final score: \(score)")
                            
                            Text("Level Reached: \(level)")
                                .font(.title3)
                                .foregroundColor(.yellow)
                                .accessibilityLabel("Level reached: \(level)")
                        }
                        
                        VStack(spacing: 16) {
                            if canContinue {
                                Button(action: onContinue) {
                                    Label("Continue", systemImage: "play.fill")
                                }
                                .primaryButton()
                                .accessibilityHint("Continue from where you left off")
                            }
                            
                            Button(action: onRetry) {
                                Label("Try Again", systemImage: "arrow.clockwise")
                            }
                            .primaryButton()
                            .accessibilityHint("Start a new game")
                            
                            Button(action: onMainMenu) {
                                Label("Main Menu", systemImage: "house.fill")
                            }
                            .secondaryButton()
                            .accessibilityHint("Return to the main menu")
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