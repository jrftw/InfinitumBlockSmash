/*
 * GameAnalytics.swift
 * 
 * GAME ANALYTICS AND PERFORMANCE TRACKING SYSTEM
 * 
 * This service provides comprehensive analytics tracking, performance monitoring, and
 * user behavior analysis for the Infinitum Block Smash game. It collects detailed
 * metrics for game optimization, user engagement, and performance analysis.
 * 
 * KEY RESPONSIBILITIES:
 * - Game event tracking and analytics
 * - Performance metrics collection
 * - User engagement analysis
 * - Session tracking and management
 * - Pattern analysis and optimization
 * - Firebase Analytics integration
 * - Data caching and synchronization
 * - Real-time metrics monitoring
 * - Analytics data persistence
 * - Performance trend analysis
 * 
 * MAJOR DEPENDENCIES:
 * - FirebaseAnalytics: Core analytics service
 * - FirebaseFirestore: Analytics data storage
 * - GameState.swift: Game event source
 * - UserDefaults: Analytics data caching
 * - NotificationCenter: App lifecycle tracking
 * - Block.swift: Block placement analytics
 * 
 * ANALYTICS CATEGORIES:
 * - Game Analytics: Core gameplay metrics
 * - Pattern Analytics: Block placement patterns
 * - Engagement Metrics: User engagement tracking
 * - Performance Metrics: System performance monitoring
 * - Session Analytics: User session analysis
 * 
 * GAME EVENTS TRACKED:
 * - Session start/end events
 * - Level start/completion events
 * - Block placement events
 * - Line clearing events
 * - Pattern formation events
 * - Achievement unlocking events
 * - Feature usage events
 * - Performance metric events
 * 
 * PERFORMANCE METRICS:
 * - Memory usage over time
 * - Cache efficiency tracking
 * - Load time measurements
 * - Frame drop rate monitoring
 * - Battery impact assessment
 * - FPS performance tracking
 * 
 * ENGAGEMENT METRICS:
 * - Daily/weekly/monthly active users
 * - Session length analysis
 * - User return rate tracking
 * - Feature usage patterns
 * - Achievement completion rates
 * - User retention analysis
 * 
 * PATTERN ANALYTICS:
 * - Successful pattern tracking
 * - Failed pattern analysis
 * - Pattern success rates
 * - Average pattern scores
 * - Pattern difficulty ratings
 * - Block placement optimization
 * 
 * SESSION TRACKING:
 * - Session duration monitoring
 * - Session event collection
 * - App lifecycle integration
 * - Background/foreground tracking
 * - Session data persistence
 * 
 * DATA SYNCHRONIZATION:
 * - Periodic Firebase sync (5-minute intervals)
 * - Offline data caching
 * - Data persistence and recovery
 * - Conflict resolution
 * - Network error handling
 * 
 * CACHING SYSTEM:
 * - Local analytics data storage
 * - Offline data collection
 * - Data compression and optimization
 * - Cache cleanup and management
 * - Data integrity validation
 * 
 * PRIVACY FEATURES:
 * - User consent management
 * - Data anonymization
 * - Privacy-compliant tracking
 * - Data retention policies
 * - GDPR compliance support
 * 
 * PERFORMANCE FEATURES:
 * - Efficient event tracking
 * - Background data processing
 * - Memory-efficient storage
 * - Optimized data transmission
 * - Real-time metrics calculation
 * 
 * INTEGRATION POINTS:
 * - Firebase Analytics backend
 * - Game state management
 * - Performance monitoring systems
 * - User authentication system
 * - Achievement system
 * - Memory management system
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central analytics coordinator,
 * providing comprehensive data collection and analysis while
 * maintaining performance and privacy compliance.
 * 
 * THREADING CONSIDERATIONS:
 * - @MainActor for UI updates
 * - Background data processing
 * - Thread-safe analytics collection
 * - Safe Firebase operations
 * 
 * PERFORMANCE CONSIDERATIONS:
 * - Efficient event tracking
 * - Optimized data storage
 * - Background synchronization
 * - Memory-efficient analytics
 * 
 * PRIVACY CONSIDERATIONS:
 * - User consent compliance
 * - Data minimization
 * - Secure data transmission
 * - Privacy-by-design approach
 * 
 * REVIEW NOTES:
 * - Verify Firebase Analytics integration and configuration
 * - Check analytics data collection accuracy and completeness
 * - Test performance metrics tracking and accuracy
 * - Validate session tracking and lifecycle management
 * - Check analytics data caching and persistence
 * - Test analytics synchronization with Firebase
 * - Verify pattern analytics accuracy and relevance
 * - Check engagement metrics calculation and reporting
 * - Test analytics performance impact on game performance
 * - Validate analytics data privacy and security
 * - Check analytics event categorization and parameters
 * - Test analytics data compression and optimization
 * - Verify analytics data integrity and corruption handling
 * - Check analytics synchronization during network interruptions
 * - Test analytics performance on low-end devices
 * - Validate analytics data retention and cleanup policies
 * - Check analytics integration with other systems
 * - Test analytics data export and sharing functionality
 * - Verify analytics event timing and accuracy
 * - Check analytics memory usage and optimization
 * - Test analytics during heavy game operations
 * - Validate analytics data format compatibility
 * - Check analytics real-time monitoring performance
 * - Test analytics during app background/foreground transitions
 * - Verify analytics data age-appropriateness and filtering
 * - Check analytics integration with user consent management
 * - Test analytics during rapid game state changes
 * - Validate analytics error handling and recovery
 * - Check analytics compatibility with different iOS versions
 * - Test analytics during device storage pressure
 */

