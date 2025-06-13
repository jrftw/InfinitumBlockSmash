import GoogleMobileAds
import SwiftUI
import StoreKit

// MARK: - Ad Configuration
struct AdConfig {
    static let bannerAdUnitID = "ca-app-pub-6815311336585204/5099168416"
    static let interstitialAdUnitID = "ca-app-pub-6815311336585204/3176321467"
    static let rewardedAdUnitID = "ca-app-pub-6815311336585204/5802484807"
    
    static func getBannerAdUnitID() -> String {
        return bannerAdUnitID
    }
    
    static func getInterstitialAdUnitID() -> String {
        return interstitialAdUnitID
    }
    
    static func getRewardedAdUnitID() -> String {
        return rewardedAdUnitID
    }
}

@MainActor
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    @Published private(set) var bannerAd: BannerView?
    @Published private(set) var interstitialAd: InterstitialAd?
    @Published private(set) var rewardedInterstitialAd: RewardedInterstitialAd?
    @Published private(set) var fallbackInterstitialAd: InterstitialAd?
    @Published private(set) var fallbackRewardedAd: RewardedInterstitialAd?
    @Published private(set) var isTopThreePlayer = false
    @Published var adDidDismiss = false
    @Published var isAdLoading = false
    @Published var adLoadFailed = false
    @Published var isLoadingIndicatorVisible = false
    
    // Add new state tracking properties
    @Published private(set) var adState: AdState = .idle
    @Published private(set) var lastAdShownTime: Date?
    @Published private(set) var adLoadAttempts: Int = 0
    @Published private(set) var adError: AdError?
    @Published private(set) var adsWatchedThisGame: Int = 0
    
    // Add ad frequency control
    private let minimumTimeBetweenAds: TimeInterval = 45 // Reduced to 45 seconds
    private let maximumAdsPerGame: Int = 8 // Increased to 8 ads per game
    private let maximumAdLoadAttempts: Int = 3
    private let adLoadTimeout: TimeInterval = 10 // 10 seconds timeout for ad loading
    
    enum AdState {
        case idle
        case loading
        case ready
        case showing
        case error
    }
    
    enum AdError: Error {
        case loadFailed
        case tooManyAttempts
        case tooFrequent
        case noAdsAvailable
        case userHasNoAds
        case timeout
    }
    
    private let subscriptionManager = SubscriptionManager.shared
    private let bannerAdUnitID = AdConfig.getBannerAdUnitID()
    private let interstitialAdUnitID = AdConfig.getInterstitialAdUnitID()
    private let rewardedInterstitialAdUnitID = AdConfig.getRewardedAdUnitID()
    
    private override init() {
        super.init()
        // Initialize the Google Mobile Ads SDK
        MobileAds.shared.start(completionHandler: { [weak self] (status: InitializationStatus) in
            print("Google Mobile Ads SDK initialization status: \(status)")
            // Preload all ad types after SDK is initialized
            Task { @MainActor [weak self] in
                await self?.preloadAllAds()
            }
        })
    }
    
    func checkTopThreeStatus() async {
        do {
            let result = try await LeaderboardService.shared.getLeaderboard(type: .score, period: "alltime")
            if let userID = UserDefaults.standard.string(forKey: "userID"),
               let userIndex = result.entries.firstIndex(where: { $0.id == userID }) {
                await MainActor.run {
                    isTopThreePlayer = userIndex < 3
                }
            }
        } catch {
            print("[AdManager] Error checking top three status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Ad Preloading
    
    private func preloadAllAds() async {
        await preloadBanner()
        await preloadInterstitial()
        await preloadRewardedInterstitial()
    }
    
    private func preloadInterstitial() async {
        guard await shouldShowAds() else { return }
        
        do {
            let request = Request()
            try await withTimeout(seconds: adLoadTimeout) {
                self.interstitialAd = try await InterstitialAd.load(with: AdConfig.getInterstitialAdUnitID(), request: request)
                self.interstitialAd?.fullScreenContentDelegate = self
                
                // Load fallback ad
                self.fallbackInterstitialAd = try await InterstitialAd.load(with: AdConfig.getInterstitialAdUnitID(), request: request)
                self.fallbackInterstitialAd?.fullScreenContentDelegate = self
            }
        } catch {
            print("Failed to preload interstitial ads: \(error.localizedDescription)")
        }
    }
    
    private func preloadRewardedInterstitial() async {
        guard await shouldShowAds() else { return }
        
        do {
            let request = Request()
            try await withTimeout(seconds: adLoadTimeout) {
                self.rewardedInterstitialAd = try await RewardedInterstitialAd.load(with: AdConfig.getRewardedAdUnitID(), request: request)
                self.rewardedInterstitialAd?.fullScreenContentDelegate = self
                
                // Load fallback ad
                self.fallbackRewardedAd = try await RewardedInterstitialAd.load(with: AdConfig.getRewardedAdUnitID(), request: request)
                self.fallbackRewardedAd?.fullScreenContentDelegate = self
            }
        } catch {
            print("Failed to preload rewarded interstitial ads: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Ad Display Logic
    
    private func shouldShowAds() async -> Bool {
        // Check if user has purchased the no-ads feature
        let hasNoAdsFeature = await subscriptionManager.hasFeature(.noAds)
        if hasNoAdsFeature {
            adError = .userHasNoAds
            return false
        }
        
        // Check if user has referral-based ad-free time
        if ReferralManager.shared.hasAdFreeTime() {
            return false
        }
        
        // Check ad frequency
        if let lastAdTime = lastAdShownTime {
            let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
            if timeSinceLastAd < minimumTimeBetweenAds {
                adError = .tooFrequent
                return false
            }
        }
        
        // Check maximum ads per game
        if adsWatchedThisGame >= maximumAdsPerGame {
            adError = .tooManyAttempts
            return false
        }
        
        return true
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
    
    // MARK: - Ad Performance Tracking
    
    private func trackAdPerformance(adType: String, success: Bool, error: Error? = nil) {
        Task {
            AnalyticsManager.shared.trackEvent(.performanceMetric(name: "ad_shown", value: success ? 1.0 : 0.0))
        }
    }
    
    // MARK: - Ad Availability Check
    
    func isAdAvailable() async -> Bool {
        return await shouldShowAds() && adState == .ready
    }
    
    // MARK: - Timeout Handling
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AdError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Interstitial Ads
    
    func loadInterstitial() async {
        adState = .loading
        adError = nil
        
        // Don't load ads if user has purchased no-ads
        guard await shouldShowAds() else {
            adState = .idle
            return
        }
        
        // Check load attempts
        if adLoadAttempts >= maximumAdLoadAttempts {
            adState = .error
            adError = .tooManyAttempts
            trackAdPerformance(adType: "interstitial", success: false, error: adError)
            return
        }
        
        // Clean up existing interstitial if any
        interstitialAd = nil
        
        do {
            let request = Request()
            try await withTimeout(seconds: adLoadTimeout) {
                self.interstitialAd = try await InterstitialAd.load(with: self.interstitialAdUnitID, request: request)
                self.interstitialAd?.fullScreenContentDelegate = self
                self.adState = .ready
                self.adLoadAttempts = 0
                self.trackAdPerformance(adType: "interstitial", success: true)
            }
        } catch {
            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
            adState = .error
            adError = error is AdError ? error as! AdError : .loadFailed
            adLoadAttempts += 1
            trackAdPerformance(adType: "interstitial", success: false, error: error)
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
        
        isLoadingIndicatorVisible = true
        
        if let ad = interstitialAd {
            adState = .showing
            ad.present(from: root)
            lastAdShownTime = Date()
            adsWatchedThisGame += 1
            // Preload next ad
            await preloadInterstitial()
        } else if let fallbackAd = fallbackInterstitialAd {
            adState = .showing
            fallbackAd.present(from: root)
            lastAdShownTime = Date()
            adsWatchedThisGame += 1
            // Preload next ad
            await preloadInterstitial()
        } else {
            await loadInterstitial()
        }
        
        isLoadingIndicatorVisible = false
    }
    
    // MARK: - Rewarded Interstitial Ads
    
    func loadRewardedInterstitial() async {
        adState = .loading
        adError = nil
        
        // Don't load ads if user has purchased no-ads
        guard await shouldShowAds() else {
            adState = .idle
            return
        }
        
        // Clean up existing rewarded interstitial if any
        rewardedInterstitialAd = nil
        
        do {
            let request = Request()
            try await withTimeout(seconds: adLoadTimeout) {
                self.rewardedInterstitialAd = try await RewardedInterstitialAd.load(with: self.rewardedInterstitialAdUnitID, request: request)
                self.rewardedInterstitialAd?.fullScreenContentDelegate = self
                self.adState = .ready
                self.adLoadFailed = false
                self.trackAdPerformance(adType: "rewarded", success: true)
            }
        } catch {
            print("Failed to load rewarded interstitial ad with error: \(error.localizedDescription)")
            adState = .error
            adError = error is AdError ? error as! AdError : .loadFailed
            adLoadFailed = true
            trackAdPerformance(adType: "rewarded", success: false, error: error)
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
        
        isLoadingIndicatorVisible = true
        
        if let ad = rewardedInterstitialAd {
            ad.present(from: root) {
                onReward()
            }
            // Preload next ad
            await preloadRewardedInterstitial()
        } else if let fallbackAd = fallbackRewardedAd {
            fallbackAd.present(from: root) {
                onReward()
            }
            // Preload next ad
            await preloadRewardedInterstitial()
        } else {
            await loadRewardedInterstitial()
        }
        
        isLoadingIndicatorVisible = false
    }
    
    // MARK: - Improved Cleanup
    
    func cleanup() {
        bannerAd?.removeFromSuperview()
        bannerAd = nil
        interstitialAd = nil
        rewardedInterstitialAd = nil
        adState = .idle
        adError = nil
        adLoadAttempts = 0
        adLoadFailed = false
    }
    
    func resetGameState() async {
        await MainActor.run {
            adsWatchedThisGame = 0
            adLoadAttempts = 0
            adState = .idle
            adError = nil
        }
    }
    
    // MARK: - Error Handling
    
    private func handleAdError(_ error: Error) {
        adError = .loadFailed
        adLoadFailed = true
        isLoadingIndicatorVisible = false
        
        // Show user-friendly error message
        NotificationCenter.default.post(
            name: NSNotification.Name("AdLoadError"),
            object: nil,
            userInfo: ["message": "Unable to load ad. Please try again later."]
        )
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            adDidDismiss = true
            adState = .idle
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
            adState = .error
            adError = .loadFailed
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
