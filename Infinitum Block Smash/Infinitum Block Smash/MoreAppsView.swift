import SwiftUI

struct MoreAppsView: View {
    var body: some View {
        List {
            Section {
                AppLinkRow(
                    title: "Phone Guardian - Protect",
                    description: "Manage your phone's performance effortlessly with Phone Guardian – Protect. Access in-depth device stats, monitor usage + more for your smartphone—all in one single app!",
                    url: "https://apps.apple.com/us/app/phone-guardian-protect/id6738286864"
                )
                
                AppLinkRow(
                    title: "Blitz Rose - 31 Card Game",
                    description: "Race to 31 in Blitz Rose! Build the best hand, challenge friends or AI, and outsmart opponents in this fast-paced card game. Quick, strategic, and endlessly fun!",
                    url: "https://apps.apple.com/us/app/blitz-rose-31-card-game/id6736508556"
                )
                
                AppLinkRow(
                    title: "InfiniView - TikTok LIVE Creator Dashboard",
                    description: "Your TikTok LIVE, Favorited & Bigo Creator Dashboard, Anytime, Anywhere! View your stats, manage campaigns, and stay connected with your community.",
                    url: "https://apps.apple.com/us/app/infiniview/id6739147518"
                )
            }
        }
        .navigationTitle("More Apps By Us")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppLinkRow: View {
    let title: String
    let description: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(.vertical, 4)
        }
    }
} 