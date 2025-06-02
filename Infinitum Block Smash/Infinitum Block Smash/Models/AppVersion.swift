import Foundation

struct AppVersion {
    static let current = "1.0.0"
    
    static let changelog: [String: [String]] = [
        "1.0.0": [
            "Initial release",
            "Classic game mode",
            "Achievement system",
            "Leaderboards",
            "User authentication",
            "Settings and customization"
        ]
    ]
    
    static var formattedVersion: String {
        "Version \(current)"
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
} 