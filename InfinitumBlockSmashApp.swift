import SwiftUI

@main
struct InfinitumBlockSmashApp: App {
    @StateObject private var appStateManager = AppStateManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            GameView()
                .environmentObject(appStateManager)
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        // App became active
                        if let savedState = appStateManager.loadGameState() {
                            // Restore game state if available
                            NotificationCenter.default.post(
                                name: NSNotification.Name("RestoreGameState"),
                                object: savedState
                            )
                        }
                    case .inactive:
                        // App became inactive
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SaveGameState"),
                            object: nil
                        )
                    case .background:
                        // App entered background
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SaveGameState"),
                            object: nil
                        )
                    @unknown default:
                        break
                    }
                }
        }
    }
} 