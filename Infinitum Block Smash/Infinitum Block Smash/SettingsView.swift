import SwiftUI
import AppTrackingTransparency
import MessageUI
import SafariServices

// MARK: - Theme Management
private func updateTheme(_ theme: String) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return }
    
    // Use ThemeManager to set the theme
    ThemeManager.shared.setTheme(theme)
    
    // Update the window's interface style
    switch theme {
    case "light":
        window.overrideUserInterfaceStyle = .light
    case "dark":
        window.overrideUserInterfaceStyle = .dark
    case "auto":
        window.overrideUserInterfaceStyle = .unspecified
    default:
        window.overrideUserInterfaceStyle = .unspecified
    }
}

// MARK: - Subviews
private struct GameSettingsSection: View {
    @Binding var theme: String
    @Binding var showTutorial: Bool
    @Binding var autoSave: Bool
    @ObservedObject var fpsManager: FPSManager
    @ObservedObject var gameState: GameState
    @Binding var showingStore: Bool
    let themes: [String]
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var hasEliteAccess = false
    @State private var unlockedThemes: Set<String> = []
    @AppStorage("selectedLanguage") private var selectedLanguage = Locale.current.languageCode ?? "en"
    @State private var systemTheme: String = UserDefaults.standard.string(forKey: "systemTheme") ?? "auto"
    
    private let availableLanguages = [
        ("en", "English"),
        ("es", "Español"),
        ("zh-Hans", "简体中文"),
        ("hi", "हिन्दी"),
        ("ar", "العربية"),
        ("bn", "বাংলা"),
        ("pt", "Português"),
        ("ru", "Русский"),
        ("ja", "日本語"),
        ("pa", "ਪੰਜਾਬੀ"),
        ("fr", "Français"),
        ("de", "Deutsch")
    ]
    
    private var fpsBinding: Binding<Int> {
        Binding(
            get: { fpsManager.targetFPS },
            set: { newValue in
                fpsManager.setTargetFPS(newValue)
                gameState.targetFPS = fpsManager.getDisplayFPS(for: newValue)
            }
        )
    }
    
    private func isThemeUnlocked(_ themeKey: String) -> Bool {
        if themeKey == "system" || ["light", "dark", "auto"].contains(themeKey) {
            return true
        }
        return unlockedThemes.contains(themeKey)
    }
    
