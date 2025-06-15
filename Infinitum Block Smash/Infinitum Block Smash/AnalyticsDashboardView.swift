import SwiftUI
import Charts

// MARK: - Analytics Dashboard View
struct AnalyticsDashboardView: View {
    @StateObject private var analyticsManager = AnalyticsManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var selectedTimeRange: TimeRange = .day
    @State private var showingCharts = false
    @State private var isLoading = false
    @State private var error: Error?
    
    @State private var debounceTask: Task<Void, Never>? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TimeRangePicker(selectedRange: $selectedTimeRange)
                ChartsToggleButton(showingCharts: $showingCharts)
                
                if isLoading {
                    AnalyticsLoadingView()
                } else if let error = error {
                    ErrorView(error: error) {
                        Task {
                            await loadAnalytics()
                        }
                    }
                } else {
                    AnalyticsContent(
                        showingCharts: showingCharts,
                        analytics: analyticsManager.gameAnalytics,
                        patternAnalytics: analyticsManager.patternAnalytics,
                        engagementMetrics: analyticsManager.engagementMetrics,
                        metrics: performanceMonitor.performanceMetrics,
                        fpsHistory: performanceMonitor.fpsHistory
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Analytics Dashboard")
        .onChange(of: selectedTimeRange) { _ in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds debounce
                await loadAnalytics()
            }
        }
        .task {
            await loadAnalytics()
        }
    }
    
    private func loadAnalytics() async {
        isLoading = true
        error = nil
        
        do {
            try await analyticsManager.loadFromFirebase(timeRange: selectedTimeRange)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views
private struct TimeRangePicker: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}

private struct ChartsToggleButton: View {
    @Binding var showingCharts: Bool
    
    var body: some View {
        Button(action: { showingCharts.toggle() }) {
            HStack {
                Image(systemName: showingCharts ? "chart.bar.fill" : "chart.bar")
                Text(showingCharts ? "Hide Charts" : "Show Charts")
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct AnalyticsContent: View {
    let showingCharts: Bool
    let analytics: GameAnalytics?
    let patternAnalytics: PatternAnalytics?
    let engagementMetrics: EngagementMetrics?
    let metrics: [String: Double]
    let fpsHistory: [Double]
    
    var body: some View {
        VStack(spacing: 20) {
            if showingCharts {
                AnalyticsChartsView(
                    fpsHistory: fpsHistory,
                    patternAnalytics: patternAnalytics,
                    engagementMetrics: engagementMetrics
                )
            }
            
            PerformanceMetricsView(metrics: metrics)
            
            if analytics != nil || patternAnalytics != nil {
                VStack(spacing: 16) {
                    if let analytics = analytics {
                        GameAnalyticsView(analytics: analytics)
                            .modifier(CardModifier())
                    }
                    
                    // Pattern analytics
                    if let patterns = patternAnalytics {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pattern Analytics")
                                .font(.headline)
                            
                            ForEach(Array(patterns.successfulPatterns.keys.prefix(5)), id: \.self) { pattern in
                                if let count = patterns.successfulPatterns[pattern] {
                                    HStack {
                                        Text(pattern)
                                        Spacer()
                                        Text("Success: \(count)")
                                            .foregroundColor(.green)
                                        if let failures = patterns.failedPatterns[pattern] {
                                            Text("Failures: \(failures)")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                        .modifier(CardModifier())
                    }
                }
            }
            
            // Engagement metrics
            if let engagement = engagementMetrics {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Engagement Metrics")
                        .font(.headline)
                    
                    HStack {
                        Text("Daily Active Users")
                        Spacer()
                        Text("\(engagement.dailyActiveUsers)")
                    }
                    
                    HStack {
                        Text("Weekly Active Users")
                        Spacer()
                        Text("\(engagement.weeklyActiveUsers)")
                    }
                    
                    HStack {
                        Text("Monthly Active Users")
                        Spacer()
                        Text("\(engagement.monthlyActiveUsers)")
                    }
                }
                .modifier(CardModifier())
            }
        }
    }
}

private struct GameAnalyticsView: View {
    let analytics: GameAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Analytics")
                .font(.headline)
            
            HStack {
                Text("Total Games")
                Spacer()
                Text("\(analytics.sessionsPerDay)")
            }
            
            HStack {
                Text("Average Score")
                Spacer()
                Text(String(format: "%.1f", analytics.averageScorePerLevel))
                    .monospacedDigit()
            }
            
            HStack {
                Text("Average Session")
                Spacer()
                Text(String(format: "%.1f min", analytics.averageSessionDuration / 60))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Performance Metrics View
struct PerformanceMetricsView: View {
    let metrics: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
            
            if let fps = metrics["fps"] {
                HStack {
                    Text("FPS")
                    Spacer()
                    Text(String(format: "%.1f", fps))
                        .foregroundColor(fps >= 60 ? .green : .red)
                        .monospacedDigit()
                }
            }
            
            if let memory = metrics["memory"] {
                HStack {
                    Text("Memory Usage")
                    Spacer()
                    Text(String(format: "%.1f MB", memory))
                }
            }
        }
        .modifier(CardModifier())
    }
}

// MARK: - Loading and Error Views
struct AnalyticsLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Loading analytics data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Error loading analytics")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Text("Retry")
                    .bold()
            }
            .buttonStyle(.bordered)
        }
        .modifier(CardModifier())
    }
}
