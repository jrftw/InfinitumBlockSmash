import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCrashlytics

enum SecurityEventType: String {
    case authentication = "authentication"
    case dataAccess = "data_access"
    case dataModification = "data_modification"
    case rateLimitExceeded = "rate_limit_exceeded"
    case suspiciousActivity = "suspicious_activity"
    case backupOperation = "backup_operation"
    case restoreOperation = "restore_operation"
    case securityRuleViolation = "security_rule_violation"
}

struct SecurityEvent {
    let type: SecurityEventType
    let userId: String?
    let timestamp: Date
    let details: [String: Any]
    let severity: Int // 1-5, where 5 is most severe
    let ipAddress: String?
    let deviceInfo: [String: String]
}

class SecurityLogger {
    static let shared = SecurityLogger()
    private let db = Firestore.firestore()
    private let securityLogsCollection = "security_logs"
    
    private init() {}
    
    func logEvent(_ event: SecurityEvent) {
        // Log to Firestore
        let logData: [String: Any] = [
            "type": event.type.rawValue,
            "userId": event.userId ?? "anonymous",
            "timestamp": event.timestamp,
            "details": event.details,
            "severity": event.severity,
            "ipAddress": event.ipAddress ?? "unknown",
            "deviceInfo": event.deviceInfo
        ]
        
        db.collection(securityLogsCollection).addDocument(data: logData) { error in
            if let error = error {
                print("Error logging security event: \(error)")
            }
        }
        
        // Log to Crashlytics for high severity events
        if event.severity >= 4 {
            Crashlytics.crashlytics().log("Security Event: \(event.type.rawValue) - Severity: \(event.severity)")
            Crashlytics.crashlytics().setCustomValue(event.details, forKey: "security_event_details")
        }
        
        // Print to console in development
        #if DEBUG
        print("Security Event: \(event.type.rawValue)")
        print("Details: \(event.details)")
        print("Severity: \(event.severity)")
        #endif
    }
    
    // Convenience methods for common security events
    
    func logAuthenticationEvent(userId: String, success: Bool, method: String, details: [String: Any] = [:]) {
        let event = SecurityEvent(
            type: .authentication,
            userId: userId,
            timestamp: Date(),
            details: [
                "success": success,
                "method": method,
                "details": details
            ],
            severity: success ? 1 : 3,
            ipAddress: getCurrentIPAddress(),
            deviceInfo: getDeviceInfo()
        )
        logEvent(event)
    }
    
    func logDataAccessEvent(userId: String, collection: String, documentId: String, success: Bool) {
        let event = SecurityEvent(
            type: .dataAccess,
            userId: userId,
            timestamp: Date(),
            details: [
                "collection": collection,
                "documentId": documentId,
                "success": success
            ],
            severity: success ? 1 : 2,
            ipAddress: getCurrentIPAddress(),
            deviceInfo: getDeviceInfo()
        )
        logEvent(event)
    }
    
    func logRateLimitExceeded(userId: String, endpoint: String, limit: Int, window: Int) {
        let event = SecurityEvent(
            type: .rateLimitExceeded,
            userId: userId,
            timestamp: Date(),
            details: [
                "endpoint": endpoint,
                "limit": limit,
                "window": window
            ],
            severity: 3,
            ipAddress: getCurrentIPAddress(),
            deviceInfo: getDeviceInfo()
        )
        logEvent(event)
    }
    
    func logSuspiciousActivity(userId: String?, activity: String, details: [String: Any]) {
        let event = SecurityEvent(
            type: .suspiciousActivity,
            userId: userId,
            timestamp: Date(),
            details: [
                "activity": activity,
                "details": details
            ],
            severity: 4,
            ipAddress: getCurrentIPAddress(),
            deviceInfo: getDeviceInfo()
        )
        logEvent(event)
    }
    
    func logSecurityRuleViolation(userId: String?, rule: String, details: [String: Any]) {
        let event = SecurityEvent(
            type: .securityRuleViolation,
            userId: userId,
            timestamp: Date(),
            details: [
                "rule": rule,
                "details": details
            ],
            severity: 3,
            ipAddress: getCurrentIPAddress(),
            deviceInfo: getDeviceInfo()
        )
        logEvent(event)
    }
    
    // Helper methods
    
    private func getCurrentIPAddress() -> String? {
        // In a real implementation, you would get this from the request headers
        // For now, return nil as this is just a placeholder
        return nil
    }
    
    private func getDeviceInfo() -> [String: String] {
        let device = UIDevice.current
        return [
            "name": device.name,
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "unknown"
        ]
    }
    
    // Analytics methods
    
    func getSecurityEvents(for userId: String, startDate: Date, endDate: Date, completion: @escaping ([SecurityEvent]) -> Void) {
        db.collection(securityLogsCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThanOrEqualTo: startDate)
            .whereField("timestamp", isLessThanOrEqualTo: endDate)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching security events: \(error)")
                    completion([])
                    return
                }
                
                let events = snapshot?.documents.compactMap { document -> SecurityEvent? in
                    guard let typeString = document.data()["type"] as? String,
                          let type = SecurityEventType(rawValue: typeString),
                          let timestamp = document.data()["timestamp"] as? Date,
                          let details = document.data()["details"] as? [String: Any],
                          let severity = document.data()["severity"] as? Int,
                          let deviceInfo = document.data()["deviceInfo"] as? [String: String] else {
                        return nil
                    }
                    
                    return SecurityEvent(
                        type: type,
                        userId: document.data()["userId"] as? String,
                        timestamp: timestamp,
                        details: details,
                        severity: severity,
                        ipAddress: document.data()["ipAddress"] as? String,
                        deviceInfo: deviceInfo
                    )
                } ?? []
                
                completion(events)
            }
    }
    
    func getHighSeverityEvents(completion: @escaping ([SecurityEvent]) -> Void) {
        db.collection(securityLogsCollection)
            .whereField("severity", isGreaterThanOrEqualTo: 4)
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching high severity events: \(error)")
                    completion([])
                    return
                }
                
                let events = snapshot?.documents.compactMap { document -> SecurityEvent? in
                    guard let typeString = document.data()["type"] as? String,
                          let type = SecurityEventType(rawValue: typeString),
                          let timestamp = document.data()["timestamp"] as? Date,
                          let details = document.data()["details"] as? [String: Any],
                          let severity = document.data()["severity"] as? Int,
                          let deviceInfo = document.data()["deviceInfo"] as? [String: String] else {
                        return nil
                    }
                    
                    return SecurityEvent(
                        type: type,
                        userId: document.data()["userId"] as? String,
                        timestamp: timestamp,
                        details: details,
                        severity: severity,
                        ipAddress: document.data()["ipAddress"] as? String,
                        deviceInfo: deviceInfo
                    )
                } ?? []
                
                completion(events)
            }
    }
} 