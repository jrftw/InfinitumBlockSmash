/******************************************************
 * FILE: ChangelogView.swift
 * MARK: App Changelog Display View
 * CREATED: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Displays the app's changelog history, showing users what changes and improvements
 * have been made in each version of the application.
 *
 * KEY RESPONSIBILITIES:
 * - Display version history in reverse chronological order
 * - Show detailed changelog entries for each version
 * - Organize changes by version in collapsible sections
 * - Provide clear navigation and readability
 *
 * MAJOR DEPENDENCIES:
 * - AppVersion.swift: Provides changelog data and version information
 * - SwiftUI: Core UI framework for view rendering
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Main UI framework for view structure and list rendering
 *
 * ARCHITECTURE ROLE:
 * Simple presentation layer that displays static changelog data
 * from the AppVersion model in an organized list format.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Versions are sorted in descending order (newest first)
 * - Changelog data is sourced from AppVersion.changelog dictionary
 * - Each version is displayed in its own section
 */

/******************************************************
 * REVIEW NOTES:
 * - Changelog data is hardcoded in AppVersion.swift
 * - Consider implementing remote changelog management
 * - Version sorting ensures newest changes appear first
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add changelog search functionality
 * - Implement changelog filtering by version type
 * - Add changelog bookmarking for important changes
 * - Remote configuration for changelog content
 ******************************************************/

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        List {
            ForEach(Array(AppVersion.changelog.keys.sorted(by: >)), id: \.self) { version in
                Section(header: Text("Version \(version)")) {
                    ForEach(AppVersion.changelog[version] ?? [], id: \.self) { change in
                        Text(change)
                            .font(.body)
                    }
                }
            }
        }
        .navigationTitle("Changelog")
    }
} 