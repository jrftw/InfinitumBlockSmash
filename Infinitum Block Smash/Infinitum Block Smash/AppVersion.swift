import Foundation

struct AppVersion {
    static let current = "1.0.0"
    static let build = "3"
    
    static let changelog: [String: [String]] = [
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