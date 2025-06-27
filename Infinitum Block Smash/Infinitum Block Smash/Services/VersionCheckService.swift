import Foundation
import StoreKit
import SwiftUI
import FirebaseRemoteConfig

class VersionCheckService: ObservableObject {
    static let shared = VersionCheckService()
    
    private init() {
        setupRemoteConfig()
        loadCachedUpdateData()
    }
    
    // MARK: - Properties
    @Published private(set) var isUpdateRequired = false
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var lastCheckDate: Date?
    
    private var updateCheckTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 5.0
    
    // MARK: - Remote Configuration
    private let remoteConfig = RemoteConfig.remoteConfig()
    private let forceUpdateKey = "force_update_enabled"
    private let minVersionKey = "minimum_required_version"
    private let updateCheckIntervalKey = "update_check_interval_hours"
    private let emergencyUpdateKey = "emergency_update_required"
    
    // MARK: - Cached Data
    private let userDefaults = UserDefaults.standard
    private let lastUpdateCheckKey = "lastUpdateCheckDate"
    private let cachedUpdateDataKey = "cachedUpdateData"
    private let updateCheckInterval: TimeInterval = 3600 // 1 hour default
    
    // MARK: - Public Methods
    func checkForUpdates() {
        // Don't check if already checking
        guard !isCheckingForUpdates else { return }
        
        // Check if we should skip based on interval
        if shouldSkipUpdateCheck() {
            Logger.shared.log("Skipping update check - too soon since last check", category: .systemNetwork, level: .info)
            return
        }
        
        isCheckingForUpdates = true
        retryCount = 0
        
        // First check remote config for emergency updates
        checkRemoteConfigForUpdates { [weak self] in
            self?.performVersionCheck()
        }
    }
    
    func forceUpdateCheck() {
        retryCount = 0
        performVersionCheck()
    }
    
    func isTestFlight() -> Bool {
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
    
    // MARK: - Private Methods
    
    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        // Set default values
        remoteConfig.setDefaults([
            forceUpdateKey: false as NSObject,
            minVersionKey: AppVersion.version as NSObject,
            updateCheckIntervalKey: 1 as NSObject,
            emergencyUpdateKey: false as NSObject
        ])
        
        // Fetch remote config
        remoteConfig.fetch { [weak self] status, error in
            if let error = error {
                Logger.shared.log("Remote config fetch failed: \(error.localizedDescription)", category: .firebaseRemoteConfig, level: .error)
            } else {
                Logger.shared.log("Remote config fetched successfully", category: .firebaseRemoteConfig, level: .info)
                self?.remoteConfig.activate()
            }
        }
    }
    
    private func checkRemoteConfigForUpdates(completion: @escaping () -> Void) {
        let forceUpdate = remoteConfig.configValue(forKey: forceUpdateKey).boolValue
        let emergencyUpdate = remoteConfig.configValue(forKey: emergencyUpdateKey).boolValue
        let minVersion = remoteConfig.configValue(forKey: minVersionKey).stringValue
        
        // Check if emergency update is required
        if emergencyUpdate {
            Logger.shared.log("Emergency update required via remote config", category: .systemNetwork, level: .warning)
            DispatchQueue.main.async {
                self.isUpdateRequired = true
                self.showUpdatePrompt(isTestFlight: self.isTestFlight(), isEmergency: true)
            }
            return
        }
        
        // Check if current version meets minimum requirement
        if compareVersions(AppVersion.version, minVersion) == .orderedAscending {
            Logger.shared.log("Current version \(AppVersion.version) below minimum required \(minVersion)", category: .systemNetwork, level: .warning)
            DispatchQueue.main.async {
                self.isUpdateRequired = true
                self.showUpdatePrompt(isTestFlight: self.isTestFlight(), isEmergency: false)
            }
            return
        }
        
        // If force update is enabled via remote config
        if forceUpdate {
            Logger.shared.log("Force update enabled via remote config", category: .systemNetwork, level: .info)
            DispatchQueue.main.async {
                self.isUpdateRequired = true
                self.showUpdatePrompt(isTestFlight: self.isTestFlight(), isEmergency: false)
            }
            return
        }
        
        completion()
    }
    
    private func performVersionCheck() {
        if ForcePublicVersion.shared.isEnabled {
            Logger.shared.log("Force public version enabled, showing public version prompt", category: .systemNetwork, level: .info)
            DispatchQueue.main.async {
                self.isUpdateRequired = true
                ForcePublicVersion.shared.showUpdatePrompt()
            }
            return
        }
        
        if isTestFlight() {
            checkTestFlightVersion()
        } else {
            checkPublicVersion()
        }
    }
    
