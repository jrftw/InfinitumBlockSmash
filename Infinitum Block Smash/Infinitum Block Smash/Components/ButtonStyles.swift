/******************************************************
 * FILE: ButtonStyles.swift
 * MARK: Custom Button Style Definitions
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Defines custom button styles for consistent UI design throughout the app,
 * providing reusable button styling with animations and visual effects.
 *
 * KEY RESPONSIBILITIES:
 * - Define primary button style with gradient backgrounds
 * - Define secondary button style with blur effects
 * - Define icon button style for circular buttons
 * - Provide button style extensions for easy application
 * - Handle dark/light mode color scheme adaptation
 * - Implement press animations and visual feedback
 *
 * MAJOR DEPENDENCIES:
 * - SwiftUI: Core UI framework for button styling
 * - BlurView.swift: Blur effect components for secondary buttons
 * - Color.accentColor: App's primary accent color
 * - Environment colorScheme: Dark/light mode detection
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as a UI styling layer that provides consistent button appearance
 * and behavior across the entire application.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Button styles must be applied consistently across the app
 * - Color scheme changes must be handled automatically
 * - Press animations must be smooth and responsive
 * - Accessibility considerations must be maintained
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify button style consistency across different screen sizes
 * - Check accessibility compliance for all button styles
 * - Test button animations and press feedback
 * - Validate color scheme adaptation
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add more button style variants
 * - Implement haptic feedback for button presses
 * - Add button state management for loading states
 ******************************************************/

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor,
                        Color.accentColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.2), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                BlurView(style: .systemUltraThinMaterialDark)
                    .opacity(0.8)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(.white)
            .padding(12)
            .background(
                BlurView(style: .systemUltraThinMaterialDark)
                    .opacity(0.8)
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension View {
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func iconButton() -> some View {
        self.buttonStyle(IconButtonStyle())
    }
} 