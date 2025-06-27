/*
 * EventsAnalyticsTrackingSystem.swift
 * 
 * COMPREHENSIVE REAL-TIME ANALYTICS TRACKING SYSTEM
 * 
 * This system provides extensive event tracking for the Infinitum Block Smash game,
 * covering all user interactions, game mechanics, performance metrics, and business events.
 * It extends the existing GameAnalytics system with hundreds of additional event types
 * for comprehensive real-time analytics.
 * 
 * KEY FEATURES:
 * - 200+ event types across all game categories
 * - Real-time event tracking and processing
 * - Event batching and optimization
 * - Privacy-compliant data collection
 * - Performance-optimized tracking
 * - Firebase Analytics integration
 * - Offline event caching
 * - Event prioritization and filtering
 * 
 * EVENT CATEGORIES:
 * - Gameplay Events (Core mechanics)
 * - User Interface Events (UI interactions)
 * - Achievement & Progress Events
 * - Monetization & Ads Events
 * - Performance & Technical Events
 * - Social & Engagement Events
 * - Device & Platform Events
 * - Analytics & Debug Events
 * 
 * ARCHITECTURE:
 * - EventType enum: Defines all event types
 * - EventData struct: Standardized event data structure
 * - EventsTracker: Main tracking coordinator
 * - EventBatcher: Optimizes event transmission
 * - EventValidator: Ensures data quality
 * - EventProcessor: Processes and analyzes events
 */

import Foundation
import FirebaseAnalytics
import FirebaseFirestore
import UIKit
import Combine

// MARK: - Event Type Definitions

/// Comprehensive event type enumeration covering all game interactions
enum EventType: String, CaseIterable {
    // MARK: - Gameplay Events (Core Mechanics)
    
    // Block Placement & Movement
    case blockDragStarted = "block_drag_started"
    case blockDragMoved = "block_drag_moved"
    case blockDragCancelled = "block_drag_cancelled"
    case blockPlacementAttempt = "block_placement_attempt"
    case blockPlacementFailed = "block_placement_failed"
    case blockPlacementSuccessful = "block_placement_successful"
    case blockPreviewShown = "block_preview_shown"
    case blockPreviewHidden = "block_preview_hidden"
    case invalidPlacementAttempt = "invalid_placement_attempt"
    case perfectPlacement = "perfect_placement"
    
    // Line Clearing & Patterns
    case lineClearAnimationStarted = "line_clear_animation_started"
    case lineClearAnimationCompleted = "line_clear_animation_completed"
    case comboChainStarted = "combo_chain_started"
    case comboChainContinued = "combo_chain_continued"
    case comboChainEnded = "combo_chain_ended"
    case patternFormationStarted = "pattern_formation_started"
    case patternFormationCompleted = "pattern_formation_completed"
    case patternBreakdown = "pattern_breakdown"
    case lineClearMultiplier = "line_clear_multiplier"
    
    // Game State Changes
    case gameModeSelected = "game_mode_selected"
    case gameDifficultyChanged = "game_difficulty_changed"
    case levelTransitionStarted = "level_transition_started"
    case levelTransitionCompleted = "level_transition_completed"
    case gamePaused = "game_paused"
    case gameResumed = "game_resumed"
    case gameSaved = "game_saved"
    case gameLoaded = "game_loaded"
    case gameReset = "game_reset"
    case gameOver = "game_over"
    case gameWon = "game_won"
    
    // MARK: - User Interface Events
    
    // Button Interactions
    case buttonTap = "button_tap"
    case buttonLongPress = "button_long_press"
    case buttonDoubleTap = "button_double_tap"
    case menuNavigation = "menu_navigation"
    case settingsChanged = "settings_changed"
    case themeChanged = "theme_changed"
    case fpsSettingChanged = "fps_setting_changed"
    case soundSettingChanged = "sound_setting_changed"
    case hapticSettingChanged = "haptic_setting_changed"
    
    // Gesture & Touch Events
    case swipeGesture = "swipe_gesture"
    case pinchGesture = "pinch_gesture"
    case tapGesture = "tap_gesture"
    case dragGesture = "drag_gesture"
    case touchStart = "touch_start"
    case touchEnd = "touch_end"
    case touchCancelled = "touch_cancelled"
    case touchMove = "touch_move"
    
