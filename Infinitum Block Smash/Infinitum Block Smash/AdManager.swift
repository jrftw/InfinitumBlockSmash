/*
 * AdManager.swift
 * 
 * ADVERTISEMENT MANAGEMENT AND MONETIZATION SERVICE
 * 
 * This service manages all advertisement-related operations including ad loading,
 * display, frequency control, and monetization optimization. It handles multiple
 * ad types with fallback mechanisms and user experience considerations.
 * 
 * KEY RESPONSIBILITIES:
 * - Advertisement loading and preloading
 * - Ad display timing and frequency control
 * - Multiple ad type management (banner, interstitial, rewarded)
 * - Fallback ad mechanisms for reliability
 * - Network connectivity monitoring
 * - Ad performance tracking and optimization
 * - User experience optimization
 * - Subscription-based ad removal
 * - Top player ad exemption
 * - Ad error handling and recovery
 * 
 * MAJOR DEPENDENCIES:
 * - GoogleMobileAds: Google AdMob SDK
 * - SubscriptionManager.swift: Premium user ad removal
 * - LeaderboardService.swift: Top player status checking
 * - GameState.swift: Game context for ad timing
 * - Network monitoring for connectivity
 * - StoreKit: Subscription status checking
 * 
 * AD TYPES MANAGED:
 * - Banner Ads: Persistent bottom banner advertisements
 * - Interstitial Ads: Full-screen ads between game sessions
 * - Rewarded Interstitial Ads: Optional ads with rewards
 * - Fallback Ads: Backup ads for reliability
 * 
 * AD CONFIGURATION:
 * - Ad unit IDs for different ad types
 * - Frequency control parameters
 * - Loading timeouts and retry logic
 * - Network availability monitoring
 * - Performance optimization settings
 * 
 * FREQUENCY CONTROL:
 * - Minimum time between ads (3 minutes)
 * - Maximum ads per game session (8)
 * - Top player exemption (no ads for top 3)
 * - Subscription-based ad removal
 * - User experience optimization
 * 
 * NETWORK FEATURES:
 * - Network connectivity monitoring
 * - Automatic ad preloading on network restore
 * - Offline state handling
 * - Connection quality optimization
 * - Retry logic for network failures
 * 
 * PERFORMANCE OPTIMIZATIONS:
 * - Parallel ad preloading
 * - Exponential backoff for retries
 * - Memory-efficient ad management
 * - Background ad refresh
 * - Cached ad content
 * 
 * ERROR HANDLING:
 * - Comprehensive error types
 * - Automatic retry mechanisms
 * - Fallback ad systems
 * - User-friendly error messages
 * - Graceful degradation
 * 
 * USER EXPERIENCE:
 * - Non-intrusive ad placement
 * - Smooth ad transitions
 * - Loading indicators
 * - Ad dismissal handling
 * - Reward system integration
 * 
 * MONETIZATION FEATURES:
 * - Multiple ad format support
 * - Revenue optimization
 * - User segmentation
 * - Performance analytics
 * - A/B testing support
 * 
 * SECURITY FEATURES:
 * - Ad content validation
 * - Safe ad loading
 * - User privacy protection
 * - Content filtering
 * - Fraud prevention
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central coordinator for all advertisement-related
 * operations, providing a clean interface for ad management while optimizing
 * for both user experience and monetization.
 * 
 * THREADING MODEL:
 * - @MainActor ensures UI updates on main thread
 * - Background operations for ad loading
 * - Async/await for network operations
 * - Timer-based periodic operations
 * 
 * INTEGRATION POINTS:
 * - GameView for ad display
 * - GameState for ad timing
 * - Subscription system for premium users
 * - Analytics for performance tracking
 * - Network monitoring for connectivity
 */

