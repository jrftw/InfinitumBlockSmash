import Foundation
import StoreKit
import SwiftUI

class VersionCheckService {
    static let shared = VersionCheckService()
    
    private init() {}
    
    // Add a property to track if update is required
    private(set) var isUpdateRequired = false
    
    func checkForUpdates() {
        if ForcePublicVersion.shared.isEnabled {
            // If force public version is enabled, show the public version prompt
            ForcePublicVersion.shared.showUpdatePrompt()
        } else {
            // Otherwise, check for the latest version (beta or public)
            if isTestFlight() {
                checkTestFlightVersion()
            } else {
                checkPublicVersion()
            }
        }
    }
    
    func isTestFlight() -> Bool {
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
    
    private func checkTestFlightVersion() {
        // Get the current app version
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return
        }
        
        // Get the TestFlight version info
        guard let testFlightURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Bundle.main.bundleIdentifier ?? "")&platform=ios&t=\(Date().timeIntervalSince1970)") else {
            Logger.shared.log("Failed to create TestFlight URL", category: .systemNetwork, level: .error)
            return
        }
        
        URLSession.shared.dataTask(with: testFlightURL) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let testFlightVersion = results.first?["version"] as? String,
                  let testFlightBuild = results.first?["buildNumber"] as? String else {
                return
            }
            
            // Compare versions and builds
            if self.compareVersions(currentVersion, testFlightVersion) == .orderedAscending ||
               (currentVersion == testFlightVersion && self.compareVersions(currentBuild, testFlightBuild) == .orderedAscending) {
                DispatchQueue.main.async {
                    self.isUpdateRequired = true
                    self.showUpdatePrompt(isTestFlight: true)
                }
            }
        }.resume()
    }
    
    private func checkPublicVersion() {
        // Get the current app version
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return
        }
        
        // Get the App Store version
        guard let appStoreURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Bundle.main.bundleIdentifier ?? "")") else {
            Logger.shared.log("Failed to create App Store URL", category: .systemNetwork, level: .error)
            return
        }
        
        URLSession.shared.dataTask(with: appStoreURL) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let appStoreVersion = results.first?["version"] as? String,
                  let appStoreBuild = results.first?["buildNumber"] as? String else {
                return
            }
            
            // Compare versions and builds
            if self.compareVersions(currentVersion, appStoreVersion) == .orderedAscending ||
               (currentVersion == appStoreVersion && self.compareVersions(currentBuild, appStoreBuild) == .orderedAscending) {
                DispatchQueue.main.async {
                    self.isUpdateRequired = true
                    self.showUpdatePrompt(isTestFlight: false)
                }
            }
        }.resume()
    }
    
    private func showUpdatePrompt(isTestFlight: Bool) {
        // Create a blocking window for the update prompt
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            Logger.shared.log("No window scene available for update prompt", category: .general, level: .error)
            return
        }
        
        let updateWindow = UIWindow(windowScene: windowScene)
        updateWindow.windowLevel = .alert + 1
        
        // Create the update view
        let updateView = UpdatePromptView(isTestFlight: isTestFlight)
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
}

struct UpdatePromptView: View {
    let isTestFlight: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text(isTestFlight ? "New Beta Available" : "Update Required")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(isTestFlight ? 
                    "A new beta version is available. Please update to continue testing." :
                    "A new version is available. Please update to continue using the app.")
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
                        .background(Color.blue)
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