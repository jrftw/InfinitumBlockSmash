import SwiftUI
import AppTrackingTransparency
import AdSupport

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var gameState: GameState
    @Binding var showingTutorial: Bool
    @AppStorage("showTutorial") private var showTutorial = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("musicVolume") private var musicVolume: Double = 0.7
    @AppStorage("sfxVolume") private var sfxVolume: Double = 0.7
    @AppStorage("difficulty") private var difficulty: String = "normal"
    @AppStorage("theme") private var theme: String = "auto"
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("hasAcceptedAds") private var hasAcceptedAds = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showingResetConfirmation = false
    @State private var showingChangelog = false
    @State private var deviceID: String = "Loading..."
    
    private let difficulties = ["easy", "normal", "hard", "expert"]
    private let themes = ["light", "dark", "auto"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Game")) {
                    Toggle("Show Tutorial", isOn: $showTutorial)
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(difficulties, id: \.self) { diff in
                            Text(diff.capitalized)
                        }
                    }
                    Toggle("Auto Save", isOn: $autoSave)
                }
                
                Section(header: Text("Audio")) {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    VStack {
                        Text("Music Volume")
                        Slider(value: $musicVolume, in: 0...1)
                    }
                    VStack {
                        Text("SFX Volume")
                        Slider(value: $sfxVolume, in: 0...1)
                    }
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $theme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme.capitalized)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showingResetConfirmation = true
                    }) {
                        Text("Reset Progress")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Device Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Advertising Identifier:")
                            .font(.headline)
                        Text(deviceID)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Text("Made In Pittsburgh, PA")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Progress", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    gameState.resetGame()
                }
            } message: {
                Text("Are you sure you want to reset all progress? This cannot be undone.")
            }
        }
        .onAppear {
            loadDeviceID()
        }
    }
    
    private func loadDeviceID() {
        print("Loading device ID...")
        if #available(iOS 14, *) {
            print("iOS 14+ detected, requesting tracking authorization...")
            ATTrackingManager.requestTrackingAuthorization { status in
                print("Tracking authorization status: \(status.rawValue)")
                DispatchQueue.main.async {
                    if status == .authorized {
                        let id = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                        print("Got advertising ID: \(id)")
                        deviceID = id
                    } else {
                        print("Tracking not authorized")
                        deviceID = "Tracking not authorized"
                    }
                }
            }
        } else {
            let id = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            print("Pre-iOS 14, got advertising ID: \(id)")
            deviceID = id
        }
    }
} 