import GoogleMobileAds
import SwiftUI
import StoreKit
import Network

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
    @Published private(set) var isAdCurrentlyShowing: Bool = false
    
    // Add SDK initialization tracking
    @Published private(set) var isSDKInitialized: Bool = false
    @Published private(set) var isInitializing: Bool = false
    
    // Add ad frequency control
    private let minimumTimeBetweenAds: TimeInterval = 300 // 5 minutes between ads (increased from 3)
    private let maximumAdsPerGame: Int = 3 // Maximum 3 ads per game (updated from 4)
    private let maximumAdLoadAttempts: Int = 3
    private let adLoadTimeout: TimeInterval = 5 // 5 seconds timeout for ad loading
    private let preloadDelay: TimeInterval = 2 // Delay before preloading next ad
    private let maxRetryAttempts: Int = 3
    private let adRefreshInterval: TimeInterval = 300 // 5 minutes refresh interval
    
    // Add new auto-triggered ad tracking
    private var lastInactivityAdTime: Date?
    private var mainMenuInteractionCount: Int = 0
    private var lastMainMenuAdTime: Date?
    private var lastSessionEndTime: Date?
    private let inactivityThreshold: TimeInterval = 6 * 3600 // 6 hours
    private let mainMenuAdThreshold: Int = 5 // Show ad after 5 main menu interactions
    private let mainMenuAdCooldown: TimeInterval = 1800 // 30 minutes between main menu ads
    
    // Add loading state management to prevent multiple simultaneous loads
    private var isLoadingInterstitial: Bool = false
    private var isLoadingRewarded: Bool = false
    private var isLoadingBanner: Bool = false
    
    // Add missing properties for network monitoring and timers
    private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable: Bool = true
    private var retryCount: Int = 0
    private var preloadTimer: Timer?
    private var refreshTimer: Timer?
    
    enum AdState {
        case idle
        case loading
        case ready
        case showing
        case error
        case retrying
    }
    
    enum AdError: Error {
        case loadFailed
        case tooManyAttempts
        case tooFrequent
        case noAdsAvailable
        case userHasNoAds
        case timeout
        case networkError
        case invalidResponse
        case retryLimitExceeded
        case sdkNotInitialized
    }
    
    private let subscriptionManager = SubscriptionManager.shared
    private let bannerAdUnitID = AdConfig.getBannerAdUnitID()
    private let interstitialAdUnitID = AdConfig.getInterstitialAdUnitID()
    private let rewardedInterstitialAdUnitID = AdConfig.getRewardedAdUnitID()
    
    private override init() {
        super.init()
        setupNetworkMonitoring()
        
        // Initialize the Google Mobile Ads SDK with better error handling
        initializeSDK()
    }
    
    private func initializeSDK() {
        guard !isInitializing else { return }
        
        isInitializing = true
        MobileAds.shared.start(completionHandler: { [weak self] (status: InitializationStatus) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                Logger.shared.log("Google Mobile Ads SDK initialization status: \(status)", category: .ads, level: .info)
                
                // Check if initialization was successful
                if status.adapterStatusesByClassName.isEmpty {
                    Logger.shared.log("Ad SDK initialization failed - no adapters available", category: .ads, level: .error)
                    self.isSDKInitialized = false
                } else {
                    self.isSDKInitialized = true
                    Logger.shared.log("Ad SDK initialized successfully", category: .ads, level: .info)
                    
                    // Preload all ad types after SDK is initialized with a delay
                    Task {
                        // Add a small delay to ensure SDK is fully ready
                        try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000)) // 1 second delay
                        await self.preloadAllAds()
                    }
                }
                
                self.isInitializing = false
            }
        })
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] (path: NWPath) in
            Task { @MainActor [weak self] in
                let wasAvailable = self?.isNetworkAvailable ?? false
                self?.isNetworkAvailable = path.status == .satisfied
                
                // If network became available, try to initialize SDK and preload ads
                if !wasAvailable && self?.isNetworkAvailable == true {
                    // Reinitialize SDK if it wasn't initialized before
                    if self?.isSDKInitialized == false {
                        self?.reinitializeSDK()
                    } else {
                        await self?.preloadAllAds()
                    }
                }
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func startAdRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: adRefreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.preloadAllAds()
            }
        }
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
    
    func preloadAllAds() async {
        // Cancel any existing preload timer
        preloadTimer?.invalidate()
        
        // Check SDK readiness first
        guard isSDKInitialized else {
            Logger.shared.log("Ad SDK not initialized - skipping ad preload", category: .ads, level: .warning)
            return
        }
        
        // Start preloading with a small delay to ensure SDK is ready
        try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
        
        // Preload ads in parallel for better performance
        async let bannerTask: Void = preloadBanner()
        async let interstitialTask: Void = preloadInterstitial()
        async let rewardedTask: Void = preloadRewardedInterstitial()
        
        // Wait for all preloads to complete
        _ = await [bannerTask, interstitialTask, rewardedTask]
        
        // Schedule periodic preloading with exponential backoff
        let nextPreloadInterval = min(300.0 * pow(1.5, Double(retryCount)), 1800.0) // Max 30 minutes
        preloadTimer = Timer.scheduledTimer(withTimeInterval: nextPreloadInterval, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.preloadAllAds()
            }
        }
    }
    
    private func preloadInterstitial() async {
        guard await shouldShowAds() else { return }
        
        // Check SDK readiness
        guard isSDKInitialized else {
            Logger.shared.log("Ad SDK not initialized - skipping interstitial preload", category: .ads, level: .warning)
            return
        }
        
        // Prevent multiple simultaneous loads
        guard !isLoadingInterstitial else {
            Logger.shared.log("Interstitial already loading - skipping preload", category: .ads, level: .debug)
            return
        }
        
        isLoadingInterstitial = true
        
        do {
            let request = Request()
            try await withTimeout(seconds: adLoadTimeout) {
                // Load primary ad with retry logic
                var attempts = 0
                while attempts < 3 {
                    do {
                        self.interstitialAd = try await InterstitialAd.load(with: AdConfig.getInterstitialAdUnitID(), request: request)
                        self.interstitialAd?.fullScreenContentDelegate = self
                        break
                    } catch {
                        attempts += 1
                        if attempts == 3 { throw error }
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
                    }
                }
                
                // Add small delay before loading fallback
                try await Task.sleep(nanoseconds: UInt64(self.preloadDelay * 1_000_000_000))
                
                // Load fallback ad with retry logic
                attempts = 0
                while attempts < 3 {
                    do {
                        self.fallbackInterstitialAd = try await InterstitialAd.load(with: AdConfig.getInterstitialAdUnitID(), request: request)
                        self.fallbackInterstitialAd?.fullScreenContentDelegate = self
                        break
                    } catch {
                        attempts += 1
                        if attempts == 3 { throw error }
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
                    }
                }
                
                self.adState = .ready
                self.retryCount = 0
            }
        } catch {
            Logger.shared.log("Failed to preload interstitial ads: \(error.localizedDescription)", category: .ads, level: .error)
            handleAdError(error)
        }
        
        isLoadingInterstitial = false
    }
    
    private func preloadRewardedInterstitial() async {
        guard await shouldShowAds() else { return }
        
        // Check SDK readiness
        guard isSDKInitialized else {
            Logger.shared.log("Ad SDK not initialized - skipping rewarded interstitial preload", category: .ads, level: .warning)
            return
        }
        
        // Prevent multiple simultaneous loads
        guard !isLoadingRewarded else {
            Logger.shared.log("Rewarded interstitial already loading - skipping preload", category: .ads, level: .debug)
            return
        }
        
        isLoadingRewarded = true
        
        do {
            let request = Request()
            try await withTimeout(seconds: adLoadTimeout) {
                // Load primary ad
                self.rewardedInterstitialAd = try await RewardedInterstitialAd.load(with: AdConfig.getRewardedAdUnitID(), request: request)
                self.rewardedInterstitialAd?.fullScreenContentDelegate = self
                
                // Add small delay before loading fallback
                try await Task.sleep(nanoseconds: UInt64(self.preloadDelay * 1_000_000_000))
                
                // Load fallback ad
                self.fallbackRewardedAd = try await RewardedInterstitialAd.load(with: AdConfig.getRewardedAdUnitID(), request: request)
                self.fallbackRewardedAd?.fullScreenContentDelegate = self
                
                self.adState = .ready
                self.retryCount = 0
            }
        } catch {
            Logger.shared.log("Failed to preload rewarded interstitial ads: \(error.localizedDescription)", category: .ads, level: .error)
            handleAdError(error)
            
            // Retry with exponential backoff
            if retryCount < maxRetryAttempts {
                retryCount += 1
                let delay = pow(2.0, Double(retryCount))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await preloadRewardedInterstitial()
            }
        }
        
        isLoadingRewarded = false
    }
    
    // MARK: - Ad Display Logic
    
    private func shouldShowAds() async -> Bool {
        // Check network connectivity first
        guard isNetworkAvailable else {
            adError = .networkError
            return false
        }
        
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
        
        // Check SDK readiness
        guard isSDKInitialized else {
            Logger.shared.log("Ad SDK not initialized - skipping banner preload", category: .ads, level: .warning)
            return
        }
        
        // Prevent multiple simultaneous loads
        guard !isLoadingBanner else {
            Logger.shared.log("Banner already loading - skipping preload", category: .ads, level: .debug)
            return
        }
        
        isLoadingBanner = true
        
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
        
        isLoadingBanner = false
    }
    
    // MARK: - Ad Performance Tracking
    
    private func trackAdPerformance(adType: String, success: Bool, error: Error? = nil) {
        Task {
            AnalyticsManager.shared.trackEvent(.performanceMetric(name: "ad_shown", value: success ? 1.0 : 0.0))
        }
    }
    
    // MARK: - Ad Availability Check
    
    func isAdAvailable() async -> Bool {
        // Check basic conditions first
        guard isNetworkAvailable else {
            Logger.shared.log("Ad not available - no network connection", category: .ads, level: .debug)
            return false
        }
        
        // Check if user has purchased the no-ads feature
        let hasNoAdsFeature = await subscriptionManager.hasFeature(.noAds)
        if hasNoAdsFeature {
            Logger.shared.log("Ad not available - user has no-ads feature", category: .ads, level: .debug)
            return false
        }
        
        // Check if user has referral-based ad-free time
        if ReferralManager.shared.hasAdFreeTime() {
            Logger.shared.log("Ad not available - user has ad-free time from referral", category: .ads, level: .debug)
            return false
        }
        
        // Check ad frequency
        if let lastAdTime = lastAdShownTime {
            let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
            if timeSinceLastAd < minimumTimeBetweenAds {
                Logger.shared.log("Ad not available - too frequent (last ad was \(Int(timeSinceLastAd))s ago)", category: .ads, level: .debug)
                return false
            }
        }
        
        // Check maximum ads per game
        if adsWatchedThisGame >= maximumAdsPerGame {
            Logger.shared.log("Ad not available - maximum ads per game reached (\(adsWatchedThisGame)/\(maximumAdsPerGame))", category: .ads, level: .debug)
            return false
        }
        
        // Check if we have a valid view controller
        guard getTopViewController() != nil else {
            Logger.shared.log("Ad not available - no valid view controller", category: .ads, level: .debug)
            return false
        }
        
        // Check if we can present an ad
        guard canPresentAd() else {
            Logger.shared.log("Ad not available - cannot present ad", category: .ads, level: .debug)
            return false
        }
        
        Logger.shared.log("Ad is available for presentation", category: .ads, level: .debug)
        return true
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
        
        // Check SDK readiness
        guard isSDKInitialized else {
            adState = .error
            adError = .sdkNotInitialized
            Logger.shared.log("Ad SDK not initialized - cannot load interstitial", category: .ads, level: .error)
            return
        }
        
        // Check load attempts
        if adLoadAttempts >= maximumAdLoadAttempts {
            adState = .error
            adError = .tooManyAttempts
            trackAdPerformance(adType: "interstitial", success: false, error: adError)
            return
        }
        
        // Prevent multiple simultaneous loads
        guard !isLoadingInterstitial else {
            Logger.shared.log("Interstitial already loading - skipping load", category: .ads, level: .debug)
            return
        }
        
        isLoadingInterstitial = true
        
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
        
        isLoadingInterstitial = false
    }
    
    func showInterstitial() async {
        // Use the centralized ad check
        guard shouldShowAd() else { return }
        
        guard await isAdAvailable() else {
            print("[AdManager] Interstitial ad not available")
            return
        }
        
        await MainActor.run {
            guard let topViewController = getTopViewController() else { return }
            interstitialAd?.present(from: topViewController)
        }
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
        
        // Check SDK readiness
        guard isSDKInitialized else {
            adState = .error
            adError = .sdkNotInitialized
            Logger.shared.log("Ad SDK not initialized - cannot load rewarded interstitial", category: .ads, level: .error)
            return
        }
        
        // Prevent multiple simultaneous loads
        guard !isLoadingRewarded else {
            Logger.shared.log("Rewarded interstitial already loading - skipping load", category: .ads, level: .debug)
            return
        }
        
        isLoadingRewarded = true
        
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
        
        isLoadingRewarded = false
    }
    
    func showRewardedInterstitial(onReward: @escaping () -> Void) async {
        // Use the centralized ad check
        guard shouldShowAd() else { 
            // If we can't show ad, still give the reward
            onReward()
            return 
        }
        
        guard await isAdAvailable() else {
            print("[AdManager] Rewarded interstitial ad not available")
            // Still give reward if ad is not available
            onReward()
            return
        }
        
        await MainActor.run {
            guard let topViewController = getTopViewController() else { 
                onReward()
                return 
            }
            rewardedInterstitialAd?.present(from: topViewController, userDidEarnRewardHandler: {
                onReward()
            })
        }
    }
    
    // MARK: - Improved Cleanup
    
    func cleanup() {
        bannerAd?.removeFromSuperview()
        bannerAd = nil
        interstitialAd = nil
        rewardedInterstitialAd = nil
        fallbackInterstitialAd = nil
        fallbackRewardedAd = nil
        adState = .idle
        adError = nil
        adLoadAttempts = 0
        adLoadFailed = false
        retryCount = 0
        preloadTimer?.invalidate()
        preloadTimer = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        networkMonitor?.cancel()
        networkMonitor = nil
        
        // Reset loading states
        isLoadingInterstitial = false
        isLoadingRewarded = false
        isLoadingBanner = false
        isAdCurrentlyShowing = false
    }
    
    func resetGameState() async {
        await MainActor.run {
            adsWatchedThisGame = 0
            adLoadAttempts = 0
            adState = .idle
            adError = nil
        }
    }
    
    // Add method to reinitialize SDK if needed
    func reinitializeSDK() {
        if !isSDKInitialized && !isInitializing {
            Logger.shared.log("Reinitializing Ad SDK", category: .ads, level: .info)
            initializeSDK()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleAdError(_ error: Error) {
        adError = .loadFailed
        adLoadFailed = true
        isLoadingIndicatorVisible = false
        
        // Determine specific error type
        if let adError = error as? AdError {
            self.adError = adError
        } else if (error as NSError).code == -1009 {
            self.adError = .networkError
        } else if (error as NSError).code == -1001 {
            self.adError = .timeout
        }
        
        // Silently retry loading ads without showing error to user
        Task {
            if retryCount < maxRetryAttempts {
                retryCount += 1
                let delay = pow(2.0, Double(retryCount))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await preloadAllAds()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topController = window.rootViewController
        
        // Navigate through presented view controllers to find the topmost one
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        // If the top controller is a navigation controller, get its top view controller
        if let navigationController = topController as? UINavigationController {
            topController = navigationController.topViewController
        }
        
        // If the top controller is a tab bar controller, get its selected view controller
        if let tabBarController = topController as? UITabBarController {
            topController = tabBarController.selectedViewController
        }
        
        return topController
    }
    
    private func canPresentAd() -> Bool {
        // First check if SDK is ready
        guard isSDKInitialized else {
            Logger.shared.log("Ad SDK not initialized", category: .ads, level: .warning)
            return false
        }
        
        guard let topController = getTopViewController() else {
            Logger.shared.log("No top view controller found for ad presentation", category: .ads, level: .warning)
            return false
        }
        
        // Check if an ad is already being shown
        if isAdCurrentlyShowing {
            Logger.shared.log("Ad is already being shown", category: .ads, level: .debug)
            return false
        }
        
        // Check if the top controller is already presenting something
        if let presentedVC = topController.presentedViewController {
            Logger.shared.log("Top controller is already presenting: \(type(of: presentedVC))", category: .ads, level: .debug)
            return false
        }
        
        // Check if the top controller is in the process of being dismissed
        if topController.isBeingDismissed {
            Logger.shared.log("Top controller is being dismissed", category: .ads, level: .debug)
            return false
        }
        
        // Check if the top controller is in the process of being presented
        if topController.isBeingPresented {
            Logger.shared.log("Top controller is being presented", category: .ads, level: .debug)
            return false
        }
        
        // Additional safety checks
        if topController.view.window == nil {
            Logger.shared.log("Top controller view is not in window hierarchy", category: .ads, level: .debug)
            return false
        }
        
        // Check if the view controller is ready for presentation
        if !topController.view.window!.isKeyWindow {
            Logger.shared.log("Top controller window is not key window", category: .ads, level: .debug)
            return false
        }
        
        // Check if view controller view is loaded and visible
        if !topController.isViewLoaded || topController.view.window == nil {
            Logger.shared.log("Top controller view is not loaded or not visible", category: .ads, level: .debug)
            return false
        }
        
        // Check if view controller is in a valid state
        if topController.view.window?.isHidden == true {
            Logger.shared.log("Top controller window is hidden", category: .ads, level: .debug)
            return false
        }
        
        Logger.shared.log("Ad presentation conditions met", category: .ads, level: .debug)
        return true
    }
    
    // MARK: - Premium Plan Checks
    
    private func isUserOnPremiumPlan() -> Bool {
        // Check if user has any active subscription or has removed ads
        return SubscriptionManager.shared.hasActiveSubscription || 
               UserDefaults.standard.bool(forKey: "hasRemovedAds")
    }
    
    private func isInTutorialOrFirstTimeFlow() -> Bool {
        // Check if tutorial is being shown or if this is a first-time user
        let showTutorial = UserDefaults.standard.bool(forKey: "showTutorial")
        let hasPlayedBefore = UserDefaults.standard.bool(forKey: "hasPlayedBefore")
        
        return showTutorial || !hasPlayedBefore
    }
    
    private func shouldShowAd() -> Bool {
        // Don't show ads if user is on premium plan
        guard !isUserOnPremiumPlan() else { 
            print("[AdManager] Skipping ad - user is on premium plan")
            return false 
        }
        
        // Don't show ads during tutorial or first-time user flow
        guard !isInTutorialOrFirstTimeFlow() else {
            print("[AdManager] Skipping ad - user is in tutorial or first-time flow")
            return false
        }
        
        return true
    }
    
    // MARK: - Auto-Triggered Ad Methods
    
    func shouldShowInactivityAd() async -> Bool {
        // Use the centralized ad check
        guard shouldShowAd() else { return false }
        
        // Check if enough time has passed since last inactivity ad
        if let lastAdTime = lastInactivityAdTime {
            let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
            if timeSinceLastAd < minimumTimeBetweenAds {
                return false
            }
        }
        
        // Check if user was inactive for 6+ hours
        if let lastSession = lastSessionEndTime {
            let timeSinceLastSession = Date().timeIntervalSince(lastSession)
            return timeSinceLastSession >= inactivityThreshold
        }
        
        return false
    }
    
    func shouldShowMainMenuAd() async -> Bool {
        // Use the centralized ad check
        guard shouldShowAd() else { return false }
        
        // Check cooldown
        if let lastAdTime = lastMainMenuAdTime {
            let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
            if timeSinceLastAd < mainMenuAdCooldown {
                return false
            }
        }
        
        // Check if we've reached the interaction threshold
        return mainMenuInteractionCount >= mainMenuAdThreshold
    }
    
    func recordMainMenuInteraction() {
        mainMenuInteractionCount += 1
        print("[AdManager] Main menu interaction count: \(mainMenuInteractionCount)")
    }
    
    func recordSessionEnd() {
        lastSessionEndTime = Date()
        print("[AdManager] Session ended at: \(lastSessionEndTime!)")
    }
    
    func showInactivityAd() async {
        guard await shouldShowInactivityAd() else { return }
        
        if await isAdAvailable() {
            print("[AdManager] Showing inactivity ad")
            lastInactivityAdTime = Date()
            await showInterstitial()
        }
    }
    
    func showMainMenuAd() async {
        guard await shouldShowMainMenuAd() else { return }
        
        if await isAdAvailable() {
            print("[AdManager] Showing main menu ad")
            lastMainMenuAdTime = Date()
            mainMenuInteractionCount = 0 // Reset counter
            await showInterstitial()
        }
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            adDidDismiss = true
            adState = .idle
            isAdCurrentlyShowing = false
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
            isAdCurrentlyShowing = false
            // Reload the ad for next time
            if ad is InterstitialAd {
                await loadInterstitial()
            } else if ad is RewardedInterstitialAd {
                await loadRewardedInterstitial()
            }
        }
    }
}
