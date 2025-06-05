// AchievementsView.swift

import SwiftUI
import Combine

struct AchievementsView: View {
    @ObservedObject var achievementsManager: AchievementsManager
    @State private var showingLeaderboard = false
    @State private var selectedCategory: String? = nil
    
    private let categories = [
        "All",
        "Score",
        "Level",
        "Clearing",
        "Combo",
        "Special",
        "Daily"
    ]
    
    private func achievementsForCategory(_ category: String) -> [Achievement] {
        if category == "All" {
            return achievementsManager.getAllAchievements()
        }
        
        return achievementsManager.getAllAchievements().filter { achievement in
            switch category {
            case "Score":
                return achievement.id.starts(with: "score_")
            case "Level":
                return achievement.id.starts(with: "level_")
            case "Clearing":
                return achievement.id.starts(with: "clear_") || achievement.id.starts(with: "first_clear")
            case "Combo":
                return achievement.id.starts(with: "combo_") || achievement.id.starts(with: "chain_")
            case "Special":
                return achievement.id.starts(with: "perfect_") || achievement.id.starts(with: "color_") ||
                       achievement.id.starts(with: "shape_") || achievement.id.starts(with: "grid_")
            case "Daily":
                return achievement.id.starts(with: "login_") || achievement.id.starts(with: "daily_")
            default:
                return false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Total points display
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Points")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("\(achievementsManager.totalPoints)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Button(action: { showingLeaderboard = true }) {
                        HStack {
                            Image(systemName: "trophy.fill")
                            Text("Leaderboard")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category == "All" ? nil : category
                            }) {
                                Text(category)
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Achievements list
                List {
                    ForEach(achievementsForCategory(selectedCategory ?? "All")) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }
            }
            .navigationTitle("Achievements")
            .sheet(isPresented: $showingLeaderboard) {
                AchievementLeaderboardView()
            }
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.name)
                        .font(.headline)
                    if achievement.unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !achievement.unlocked {
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: Double(achievement.progress), total: Double(achievement.goal))
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 4)
                        
                        Text("\(achievement.progress)/\(achievement.goal) (\(Int((Double(achievement.progress) / Double(achievement.goal)) * 100))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text("\(achievement.points) pts")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
        .opacity(achievement.unlocked ? 1.0 : 0.7)
    }
}

struct AchievementNotification: View {
    let achievement: Achievement
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("Achievement Unlocked!")
                .font(.headline)
            
            Text(achievement.name)
                .font(.title3)
                .multilineTextAlignment(.center)
            
            Text(achievement.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(radius: 10)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    AchievementsView(achievementsManager: AchievementsManager())
}
