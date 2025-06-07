import GoogleMobileAds
import SwiftUI
import StoreKit

// MARK: - Ad Configuration
struct AdConfig {
    static let bannerAdUnitID = "ca-app-pub-6815311336585204/5099168416"
    static let interstitialAdUnitID = "ca-app-pub-6815311336585204/3176321467"
    static let rewardedAdUnitID = "ca-app-pub-6815311336585204/5802484807"
    
    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    
    static func shouldShowTestAds() -> Bool {
        #if DEBUG
        return true
        #else
        // Check if running in TestFlight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return true
        }
        return false
        #endif
    }
    
    static func getBannerAdUnitID() -> String {
        return shouldShowTestAds() ? testBannerAdUnitID : bannerAdUnitID
    }
    
    static func getInterstitialAdUnitID() -> String {
        return shouldShowTestAds() ? testInterstitialAdUnitID : interstitialAdUnitID
    }
    
    static func getRewardedAdUnitID() -> String {
        return shouldShowTestAds() ? testRewardedAdUnitID : rewardedAdUnitID
    }
}

@MainActor
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    @Published private(set) var bannerAd: BannerView?
    @Published private(set) var interstitialAd: InterstitialAd?
    @Published private(set) var rewardedInterstitialAd: RewardedInterstitialAd?
    @Published private(set) var isTopThreePlayer = false
    @Published var adDidDismiss = false
    @Published var isAdLoading = false
    @Published var adLoadFailed = false
    
    private let subscriptionManager = SubscriptionManager.shared
    private let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // Test ID
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Test ID
    private let rewardedInterstitialAdUnitID = "ca-app-pub-3940256099942544/1712485313" // Test ID
    
    private override init() {
        super.init()
        // Initialize the Google Mobile Ads SDK
        MobileAds.shared.start(completionHandler: { [weak self] (status: InitializationStatus) in
            // Handle initialization status if needed
            print("Google Mobile Ads SDK initialization status: \(status)")
            // Load initial ads after SDK is initialized
            Task { @MainActor [weak self] in
                await self?.preloadBanner()
            }
        })
    }
    
    func checkTopThreeStatus() async {
        do {
            let leaderboard = try await LeaderboardService.shared.getLeaderboard(type: .score, period: "alltime")
            if let userID = UserDefaults.standard.string(forKey: "userID"),
               let userIndex = leaderboard.firstIndex(where: { $0.id == userID }) {
                await MainActor.run {
                    isTopThreePlayer = userIndex < 3
                }
            }
        } catch {
            print("[AdManager] Error checking top three status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Ad Display Logic
    
    private func shouldShowAds() async -> Bool {
        // Check if user has purchased the no-ads feature
        let hasNoAdsFeature = await subscriptionManager.hasFeature(.noAds)
        if hasNoAdsFeature {
            return false
        }
        
        // Check if user has referral-based ad-free time
        return !ReferralManager.shared.hasAdFreeTime()
    }
    
    // MARK: - Banner Ads
    
    func preloadBanner() async {
        // Don't load ads if user has purchased no-ads
        guard await shouldShowAds() else { return }
        
        // Clean up existing banner if any
        bannerAd?.removeFromSuperview()
        bannerAd = nil
        
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = bannerAdUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .first
        banner.load(Request())
        self.bannerAd = banner
    }
    
    // MARK: - Interstitial Ads
    
    func loadInterstitial() async {
        // Don't load ads if user has purchased no-ads
        guard await shouldShowAds() else { return }
        
        // Clean up existing interstitial if any
        interstitialAd = nil
        
        do {
            let request = Request()
            interstitialAd = try await InterstitialAd.load(with: interstitialAdUnitID, request: request)
            interstitialAd?.fullScreenContentDelegate = self
        } catch {
            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
            adLoadFailed = true
        }
    }
    
    func showInterstitial() async {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController else {
            return
        }
        
        let shouldShow = await shouldShowAds()
        guard shouldShow else { return }
        
        if let ad = interstitialAd {
            ad.present(from: root)
        } else {
            await loadInterstitial()
        }
    }
    
    // MARK: - Rewarded Interstitial Ads
    
    func loadRewardedInterstitial() async {
        // Don't load ads if user has purchased no-ads
        guard await shouldShowAds() else { return }
        
        // Clean up existing rewarded interstitial if any
        rewardedInterstitialAd = nil
        
        do {
            let request = Request()
            rewardedInterstitialAd = try await RewardedInterstitialAd.load(with: rewardedInterstitialAdUnitID, request: request)
            rewardedInterstitialAd?.fullScreenContentDelegate = self
            adLoadFailed = false
        } catch {
            print("Failed to load rewarded interstitial ad with error: \(error.localizedDescription)")
            adLoadFailed = true
        }
    }
    
    func showRewardedInterstitial(onReward: @escaping () -> Void) async {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController else {
            return
        }
        
        let shouldShow = await shouldShowAds()
        guard shouldShow else { return }
        
        if let ad = rewardedInterstitialAd {
            ad.present(from: root) {
                onReward()
            }
        } else {
            await loadRewardedInterstitial()
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        bannerAd?.removeFromSuperview()
        bannerAd = nil
        interstitialAd = nil
        rewardedInterstitialAd = nil
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            adDidDismiss = true
            // Reload the ad for next time
            if ad is InterstitialAd {
                await loadInterstitial()
            } else if ad is RewardedInterstitialAd {
                await loadRewardedInterstitial()
            }
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("Ad failed to present with error: \(error.localizedDescription)")
            adLoadFailed = true
            // Reload the ad for next time
            if ad is InterstitialAd {
                await loadInterstitial()
            } else if ad is RewardedInterstitialAd {
                await loadRewardedInterstitial()
            }
        }
    }
} 
