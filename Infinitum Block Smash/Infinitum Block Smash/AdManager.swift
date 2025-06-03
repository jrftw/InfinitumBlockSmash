import GoogleMobileAds
import SwiftUI

// MARK: - Ad Configuration
struct AdConfig {
    static let bannerAdUnitID = "ca-app-pub-6815311336585204/5099168416"
    static let interstitialAdUnitID = "ca-app-pub-6815311336585204/3176321467"
    static let rewardedAdUnitID = "ca-app-pub-6815311336585204/5802484807"
    
    #if DEBUG
    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    #endif
}

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdManager()
    
    // Ad instances
    private var interstitial: InterstitialAd?
    private var rewardedInterstitial: RewardedInterstitialAd?
    private(set) var bannerView: BannerView?
    
    // Published properties for UI updates
    @Published var adDidDismiss = false
    @Published var isAdLoading = false
    @Published var adLoadFailed = false // For silent debugging only
    
    override init() {
        super.init()
        // Load ads only when needed
        preloadBanner()
    }
    
    // MARK: - Banner Ad Preloading
    func preloadBanner() {
        // Clean up existing banner if any
        bannerView?.removeFromSuperview()
        bannerView = nil
        
        let banner = BannerView(adSize: AdSizeBanner)
        #if DEBUG
        banner.adUnitID = AdConfig.testBannerAdUnitID
        #else
        banner.adUnitID = AdConfig.bannerAdUnitID
        #endif
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .first
        banner.load(Request())
        self.bannerView = banner
    }
    
    // MARK: - Interstitial Ads
    func loadInterstitial() {
        // Clean up existing interstitial if any
        interstitial = nil
        
        let request = Request()
        #if DEBUG
        InterstitialAd.load(with: AdConfig.testInterstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
        #else
        InterstitialAd.load(with: AdConfig.interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
        #endif
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
        // Clean up existing rewarded interstitial if any
        rewardedInterstitial = nil
        
        let request = Request()
        #if DEBUG
        RewardedInterstitialAd.load(with: AdConfig.testRewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded interstitial ad with error: \(error.localizedDescription)")
                self?.adLoadFailed = true
                return
            }
            self?.rewardedInterstitial = ad
            self?.rewardedInterstitial?.fullScreenContentDelegate = self
            self?.adLoadFailed = false
        }
        #else
        RewardedInterstitialAd.load(with: AdConfig.rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded interstitial ad with error: \(error.localizedDescription)")
                self?.adLoadFailed = true
                return
            }
            self?.rewardedInterstitial = ad
            self?.rewardedInterstitial?.fullScreenContentDelegate = self
            self?.adLoadFailed = false
        }
        #endif
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
        self.adLoadFailed = true // Silent fail
        // Reload the ad for next time
        if ad is InterstitialAd {
            loadInterstitial()
        } else if ad is RewardedInterstitialAd {
            loadRewardedInterstitial()
        }
    }
    
    func cleanup() {
        bannerView?.removeFromSuperview()
        bannerView = nil
        interstitial = nil
        rewardedInterstitial = nil
    }
} 
