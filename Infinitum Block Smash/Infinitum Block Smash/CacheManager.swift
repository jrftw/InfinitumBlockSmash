import Foundation

final class CacheManager {
    static let shared = CacheManager()
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    private init() {
        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Setup cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("GameCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Memory Cache
    
    func setMemoryCache<T: AnyObject>(_ object: T, forKey key: String) {
        memoryCache.setObject(object, forKey: key as NSString)
    }
    
    func getMemoryCache<T: AnyObject>(forKey key: String) -> T? {
        return memoryCache.object(forKey: key as NSString) as? T
    }
    
    func removeMemoryCache(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
    }
    
    // MARK: - Disk Cache
    
    func setDiskCache<T: Encodable>(_ object: T, forKey key: String, expiration: TimeInterval? = nil) throws {
        let cacheEntry = CacheEntry(
            data: try JSONEncoder().encode(object),
            expirationDate: Date().addingTimeInterval(expiration ?? cacheExpirationInterval)
        )
        
        let data = try JSONEncoder().encode(cacheEntry)
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try data.write(to: fileURL)
        
        // Cleanup if needed
        try cleanupCache()
    }
    
    func getDiskCache<T: Decodable>(forKey key: String) throws -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        let data = try Data(contentsOf: fileURL)
        let cacheEntry = try JSONDecoder().decode(CacheEntry.self, from: data)
        
        // Check expiration
        if cacheEntry.expirationDate < Date() {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return try JSONDecoder().decode(T.self, from: cacheEntry.data)
    }
    
    func removeDiskCache(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Cache Management
    
    func clearAllCaches() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func cleanupCache() throws {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        let now = Date()
        
        // Remove expired files and calculate total size
        var totalSize: Int64 = 0
        for fileURL in contents {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date,
               now.timeIntervalSince(modificationDate) > cacheExpirationInterval {
                try fileManager.removeItem(at: fileURL)
            } else if let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        // If total size exceeds limit, remove oldest files
        if totalSize > maxCacheSize {
            let sortedFiles = try contents.sorted { file1, file2 in
                let date1 = try fileManager.attributesOfItem(atPath: file1.path)[.modificationDate] as? Date ?? Date.distantPast
                let date2 = try fileManager.attributesOfItem(atPath: file2.path)[.modificationDate] as? Date ?? Date.distantPast
                return date1 < date2
            }
            
            for fileURL in sortedFiles {
                if totalSize <= maxCacheSize { break }
                if let fileSize = try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 {
                    try fileManager.removeItem(at: fileURL)
                    totalSize -= fileSize
                }
            }
        }
    }
}

// MARK: - Supporting Types

private struct CacheEntry: Codable {
    let data: Data
    let expirationDate: Date
} 