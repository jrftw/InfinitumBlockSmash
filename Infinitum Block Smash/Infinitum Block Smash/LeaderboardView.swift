import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: LeaderboardType = .score
    @State private var selectedPeriod: String = "daily"
    @State private var leaderboardData: [FirebaseManager.LeaderboardEntry] = []
    @State private var totalUsers: Int = 0
    @State private var userPosition: Int?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var searchText = ""
    @State private var lastUpdated: Date?
    @State private var isOffline = false
    
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
    }
    
    private var typeSelector: some View {
        Picker("Leaderboard Type", selection: $selectedType) {
            Text("High Scores").tag(LeaderboardType.score)
            Text("Achievements").tag(LeaderboardType.achievement)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var periodSelector: some View {
        HStack {
            ForEach(periods, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                    Task {
                        await loadLeaderboardData()
                    }
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
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredLeaderboardData) { entry in
                    LeaderboardRow(
                        entry: entry,
                        position: leaderboardData.firstIndex(where: { $0.id == entry.id }) ?? 0,
                        isCurrentUser: entry.id == FirebaseManager.shared.currentUserId,
                        type: selectedType
                    )
                }
            }
            .padding(.horizontal)
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
                print("[LeaderboardView] User position in leaderboard: \(userPosition ?? -1)")
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
}

struct LeaderboardRow: View {
    let entry: FirebaseManager.LeaderboardEntry
    let position: Int
    let isCurrentUser: Bool
    let type: LeaderboardType
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Position
                Text("#\(position + 1)")
                    .font(.headline)
                    .foregroundColor(positionColor)
                    .frame(width: 40)
                
                // Username
                Text(entry.username)
                    .font(.body)
                    .foregroundColor(isCurrentUser ? .blue : .primary)
                
                Spacer()
                
                // Score/Time
                if type == .timed, let time = entry.time {
                    Text(formatTime(time))
                        .font(.body)
                        .foregroundColor(.green)
                } else {
                    Text("\(entry.score)")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                // Level (if available)
                if let level = entry.level {
                    Text("Lvl \(level)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isCurrentUser ? Color.blue.opacity(0.1) : Color.clear)
            
            // Divider line
            Divider()
                .padding(.horizontal, 12)
        }
    }
    
    private var positionColor: Color {
        switch position {
        case 0:
            return .yellow // Gold
        case 1:
            return .red // Red for second place
        case 2:
            return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default:
            return .gray
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
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

#Preview {
    LeaderboardView()
}
