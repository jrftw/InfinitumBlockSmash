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