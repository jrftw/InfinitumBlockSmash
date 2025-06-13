import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import GameKit

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: LeaderboardType = .score
    @State private var selectedPeriod: String = "alltime"
    @State private var leaderboardData: [FirebaseManager.LeaderboardEntry] = []
    @State private var totalUsers: Int = 0
    @State private var userPosition: Int?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var searchText = ""
    @State private var lastUpdated: Date?
    @State private var isOffline = false
    @State private var entries: [GKLeaderboard.Entry] = []
    @State private var currentPage = 1
    @State private var hasMorePages = true
    private let pageSize = 20
    
    private let periods = ["daily", "weekly", "monthly", "alltime"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                typeSelector
                periodSelector
                
                if shouldShowEliteBanner {
                    ElitePlayerBanner(entries: Array(leaderboardData.prefix(3)))
                }
                
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                statsSection
                
                if isOffline {
                    offlineBanner
                }
                
                leaderboardContent
            }
            .navigationTitle(selectedType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        GameCenterManager.shared.presentGameCenterUI()
                    }) {
                        Image(systemName: "gamecontroller.fill")
                    }
                }
            }
        }
        .modifier(SheetPresentationModifier())
        .onAppear {
            Task {
                await loadLeaderboardData()
            }
        }
        .onChange(of: selectedType) { _ in
            Task {
                await loadLeaderboardData()
            }
        }
        .onChange(of: selectedPeriod) { _ in
            resetAndLoad()
        }
    }
    
    private var typeSelector: some View {
        Picker("Leaderboard Type", selection: $selectedType) {
            Text("High Scores").tag(LeaderboardType.score)
            Text("Achievements").tag(LeaderboardType.achievement)
            Text("Timed").tag(LeaderboardType.timed)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var periodSelector: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            Text("Daily").tag("daily")
            Text("Weekly").tag("weekly")
            Text("Monthly").tag("monthly")
            Text("All Time").tag("alltime")
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var shouldShowEliteBanner: Bool {
        selectedType == .score && selectedPeriod == "alltime" && leaderboardData.count >= 3
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
    
    private func errorView(_ error: Error) -> some View {
        VStack {
            Text("Error loading leaderboard")
                .font(.headline)
                .foregroundColor(.red)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private var leaderboardList: some View {
        List {
            ForEach(Array(displayedLeaderboardData.enumerated()), id: \.element.id) { index, entry in
                FirebaseLeaderboardRow(entry: entry, rank: index + 1)
            }
        }
    }
    
    private var displayedLeaderboardData: [FirebaseManager.LeaderboardEntry] {
        if searchText.isEmpty {
            return Array(filteredLeaderboardData.prefix(10))
        } else {
            return filteredLeaderboardData
        }
    }
    
    private var filteredLeaderboardData: [FirebaseManager.LeaderboardEntry] {
        if searchText.isEmpty {
            return leaderboardData
        }
        return leaderboardData.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func loadLeaderboardData() async {
        print("[LeaderboardView] Starting to load leaderboard data")
        print("[LeaderboardView] Selected type: \(selectedType), period: \(selectedPeriod)")
        
        isLoading = true
        error = nil
        
        // Check authentication state first
        guard let currentUser = Auth.auth().currentUser else {
            print("[LeaderboardView] ❌ User not authenticated")
            error = LeaderboardError.notAuthenticated
            isLoading = false
            return
        }
        print("[LeaderboardView] ✅ User authenticated: \(currentUser.uid)")
        
        do {
            print("[LeaderboardView] Fetching leaderboard data from service")
            let (entries, total) = try await LeaderboardService.shared.getLeaderboard(
                type: selectedType,
                period: selectedPeriod
            )
            
            print("[LeaderboardView] Received \(entries.count) entries, total users: \(total)")
            
            // Update user position
            if let userId = FirebaseManager.shared.currentUserId {
                userPosition = entries.firstIndex(where: { $0.id == userId })
                if let position = userPosition {
                    print("[LeaderboardView] User position in leaderboard: \(position)")
                } else {
                    print("[LeaderboardView] User not found in leaderboard")
                }
            }
            
            // Log some sample entries for debugging
            if !entries.isEmpty {
                print("[LeaderboardView] Sample entries:")
                for (index, entry) in entries.prefix(3).enumerated() {
                    print("[LeaderboardView] Entry \(index + 1):")
                    print("  - Username: \(entry.username)")
                    print("  - Score: \(entry.score)")
                    print("  - Timestamp: \(entry.timestamp)")
                }
            }
            
            leaderboardData = entries
            totalUsers = total
            lastUpdated = Date()
            isOffline = false
            print("[LeaderboardView] ✅ Successfully loaded leaderboard data")
        } catch {
            print("[LeaderboardView] ❌ Error loading leaderboard: \(error.localizedDescription)")
            // Only try to load cached data if we have a valid authentication state
            if Auth.auth().currentUser != nil,
               let cachedData = LeaderboardCache.shared.getCachedLeaderboard(type: selectedType, period: selectedPeriod) {
                print("[LeaderboardView] Using cached data after error")
                print("[LeaderboardView] Cached entries count: \(cachedData.count)")
                leaderboardData = cachedData
                totalUsers = cachedData.count
                isOffline = true
            } else {
                print("[LeaderboardView] ❌ No cached data available")
                self.error = error
            }
        }
        
        isLoading = false
        print("[LeaderboardView] Completed leaderboard data loading")
    }
    
    private func resetAndLoad() {
        currentPage = 1
        hasMorePages = true
        Task {
            await loadLeaderboardData()
        }
    }
    
    private func loadMoreEntries() {
        guard !isLoading else { return }
        Task {
            await loadLeaderboardData()
        }
    }
}

struct FirebaseLeaderboardRow: View {
    let entry: FirebaseManager.LeaderboardEntry
    let rank: Int

    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(rank <= 3 ? 0.2 : 0))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(rankColor)
            }
            .frame(width: 40)

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
        .padding(.vertical, 6)
        .background(
            Group {
                if rank <= 3 {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rankColor.opacity(0.08))
                } else {
                    Color.clear
                }
            }
        )
    }
}

extension GKPlayer {
    var gameKitImage: UIImage? {
        // This is a placeholder. In a real app, you would need to implement
        // proper photo loading from Game Center
        return nil
    }
}

struct ElitePlayerBanner: View {
    let entries: [FirebaseManager.LeaderboardEntry]
    @State private var showingAdFreeInfo = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("Elite Players")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("Ad Free")
                    .font(.subheadline)
                    .foregroundColor(.green)
                Button(action: {
                    showingAdFreeInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 16) {
                ForEach(entries) { entry in
                    VStack {
                        Text(entry.username)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Text("\(entry.score)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .alert("Ad Free Status", isPresented: $showingAdFreeInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Players in the top 3 of the All Time High Scores leaderboard receive unlimited ad-free time until they are knocked off the leaderboard.")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search users...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct SheetPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
