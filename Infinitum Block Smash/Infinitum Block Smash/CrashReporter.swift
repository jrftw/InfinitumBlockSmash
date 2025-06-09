import Foundation
import FirebaseCrashlytics
import UIKit
import FirebaseAuth

class CrashReporter {
    static let shared = CrashReporter()
    
    private init() {
        // Set default value for allowCrashReports if not set
        if UserDefaults.standard.object(forKey: "allowCrashReports") == nil {
            UserDefaults.standard.set(true, forKey: "allowCrashReports")
        }
    }
    
    func log(_ message: String) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        Crashlytics.crashlytics().log(message)
    }
    
    func setUserIdentifier(_ userId: String) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        Crashlytics.crashlytics().setUserID(userId)
    }
    
    func setCustomValue(_ value: Any, forKey key: String) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
    
    func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }
    
    func forceCrash() {
        guard UserDefaults.standard.bool(forKey: "allowCrashReports") else { return }
        fatalError("Forced crash for testing")
    }
    
    func getCrashReport() -> String {
        // Get the last crash report if available
        var report = "No crash report available"
        
        // Add device information
        let device = UIDevice.current
        report += "\n\nDevice Information:"
        report += "\nModel: \(device.model)"
        report += "\nSystem Version: \(device.systemVersion)"
        report += "\nApp Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
        
        // Add user information if available
        if let userId = Auth.auth().currentUser?.uid {
            report += "\n\nUser Information:"
            report += "\nUser ID: \(userId)"
        }
        
        return report
    }
} 