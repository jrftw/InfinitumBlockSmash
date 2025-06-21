# Xcode Project Update Guide - Phase 5

## Overview

This guide provides step-by-step instructions for updating the Xcode project to match the organized folder structure. This will ensure that the Xcode project groups align with the actual file organization, making navigation and development much easier.

## Current Situation

- **Xcode Project Location**: `../Infinitum Block Smash.xcodeproj` (one directory up from current workspace)
- **Current Workspace**: `Infinitum Block Smash/` (contains all organized files)
- **Goal**: Update Xcode project groups to match the folder structure

## Prerequisites

1. **Backup**: The Xcode project already has backup files (`project.pbxproj.backup`)
2. **File Organization**: All files are properly organized in the folder structure
3. **Xcode Version**: Ensure you're using Xcode 14.0+ for best compatibility

## Step-by-Step Update Process

### Step 1: Open the Xcode Project

1. **Navigate to the project directory**:
   ```bash
   cd "../Infinitum Block Smash.xcodeproj"
   ```

2. **Open the project in Xcode**:
   ```bash
   open "Infinitum Block Smash.xcodeproj"
   ```
   
   Or double-click the `.xcodeproj` file in Finder.

### Step 2: Verify Current Project Structure

1. **In Xcode, examine the current project navigator**:
   - Look at the current group structure
   - Note any files that are in the wrong groups
   - Identify any missing files or broken references

2. **Check for any build errors**:
   - Build the project (⌘+B) to ensure it compiles
   - Note any missing file references

### Step 3: Update Project Groups

#### 3.1 Create New Group Structure

Create the following groups in the Xcode project navigator to match the folder structure:

```
📁 Infinitum Block Smash
├── 📁 App
├── 📁 Config
├── 📁 Resources
├── 📁 Models
├── 📁 Services
├── 📁 Views
├── 📁 ViewModels
├── 📁 Components
├── 📁 Extensions
├── 📁 Utilities
├── 📁 Game
│   ├── 📁 GameState
│   ├── 📁 GameScene
│   ├── 📁 GameMechanics
│   ├── 📁 GameUI
│   └── 📁 Particles
├── 📁 Features
│   ├── 📁 Authentication
│   │   ├── 📁 Views
│   │   ├── 📁 ViewModels
│   │   └── 📁 Components
│   ├── 📁 Achievements
│   │   ├── 📁 Views
│   │   ├── 📁 Components
│   │   └── 📁 Services
│   ├── 📁 Leaderboard
│   │   ├── 📁 Views
│   │   ├── 📁 Models
│   │   └── 📁 Services
│   ├── 📁 Subscription
│   │   ├── 📁 Views
│   │   └── 📁 Services
│   ├── 📁 Referral
│   │   ├── 📁 Views
│   │   └── 📁 Services
│   ├── 📁 Analytics
│   │   ├── 📁 Views
│   │   └── 📁 Components
│   ├── 📁 Debug
│   │   ├── 📁 Views
│   │   └── 📁 Services
│   └── 📁 Ads
│       ├── 📁 Views
│       └── 📁 Services
├── 📁 Managers
└── 📁 Documentation
```

#### 3.2 Move Files to Correct Groups

**App Group**:
- `Infinitum_Block_SmashApp.swift`
- `AppVersion.swift`
- `StartupManager.swift`
- `ForceLogout.swift`
- `ForcePublicVersion.swift`
- `Info.plist`

**Config Group**:
- `Constants.swift`
- `MemoryConfig.swift`
- `LoggerConfig.swift`
- `GoogleService-Info.plist`
- `firestore.rules`
- `realtime.rules.json`
- `storage.rules`
- `app-ads.txt`
- `Infinitum Block Smash.entitlements`
- `BLock_Blast_profile.mobileprovision`

**Resources Group**:
- `Assets.xcassets/`
- All `.lproj` folders (Base, ar, bn, de, es, fr, hi, ja, pa, pt, ru, zh-Hans)
- `LaunchScreen.storyboard`
- `Main.storyboard`

**Models Group**:
- `Block.swift`
- `GameMove.swift`
- `GameProgress.swift`
- `Hint.swift`
- `TimeRange.swift`
- `GameDataVersion.swift`

