import SwiftUI
import Charts

// MARK: - Chart Views
@available(iOS 16.0, *)
struct FPSChart: View {
    let fpsHistory: [Double]
    
    var body: some View {
        Chart {
            ForEach(Array(fpsHistory.enumerated()), id: \.offset) { index, fps in
                LineMark(
                    x: .value("Time", index),
                    y: .value("FPS", fps)
                )
                .foregroundStyle(.blue)
            }
            
            RuleMark(y: .value("Target", 60))
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .chartYScale(domain: 0...120)
        .frame(height: 200)
    }
}

@available(iOS 16.0, *)
struct MemoryUsageChart: View {
    let memoryHistory: [(Date, Double)]
    
    var body: some View {
        Chart {
            ForEach(memoryHistory, id: \.0) { date, usage in
                LineMark(
                    x: .value("Time", date),
                    y: .value("Memory (MB)", usage)
                )
                .foregroundStyle(.green)
            }
        }
        .frame(height: 200)
    }
}

@available(iOS 16.0, *)
struct PatternSuccessChart: View {
    let patterns: [(String, Int, Int)] // (pattern, successes, failures)
    
    var body: some View {
        Chart {
            ForEach(patterns, id: \.0) { pattern, successes, failures in
                BarMark(
                    x: .value("Pattern", pattern),
                    y: .value("Successes", successes)
                )
                .foregroundStyle(.blue)
                
                BarMark(
                    x: .value("Pattern", pattern),
                    y: .value("Failures", failures)
                )
                .foregroundStyle(.red)
            }
        }
        .frame(height: 200)
    }
}

@available(iOS 16.0, *)
struct EngagementChart: View {
    let dailyUsers: [(Date, Int)]
    
    var body: some View {
        Chart {
            ForEach(dailyUsers, id: \.0) { date, count in
                BarMark(
                    x: .value("Date", date),
                    y: .value("Users", count)
                )
                .foregroundStyle(.purple)
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Legacy Views (iOS < 16.0)
struct LegacyFPSView: View {
    let fpsHistory: [Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FPS History")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(fpsHistory.enumerated()), id: \.offset) { index, fps in
                        VStack {
                            Rectangle()
                                .fill(fps >= 60 ? Color.green : Color.red)
                                .frame(width: 4, height: CGFloat(fps))
                            Text("\(Int(fps))")
                                .font(.system(size: 8))
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct LegacyMemoryView: View {
    let memoryHistory: [(Date, Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Usage")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(memoryHistory, id: \.0) { date, usage in
                        VStack {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 4, height: CGFloat(usage))
                            Text("\(Int(usage))MB")
                                .font(.system(size: 8))
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct LegacyPatternView: View {
    let patterns: [(String, Int, Int)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pattern Analysis")
                .font(.headline)
            
            ForEach(patterns.prefix(5), id: \.0) { pattern, successes, failures in
                HStack {
                    Text(pattern)
                        .font(.caption)
                    Spacer()
                    Text("✓ \(successes)")
                        .foregroundColor(.green)
                    Text("✗ \(failures)")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Main Analytics View
struct AnalyticsChartsView: View {
    let fpsHistory: [Double]
    let patternAnalytics: PatternAnalytics?
    let engagementMetrics: EngagementMetrics?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance Charts
                VStack(alignment: .leading) {
                    Text("Performance Metrics")
                        .font(.headline)
                    
                    if #available(iOS 16.0, *) {
                        FPSChart(fpsHistory: fpsHistory)
                    } else {
                        LegacyFPSView(fpsHistory: fpsHistory)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Pattern Analysis
                if let patterns = patternAnalytics {
                    VStack(alignment: .leading) {
                        Text("Pattern Analysis")
                            .font(.headline)
                        
                        let patternData = Array(patterns.successfulPatterns.keys.prefix(5)).map { pattern in
                            (
                                pattern,
                                patterns.successfulPatterns[pattern] ?? 0,
                                patterns.failedPatterns[pattern] ?? 0
                            )
                        }
                        
                        if #available(iOS 16.0, *) {
                            PatternSuccessChart(patterns: patternData)
                        } else {
                            LegacyPatternView(patterns: patternData)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                // Engagement Metrics
                if let engagement = engagementMetrics {
                    VStack(alignment: .leading) {
                        Text("User Engagement")
                            .font(.headline)
                        
                        if #available(iOS 16.0, *) {
                            let dailyUsers = [
                                (Date(), engagement.dailyActiveUsers),
                                (Date().addingTimeInterval(-86400), engagement.weeklyActiveUsers / 7),
                                (Date().addingTimeInterval(-172800), engagement.monthlyActiveUsers / 30)
                            ]
                            EngagementChart(dailyUsers: dailyUsers)
                        } else {
                            // Legacy engagement view
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Daily Active Users: \(engagement.dailyActiveUsers)")
                                Text("Weekly Active Users: \(engagement.weeklyActiveUsers)")
                                Text("Monthly Active Users: \(engagement.monthlyActiveUsers)")
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
            }
            .padding()
        }
    }
}

#Preview {
    AnalyticsChartsView(fpsHistory: [60, 62, 63, 65, 68, 70, 72], patternAnalytics: nil, engagementMetrics: nil)
} 