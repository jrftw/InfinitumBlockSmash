import SwiftUI
import AppTrackingTransparency

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
    
    private let difficulties = ["easy", "normal", "hard", "expert"]
    private let themes = ["light", "dark", "auto"]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Game Settings")) {
                    Picker("Theme", selection: $theme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme.capitalized)
                        }
                    }
                    .onChange(of: theme) { newValue in
                        updateTheme(newValue)
                    }
                    
                    Toggle("Show Tutorial", isOn: $showTutorial)
                    Toggle("Auto Save", isOn: $autoSave)
                }
                
                Section(header: Text("Audio Settings")) {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Music Volume")
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $musicVolume, in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SFX Volume")
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $sfxVolume, in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                    }
                }
                
                Section(header: Text("Game Progress")) {
                    HStack {
                        Text("High Score")
                        Spacer()
                        Text("\(UserDefaults.standard.integer(forKey: "highScore"))")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Highest Level")
                        Spacer()
                        Text("\(UserDefaults.standard.integer(forKey: "highestLevel"))")
                            .foregroundColor(.blue)
                    }
                }
                
                // Rules Section
                Section(header: Text("Rules").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Drag shapes from the tray onto the grid.", systemImage: "hand.point.up.left.fill")
                        Label("Shapes come in many sizes and rotations, including I, L, T, and more.", systemImage: "cube")
                        Label("Fill an entire row or column to clear it and earn points.", systemImage: "line.horizontal.3.decrease.circle")
                        Label("Bonus points for clearing lines with all the same color.", systemImage: "star.fill")
                        Label("Group bonuses for clearing large groups when clearing lines.", systemImage: "sparkles")
                        Label("Level up by reaching the required score (Level × 1000).", systemImage: "arrow.up.right.square")
                        Label("Each level gets harder with more shapes and colors.", systemImage: "flame")
                        Label("Undo your last move once per placement.", systemImage: "arrow.uturn.left.circle")
                        Label("Pause the game anytime with the pause button.", systemImage: "pause.circle")
                        Label("Game over if none of your tray shapes can be placed.", systemImage: "xmark.octagon")
                        Label("Track your high score and highest level in the settings.", systemImage: "chart.bar")
                        Divider()
                        Button(action: { showingTutorial = true }) {
                            Label("View Tutorial", systemImage: "questionmark.circle")
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Section(header: Text("Data Management")) {
                    Button("Reset Game Data") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.red)
                    
                    NavigationLink(destination: ChangelogView()) {
                        Text("Changelog")
                    }
                }
                
                Section {
                    VStack(spacing: 8) {
                        Text(AppVersion.location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(AppVersion.formattedVersion)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(AppVersion.copyright)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(AppVersion.credits)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Reset Game Data", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    // Reset game data
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                }
            } message: {
                Text("This will reset all game data including high scores and achievements. This action cannot be undone.")
            }
        }
    }
    
    private func updateTheme(_ newValue: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        switch newValue {
        case "auto":
            window.overrideUserInterfaceStyle = .unspecified
        case "dark":
            window.overrideUserInterfaceStyle = .dark
        case "light":
            window.overrideUserInterfaceStyle = .light
        default:
            break
        }
    }
    
    private func requestTrackingAuthorization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { status in
                // Handle tracking authorization status
            }
        }
    }
} 