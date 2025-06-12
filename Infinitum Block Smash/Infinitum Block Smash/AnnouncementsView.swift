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