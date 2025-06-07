import Foundation
import Compression

final class CacheManager {
    static let shared = CacheManager()
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    private let compressionQueue = DispatchQueue(label: "com.infinitum.blocksmash.compression")
    private let cacheQueue = DispatchQueue(label: "com.infinitum.blocksmash.cache")
    
    // Cache statistics
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var lastCleanupTime: Date = Date()
    private let cleanupInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        // Configure memory cache with better defaults
        memoryCache.countLimit = 200 // Increased from 100
        memoryCache.totalCostLimit = 75 * 1024 * 1024 // 75MB, increased from 50MB
        
        // Setup cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("GameCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Start periodic cleanup
        startPeriodicCleanup()
    }
    
    // MARK: - Memory Cache
    
    func setMemoryCache<T: AnyObject>(_ object: T, forKey key: String, cost: Int = 1) {
        cacheQueue.async {
            self.memoryCache.setObject(object, forKey: key as NSString, cost: cost)
        }
    }
    
    func getMemoryCache<T: AnyObject>(forKey key: String) -> T? {
        let result = memoryCache.object(forKey: key as NSString) as? T
        if result != nil {
            cacheHits += 1
        } else {
            cacheMisses += 1
        }
        return result
    }
    
    func removeMemoryCache(forKey key: String) {
        cacheQueue.async {
            self.memoryCache.removeObject(forKey: key as NSString)
        }
    }
    
    // MARK: - Disk Cache
    
    func setDiskCache<T: Encodable>(_ object: T, forKey key: String, expiration: TimeInterval? = nil, compress: Bool = true) throws {
        let cacheEntry = CacheEntry(
            data: try JSONEncoder().encode(object),
            expirationDate: Date().addingTimeInterval(expiration ?? cacheExpirationInterval)
        )
        
        var data = try JSONEncoder().encode(cacheEntry)
        
        if compress {
            data = try compressionQueue.sync {
                try compressData(data)
            }
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try data.write(to: fileURL)
        
        // Cleanup if needed
        try cleanupCache()
    }
    
    func getDiskCache<T: Decodable>(forKey key: String, decompress: Bool = true) throws -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        var data = try Data(contentsOf: fileURL)
        
        if decompress {
            data = try compressionQueue.sync {
                try decompressData(data)
            }
        }
        
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
        resetCacheStats()
    }
    
    private func cleanupCache() throws {
        let now = Date()
        
        // Only cleanup if enough time has passed
        guard now.timeIntervalSince(lastCleanupTime) >= cleanupInterval else {
            return
        }
        
        lastCleanupTime = now
        
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        
        // Remove expired files and calculate total size
        var totalSize: Int64 = 0
        var filesToRemove: [URL] = []
        
        for fileURL in contents {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date,
               now.timeIntervalSince(modificationDate) > cacheExpirationInterval {
                filesToRemove.append(fileURL)
            } else if let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        // Remove expired files
        for fileURL in filesToRemove {
            try? fileManager.removeItem(at: fileURL)
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
                    try? fileManager.removeItem(at: fileURL)
                    totalSize -= fileSize
                }
            }
        }
    }
    
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            try? self?.cleanupCache()
        }
    }
    
    private func resetCacheStats() {
        cacheHits = 0
        cacheMisses = 0
    }
    
    // MARK: - Compression
    
    private func compressData(_ data: Data) throws -> Data {
        let sourceSize = data.count
        let destinationSize = sourceSize * 2 // Worst case scenario
        
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destination.deallocate() }
        
        let algorithm = COMPRESSION_ZLIB
        
        let compressedSize = data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return 0 }
            let source = baseAddress.assumingMemoryBound(to: UInt8.self)
            return compression_encode_buffer(destination, destinationSize,
                                          source, sourceSize,
                                          nil, algorithm)
        }
        
        guard compressedSize > 0 else {
            throw NSError(domain: "CacheManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Compression failed"])
        }
        
        return Data(bytes: destination, count: compressedSize)
    }
    
    private func decompressData(_ data: Data) throws -> Data {
        let sourceSize = data.count
        let destinationSize = sourceSize * 4 // Worst case scenario
        
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destination.deallocate() }
        
        let algorithm = COMPRESSION_ZLIB
        
        let decompressedSize = data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return 0 }
            let source = baseAddress.assumingMemoryBound(to: UInt8.self)
            return compression_decode_buffer(destination, destinationSize,
                                          source, sourceSize,
                                          nil, algorithm)
        }
        
        guard decompressedSize > 0 else {
            throw NSError(domain: "CacheManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
        }
        
        return Data(bytes: destination, count: decompressedSize)
    }
}

// MARK: - Supporting Types

private struct CacheEntry: Codable {
    let data: Data
    let expirationDate: Date
} 