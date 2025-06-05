import SwiftUI
import AppTrackingTransparency
import MessageUI
import SafariServices

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
    @AppStorage("allowAnalytics") private var allowAnalytics = true
    @AppStorage("allowDataSharing") private var allowDataSharing = true
    @AppStorage("placementPrecision") private var placementPrecision: Double = 0.15
    @AppStorage("blockDragOffset") private var blockDragOffset: Double = 0.4
    @Environment(\.presentationMode) var presentationMode
    @State private var showingResetConfirmation = false
    @State private var showingChangelog = false
    @State private var showingFeedbackMail = false
    @State private var showingFeatureMail = false
    @State private var showingDiscordWebView = false
    @State private var showingPlacementPrecisionInfo = false
    @State private var showingBlockDragInfo = false
    @State private var showingTestFlightAlert = false
    @State private var showingTestFlightWebView = false
    
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
                
                Section(header: Text("Gameplay Settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Placement Precision")
                            Button(action: {
                                showingPlacementPrecisionInfo = true
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                            Text("\(Int((1 - placementPrecision) * 100))%")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Image(systemName: "hand.tap")
                            Slider(value: $placementPrecision, in: 0.05...0.3)
                            Image(systemName: "hand.tap.fill")
                        }
                        HStack {
                            Text("Lower = More Precise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Reset") {
                                placementPrecision = 0.15
                            }
                            .font(.caption)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Block Drag Position")
                            Button(action: {
                                showingBlockDragInfo = true
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                            Text("\(Int(blockDragOffset * 100))%")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Image(systemName: "hand.point.up")
                            Slider(value: $blockDragOffset, in: 0.0...2.0)
                            Image(systemName: "hand.point.up.fill")
                        }
                        HStack {
                            Text("Higher = Block Above Finger")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Reset") {
                                blockDragOffset = 0.4
                            }
                            .font(.caption)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Section(header: Text("Game Mode Rules")) {
                    NavigationLink(destination: GameRulesView(gameMode: "Classic")) {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundColor(.blue)
                            Text("Classic")
                            Spacer()
                            Text("Current")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
                        Text("Note: For optimal sound experience, ensure your device's ringer volume is turned up and not muted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                
                Section(header: Text("Data Management")) {
                    Button("Reset Game Data") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("Information")) {
                    NavigationLink(destination: ChangelogView()) {
                        Text("Changelog")
                    }
                    
                    Button("Join the Discord") {
                        showingDiscordWebView = true
                    }
                    
                    Button("Test New Features") {
                        showingTestFlightAlert = true
                    }
                    
                    Button("Send Feedback") {
                        showingFeedbackMail = true
                    }
                    
                    Button("Suggest a Feature") {
                        showingFeatureMail = true
                    }
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Allow anonymous usage analytics", isOn: $allowAnalytics)
                    Toggle("Allow data sharing for app features", isOn: $allowDataSharing)
                }
                
                Section(header: Text("Notifications")) {
                    NavigationLink(destination: NotificationPreferencesView()) {
                        Text("Notification Preferences")
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
            .alert("Placement Precision", isPresented: $showingPlacementPrecisionInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Controls how precisely you need to place blocks on the grid. Lower values require more precise placement, while higher values are more forgiving.")
            }
            .alert("Block Drag Position", isPresented: $showingBlockDragInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Controls how high above your finger the block appears while dragging. Higher values make it easier to see where you're placing the block, while lower values keep it closer to your finger.")
            }
            .sheet(isPresented: $showingFeedbackMail) {
                MailView(isShowing: $showingFeedbackMail, recipient: "support@infinitumlive.com", subject: "Infinitum Block Smash Feedback")
            }
            .sheet(isPresented: $showingFeatureMail) {
                MailView(isShowing: $showingFeatureMail, recipient: "jrftw@infinitumlive.com", subject: "Infinitum Block Smash Feature Suggestion")
            }
            .sheet(isPresented: $showingDiscordWebView) {
                SafariView(url: URL(string: "https://discord.gg/8xx4QzceRA")!)
            }
            .alert("Test New Features", isPresented: $showingTestFlightAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Join TestFlight") {
                    showingTestFlightWebView = true
                }
            } message: {
                Text("Join our TestFlight program to experience upcoming features before they're released. Your feedback helps us improve the game and ensure the highest quality experience for all players.")
            }
            .sheet(isPresented: $showingTestFlightWebView) {
                SafariView(url: URL(string: "https://testflight.apple.com/join/nd4DWxbT")!)
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
    
    private func openDiscord() {
        let discordURL = URL(string: "discord://discord.com/invite/8xx4QzceRA")!
        let appStoreURL = URL(string: "https://apps.apple.com/app/discord/id985746746")!
        
        if UIApplication.shared.canOpenURL(discordURL) {
            UIApplication.shared.open(discordURL)
        } else {
            UIApplication.shared.open(appStoreURL)
        }
    }
}

struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    let recipient: String
    let subject: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isShowing: $isShowing)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isShowing: Bool
        
        init(isShowing: Binding<Bool>) {
            _isShowing = isShowing
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isShowing = false
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safariVC = SFSafariViewController(url: url, configuration: config)
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
    }
} 