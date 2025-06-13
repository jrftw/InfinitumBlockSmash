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
                ForEach(Array(filteredData.enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        Text("\(index + 1)")
                            .font(.headline)
                            .frame(width: 40)
                        
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            Text(entry.username)
                                .font(.headline)
                            if let level = entry.level {
                                Text("Level \(level)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(entry.score)")
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func loadLeaderboardData() {
        print("[AchievementLeaderboardView] Starting to load achievement leaderboard data")
        print("[AchievementLeaderboardView] Selected period: \(selectedPeriod)")
        
        isLoading = true
        error = nil
        
        Task {
            do {
                print("[AchievementLeaderboardView] Fetching leaderboard entries from Firebase")
                let entries = try await FirebaseManager.shared.getLeaderboardEntries(
                    type: .achievement,
                    period: selectedPeriod
                )
                
                print("[AchievementLeaderboardView] Received \(entries.count) entries")
                
                // Update user position
                if let userId = FirebaseManager.shared.currentUserId {
                    userPosition = entries.firstIndex(where: { $0.id == userId })
                    print("[AchievementLeaderboardView] User position in leaderboard: \(userPosition ?? -1)")
                }
                
                // Log sample entries for debugging
                if !entries.isEmpty {
                    print("[AchievementLeaderboardView] Sample entries:")
                    for (index, entry) in entries.prefix(3).enumerated() {
                        print("[AchievementLeaderboardView] Entry \(index + 1):")
                        print("  - Username: \(entry.username)")
                        print("  - Score: \(entry.score)")
                        print("  - Timestamp: \(entry.timestamp)")
                    }
                }
                
                // Cache the data for offline access
                if let encodedData = try? JSONEncoder().encode(entries) {
                    UserDefaults.standard.set(encodedData, forKey: "cached_leaderboard_achievement_\(selectedPeriod)")
                    print("[AchievementLeaderboardView] Successfully cached \(entries.count) entries")
                }
                
                leaderboardData = entries
                totalUsers = entries.count
                lastUpdated = Date()
                isOffline = false
                print("[AchievementLeaderboardView] ✅ Successfully loaded achievement leaderboard data")
            } catch {
                print("[AchievementLeaderboardView] ❌ Error loading achievement leaderboard: \(error.localizedDescription)")
                // Try to load cached data
                if let cachedData = UserDefaults.standard.data(forKey: "cached_leaderboard_achievement_\(selectedPeriod)"),
                   let entries = try? JSONDecoder().decode([FirebaseManager.LeaderboardEntry].self, from: cachedData) {
                    print("[AchievementLeaderboardView] Using cached data with \(entries.count) entries")
                    leaderboardData = entries
                    totalUsers = entries.count
                    isOffline = true
                } else {
                    print("[AchievementLeaderboardView] ❌ No cached data available")
                    self.error = error.localizedDescription
                }
            }
            
            isLoading = false
            print("[AchievementLeaderboardView] Completed loading achievement leaderboard data")
        }
    }
}

