import SwiftUI
import SpriteKit

struct GameSceneProvider: View {
    @ObservedObject var gameState: GameState
    var body: some View {
        SpriteView(scene: makeScene())
            .ignoresSafeArea()
    }
    private func makeScene() -> SKScene {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        let scene = GameScene()
        scene.size = CGSize(width: width, height: height)
        scene.scaleMode = .aspectFill
        scene.gameState = gameState
        return scene
    }
} 