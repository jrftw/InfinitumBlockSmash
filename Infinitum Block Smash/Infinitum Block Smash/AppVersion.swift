import Foundation

struct AppVersion {
    static let version = "1.0.7"
    static let build = "1"
    
    static var fullVersion: String {
        return "\(version) (\(build))"
    }
    
    static var displayVersion: String {
        return "Version \(version)"
    }
    
    static var buildNumber: Int {
        return Int(build) ?? 0
    }
    
    static var versionNumber: String {
        return version
    }
    
    static let changelog: [String: [String]] = [
        
        "1.0.7 (Build 1)": [
            "Performance optimizations",
            "Bug Fixes and Improvements"
        ],
        
        "1.0.6 (Build 1)": [
            "Performance optimizations",
            "Bug Fixes and Improvements"
        ],
        
        "1.0.5 (Build 3)": [
            "Fixed timestamp fatal crash error",
            "Bug Fixes and Improvements"
        ],
        
        "1.0.5 (Build 2)": [
            "Made the hint logic smarter",
            "Leaderboard UI enhancements",
            "Bug Fixes and Improvements"
        ],
        
        "1.0.5 (Build 1)": [
            "Added other apps by us",
            "Bug Fixes and Improvements"
        ],
        
        "1.0.4 (Build 2)": [
            "Added some UI Tweaks",
            "Other bug fixes and improvements on smaller screen sizes and larger screen sizes"
        ],
        
        "1.0.4 (Build 1)": [
            "Added some UI Tweaks",
            "Other bug fixes and improvements"
        ],
        
        "1.0.3 (Build 8)": [
            "Fixed score issues",
            "Fixed Need score issues"
        ],
        
        "1.0.3 (Build 7)": [
            "Added App Check security",
            "Enhanced Firestore rules",
            "Improved leaderboard security",
            "Bug fixes and performance improvements"
        ],
        "1.0.3 (Build 6)": [
            "Bug fixes and improvements"
        ],
        "1.0.3 (Build 5)": [
            "Fixed game over screen not appearing",
            "Prevented guest users from writing to leaderboard",
            "Fixed anonymous username generation",
            "Enhanced game stability and performance",
            "Bug fixes and improvements"
        ],
        "1.0.3 (Build 4)": [
            "Add Column and Row Highlighting when about to clear",
            "Enhanced game performance and stability",
            "Improved memory management",
            "Optimized battery consumption",
            "Enhanced user feedback system",
            "Bug fixes and performance improvements"
        ],
        "1.0.3 (Build 3)": [
            "Added Localization support for all languages"
        ],
        "1.0.3 (Build 2)": [
            "Enhanced game performance and stability",
            "Improved memory management and optimization",
            "Enhanced block placement mechanics",
            "Updated UI elements and animations",
            "Improved error handling and crash recovery",
            "Enhanced background task handling",
            "Optimized battery consumption",
            "Improved achievement tracking",
            "Enhanced user feedback system",
            "Bug fixes and performance improvements"
        ],
        "1.0.2 (Build 3)": [
            "Memory fixes:",
            "  - Reduced memory usage and improved cleanup",
            "  - Fixed memory leaks in particle system",
            "  - Optimized gradient cache management",
            "  - Enhanced memory pressure handling",
            "  - Improved resource cleanup timing"
        ],
        "1.0.2 (Build 2)": [
            "Enhanced subscription and in-app purchase system",
            "Added comprehensive purchase verification",
            "Improved subscription status tracking",
            "Enhanced trial period handling",
            "Added detailed purchase logging",
            "Improved error handling for purchases",
            "Enhanced restore purchases functionality",
            "Added subscription expiration tracking",
            "Improved feature access verification",
            "Enhanced purchase UI feedback",
            "Added environment-specific testing",
            "Improved sandbox testing support",
            "Enhanced production purchase handling",
            "Added detailed purchase analytics",
            "Improved subscription management",
            "Enhanced purchase security",
            "Bug fixes and performance improvements"
        ],
        "1.0.2 (Build 1)": [
            "Added new version tracking system",
            "Improved version display in settings",
            "Enhanced changelog organization",
            "Enhanced game performance and stability",
            "Improved block placement mechanics and precision",
            "Added new visual feedback for block interactions",
            "Optimized memory usage and battery consumption",
            "Enhanced achievement tracking and notifications",
            "Added new tutorial hints for better gameplay experience",
            "Enhanced UI responsiveness and animations",
            "Fixed various minor bugs and glitches",
            "Enhanced background task handling",
            "Updated privacy policy and data handling",
            "Improved error handling and crash recovery",
            "Enhanced user feedback system",
            "Optimized network connectivity handling",
            "Bug fixes and performance improvements"
        ],
        "1.0.1 (Build 1)": [
            "Added 'Block Drag Position' setting under Gameplay settings to adjust how high above your finger the block appears while dragging",
            "Added 'Placement Precision' setting under Gameplay settings to adjust how precisely you need to place blocks on the grid",
            "Added info buttons with descriptions for all settings",
            "Fixed game save/load functionality:",
            "  - Game now automatically saves when app moves to background or is terminated",
            "  - Game automatically loads saved progress when app starts",
            "  - Added proper scene lifecycle handling for reliable saves",
            "  - Added debug logging for save/load operations",
            "Fixed preview position to align perfectly with grid cells",
            "Improved drag node visibility while maintaining crisp placement mechanics",
            "Default settings:",
            "  - Placement Precision: 85%",
            "  - Block Drag Position: 40%",
            "Fixed ad implementation for production builds",
            "Test ads now only show in development and TestFlight",
            "Production ads properly configured for App Store release",
            "Improved ad loading and error handling",
            "Bug fixes and performance improvements"
        ],
        "1.0.0 (Build 7)": [
            "Added Block Drag Position setting",
            "Added Placement Precision setting",
            "Fixed game save/load functionality",
            "Improved block placement mechanics",
            "Added secure in-app Discord invite link",
            "Improved settings organization",
            "Enhanced user engagement features",
            "Fixed tray visibility and block placement issues",
            "Improved achievement tracking and progress display",
            "Added daily login achievement with 5 points reward",
            "Fixed achievement duplication and progress tracking",
            "Enhanced achievement notifications",
            "Bug fixes and performance improvements"
        ],
        "1.0.0 (Build 6)": [
            "Added daily notification system with fun reminders",
            "Notification permission requested on first launch",
            "Push Notifications, App Attest, and related entitlements added",
            "Notification preferences and device token display improved",
            "Bug fixes and performance improvements"
        ],
        "1.0.0 (Build 5)": [
            "Fixed game over state handling",
            "Improved game stability",
            "Enhanced achievement tracking",
            "Optimized performance",
            "Bug fixes and refinements"
        ],
        "1.0.0 (Build 4)": [
            "Added point system for touching blocks",
            "Fixed scoring system for block placement",
            "Improved game performance",
            "Enhanced UI responsiveness",
            "Bug fixes and optimizations"
        ],
        "1.0.0 (Build 3)": [
            "Fixed tray visibility and placement issues",
            "Improved game performance and stability",
            "Enhanced ad integration and compliance",
            "Updated UI/UX elements",
            "Bug fixes and optimizations"
        ],
        "1.0.0 (Build 2)": [
            "Added achievement system",
            "Implemented leaderboards",
            "Enhanced user authentication",
            "Added settings and customization options",
            "Improved game mechanics"
        ],
        "1.0.0 (Build 1)": [
            "Initial release",
            "Classic game mode",
            "Basic game mechanics",
            "Core gameplay features",
            "Essential UI elements"
        ]
    ]
    
    static var formattedVersion: String {
        "Version \(version) (Build \(build))"
    }
    
    static var copyright: String {
        "© 2025 Infinitum Imagery LLC All Rights Reserved"
    }
    
    static var credits: String {
        "Made by @JrFTW"
    }
    
    static var location: String {
        "Made in Pittsburgh, PA 🇺🇸"
    }
    
    static var fullVersionInfo: String {
        """
        \(formattedVersion)
        \(copyright)
        \(credits)
        \(location)
        """
    }
    
    static func getChangelog(for version: String) -> [String] {
        changelog[version] ?? []
    }
    
    static var currentChangelog: [String] {
        getChangelog(for: version)
    }
} 
