# UserDefaults Hang Risk Fix

## Problem Description

The app was experiencing hang risks due to performing I/O operations on the main thread. The specific warning was:

```
/Users/junior/Library/Developer/Xcode/DerivedData/Infinitum_Block_Smash-eqtkdgbgdcnjzjbasxjztkqpipco/SourcePackages/checkouts/GoogleUtilities/GoogleUtilities/Environment/GULAppEnvironmentUtil.m:213 Performing I/O on the main thread can cause hangs.
```

This warning indicates that synchronous I/O operations are being performed on the main thread, which can cause the UI to freeze and the app to become unresponsive.

## Root Cause Analysis

The main culprits were:

1. **UserDefaults.synchronize()** calls on the main thread
2. **UserDefaults.standard.set()** followed by immediate synchronization
3. **FileManager operations** on the main thread
4. **Bundle operations** on the main thread

### Specific Issues Found

The script identified the following problematic patterns:

- **10 instances** of `UserDefaults.standard.synchronize()` calls
- **80+ instances** of `UserDefaults.standard.set()` calls
- **6 instances** of `UserDefaults.standard.removeObject()` calls
- **1 instance** of `UserDefaults.standard.removePersistentDomain()` calls

## Solution Implemented

### 1. Created UserDefaultsManager

A new `UserDefaultsManager` class was created in `Utilities/UserDefaultsManager.swift` that:

- **Performs all disk I/O on background threads**
- **Maintains immediate memory access for reads**
- **Queues write operations for background synchronization**
- **Provides thread-safe operations**
- **Includes convenience methods for common operations**

### 2. Key Features

```swift
@MainActor
class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()
    
    // Safe read operations (main thread safe)
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func string(forKey key: String) -> String?
    
    // Safe write operations (background thread)
    func set(_ value: Any?, forKey key: String)
    func setBool(_ value: Bool, forKey key: String)
    func setInteger(_ value: Int, forKey key: String)
    
    // Batch operations
    func setMultiple(_ values: [String: Any])
    
    // Force synchronization
    func synchronize() async
}
```

### 3. Threading Model

- **Read operations**: Immediate access from memory (main thread safe)
- **Write operations**: Stored in memory immediately, synchronized in background
- **Synchronization**: Automatic background queue with periodic flushing
- **Async support**: `synchronize()` method for explicit synchronization

### 4. Migration Strategy

#### Before (Hang Risk):
```swift
UserDefaults.standard.set(value, forKey: key)
UserDefaults.standard.synchronize() // ❌ Main thread I/O
```

#### After (Safe):
```swift
UserDefaultsManager.shared.set(value, forKey: key)
// ✅ Automatic background synchronization
```

## Migration Guide

### Step 1: Replace Direct UserDefaults Calls

Replace all instances of:
- `UserDefaults.standard.synchronize()` → `UserDefaultsManager.shared.synchronize()`
- `UserDefaults.standard.set()` → `UserDefaultsManager.shared.set()`
- `UserDefaults.standard.removeObject()` → `UserDefaultsManager.shared.removeObject()`

### Step 2: Use Convenience Methods

For common operations, use the provided convenience methods:

```swift
// Instead of:
UserDefaults.standard.set(true, forKey: "soundEnabled")

// Use:
UserDefaultsManager.shared.setSoundEnabled(true)

// Instead of:
UserDefaults.standard.integer(forKey: "highScore")

// Use:
UserDefaultsManager.shared.getHighScore()
```

### Step 3: Handle Async Operations

For operations that require explicit synchronization:

```swift
// Old way:
UserDefaults.standard.synchronize()

// New way:
await UserDefaultsManager.shared.synchronize()
```

## Files Modified

### Created:
- `Utilities/UserDefaultsManager.swift` - Main manager class
- `Scripts/fix_userdefaults_hang_risk.sh` - Migration helper script
- `Documentation/USERDEFAULTS_HANG_RISK_FIX.md` - This documentation

### Files Requiring Migration:
- `Services/FirebaseManager.swift` (10+ instances)
- `Views/GameView.swift` (2 instances)
- `Views/SettingsView.swift` (2 instances)
- `Game/GameState/GameState.swift` (3 instances)
- `Game/GameMechanics/FPSManager.swift` (1 instance)
- `Models/GameDataVersion.swift` (1 instance)
- `Managers/ThemeManager.swift` (1 instance)
- And many more...

## Testing

### Verification Steps:
1. Run the migration script: `./Scripts/fix_userdefaults_hang_risk.sh`
2. Check that no `UserDefaults.standard.synchronize()` calls remain
3. Verify app functionality remains intact
4. Test on different devices and iOS versions
5. Monitor for any new hang warnings

### Performance Impact:
- **Positive**: Eliminates main thread I/O hangs
- **Minimal**: Background operations have negligible impact
- **Improved**: Better app responsiveness and stability

## Best Practices Going Forward

### ✅ Do:
- Use `UserDefaultsManager.shared` for all UserDefaults operations
- Use convenience methods when available
- Handle async operations properly with `await`
- Test on low-end devices

### ❌ Don't:
- Call `UserDefaults.standard.synchronize()` directly
- Perform heavy I/O operations on the main thread
- Mix old and new UserDefaults patterns
- Forget to handle async operations

## Monitoring

### Warning Signs:
- App freezes during data operations
- UI becomes unresponsive
- Xcode warnings about main thread I/O
- Performance degradation on older devices

### Debug Tools:
- Xcode's Main Thread Checker
- Instruments for performance profiling
- Console logs for I/O warnings
- The provided migration script

## Conclusion

This fix addresses the core issue of main thread I/O operations that were causing hang risks. The `UserDefaultsManager` provides a safe, efficient, and maintainable solution that:

1. **Eliminates hang risks** by moving I/O to background threads
2. **Maintains performance** with immediate memory access
3. **Provides convenience** with game-specific methods
4. **Ensures compatibility** with existing code patterns
5. **Improves maintainability** with centralized UserDefaults management

The migration should be completed systematically across all affected files to ensure the app runs smoothly without any main thread I/O warnings. 