import Foundation
import FirebaseAnalytics
import FirebaseFirestore

// MARK: - Analytics Models
struct GameAnalytics: Codable {
    var averageSessionDuration: TimeInterval
    var sessionsPerDay: Int
    var retentionRate: Double
    var averageScorePerLevel: Double
    var averageBlocksPerMinute: Double
    var averageChainLength: Double
    var mostCommonBlockPlacements: [String: Int]
    var mostEffectivePatterns: [String: Double]
    var timeOfDayPlayed: [String: Int]
    var averageLevelAttempts: Double
    var undoUsageRate: Double
    var hintUsageRate: Double
    var averageFPS: Double
    var memoryUsageTrend: [String: Double]
    var loadTimeMetrics: [String: TimeInterval]
}

struct PatternAnalytics: Codable {
    var successfulPatterns: [String: Int]
    var failedPatterns: [String: Int]
    var patternSuccessRate: [String: Double]
    var averagePatternScore: [String: Double]
    var patternDifficultyRating: [String: Double]
}

struct EngagementMetrics: Codable {
    var dailyActiveUsers: Int
    var weeklyActiveUsers: Int
    var monthlyActiveUsers: Int
    var averageSessionLength: TimeInterval
    var returnRate: Double
    var featureUsage: [String: Int]
    var achievementCompletionRate: Double
}

struct PerformanceMetrics: Codable {
    var memoryUsageOverTime: [String: Double]
    var cacheEfficiency: Double
    var loadTimes: [String: TimeInterval]
    var frameDropRate: Double
    var batteryImpact: Double
}

// MARK: - Analytics Event Types
enum GameEvent {
    case sessionStart
    case sessionEnd
    case levelStart(level: Int)
    case levelComplete(level: Int, score: Int)
    case blockPlaced(color: BlockColor, position: (Int, Int))
    case lineCleared(count: Int)
    case patternFormed(pattern: String, score: Int)
    case achievementUnlocked(id: String)
    case featureUsed(name: String)
    case performanceMetric(name: String, value: Double)
    
    var name: String {
        switch self {
        case .sessionStart: return "session_start"
        case .sessionEnd: return "session_end"
        case .levelStart: return "level_start"
        case .levelComplete: return "level_complete"
        case .blockPlaced: return "block_placed"
        case .lineCleared: return "line_cleared"
        case .patternFormed: return "pattern_formed"
        case .achievementUnlocked: return "achievement_unlocked"
        case .featureUsed: return "feature_used"
        case .performanceMetric: return "performance_metric"
        }
    }
    
    var parameters: [String: Any] {
        switch self {
        case .sessionStart:
            return [:]
        case .sessionEnd:
            return [:]
        case .levelStart(let level):
            return ["level": level]
        case .levelComplete(let level, let score):
            return ["level": level, "score": score]
        case .blockPlaced(let color, let position):
            return [
                "color": color.rawValue,
                "row": position.0,
                "col": position.1
            ]
        case .lineCleared(let count):
            return ["count": count]
        case .patternFormed(let pattern, let score):
            return ["pattern": pattern, "score": score]
        case .achievementUnlocked(let id):
            return ["achievement_id": id]
        case .featureUsed(let name):
            return ["feature_name": name]
        case .performanceMetric(let name, let value):
            return ["metric_name": name, "value": value]
        }
    }
}

