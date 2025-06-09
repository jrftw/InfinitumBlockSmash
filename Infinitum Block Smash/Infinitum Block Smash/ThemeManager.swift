import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: String = UserDefaults.standard.string(forKey: "selectedTheme") ?? "system"
    @Published var systemTheme: String = UserDefaults.standard.string(forKey: "systemTheme") ?? "auto"
    
    private let availableThemes = [
        "system": Theme(
            name: "System",
            colors: ThemeColors(
                primary: Color.accentColor,
                background: Color(.systemBackground),
                secondary: Color(.secondarySystemBackground),
                text: Color(.label)
            ),
            isCustom: false,
            isFree: true
        ),
        "neon": Theme(
            name: "Neon",
            colors: ThemeColors(
                primary: Color(red: 0.0, green: 1.0, blue: 0.5),
                background: Color(red: 0.1, green: 0.1, blue: 0.2),
                secondary: Color(red: 0.2, green: 0.2, blue: 0.3),
                text: Color(red: 0.0, green: 1.0, blue: 0.5)
            ),
            isCustom: true,
            isFree: false
        ),
        "retro": Theme(
            name: "Retro",
            colors: ThemeColors(
                primary: Color(red: 1.0, green: 0.4, blue: 0.0),
                background: Color(red: 0.2, green: 0.2, blue: 0.2),
                secondary: Color(red: 0.3, green: 0.3, blue: 0.3),
                text: Color(red: 1.0, green: 0.8, blue: 0.0)
            ),
            isCustom: true,
            isFree: false
        ),
        "nature": Theme(
            name: "Nature",
            colors: ThemeColors(
                primary: Color(red: 0.2, green: 0.8, blue: 0.2),
                background: Color(red: 0.9, green: 0.95, blue: 0.9),
                secondary: Color(red: 0.8, green: 0.9, blue: 0.8),
                text: Color(red: 0.2, green: 0.4, blue: 0.2)
            ),
            isCustom: true,
            isFree: false
        ),
        "pride": Theme(
            name: "Execution",
            colors: ThemeColors(
                primary: Color(red: 0.95, green: 0.2, blue: 0.2),
                background: Color(red: 0.1, green: 0.1, blue: 0.15),
                secondary: Color(red: 0.15, green: 0.15, blue: 0.2),
                text: Color(red: 1.0, green: 1.0, blue: 1.0)
            ),
            isCustom: true,
            isFree: false
        ),
        "rainbow": Theme(
            name: "Rainbow",
            colors: ThemeColors(
                primary: Color(red: 1.0, green: 0.0, blue: 0.0),  // Red
                background: Color(red: 0.0, green: 0.5, blue: 0.8),  // Blue
                secondary: Color(red: 0.5, green: 0.0, blue: 0.5),  // Purple
                text: Color(red: 1.0, green: 1.0, blue: 1.0)  // White
            ),
            isCustom: true,
            isFree: false
        ),
        "adventure": Theme(
            name: "Adventure",
            colors: ThemeColors(
                primary: Color(red: 0.8, green: 0.4, blue: 0.1),
                background: Color(red: 0.15, green: 0.1, blue: 0.05),
                secondary: Color(red: 0.25, green: 0.2, blue: 0.15),
                text: Color(red: 1.0, green: 0.9, blue: 0.7)
            ),
            isCustom: true,
            isFree: false
        ),
        "cyberpunk": Theme(
            name: "Cyberpunk",
            colors: ThemeColors(
                primary: Color(red: 1.0, green: 0.0, blue: 0.8),
                background: Color(red: 0.05, green: 0.05, blue: 0.1),
                secondary: Color(red: 0.15, green: 0.15, blue: 0.2),
                text: Color(red: 0.0, green: 1.0, blue: 0.8)
            ),
            isCustom: true,
            isFree: false
        ),
        "sunset": Theme(
            name: "Sunset",
            colors: ThemeColors(
                primary: Color(red: 1.0, green: 0.6, blue: 0.0),
                background: Color(red: 0.2, green: 0.1, blue: 0.2),
                secondary: Color(red: 0.3, green: 0.2, blue: 0.3),
                text: Color(red: 1.0, green: 0.8, blue: 0.6)
            ),
            isCustom: true,
            isFree: false
        ),
        "ocean": Theme(
            name: "Ocean",
            colors: ThemeColors(
                primary: Color(red: 0.0, green: 0.7, blue: 1.0),
                background: Color(red: 0.1, green: 0.2, blue: 0.3),
                secondary: Color(red: 0.2, green: 0.3, blue: 0.4),
                text: Color(red: 0.8, green: 0.9, blue: 1.0)
            ),
            isCustom: true,
            isFree: false
        ),
        "forest": Theme(
            name: "Forest",
            colors: ThemeColors(
                primary: Color(red: 0.4, green: 0.8, blue: 0.2),
                background: Color(red: 0.1, green: 0.15, blue: 0.1),
                secondary: Color(red: 0.2, green: 0.25, blue: 0.2),
                text: Color(red: 0.8, green: 0.9, blue: 0.8)
            ),
            isCustom: true,
            isFree: false
        ),
        "nordic": Theme(
            name: "Nordic",
            colors: ThemeColors(
                primary: Color(red: 0.4, green: 0.6, blue: 0.8),
                background: Color(red: 0.9, green: 0.9, blue: 0.95),
                secondary: Color(red: 0.8, green: 0.85, blue: 0.9),
                text: Color(red: 0.2, green: 0.3, blue: 0.4)
            ),
            isCustom: true,
            isFree: false
        ),
        "midnight": Theme(
            name: "Midnight",
            colors: ThemeColors(
                primary: Color(red: 0.6, green: 0.4, blue: 1.0),
                background: Color(red: 0.05, green: 0.05, blue: 0.1),
                secondary: Color(red: 0.15, green: 0.15, blue: 0.2),
                text: Color(red: 0.9, green: 0.9, blue: 1.0)
            ),
            isCustom: true,
            isFree: false
        ),
        "desert": Theme(
            name: "Desert",
            colors: ThemeColors(
                primary: Color(red: 0.9, green: 0.7, blue: 0.3),
                background: Color(red: 0.95, green: 0.9, blue: 0.8),
                secondary: Color(red: 0.9, green: 0.85, blue: 0.7),
                text: Color(red: 0.4, green: 0.3, blue: 0.2)
            ),
            isCustom: true,
            isFree: false
        ),
        "aurora": Theme(
            name: "Aurora",
            colors: ThemeColors(
                primary: Color(red: 0.0, green: 0.8, blue: 0.6),
                background: Color(red: 0.1, green: 0.1, blue: 0.15),
                secondary: Color(red: 0.15, green: 0.15, blue: 0.2),
                text: Color(red: 0.8, green: 1.0, blue: 0.9)
            ),
            isCustom: true,
            isFree: false
        ),
        "cherry": Theme(
            name: "Cherry",
            colors: ThemeColors(
                primary: Color(red: 0.9, green: 0.2, blue: 0.3),
                background: Color(red: 0.95, green: 0.95, blue: 0.97),
                secondary: Color(red: 0.9, green: 0.9, blue: 0.95),
                text: Color(red: 0.3, green: 0.1, blue: 0.1)
            ),
            isCustom: true,
            isFree: false
        )
    ]
    
    private init() {
        // Initialize system theme
        if let savedSystemTheme = UserDefaults.standard.string(forKey: "systemTheme") {
            systemTheme = savedSystemTheme
        }
        
        // Initialize current theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") {
            currentTheme = savedTheme
        }
    }
    
    func setTheme(_ theme: String) {
        if ["light", "dark", "auto"].contains(theme) {
            systemTheme = theme
            UserDefaults.standard.set(theme, forKey: "systemTheme")
            currentTheme = "system"
            UserDefaults.standard.set("system", forKey: "selectedTheme")
        } else {
            currentTheme = theme
            UserDefaults.standard.set(theme, forKey: "selectedTheme")
        }
        NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
    }
    
    func getCurrentTheme() -> Theme {
        if currentTheme == "system" {
            // Use system theme colors based on systemTheme setting
            switch systemTheme {
            case "light":
                return Theme(
                    name: "System Light",
                    colors: ThemeColors(
                        primary: Color.accentColor,
                        background: Color(.systemBackground),
                        secondary: Color(.secondarySystemBackground),
                        text: Color(.label)
                    ),
                    isCustom: false,
                    isFree: true
                )
            case "dark":
                return Theme(
                    name: "System Dark",
                    colors: ThemeColors(
                        primary: Color.accentColor,
                        background: Color(.systemBackground),
                        secondary: Color(.secondarySystemBackground),
                        text: Color(.label)
                    ),
                    isCustom: false,
                    isFree: true
                )
            default: // "auto"
                return availableThemes["system"]!
            }
        }
        return availableThemes[currentTheme] ?? availableThemes["system"]!
    }
    
    func getAvailableThemes() -> [String: Theme] {
        return availableThemes
    }
    
    func isCustomTheme(_ theme: String) -> Bool {
        return availableThemes[theme]?.isCustom ?? false
    }
    
    func isFreeTheme(_ theme: String) -> Bool {
        return availableThemes[theme]?.isFree ?? false
    }
}

struct Theme {
    let name: String
    let colors: ThemeColors
    let isCustom: Bool
    let isFree: Bool
}

struct ThemeColors {
    let primary: Color
    let background: Color
    let secondary: Color
    let text: Color
} 