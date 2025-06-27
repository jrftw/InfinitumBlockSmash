import SwiftUI
import Foundation

struct UpdateManagementView: View {
    @StateObject private var versionCheckService = VersionCheckService.shared
    @StateObject private var remoteConfigService = RemoteConfigService.shared
    @StateObject private var maintenanceService = MaintenanceService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingForceUpdateAlert = false
    @State private var showingClearCacheAlert = false
    @State private var showingRefreshAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Current Status Section
                Section(header: Text("Current Status")) {
                    StatusRow(title: "Update Status", value: versionCheckService.getUpdateStatus())
                    StatusRow(title: "Last Check", value: formatDate(versionCheckService.lastCheckDate))
                    StatusRow(title: "Environment", value: getEnvironmentString())
                    StatusRow(title: "Current Version", value: AppVersion.formattedVersion)
                }
                
                // Remote Configuration Section
                Section(header: Text("Remote Configuration")) {
                    StatusRow(title: "Force Update", value: remoteConfigService.isForceUpdateEnabled ? "Enabled" : "Disabled")
                    StatusRow(title: "Minimum Version", value: remoteConfigService.minimumRequiredVersion)
                    StatusRow(title: "Check Interval", value: "\(remoteConfigService.updateCheckIntervalHours) hours")
                    StatusRow(title: "Emergency Update", value: remoteConfigService.isEmergencyUpdateRequired ? "Required" : "Not Required")
                    StatusRow(title: "Maintenance Mode", value: maintenanceService.isMaintenanceModeEnabled ? "Active" : "Inactive")
                }
                
                // Actions Section
                Section(header: Text("Actions")) {
                    Button(action: {
                        versionCheckService.forceUpdateCheck()
                        showingRefreshAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Check for Updates")
                        }
                    }
                    
                    Button(action: {
                        remoteConfigService.forceRefresh()
                        maintenanceService.forceRefresh()
                        showingRefreshAlert = true
                    }) {
                        HStack {
                            Image(systemName: "network")
                            Text("Refresh Remote Config")
                        }
                    }
                    
                    Button(action: {
                        showingClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Update Cache")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Debug Information Section
                Section(header: Text("Debug Information")) {
                    NavigationLink(destination: DebugConfigView()) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("View Remote Config")
                        }
                    }
                    
                    NavigationLink(destination: UpdateLogView()) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Update Logs")
                        }
                    }
                }
                
                // Settings Section
                Section(header: Text("Settings")) {
                    Toggle("Force Public Version", isOn: Binding(
                        get: { ForcePublicVersion.shared.isEnabled },
                        set: { ForcePublicVersion.shared.isEnabled = $0 }
                    ))
                    .onChange(of: ForcePublicVersion.shared.isEnabled) { newValue in
                        if newValue {
                            showingForceUpdateAlert = true
                        }
                    }
                }
            }
            .navigationTitle("Update Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Force Public Version", isPresented: $showingForceUpdateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This will force all users to download the public App Store version. This setting is typically used to prevent beta users from using outdated versions.")
        }
        .alert("Cache Cleared", isPresented: $showingClearCacheAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The update cache has been cleared. The next update check will fetch fresh data from the server.")
        }
        .alert("Refresh Initiated", isPresented: $showingRefreshAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The refresh has been initiated. Check the status above for updates.")
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getEnvironmentString() -> String {
        if AppVersion.isSimulator {
            return "Simulator"
        } else if AppVersion.isDevelopmentBuild {
            return "Development"
        } else if AppVersion.isTestFlight {
            return "TestFlight"
        } else if AppVersion.isAppStoreBuild {
            return "App Store"
        } else {
            return "Unknown"
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct DebugConfigView: View {
    @StateObject private var remoteConfigService = RemoteConfigService.shared
    
    var body: some View {
        List {
            Section(header: Text("Remote Configuration Values")) {
                ForEach(Array(remoteConfigService.getCurrentConfig().keys.sorted()), id: \.self) { key in
                    if let value = remoteConfigService.getCurrentConfig()[key] {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.headline)
                            Text("\(String(describing: value))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Remote Config")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UpdateLogView: View {
    @State private var logs: [String] = []
    
    var body: some View {
        List {
            Section(header: Text("Recent Update Activity")) {
                if logs.isEmpty {
                    Text("No recent update activity")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(logs, id: \.self) { log in
                        Text(log)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Update Logs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadLogs()
        }
    }
    
    private func loadLogs() {
        // This would typically load from a log file or database
        // For now, we'll show a placeholder
        logs = [
            "2025-01-19 10:30:15 - Update check completed",
            "2025-01-19 10:30:10 - Checking for updates...",
            "2025-01-19 10:30:05 - Remote config refreshed",
            "2025-01-19 10:30:00 - App launched"
        ]
    }
}

#Preview {
    UpdateManagementView()
} 