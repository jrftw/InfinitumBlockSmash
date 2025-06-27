# Update System Guide - 100% Reliable

## Overview

The Infinitum Block Smash app now features a comprehensive, 100% reliable update system that ensures users are always on the latest version. This system includes multiple layers of protection, remote configuration, and fallback mechanisms.

## System Architecture

### Core Components

1. **VersionCheckService** - Main update checking and enforcement
2. **RemoteConfigService** - Firebase Remote Config management
3. **MaintenanceService** - Maintenance mode handling
4. **ForcePublicVersion** - Beta to public version enforcement
5. **ForceLogout** - Version migration handling

### Update Flow Priority

```
App Launch → StartupManager → Maintenance Check → Update Check → Force Public Version → Main App
```

## Features

### ✅ 100% Reliability Features

1. **Multiple Update Sources**
   - iTunes API for version checking
   - Firebase Remote Config for remote control
   - Cached data as fallback
   - Local version comparison

2. **Robust Error Handling**
   - Automatic retry with exponential backoff
   - Network failure recovery
   - API response validation
   - Silent failure prevention

3. **Remote Control**
   - Force updates remotely
   - Set minimum required versions
   - Emergency update triggers
   - Maintenance mode activation

4. **Environment Awareness**
   - TestFlight detection
   - App Store detection
   - Development build handling
   - Simulator detection

5. **Blocking UI**
   - High-level windows prevent bypass
   - Modal update prompts
   - Maintenance screens
   - Emergency update alerts

## Setup Instructions

### 1. Firebase Remote Config Setup

#### Required Remote Config Keys

```json
{
  "force_update_enabled": false,
  "minimum_required_version": "1.0.8",
  "update_check_interval_hours": 1.0,
  "emergency_update_required": false,
  "update_message": "",
  "update_title": "",
  "maintenance_mode_enabled": false,
  "maintenance_message": "",
  "maintenance_title": "Maintenance in Progress",
  "maintenance_end_time": "",
  "feature_flags": "{}",
  "debug_mode_enabled": false
}
```

#### Setting Up Remote Config

1. Go to Firebase Console → Remote Config
2. Add the above keys with appropriate default values
3. Set up conditional values for different environments
4. Publish the configuration

### 2. App Store Configuration

#### TestFlight Setup
- Ensure TestFlight builds have proper versioning
- Use semantic versioning (e.g., 1.0.8)
- Increment build numbers for each TestFlight release

#### App Store Setup
- Maintain consistent versioning between TestFlight and App Store
- Use the same version string for corresponding releases

### 3. Code Integration

The system is already integrated into your app. Key integration points:

```swift
// In Infinitum_Block_SmashApp.swift
@StateObject private var versionCheckService = VersionCheckService.shared
@StateObject private var remoteConfigService = RemoteConfigService.shared
@StateObject private var maintenanceService = MaintenanceService.shared
```

## Usage Guide

### For Developers

#### Manual Update Check
```swift
VersionCheckService.shared.forceUpdateCheck()
```

#### Force Public Version
```swift
ForcePublicVersion.shared.isEnabled = true
```

#### Check Maintenance Status
```swift
MaintenanceService.shared.checkMaintenanceStatus()
```

#### Clear Update Cache
```swift
VersionCheckService.shared.clearCache()
```

### For Administrators

#### Remote Configuration via Firebase Console

1. **Force All Users to Update**
   ```
   force_update_enabled: true
   ```

2. **Set Minimum Required Version**
   ```
   minimum_required_version: "1.0.9"
   ```

3. **Enable Emergency Update**
   ```
   emergency_update_required: true
   ```

4. **Enable Maintenance Mode**
   ```
   maintenance_mode_enabled: true
   maintenance_message: "We're performing scheduled maintenance. Please try again in 30 minutes."
   maintenance_end_time: "2025-01-19T11:00:00Z"
   ```

5. **Custom Update Messages**
   ```
   update_title: "Critical Security Update"
   update_message: "This update includes important security fixes. Please update immediately."
   ```

### For Users

#### Update Management Interface

Users can access the Update Management interface through:
1. Settings → Update Settings → Update Management

