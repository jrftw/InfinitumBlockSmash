/******************************************************
 * FILE: MoreAppsView.swift
 * MARK: More Apps Display View
 * CREATED: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Displays a list of other apps by the same developer, providing users with
 * easy access to discover and download additional applications.
 *
 * KEY RESPONSIBILITIES:
 * - Display list of developer's other apps
 * - Provide app descriptions and download links
 * - Handle app store navigation
 * - Present app information in organized format
 *
 * MAJOR DEPENDENCIES:
 * - SwiftUI: Core UI framework for view rendering
 * - UIKit: App store URL handling via UIApplication
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Main UI framework for view structure
 * - UIKit: App store navigation functionality
 *
 * ARCHITECTURE ROLE:
 * Simple presentation layer that showcases other apps by the developer
 * and provides direct links to the App Store for easy discovery.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - App links are hardcoded and require manual updates
 * - URL validation ensures safe app store navigation
 */

/******************************************************
 * REVIEW NOTES:
 * - App links need manual maintenance for new releases
 * - Consider implementing remote configuration for app list
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add app icons and screenshots
 * - Implement app rating display
 * - Add app category filtering
 * - Remote configuration for app list management
 ******************************************************/

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