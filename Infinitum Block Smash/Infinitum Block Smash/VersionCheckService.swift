import Foundation
import StoreKit

class VersionCheckService {
    static let shared = VersionCheckService()
    
    private init() {}
    
    func checkForUpdates() {
        #if DEBUG
        // In debug/simulator, check for updates just like in production
        checkAppStoreUpdate()
        #else
        if isTestFlight() {
            // In TestFlight, check for beta updates
            checkTestFlightUpdate()
        } else {
            // In production, check for App Store updates
            checkAppStoreUpdate()
        }
        #endif
    }
    
    private func isTestFlight() -> Bool {
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
    
    private func checkTestFlightUpdate() {
        // For TestFlight, we'll check if there's a new version available
        // by comparing the current version with the latest TestFlight version
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return
        }
        
        // Get the TestFlight version info
        let testFlightURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Bundle.main.bundleIdentifier ?? "")&platform=ios&t=\(Date().timeIntervalSince1970)")!
        
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
                    self.showUpdatePrompt(isTestFlight: true)
                }
            }
        }.resume()
    }
    
    private func checkAppStoreUpdate() {
        // Get the current app version
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }
        
        // Get the App Store version
        let appStoreURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Bundle.main.bundleIdentifier ?? "")")!
        
        URLSession.shared.dataTask(with: appStoreURL) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let appStoreVersion = results.first?["version"] as? String else {
                return
            }
            
            // Compare versions
            if self.compareVersions(currentVersion, appStoreVersion) == .orderedAscending {
                DispatchQueue.main.async {
                    self.showUpdatePrompt(isTestFlight: false)
                }
            }
        }.resume()
    }
    
    private func showUpdatePrompt(isTestFlight: Bool) {
        let alert = UIAlertController(
            title: isTestFlight ? "New Beta Available" : "Update Available",
            message: isTestFlight ? "A new beta version is available. Please update to continue testing." : "A new version is available. Please update to continue playing.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            if isTestFlight {
                // Open TestFlight
                if let url = URL(string: "itms-beta://") {
                    UIApplication.shared.open(url)
                }
            } else {
                // Open App Store
                if let url = URL(string: "itms-apps://itunes.apple.com/app/id6746708231") {
                    UIApplication.shared.open(url)
                }
            }
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        return version1.compare(version2, options: .numeric)
    }
} 