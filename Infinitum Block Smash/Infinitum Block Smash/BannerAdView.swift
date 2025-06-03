import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        #if DEBUG
        banner.adUnitID = AdConfig.testBannerAdUnitID
        #else
        banner.adUnitID = AdConfig.bannerAdUnitID
        #endif
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .first
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
    
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner failed to load: \(error.localizedDescription)")
            // Silent fail: do not update UI
        }
    }
} 
