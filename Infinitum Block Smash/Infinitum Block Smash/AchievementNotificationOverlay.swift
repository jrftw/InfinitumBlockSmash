import SwiftUI

struct AchievementNotificationOverlay: View {
    @Binding var showing: Bool
    @Binding var achievement: Achievement?
    
    var body: some View {
        if let achievement = achievement {
            VStack {
                Text("Achievement Unlocked!")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(achievement.name)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.yellow)
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
} 