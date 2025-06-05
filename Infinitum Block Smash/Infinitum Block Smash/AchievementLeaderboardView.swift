import SwiftUI
import FirebaseFirestore

struct AchievementLeaderboardView: View {
    @State private var selectedPeriod = "daily"
    @State private var leaderboardData: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var userPosition: Int?
    @State private var lastUpdated: Date?
    @State private var totalUsers: Int = 0
    
    private let periods = ["daily", "weekly", "monthly", "alltime"]
    private let periodNames = ["Daily", "Weekly", "Monthly", "All Time"]
    
    private var filteredData: [LeaderboardEntry] {
        if searchText.isEmpty {
            return leaderboardData
        }
        return leaderboardData.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func getBackgroundColor(for index: Int) -> Color {
        switch index {
        case 0:
            return Color.yellow.opacity(0.3) // Gold
        case 1:
            return Color.gray.opacity(0.3) // Silver
        case 2:
            return Color.orange.opacity(0.3) // Bronze
        default:
            return Color.clear
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Period selector
            HStack {
                ForEach(0..<periods.count, id: \.self) { index in
                    Button(action: {
                        selectedPeriod = periods[index]
                        loadLeaderboardData()
                    }) {
                        Text(periodNames[index])
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == periods[index] ? Color.blue : Color.clear)
                            .foregroundColor(selectedPeriod == periods[index] ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search users...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Stats section
            HStack {
                if let lastUpdated = lastUpdated {
                    Text("Last updated: \(lastUpdated, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Total users: \(totalUsers)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxHeight: .infinity)
            } else if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                List {
                    if let userPosition = userPosition {
                        HStack {
                            Text("Your Position: \(userPosition)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.blue.opacity(0.1))
                    }
                    
                    ForEach(Array(filteredData.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 30)
                            
                            Text(entry.username)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(entry.score) pts")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(getBackgroundColor(for: index))
                    }
                }
            }
        }
        .onAppear {
            loadLeaderboardData()
        }
    }
    
    private func loadLeaderboardData() {
        isLoading = true
        error = nil
        let db = Firestore.firestore()
        let scoresCollection = db.collection(LeaderboardType.achievement.collectionName)
            .document(selectedPeriod)
            .collection("scores")
        // Query for top 10
        scoresCollection
            .order(by: LeaderboardType.achievement.scoreField, descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                isLoading = false
                if let error = error {
                    self.error = "Error loading leaderboard: \(error.localizedDescription)"
                    return
                }
                guard let documents = snapshot?.documents else {
                    self.error = "No data available"
                    return
                }
                leaderboardData = documents.compactMap { document -> LeaderboardEntry? in
                    guard let username = document.data()["username"] as? String,
                          let points = document.data()[LeaderboardType.achievement.scoreField] as? Int,
                          let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    return LeaderboardEntry(id: document.documentID, username: username, score: points, timestamp: timestamp)
                }
                // Find user's position
                if let userID = UserDefaults.standard.string(forKey: "userID") {
                    userPosition = leaderboardData.firstIndex(where: { $0.id == userID }).map { $0 + 1 }
                }
                // Update last updated time
                lastUpdated = Date()
            }
        // Query for total users
        scoresCollection.getDocuments { snapshot, _ in
            totalUsers = snapshot?.documents.count ?? 0
        }
    }
}

