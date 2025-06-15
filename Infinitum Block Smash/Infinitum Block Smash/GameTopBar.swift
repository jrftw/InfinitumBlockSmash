import SwiftUI

struct GameTopBar: View {
    @Binding var showingSettings: Bool
    @Binding var showingAchievements: Bool
    @Binding var isPaused: Bool
    @ObservedObject var gameState: GameState
    @State private var showingLeaderboard = false
    
    // Minimum tap target size for better touch response
    private let minimumTapSize: CGFloat = 44
    
    @inline(__always)
    private var isSmallScreen: Bool {
        UIScreen.main.bounds.width <= 390 // 6.1" iPhone width
    }
    
    private struct MinimumTapButtonStyle: ButtonStyle {
        let size: CGFloat
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: size, height: size)
        }
    }
    
    private func iconButton(systemName: String, action: @escaping () -> Void, foreground: Color) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundColor(foreground)
        }
        .buttonStyle(MinimumTapButtonStyle(size: minimumTapSize))
    }
    
    var body: some View {
        HStack {
            // Pause Button
            Button(action: { isPaused = true }) {
                Image(systemName: "pause.circle.fill")
                    .font(isSmallScreen ? .title3 : .title2)
                    .foregroundColor(.white)
            }
            .buttonStyle(MinimumTapButtonStyle(size: minimumTapSize))
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
                }
                .buttonStyle(MinimumTapButtonStyle(size: minimumTapSize))
                .disabled(gameState.hintsUsedThisGame >= 3)
                .opacity(gameState.hintsUsedThisGame >= 3 ? 0.5 : 1.0)
                .accessibilityLabel("Get Hint (Watch Ad)")
                
                // Achievements Button
                iconButton(systemName: "rosette", action: { showingAchievements = true }, foreground: .yellow)
                    .accessibilityLabel("Achievements")
                
                // Leaderboard Button
                iconButton(systemName: "trophy.fill", action: { showingLeaderboard = true }, foreground: .yellow)
                    .accessibilityLabel("Leaderboard")
                
                // Settings Button
                iconButton(systemName: "gearshape.fill", action: { showingSettings = true }, foreground: .white)
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
