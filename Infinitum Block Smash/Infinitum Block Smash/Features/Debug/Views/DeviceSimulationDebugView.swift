import SwiftUI
import Combine

// MARK: - Device Simulation Debug View
struct DeviceSimulationDebugView: View {
    @StateObject private var deviceSimulationManager = DeviceSimulationManager.shared
    @StateObject private var fpsManager = FPSManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    // Use regular properties instead of @StateObject for MemorySystem
    private let memorySystem = MemorySystem.shared
    
    @State private var memoryUsage: (used: Double, total: Double) = (0, 0)
    @State private var memoryStatus: MemoryStatus = .normal
    @State private var cacheStats: (hits: Int, misses: Int) = (0, 0)
    
    @State private var showingCleanupAlert = false
    @State private var showingResetAlert = false
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Device Simulation Status
                    deviceSimulationSection
                    
                    // Memory Usage
                    memoryUsageSection
                    
                    // Performance Metrics
                    performanceSection
                    
                    // FPS Information
                    fpsSection
                    
                    // Recommendations
                    recommendationsSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Device Simulation")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(timer) { _ in
                updateMemoryInfo()
            }
            .onAppear {
                updateMemoryInfo()
            }
        }
        .alert("Memory Cleanup", isPresented: $showingCleanupAlert) {
            Button("OK") { }
        } message: {
            Text("Memory cleanup completed. Cache cleared and unused resources freed.")
        }
        .alert("Reset Simulation", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                deviceSimulationManager.resetSimulation()
            }
        } message: {
            Text("This will reset all simulation settings to default values. Continue?")
        }
    }
    
    private var deviceSimulationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                Text("Device Simulation")
                    .font(.headline)
                Spacer()
                StatusIndicator(isActive: deviceSimulationManager.isSimulatorMode)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DebugInfoRow(title: "Device Model", value: deviceSimulationManager.currentDeviceModel)
                DebugInfoRow(title: "Memory Limit", value: "\(String(format: "%.1f", deviceSimulationManager.memoryLimit))MB")
                DebugInfoRow(title: "CPU Cores", value: "\(deviceSimulationManager.cpuCores)")
                DebugInfoRow(title: "Max FPS", value: "\(deviceSimulationManager.maxFPS)")
                DebugInfoRow(title: "Low-End Device", value: deviceSimulationManager.isLowEndDevice ? "Yes" : "No")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var memoryUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.green)
                Text("Memory Usage")
                    .font(.headline)
                Spacer()
                StatusIndicator(isActive: memoryStatus == .normal)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DebugInfoRow(title: "Used Memory", value: "\(String(format: "%.1f", memoryUsage.used))MB")
                DebugInfoRow(title: "Total Available", value: "\(String(format: "%.1f", memoryUsage.total))MB")
                DebugInfoRow(title: "Usage Percentage", value: "\(String(format: "%.1f", memoryUsage.used / memoryUsage.total * 100))%")
                DebugInfoRow(title: "Status", value: memoryStatusText)
                DebugInfoRow(title: "Cache Hits", value: "\(cacheStats.hits)")
                DebugInfoRow(title: "Cache Misses", value: "\(cacheStats.misses)")
            }
            
            // Memory usage progress bar
            ProgressView(value: min(memoryUsage.used, memoryUsage.total), total: memoryUsage.total)
                .progressViewStyle(LinearProgressViewStyle(tint: memoryStatusColor))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.orange)
                Text("Performance Metrics")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DebugInfoRow(title: "CPU Usage", value: "\(String(format: "%.1f", performanceMonitor.cpuUsage))%")
                DebugInfoRow(title: "Memory Pressure", value: "\(String(format: "%.1f", deviceSimulationManager.memoryPressure * 100))%")
                DebugInfoRow(title: "Thermal Throttling", value: "\(String(format: "%.1f", deviceSimulationManager.thermalThrottling * 100))%")
                DebugInfoRow(title: "Frame Rate", value: "\(String(format: "%.1f", performanceMonitor.currentFPS)) FPS")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var fpsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "display")
                    .foregroundColor(.purple)
                Text("FPS Information")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DebugInfoRow(title: "Target FPS", value: "\(fpsManager.targetFPS)")
                DebugInfoRow(title: "Current FPS", value: "\(fpsManager.currentFPS)")
                DebugInfoRow(title: "Effective FPS", value: "\(fpsManager.getEffectiveFPS())")
                DebugInfoRow(title: "Available Options", value: fpsManager.availableFPSOptions.map { fpsManager.getFPSDisplayName(for: $0) }.joined(separator: ", "))
                DebugInfoRow(title: "Recommended FPS", value: "\(fpsManager.getRecommendedFPS())")
                DebugInfoRow(title: "Should Limit FPS", value: fpsManager.shouldLimitFPS() ? "Yes" : "No")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Recommendations")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(deviceSimulationManager.getPerformanceRecommendations(), id: \.title) { recommendation in
                    HStack(alignment: .top) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(recommendation.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await deviceSimulationManager.forceMemoryCleanup()
                    showingCleanupAlert = true
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Force Memory Cleanup")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Button(action: {
                showingResetAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Reset Simulation")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    private var memoryStatusText: String {
        switch memoryStatus {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }
    
    private var memoryStatusColor: Color {
        switch memoryStatus {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private func updateMemoryInfo() {
        memoryUsage = memorySystem.getMemoryUsage()
        memoryStatus = memorySystem.checkMemoryStatus()
        cacheStats = memorySystem.getCacheStats()
    }
}

// MARK: - Supporting Views

struct DebugInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isActive ? "Active" : "Inactive")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct DeviceSimulationDebugView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceSimulationDebugView()
    }
} 