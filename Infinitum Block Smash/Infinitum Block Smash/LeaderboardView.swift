import SwiftUI
import FirebaseFirestore

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod = "daily"
    @State private var selectedType: LeaderboardType = .score
    @State private var leaderboardData: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var error: String?
    
    private let periods = ["daily", "weekly", "monthly", "alltime"]
    private let periodNames = ["Daily", "Weekly", "Monthly", "All Time"]
    
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
                                
                                Text(selectedType == .score ? "\(entry.score)" : "\(entry.score) pts")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
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
        
        do {
            leaderboardData = try await LeaderboardService.shared.getLeaderboard(
                type: selectedType,
                period: selectedPeriod
            )
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
