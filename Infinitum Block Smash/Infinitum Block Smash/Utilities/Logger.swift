import Foundation
import os.log
import FirebaseCrashlytics

/// A centralized logging system that allows for granular control of different types of logs
/// Last updated: 2024-03-17
class Logger {
    static let shared = Logger()
    
    // MARK: - Log Categories
    enum Category: String {
        // Score and Leaderboard
        case score = "Score"
        case leaderboard = "Leaderboard"
        case leaderboardWrite = "LeaderboardWrite"
        case leaderboardCache = "LeaderboardCache"
        case highscore = "Highscore"
        
        // Core Systems
        case memorySystem = "MemorySystem"
        case networkMonitor = "NetworkMonitor"
        case firebaseManager = "FirebaseManager"
        case gameState = "GameState"
        case gameScene = "GameScene"
        case analyticsManager = "AnalyticsManager"
        case subscriptionManager = "SubscriptionManager"
        case crashReporter = "CrashReporter"
        case securityLogger = "SecurityLogger"
        case appCheck = "AppCheck"
        case gameCenter = "GameCenter"
        case inAppMessaging = "InAppMessaging"
        case cacheManager = "CacheManager"
        case forceLogout = "ForceLogout"
        case ads = "Ads"
        
        // Firebase Components
        case firebaseAuth = "FirebaseAuth"
        case firebaseFirestore = "FirebaseFirestore"
        case firebaseRTDB = "FirebaseRTDB"
        case firebaseAnalytics = "FirebaseAnalytics"
        case firebaseCrashlytics = "FirebaseCrashlytics"
        case firebasePerformance = "FirebasePerformance"
        case firebaseRemoteConfig = "FirebaseRemoteConfig"
        case firebaseMessaging = "FirebaseMessaging"
        
        // Game Components
        case gameUI = "GameUI"
        case gameGrid = "GameGrid"
        case gameTray = "GameTray"
        case gameBlocks = "GameBlocks"
        case gameParticles = "GameParticles"
        case gamePhysics = "GamePhysics"
        case gameAudio = "GameAudio"
        case gameInput = "GameInput"
        case placement = "Placement"
        case level = "Level"
        case lineClear = "LineClear"
        case preview = "Preview"
        case bonus = "Bonus"
        case achievements = "Achievements"
        
        // Debug Categories
        case debugGameScene = "DebugGameScene"
        case debugGameState = "DebugGameState"
        case debugGameProvider = "DebugGameProvider"
        
        // System Components
        case systemMemory = "SystemMemory"
        case systemNetwork = "SystemNetwork"
        case systemStorage = "SystemStorage"
        case systemPerformance = "SystemPerformance"
        case systemSecurity = "SystemSecurity"
        
        // Feature Components
        case featureSubscription = "FeatureSubscription"
        case featureAnalytics = "FeatureAnalytics"
        case featureInAppPurchase = "FeatureInAppPurchase"
        case featureGameCenter = "FeatureGameCenter"
        case featureNotifications = "FeatureNotifications"
        
        // General Categories
        case general = "General"
        case debug = "Debug"
        case error = "Error"
        case warning = "Warning"
        case info = "Info"
        
