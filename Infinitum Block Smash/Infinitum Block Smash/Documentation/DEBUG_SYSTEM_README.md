# Debug System Documentation

## Overview

The Infinitum Block Smash app now includes a comprehensive debug system that provides centralized control over all debug features, logging, and development-only functionality. This system allows you to easily enable/disable debugging without modifying code or rebuilding the app.

## Key Features

### 🎛️ **Centralized Control**
- Single point of control for all debug features
- Runtime configuration (no rebuild required)
- Persistent settings across app launches
- Environment-aware (DEBUG vs RELEASE builds)

### 🔧 **Debug Manager**
- Visual interface for controlling debug features
- Real-time toggles for different debug categories
- Production mode simulation
- Settings persistence

### 📝 **Smart Logging**
- Category-based logging system
- Dynamic log level control
- Automatic debug/release switching
- Performance-optimized logging

## Quick Start

### 1. Access Debug Manager
1. Build and run the app in **DEBUG** mode
2. Go to **Settings** → **Debug Manager** (only visible in debug builds)
3. Toggle **Debug Mode** to enable debug features

### 2. Enable Debug Features
Once debug mode is enabled, you can control:
- **Show Debug UI**: Display debug information overlays
- **Show Debug Logs**: Enable verbose logging
- **Show Debug Borders**: Display visual debug elements
- **Verbose Logging**: Enable detailed logging across all categories
- **Force Logout**: Enable force logout for testing
- **Device Simulation**: Enable device simulation features
- **Debug Analytics**: Enable debug analytics events

### 3. Production Mode
- Toggle **Production Mode** to simulate release build behavior
- Useful for testing production-like conditions in debug builds
- Automatically disables all debug features when enabled

## Debug Manager Interface

### Main Controls
- **Debug Mode**: Master toggle for all debug features
- **Production Mode**: Simulate release build behavior

### Feature Toggles
- **Show Debug UI**: Enable debug UI elements
- **Show Debug Logs**: Enable debug logging
- **Show Debug Borders**: Show visual debug borders
- **Show Debug Info**: Display debug information
- **Verbose Logging**: Enable detailed logging
- **Force Logout**: Enable force logout testing
- **Device Simulation**: Enable device simulation
- **Debug Analytics**: Enable debug analytics

### Status Section
- Shows whether debug features are currently available
- Green = Available, Red = Not Available

## Logging System

### Categories
The logging system supports multiple categories:
- **Score & Leaderboard**: Score tracking and leaderboard operations
- **Core Systems**: Firebase, GameState, GameScene, etc.
- **Firebase Components**: Auth, Firestore, RTDB, Analytics, etc.
- **Game Components**: UI, Grid, Tray, Blocks, Particles, etc.
- **Debug Categories**: Debug-specific logging
- **System Components**: Memory, Network, Storage, Performance, Security
- **Feature Components**: Subscriptions, Analytics, IAP, Game Center, etc.

### Log Levels
- **Debug**: Detailed debugging information
- **Info**: General information
- **Warning**: Warning messages
- **Error**: Error messages
- **Critical**: Critical error messages

### Usage Examples
```swift
// Basic logging
Logger.shared.log("User logged in", category: .firebaseAuth, level: .info)

// Debug logging (only in debug mode)
Logger.shared.debug("Processing game state", category: .gameState)

// Error logging
Logger.shared.log("Failed to save progress", category: .firebaseManager, level: .error)
```

## Code Integration

### Checking Debug State
```swift
// Check if debug mode is active
if DebugManager.isDebugActive {
    // Show debug features
}

// Check specific debug features
if DebugManager.shouldShowDebugUI {
    // Show debug UI
}

if DebugManager.shouldShowDebugBorders {
    // Show debug borders
}
```

### Conditional Debug Code
```swift
// Debug-only code
#if DEBUG
if DebugManager.shouldShowDebugFeatures {
    // Debug-specific functionality
}
#endif

// Simulator-only code
#if targetEnvironment(simulator)
if DebugManager.shouldEnableDeviceSimulation {
    // Device simulation features
}
#endif
```

