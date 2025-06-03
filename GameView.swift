import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject private var gameState = GameState()
    @EnvironmentObject private var appStateManager: AppStateManager
    
    var scene: SKScene {
        let scene = GameScene()
        scene.size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        scene.scaleMode = .fill
        scene.gameState = gameState
        return scene
    }
    
    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Game Board"))
            
            VStack {
                HStack {
                    Text(String(format: NSLocalizedString("score", comment: ""), gameState.score))
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .accessibilityLabel(Text(String(format: NSLocalizedString("score", comment: ""), gameState.score)))
                    
                    Spacer()
                    
                    Button(action: {
                        gameState.resetGame()
                    }) {
                        Text(NSLocalizedString("reset", comment: ""))
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                    .accessibilityLabel(Text(NSLocalizedString("reset.accessibility.label", comment: "")))
                    .accessibilityHint(Text(NSLocalizedString("reset.accessibility.hint", comment: "")))
                }
                Spacer()
            }
            
            if appStateManager.isOffline {
                VStack {
                    Text("Offline Mode")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
                .padding(.top, 50)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupNotifications()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveGameState"),
            object: nil,
            queue: .main
        ) { _ in
            appStateManager.saveGameState(gameState)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RestoreGameState"),
            object: nil,
            queue: .main
        ) { notification in
            if let savedState = notification.object as? GameState {
                gameState.score = savedState.score
                gameState.isGameOver = savedState.isGameOver
                gameState.level = savedState.level
                gameState.blocks = savedState.blocks
            }
        }
    }
}

#Preview {
    GameView()
        .environmentObject(AppStateManager())
} 