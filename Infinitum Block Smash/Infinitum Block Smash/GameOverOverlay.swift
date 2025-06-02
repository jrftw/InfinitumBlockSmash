import SwiftUI

struct GameOverOverlay: View {
    let isPresented: Bool
    let score: Int
    let level: Int
    let onRetry: () -> Void
    let onMainMenu: () -> Void
    
    var body: some View {
        if isPresented {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 24) {
                        Text("Game Over")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Final Score: \(score)")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Level Reached: \(level)")
                            .font(.title3)
                            .foregroundColor(.yellow)
                        
                        VStack(spacing: 16) {
                            Button(action: onRetry) {
                                Text("Try Again")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 14)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: onMainMenu) {
                                Text("Main Menu")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 14)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
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