    private func checkTestFlightVersion() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            handleUpdateCheckError("Failed to get current version info")
            return
        }
        
        // Try cached data first
        if let cachedData = getCachedUpdateData(),
           let testFlightVersion = cachedData["testFlightVersion"] as? String,
           let testFlightBuild = cachedData["testFlightBuild"] as? String {
            
            if shouldUpdate(currentVersion: currentVersion, currentBuild: currentBuild,
                          latestVersion: testFlightVersion, latestBuild: testFlightBuild) {
                DispatchQueue.main.async {
                    self.isUpdateRequired = true
                    self.showUpdatePrompt(isTestFlight: true, isEmergency: false)
                }
                return
            }
        }
        
        // Fetch fresh data
        fetchTestFlightVersion(currentVersion: currentVersion, currentBuild: currentBuild)
    }
    
    private func checkPublicVersion() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            handleUpdateCheckError("Failed to get current version info")
            return
        }
        
        // Try cached data first
        if let cachedData = getCachedUpdateData(),
           let appStoreVersion = cachedData["appStoreVersion"] as? String,
           let appStoreBuild = cachedData["appStoreBuild"] as? String {
            
            if shouldUpdate(currentVersion: currentVersion, currentBuild: currentBuild,
                          latestVersion: appStoreVersion, latestBuild: appStoreBuild) {
                DispatchQueue.main.async {
                    self.isUpdateRequired = true
                    self.showUpdatePrompt(isTestFlight: false, isEmergency: false)
                }
                return
            }
        }
        
        // Fetch fresh data
        fetchAppStoreVersion(currentVersion: currentVersion, currentBuild: currentBuild)
    }
    
    private func fetchTestFlightVersion(currentVersion: String, currentBuild: String) {
        guard let testFlightURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Bundle.main.bundleIdentifier ?? "")&platform=ios&t=\(Date().timeIntervalSince1970)") else {
            handleUpdateCheckError("Failed to create TestFlight URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: testFlightURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleUpdateCheckError("Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                self.handleUpdateCheckError("No data received")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let results = json?["results"] as? [[String: Any]],
                      let testFlightVersion = results.first?["version"] as? String,
                      let testFlightBuild = results.first?["buildNumber"] as? String else {
                    self.handleUpdateCheckError("Invalid response format")
                    return
                }
                
                // Cache the data
                self.cacheUpdateData([
                    "testFlightVersion": testFlightVersion,
                    "testFlightBuild": testFlightBuild,
                    "lastCheck": Date()
                ])
                
                if self.shouldUpdate(currentVersion: currentVersion, currentBuild: currentBuild,
                                   latestVersion: testFlightVersion, latestBuild: testFlightBuild) {
                    DispatchQueue.main.async {
                        self.isUpdateRequired = true
                        self.showUpdatePrompt(isTestFlight: true, isEmergency: false)
                    }
                }
                
                self.completeUpdateCheck()
                
            } catch {
                self.handleUpdateCheckError("JSON parsing error: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    private func fetchAppStoreVersion(currentVersion: String, currentBuild: String) {
        guard let appStoreURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Bundle.main.bundleIdentifier ?? "")") else {
            handleUpdateCheckError("Failed to create App Store URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: appStoreURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleUpdateCheckError("Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                self.handleUpdateCheckError("No data received")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let results = json?["results"] as? [[String: Any]],
                      let appStoreVersion = results.first?["version"] as? String,
                      let appStoreBuild = results.first?["buildNumber"] as? String else {
                    self.handleUpdateCheckError("Invalid response format")
                    return
                }
                
                // Cache the data
                self.cacheUpdateData([
                    "appStoreVersion": appStoreVersion,
                    "appStoreBuild": appStoreBuild,
                    "lastCheck": Date()
                ])
                
                if self.shouldUpdate(currentVersion: currentVersion, currentBuild: currentBuild,
                                   latestVersion: appStoreVersion, latestBuild: appStoreBuild) {
                    DispatchQueue.main.async {
                        self.isUpdateRequired = true
                        self.showUpdatePrompt(isTestFlight: false, isEmergency: false)
                    }
                }
                
                self.completeUpdateCheck()
                
            } catch {
                self.handleUpdateCheckError("JSON parsing error: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    private func shouldUpdate(currentVersion: String, currentBuild: String, latestVersion: String, latestBuild: String) -> Bool {
        // Compare versions first
        let versionComparison = compareVersions(currentVersion, latestVersion)
        
        if versionComparison == .orderedAscending {
            return true
        }
        
        // If versions are equal, compare build numbers
        if versionComparison == .orderedSame {
            return compareVersions(currentBuild, latestBuild) == .orderedAscending
        }
        
        return false
    }
    
    private func handleUpdateCheckError(_ error: String) {
        Logger.shared.log("Update check error: \(error)", category: .systemNetwork, level: .error)
        
        retryCount += 1
        
        if retryCount < maxRetries {
            Logger.shared.log("Retrying update check (\(retryCount)/\(maxRetries))", category: .systemNetwork, level: .info)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay * Double(retryCount)) { [weak self] in
                self?.performVersionCheck()
            }
        } else {
            Logger.shared.log("Max retries reached, falling back to cached data", category: .systemNetwork, level: .warning)
            completeUpdateCheck()
        }
    }
    
    private func completeUpdateCheck() {
        DispatchQueue.main.async { [weak self] in
            self?.isCheckingForUpdates = false
            self?.lastCheckDate = Date()
            self?.userDefaults.set(Date(), forKey: self?.lastUpdateCheckKey ?? "")
        }
    }
    
    private func shouldSkipUpdateCheck() -> Bool {
        guard let lastCheck = userDefaults.object(forKey: lastUpdateCheckKey) as? Date else {
            return false
        }
        
        let interval = remoteConfig.configValue(forKey: updateCheckIntervalKey).numberValue.doubleValue * 3600 // Convert hours to seconds
        return Date().timeIntervalSince(lastCheck) < interval
    }
    
    private func showUpdatePrompt(isTestFlight: Bool, isEmergency: Bool) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            Logger.shared.log("No window scene available for update prompt", category: .general, level: .error)
            return
        }
        
        let updateWindow = UIWindow(windowScene: windowScene)
        updateWindow.windowLevel = .alert + 1
        
        let updateView = UpdatePromptView(isTestFlight: isTestFlight, isEmergency: isEmergency)
        let hostingController = UIHostingController(rootView: updateView)
        hostingController.view.backgroundColor = .clear
        
        updateWindow.rootViewController = hostingController
        updateWindow.makeKeyAndVisible()
        
        // Store the window to prevent it from being deallocated
        objc_setAssociatedObject(UIApplication.shared, "updateWindow", updateWindow, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        return version1.compare(version2, options: .numeric)
    }
    
    // MARK: - Caching Methods
    
    private func cacheUpdateData(_ data: [String: Any]) {
        userDefaults.set(data, forKey: cachedUpdateDataKey)
    }
    
    private func getCachedUpdateData() -> [String: Any]? {
        return userDefaults.object(forKey: cachedUpdateDataKey) as? [String: Any]
    }
    
    private func loadCachedUpdateData() {
        if let cachedData = getCachedUpdateData(),
           let lastCheck = cachedData["lastCheck"] as? Date {
            lastCheckDate = lastCheck
        }
    }
    
    // MARK: - Public Utility Methods
    
    func clearCache() {
        userDefaults.removeObject(forKey: cachedUpdateDataKey)
        userDefaults.removeObject(forKey: lastUpdateCheckKey)
    }
    
    func getUpdateStatus() -> String {
        if isUpdateRequired {
            return "Update Required"
        } else if isCheckingForUpdates {
            return "Checking for Updates..."
        } else {
            return "Up to Date"
        }
    }
}

struct UpdatePromptView: View {
    let isTestFlight: Bool
    let isEmergency: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: isEmergency ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isEmergency ? .red : .blue)
                
                Text(isEmergency ? "Emergency Update Required" : (isTestFlight ? "New Beta Available" : "Update Required"))
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(isEmergency ? 
                    "A critical update is required for security and stability. Please update immediately." :
                    (isTestFlight ? 
                        "A new beta version is available. Please update to continue testing." :
                        "A new version is available. Please update to continue using the app."))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    if isTestFlight {
                        if let url = URL(string: "itms-beta://") {
                            UIApplication.shared.open(url)
                        }
                    } else {
                        if let url = URL(string: "itms-apps://itunes.apple.com/app/id6746708231") {
                            UIApplication.shared.open(url)
                        }
                    }
                }) {
                    Text("Update Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEmergency ? Color.red : Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }
} 