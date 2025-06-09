import SwiftUI
import FirebaseFirestore

struct AchievementLeaderboardView: View {
    @State private var selectedPeriod = "daily"
    @State private var leaderboardData: [FirebaseManager.LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var userPosition: Int?
    @State private var lastUpdated: Date?
    @State private var totalUsers: Int = 0
    @State private var isOffline = false
    
    private let periods = ["daily", "weekly", "monthly", "alltime"]
    
    private var filteredData: [FirebaseManager.LeaderboardEntry] {
        if searchText.isEmpty {
            return leaderboardData
        }
        return leaderboardData.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            periodSelector
            
            SearchBar(text: $searchText)
                .padding(.horizontal)
            
            statsSection
            
            if isOffline {
                offlineBanner
            }
            
            leaderboardContent
        }
        .onAppear {
            loadLeaderboardData()
        }
    }
    
    private var periodSelector: some View {
        HStack {
            ForEach(periods, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                    loadLeaderboardData()
                }) {
                    Text(period.capitalized)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedPeriod == period ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var statsSection: some View {
        HStack {
            if let lastUpdated = lastUpdated {
                Text("Last updated: \(lastUpdated, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("Total users: \(totalUsers)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
    
    private var offlineBanner: some View {
        Text("Offline Mode - Showing cached data")
            .font(.caption)
            .foregroundColor(.orange)
            .padding(.horizontal)
    }
    
    private var leaderboardContent: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                errorView(error)
            } else {
                leaderboardList
            }
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack {
            Text("Error loading leaderboard")
                .font(.headline)
                .foregroundColor(.red)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredData) { entry in
                    LeaderboardRow(
                        entry: entry,
                        position: leaderboardData.firstIndex(where: { $0.id == entry.id }) ?? 0,
                        isCurrentUser: entry.id == FirebaseManager.shared.currentUserId,
                        type: .achievement
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func loadLeaderboardData() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let entries = try await FirebaseManager.shared.getLeaderboardEntries(
                    type: .achievement,
                    period: selectedPeriod
                )
                
                // Update user position
                if let userId = FirebaseManager.shared.currentUserId {
                    userPosition = entries.firstIndex(where: { $0.id == userId })
                }
                
                // Cache the data for offline access
                if let encodedData = try? JSONEncoder().encode(entries) {
                    UserDefaults.standard.set(encodedData, forKey: "cached_leaderboard_achievement_\(selectedPeriod)")
                }
                
                leaderboardData = entries
                totalUsers = entries.count
                lastUpdated = Date()
                isOffline = false
            } catch {
                // Try to load cached data
                if let cachedData = UserDefaults.standard.data(forKey: "cached_leaderboard_achievement_\(selectedPeriod)"),
                   let entries = try? JSONDecoder().decode([FirebaseManager.LeaderboardEntry].self, from: cachedData) {
                    leaderboardData = entries
                    totalUsers = entries.count
                    isOffline = true
                } else {
                    self.error = error.localizedDescription
                }
            }
            
            isLoading = false
        }
    }
}

