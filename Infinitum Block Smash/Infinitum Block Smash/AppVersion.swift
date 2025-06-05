import Foundation

struct AppVersion {
    static let current = "1.0.1"
    static let build = "1"
    
    static let changelog: [String: [String]] = [
        "1.0.1 (Build 1)": [
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
        "Version \(current) (Build \(build))"
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
} 