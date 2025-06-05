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
            print("Banner failed to load: \(error.localizedDescription)")
            // Silent fail: do not update UI
        }
    }
} 
