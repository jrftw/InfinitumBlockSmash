/******************************************************
 * FILE: SKColor+Hex.swift
 * MARK: SKColor Hex Color Support Extension
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides hex color support for SKColor, enabling easy color
 * definition using hexadecimal values and SwiftUI Color conversion.
 *
 * KEY RESPONSIBILITIES:
 * - Initialize SKColor from hex string values
 * - Support RGB, ARGB, and 12-bit color formats
 * - Convert SwiftUI Color to SKColor
 * - Handle hex string parsing and validation
 * - Provide cross-platform color compatibility
 *
 * MAJOR DEPENDENCIES:
 * - SpriteKit: Core framework for SKColor
 * - SwiftUI: Color framework for conversion
 * - Foundation: String parsing and validation
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SpriteKit: Game development framework for colors
 * - SwiftUI: Modern UI framework for color conversion
 * - Foundation: Core framework for string operations
 *
 * ARCHITECTURE ROLE:
 * Acts as a color utility layer that bridges different
 * color systems and provides convenient hex color support.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Hex string parsing must be robust and error-safe
 * - Color format support must be comprehensive
 * - Cross-platform compatibility must be maintained
 * - Performance must be optimized for frequent use
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify hex string parsing handles all formats correctly
 * - Test color conversion accuracy
 * - Check cross-platform compatibility
 * - Validate error handling for invalid hex strings
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add more color format support
 * - Implement color validation utilities
 * - Add color manipulation methods
 ******************************************************/

import SpriteKit
import SwiftUI

extension SKColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    static func from(_ color: Color) -> SKColor {
        #if os(iOS)
        if let cgColor = color.cgColor {
            return SKColor(cgColor: cgColor)
        }
        #endif
        return SKColor.white
    }
} 