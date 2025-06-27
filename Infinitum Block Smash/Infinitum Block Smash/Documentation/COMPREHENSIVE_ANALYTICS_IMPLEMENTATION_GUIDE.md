# Comprehensive Analytics Implementation Guide

## Overview

This guide provides complete implementation instructions for the new `EventsAnalyticsTrackingSystem` that extends your existing analytics with 200+ event types for comprehensive real-time tracking.

## System Architecture

### Core Components

1. **EventsAnalyticsTrackingSystem.swift** - Main tracking system with 200+ event types
2. **EventsAnalyticsIntegration.swift** - Integration layer for backward compatibility
3. **Existing GameAnalytics.swift** - Legacy system (maintained for compatibility)

### Event Categories

The system tracks events across 8 major categories:

1. **Gameplay Events** (Core mechanics)
2. **User Interface Events** (UI interactions)
3. **Achievement & Progress Events**
4. **Monetization & Ads Events**
5. **Performance & Technical Events**
6. **Social & Engagement Events**
7. **Device & Platform Events**
8. **Analytics & Debug Events**

## Quick Start

### 1. Basic Event Tracking

```swift
// Track a simple event
EventsTracker.shared.track(.buttonTap, parameters: ["button_name": "pause_button"])

// Track with automatic parameter extraction
EventsTracker.shared.track(.blockPlacementSuccessful, block)

// Track with custom parameters
EventsTracker.shared.track(.levelComplete, parameters: [
    "level": 5,
    "score": 1000,
    "time_taken": 120.5,
    "perfect_level": true
])
```

### 2. Convenience Methods

```swift
// Track gameplay events
EventsTracker.shared.trackGameplay(.blockPlacementSuccessful, level: 5, score: 1000)

// Track UI events
EventsTracker.shared.trackUI(.buttonTap, element: "settings_button")

// Track performance events
EventsTracker.shared.trackPerformance(.fpsDropDetected, value: 45.0, unit: "fps")

// Track error events
EventsTracker.shared.trackError(.networkError, error: networkError, context: "leaderboard_fetch")
```

### 3. Integration with Existing System

```swift
// Use both old and new systems
analyticsManager.trackEventWithIntegration(.levelComplete(level: 5, score: 1000))

// Get combined analytics data
let combinedData = AnalyticsIntegrationManager.shared.getCombinedAnalytics()
```

## Implementation Examples

### Gameplay Events

```swift
// Block placement tracking
func placeBlock(_ block: Block, at position: CGPoint) {
    // Game logic...
    
    // Track successful placement
    EventsTracker.shared.track(.blockPlacementSuccessful, parameters: [
        "block_color": block.color.rawValue,
        "block_shape": block.shape.rawValue,
        "position_x": position.x,
        "position_y": position.y,
        "level": currentLevel
    ])
    
    // Track if it's a perfect placement
    if isPerfectPlacement {
        EventsTracker.shared.track(.perfectPlacement, parameters: [
            "block_color": block.color.rawValue,
            "position_x": position.x,
            "position_y": position.y
        ])
    }
}

// Line clearing tracking
func clearLines(_ lines: [Int]) {
    // Game logic...
    
    EventsTracker.shared.track(.lineCleared, parameters: [
        "lines_cleared": lines.count,
        "line_positions": lines,
        "combo_multiplier": currentCombo
    ])
    
    // Track combo chain
    if currentCombo > 1 {
        EventsTracker.shared.track(.comboChainContinued, parameters: [
            "combo_count": currentCombo,
            "total_score": currentScore
        ])
    }
}
```

### UI Events