**Services Group**:
- `FirebaseManager.swift`
- `LeaderboardService.swift`
- `LeaderboardCache.swift`
- `NotificationService.swift`
- `BackupService.swift`
- `CacheManager.swift`
- `AnnouncementsService.swift`
- `VersionCheckService.swift`
- `BugsService.swift`

**Views Group**:
- `ContentView.swift`
- `GameView.swift`
- `SettingsView.swift`
- `StatsView.swift`
- `BugsView.swift`
- `ChangelogView.swift`
- `EULAView.swift`
- `MoreAppsView.swift`
- `GameModeSelectionView.swift`
- `ClassicTimedGameView.swift`
- `ClassicTimedRulesView.swift`
- `GameRulesView.swift`
- `AdminMigrationView.swift`
- `NotificationPreferencesView.swift`
- `ChangeInformationView.swift`
- `RatingPromptView.swift`
- `LaunchLoadingView.swift`
- `CrashReportView.swift`
- `AnnouncementsView.swift`

**ViewModels Group**:
- `AuthViewModel.swift`

**Components Group**:
- `BannerAdView.swift`
- `BlurView.swift`
- `ButtonStyles.swift`
- `GameTopBar.swift`
- `GameOverOverlay.swift`
- `LevelCompleteOverlay.swift`
- `PauseMenuOverlay.swift`
- `ScoreAnimationView.swift`
- `HighScoreBannerView.swift`
- `TutorialModal.swift`
- `BlockShapeView.swift`

**Extensions Group**:
- `NotificationName+Extension.swift`
- `Color+Hex.swift`
- `SKColor+Hex.swift`
- `UIImageView+Cache.swift`
- `CalendarExtensions.swift`
- `DateFormatter+Extension.swift`
- `GameStateExtension.swift`

**Utilities Group**:
- `Logger.swift`
- `SecurityLogger.swift`
- `CrashReporter.swift`
- `PerformanceMonitor.swift`
- `ProfanityFilter.swift`
- `ManualLeaderboardUpdate.swift`
- `MyAppCheckProviderFactory.swift`
- `MemoryLeakDetector.swift`
- `NetworkMetricsManager.swift`
- `upload-symbols.sh`
- `replace_prints.py`

**Game Group**:

**GameState Subgroup**:
- `GameState.swift`
- `ClassicTimedGameState.swift`

**GameScene Subgroup**:
- `GameScene.swift`
- `GameSceneExtension.swift`
- `GameSceneProvider.swift`
- `GameBoard.swift`
- `GridRenderer.swift`
- `ShapeNode.swift`
- `TrayNode.swift`
- `NodePool.swift`

**GameMechanics Subgroup**:
- `AdaptiveDifficultyManager.swift`
- `AdaptiveQualityManager.swift`
- `FPSManager.swift`
- `MemorySystem.swift`
- `GameAnalytics.swift`

**Particles Subgroup**:
- `BackgroundParticles.sks`
- `ClearParticles.sks`

**Features Group**:

**Authentication Subgroup**:
- **Views**: `AuthView.swift`, `LoginView.swift`, `SignUpView.swift`
- **ViewModels**: `AuthViewModel.swift`
- **Components**: `AuthComponents.swift`

**Achievements Subgroup**:
- **Views**: `AchievementsView.swift`, `AchievementLeaderboardView.swift`
- **Components**: `AchievementNotificationOverlay.swift`

**Leaderboard Subgroup**:
- **Views**: `LeaderboardView.swift`
- **Models**: `LeaderboardModels.swift`
- **Services**: `LeaderboardService.swift`, `LeaderboardCache.swift`

**Subscription Subgroup**:
- **Views**: `StoreView.swift`, `SubscriptionView.swift`

**Referral Subgroup**:
- **Views**: `ReferralView.swift`, `ReferralPromptView.swift`

**Analytics Subgroup**:
- **Views**: `AnalyticsDashboardView.swift`
- **Components**: `AnalyticsCharts.swift`

**Debug Subgroup**:
- **Views**: `DebugLogsView.swift`, `DeviceSimulationDebugView.swift`

**Ads Subgroup**:
- **Views**: `BannerAdView.swift`

**Managers Group**:
- `GameCenterManager.swift`
- `AudioManager.swift`
- `ThemeManager.swift`
- `DeviceManager.swift`
- `NotificationManager.swift`

