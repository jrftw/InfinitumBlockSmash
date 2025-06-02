// AchievementsView.swift

import SwiftUI
import Combine

struct AchievementsView: View {
    @ObservedObject var achievementsManager: AchievementsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(achievementsManager.getAllAchievements()) { achievement in
                    AchievementRow(achievement: achievement)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(achievement.unlocked ? .primary : .secondary)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if achievement.goal > 1 {
                    ProgressView(value: min(Double(achievement.progress), Double(achievement.goal)), total: Double(achievement.goal))
                        .tint(achievement.unlocked ? .green : .blue)
                }
            }
            
            Spacer()
            
            if achievement.unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .imageScale(.large)
            } else if achievement.goal > 1 {
                Text("\(achievement.progress)/\(achievement.goal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