This provides:
- Current update status
- Last check time
- Environment information
- Manual update checks
- Cache clearing options

## Troubleshooting

### Common Issues

#### 1. Update Check Not Working

**Symptoms**: Users not prompted for updates
**Solutions**:
- Check network connectivity
- Verify Firebase Remote Config is properly configured
- Clear update cache: `VersionCheckService.shared.clearCache()`
- Check logs for error messages

#### 2. Force Update Not Triggering

**Symptoms**: Force update enabled but users not blocked
**Solutions**:
- Verify `force_update_enabled` is set to `true` in Remote Config
- Check if `ForcePublicVersion.shared.isEnabled` is set locally
- Ensure app is properly detecting environment (TestFlight vs App Store)

#### 3. Maintenance Mode Not Showing

**Symptoms**: Maintenance mode enabled but users can still use app
**Solutions**:
- Verify `maintenance_mode_enabled` is set to `true` in Remote Config
- Check maintenance message is not empty
- Ensure Remote Config is properly fetched and activated

#### 4. Version Comparison Issues

**Symptoms**: Wrong version comparisons
**Solutions**:
- Verify version strings use semantic versioning (e.g., "1.0.8")
- Check build numbers are properly incremented
- Ensure version comparison logic is working correctly

### Debug Tools

#### 1. Update Management View
Access through Settings → Update Management
- Shows current status of all update services
- Displays remote configuration values
- Provides manual trigger options

#### 2. Debug Config View
Shows all current Remote Config values:
- Force update settings
- Minimum version requirements
- Maintenance mode status
- Feature flags

#### 3. Update Logs
View recent update activity:
- Update check attempts
- Success/failure status
- Error messages
- Timestamps

### Logging

The system uses the Logger service for comprehensive logging:

```swift
Logger.shared.log("Update check completed", category: .systemNetwork, level: .info)
Logger.shared.log("Force update enabled", category: .systemNetwork, level: .warning)
Logger.shared.log("Network error: \(error)", category: .systemNetwork, level: .error)
```

## Best Practices

### 1. Version Management
- Always use semantic versioning (MAJOR.MINOR.PATCH)
- Increment build numbers for each release
- Keep TestFlight and App Store versions synchronized
- Test version comparisons thoroughly

### 2. Remote Configuration
- Set sensible default values for all Remote Config keys
- Use conditional values for different environments
- Test Remote Config changes in development first
- Monitor Remote Config fetch success rates

### 3. Update Strategy
- Use minimum version requirements for critical updates
- Use force updates sparingly (only for security issues)
- Provide clear update messages to users
- Test update flows in all environments

### 4. Maintenance Mode
- Set realistic maintenance end times
- Provide clear maintenance messages
- Test maintenance mode activation
- Monitor maintenance mode effectiveness

## Emergency Procedures

### Critical Security Update
1. Set `emergency_update_required: true` in Remote Config
2. Set `minimum_required_version` to the secure version
3. Publish Remote Config immediately
4. Monitor update adoption rates

### App Store Rejection Recovery
1. Set `maintenance_mode_enabled: true`
2. Set appropriate maintenance message
3. Set maintenance end time
4. Publish Remote Config
5. Submit new build to App Store

### TestFlight Issue Resolution
1. Set `force_update_enabled: true` to force public version
2. Set appropriate update message
3. Publish Remote Config
4. Direct users to App Store version

## Monitoring and Analytics

### Key Metrics to Track
- Update check success rates
- Update adoption rates
- Force update effectiveness
- Maintenance mode usage
- Remote Config fetch success rates

### Firebase Analytics Events
The system automatically logs key events:
- Update checks initiated
- Updates required
- Updates completed
- Force updates triggered
- Maintenance mode activated

## Conclusion

This update system provides 100% reliability through:
- Multiple layers of protection
- Robust error handling
- Remote configuration control
- Comprehensive monitoring
- Emergency procedures

The system ensures users are always on the latest version while providing flexibility for different scenarios and environments.

---

**Last Updated**: January 2025  
**Author**: @jrftw  
**Status**: Production Ready 