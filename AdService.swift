import GoogleMobileAds
import SwiftUI

class AdService: NSObject, ObservableObject {
    static let shared = AdService()
    
    @Published var isAdLoaded = false
    @Published var adError: String?
    
    private var interstitial: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    private var bannerView: GADBannerView?
    
    private override init() {
        super.init()
        setupAds()
    }
    
    private func setupAds() {
        // Initialize the Google Mobile Ads SDK
        GADMobileAds.sharedInstance().start { status in
            print("[Ads] SDK initialization status: \(status)")
        }
        
        // Load initial ads
        loadInterstitial()
        loadRewardedAd()
    }
    
    // MARK: - Banner Ads
    
    func createBannerView() -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = "ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy" // Replace with your banner ad unit ID
        bannerView.rootViewController = UIApplication.shared.windows.first?.rootViewController
        bannerView.delegate = self
        bannerView.load(GADRequest())
        self.bannerView = bannerView
        return bannerView
    }
    
    // MARK: - Interstitial Ads
    
    func loadInterstitial() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: "ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy", // Replace with your interstitial ad unit ID
                             request: request) { [weak self] ad, error in
            if let error = error {
                print("[Ads] Failed to load interstitial ad: \(error.localizedDescription)")
                self?.adError = "Failed to load ad: \(error.localizedDescription)"
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            self?.isAdLoaded = true
        }
    }
    
    func showInterstitial(from viewController: UIViewController) {
        guard let interstitial = interstitial else {
            print("[Ads] Interstitial ad not ready")
            adError = "Ad not ready"
            loadInterstitial() // Try to load a new one
            return
        }
        
        interstitial.present(fromRootViewController: viewController)
    }
    
    // MARK: - Rewarded Ads
    
    func loadRewardedAd() {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: "ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy", // Replace with your rewarded ad unit ID
                          request: request) { [weak self] ad, error in
            if let error = error {
                print("[Ads] Failed to load rewarded ad: \(error.localizedDescription)")
                self?.adError = "Failed to load ad: \(error.localizedDescription)"
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }
    
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            print("[Ads] Rewarded ad not ready")
            adError = "Ad not ready"
            loadRewardedAd() // Try to load a new one
            completion(false)
            return
        }
        
        rewardedAd.present(fromRootViewController: viewController) { [weak self] in
            print("[Ads] User earned reward")
            completion(true)
            self?.loadRewardedAd() // Load the next rewarded ad
        }
    }
}

// MARK: - GADBannerViewDelegate

extension AdService: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("[Ads] Banner ad loaded successfully")
        isAdLoaded = true
        adError = nil
    }
    
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("[Ads] Banner ad failed to load: \(error.localizedDescription)")
        adError = "Failed to load ad: \(error.localizedDescription)"
        isAdLoaded = false
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdService: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("[Ads] Ad dismissed")
        isAdLoaded = false
        
        // Load the next ad
        if ad is GADInterstitialAd {
            loadInterstitial()
        } else if ad is GADRewardedAd {
            loadRewardedAd()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[Ads] Ad failed to present: \(error.localizedDescription)")
        adError = "Failed to present ad: \(error.localizedDescription)"
        isAdLoaded = false
    }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        print("[Ads] Ad impression recorded")
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        print("[Ads] Ad click recorded")
    }
} 