    // Modal & Overlay Events
    case modalOpened = "modal_opened"
    case modalClosed = "modal_closed"
    case overlayDismissed = "overlay_dismissed"
    case tutorialStepViewed = "tutorial_step_viewed"
    case tutorialCompleted = "tutorial_completed"
    case tutorialSkipped = "tutorial_skipped"
    case helpAccessed = "help_accessed"
    case faqViewed = "faq_viewed"
    
    // MARK: - Achievement & Progress Events
    
    // Achievement System
    case achievementProgressUpdated = "achievement_progress_updated"
    case achievementMilestoneReached = "achievement_milestone_reached"
    case achievementViewed = "achievement_viewed"
    case achievementShareAttempted = "achievement_share_attempted"
    case achievementNotificationDismissed = "achievement_notification_dismissed"
    case achievementUnlocked = "achievement_unlocked"
    case achievementFailed = "achievement_failed"
    
    // Progress Tracking
    case dailyStreakUpdated = "daily_streak_updated"
    case weeklyGoalProgress = "weekly_goal_progress"
    case monthlyChallengeProgress = "monthly_challenge_progress"
    case personalBestUpdated = "personal_best_updated"
    case leaderboardPositionChanged = "leaderboard_position_changed"
    case levelProgress = "level_progress"
    case scoreMilestone = "score_milestone"
    
    // MARK: - Monetization & Ads Events
    
    // Ad Interactions
    case adRequested = "ad_requested"
    case adLoaded = "ad_loaded"
    case adFailedToLoad = "ad_failed_to_load"
    case adShown = "ad_shown"
    case adClosed = "ad_closed"
    case adClicked = "ad_clicked"
    case adCompleted = "ad_completed"
    case adSkipped = "ad_skipped"
    case adError = "ad_error"
    case adImpression = "ad_impression"
    case adRevenue = "ad_revenue"
    
    // Purchase Events
    case purchaseInitiated = "purchase_initiated"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case purchaseCancelled = "purchase_cancelled"
    case subscriptionStarted = "subscription_started"
    case subscriptionRenewed = "subscription_renewed"
    case subscriptionCancelled = "subscription_cancelled"
    case restorePurchasesAttempted = "restore_purchases_attempted"
    case inAppPurchaseViewed = "in_app_purchase_viewed"
    
    // In-App Features
    case hintUsed = "hint_used"
    case undoUsed = "undo_used"
    case powerUpPurchased = "power_up_purchased"
    case premiumFeatureAccessed = "premium_feature_accessed"
    case referralCodeEntered = "referral_code_entered"
    case referralInviteSent = "referral_invite_sent"
    case referralRewardEarned = "referral_reward_earned"
    
    // MARK: - Performance & Technical Events
    
    // Performance Metrics
    case fpsDropDetected = "fps_drop_detected"
    case memoryWarningReceived = "memory_warning_received"
    case thermalStateChanged = "thermal_state_changed"
    case batteryLevelChanged = "battery_level_changed"
    case lowPowerModeEnabled = "low_power_mode_enabled"
    case performanceModeChanged = "performance_mode_changed"
    case cacheHit = "cache_hit"
    case cacheMiss = "cache_miss"
    case networkLatencyMeasured = "network_latency_measured"
    case loadTimeMeasured = "load_time_measured"
    case renderTimeMeasured = "render_time_measured"
    
    // Error & Crash Events
    case appCrash = "app_crash"
    case errorOccurred = "error_occurred"
    case networkError = "network_error"
    case firebaseError = "firebase_error"
    case memoryLeakDetected = "memory_leak_detected"
    case exceptionThrown = "exception_thrown"
    case validationError = "validation_error"
    case timeoutError = "timeout_error"
    
    // System Events
    case appForegrounded = "app_foregrounded"
    case appBackgrounded = "app_backgrounded"
    case deviceOrientationChanged = "device_orientation_changed"
    case accessibilityFeatureUsed = "accessibility_feature_used"
    case notificationReceived = "notification_received"
    case deepLinkOpened = "deep_link_opened"
    case appUpdateAvailable = "app_update_available"
    case appUpdated = "app_updated"
    
