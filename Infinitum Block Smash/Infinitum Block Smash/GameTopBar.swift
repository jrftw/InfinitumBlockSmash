import SwiftUI

struct GameTopBar: View {
    @Binding var showingSettings: Bool
    @Binding var showingAchievements: Bool
    @Binding var isPaused: Bool
    @ObservedObject var gameState: GameState
    
    var body: some View {
        HStack {
            Button(action: { isPaused = true }) {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.trailing, 8)
            
            Text("Block Smash")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    if gameState.showHint() {
                        // Hint will be shown after ad
                    }
                }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(gameState.hintsUsedThisGame >= 3)
                .opacity(gameState.hintsUsedThisGame >= 3 ? 0.5 : 1.0)
                .accessibilityLabel("Get Hint (Watch Ad)")
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Button(action: { showingAchievements = true }) {
                    Image(systemName: "rosette")
                        .font(.title2)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
} 
