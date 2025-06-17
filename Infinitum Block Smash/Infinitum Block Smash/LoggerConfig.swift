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
    static let memorySystemEnabled = false
    static let networkMonitorEnabled = false
    static let firebaseManagerEnabled = false
    static let gameStateEnabled = false
    static let gameSceneEnabled = false
    static let analyticsManagerEnabled = false
    static let subscriptionManagerEnabled = false
    static let crashReporterEnabled = false
    static let securityLoggerEnabled = false
    static let appCheckEnabled = false
    static let gameCenterEnabled = false
    static let inAppMessagingEnabled = false
    static let cacheManagerEnabled = false
    static let forceLogoutEnabled = false
    
    // MARK: - Firebase Components
    static let firebaseAuthEnabled = false
    static let firebaseFirestoreEnabled = false
    static let firebaseRTDBEnabled = false
    static let firebaseAnalyticsEnabled = false
    static let firebaseCrashlyticsEnabled = false
    static let firebasePerformanceEnabled = false
    static let firebaseRemoteConfigEnabled = false
    static let firebaseMessagingEnabled = false
    
    // MARK: - Game Components
    static let gameUIEnabled = false
    static let gameGridEnabled = false
    static let gameTrayEnabled = false
    static let gameBlocksEnabled = false
    static let gameParticlesEnabled = false
    static let gamePhysicsEnabled = false
    static let gameAudioEnabled = false
    static let gameInputEnabled = false
    static let placementEnabled = false
    static let levelEnabled = false
    static let lineClearEnabled = false
    static let previewEnabled = false
    static let bonusEnabled = false
    static let achievementsEnabled = false
    
    // MARK: - System Components
    static let systemMemoryEnabled = false
    static let systemNetworkEnabled = false
    static let systemStorageEnabled = false
    static let systemPerformanceEnabled = false
    static let systemSecurityEnabled = false
    
    // MARK: - Feature Components
    static let featureSubscriptionEnabled = false
    static let featureAnalyticsEnabled = false
    static let featureInAppPurchaseEnabled = false
    static let featureGameCenterEnabled = false
    static let featureNotificationsEnabled = false
    
    // MARK: - General Categories
    static let generalEnabled = false
    static let debugEnabled = false
    static let errorEnabled = false
    static let warningEnabled = false
    static let infoEnabled = false
} 