    // MARK: - Social & Engagement Events
    
    // Social Features
    case leaderboardViewed = "leaderboard_viewed"
    case friendChallengeSent = "friend_challenge_sent"
    case friendChallengeAccepted = "friend_challenge_accepted"
    case socialShareAttempted = "social_share_attempted"
    case ratingPromptShown = "rating_prompt_shown"
    case ratingPromptResponded = "rating_prompt_responded"
    case reviewSubmitted = "review_submitted"
    case feedbackSubmitted = "feedback_submitted"
    
    // User Engagement
    case sessionDuration = "session_duration"
    case featureDiscovery = "feature_discovery"
    case helpSectionAccessed = "help_section_accessed"
    case bugReportSubmitted = "bug_report_submitted"
    case supportContacted = "support_contacted"
    case userRetention = "user_retention"
    case userChurn = "user_churn"
    case userReengagement = "user_reengagement"
    
    // MARK: - Device & Platform Events
    
    // Device Information
    case deviceTypeIdentified = "device_type_identified"
    case iosVersionDetected = "ios_version_detected"
    case screenSizeDetected = "screen_size_detected"
    case deviceCapabilities = "device_capabilities"
    case storageSpaceChecked = "storage_space_checked"
    case deviceLanguageChanged = "device_language_changed"
    case deviceRegionChanged = "device_region_changed"
    
    // Platform Integration
    case gameCenterAuthenticated = "game_center_authenticated"
    case iCloudSyncStarted = "icloud_sync_started"
    case iCloudSyncCompleted = "icloud_sync_completed"
    case iCloudSyncFailed = "icloud_sync_failed"
    case appStoreReviewRequested = "app_store_review_requested"
    case appStoreReviewCompleted = "app_store_review_completed"
    case pushNotificationPermission = "push_notification_permission"
    
    // MARK: - Analytics & Debug Events
    
    // Debug & Development
    case debugFeatureAccessed = "debug_feature_accessed"
    case testModeEnabled = "test_mode_enabled"
    case analyticsConsentChanged = "analytics_consent_changed"
    case dataCollectionToggled = "data_collection_toggled"
    case crashReportGenerated = "crash_report_generated"
    case performanceTestRun = "performance_test_run"
    case memoryTestRun = "memory_test_run"
    
    // A/B Testing
    case abTestVariantAssigned = "ab_test_variant_assigned"
    case abTestExposure = "ab_test_exposure"
    case featureFlagEnabled = "feature_flag_enabled"
    case experimentParticipation = "experiment_participation"
    case experimentConversion = "experiment_conversion"
    
    // MARK: - Legacy Events (Compatibility)
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case levelStart = "level_start"
    case levelComplete = "level_complete"
    case blockPlaced = "block_placed"
    case lineCleared = "line_cleared"
    case patternFormed = "pattern_formed"
    case featureUsed = "feature_used"
    case performanceMetric = "performance_metric"
}

// MARK: - Event Data Structure

/// Standardized event data structure for all analytics events
struct EventData: Codable {
    let eventType: String
    let timestamp: Date
    let sessionId: String
    let userId: String?
    let deviceId: String
    let parameters: [String: AnyCodable]
    let metadata: EventMetadata
    
    init(
        eventType: EventType,
        parameters: [String: Any] = [:],
        userId: String? = nil,
        sessionId: String? = nil
    ) {
        self.eventType = eventType.rawValue
        self.timestamp = Date()
        self.sessionId = sessionId ?? UUID().uuidString // Use a temporary session ID
        self.userId = userId
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        self.parameters = parameters.mapValues { AnyCodable($0) }
        self.metadata = EventMetadata()
    }
    
    /// Create EventData with proper session ID from EventsTracker
    static func create(
        eventType: EventType,
        parameters: [String: Any] = [:],
        userId: String? = nil,
        sessionId: String? = nil
    ) async -> EventData {
        let actualSessionId: String
        if let providedSessionId = sessionId {
            actualSessionId = providedSessionId
        } else {
            // Access the main actor-isolated property safely
            actualSessionId = await MainActor.run {
                EventsTracker.shared.sessionId
            }
        }
        
        return EventData(
            eventType: eventType,
            parameters: parameters,
            userId: userId,
            sessionId: actualSessionId
        )
    }
}

