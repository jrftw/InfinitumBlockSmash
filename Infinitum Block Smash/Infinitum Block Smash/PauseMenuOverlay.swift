import SwiftUI
import UIKit

struct PauseMenuOverlay: View {
    let isPresented: Bool
    let onResume: () -> Void
    let onSave: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void
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
                        Button(action: onRestart) {
                            Text("Restart")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                        Button(action: onHome) {
                            Text("Home")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.red)
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