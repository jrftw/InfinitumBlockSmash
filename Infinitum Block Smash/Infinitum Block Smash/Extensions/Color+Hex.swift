/******************************************************
 * FILE: Color+Hex.swift
 * MARK: SwiftUI Color Hex Support Extension
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides hex color support for SwiftUI Color, enabling easy color
 * definition using hexadecimal values with comprehensive format support.
 *
 * KEY RESPONSIBILITIES:
 * - Initialize SwiftUI Color from hex string values
 * - Support RGB, ARGB, and 12-bit color formats
 * - Handle hex string parsing and validation
 * - Provide sRGB color space initialization
 * - Support opacity/alpha channel handling
 *
 * MAJOR DEPENDENCIES:
 * - SwiftUI: Core framework for Color
 * - Foundation: String parsing and validation
 * - Scanner: Hex string parsing utilities
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern UI framework for colors
 * - Foundation: Core framework for string operations
 *
 * ARCHITECTURE ROLE:
 * Acts as a color utility layer that provides convenient
 * hex color support for SwiftUI interfaces.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Hex string parsing must be robust and error-safe
 * - Color format support must be comprehensive
 * - sRGB color space must be properly initialized
 * - Performance must be optimized for frequent use
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify hex string parsing handles all formats correctly
 * - Test color initialization accuracy
 * - Check sRGB color space handling
 * - Validate error handling for invalid hex strings
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add more color format support
 * - Implement color validation utilities
 * - Add color manipulation methods
 ******************************************************/

import SwiftUI

extension Color {
    init(hex: String) {
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
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 