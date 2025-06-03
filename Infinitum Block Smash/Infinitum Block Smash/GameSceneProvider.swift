import SwiftUI
import SpriteKit

struct GameSceneProvider: View {
    @ObservedObject var gameState: GameState
    @State private var scene: GameScene? = nil
    
    var body: some View {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        let sceneSize = CGSize(width: width, height: height)
        SpriteView(scene: scene ?? GameScene(size: sceneSize, gameState: gameState))
            .ignoresSafeArea()
            .onAppear {
                print("[DEBUG] GameSceneProvider onAppear")
                if scene == nil {
                    let newScene = GameScene(size: sceneSize, gameState: gameState)
                    newScene.scaleMode = .aspectFill
                    scene = newScene
                }
            }
    }
} 