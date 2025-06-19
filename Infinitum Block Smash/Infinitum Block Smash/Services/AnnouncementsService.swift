/*
 * AnnouncementsService.swift
 * 
 * MAIN PURPOSE:
 * Manages in-app announcements and notifications fetched from a remote JSON source.
 * Provides a centralized service for displaying important updates, news, and announcements
 * to users within the Infinitum Block Smash game.
 * 
 * KEY FUNCTIONALITY:
 * - Fetches announcements from remote GitHub JSON endpoint
 * - Sorts announcements by priority and date
 * - Provides real-time announcement updates
 * - Supports announcement links and content
 * - Handles loading states and error conditions
 * - Uses @MainActor for UI thread safety
 * 
 * DEPENDENCIES:
 * - Foundation: Core framework for networking and data structures
 * - URLSession: HTTP networking for fetching announcements
 * - JSONDecoder: JSON parsing for announcement data
 * - SwiftUI: ObservableObject for reactive UI updates
 * 
 * FILES THAT USE THIS:
 * - AnnouncementsView.swift: Primary UI for displaying announcements
 * - ContentView.swift: May integrate announcements into main app flow
 * - GameView.swift: Could show critical announcements during gameplay
 * 
 * FILES THIS USES EXTENSIVELY:
 * - URLSession: For HTTP requests to GitHub JSON endpoint
 * - Foundation framework: For data structures and networking
 * 
 * DATA FLOW:
 * 1. Service fetches announcements from GitHub JSON endpoint
 * 2. JSON data is decoded into Announcement structs
 * 3. Announcements are sorted by priority and date
 * 4. UI components observe and display announcements
 * 5. Users can interact with announcements and links
 * 
 * REVIEW NOTES:
 * 
 * POTENTIAL ISSUES:
 * - Hard-coded GitHub URL could become unavailable or change
 * - No caching mechanism - fetches fresh data every time
 * - No offline fallback for announcement data
 * - No validation of announcement content or links
 * - No rate limiting for announcement fetching
 * - No error retry mechanism for network failures
 * - Priority system may not handle edge cases properly
 * 
 * AREAS FOR IMPROVEMENT:
 * - Add local caching for offline access
 * - Implement announcement expiration dates
 * - Add announcement categories and filtering
 * - Implement push notifications for critical announcements
 * - Add announcement analytics and tracking
 * - Consider using Firebase for announcement management
 * - Add announcement scheduling and time-based display
 * 
 * DEPENDENCY CONCERNS:
 * - Direct dependency on external GitHub repository
 * - No fallback announcement source
 * - Network dependency for all announcement data
 * - No announcement validation or sanitization
 * 
 * DATE: 6/19/2025
 * AUTHOR: @jrftw
 */

import Foundation

struct Announcement: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let content: String
    let date: String
    let priority: Int
    let link: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case date
        case priority
        case link
    }
}

@MainActor
class AnnouncementsService: ObservableObject {
    @Published var announcements: [Announcement] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let announcementsURL = "https://raw.githubusercontent.com/jrftw/blocksmashannouncements/main/announcements.json"
    
    func fetchAnnouncements() async {
        isLoading = true
        error = nil
        
        do {
            guard let url = URL(string: announcementsURL) else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let announcements = try decoder.decode([Announcement].self, from: data)
            
            // Sort by priority first (higher numbers first), then by date (newest first)
            self.announcements = announcements.sorted { a1, a2 in
                if a1.priority != a2.priority {
                    return a1.priority > a2.priority
                }
                return a1.date > a2.date
            }
            self.isLoading = false
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
} 