**Documentation Group**:
- All `.md` files
- `bugs.json`

### Step 4: Update File References

#### 4.1 Remove Broken References

1. **In Xcode, look for red file references** (broken links)
2. **Remove these broken references**:
   - Right-click on red files
   - Select "Delete"
   - Choose "Remove Reference" (not "Move to Trash")

#### 4.2 Add Missing Files

1. **For each missing file**:
   - Right-click on the appropriate group
   - Select "Add Files to [Project Name]"
   - Navigate to the file in the folder structure
   - Select the file
   - Ensure "Add to target" is checked
   - Click "Add"

#### 4.3 Update File Paths

1. **For files with incorrect paths**:
   - Select the file in Xcode
   - Open the File Inspector (right panel)
   - Update the "Location" field to point to the correct path
   - Or remove and re-add the file

### Step 5: Verify Build Configuration

#### 5.1 Check Target Membership

1. **Select each file** and verify it's added to the correct target:
   - In the File Inspector, ensure the target checkbox is selected
   - Files should be added to the main app target

#### 5.2 Check Build Phases

1. **Open the project settings**:
   - Select the project in the navigator
   - Select the target
   - Go to "Build Phases"

2. **Verify file organization**:
   - Check that files are in the correct build phases
   - Ensure no duplicate files
   - Verify that all necessary files are included

### Step 6: Test the Project

#### 6.1 Build the Project

1. **Clean the build folder**:
   - Product → Clean Build Folder (⇧⌘K)

2. **Build the project**:
   - Product → Build (⌘B)

3. **Check for errors**:
   - Fix any compilation errors
   - Address any missing file warnings

#### 6.2 Run the Project

1. **Select a simulator or device**
2. **Run the project** (⌘R)
3. **Verify the app launches correctly**
4. **Test basic functionality**

### Step 7: Update Project Settings

#### 7.1 Update Search Paths

1. **In project settings**:
   - Select the project
   - Go to "Build Settings"
   - Search for "Search Paths"
   - Ensure the folder structure is properly referenced

#### 7.2 Update Info.plist Reference

1. **Verify Info.plist location**:
   - In project settings, check "Info.plist File" setting
   - Update if necessary to point to `Config/Info.plist`

### Step 8: Final Verification

#### 8.1 Project Structure Check

1. **Verify all groups match the folder structure**
2. **Ensure no files are in the wrong groups**
3. **Check that all files are properly referenced**

#### 8.2 Documentation Update

1. **Update PROJECT_STRUCTURE_SUMMARY.md**:
   - Mark Phase 5 as complete
   - Add any notes about the update process

## Troubleshooting

### Common Issues

#### Issue: Files showing as red (broken references)
**Solution**: Remove the broken reference and re-add the file from its correct location.

#### Issue: Build errors due to missing files
**Solution**: Check that all files are added to the correct target and build phases.

#### Issue: Files in wrong groups
**Solution**: Drag files to the correct groups in the project navigator.

#### Issue: Duplicate files
**Solution**: Remove duplicate references, keeping only the correct one.

#### Issue: Build path errors
**Solution**: Check that file paths in the project settings are correct.

### Recovery Steps

If something goes wrong:

1. **Restore from backup**:
   - Close Xcode
   - Copy `project.pbxproj.backup` to `project.pbxproj`
   - Reopen the project

2. **Start over**:
   - Follow the steps more carefully
   - Make smaller changes and test frequently

## Success Criteria

The Xcode project update is complete when:

- ✅ All files are in the correct groups matching the folder structure
- ✅ No red (broken) file references
- ✅ Project builds successfully without errors
- ✅ App runs correctly on simulator/device
- ✅ All functionality works as expected
- ✅ Project navigator is clean and organized

## Post-Update Tasks

1. **Commit changes** to version control
2. **Update team documentation** about the new structure
3. **Test on different machines** to ensure consistency
4. **Update any CI/CD scripts** that reference the old structure

## Benefits of Updated Structure

- **Easier Navigation**: Files are logically grouped
- **Better Organization**: Clear separation of concerns
- **Improved Collaboration**: Team members can find files quickly
- **Scalability**: Easy to add new features in appropriate groups
- **Maintainability**: Clear structure makes maintenance easier

---

**Last Updated**: January 2025  
**Author**: @jrftw  
**Status**: Ready for Implementation 