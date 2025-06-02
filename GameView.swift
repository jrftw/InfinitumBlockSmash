import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject private var gameState = GameState()
    
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
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    GameView()
} 