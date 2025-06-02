import SwiftUI
import UIKit

struct LevelCompleteOverlay: View {
    let isPresented: Bool
    let score: Int
    let level: Int
    let onContinue: () -> Void
    var body: some View {
        if isPresented {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 24) {
                        Text("Level Complete!")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text("Score: \(score)")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Level: \(level)")
                            .font(.title3)
                            .foregroundColor(.yellow)
                        Button(action: onContinue) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.blue)
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