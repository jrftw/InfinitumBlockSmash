/******************************************************
 * FILE: StartupManager.swift
 * MARK: App Startup Coordinator
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Manages the app startup sequence, ensuring all critical services are initialized
 * before the main UI is presented to the user.
 *
 * KEY RESPONSIBILITIES:
 * - Coordinate Firebase initialization
 * - Load subscription products
 * - Ensure minimum launch screen display time
 * - Manage startup timing and dependencies
 * - Provide startup status to UI components
 *
 * MAJOR DEPENDENCIES:
 * - FirebaseManager.swift: Core Firebase operations and data management
 * - SubscriptionManager.swift: In-app purchase product loading
 * - Task and async/await: For non-blocking startup operations
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for data structures
 * - Combine: Reactive programming for state management
 *
 * ARCHITECTURE ROLE:
 * Acts as the startup coordinator layer that ensures all critical services
 * are properly initialized before the main app interface is shown.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - FirebaseManager must initialize first
 * - Subscription products must load before UI presentation
 * - Minimum 7-second launch screen display time enforced
 * - All operations are async to prevent UI blocking
 */

/******************************************************
 * REVIEW NOTES:
 * - Startup timing is critical for user experience
 * - Firebase initialization must complete before proceeding
 * - Subscription loading is essential for purchase functionality
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add startup progress indicators
 * - Implement startup failure recovery
 * - Add startup performance metrics
 ******************************************************/

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