import SwiftUI
import FirebaseFirestore

struct AchievementLeaderboardView: View {
    @State private var selectedPeriod = "daily"
    @State private var leaderboardData: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var error: String?
    
    private let periods = ["daily", "weekly", "monthly", "alltime"]
    private let periodNames = ["Daily", "Weekly", "Monthly", "All Time"]
    
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
                    ForEach(Array(leaderboardData.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 30)
                            
                            Text(entry.username)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(entry.score)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
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
        db.collection(LeaderboardType.achievement.collectionName)
            .document(selectedPeriod)
            .collection("scores")
            .order(by: LeaderboardType.achievement.scoreField, descending: true)
            .limit(to: 100)
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
            }
    }
}

