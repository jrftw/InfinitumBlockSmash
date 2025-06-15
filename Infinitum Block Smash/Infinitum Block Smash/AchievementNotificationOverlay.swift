import SwiftUI

struct AchievementNotificationOverlay: View {
    @Binding var showing: Bool
    @Binding var achievement: Achievement?
    
    var body: some View {
        ZStack(alignment: .top) {
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
                .padding(.horizontal)
                .background(Color.black.opacity(0.8))
                .cornerRadius(10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showing)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Achievement unlocked: \(achievement.name). \(achievement.description)")
            }
        }
    }
} 
