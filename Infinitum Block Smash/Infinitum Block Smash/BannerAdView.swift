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
