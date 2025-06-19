/*
 * AppOpenManager.swift
 * 
 * MAIN PURPOSE:
 * Manages app launch events and triggers user engagement prompts based on app usage patterns.
 * Handles rating prompts and referral prompts at specific app open intervals to improve
 * user engagement and app store ratings for Infinitum Block Smash.
 * 
 * KEY FUNCTIONALITY:
 * - Tracks app open count using UserDefaults
 * - Shows rating prompt on 3rd app open if user hasn't rated
 * - Shows referral prompt on 5th app open if not shown before
 * - Manages StoreKit review requests
 * - Prevents duplicate prompts through persistent flags
 * - Uses @MainActor for UI thread safety
 * 
 * DEPENDENCIES:
 * - SwiftUI: ObservableObject for reactive UI updates
 * - StoreKit: App store review functionality
 * - UserDefaults: Persistent storage for app open count and flags
 * - UIKit: UIApplication for accessing app scenes
 * 
 * FILES THAT USE THIS:
 * - ContentView.swift: Likely observes and displays prompts
 * - RatingPromptView.swift: UI component for rating prompts
 * - ReferralPromptView.swift: UI component for referral prompts
 * - Main app file: May initialize this manager on app launch
 * 
 * FILES THIS USES EXTENSIVELY:
 * - UserDefaults: For tracking app opens and prompt states
 * - StoreKit: For requesting app store reviews
 * 
 * DATA FLOW:
 * 1. App launches and AppOpenManager initializes
 * 2. App open count is incremented and stored
 * 3. Manager checks if prompts should be shown
 * 4. UI components observe and display appropriate prompts
 * 5. User interactions mark prompts as shown
 * 
 * REVIEW NOTES:
 * 
 * POTENTIAL ISSUES:
 * - Hard-coded thresholds (3rd and 5th open) may not be optimal for all users
 * - No consideration for user engagement level before showing prompts
 * - UserDefaults keys could conflict with other components
 * - No analytics tracking for prompt effectiveness
 * - No fallback if StoreKit review request fails
 * - Prompts may show even if user is in middle of gameplay
 * 
 * AREAS FOR IMPROVEMENT:
 * - Add analytics tracking for prompt interactions
 * - Implement dynamic thresholds based on user behavior
 * - Add prompt scheduling based on user engagement
 * - Consider user session length before showing prompts
 * - Add A/B testing for different prompt timings
 * - Implement prompt frequency limits
 * - Add user preference to disable prompts
 * 
 * DEPENDENCY CONCERNS:
 * - Direct dependency on UserDefaults for all state management
 * - StoreKit dependency may not work in all environments
 * - No dependency injection - tightly coupled to UserDefaults
 * - UIApplication access may not work in all contexts
 * 
 * DATE: 6/19/2025
 * AUTHOR: @jrftw
 */

import SwiftUI
import StoreKit

@MainActor
class AppOpenManager: ObservableObject {
    static let shared = AppOpenManager()
    
    @Published var showingRatingPrompt = false
    @Published var showingReferralPrompt = false
    
    private let ratingPromptThreshold = 3
    private let referralPromptThreshold = 5
    private let userDefaults = UserDefaults.standard
    private let appOpenCountKey = "appOpenCount"
    private let hasRatedKey = "hasRated"
    private let hasShownReferralKey = "hasShownReferral"
    
    private init() {
        incrementAppOpenCount()
        checkAndShowPrompts()
    }
    
    private func incrementAppOpenCount() {
        let currentCount = userDefaults.integer(forKey: appOpenCountKey)
        userDefaults.set(currentCount + 1, forKey: appOpenCountKey)
    }
    
    private func checkAndShowPrompts() {
        let appOpenCount = userDefaults.integer(forKey: appOpenCountKey)
        let hasRated = userDefaults.bool(forKey: hasRatedKey)
        let hasShownReferral = userDefaults.bool(forKey: hasShownReferralKey)
        
        // Show rating prompt on 3rd open if not rated
        if appOpenCount == ratingPromptThreshold && !hasRated {
            showingRatingPrompt = true
        }
        
        // Show referral prompt on 5th open if not shown before
        if appOpenCount == referralPromptThreshold && !hasShownReferral {
            showingReferralPrompt = true
        }
    }
    
    func markRatingAsShown() {
        showingRatingPrompt = false
        userDefaults.set(true, forKey: hasRatedKey)
    }
    
    func markReferralAsShown() {
        showingReferralPrompt = false
        userDefaults.set(true, forKey: hasShownReferralKey)
    }
    
    func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            markRatingAsShown()
        }
    }
} 