### Force Logout Integration
```swift
// Force logout is now controlled by DebugManager
if DebugManager.shouldEnableForceLogout {
    // Force logout functionality
}
```

## Production Build Safety

### Automatic Disabling
- All debug features are **automatically disabled** in RELEASE builds
- Debug Manager is **not accessible** in production builds
- Logging is **minimal** in production (only errors and critical events)
- Force logout is **disabled** by default

### Environment Detection
```swift
#if DEBUG
// Debug build - debug features available
#else
// Release build - debug features disabled
#endif
```

## Best Practices

### 1. Use Logger Instead of Print
```swift
// ❌ Don't do this
print("[Firebase] User logged in")

// ✅ Do this instead
Logger.shared.log("User logged in", category: .firebaseAuth, level: .info)
```

### 2. Check Debug State Before Debug Operations
```swift
// ❌ Don't do this
#if DEBUG
showDebugInfo()
#endif

// ✅ Do this instead
if DebugManager.shouldShowDebugFeatures {
    showDebugInfo()
}
```

### 3. Use Appropriate Log Levels
```swift
// Debug information
Logger.shared.log("Processing data", category: .gameState, level: .debug)

// Important information
Logger.shared.log("User completed level", category: .gameState, level: .info)

// Errors
Logger.shared.log("Failed to save", category: .firebaseManager, level: .error)
```

### 4. Test Production Mode
- Always test with **Production Mode** enabled in debug builds
- Verify that debug features are properly disabled
- Check that logging is minimal in production mode

## Troubleshooting

### Debug Manager Not Visible
1. Ensure you're running a **DEBUG** build
2. Check that **Debug Mode** is enabled
3. Verify that **Production Mode** is disabled

### Logging Not Working
1. Check that **Verbose Logging** is enabled
2. Verify the log category is enabled in `LoggerConfig.swift`
3. Ensure you're using the correct log level

### Force Logout Not Working
1. Enable **Force Logout** in Debug Manager
2. Check that **Debug Mode** is enabled
3. Verify that **Production Mode** is disabled

### Device Simulation Not Available
1. Ensure you're running in the **Simulator**
2. Enable **Device Simulation** in Debug Manager
3. Check that **Debug Mode** is enabled

## Migration Guide

### From Old Debug System
1. Replace `#if DEBUG` checks with `DebugManager.isDebugActive`
2. Replace `print()` statements with `Logger.shared.log()`
3. Update force logout logic to use `DebugManager.shouldEnableForceLogout`
4. Remove hard-coded debug toggles

### Example Migration
```swift
// Old way
#if DEBUG
print("[Firebase] User logged in")
if shouldForceLogout {
    forceLogout()
}
#endif

// New way
Logger.shared.log("User logged in", category: .firebaseAuth, level: .info)
if DebugManager.shouldEnableForceLogout {
    forceLogout()
}
```

## Scripts and Tools

### Replace Print Statements
Use the provided Python script to automatically replace print statements:
```bash
python replace_prints.py /path/to/your/project
```

### Clean Up Debug Code
1. Run the print replacement script
2. Review and adjust Logger categories
3. Test with Production Mode enabled
4. Verify all debug features are properly gated

## Security Considerations

### Debug Information
- Debug logs may contain sensitive information
- Always review debug output before sharing
- Debug features are automatically disabled in production

### Force Logout
- Force logout is disabled by default
- Only enable for testing purposes
- Never enable in production builds

### Device Simulation
- Device simulation is simulator-only
- Contains performance testing features
- Safe to use in development

## Support

For issues with the debug system:
1. Check this documentation
2. Verify debug mode is enabled
3. Test with production mode
4. Review Logger categories
5. Check environment detection

## Future Enhancements

### Planned Features
- Remote debug configuration
- Debug analytics dashboard
- Performance profiling tools
- Automated debug report generation
- Debug feature presets

### Contributing
When adding new debug features:
1. Add to `DebugManager.swift`
2. Update `LoggerConfig.swift` if needed
3. Add appropriate documentation
4. Test in both debug and production modes
5. Update this README 