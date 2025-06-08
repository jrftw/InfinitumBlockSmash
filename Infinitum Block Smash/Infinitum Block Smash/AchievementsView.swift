// AchievementsView.swift

import SwiftUI
import Combine

struct AchievementsView: View {
    @ObservedObject var achievementsManager: AchievementsManager
    @State private var showingLeaderboard = false
    @State private var selectedCategory: String? = nil
    
    private let categories = [
        NSLocalizedString("All", comment: "All achievements category"),
        NSLocalizedString("Score", comment: "Score achievements category"),
        NSLocalizedString("Level", comment: "Level achievements category"),
        NSLocalizedString("Clearing", comment: "Clearing achievements category"),
        NSLocalizedString("Combo", comment: "Combo achievements category"),
        NSLocalizedString("Special", comment: "Special achievements category"),
        NSLocalizedString("Daily", comment: "Daily achievements category")
    ]
    
    private func achievementsForCategory(_ category: String) -> [Achievement] {
        if category == NSLocalizedString("All", comment: "All achievements category") {
            return achievementsManager.getAllAchievements()
        }
        
        return achievementsManager.getAllAchievements().filter { achievement in
            switch category {
            case NSLocalizedString("Score", comment: "Score achievements category"):
                return achievement.id.starts(with: "score_")
            case NSLocalizedString("Level", comment: "Level achievements category"):
                return achievement.id.starts(with: "level_")
            case NSLocalizedString("Clearing", comment: "Clearing achievements category"):
                return achievement.id.starts(with: "clear_") || achievement.id.starts(with: "first_clear")
            case NSLocalizedString("Combo", comment: "Combo achievements category"):
                return achievement.id.starts(with: "combo_") || achievement.id.starts(with: "chain_")
            case NSLocalizedString("Special", comment: "Special achievements category"):
                return achievement.id.starts(with: "perfect_") || achievement.id.starts(with: "color_") ||
                       achievement.id.starts(with: "shape_") || achievement.id.starts(with: "grid_")
            case NSLocalizedString("Daily", comment: "Daily achievements category"):
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
                        Text(NSLocalizedString("Total Points", comment: "Total points label"))
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
                            Text(NSLocalizedString("Leaderboard", comment: "Leaderboard button"))
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
                                selectedCategory = category == NSLocalizedString("All", comment: "All achievements category") ? nil : category
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
                    ForEach(achievementsForCategory(selectedCategory ?? NSLocalizedString("All", comment: "All achievements category"))) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Achievements", comment: "Achievements view title"))
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
                        
                        Text(String(format: NSLocalizedString("Progress: %d/%d (%d%%)", comment: "Achievement progress"), 
                            achievement.progress, 
                            achievement.goal,
                            Int((Double(achievement.progress) / Double(achievement.goal)) * 100)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(String(format: NSLocalizedString("%d pts", comment: "Achievement points"), achievement.points))
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
            
            Text(NSLocalizedString("Achievement Unlocked!", comment: "Achievement unlocked notification"))
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
