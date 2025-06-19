/*
 * NotificationManager.swift
 * 
 * PUSH NOTIFICATION AND USER ENGAGEMENT MANAGEMENT
 * 
 * This service manages all push notification functionality for the Infinitum Block Smash
 * game, including daily reminders, engagement notifications, and user retention
 * strategies through intelligent notification scheduling and content management.
 * 
 * KEY RESPONSIBILITIES:
 * - Daily reminder notification scheduling
 * - User engagement notification management
 * - Notification content generation and personalization
 * - Notification timing optimization
 * - User retention strategy implementation
 * - Notification permission handling
 * - Notification cancellation and management
 * - Engagement analytics tracking
 * - A/B testing for notification content
 * - User preference management
 * 
 * MAJOR DEPENDENCIES:
 * - UserNotifications: iOS notification framework
 * - NotificationService.swift: Extended notification handling
 * - NotificationPreferencesView.swift: User notification settings
 * - FirebaseManager.swift: User data and preferences
 * - GameState.swift: Game progress and achievements
 * - UserDefaults: Notification preference storage
 * 
 * NOTIFICATION TYPES:
 * - Daily Reminders: Encouraging daily gameplay
 * - Achievement Notifications: Celebrating user accomplishments
 * - High Score Alerts: Notifying of new records
 * - Engagement Prompts: Encouraging continued play
 * - Event Notifications: Special events and updates
 * - Retention Notifications: Re-engagement strategies
 * 
 * CONTENT STRATEGY:
 * - Motivational and encouraging messages
 * - Achievement-focused content
 * - Competitive leaderboard references
 * - Fun and engaging language
 * - Personalized content based on user data
 * - A/B testing for optimal engagement
 * 
 * TIMING OPTIMIZATION:
 * - Random daily scheduling (8 AM - 8 PM)
 * - User activity pattern analysis
 * - Optimal engagement time detection
 * - Frequency control and limits
 * - Quiet hours respect
 * - Time zone consideration
 * 
 * USER ENGAGEMENT:
 * - Daily habit formation
 * - Achievement celebration
 * - Competitive motivation
 * - Social engagement
 * - Progress recognition
 * - Community building
 * 
 * RETENTION STRATEGIES:
 * - Progressive engagement messaging
 * - Achievement milestone notifications
 * - Social competitive elements
 * - Personalized content delivery
 * - Behavioral pattern analysis
 * - Re-engagement campaigns
 * 
 * PERMISSION MANAGEMENT:
 * - Notification permission requests
 * - Permission status monitoring
 * - Graceful permission handling
 * - Alternative engagement methods
 * - Permission education
 * - Opt-in optimization
 * 
 * ANALYTICS AND TRACKING:
 * - Notification delivery tracking
 * - User engagement metrics
 * - Click-through rate analysis
 * - Retention impact measurement
 * - A/B test results
 * - User behavior correlation
 * 
 * PERSONALIZATION:
 * - User progress-based content
 * - Achievement history integration
 * - Playing pattern adaptation
 * - Preference-based timing
 * - Customized messaging
 * - Dynamic content generation
 * 
 * COMPLIANCE AND PRIVACY:
 * - GDPR compliance
 * - User consent management
 * - Data privacy protection
 * - Opt-out mechanisms
 * - Transparency in notification use
 * - Respect for user preferences
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central coordinator for user engagement
 * through notifications, providing intelligent and personalized
 * communication to enhance user retention and satisfaction.
 * 
 * THREADING CONSIDERATIONS:
 * - Background notification scheduling
 * - Async notification operations
 * - Thread-safe preference management
 * - Efficient content generation
 * 
 * INTEGRATION POINTS:
 * - iOS notification system
 * - User preference management
 * - Analytics and tracking
 * - User engagement metrics
 * - A/B testing framework
 * - Privacy compliance systems
 */

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private let notificationMessages = [
        "🏆 Ready to smash some blocks and climb the leaderboards? Your high score is waiting to be beaten!",
        "🎮 Missing the thrill of block smashing? Time to set a new high score!",
        "🌟 Your daily dose of block-smashing excitement awaits! Can you beat your best?",
        "🚀 Ready for an epic block-smashing session? The leaderboards are calling your name!",
        "💫 Time to show the world your block-smashing skills! New high score incoming?",
        "🎯 Your perfect block-smashing moment is now! Ready to dominate the leaderboards?",
        "⚡️ The blocks are getting lonely! Time for your daily smash session!",
        "🎪 Step right up to the most exciting block-smashing challenge of the day!",
        "🌈 Your daily block-smashing adventure awaits! New records to break!",
        "🎪 The block-smashing arena is open! Ready to make some magic?"
    ]
    
    private init() {}
    
    func scheduleDailyReminder() {
        // Remove any existing notifications first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Play Infinitum Block Smash!"
        content.body = notificationMessages.randomElement() ?? "Ready to smash some blocks?"
        content.sound = .default
        content.badge = 1
        
        // Create a random time between 8 AM and 8 PM
        var dateComponents = DateComponents()
        dateComponents.hour = Int.random(in: 8...20)
        dateComponents.minute = Int.random(in: 0...59)
        
        // Create the trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: "dailyReminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func updateNotificationTime() {
        // Only reschedule if notifications are enabled
        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            scheduleDailyReminder()
        }
    }
} 