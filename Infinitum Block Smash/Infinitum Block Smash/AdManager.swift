import GoogleMobileAds
import SwiftUI

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdManager()
    
    // Ad Unit IDs
    private let bannerAdUnitID = "ca-app-pub-6815311336585204/5099168416"
    private let interstitialAdUnitID = "ca-app-pub-6815311336585204/3176321467"
    private let rewardedAdUnitID = "ca-app-pub-6815311336585204/5802484807"
    
    // Ad instances
    private var interstitial: InterstitialAd?
    private var rewardedInterstitial: RewardedInterstitialAd?
    private(set) var bannerView: BannerView?
    
    // Published properties for UI updates
    @Published var adDidDismiss = false
    @Published var isAdLoading = false
    
    override init() {
        super.init()
        loadInterstitial()
        loadRewardedInterstitial()
        preloadBanner()
    }
    
    // MARK: - Banner Ad Preloading
    func preloadBanner() {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = bannerAdUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .first
        banner.load(Request())
        self.bannerView = banner
    }
    
    // MARK: - Interstitial Ads
    func loadInterstitial() {
        let request = Request()
        InterstitialAd.load(with: interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }
    
    func showInterstitial(from root: UIViewController) {
        if let ad = interstitial {
            ad.present(from: root)
        } else {
            print("Interstitial ad wasn't ready")
            loadInterstitial()
        }
    }
    
    // MARK: - Rewarded Interstitial Ads
    func loadRewardedInterstitial() {
        let request = Request()
        RewardedInterstitialAd.load(with: rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded interstitial ad with error: \(error.localizedDescription)")
                return
            }
            self?.rewardedInterstitial = ad
            self?.rewardedInterstitial?.fullScreenContentDelegate = self
        }
    }
    
    func showRewardedInterstitial(from root: UIViewController, onReward: @escaping () -> Void) {
        if let ad = rewardedInterstitial {
            ad.present(from: root) {
                onReward()
            }
        } else {
            print("Rewarded interstitial ad wasn't ready")
            loadRewardedInterstitial()
        }
    }
    
    // MARK: - GADFullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        adDidDismiss = true
        // Reload the ad for next time
        if ad is InterstitialAd {
            loadInterstitial()
        } else if ad is RewardedInterstitialAd {
            loadRewardedInterstitial()
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present with error: \(error.localizedDescription)")
        // Reload the ad for next time
        if ad is InterstitialAd {
            loadInterstitial()
        } else if ad is RewardedInterstitialAd {
            loadRewardedInterstitial()
        }
    }
} 
