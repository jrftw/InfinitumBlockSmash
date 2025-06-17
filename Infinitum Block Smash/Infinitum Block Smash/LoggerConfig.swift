import Foundation

/// Configuration for the logging system
/// Updated with new logging categories for game components
/// Last updated: 2024-03-17
struct LoggerConfig {
    // MARK: - Global Settings
    static let loggingEnabled = true
    
    // MARK: - Log Levels
    static let debugLevelEnabled = true
    static let infoLevelEnabled = true
    static let warningLevelEnabled = true
    static let errorLevelEnabled = true
    static let criticalLevelEnabled = true
    
    // MARK: - Score and Leaderboard Categories
    static let scoreEnabled = true
    static let leaderboardEnabled = true
    static let leaderboardWriteEnabled = true
    static let leaderboardCacheEnabled = true
    static let highscoreEnabled = true
    
    // MARK: - Core Systems
    static let memorySystemEnabled = true
    static let networkMonitorEnabled = true
    static let firebaseManagerEnabled = true
    static let gameStateEnabled = true
    static let gameSceneEnabled = true
    static let analyticsManagerEnabled = true
    static let subscriptionManagerEnabled = true
    static let crashReporterEnabled = true
    static let securityLoggerEnabled = true
    static let appCheckEnabled = true
    static let gameCenterEnabled = true
    static let inAppMessagingEnabled = true
    static let cacheManagerEnabled = true
    static let forceLogoutEnabled = true
    
    // MARK: - Firebase Components
    static let firebaseAuthEnabled = true
    static let firebaseFirestoreEnabled = true
    static let firebaseRTDBEnabled = true
    static let firebaseAnalyticsEnabled = true
    static let firebaseCrashlyticsEnabled = true
    static let firebasePerformanceEnabled = true
    static let firebaseRemoteConfigEnabled = true
    static let firebaseMessagingEnabled = true
    
    // MARK: - Game Components
    static let gameUIEnabled = true
    static let gameGridEnabled = true
    static let gameTrayEnabled = true
    static let gameBlocksEnabled = true
    static let gameParticlesEnabled = true
    static let gamePhysicsEnabled = true
    static let gameAudioEnabled = true
    static let gameInputEnabled = true
    static let placementEnabled = true
    static let levelEnabled = true
    static let lineClearEnabled = true
    static let previewEnabled = true
    static let bonusEnabled = true
    static let achievementsEnabled = true
    
    // MARK: - Debug Categories
    static let debugGameSceneEnabled = true
    static let debugGameStateEnabled = true
    static let debugGameProviderEnabled = true
    
    // MARK: - System Components
    static let systemMemoryEnabled = true
    static let systemNetworkEnabled = true
    static let systemStorageEnabled = true
    static let systemPerformanceEnabled = true
    static let systemSecurityEnabled = true
    
    // MARK: - Feature Components
    static let featureSubscriptionEnabled = true
    static let featureAnalyticsEnabled = true
    static let featureInAppPurchaseEnabled = true
    static let featureGameCenterEnabled = true
    static let featureNotificationsEnabled = true
    
    // MARK: - General Categories
    static let generalEnabled = true
    static let debugEnabled = true
    static let errorEnabled = true
    static let warningEnabled = true
    static let infoEnabled = true
} 