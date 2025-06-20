/******************************************************
 * FILE: ScoreAnimationView.swift
 * MARK: Score Point Animation Display System
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides animated score point displays that appear when players earn points,
 * creating visual feedback and enhancing the gaming experience.
 *
 * KEY RESPONSIBILITIES:
 * - Display animated score point notifications
 * - Manage multiple simultaneous score animations
 * - Provide visual feedback for point earning
 * - Handle animation timing and cleanup
 * - Support different point value styling
 * - Coordinate animation container management
 *
 * MAJOR DEPENDENCIES:
 * - SwiftUI: Core UI framework for animation display
 * - Animation system: Smooth point animations
 * - UUID: Unique animation identification
 * - DispatchQueue: Animation cleanup timing
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as a visual feedback system that provides immediate
 * confirmation when players earn points during gameplay.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Animations must be smooth and non-intrusive
 * - Multiple animations must not interfere with each other
 * - Cleanup must occur automatically after animation completion
 * - Point values must be clearly visible and readable
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify animation smoothness and performance
 * - Check animation timing and cleanup reliability
 * - Test multiple simultaneous animations
 * - Validate point value visibility and readability
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add sound effects for point animations
 * - Implement different animation styles for different point values
 * - Add particle effects for high-value points
 ******************************************************/

import SwiftUI

struct ScoreAnimationView: View {
    let points: Int
    let position: CGPoint
    @State private var opacity: Double = 1.0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        Text("+\(points)")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(points >= 500 ? .yellow : .white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .opacity(opacity)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    offset = -50
                    opacity = 0
                }
            }
            .position(position)
    }
}

struct ScoreAnimationContainer: View {
    @State private var animations: [(id: UUID, points: Int, position: CGPoint)] = []
    
    func addAnimation(points: Int, at position: CGPoint) {
        let id = UUID()
        animations.append((id: id, points: points, position: position))
        
        // Remove animation after it completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            animations.removeAll { $0.id == id }
        }
    }
    
    var body: some View {
        ZStack {
            ForEach(animations, id: \.id) { animation in
                ScoreAnimationView(points: animation.points, position: animation.position)
            }
        }
    }
} 