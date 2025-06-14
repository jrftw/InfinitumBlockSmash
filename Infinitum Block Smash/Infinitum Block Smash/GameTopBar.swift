import SwiftUI

struct GameTopBar: View {
    @Binding var showingSettings: Bool
    @Binding var showingAchievements: Bool
    @Binding var isPaused: Bool
    @ObservedObject var gameState: GameState
    @State private var showingLeaderboard = false
    
    // Minimum tap target size for better touch response
    private let minimumTapSize: CGFloat = 44
    
    // Screen size check
    private var isSmallScreen: Bool {
        UIScreen.main.bounds.width <= 390 // 6.1" iPhone width
    }
    
    var body: some View {
        HStack {
            // Pause Button
            Button(action: { isPaused = true }) {
                Image(systemName: "pause.circle.fill")
                    .font(isSmallScreen ? .title3 : .title2)
                    .foregroundColor(.white)
                    .frame(width: minimumTapSize, height: minimumTapSize)
            }
            .padding(.trailing, 8)
            
            if !isSmallScreen {
                Text("Block Smash")
                    .font(.title2.bold())
                    .foregroundColor(.white)
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
                        .frame(width: minimumTapSize, height: minimumTapSize)
                }
                .disabled(gameState.hintsUsedThisGame >= 3)
                .opacity(gameState.hintsUsedThisGame >= 3 ? 0.5 : 1.0)
                .accessibilityLabel("Get Hint (Watch Ad)")
                
                // Achievements Button
                Button(action: { showingAchievements = true }) {
                    Image(systemName: "rosette")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .frame(width: minimumTapSize, height: minimumTapSize)
                }
                .accessibilityLabel("Achievements")
                
                // Leaderboard Button
                Button(action: { showingLeaderboard = true }) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .frame(width: minimumTapSize, height: minimumTapSize)
                }
                .accessibilityLabel("Leaderboard")
                
                // Settings Button
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: minimumTapSize, height: minimumTapSize)
                }
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
    }
} 
