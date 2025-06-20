/******************************************************
 * FILE: AnnouncementsView.swift
 * MARK: Announcements and Bugs Display View
 * CREATED: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Displays app announcements and known bugs to users, providing a centralized
 * location for important updates and issue notifications.
 *
 * KEY RESPONSIBILITIES:
 * - Display app announcements from remote service
 * - Show known bugs and issues
 * - Handle tab switching between announcements and bugs
 * - Provide error handling and loading states
 * - Manage announcement data fetching
 *
 * MAJOR DEPENDENCIES:
 * - AnnouncementsService.swift: Fetches announcement data from Firebase
 * - BugsView.swift: Displays known bugs in separate tab
 * - SwiftUI: Core UI framework for view rendering
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Main UI framework for view structure and navigation
 * - Foundation: Core framework for data handling
 *
 * ARCHITECTURE ROLE:
 * Presentation layer that combines announcements and bugs display
 * with tab-based navigation and error handling.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Announcements are fetched on view appearance
 * - Tab switching preserves state between announcements and bugs
 * - Error states provide retry functionality
 */

/******************************************************
 * REVIEW NOTES:
 * - Announcement data is fetched from remote service
 * - Error handling provides user-friendly feedback
 * - Tab navigation improves user experience
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add announcement categories and filtering
 * - Implement push notifications for new announcements
 * - Add announcement search functionality
 * - Implement announcement read/unread tracking
 ******************************************************/

import SwiftUI

struct AnnouncementsView: View {
    @StateObject private var announcementsService = AnnouncementsService()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.2, blue: 0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Section", selection: $selectedTab) {
                        Text("Announcements").tag(0)
                        Text("Bugs").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if selectedTab == 0 {
                        announcementsContent
                    } else {
                        BugsView()
                    }
                }
            }
            .navigationTitle(selectedTab == 0 ? "Announcements" : "Known Bugs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await announcementsService.fetchAnnouncements()
        }
    }
    
    private var announcementsContent: some View {
        Group {
            if announcementsService.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else if let error = announcementsService.error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("Failed to load announcements")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        Task {
                            await announcementsService.fetchAnnouncements()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            } else if announcementsService.announcements.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("No Announcements")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Check back later for updates!")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(announcementsService.announcements) { announcement in
                            AnnouncementCard(announcement: announcement)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct AnnouncementCard: View {
    let announcement: Announcement
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(announcement.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(announcement.date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(announcement.content)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            if let link = announcement.link {
                Link(destination: URL(string: link)!) {
                    HStack {
                        Text("Learn More")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
} 