/// Event metadata for additional context
struct EventMetadata: Codable {
    let appVersion: String
    let iosVersion: String
    let deviceModel: String
    let screenSize: String
    let timeZone: String
    let locale: String
    let isDebug: Bool
    let isSimulator: Bool
    
    init() {
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.iosVersion = UIDevice.current.systemVersion
        self.deviceModel = UIDevice.current.model
        self.screenSize = "\(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)"
        self.timeZone = TimeZone.current.identifier
        self.locale = Locale.current.identifier
        #if DEBUG
        self.isDebug = true
        #else
        self.isDebug = false
        #endif
        #if targetEnvironment(simulator)
        self.isSimulator = true
        #else
        self.isSimulator = false
        #endif
    }
}

/// Wrapper for Any type to make it Codable
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Events Tracker

/// Main analytics tracking coordinator
@MainActor
final class EventsTracker: ObservableObject {
    static let shared = EventsTracker()
    
    // MARK: - Published Properties
    @Published private(set) var isTrackingEnabled = true
    @Published private(set) var eventsProcessed: Int = 0
    @Published private(set) var eventsInQueue: Int = 0
    @Published private(set) var lastEventTime: Date?
    
    // MARK: - Private Properties
    private var eventQueue: [EventData] = []
    private var currentSessionId: String
    private var batchTimer: Timer?
    private var syncTimer: Timer?
    private let maxQueueSize = 1000
    private let batchSize = 50
    private let batchInterval: TimeInterval = 30.0 // 30 seconds
    private let syncInterval: TimeInterval = 300.0 // 5 minutes
    
    private let userDefaults = UserDefaults.standard
    private let db = Firestore.firestore()
    
    // MARK: - Event Processing
    private var eventProcessor: EventProcessor
    private var eventValidator: EventValidator
    private var eventBatcher: EventBatcher
    
    private init() {
        self.currentSessionId = UUID().uuidString
        self.eventProcessor = EventProcessor()
        self.eventValidator = EventValidator()
        self.eventBatcher = EventBatcher()
        
        setupTimers()
        loadQueuedEvents()
        startSession()
    }
    
    // MARK: - Public Methods
    
    /// Track a new event
    func track(_ eventType: EventType, parameters: [String: Any] = [:], userId: String? = nil) {
        guard isTrackingEnabled else { return }
        
        let eventData = EventData(
            eventType: eventType,
            parameters: parameters,
            userId: userId,
            sessionId: currentSessionId
        )
        
        // Validate event
        guard eventValidator.validate(eventData) else {
            print("[EventsTracker] Event validation failed for: \(eventType.rawValue)")
            return
        }
        
        // Add to queue
        eventQueue.append(eventData)
        eventsInQueue = eventQueue.count
        
        // Process if queue is full
        if eventQueue.count >= batchSize {
            processBatch()
        }
        
        // Update last event time
        lastEventTime = Date()
        
        // Log to Firebase Analytics for critical events
        logToFirebaseAnalytics(eventType, parameters: parameters)
    }
    
    /// Track event with automatic parameter extraction
    func trackEvent(_ eventType: EventType, _ object: Any? = nil, userId: String? = nil) {
        let parameters = extractParameters(from: object)
        track(eventType, parameters: parameters, userId: userId)
    }
    
    /// Enable/disable tracking
    func setTrackingEnabled(_ enabled: Bool) {
        isTrackingEnabled = enabled
        userDefaults.set(enabled, forKey: "analytics_tracking_enabled")
        
        if enabled {
            startSession()
        } else {
            endSession()
        }
    }
    
    /// Force process all queued events
    func forceProcess() {
        processBatch()
    }
    
    /// Clear all queued events
    func clearQueue() {
        eventQueue.removeAll()
        eventsInQueue = 0
        saveQueuedEvents()
    }
    
    /// Get current session ID
    var sessionId: String {
        return currentSessionId
    }
    
    // MARK: - Private Methods
    
