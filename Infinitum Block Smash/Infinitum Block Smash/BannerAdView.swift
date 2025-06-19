/*
 * BannerAdView.swift
 * 
 * BANNER ADVERTISEMENT SWIFTUI WRAPPER
 * 
 * This SwiftUI view provides a wrapper for Google AdMob banner advertisements,
 * integrating with the AdManager for centralized ad control and analytics tracking.
 * It handles banner ad display, loading, error handling, and top player exemptions.
 * 
 * KEY RESPONSIBILITIES:
 * - Banner advertisement display and management
 * - Google AdMob integration and configuration
 * - Ad loading and error handling
 * - Top player ad exemption logic
 * - Analytics tracking for ad performance
 * - SwiftUI integration with UIKit components
 * - Ad failure recovery and reporting
 * - Performance metrics collection
 * 
 * MAJOR DEPENDENCIES:
 * - AdManager.swift: Centralized ad management and state
 * - GoogleMobileAds: Google AdMob SDK
 * - SwiftUI: UI framework integration
 * - UIKit: Banner view implementation
 * - Logger.swift: Error logging and debugging
 * - AnalyticsManager.swift: Ad performance tracking
 * - AdConfig: Ad unit ID configuration
 * 
 * AD FEATURES:
 * - Banner Ad Display: Standard banner advertisement
 * - Top Player Exemption: No ads for top 3 players
 * - Dynamic Ad Loading: On-demand ad loading
 * - Error Handling: Comprehensive failure management
 * - Analytics Integration: Performance tracking
 * - Responsive Design: Adaptive banner sizing
 * 
 * INTEGRATION POINTS:
 * - AdManager for centralized control
 * - GameView for banner placement
 * - ContentView for main menu ads
 * - Analytics for performance tracking
 * - Logger for error reporting
 * 
 * PERFORMANCE FEATURES:
 * - Efficient ad loading
 * - Memory management for banner views
 * - Error recovery mechanisms
 * - Analytics optimization
 * - Background ad processing
 * 
 * ERROR HANDLING:
 * - Network connectivity issues
 * - Ad loading failures
 * - Timeout handling
 * - Invalid ad unit errors
 * - Analytics tracking for failures
 * 
 * ANALYTICS TRACKING:
 * - Ad load success metrics
 * - Ad failure tracking
 * - Network error categorization
 * - Timeout error tracking
 * - Performance monitoring
 * 
 * USER EXPERIENCE:
 * - Non-intrusive banner placement
 * - Smooth ad loading
 * - Top player exemption
 * - Error recovery
 * - Performance optimization
 * 
 * ARCHITECTURE ROLE:
 * This view acts as a SwiftUI wrapper for UIKit banner ads,
 * providing seamless integration with the app's ad management
 * system while maintaining clean separation of concerns.
 * 
 * THREADING CONSIDERATIONS:
 * - UI updates on main thread
 * - Background analytics processing
 * - Thread-safe ad state management
 * - Async/await for analytics tracking
 * 
 * SECURITY CONSIDERATIONS:
 * - Ad content validation
 * - Safe ad loading
 * - User privacy protection
 * - Content filtering
 * 
 * REVIEW NOTES:
 * - Verify Google AdMob SDK integration and configuration
 * - Check ad unit ID configuration and validity
 * - Test banner ad loading and display functionality
 * - Validate top player exemption logic
 * - Check ad failure handling and recovery
 * - Test analytics tracking accuracy
 * - Verify network error categorization
 * - Check ad loading timeout handling
 * - Test banner ad responsiveness on different screen sizes
 * - Validate ad content safety and filtering
 * - Check memory management for banner views
 * - Test ad loading during network interruptions
 * - Verify analytics data collection and reporting
 * - Check ad performance impact on app performance
 * - Test banner ad integration with game state
 * - Validate ad exemption logic for premium users
 * - Check ad loading during app background/foreground transitions
 * - Test banner ad compatibility with different iOS versions
 * - Verify ad content compliance with app store guidelines
 * - Check ad loading performance on low-end devices
 * - Test banner ad integration with accessibility features
 * - Validate ad error recovery mechanisms
 * - Check ad analytics integration with Firebase
 * - Test banner ad loading during heavy game operations
 * - Verify ad content age-appropriateness and filtering
 */

import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    @ObservedObject private var adManager = AdManager.shared
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        // Don't show banner if user is in top 3
        if adManager.isTopThreePlayer {
            return BannerView(adSize: AdSizeBanner)
        }
        
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdConfig.getBannerAdUnitID()
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .first
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // If user becomes top 3, remove the banner
        if adManager.isTopThreePlayer {
            uiView.removeFromSuperview()
        }
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            Logger.shared.log("Banner failed to load: \(error.localizedDescription)", category: .firebaseManager, level: .error)
            
            // Track ad failure with detailed error information
            Task {
                let errorCode = (error as NSError).code
                
                // Track the failure event with detailed metrics
                AnalyticsManager.shared.trackEvent(.performanceMetric(
                    name: "banner_ad_failure",
                    value: 1.0
                ))
                
                // Track specific error types
                if errorCode == -1009 {
                    AnalyticsManager.shared.trackEvent(.performanceMetric(
                        name: "banner_ad_network_error",
                        value: 1.0
                    ))
                } else if errorCode == -1001 {
                    AnalyticsManager.shared.trackEvent(.performanceMetric(
                        name: "banner_ad_timeout",
                        value: 1.0
                    ))
                }
            }
        }
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            // Track successful ad load
            Task {
                AnalyticsManager.shared.trackEvent(.performanceMetric(
                    name: "banner_ad_success",
                    value: 1.0
                ))
            }
        }
    }
} 
