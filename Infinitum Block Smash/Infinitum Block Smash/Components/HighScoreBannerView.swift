/******************************************************
 * FILE: HighScoreBannerView.swift
 * MARK: High Score Achievement Notification Banner
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Displays animated notification banners for new high score achievements,
 * providing user feedback and encouraging engagement with leaderboard features.
 *
 * KEY RESPONSIBILITIES:
 * - Display high score achievement notifications
 * - Show user-friendly score announcements
 * - Provide dismissible banner interface
 * - Animate banner appearance and disappearance
 * - Display leaderboard incentive information
 * - Handle notification data presentation
 *
 * MAJOR DEPENDENCIES:
 * - NotificationService.swift: High score notification data
 * - SwiftUI: Core UI framework for banner display
 * - Animation system: Smooth banner transitions
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as a notification display component that provides
 * immediate feedback for high score achievements.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Banner must animate in from top of screen
 * - Dismissal must be smooth and user-friendly
 * - Content must be readable and accessible
 * - Animation timing must be appropriate for user attention
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify banner animation smoothness and timing
 * - Check accessibility compliance for notification content
 * - Test banner dismissal functionality
 * - Validate notification data display accuracy
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add sound effects for high score notifications
 * - Implement banner queuing for multiple notifications
 * - Add haptic feedback for banner interactions
 ******************************************************/

import SwiftUI

struct HighScoreBannerView: View {
    let notification: NotificationService.HighScoreNotification
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("🏆 New All-Time High Score! 🏆")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(notification.username) just scored \(notification.score) points!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 5)
            )
            .padding(.horizontal)
            
            Text("Top 3 players get ad-free experience!")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 4)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
} 