        var isEnabled: Bool {
            switch self {
            // Score and Leaderboard
            case .score: return LoggerConfig.scoreEnabled
            case .leaderboard: return LoggerConfig.leaderboardEnabled
            case .leaderboardWrite: return LoggerConfig.leaderboardWriteEnabled
            case .leaderboardCache: return LoggerConfig.leaderboardCacheEnabled
            case .highscore: return LoggerConfig.highscoreEnabled
            
            // Core Systems
            case .memorySystem: return LoggerConfig.memorySystemEnabled
            case .networkMonitor: return LoggerConfig.networkMonitorEnabled
            case .firebaseManager: return LoggerConfig.firebaseManagerEnabled
            case .gameState: return LoggerConfig.gameStateEnabled
            case .gameScene: return LoggerConfig.gameSceneEnabled
            case .analyticsManager: return LoggerConfig.analyticsManagerEnabled
            case .subscriptionManager: return LoggerConfig.subscriptionManagerEnabled
            case .crashReporter: return LoggerConfig.crashReporterEnabled
            case .securityLogger: return LoggerConfig.securityLoggerEnabled
            case .appCheck: return LoggerConfig.appCheckEnabled
            case .gameCenter: return LoggerConfig.gameCenterEnabled
            case .inAppMessaging: return LoggerConfig.inAppMessagingEnabled
            case .cacheManager: return LoggerConfig.cacheManagerEnabled
            case .forceLogout: return LoggerConfig.forceLogoutEnabled
            case .ads: return LoggerConfig.adsEnabled
            
            // Firebase Components
            case .firebaseAuth: return LoggerConfig.firebaseAuthEnabled
            case .firebaseFirestore: return LoggerConfig.firebaseFirestoreEnabled
            case .firebaseRTDB: return LoggerConfig.firebaseRTDBEnabled
            case .firebaseAnalytics: return LoggerConfig.firebaseAnalyticsEnabled
            case .firebaseCrashlytics: return LoggerConfig.firebaseCrashlyticsEnabled
            case .firebasePerformance: return LoggerConfig.firebasePerformanceEnabled
            case .firebaseRemoteConfig: return LoggerConfig.firebaseRemoteConfigEnabled
            case .firebaseMessaging: return LoggerConfig.firebaseMessagingEnabled
            
            // Game Components
            case .gameUI: return LoggerConfig.gameUIEnabled
            case .gameGrid: return LoggerConfig.gameGridEnabled
            case .gameTray: return LoggerConfig.gameTrayEnabled
            case .gameBlocks: return LoggerConfig.gameBlocksEnabled
            case .gameParticles: return LoggerConfig.gameParticlesEnabled
            case .gamePhysics: return LoggerConfig.gamePhysicsEnabled
            case .gameAudio: return LoggerConfig.gameAudioEnabled
            case .gameInput: return LoggerConfig.gameInputEnabled
            case .placement: return LoggerConfig.placementEnabled
            case .level: return LoggerConfig.levelEnabled
            case .lineClear: return LoggerConfig.lineClearEnabled
            case .preview: return LoggerConfig.previewEnabled
            case .bonus: return LoggerConfig.bonusEnabled
            case .achievements: return LoggerConfig.achievementsEnabled
            
            // Debug Categories
            case .debugGameScene: return LoggerConfig.debugGameSceneEnabled
            case .debugGameState: return LoggerConfig.debugGameStateEnabled
            case .debugGameProvider: return LoggerConfig.debugGameProviderEnabled
            
            // System Components
            case .systemMemory: return LoggerConfig.systemMemoryEnabled
            case .systemNetwork: return LoggerConfig.systemNetworkEnabled
            case .systemStorage: return LoggerConfig.systemStorageEnabled
            case .systemPerformance: return LoggerConfig.systemPerformanceEnabled
            case .systemSecurity: return LoggerConfig.systemSecurityEnabled
            
            // Feature Components
            case .featureSubscription: return LoggerConfig.featureSubscriptionEnabled
            case .featureAnalytics: return LoggerConfig.featureAnalyticsEnabled
            case .featureInAppPurchase: return LoggerConfig.featureInAppPurchaseEnabled
            case .featureGameCenter: return LoggerConfig.featureGameCenterEnabled
            case .featureNotifications: return LoggerConfig.featureNotificationsEnabled
            
            // General Categories
            case .general: return LoggerConfig.generalEnabled
            case .debug: return LoggerConfig.debugEnabled
            case .error: return LoggerConfig.errorEnabled
            case .warning: return LoggerConfig.warningEnabled
            case .info: return LoggerConfig.infoEnabled
            }
        }
    }
    