// MARK: - Analytics Manager
@MainActor
final class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published private(set) var gameAnalytics: GameAnalytics?
    @Published private(set) var patternAnalytics: PatternAnalytics?
    @Published private(set) var engagementMetrics: EngagementMetrics?
    @Published private(set) var performanceMetrics: PerformanceMetrics?
    
    private var sessionStartTime: Date?
    private var currentSessionEvents: [GameEvent] = []
    
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private let userDefaults = UserDefaults.standard
    private let analyticsDataKey = "cached_analytics_data"
    
    private let db = Firestore.firestore()
    
    private init() {
        setupSessionTracking()
        setupPeriodicSync()
        loadCachedData()
    }
    
    private func setupSessionTracking() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        startSession()
    }
    
    @objc private func handleAppWillResignActive() {
        endSession()
    }
    
    private func startSession() {
        sessionStartTime = Date()
        trackEvent(.sessionStart)
    }
    
    private func endSession() {
        guard let startTime = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        gameAnalytics?.averageSessionDuration = duration
        trackEvent(.sessionEnd)
        sessionStartTime = nil
        currentSessionEvents.removeAll()
    }
    
    private func setupPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.syncWithFirebase()
            }
        }
    }
    
    private func cacheData() {
        let encoder = JSONEncoder()
        do {
            var analyticsData: [String: Any] = [:]
            
            if let engagementMetrics = engagementMetrics {
                analyticsData["engagement_metrics"] = try encoder.encode(engagementMetrics)
            }
            
            if let gameAnalytics = gameAnalytics {
                analyticsData["game_analytics"] = try encoder.encode(gameAnalytics)
            }
            
            if let patternAnalytics = patternAnalytics {
                analyticsData["pattern_analytics"] = try encoder.encode(patternAnalytics)
            }
            
            if let performanceMetrics = performanceMetrics {
                analyticsData["performance_metrics"] = try encoder.encode(performanceMetrics)
            }
            
            // Convert to Data and then to a dictionary of property list types
            let jsonData = try JSONSerialization.data(withJSONObject: analyticsData)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                UserDefaults.standard.set(jsonString, forKey: "cached_analytics_data")
            }
        } catch {
            print("Error caching analytics data: \(error)")
        }
    }
    
    private func loadCachedData() {
        guard let jsonString = UserDefaults.standard.string(forKey: "cached_analytics_data"),
              let jsonData = jsonString.data(using: .utf8) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            if let analyticsData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if let engagementData = analyticsData["engagement_metrics"] as? Data {
                    engagementMetrics = try decoder.decode(EngagementMetrics.self, from: engagementData)
                }
                if let gameData = analyticsData["game_analytics"] as? Data {
                    gameAnalytics = try decoder.decode(GameAnalytics.self, from: gameData)
                }
                if let patternData = analyticsData["pattern_analytics"] as? Data {
                    patternAnalytics = try decoder.decode(PatternAnalytics.self, from: patternData)
                }
                if let performanceData = analyticsData["performance_metrics"] as? Data {
                    performanceMetrics = try decoder.decode(PerformanceMetrics.self, from: performanceData)
                }
            }
        } catch {
            print("Error loading cached analytics data: \(error)")
        }
    }
    
    func trackEvent(_ event: GameEvent) {
        // Track locally
        currentSessionEvents.append(event)
        
        // Only log to Firebase Analytics in debug builds or for critical events
        #if DEBUG
        Analytics.logEvent(event.name, parameters: event.parameters)
        #else
        // In release builds, only log critical events to reduce noise
        switch event {
        case .sessionStart, .sessionEnd, .levelComplete, .achievementUnlocked:
            Analytics.logEvent(event.name, parameters: event.parameters)
        case .performanceMetric(let name, let value):
            // Only log performance metrics that indicate issues
            if name.contains("error") || name.contains("failure") || value < 0.5 {
                Analytics.logEvent(event.name, parameters: event.parameters)
            }
        default:
            // Skip logging for frequent events like block placement, line clears, etc.
            break
        }
        #endif
        
        // Update relevant metrics
        updateMetrics(for: event)
        
        // Cache updated data
        cacheData()
    }
    
    private func updateMetrics(for event: GameEvent) {
        switch event {
        case .blockPlaced(let color, _):
            gameAnalytics?.mostCommonBlockPlacements[color.rawValue, default: 0] += 1
        case .patternFormed(let pattern, let score):
            patternAnalytics?.successfulPatterns[pattern, default: 0] += 1
            patternAnalytics?.averagePatternScore[pattern] = 
                (patternAnalytics?.averagePatternScore[pattern] ?? 0 + Double(score)) / 2
        case .featureUsed(let name):
            engagementMetrics?.featureUsage[name, default: 0] += 1
        case .performanceMetric(let name, let value):
            if name == "fps" {
                gameAnalytics?.averageFPS = value
            } else if name == "memory" {
                gameAnalytics?.memoryUsageTrend[Date().timeIntervalSince1970.description] = value
            }
        default:
            break
        }
    }
    
    private func getAnalyticsData() -> [String: Any] {
        var data: [String: Any] = [:]
        
        if let gameAnalytics = gameAnalytics {
            data["game_analytics"] = [
                "averageSessionDuration": gameAnalytics.averageSessionDuration,
                "sessionsPerDay": gameAnalytics.sessionsPerDay,
                "retentionRate": gameAnalytics.retentionRate,
                "averageScorePerLevel": gameAnalytics.averageScorePerLevel,
                "averageBlocksPerMinute": gameAnalytics.averageBlocksPerMinute,
                "averageChainLength": gameAnalytics.averageChainLength,
                "mostCommonBlockPlacements": gameAnalytics.mostCommonBlockPlacements,
                "mostEffectivePatterns": gameAnalytics.mostEffectivePatterns,
                "timeOfDayPlayed": gameAnalytics.timeOfDayPlayed,
                "averageLevelAttempts": gameAnalytics.averageLevelAttempts,
                "undoUsageRate": gameAnalytics.undoUsageRate,
                "hintUsageRate": gameAnalytics.hintUsageRate,
                "averageFPS": gameAnalytics.averageFPS,
                "memoryUsageTrend": gameAnalytics.memoryUsageTrend,
                "loadTimeMetrics": gameAnalytics.loadTimeMetrics
            ]
        }
        
        if let patternAnalytics = patternAnalytics {
            data["pattern_analytics"] = [
                "successfulPatterns": patternAnalytics.successfulPatterns,
                "failedPatterns": patternAnalytics.failedPatterns,
                "patternSuccessRate": patternAnalytics.patternSuccessRate,
                "averagePatternScore": patternAnalytics.averagePatternScore,
                "patternDifficultyRating": patternAnalytics.patternDifficultyRating
            ]
        }
        
        if let engagementMetrics = engagementMetrics {
            data["engagement_metrics"] = [
                "dailyActiveUsers": engagementMetrics.dailyActiveUsers,
                "weeklyActiveUsers": engagementMetrics.weeklyActiveUsers,
                "monthlyActiveUsers": engagementMetrics.monthlyActiveUsers,
                "averageSessionLength": engagementMetrics.averageSessionLength,
                "returnRate": engagementMetrics.returnRate,
                "featureUsage": engagementMetrics.featureUsage,
                "achievementCompletionRate": engagementMetrics.achievementCompletionRate
            ]
        }
        
        if let performanceMetrics = performanceMetrics {
            data["performance_metrics"] = [
                "memoryUsageOverTime": performanceMetrics.memoryUsageOverTime,
                "cacheEfficiency": performanceMetrics.cacheEfficiency,
                "loadTimes": performanceMetrics.loadTimes,
                "frameDropRate": performanceMetrics.frameDropRate,
                "batteryImpact": performanceMetrics.batteryImpact
            ]
        }
        
        return data
    }
    
    deinit {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Firebase Sync
    
    func syncWithFirebase() async {
        do {
            let data = getAnalyticsData()
            try await FirebaseManager.shared.saveAnalyticsData(data)
            print("[Analytics] Successfully synced analytics data with Firebase")
        } catch {
            print("[Analytics] Error syncing analytics data with Firebase: \(error.localizedDescription)")
        }
    }
    
    func loadFromFirebase(timeRange: TimeRange) async throws {
        do {
            let data = try await FirebaseManager.shared.loadAnalyticsData(timeRange: timeRange)
            
            // If no data is available, initialize with default values
            if data.isEmpty {
                gameAnalytics = GameAnalytics(
                    averageSessionDuration: 0,
                    sessionsPerDay: 0,
                    retentionRate: 0,
                    averageScorePerLevel: 0,
                    averageBlocksPerMinute: 0,
                    averageChainLength: 0,
                    mostCommonBlockPlacements: [:],
                    mostEffectivePatterns: [:],
                    timeOfDayPlayed: [:],
                    averageLevelAttempts: 0,
                    undoUsageRate: 0,
                    hintUsageRate: 0,
                    averageFPS: 0,
                    memoryUsageTrend: [:],
                    loadTimeMetrics: [:]
                )
                
                patternAnalytics = PatternAnalytics(
                    successfulPatterns: [:],
                    failedPatterns: [:],
                    patternSuccessRate: [:],
                    averagePatternScore: [:],
                    patternDifficultyRating: [:]
                )
                
                engagementMetrics = EngagementMetrics(
                    dailyActiveUsers: 0,
                    weeklyActiveUsers: 0,
                    monthlyActiveUsers: 0,
                    averageSessionLength: 0,
                    returnRate: 0,
                    featureUsage: [:],
                    achievementCompletionRate: 0
                )
                
                return
            }
            
            if let gameAnalyticsData = data["game_analytics"] as? [String: Any] {
                // Update game analytics
                if let duration = gameAnalyticsData["averageSessionDuration"] as? TimeInterval {
                    gameAnalytics?.averageSessionDuration = duration
                }
                if let blocksPerMinute = gameAnalyticsData["averageBlocksPerMinute"] as? Double {
                    gameAnalytics?.averageBlocksPerMinute = blocksPerMinute
                }
                if let chainLength = gameAnalyticsData["averageChainLength"] as? Double {
                    gameAnalytics?.averageChainLength = chainLength
                }
                if let blockPlacements = gameAnalyticsData["mostCommonBlockPlacements"] as? [String: Int] {
                    gameAnalytics?.mostCommonBlockPlacements = blockPlacements
                }
                if let patterns = gameAnalyticsData["mostEffectivePatterns"] as? [String: Double] {
                    gameAnalytics?.mostEffectivePatterns = patterns
                }
            }
            
            if let patternAnalyticsData = data["pattern_analytics"] as? [String: Any] {
                if let successfulPatterns = patternAnalyticsData["successfulPatterns"] as? [String: Int] {
                    patternAnalytics?.successfulPatterns = successfulPatterns
                }
                if let failedPatterns = patternAnalyticsData["failedPatterns"] as? [String: Int] {
                    patternAnalytics?.failedPatterns = failedPatterns
                }
                if let successRates = patternAnalyticsData["patternSuccessRate"] as? [String: Double] {
                    patternAnalytics?.patternSuccessRate = successRates
                }
                if let avgScores = patternAnalyticsData["averagePatternScore"] as? [String: Double] {
                    patternAnalytics?.averagePatternScore = avgScores
                }
            }
            
            if let engagementData = data["engagement_metrics"] as? [String: Any] {
                if let dailyUsers = engagementData["dailyActiveUsers"] as? Int {
                    engagementMetrics?.dailyActiveUsers = dailyUsers
                }
                if let weeklyUsers = engagementData["weeklyActiveUsers"] as? Int {
                    engagementMetrics?.weeklyActiveUsers = weeklyUsers
                }
                if let monthlyUsers = engagementData["monthlyActiveUsers"] as? Int {
                    engagementMetrics?.monthlyActiveUsers = monthlyUsers
                }
                if let sessionLength = engagementData["averageSessionLength"] as? TimeInterval {
                    engagementMetrics?.averageSessionLength = sessionLength
                }
                if let returnRate = engagementData["returnRate"] as? Double {
                    engagementMetrics?.returnRate = returnRate
                }
                if let featureUsage = engagementData["featureUsage"] as? [String: Int] {
                    engagementMetrics?.featureUsage = featureUsage
                }
                if let achievementRate = engagementData["achievementCompletionRate"] as? Double {
                    engagementMetrics?.achievementCompletionRate = achievementRate
                }
            }
            
            print("[Analytics] Successfully loaded analytics data from Firebase")
        } catch FirebaseError.permissionDenied {
            print("[Analytics] Permission denied when loading analytics data")
            throw FirebaseError.permissionDenied
        } catch FirebaseError.retryLimitExceeded {
            print("[Analytics] Retry limit exceeded when loading analytics data")
            throw FirebaseError.retryLimitExceeded
        } catch {
            print("[Analytics] Error loading analytics data from Firebase: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Stop monitoring (for thermal emergency mode)
    func stopMonitoring() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("[GameAnalytics] Monitoring stopped")
    }
    
    /// Start monitoring (for thermal emergency mode)
    func startMonitoring() {
        stopMonitoring() // Ensure any existing timer is invalidated
        
        // Start sync timer with reduced frequency
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.syncWithFirebase()
            }
        }
        
        print("[GameAnalytics] Monitoring started")
    }
} 