import SwiftUI
import MessageUI

struct DebugLogsView: View {
    @State private var logs: String = ""
    @State private var realTimeLogs: String = ""
    @State private var previousLogs: String = ""
    @State private var showingMailView = false
    @State private var selectedTab = 0
    @State private var autoScroll = true
    @State private var logUpdateTimer: Timer?
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        Form {
            Section {
                Picker("Log Type", selection: $selectedTab) {
                    Text("Real-time").tag(0)
                    Text("Previous").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, 8)
                
                if selectedTab == 0 {
                    VStack(alignment: .leading) {
                        Text("Real-time Logs")
                            .font(.headline)
                        Text("Current session logs that update automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(realTimeLogs)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 400)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        
                        Toggle("Auto-scroll", isOn: $autoScroll)
                    }
                } else {
                    VStack(alignment: .leading) {
                        Text("Previous Logs")
                            .font(.headline)
                        Text("Historical logs from previous sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(previousLogs)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 400)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            
            Section {
                Button(action: {
                    Task { @MainActor in
                        let allLogs = CrashReporter.shared.getDebugLogs()
                        let activityVC = UIActivityViewController(
                            activityItems: [allLogs],
                            applicationActivities: nil
                        )
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    }
                }) {
                    Label("Send All Logs", systemImage: "square.and.arrow.up")
                }
                
                Button(action: {
                    Task { @MainActor in
                        let allLogs = CrashReporter.shared.getDebugLogs()
                        UIPasteboard.general.string = allLogs
                    }
                }) {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                }
                
                Button(action: {
                    showingPrivacyPolicy = true
                }) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("Debug Logs")
        .onAppear {
            loadLogs()
            startLogUpdates()
        }
        .onDisappear {
            stopLogUpdates()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            NavigationView {
                PrivacyPolicyView()
            }
        }
    }
    
    private func loadLogs() {
        Task { @MainActor in
            previousLogs = CrashReporter.shared.getDebugLogs()
            realTimeLogs = CrashReporter.shared.getRealTimeLogs()
        }
    }
    
    private func startLogUpdates() {
        logUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                realTimeLogs = CrashReporter.shared.getRealTimeLogs()
            }
        }
    }
    
    private func stopLogUpdates() {
        logUpdateTimer?.invalidate()
        logUpdateTimer = nil
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Debug Logs Privacy Policy")
                    .font(.title)
                    .bold()
                    .padding(.bottom)
                
                Group {
                    Text("Data Collection and Privacy")
                        .font(.headline)
                    
                    Text("The debug logs feature collects technical information about your app usage, including performance metrics, system status, and gameplay statistics. This information is collected solely for the purpose of improving app performance and user experience.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Data Handling")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("• All collected data is stored locally on your device\n• Data is not linked to your personal information\n• Data is not transmitted to our servers unless explicitly shared by you\n• All debug logs are automatically cleared when the app session ends\n• You have full control over what data is shared")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Data Sharing")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Debug logs are only shared when you explicitly choose to send them through the 'Send All Logs' feature. This sharing is completely voluntary and under your control. The data is not accessible to us unless you choose to share it.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Data Retention")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Debug logs are temporary and are automatically cleared when you close the app. No data is permanently stored or retained beyond your current app session.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
            }
            .padding()
        }
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