    // MARK: - Log Levels
    enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case critical = "💥"
        
        var isEnabled: Bool {
            switch self {
            case .debug: return LoggerConfig.debugLevelEnabled
            case .info: return LoggerConfig.infoLevelEnabled
            case .warning: return LoggerConfig.warningLevelEnabled
            case .error: return LoggerConfig.errorLevelEnabled
            case .critical: return LoggerConfig.criticalLevelEnabled
            }
        }
    }
    
    // MARK: - Properties
    private var logBuffer: [String] = []
    private let maxBufferSize = 1000
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Log a message with the specified category and level
    func log(_ message: String, category: Category = .general, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard LoggerConfig.loggingEnabled,
              category.isEnabled,
              level.isEnabled else {
            return
        }
        
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] [\(fileName):\(line)] \(function): \(message)"
        
        // Add to buffer
        logBuffer.append(logMessage)
        if logBuffer.count > maxBufferSize {
            logBuffer.removeFirst()
        }
        
        // Print to console
        print(logMessage)
        
        // Log to Crashlytics for high severity events
        if level == .critical || level == .error {
            Crashlytics.crashlytics().log(logMessage)
        }
        
        // Log to system log for critical errors
        if level == .critical {
            os_log(.fault, "%{public}@", logMessage)
        }
        
        // Log to SecurityLogger for security-related events
        if category == .securityLogger {
            Task {
                SecurityLogger.shared.logSuspiciousActivity(
                    userId: nil,
                    activity: message,
                    details: [
                        "level": level.rawValue,
                        "file": fileName,
                        "function": function,
                        "line": line
                    ]
                )
            }
        }
    }
    
    /// Get all buffered logs
    func getLogs() -> [String] {
        return logBuffer
    }
    
    /// Clear all buffered logs
    func clearLogs() {
        logBuffer.removeAll()
    }
    
    // MARK: - Convenience Methods
    
    func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .error, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .critical, file: file, function: function, line: line)
    }
}

// MARK: - Category Extension
extension Logger.Category: CaseIterable {
    static var allCases: [Logger.Category] {
        return [
            // Score and Leaderboard
            .score,
            .leaderboard,
            .leaderboardWrite,
            .leaderboardCache,
            .highscore,
            
            // Core Systems
            .memorySystem,
            .networkMonitor,
            .firebaseManager,
            .gameState,
            .gameScene,
            .analyticsManager,
            .subscriptionManager,
            .crashReporter,
            .securityLogger,
            .appCheck,
            .gameCenter,
            .inAppMessaging,
            .cacheManager,
            .forceLogout,
            .ads,
            
            // Firebase Components
            .firebaseAuth,
            .firebaseFirestore,
            .firebaseRTDB,
            .firebaseAnalytics,
            .firebaseCrashlytics,
            .firebasePerformance,
            .firebaseRemoteConfig,
            .firebaseMessaging,
            
            // Game Components
            .gameUI,
            .gameGrid,
            .gameTray,
            .gameBlocks,
            .gameParticles,
            .gamePhysics,
            .gameAudio,
            .gameInput,
            .placement,
            .level,
            .lineClear,
            .preview,
            .bonus,
            .achievements,
            
            // Debug Categories
            .debugGameScene,
            .debugGameState,
            .debugGameProvider,
            
            // System Components
            .systemMemory,
            .systemNetwork,
            .systemStorage,
            .systemPerformance,
            .systemSecurity,
            
            // Feature Components
            .featureSubscription,
            .featureAnalytics,
            .featureInAppPurchase,
            .featureGameCenter,
            .featureNotifications,
            
            // General Categories
            .general,
            .debug,
            .error,
            .warning,
            .info
        ]
    }
}

// MARK: - Level Extension
extension Logger.Level: CaseIterable {
    static var allCases: [Logger.Level] {
        return [.debug, .info, .warning, .error, .critical]
    }
} 
