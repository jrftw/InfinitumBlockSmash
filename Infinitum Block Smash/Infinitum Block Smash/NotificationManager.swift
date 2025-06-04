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