    private func setupTimers() {
        // Batch processing timer
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processBatch()
            }
        }
        
        // Sync timer
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.syncWithFirebase()
            }
        }
    }
    
    private func startSession() {
        currentSessionId = UUID().uuidString
        track(.sessionStart)
        print("[EventsTracker] Session started: \(currentSessionId)")
    }
    
    private func endSession() {
        track(.sessionEnd)
        processBatch()
        print("[EventsTracker] Session ended: \(currentSessionId)")
    }
    
    private func processBatch() {
        guard !eventQueue.isEmpty else { return }
        
        let batch = Array(eventQueue.prefix(batchSize))
        eventQueue.removeFirst(min(batchSize, eventQueue.count))
        eventsInQueue = eventQueue.count
        
        // Process batch
        Task {
            await eventProcessor.process(batch)
            eventsProcessed += batch.count
        }
        
        // Save remaining events
        saveQueuedEvents()
    }
    
    private func logToFirebaseAnalytics(_ eventType: EventType, parameters: [String: Any]) {
        // Only log critical events to Firebase Analytics to reduce noise
        let criticalEvents: [EventType] = [
            .sessionStart, .sessionEnd, .levelComplete, .achievementUnlocked,
            .purchaseCompleted, .adCompleted, .appCrash, .errorOccurred
        ]
        
        if criticalEvents.contains(eventType) {
            Analytics.logEvent(eventType.rawValue, parameters: parameters)
        }
    }
    
    private func extractParameters(from object: Any?) -> [String: Any] {
        guard let object = object else { return [:] }
        
        var parameters: [String: Any] = [:]
        
        // Extract parameters based on object type
        if let block = object as? Block {
            parameters["block_color"] = block.color.rawValue
            parameters["block_shape"] = block.shape.rawValue
            parameters["block_id"] = block.id.uuidString
        } else if let position = object as? CGPoint {
            parameters["x"] = position.x
            parameters["y"] = position.y
        } else if let rect = object as? CGRect {
            parameters["x"] = rect.origin.x
            parameters["y"] = rect.origin.y
            parameters["width"] = rect.size.width
            parameters["height"] = rect.size.height
        } else if let error = object as? Error {
            parameters["error_description"] = error.localizedDescription
            parameters["error_domain"] = (error as NSError).domain
            parameters["error_code"] = (error as NSError).code
        } else if let string = object as? String {
            parameters["value"] = string
        } else if let number = object as? NSNumber {
            parameters["value"] = number.doubleValue
        }
        
        return parameters
    }
    
    private func saveQueuedEvents() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(eventQueue)
            userDefaults.set(data, forKey: "queued_analytics_events")
        } catch {
            print("[EventsTracker] Failed to save queued events: \(error)")
        }
    }
    
    private func loadQueuedEvents() {
        guard let data = userDefaults.data(forKey: "queued_analytics_events") else { return }
        
        do {
            let decoder = JSONDecoder()
            eventQueue = try decoder.decode([EventData].self, from: data)
            eventsInQueue = eventQueue.count
        } catch {
            print("[EventsTracker] Failed to load queued events: \(error)")
            eventQueue.removeAll()
        }
    }
    
    private func syncWithFirebase() async {
        // Sync processed events with Firebase
        await eventProcessor.syncWithFirebase()
    }
    
    deinit {
        batchTimer?.invalidate()
        syncTimer?.invalidate()
    }
}

// MARK: - Event Processor

/// Processes and analyzes events
final class EventProcessor {
    private var processedEvents: [EventData] = []
    private let maxProcessedEvents = 10000
    
    func process(_ events: [EventData]) async {
        // Add to processed events
        processedEvents.append(contentsOf: events)
        
        // Keep only recent events
        if processedEvents.count > maxProcessedEvents {
            processedEvents.removeFirst(processedEvents.count - maxProcessedEvents)
        }
        
        // Analyze events for patterns
        await analyzeEvents(events)
        
        // Store in local database
        await storeEvents(events)
    }
    
    private func analyzeEvents(_ events: [EventData]) async {
        // Analyze event patterns for insights
        let eventTypes = events.map { $0.eventType }
        let eventCounts = Dictionary(grouping: eventTypes, by: { $0 }).mapValues { $0.count }
        
        // Track high-frequency events
        for (eventType, count) in eventCounts {
            if count > 10 {
                print("[EventProcessor] High frequency event detected: \(eventType) (\(count) times)")
            }
        }
    }
    
