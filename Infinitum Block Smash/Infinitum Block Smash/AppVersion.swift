import Foundation

struct AppVersion {
    static let current = "1.0.0"
    static let build = "6"
    
    static let changelog: [String: [String]] = [
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