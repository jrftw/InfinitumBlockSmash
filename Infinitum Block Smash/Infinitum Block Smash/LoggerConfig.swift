import Foundation

/// Configuration for the logging system
/// Updated with new logging categories for game components
/// Last updated: 2024-03-17
struct LoggerConfig {
    // MARK: - Global Settings
    #if DEBUG
    static let loggingEnabled = true
    #else
    static let loggingEnabled = false
    #endif
    
    // MARK: - Log Levels
    #if DEBUG
    static let debugLevelEnabled = true
    #else
    static let debugLevelEnabled = false
    #endif
    static let infoLevelEnabled = true
    static let warningLevelEnabled = true
    static let errorLevelEnabled = true
    static let criticalLevelEnabled = true
    
    // MARK: - Score and Leaderboard Categories
    #if DEBUG
    static let scoreEnabled = true
    static let leaderboardEnabled = true
    static let leaderboardWriteEnabled = true
    static let leaderboardCacheEnabled = true
    static let highscoreEnabled = true
    #else
    // In release builds, only log leaderboard errors and significant score improvements
    static let scoreEnabled = false
    static let leaderboardEnabled = false
    static let leaderboardWriteEnabled = false
    static let leaderboardCacheEnabled = false
    static let highscoreEnabled = false
    #endif
    
    // MARK: - Core Systems
    static let memorySystemEnabled = true
    static let networkMonitorEnabled = true
    #if DEBUG
    static let firebaseManagerEnabled = true
    static let gameStateEnabled = true
    static let gameSceneEnabled = true
    #else
    // Reduce Firebase manager logging in release builds
    static let firebaseManagerEnabled = false
    static let gameStateEnabled = false
    static let gameSceneEnabled = false
    #endif
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
    #if DEBUG
    static let firebaseAuthEnabled = true
    static let firebaseFirestoreEnabled = true
    static let firebaseRTDBEnabled = true
    static let firebaseAnalyticsEnabled = true
    static let firebaseCrashlyticsEnabled = true
    static let firebasePerformanceEnabled = true
    static let firebaseRemoteConfigEnabled = true
    static let firebaseMessagingEnabled = true
    #else
    // In release builds, only log Firebase errors and critical events
    static let firebaseAuthEnabled = false
    static let firebaseFirestoreEnabled = false
    static let firebaseRTDBEnabled = false
    static let firebaseAnalyticsEnabled = false
    static let firebaseCrashlyticsEnabled = true // Keep crashlytics enabled
    static let firebasePerformanceEnabled = false
    static let firebaseRemoteConfigEnabled = false
    static let firebaseMessagingEnabled = false
    #endif
    
    // MARK: - Game Components
    static let gameUIEnabled = true
    static let gameGridEnabled = true
    static let gameTrayEnabled = true
    static let gameBlocksEnabled = true
    static let gameParticlesEnabled = true
    static let gamePhysicsEnabled = true
    static let gameAudioEnabled = true
    static let gameInputEnabled = true
    #if DEBUG
    static let placementEnabled = true
    static let levelEnabled = true
    static let lineClearEnabled = true
    static let previewEnabled = true
    #else
    static let placementEnabled = false
    static let levelEnabled = false
    static let lineClearEnabled = false
    static let previewEnabled = false
    #endif
    static let bonusEnabled = true
    static let achievementsEnabled = true
    
    // MARK: - Debug Categories
    #if DEBUG
    static let debugGameSceneEnabled = true
    static let debugGameStateEnabled = true
    static let debugGameProviderEnabled = true
    #else
    static let debugGameSceneEnabled = false
    static let debugGameStateEnabled = false
    static let debugGameProviderEnabled = false
    #endif
    
    // MARK: - System Components
    #if DEBUG
    static let systemMemoryEnabled = true
    static let systemNetworkEnabled = true
    static let systemStorageEnabled = true
    static let systemPerformanceEnabled = true
    static let systemSecurityEnabled = true
    #else
    // In release builds, only log critical system issues
    static let systemMemoryEnabled = false
    static let systemNetworkEnabled = false
    static let systemStorageEnabled = false
    static let systemPerformanceEnabled = false
    static let systemSecurityEnabled = true // Keep security logging
    #endif
    
    // MARK: - Feature Components
    static let featureSubscriptionEnabled = true
    static let featureAnalyticsEnabled = true
    static let featureInAppPurchaseEnabled = true
    static let featureGameCenterEnabled = true
    static let featureNotificationsEnabled = true
    
    // MARK: - General Categories
    static let generalEnabled = true
    #if DEBUG
    static let debugEnabled = true
    #else
    static let debugEnabled = false
    #endif
    static let errorEnabled = true
    static let warningEnabled = true
    static let infoEnabled = true
} 