```swift
// Button interactions
Button("Pause") {
    EventsTracker.shared.trackUI(.buttonTap, element: "pause_button")
    gameState.pause()
}

// Menu navigation
NavigationLink("Settings") {
    EventsTracker.shared.trackUI(.modalOpened, element: "settings_modal")
    showingSettings = true
}

// Gesture tracking
.gesture(
    DragGesture()
        .onChanged { gesture in
            EventsTracker.shared.track(.dragGesture, parameters: [
                "gesture_type": "drag",
                "distance": gesture.translation.magnitude,
                "direction": getDirection(gesture.translation)
            ])
        }
)
```

### Performance Events

```swift
// FPS monitoring
func updateFPS(_ fps: Double) {
    if fps < 30 {
        EventsTracker.shared.trackPerformance(.fpsDropDetected, value: fps, unit: "fps")
    }
}

// Memory monitoring
func checkMemoryUsage(_ usage: Double) {
    if usage > 500 {
        EventsTracker.shared.trackPerformance(.memoryWarningReceived, value: usage, unit: "MB")
    }
}

// Thermal state monitoring
func monitorThermalState(_ state: ProcessInfo.ThermalState) {
    EventsTracker.shared.track(.thermalStateChanged, parameters: [
        "thermal_state": state.rawValue,
        "device_model": UIDevice.current.model
    ])
}
```

### Achievement Events

```swift
// Achievement progress
func updateAchievement(_ achievement: Achievement) {
    EventsTracker.shared.track(.achievementProgressUpdated, parameters: [
        "achievement_id": achievement.id,
        "progress": achievement.progress,
        "goal": achievement.goal,
        "percentage": Double(achievement.progress) / Double(achievement.goal)
    ])
    
    if achievement.unlocked {
        EventsTracker.shared.track(.achievementUnlocked, parameters: [
            "achievement_id": achievement.id,
            "achievement_name": achievement.name,
            "points_earned": achievement.points
        ])
    }
}
```

### Monetization Events

```swift
// Ad tracking
func showAd() {
    EventsTracker.shared.track(.adRequested, parameters: [
        "ad_type": "rewarded",
        "placement": "game_over"
    ])
    
    // When ad loads
    EventsTracker.shared.track(.adLoaded, parameters: [
        "ad_type": "rewarded",
        "load_time": loadTime
    ])
    
    // When ad completes
    EventsTracker.shared.track(.adCompleted, parameters: [
        "ad_type": "rewarded",
        "reward_type": "undo",
        "reward_amount": 1
    ])
}

// Purchase tracking
func purchaseItem(_ product: SKProduct) {
    EventsTracker.shared.track(.purchaseInitiated, parameters: [
        "product_id": product.productIdentifier,
        "price": product.price.doubleValue,
        "currency": product.priceLocale.currencyCode ?? "USD"
    ])
}
```

### Error Tracking

```swift
// Network errors
func fetchLeaderboard() async {
    do {
        let data = try await networkService.fetchData()
        // Process data...
    } catch {
        EventsTracker.shared.trackError(.networkError, error: error, context: "leaderboard_fetch")
    }
}

// Validation errors
func validateUserInput(_ input: String) {
    guard !input.isEmpty else {
        EventsTracker.shared.trackError(.validationError, error: ValidationError.emptyInput, context: "username_validation")
        return
    }
}
```

## Advanced Usage

### Custom Event Types

```swift
// Define custom event parameters
extension EventType {
    static let customGameEvent = EventType(rawValue: "custom_game_event")!
}

// Track custom events
EventsTracker.shared.track(.customGameEvent, parameters: [
    "custom_parameter": "custom_value",
    "timestamp": Date().timeIntervalSince1970
])
```

### Event Batching

```swift
// Events are automatically batched, but you can force processing
EventsTracker.shared.forceProcess()

// Clear the queue if needed
EventsTracker.shared.clearQueue()
```

### Performance Optimization

```swift
// Disable tracking for performance-critical sections
EventsTracker.shared.setTrackingEnabled(false)
// ... performance-critical code ...
EventsTracker.shared.setTrackingEnabled(true)

// Track only critical events in release builds
#if DEBUG
EventsTracker.shared.track(.debugFeatureAccessed, parameters: ["feature": "debug_panel"])
#endif
```

