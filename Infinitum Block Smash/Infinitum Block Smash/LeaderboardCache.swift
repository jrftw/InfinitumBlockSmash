import Foundation

class LeaderboardCache {
    static let shared = LeaderboardCache()
    private let cache = NSCache<NSString, NSArray>()
    private let userDefaults = UserDefaults.standard
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // Cache key format: "type_period_timestamp"
    private func cacheKey(type: LeaderboardType, period: String) -> String {
        return "\(type.collectionName)_\(period)"
    }
    
    func cacheLeaderboard(_ entries: [LeaderboardEntry], type: LeaderboardType, period: String) {
        let key = cacheKey(type: type, period: period)
        cache.setObject(entries as NSArray, forKey: key as NSString)
        userDefaults.set(Date().timeIntervalSince1970, forKey: "\(key)_timestamp")
    }
    
    func getCachedLeaderboard(type: LeaderboardType, period: String) -> [LeaderboardEntry]? {
        let key = cacheKey(type: type, period: period)
        guard let timestamp = userDefaults.object(forKey: "\(key)_timestamp") as? TimeInterval else {
            return nil
        }
        
        // Check if cache is expired
        if Date().timeIntervalSince1970 - timestamp > cacheExpirationInterval {
            return nil
        }
        
        return cache.object(forKey: key as NSString) as? [LeaderboardEntry]
    }
    
    func clearCache() {
        cache.removeAllObjects()
        // Clear timestamp keys
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasSuffix("_timestamp") }
        keys.forEach { userDefaults.removeObject(forKey: $0) }
    }
} 