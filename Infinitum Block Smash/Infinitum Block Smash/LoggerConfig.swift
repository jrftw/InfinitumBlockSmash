import Foundation

/// Configuration for the logging system
/// Updated with new logging categories for game components
/// Last updated: 2024-03-17
struct LoggerConfig {
    // MARK: - Global Settings
    static var loggingEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive || DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    
    // MARK: - Log Levels
    static var debugLevelEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static let infoLevelEnabled = true
    static let warningLevelEnabled = true
    static let errorLevelEnabled = true
    static let criticalLevelEnabled = true
    
    // MARK: - Score and Leaderboard Categories
    static var scoreEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var leaderboardEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var leaderboardWriteEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var leaderboardCacheEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var highscoreEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    
    // MARK: - Core Systems
    static let memorySystemEnabled = true
    static let networkMonitorEnabled = true
    static var firebaseManagerEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var gameStateEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var gameSceneEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static let analyticsManagerEnabled = true
    static let subscriptionManagerEnabled = true
    static let crashReporterEnabled = true
    static let securityLoggerEnabled = true
    static let appCheckEnabled = true
    static let gameCenterEnabled = true
    static let inAppMessagingEnabled = true
    static let cacheManagerEnabled = true
    static let forceLogoutEnabled = true
    static let adsEnabled = true
    
    // MARK: - Firebase Components
    static var firebaseAuthEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var firebaseFirestoreEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var firebaseRTDBEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var firebaseAnalyticsEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static let firebaseCrashlyticsEnabled = true // Keep crashlytics enabled
    static var firebasePerformanceEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var firebaseRemoteConfigEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var firebaseMessagingEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    
    // MARK: - Game Components
    static let gameUIEnabled = true
    static let gameGridEnabled = true
    static let gameTrayEnabled = true
    static let gameBlocksEnabled = true
    static let gameParticlesEnabled = true
    static let gamePhysicsEnabled = true
    static let gameAudioEnabled = true
    static let gameInputEnabled = true
    static var placementEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var levelEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var lineClearEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var previewEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static let bonusEnabled = true
    static let achievementsEnabled = true
    
    // MARK: - Debug Categories
    static var debugGameSceneEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var debugGameStateEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var debugGameProviderEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    
    // MARK: - System Components
    static var systemMemoryEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var systemNetworkEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var systemStorageEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static var systemPerformanceEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static let systemSecurityEnabled = true // Keep security logging
    
    // MARK: - Feature Components
    static let featureSubscriptionEnabled = true
    static let featureAnalyticsEnabled = true
    static let featureInAppPurchaseEnabled = true
    static let featureGameCenterEnabled = true
    static let featureNotificationsEnabled = true
    
    // MARK: - General Categories
    static let generalEnabled = true
    static var debugEnabled: Bool {
        #if DEBUG
        return DebugManager.isDebugActive && DebugManager.isVerboseLoggingEnabled
        #else
        return false
        #endif
    }
    static let errorEnabled = true
    static let warningEnabled = true
    static let infoEnabled = true
} 