## Integration with Existing Code

### Replace Existing Analytics Calls

```swift
// Old way
analyticsManager.trackEvent(.levelComplete(level: 5, score: 1000))

// New way (with integration)
analyticsManager.trackEventWithIntegration(.levelComplete(level: 5, score: 1000))

// Or use new system directly
EventsTracker.shared.track(.levelComplete, parameters: [
    "level": 5,
    "score": 1000,
    "time_taken": levelTime,
    "perfect_level": isPerfectLevel
])
```

### Migration Utilities

```swift
// Migrate user preferences
AnalyticsMigrationUtilities.migrateUserPreferences()

// Clean up old data
AnalyticsMigrationUtilities.cleanupOldAnalyticsData()

// Validate migration
if AnalyticsMigrationUtilities.validateMigration() {
    print("Migration successful")
}
```

## Best Practices

### 1. Event Naming

- Use descriptive, consistent names
- Follow the established naming convention (snake_case)
- Group related events with common prefixes

### 2. Parameter Selection

- Include relevant context (level, score, time, etc.)
- Avoid sensitive information (passwords, personal data)
- Use consistent data types for similar parameters

### 3. Performance Considerations

- Don't track events in tight loops
- Use batching for high-frequency events
- Disable tracking during performance-critical operations

### 4. Privacy Compliance

- Only track necessary data
- Respect user consent settings
- Anonymize sensitive information

### 5. Error Handling

- Always track errors with context
- Include error codes and descriptions
- Don't let analytics errors break game functionality

## Monitoring and Debugging

### Check System Status

```swift
// Check if tracking is enabled
if EventsTracker.shared.isTrackingEnabled {
    print("Analytics tracking is active")
}

// Check queue status
print("Events in queue: \(EventsTracker.shared.eventsInQueue)")
print("Events processed: \(EventsTracker.shared.eventsProcessed)")

// Check integration status
let status = analyticsManager.integrationStatus
if status.isHealthy {
    print("Analytics integration is working")
}
```

### Debug Mode

```swift
#if DEBUG
// Enable detailed logging
EventsTracker.shared.setTrackingEnabled(true)

// Track debug events
EventsTracker.shared.track(.debugFeatureAccessed, parameters: [
    "feature": "analytics_debug",
    "timestamp": Date().timeIntervalSince1970
])
#endif
```

## Firebase Integration

### Real-time Analytics

The system automatically integrates with Firebase Analytics for critical events:

- Session start/end
- Level completion
- Achievement unlocks
- Purchase completions
- Ad completions
- App crashes
- Errors

### Custom Firebase Events

```swift
// Track custom Firebase events
Analytics.logEvent("custom_firebase_event", parameters: [
    "custom_parameter": "value",
    "timestamp": Date().timeIntervalSince1970
])
```

## Troubleshooting

### Common Issues

1. **Events not being tracked**
   - Check if tracking is enabled
   - Verify event type exists
   - Check for validation errors

2. **Performance impact**
   - Reduce event frequency
   - Use batching
   - Disable tracking during critical operations

3. **Integration issues**
   - Check integration status
   - Verify migration completed
   - Restart the integration manager

### Debug Commands

```swift
// Force process all events
EventsTracker.shared.forceProcess()

// Clear event queue
EventsTracker.shared.clearQueue()

// Check system health
let combinedData = AnalyticsIntegrationManager.shared.getCombinedAnalytics()
print("Total events: \(combinedData.totalEvents)")
print("Data available: \(combinedData.isDataAvailable)")
```

## Conclusion

This comprehensive analytics system provides extensive tracking capabilities while maintaining backward compatibility with your existing analytics. The system is designed to be performant, privacy-compliant, and easy to integrate into your existing codebase.

For additional support or questions, refer to the inline documentation in the source files or contact the development team. 