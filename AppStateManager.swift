import SwiftUI
import StoreKit

class AppStateManager: ObservableObject {
    @Published var isOffline: Bool = false
    @Published var launchCount: Int = 0
    @Published var hasRated: Bool = false
    
    private let defaults = UserDefaults.standard
    private let launchCountKey = "appLaunchCount"
    private let hasRatedKey = "hasRatedApp"
    
    init() {
        loadState()
        checkConnectivity()
    }
    
    private func loadState() {
        launchCount = defaults.integer(forKey: launchCountKey)
        hasRated = defaults.bool(forKey: hasRatedKey)
        
        // Increment launch count
        launchCount += 1
        defaults.set(launchCount, forKey: launchCountKey)
        
        // Check if we should show rating prompt
        if launchCount >= 5 && !hasRated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.requestAppRating()
            }
        }
    }
    
    private func checkConnectivity() {
        // Simple connectivity check
        let url = URL(string: "https://www.apple.com")!
        let task = URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            DispatchQueue.main.async {
                self?.isOffline = error != nil
            }
        }
        task.resume()
    }
    
    func requestAppRating() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            hasRated = true
            defaults.set(true, forKey: hasRatedKey)
        }
    }
    
    func saveGameState(_ gameState: GameState) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(gameState) {
            defaults.set(encoded, forKey: "savedGameState")
        }
    }
    
    func loadGameState() -> GameState? {
        if let savedState = defaults.data(forKey: "savedGameState"),
           let gameState = try? JSONDecoder().decode(GameState.self, from: savedState) {
            return gameState
        }
        return nil
    }
} 