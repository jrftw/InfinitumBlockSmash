import Foundation
import UserNotifications
import SwiftUI
import FirebaseFirestore

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    private let db = Firestore.firestore()
    
    @Published var currentHighScoreNotification: HighScoreNotification?
    @Published var showHighScoreBanner = false
    
    struct HighScoreNotification: Identifiable {
        let id = UUID()
        let username: String
        let score: Int
        let timestamp: Date
    }
    
    private init() {
        setupNotificationListener()
    }
    
    private func setupNotificationListener() {
        // Listen for new high scores in the all-time leaderboard
        db.collection("classic_leaderboard")
            .document("alltime")
            .collection("scores")
            .order(by: "score", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents,
                      let topScore = documents.first,
                      let username = topScore.data()["username"] as? String,
                      let score = topScore.data()["score"] as? Int,
                      let timestamp = (topScore.data()["timestamp"] as? Timestamp)?.dateValue() else {
                    return
                }
                
                // Create notification
                let notification = HighScoreNotification(
                    username: username,
                    score: score,
                    timestamp: timestamp
                )
                
                // Show banner for users currently playing
                DispatchQueue.main.async {
                    self.currentHighScoreNotification = notification
                    self.showHighScoreBanner = true
                    
                    // Hide banner after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.showHighScoreBanner = false
                    }
                }
                
                // Send push notification to users not currently playing
                self.sendPushNotification(for: notification)
            }
    }
    
    private func sendPushNotification(for notification: HighScoreNotification) {
        let content = UNMutableNotificationContent()
        content.title = "🏆 New All-Time High Score! 🏆"
        content.body = "\(notification.username) just scored \(notification.score) points! Can you beat them?"
        content.sound = .default
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "type": "high_score",
            "username": notification.username,
            "score": notification.score
        ]
        
        // Create trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "high-score-\(notification.id)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[NotificationService] Notification permission granted")
            } else if let error = error {
                print("[NotificationService] Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
} 