    var body: some View {
        Section(header: Text(NSLocalizedString("Game Settings", comment: "Settings section header"))) {
            // Language Picker
            Picker(NSLocalizedString("Language", comment: "Language picker label"), selection: $selectedLanguage) {
                ForEach(availableLanguages, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
            .onChange(of: selectedLanguage) { newValue in
                // Update the app's language
                UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                UserDefaults.standard.synchronize()
                
                // Show alert to restart app
                let alert = UIAlertController(
                    title: NSLocalizedString("Language Changed", comment: "Language change alert title"),
                    message: NSLocalizedString("Please restart the app for the language change to take effect.", comment: "Language change alert message"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(
                    title: NSLocalizedString("OK", comment: "OK button"),
                    style: .default
                ))
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let viewController = windowScene.windows.first?.rootViewController {
                    viewController.present(alert, animated: true)
                }
            }
            
            // Unified Theme Picker
            Picker(NSLocalizedString("Theme", comment: "Theme picker label"), selection: $theme) {
                // System themes
                Text(NSLocalizedString("Auto", comment: "Auto theme option")).tag("auto")
                Text(NSLocalizedString("Light", comment: "Light theme option")).tag("light")
                Text(NSLocalizedString("Dark", comment: "Dark theme option")).tag("dark")
                // Custom themes
                ForEach(Array(themeManager.getAvailableThemes().keys.sorted().filter { !["system", "light", "dark", "auto"].contains($0) }), id: \.self) { themeKey in
                    if let themeObj = themeManager.getAvailableThemes()[themeKey] {
                        let unlocked = isThemeUnlocked(themeKey)
                        HStack {
                            Text(themeObj.name)
                                .foregroundColor(unlocked ? .primary : .secondary)
                            if !unlocked {
                                Text(NSLocalizedString("Locked", comment: "Locked theme indicator"))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .tag(themeKey)
                        .disabled(!unlocked)
                    }
                }
            }
            .onChange(of: theme) { newValue in
                if !["light", "dark", "auto"].contains(newValue) {
                    if isThemeUnlocked(newValue) {
                        themeManager.setTheme(newValue)
                    } else {
                        // Reset to previous theme
                        theme = themeManager.currentTheme
                        // Show store
                        showingStore = true
                    }
                } else {
                    themeManager.setTheme(newValue)
                }
            }
            
            Picker(NSLocalizedString("Target FPS", comment: "FPS picker label"), selection: fpsBinding) {
                ForEach(fpsManager.availableFPSOptions, id: \.self) { fps in
                    Text(fpsManager.getFPSDisplayName(for: fps))
                        .tag(fps)
                }
            }
            
            Toggle(NSLocalizedString("Show Tutorial", comment: "Tutorial toggle label"), isOn: $showTutorial)
            Toggle(NSLocalizedString("Auto Save", comment: "Auto save toggle label"), isOn: $autoSave)
        }
        .task {
            // Load initial state
            hasEliteAccess = await subscriptionManager.hasFeature(.allThemes)
            
            // Load unlocked themes
            var unlocked: Set<String> = []
            for themeKey in themeManager.getAvailableThemes().keys {
                if await subscriptionManager.isThemeUnlocked(themeKey) {
                    unlocked.insert(themeKey)
                }
            }
            unlockedThemes = unlocked
        }
    }
}

private struct GameplaySettingsSection: View {
    @Binding var placementPrecision: Double
    @Binding var blockDragOffset: Double
    @Binding var showingPlacementPrecisionInfo: Bool
    @Binding var showingBlockDragInfo: Bool
    
    var body: some View {
        Section(header: Text(NSLocalizedString("Gameplay Settings", comment: "Gameplay settings section header"))) {
            PlacementPrecisionView(
                placementPrecision: $placementPrecision,
                showingInfo: $showingPlacementPrecisionInfo
            )
            
            BlockDragView(
                blockDragOffset: $blockDragOffset,
                showingInfo: $showingBlockDragInfo
            )
        }
    }
}

private struct PlacementPrecisionView: View {
    @Binding var placementPrecision: Double
    @Binding var showingInfo: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("Placement Precision", comment: "Placement precision label"))
                Button(action: { showingInfo = true }) {
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
                Text(NSLocalizedString("Lower = More Precise", comment: "Placement precision description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(NSLocalizedString("Reset", comment: "Reset button label")) {
                    placementPrecision = 0.15
                }
                .font(.caption)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

private struct BlockDragView: View {
    @Binding var blockDragOffset: Double
    @Binding var showingInfo: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("Block Drag Position", comment: "Block drag position label"))
                Button(action: { showingInfo = true }) {
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
                Text(NSLocalizedString("Higher = Block Above Finger", comment: "Block drag position description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(NSLocalizedString("Reset", comment: "Reset button label")) {
                    blockDragOffset = 0.4
                }
                .font(.caption)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

private struct AudioSettingsSection: View {
    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var musicVolume: Double
    @Binding var sfxVolume: Double
    
    var body: some View {
        Section(header: Text("Audio Settings")) {
            Toggle("Sound Effects", isOn: $soundEnabled)
            Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            
            VolumeControlView(title: "Music Volume", volume: $musicVolume)
            VolumeControlView(title: "SFX Volume", volume: $sfxVolume)
        }
    }
}

private struct VolumeControlView: View {
    let title: String
    @Binding var volume: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
            }
            if title == "SFX Volume" {
                Text("Note: For optimal sound experience, ensure your device's ringer volume is turned up and not muted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct StatsForNerdsSection: View {
    @ObservedObject var gameState: GameState
    @StateObject private var fpsManager = FPSManager.shared
    @AppStorage("showStatsOverlay") private var showStatsOverlay = false
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("showMemory") private var showMemory = false
    
    var body: some View {
        Section(header: Text("Stats for Nerds")) {
            Toggle("Show Stats Overlay", isOn: $showStatsOverlay)
            
            if showStatsOverlay {
                Toggle("Show FPS", isOn: $showFPS)
                Toggle("Show Memory Usage", isOn: $showMemory)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current FPS: \(fpsManager.getDisplayFPS(for: fpsManager.targetFPS))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Target FPS: \(fpsManager.getFPSDisplayName(for: fpsManager.targetFPS))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let (hits, misses) = MemorySystem.shared.getCacheStats()
                    Text("Cache Stats: \(hits) hits, \(misses) misses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Main View
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
    @StateObject private var fpsManager = FPSManager.shared
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
    @State private var showingStore = false
    @AppStorage("forceUpdateEnabled") private var forceUpdateEnabled = false
    @AppStorage("autoSyncEnabled") private var autoSyncEnabled = true
    @State private var showingAnalytics = false
    @AppStorage("showStatsOverlay") private var showStatsOverlay = false
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("showMemory") private var showMemory = false
    
    private let difficulties = ["easy", "normal", "hard", "expert"]
    private let themes = ["light", "dark", "auto"]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showingStore = true }) {
                        HStack {
                            Image(systemName: "cart.fill")
                                .foregroundColor(.blue)
                            Text("Store")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        ReferralView()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.green)
                            Text("Refer Friends")
                            Spacer()
                        }
                    }
                }
                
                GameSettingsSection(
                    theme: $theme,
                    showTutorial: $showTutorial,
                    autoSave: $autoSave,
                    fpsManager: fpsManager,
                    gameState: gameState,
                    showingStore: $showingStore,
                    themes: themes
                )
                
                GameplaySettingsSection(
                    placementPrecision: $placementPrecision,
                    blockDragOffset: $blockDragOffset,
                    showingPlacementPrecisionInfo: $showingPlacementPrecisionInfo,
                    showingBlockDragInfo: $showingBlockDragInfo
                )
                
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
                
                AudioSettingsSection(
                    soundEnabled: $soundEnabled,
                    hapticsEnabled: $hapticsEnabled,
                    musicVolume: $musicVolume,
                    sfxVolume: $sfxVolume
                )
                .onChange(of: soundEnabled) { newValue in
                    AudioManager.shared.updateSettings(soundEnabled: newValue, musicVolume: musicVolume, sfxVolume: sfxVolume)
                }
                .onChange(of: musicVolume) { newValue in
                    AudioManager.shared.updateSettings(soundEnabled: soundEnabled, musicVolume: newValue, sfxVolume: sfxVolume)
                }
                .onChange(of: sfxVolume) { newValue in
                    AudioManager.shared.updateSettings(soundEnabled: soundEnabled, musicVolume: musicVolume, sfxVolume: newValue)
                }
                .onChange(of: hapticsEnabled) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "hapticsEnabled")
                    UserDefaults.standard.synchronize()
                }
                
                Section(header: Text("Game Progress")) {
                    HStack {
                        Text("High Score")
                        Spacer()
                        Text("\(gameState.highScore)")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Highest Level")
                        Spacer()
                        Text("\(gameState.highestLevel)")
                            .foregroundColor(.blue)
                    }
                }
                
                StatsForNerdsSection(gameState: gameState)
                
                Section(header: Text("Data Management")) {
                    Toggle("Auto Sync Data", isOn: $autoSyncEnabled)
                    
                    Button("Reset Game Data") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("Information")) {
                    NavigationLink(destination: ChangelogView()) {
                        Text("Changelog")
                    }
                    
                    NavigationLink(destination: EULAView()) {
                        Text("End User License Agreement")
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
                
                Section(header: Text("Update Settings")) {
                    Toggle("Force Public Version", isOn: Binding(
                        get: { ForcePublicVersion.shared.isEnabled },
                        set: { ForcePublicVersion.shared.isEnabled = $0 }
                    ))
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Allow anonymous usage analytics", isOn: $allowAnalytics)
                    Toggle("Allow data sharing for app features", isOn: $allowDataSharing)
                    Button("View Analytics Dashboard") {
                        showingAnalytics = true
                    }
                }
                
                Section {
                    VStack(spacing: 8) {
                        Text(AppVersion.formattedVersion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(AppVersion.copyright)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(AppVersion.credits)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(AppVersion.location)
                            .font(.caption2)
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
                        dismiss()
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
            .sheet(isPresented: $showingStore) {
                StoreView()
            }
            .sheet(isPresented: $showingAnalytics) {
                NavigationView {
                    AnalyticsDashboardView()
                }
            }
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