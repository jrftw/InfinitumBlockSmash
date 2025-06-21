/******************************************************
 * FILE: StatsView.swift
 * MARK: Game Statistics and Player Progress Display Interface
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides a comprehensive statistics and progress tracking interface that displays
 * detailed player performance metrics, achievement progress, and skill level analysis.
 * This view serves as the primary analytics dashboard for players to track their
 * improvement and understand their gameplay patterns.
 *
 * KEY RESPONSIBILITIES:
 * - Comprehensive game statistics display and tracking
 * - Player skill level calculation and analysis
 * - Achievement progress monitoring and visualization
 * - Performance metrics breakdown and analysis
 * - Play time tracking and formatting
 * - Skill component analysis and scoring
 * - Visual data presentation with cards and grids
 * - Interactive information tooltips and explanations
 * - Responsive design for different screen sizes
 * - Accessibility support for statistics comprehension
 * - Real-time data updates and synchronization
 * - Achievement progress visualization
 * - Player skill level assessment and feedback
 *
 * MAJOR DEPENDENCIES:
 * - GameState.swift: Game statistics and player data
 * - AchievementsManager.swift: Achievement tracking and progress
 * - Foundation: Core framework for data formatting and calculations
 * - SwiftUI: Core UI framework for interface components
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - Foundation: Core framework for data structures and formatting
 *
 * ARCHITECTURE ROLE:
 * Acts as an analytics dashboard that provides players with
 * comprehensive insights into their gameplay performance,
 * progress tracking, and skill development.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Statistics must be calculated accurately and in real-time
 * - Skill level calculations should reflect current game mechanics
 * - Achievement progress should be properly synchronized
 * - Data formatting should be user-friendly and localized
 * - Performance should be optimized for frequent updates
 */

import SwiftUI

struct StatsView: View {
    @ObservedObject var gameState: GameState
    @State private var showingInfoFor: InfoItem? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Game Statistics")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top)
                
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    // Basic Stats
                    StatCard(
                        title: "Blocks Placed",
                        value: "\(gameState.blocksPlaced)",
                        icon: "square.grid.3x3.fill",
                        color: .blue,
                        description: "Total number of blocks placed in the game"
                    )
                    
                    StatCard(
                        title: "Lines Cleared",
                        value: "\(gameState.linesCleared)",
                        icon: "line.3.horizontal",
                        color: .green,
                        description: "Total number of lines cleared"
                    )
                    
                    StatCard(
                        title: "Total Score",
                        value: "\(gameState.score)",
                        icon: "star.fill",
                        color: .yellow,
                        description: "Your current total score"
                    )
                    
                    StatCard(
                        title: "Games Completed",
                        value: "\(gameState.gamesCompleted)",
                        icon: "trophy.fill",
                        color: .orange,
                        description: "Number of games completed"
                    )
                    
                    StatCard(
                        title: "Perfect Levels",
                        value: "\(gameState.perfectLevels)",
                        icon: "checkmark.circle.fill",
                        color: .purple,
                        description: "Levels completed without any mistakes"
                    )
                    
                    StatCard(
                        title: "Play Time",
                        value: formatPlayTime(gameState.gameStartTime),
                        icon: "clock.fill",
                        color: .red,
                        description: "Total time spent playing"
                    )
                }
                .padding(.horizontal)
                
                // Achievement Progress
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Achievement Progress")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            showingInfoFor = InfoItem(
                                id: "achievements",
                                title: "Achievements",
                                description: "Achievements are special goals you can complete while playing. Each achievement has a specific requirement and rewards you with points when completed. Keep playing to unlock them all!"
                            )
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(gameState.achievementsManager.allAchievements) { achievement in
                                AchievementCard(achievement: achievement)
                                    .frame(width: 300)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)

                // Player Skill Section
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Player Skill")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            showingInfoFor = InfoItem(
                                id: "player_skill",
                                title: "Player Skill",
                                description: "Your skill level is calculated based on your perfect levels, chain bonuses, and average score per level. Higher skill levels unlock more complex gameplay mechanics!"
                            )
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        // Overall Skill Level
                        SkillCard(
                            title: "Overall Skill Level",
                            value: "\(gameState.calculatePlayerSkill())/5",
                            icon: "star.fill",
                            color: .yellow,
                            description: "Your overall skill level based on all factors"
                        )
                        
                        // Skill Components
                        SkillCard(
                            title: "Perfect Levels Bonus",
                            value: "\(gameState.perfectLevels * 2)",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            description: "Bonus from completing levels perfectly"
                        )
                        
                        SkillCard(
                            title: "Chain Bonus",
                            value: "\(gameState.currentChain)",
                            icon: "link",
                            color: .blue,
                            description: "Current chain multiplier"
                        )
                        
                        SkillCard(
                            title: "Score Efficiency",
                            value: "\(Int(Double(gameState.score) / Double(max(1, gameState.level)) / 1000))",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple,
                            description: "Average score per level (in thousands)"
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.2, blue: 0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(item: $showingInfoFor) { info in
            InfoView(info: info)
        }
    }
    
    private func formatPlayTime(_ startTime: Date?) -> String {
        let totalSeconds = Int(gameState.totalPlayTime)
        let hours = totalSeconds / 3600
        let minutes = totalSeconds / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let description: String
    @State private var showingInfo = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                
                Spacer()
                
                Button(action: {
                    showingInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .alert(title, isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(description)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    @State private var showingInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(achievement.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Text("\(achievement.progress)/\(achievement.goal)")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(achievement.unlocked ? Color.green : Color.blue)
                        .frame(width: geometry.size.width * CGFloat(achievement.progress) / CGFloat(achievement.goal), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .alert(achievement.name, isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(achievement.description)
        }
    }
}

struct InfoView: View {
    let info: InfoItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(info.description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                }
            }
            .navigationTitle(info.title)
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

struct InfoItem: Identifiable {
    let id: String
    let title: String
    let description: String
}

struct SkillCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let description: String
    @State private var showingInfo = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            Button(action: {
                showingInfo = true
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .alert(title, isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(description)
        }
    }
} 