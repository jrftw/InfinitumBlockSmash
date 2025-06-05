import SwiftUI
import FirebaseFirestore

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod = "daily"
    @State private var selectedType: LeaderboardType = .score
    @State private var leaderboardData: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var userPosition: Int?
    @State private var allTimeUserPosition: Int?
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
        NavigationView {
            VStack(spacing: 0) {
                // Leaderboard type selector
                Picker("Leaderboard Type", selection: $selectedType) {
                    Text("High Scores").tag(LeaderboardType.score)
                    Text("Achievements").tag(LeaderboardType.achievement)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Period selector
                HStack {
                    ForEach(0..<periods.count, id: \.self) { index in
                        Button(action: {
                            selectedPeriod = periods[index]
                            Task {
                                await loadLeaderboardData()
                            }
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
                
                // Elite Player Status Banner (show only for High Scores All Time)
                if selectedType == .score && selectedPeriod == "alltime" && leaderboardData.count >= 3 {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Elite Player: Top 3 in All Time - Ad Free!")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                }
                
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
                                
                                Text(selectedType == .score ? "\(entry.score)" : "\(entry.score) pts")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(getBackgroundColor(for: index))
                        }
                    }
                }
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
            .onChange(of: selectedType) { _ in
                Task {
                    await loadLeaderboardData()
                }
            }
            .onChange(of: selectedPeriod) { _ in
                Task {
                    await loadLeaderboardData()
                }
            }
            .task {
                await loadLeaderboardData()
            }
        }
    }
    
    private func loadLeaderboardData() async {
        isLoading = true
        error = nil
        let db = Firestore.firestore()
        let scoresCollection = db.collection(selectedType.collectionName)
            .document(selectedPeriod)
            .collection("scores")
        do {
            // Query for top 10
            let snapshot = try await scoresCollection
                .order(by: selectedType.scoreField, descending: true)
                .limit(to: 10)
                .getDocuments()
            leaderboardData = snapshot.documents.compactMap { document -> LeaderboardEntry? in
                guard let username = document.data()["username"] as? String,
                      let score = document.data()[selectedType.scoreField] as? Int,
                      let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                return LeaderboardEntry(id: document.documentID, username: username, score: score, timestamp: timestamp)
            }
            
            // Find user's position in current period
            if let userID = UserDefaults.standard.string(forKey: "userID") {
                if let idx = leaderboardData.firstIndex(where: { $0.id == userID }) {
                    userPosition = idx + 1
                } else {
                    // If not in top 10, find user's position in the whole leaderboard
                    let allSnapshot = try await scoresCollection
                        .order(by: selectedType.scoreField, descending: true)
                        .getDocuments()
                    if let idx = allSnapshot.documents.firstIndex(where: { $0.documentID == userID }) {
                        userPosition = idx + 1
                    } else {
                        userPosition = nil
                    }
                }
            }
            
            // Always check All Time position
            if let userID = UserDefaults.standard.string(forKey: "userID") {
                let allTimeCollection = db.collection(selectedType.collectionName)
                    .document("alltime")
                    .collection("scores")
                let allTimeSnapshot = try await allTimeCollection
                    .order(by: selectedType.scoreField, descending: true)
                    .getDocuments()
                if let idx = allTimeSnapshot.documents.firstIndex(where: { $0.documentID == userID }) {
                    allTimeUserPosition = idx + 1
                } else {
                    allTimeUserPosition = nil
                }
            }
            
            // Update last updated time
            lastUpdated = Date()
            // Query for total users
            let totalSnapshot = try await scoresCollection.getDocuments()
            totalUsers = totalSnapshot.documents.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
