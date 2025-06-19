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