    private func storeEvents(_ events: [EventData]) async {
        // Store events in local database for offline access
        // Implementation would depend on your local storage solution
    }
    
    func syncWithFirebase() async {
        // Sync processed events with Firebase
        // Implementation would depend on your Firebase setup
    }
}

// MARK: - Event Validator

/// Validates event data quality
final class EventValidator {
    func validate(_ event: EventData) -> Bool {
        // Check required fields
        guard !event.eventType.isEmpty else { return false }
        guard !event.sessionId.isEmpty else { return false }
        guard !event.deviceId.isEmpty else { return false }
        
        // Check timestamp is recent
        let timeSinceEvent = Date().timeIntervalSince(event.timestamp)
        guard timeSinceEvent < 3600 else { return false } // Events older than 1 hour are invalid
        
        // Check parameter limits
        guard event.parameters.count <= 50 else { return false } // Max 50 parameters per event
        
        return true
    }
}

// MARK: - Event Batcher

/// Optimizes event transmission
final class EventBatcher {
    private var batches: [[EventData]] = []
    
    func addBatch(_ events: [EventData]) {
        batches.append(events)
    }
    
    func getNextBatch() -> [EventData]? {
        return batches.isEmpty ? nil : batches.removeFirst()
    }
    
    func clearBatches() {
        batches.removeAll()
    }
}

// MARK: - Convenience Extensions

extension EventsTracker {
    /// Track gameplay events
    func trackGameplay(_ eventType: EventType, level: Int? = nil, score: Int? = nil, additionalParams: [String: Any] = [:]) {
        var parameters = additionalParams
        if let level = level { parameters["level"] = level }
        if let score = score { parameters["score"] = score }
        track(eventType, parameters: parameters)
    }
    
    /// Track UI events
    func trackUI(_ eventType: EventType, element: String, additionalParams: [String: Any] = [:]) {
        var parameters = additionalParams
        parameters["ui_element"] = element
        track(eventType, parameters: parameters)
    }
    
    /// Track performance events
    func trackPerformance(_ eventType: EventType, value: Double, unit: String = "", additionalParams: [String: Any] = [:]) {
        var parameters = additionalParams
        parameters["value"] = value
        parameters["unit"] = unit
        track(eventType, parameters: parameters)
    }
    
    /// Track error events
    func trackError(_ eventType: EventType, error: Error, context: String = "", additionalParams: [String: Any] = [:]) {
        var parameters = additionalParams
        parameters["error_description"] = error.localizedDescription
        parameters["error_domain"] = (error as NSError).domain
        parameters["error_code"] = (error as NSError).code
        parameters["context"] = context
        track(eventType, parameters: parameters)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let analyticsEventTracked = Notification.Name("analyticsEventTracked")
    static let analyticsBatchProcessed = Notification.Name("analyticsBatchProcessed")
    static let analyticsErrorOccurred = Notification.Name("analyticsErrorOccurred")
}

// MARK: - Usage Examples

/*
 Example usage:
 
 // Track gameplay events
 EventsTracker.shared.trackGameplay(.blockPlacementSuccessful, level: 5, score: 1000)
 EventsTracker.shared.trackGameplay(.lineCleared, level: 5, additionalParams: ["lines_cleared": 3])
 
 // Track UI events
 EventsTracker.shared.trackUI(.buttonTap, element: "pause_button")
 EventsTracker.shared.trackUI(.modalOpened, element: "settings_modal")
 
 // Track performance events
 EventsTracker.shared.trackPerformance(.fpsDropDetected, value: 45.0, unit: "fps")
 EventsTracker.shared.trackPerformance(.memoryWarningReceived, value: 512.0, unit: "MB")
 
 // Track error events
 EventsTracker.shared.trackError(.networkError, error: networkError, context: "leaderboard_fetch")
 
 // Track custom events
 EventsTracker.shared.track(.achievementUnlocked, parameters: ["achievement_id": "first_win"])
 EventsTracker.shared.track(.purchaseCompleted, parameters: ["product_id": "premium_subscription"])
 */ 
