/*
 * File: AchievementLeaderboardView.swift
 * Purpose: Displays achievement-based leaderboard with user rankings across different time periods
 * Author: @jrftw
 * Date: 6/19/2025
 * Dependencies: SwiftUI, FirebaseFirestore, FirebaseManager.shared, SearchBar component
 * Related Files: AchievementsView.swift, FirebaseManager.swift, LeaderboardService.swift
 */

/*
 * AchievementLeaderboardView.swift
 * 
 * MAIN PURPOSE:
 * Displays a leaderboard specifically for achievement-based rankings in the Infinitum Block Smash game.
 * Shows user rankings based on achievement points across different time periods (daily, weekly, monthly, all-time).
 * 
 * KEY FUNCTIONALITY:
 * - Displays achievement leaderboard with user rankings and scores
 * - Supports multiple time periods (daily, weekly, monthly, all-time)
 * - Real-time data fetching from Firebase with offline caching
 * - Search functionality to filter users
 * - Shows user position in leaderboard
 * - Displays reset timers for time-based periods
 * - Offline mode with cached data fallback
 * 
 * DEPENDENCIES:
 * - SwiftUI: Core UI framework
 * - FirebaseFirestore: Database access for leaderboard data
 * - FirebaseManager.shared: Main Firebase service for data operations
 * - SearchBar: Custom search component (referenced but not imported)
 * 
 * FILES THAT USE THIS:
 * - Likely used in main navigation or achievements section
 * - Referenced by AchievementsView or main game navigation
 * 
 * FILES THIS USES EXTENSIVELY:
 * - FirebaseManager.swift: For leaderboard data fetching and user management
 * - UserDefaults: For caching leaderboard data offline
 * 
 * DATA FLOW:
 * 1. View loads and calls loadLeaderboardData()
 * 2. FirebaseManager fetches achievement leaderboard entries
 * 3. Data is cached locally for offline access
 * 4. UI updates with leaderboard rankings and user position
 * 
 * REVIEW NOTES:
 * 
 * POTENTIAL ISSUES:
 * - SearchBar component is referenced but not imported - may cause compilation errors
 * - Calendar extension methods (startOfWeek, startOfMonth) may not exist - needs verification
 * - No error handling for invalid date calculations in timeUntilNextReset
 * - Cache key collision potential if multiple leaderboards use same naming pattern
 * - No pagination for large leaderboards - could cause performance issues
 * - UserDefaults caching doesn't handle data expiration
 * 
 * AREAS FOR IMPROVEMENT:
 * - Add pull-to-refresh functionality
 * - Implement proper pagination for large datasets
 * - Add loading states for individual period switches
 * - Consider using Core Data for better offline caching
 * - Add accessibility labels for screen readers
 * - Implement proper error retry mechanisms
 * 
 * DEPENDENCY CONCERNS:
 * - Heavy reliance on FirebaseManager.shared singleton
 * - Direct UserDefaults usage could be abstracted
 * - Calendar calculations could be moved to utility class
 * 
 * DATE: 6/19/2025
 * AUTHOR: @jrftw
 */

import SwiftUI
import FirebaseFirestore

