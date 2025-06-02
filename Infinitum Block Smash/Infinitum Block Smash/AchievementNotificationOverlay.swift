import SwiftUI

struct AchievementNotificationOverlay: View {
    @Binding var showing: Bool
    @Binding var achievement: Achievement?
    var body: some View {
        if showing, let achievement = achievement {
            AchievementNotification(achievement: achievement, isPresented: $showing)
                .transition(.scale.combined(with: .opacity))
        }
    }
} 