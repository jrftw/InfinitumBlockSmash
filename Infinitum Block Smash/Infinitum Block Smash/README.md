# Infinitum Block Smash

A modern iOS puzzle game built with SwiftUI and Firebase, featuring adaptive difficulty, thermal optimization, and comprehensive analytics.

## 🎮 Overview

Infinitum Block Smash is a sophisticated block-matching puzzle game that combines classic gameplay mechanics with modern iOS features. The game features adaptive difficulty, thermal optimization, comprehensive analytics, and a robust backend infrastructure.

## 🏗️ Architecture

The project follows a modular architecture with clear separation of concerns:

- **App/**: Core application files and entry points
- **Game/**: Game-specific logic organized by domain
- **Features/**: Feature-specific modules (Authentication, Achievements, etc.)
- **Components/**: Reusable UI components
- **Services/**: Backend and external services
- **Managers/**: Core system managers
- **Models/**: Data models and structures
- **Views/**: Main UI views
- **Extensions/**: Swift extensions and utilities
- **Config/**: Configuration files and settings
- **Resources/**: Assets and localization files

## 🚀 Key Features

- **Adaptive Difficulty**: Dynamic difficulty adjustment based on player performance
- **Thermal Optimization**: Prevents device overheating with intelligent performance management
- **Memory Management**: Comprehensive memory optimization and leak detection
- **Debug System**: Centralized debug controls for development and testing
- **Device Simulation**: Test with realistic device constraints in simulator
- **Analytics**: Comprehensive game analytics and performance monitoring
- **Firebase Integration**: Full backend integration with Firestore and RTDB
- **Game Center**: Leaderboards and achievements
- **In-App Purchases**: Subscription management and premium features

## 📱 Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Firebase project setup
- Apple Developer Account (for distribution)

## 🛠️ Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd "Infinitum Block Smash"
```

### 2. Install Dependencies
The project uses Swift Package Manager for dependencies. Dependencies will be automatically resolved when you open the project in Xcode.

### 3. Firebase Setup
1. Create a Firebase project
2. Add an iOS app to your Firebase project
3. Download `GoogleService-Info.plist` and place it in the `Config/` directory
4. Enable the following Firebase services:
   - Authentication
   - Firestore Database
   - Realtime Database
   - Analytics
   - Crashlytics
   - Remote Config
   - Cloud Messaging

### 4. Build and Run
1. Open `Infinitum Block Smash.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run the project

## 🧪 Development

### Debug System
The app includes a comprehensive debug system accessible in DEBUG builds:
- Go to Settings → Debug Manager
- Enable debug features for development
- Use device simulation for testing different device constraints

### Device Simulation
Test your app with realistic device constraints:
- Memory limitations based on actual device RAM
- Performance constraints matching real devices
- Thermal throttling simulation

### Memory Management
The app includes sophisticated memory management:
- Automatic memory cleanup every 60 seconds
- Memory pressure detection and response
- Leak detection and reporting

## 📚 Documentation

- [Project Structure](Documentation/PROJECT_STRUCTURE_SUMMARY.md) - Detailed project organization
- [Debug System](Documentation/DEBUG_SYSTEM_README.md) - Debug features and controls
- [Device Simulation](Documentation/DEVICE_SIMULATION_README.md) - Testing with device constraints
- [Memory Optimization](Documentation/MEMORY_OPTIMIZATION_SUMMARY.md) - Memory management details
- [Thermal Optimization](Documentation/THERMAL_OPTIMIZATION_SUMMARY.md) - Performance and thermal management
- [Safety Fixes](Documentation/SAFETY_FIXES_SUMMARY.md) - Security and safety improvements
- [Build Conflicts Fix](Documentation/BUILD_CONFLICTS_FIX.md) - Build system troubleshooting

## 🏆 Features

### Game Mechanics
- **Block Placement**: Strategic block placement on a 10x10 grid
- **Line Clearing**: Clear lines to score points and progress
- **Adaptive Difficulty**: Dynamic difficulty based on player skill
- **Undo System**: Undo moves with ad-based or premium options
- **Hint System**: Intelligent hints for challenging situations

### Technical Features
- **Thermal Management**: Prevents device overheating
- **Memory Optimization**: Efficient memory usage and cleanup
- **Performance Monitoring**: Real-time FPS and performance tracking
- **Offline Support**: Queue system for offline data changes
- **Cross-Device Sync**: Firebase-based progress synchronization

### User Experience
- **Modern UI**: SwiftUI-based interface with smooth animations
- **Accessibility**: Full accessibility support
- **Localization**: Multi-language support
- **Dark Mode**: Automatic dark/light mode support
- **Haptic Feedback**: Tactile feedback for interactions

## 🔧 Configuration

### Environment Variables
The app automatically detects the build environment:
- **DEBUG**: Full debug features and verbose logging
- **RELEASE**: Minimal logging and optimized performance

### Firebase Configuration
All Firebase configuration is handled in `Config/GoogleService-Info.plist` and the app automatically configures services based on the environment.

## 🐛 Troubleshooting

### Build Issues
If you encounter build conflicts, run:
```bash
./Scripts/clean_build_conflicts.sh
```

### Memory Issues
The app includes comprehensive memory management, but if you encounter issues:
1. Check the debug logs for memory warnings
2. Use the device simulation to test with memory constraints
3. Review the memory optimization documentation

### Performance Issues
1. Enable debug mode to monitor performance
2. Check thermal optimization settings
3. Use device simulation to test on different device types

## 📄 License

This project is proprietary software. See [EULA.md](Documentation/EULA.md) for terms of use.

## 🤝 Contributing

For internal development:
1. Follow the existing code style and architecture
2. Add comprehensive headers to new files
3. Update documentation for any architectural changes
4. Test with device simulation before submitting

## 📞 Support

For technical support or questions:
- Check the documentation in the `Documentation/` directory
- Review the debug logs for error information
- Use the debug system for troubleshooting

---

**Last Updated**: January 2025  
**Version**: See `App/AppVersion.swift` for current version information 