// Main view struct for achievement leaderboard display
// Handles UI state management and data loading coordination
struct AchievementLeaderboardView: View {
    // State variables for UI management and data storage
    @State private var selectedPeriod = "daily"
    @State private var leaderboardData: [FirebaseManager.LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var userPosition: Int?
    @State private var lastUpdated: Date?
    @State private var totalUsers: Int = 0
    @State private var isOffline = false
    
    // Available time periods for leaderboard filtering
    private let periods = ["daily", "weekly", "monthly", "alltime"]
    
    // Computed property that filters leaderboard data based on search text
    // Returns all data if search is empty, otherwise filters by username
    private var filteredData: [FirebaseManager.LeaderboardEntry] {
        if searchText.isEmpty {
            return leaderboardData
        }
        return leaderboardData.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Main view body - orchestrates all UI components
    var body: some View {
        VStack(spacing: 16) {
            periodSelector
            
            SearchBar(text: $searchText)
                .padding(.horizontal)
            
            statsSection
            
            if isOffline {
                offlineBanner
            }
            
            leaderboardContent
        }
        .onAppear {
            loadLeaderboardData()
        }
    }
    
    // Period selector UI component
    // Allows users to switch between different time periods (daily, weekly, monthly, all-time)
    // Triggers data reload when period changes
    private var periodSelector: some View {
        HStack {
            ForEach(periods, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                    loadLeaderboardData()
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
    
    // Statistics section showing last update time and reset countdown
    // Displays total user count and time until next leaderboard reset
    private var statsSection: some View {
        HStack {
            if let lastUpdated = lastUpdated {
                Text("Last updated: \(lastUpdated, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if selectedPeriod != "alltime" {
                    Text("• Reset in: \(timeUntilNextReset)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Text(selectedPeriod == "alltime" ? "Total users: \(totalUsers)" : "Entries: \(totalUsers)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
    
    // Calculates time remaining until next leaderboard reset
    // Returns formatted string showing hours/minutes or days/hours remaining
    // Depends on Calendar extensions that may not exist
    private var timeUntilNextReset: String {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case "daily":
            let tomorrow = calendar.startOfDay(for: now.addingTimeInterval(86400))
            let components = calendar.dateComponents([.hour, .minute], from: now, to: tomorrow)
            return "\(components.hour ?? 0)h \(components.minute ?? 0)m"
        case "weekly":
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfWeek(for: now))!
            let components = calendar.dateComponents([.day, .hour], from: now, to: nextWeek)
            return "\(components.day ?? 0)d \(components.hour ?? 0)h"
        case "monthly":
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfMonth(for: now))!
            let components = calendar.dateComponents([.day, .hour], from: now, to: nextMonth)
            return "\(components.day ?? 0)d \(components.hour ?? 0)h"
        default:
            return ""
        }
    }
    
    // Offline mode indicator banner
    // Shows when cached data is being displayed due to network issues
    private var offlineBanner: some View {
        Text("Offline Mode - Showing cached data")
            .font(.caption)
            .foregroundColor(.orange)
            .padding(.horizontal)
    }
    
    // Main content area that switches between loading, error, and leaderboard states
    // Handles all possible UI states for data display
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
    
    // Error display view for when data loading fails
    // Shows error message and description to user
    private func errorView(_ error: String) -> some View {
        VStack {
            Text("Error loading leaderboard")
                .font(.headline)
                .foregroundColor(.red)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    // Scrollable list view displaying leaderboard entries
    // Shows rank, user avatar, username, level, and score for each entry
    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(filteredData.enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        Text("\(index + 1)")
                            .font(.headline)
                            .frame(width: 40)
                        
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                        
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
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // Main data loading function that fetches leaderboard data from Firebase
    // Handles caching, error states, and offline fallback
    // Updates all relevant state variables and logs debugging information
    private func loadLeaderboardData() {
        print("[AchievementLeaderboardView] Starting to load achievement leaderboard data")
        print("[AchievementLeaderboardView] Selected period: \(selectedPeriod)")
        
        isLoading = true
        error = nil
        
        let cacheKey = "cached_leaderboard_achievement_\(selectedPeriod)"
        
        Task {
            do {
                print("[AchievementLeaderboardView] Fetching leaderboard entries from LeaderboardService")
                let (entries, totalUsersCount) = try await LeaderboardService.shared.getLeaderboard(
                    type: .achievement,
                    period: selectedPeriod
                )
                
                print("[AchievementLeaderboardView] Received \(entries.count) entries, total users: \(totalUsersCount)")
                
                if let userId = FirebaseManager.shared.currentUserId {
                    userPosition = entries.firstIndex(where: { $0.id == userId })
                    print("[AchievementLeaderboardView] User position in leaderboard: \(userPosition ?? -1)")
                }
                
                // Log sample entries for debugging
                if !entries.isEmpty {
                    print("[AchievementLeaderboardView] Sample entries:")
                    for (index, entry) in entries.prefix(3).enumerated() {
                        print("[AchievementLeaderboardView] Entry \(index + 1):")
                        print("  - Username: \(entry.username)")
                        print("  - Score: \(entry.score)")
                        print("  - Timestamp: \(entry.timestamp)")
                    }
                }
                
                // Cache the data for offline access
                if let encodedData = try? JSONEncoder().encode(entries) {
                    UserDefaults.standard.set(encodedData, forKey: cacheKey)
                    print("[AchievementLeaderboardView] Successfully cached \(entries.count) entries")
                }
                
                leaderboardData = entries
                totalUsers = totalUsersCount
                lastUpdated = Date()
                isOffline = false
                print("[AchievementLeaderboardView] ✅ Successfully loaded achievement leaderboard data")
            } catch {
                print("[AchievementLeaderboardView] ❌ Error loading achievement leaderboard: \(error.localizedDescription)")
                // Try to load cached data
                if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
                   let entries = try? JSONDecoder().decode([FirebaseManager.LeaderboardEntry].self, from: cachedData) {
                    print("[AchievementLeaderboardView] Using cached data with \(entries.count) entries")
                    leaderboardData = entries
                    // For All Time, get total players count; for other periods, use entries count
                    if selectedPeriod == "alltime" {
                        do {
                            totalUsers = try await FirebaseManager.shared.getTotalPlayersCount()
                        } catch {
                            totalUsers = entries.count
                        }
                    } else {
                        totalUsers = entries.count
                    }
                    isOffline = true
                } else {
                    print("[AchievementLeaderboardView] ❌ No cached data available")
                    self.error = error.localizedDescription
                }
            }
            
            isLoading = false
            print("[AchievementLeaderboardView] Completed loading achievement leaderboard data")
        }
    }
}

// REVIEW NOTES:
// - SearchBar component is referenced but not imported - may cause compilation errors
// - Calendar extension methods (startOfWeek, startOfMonth) may not exist - needs verification
// - No error handling for invalid date calculations in timeUntilNextReset
// - Cache key collision potential if multiple leaderboards use same naming pattern
// - No pagination for large leaderboards - could cause performance issues
// - UserDefaults caching doesn't handle data expiration
// - Heavy reliance on FirebaseManager.shared singleton
// - Direct UserDefaults usage could be abstracted
// - Calendar calculations could be moved to utility class

// FUTURE IDEAS:
// - Add pull-to-refresh functionality
// - Implement proper pagination for large datasets
// - Add loading states for individual period switches
// - Consider using Core Data for better offline caching
// - Add accessibility labels for screen readers
// - Implement proper error retry mechanisms
// - Add user profile pictures/avatars
// - Implement real-time updates using Firebase listeners
// - Add achievement badges display in leaderboard
// - Create share functionality for user rankings
