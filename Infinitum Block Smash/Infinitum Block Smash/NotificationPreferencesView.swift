import SwiftUI
import UserNotifications

struct NotificationPreferencesView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("eventNotifications") private var eventNotifications = true
    @AppStorage("updateNotifications") private var updateNotifications = true
    @AppStorage("reminderNotifications") private var reminderNotifications = true
    @State private var deviceToken: String = UserDefaults.standard.string(forKey: "deviceToken") ?? "Not registered"
    @State private var showingPermissionAlert = false
    
    var body: some View {
        List {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { newValue in
                        if newValue {
                            requestNotificationPermission()
                        } else {
                            disableNotifications()
                        }
                    }
            }
            
            if notificationsEnabled {
                Section(header: Text("Notification Types")) {
                    Toggle("Events", isOn: $eventNotifications)
                    Toggle("Updates", isOn: $updateNotifications)
                    Toggle("Reminders", isOn: $reminderNotifications)
                        .onChange(of: reminderNotifications) { newValue in
                            if newValue {
                                NotificationManager.shared.scheduleDailyReminder()
                            } else {
                                NotificationManager.shared.cancelDailyReminder()
                            }
                        }
                }
                
                Section(header: Text("Device Token")) {
                    HStack {
                        Text(deviceToken)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = deviceToken
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
            }
        }
        .navigationTitle("Notification Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
            Button("Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                notificationsEnabled = false
            }
        } message: {
            Text("Please enable notifications in Settings to receive updates and reminders.")
        }
        .onAppear {
            updateDeviceToken()
            if notificationsEnabled {
                requestNotificationPermission()
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    if reminderNotifications {
                        NotificationManager.shared.scheduleDailyReminder()
                    }
                } else {
                    notificationsEnabled = false
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func disableNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
        eventNotifications = false
        updateNotifications = false
        reminderNotifications = false
        NotificationManager.shared.cancelDailyReminder()
    }
    
    private func updateDeviceToken() {
        if let token = UserDefaults.standard.string(forKey: "deviceToken") {
            deviceToken = token
        }
    }
}

#Preview {
    NavigationView {
        NotificationPreferencesView()
    }
} 