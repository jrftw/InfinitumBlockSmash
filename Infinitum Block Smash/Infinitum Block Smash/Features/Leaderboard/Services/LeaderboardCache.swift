import Foundation
import FirebaseAuth

class LeaderboardCache {
    static let shared = LeaderboardCache()
    private let cache = NSCache<NSString, CachedLeaderboard>()
    private let cacheExpirationInterval: TimeInterval = 30 // Reduced from 300 to 30 seconds
    
    private init() {}
    
    class CachedLeaderboard {
        let entries: [FirebaseManager.LeaderboardEntry]
        let timestamp: Date
        
        init(entries: [FirebaseManager.LeaderboardEntry], timestamp: Date) {
            self.entries = entries
            self.timestamp = timestamp
        }
    }
    
    func cacheLeaderboard(_ entries: [FirebaseManager.LeaderboardEntry], type: LeaderboardType, period: String) {
        guard Auth.auth().currentUser != nil else {
            print("[LeaderboardCache] Not caching data - User not authenticated")
            return
        }
        
        let key = "\(type.collectionName)_\(period)" as NSString
        let cachedData = CachedLeaderboard(entries: entries, timestamp: Date())
        cache.setObject(cachedData, forKey: key)
        print("[LeaderboardCache] Cached \(entries.count) entries for \(period) leaderboard")
    }
    
    func getCachedLeaderboard(type: LeaderboardType, period: String) -> [FirebaseManager.LeaderboardEntry]? {
        guard Auth.auth().currentUser != nil else {
            print("[LeaderboardCache] Not returning cached data - User not authenticated")
            return nil
        }
        
        let key = "\(type.collectionName)_\(period)" as NSString
        guard let cachedData = cache.object(forKey: key) else {
            print("[LeaderboardCache] No cached data found for \(period) leaderboard")
            return nil
        }
        
        // Check if cache is expired
        let now = Date()
        let isExpired = now.timeIntervalSince(cachedData.timestamp) > cacheExpirationInterval
        
        if isExpired {
            print("[LeaderboardCache] Cache expired for \(period) leaderboard")
            cache.removeObject(forKey: key)
            return nil
        }
        
        print("[LeaderboardCache] Returning \(cachedData.entries.count) cached entries for \(period) leaderboard")
        return cachedData.entries
    }
    
    func invalidateCache(type: LeaderboardType? = nil, period: String? = nil) {
        if let type = type, let period = period {
            // Invalidate specific leaderboard
            let key = "\(type.collectionName)_\(period)" as NSString
            cache.removeObject(forKey: key)
            print("[LeaderboardCache] Invalidated cache for \(period) leaderboard")
        } else {
            // Invalidate all caches
            cache.removeAllObjects()
            print("[LeaderboardCache] Invalidated all caches")
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        print("[LeaderboardCache] Cleared all cached data")
    }
} 