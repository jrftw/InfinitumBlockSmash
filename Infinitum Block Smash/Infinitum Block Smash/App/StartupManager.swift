import Foundation
import Combine

class StartupManager: ObservableObject {
    @Published var isReady: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Task {
            await self.performStartup()
        }
    }
    
    @MainActor
    private func performStartup() async {
        print("[StartupManager] Starting initialization...")
        
        // Wait for FirebaseManager to finish initializing
        _ = FirebaseManager.shared
        // Add a delay to ensure FirebaseManager has time to initialize
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Wait for SubscriptionManager to finish loading products
        print("[StartupManager] Loading subscription products...")
        await SubscriptionManager.shared.loadProducts()
        
        // Add any other async startup tasks here
        // ...
        
        // Ensure minimum display time for launch screen (7 seconds)
        // This gives users plenty of time to read tips and see the loading animation
        try? await Task.sleep(nanoseconds: 7_000_000_000) // 7 seconds
        
        print("[StartupManager] Initialization complete")
        isReady = true
    }
} 