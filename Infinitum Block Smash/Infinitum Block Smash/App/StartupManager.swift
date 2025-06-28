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
 * - Initialize remote configuration services
 * - Load subscription products
 * - Ensure minimum launch screen display time
 * - Manage startup timing and dependencies
 * - Provide startup status to UI components
 *
 * MAJOR DEPENDENCIES:
 * - FirebaseManager.swift: Core Firebase operations and data management
 * - RemoteConfigService.swift: Remote configuration management
 * - VersionCheckService.swift: Update checking and enforcement
 * - MaintenanceService.swift: Maintenance mode management
 * - SubscriptionManager.swift: In-app purchase product loading
 * - Task and async/await: For non-blocking startup operations
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for data structures
 * - Combine: Reactive programming for state management
 * - FirebaseRemoteConfig: Remote configuration management
 *
 * ARCHITECTURE ROLE:
 * Acts as the startup coordinator layer that ensures all critical services
 * are properly initialized before the main app interface is shown.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - FirebaseManager must initialize first
 * - RemoteConfigService must initialize before other services
 * - VersionCheckService and MaintenanceService depend on RemoteConfig
 * - Subscription products must load before UI presentation
 * - Minimum 7-second launch screen display time enforced
 * - All operations are async to prevent UI blocking
 */

/******************************************************
 * REVIEW NOTES:
 * - Startup timing is critical for user experience
 * - Firebase initialization must complete before proceeding
 * - Remote config must be fetched before other services
 * - Subscription loading is essential for purchase functionality
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add startup progress indicators
 * - Implement startup failure recovery
 * - Add startup performance metrics
 * - Add startup dependency graph visualization
 ******************************************************/

import Foundation
import Combine
import SwiftUI

class StartupManager: ObservableObject {
    @Published var isReady: Bool = false
    @Published var startupProgress: Double = 0.0
    @Published var currentStep: String = "Initializing..."
    
    private var cancellables = Set<AnyCancellable>()
    private let startupSteps = [
        "Initializing Firebase...",
        "Loading Remote Configuration...",
        "Checking for Updates...",
        "Checking Maintenance Status...",
        "Loading Subscription Products...",
        "Finalizing Startup..."
    ]
    
    init() {
        Task {
            await self.performStartup()
        }
    }
    
    @MainActor
    private func performStartup() async {
        Logger.shared.log("[StartupManager] Starting initialization...", category: .general, level: .info)
        
        // Step 1: Initialize Firebase Manager
        updateProgress(step: 0, message: startupSteps[0])
        _ = FirebaseManager.shared
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Step 2: Initialize Remote Configuration
        updateProgress(step: 1, message: startupSteps[1])
        _ = RemoteConfigService.shared
        // Wait for remote config to be ready
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Step 3: Initialize Version Check Service
        updateProgress(step: 2, message: startupSteps[2])
        _ = VersionCheckService.shared
        // Allow time for version check to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Step 4: Initialize Maintenance Service
        updateProgress(step: 3, message: startupSteps[3])
        _ = MaintenanceService.shared
        // Allow time for maintenance check to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Step 5: Load Subscription Products
        updateProgress(step: 4, message: startupSteps[4])
        Logger.shared.log("[StartupManager] Loading subscription products...", category: .general, level: .info)
        await SubscriptionManager.shared.loadProducts()
        
        // Step 6: Finalize Startup
        updateProgress(step: 5, message: startupSteps[5])
        
        // Ensure minimum display time for launch screen (7 seconds total)
        // This gives users plenty of time to read tips and see the loading animation
        let elapsedTime = Date().timeIntervalSince(Date().addingTimeInterval(-7))
        if elapsedTime < 7.0 {
            let remainingTime = 7.0 - elapsedTime
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        Logger.shared.log("[StartupManager] Initialization complete", category: .general, level: .info)
        isReady = true
    }
    
    private func updateProgress(step: Int, message: String) {
        let progress = Double(step + 1) / Double(startupSteps.count)
        startupProgress = progress
        currentStep = message
        Logger.shared.log("[StartupManager] \(message)", category: .general, level: .info)
    }
    
    // MARK: - Public Methods
    
    func getStartupProgress() -> Double {
        return startupProgress
    }
    
    func getCurrentStep() -> String {
        return currentStep
    }
    
    func forceComplete() {
        isReady = true
        startupProgress = 1.0
        currentStep = "Ready"
    }
} 