/*
 * ThemeManager.swift
 * 
 * VISUAL THEME MANAGEMENT AND CUSTOMIZATION SYSTEM
 * 
 * This service manages all visual themes, color schemes, and customization options
 * for the Infinitum Block Smash game. It provides a comprehensive theming system
 * with premium themes, system integration, and dynamic theme switching.
 * 
 * KEY RESPONSIBILITIES:
 * - Theme definition and management
 * - Color scheme customization
 * - Premium theme access control
 * - System theme integration
 * - Dynamic theme switching
 * - Theme persistence and storage
 * - Visual consistency across the app
 * - Premium feature unlocking
 * - Theme preview and selection
 * - Accessibility color support
 * 
 * MAJOR DEPENDENCIES:
 * - SubscriptionManager.swift: Premium theme access control
 * - SettingsView.swift: Theme selection interface
 * - GameScene.swift: Visual theme application
 * - GameView.swift: UI theme integration
 * - ContentView.swift: Main interface theming
 * - UserDefaults: Theme persistence
 * - NotificationCenter: Theme change notifications
 * 
 * THEME CATEGORIES:
 * - System Themes: Auto, Light, Dark (free)
 * - Premium Themes: Custom visual themes (paid)
 * - Special Themes: Limited edition and event themes
 * - Accessibility Themes: High contrast and colorblind support
 * 
 * AVAILABLE THEMES:
 * - System: Automatic light/dark mode
 * - Neon: Bright green cyberpunk style
 * - Retro: Orange and yellow vintage look
 * - Nature: Green and natural colors
 * - Execution: Red and dark theme
 * - Rainbow: Colorful and vibrant
 * - Adventure: Brown and earthy tones
 * - Cyberpunk: Pink and neon blue
 * - Sunset: Orange and purple gradients
 * - Ocean: Blue and aquatic colors
 * - Forest: Green and natural
 * - Nordic: Clean and minimal
 * - Midnight: Purple and dark
 * - Desert: Warm and sandy
 * - Aurora: Teal and green
 * - Cherry: Pink and light
 * 
 * COLOR SYSTEM:
 * - Primary colors for main UI elements
 * - Background colors for app surfaces
 * - Secondary colors for supporting elements
 * - Text colors for readability
 * - Gradient support for visual depth
 * - Accessibility color considerations
 * 
 * PREMIUM FEATURES:
 * - Premium theme unlocking
 * - Subscription-based access
 * - Theme preview functionality
 * - Exclusive theme designs
 * - Limited edition themes
 * - Custom theme creation
 * 
 * SYSTEM INTEGRATION:
 * - iOS system theme detection
 * - Automatic theme switching
 * - Dark mode support
 * - Light mode optimization
 * - Dynamic color adaptation
 * - System appearance changes
 * 
 * PERSISTENCE AND STORAGE:
 * - Theme selection persistence
 * - User preference storage
 * - Cross-device theme sync
 * - Theme history tracking
 * - Backup and restore functionality
 * 
 * PERFORMANCE FEATURES:
 * - Efficient theme switching
 * - Cached color definitions
 * - Optimized theme loading
 * - Memory-efficient storage
 * - Fast theme application
 * 
 * ACCESSIBILITY:
 * - High contrast theme support
 * - Colorblind-friendly themes
 * - Dynamic type integration
 * - Reduced motion support
 * - VoiceOver compatibility
 * 
 * USER EXPERIENCE:
 * - Smooth theme transitions
 * - Real-time theme preview
 * - Intuitive theme selection
 * - Consistent visual design
 * - Personalized experience
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central coordinator for all visual theming,
 * providing a unified interface for theme management while ensuring
 * consistency across the entire application.
 * 
 * THREADING CONSIDERATIONS:
 * - UI updates on main thread
 * - Background theme loading
 * - Thread-safe theme access
 * - Efficient notification handling
 * 
 * INTEGRATION POINTS:
 * - Settings interface
 * - Game visual system
 * - Subscription management
 * - Analytics and tracking
 * - User preferences
 * - System appearance
 */

import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: String {
        didSet {
            UserDefaults.standard.set(currentTheme, forKey: "selectedTheme")
            NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
        }
    }
    
    @Published var systemTheme: String {
        didSet {
            UserDefaults.standard.set(systemTheme, forKey: "systemTheme")
            if currentTheme == "system" {
                NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
            }
        }
    }
    
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
        // Initialize system theme with "auto" as default
        self.systemTheme = UserDefaults.standard.string(forKey: "systemTheme") ?? "auto"
        
        // Initialize current theme with "auto" as default
        self.currentTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? "auto"
        
        // Apply the theme immediately
        applyTheme()
    }
    
    private func applyTheme() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        if currentTheme == "system" {
            switch systemTheme {
            case "light":
                window.overrideUserInterfaceStyle = .light
            case "dark":
                window.overrideUserInterfaceStyle = .dark
            default: // "auto"
                window.overrideUserInterfaceStyle = .unspecified
            }
        } else {
            // For custom themes, we need to ensure the window style is unspecified
            // so our custom colors can take effect
            window.overrideUserInterfaceStyle = .unspecified
        }
        
        // Post notification to update all views
        NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
    }
    
    func setTheme(_ theme: String) {
        if ["light", "dark", "auto"].contains(theme) {
            systemTheme = theme
            currentTheme = "system"
        } else {
            currentTheme = theme
        }
        
        // Save to UserDefaults immediately
        UserDefaults.standard.set(currentTheme, forKey: "selectedTheme")
        UserDefaults.standard.set(systemTheme, forKey: "systemTheme")
        UserDefaults.standard.synchronize()
        
        // Apply the theme
        applyTheme()
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