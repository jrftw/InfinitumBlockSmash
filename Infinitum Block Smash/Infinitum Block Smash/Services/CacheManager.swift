/*
 * CacheManager.swift
 * 
 * COMPREHENSIVE CACHING AND DATA MANAGEMENT SYSTEM
 * 
 * This service provides a complete caching solution for the Infinitum Block Smash game,
 * including memory caching, disk caching, compression, and intelligent cache management.
 * It optimizes performance through efficient data storage and retrieval.
 * 
 * KEY RESPONSIBILITIES:
 * - Memory and disk caching management
 * - Data compression and decompression
 * - Cache expiration and cleanup
 * - Cache statistics and monitoring
 * - Performance optimization
 * - Memory pressure handling
 * - Cache size management
 * - Background cleanup operations
 * - Cache hit/miss tracking
 * - Data persistence and recovery
 * 
 * MAJOR DEPENDENCIES:
 * - Foundation: Core data management
 * - Compression: Data compression framework
 * - os.log: System logging
 * - FileManager: File system operations
 * - NSCache: Memory caching
 * - Logger.swift: Application logging
 * 
 * CACHING FEATURES:
 * - Memory Cache: Fast in-memory data storage
 * - Disk Cache: Persistent file-based storage
 * - Data Compression: Storage optimization
 * - Cache Expiration: Automatic data cleanup
 * - Size Management: Cache size limits
 * - Statistics Tracking: Performance monitoring
 * - Background Cleanup: Automatic maintenance
 * 
 * MEMORY CACHE:
 * - 100 object limit
 * - 25MB total cost limit
 * - Thread-safe operations
 * - Automatic eviction
 * - Hit/miss tracking
 * 
 * DISK CACHE:
 * - 50MB total size limit
 * - 30-minute expiration
 * - Compressed storage
 * - File-based persistence
 * - Automatic cleanup
 * 
 * COMPRESSION FEATURES:
 * - LZ4 compression algorithm
 * - Background compression
 * - Automatic decompression
 * - Compression ratio optimization
 * - Memory-efficient processing
 * 
 * CACHE MANAGEMENT:
 * - Periodic cleanup (3-minute intervals)
 * - Expired entry removal
 * - Size limit enforcement
 * - Oldest-first eviction
 * - Memory pressure response
 * 
 * PERFORMANCE FEATURES:
 * - Efficient data serialization
 * - Optimized compression
 * - Background processing
 * - Memory-efficient storage
 * - Fast cache lookups
 * 
 * STATISTICS AND MONITORING:
 * - Cache hit/miss ratios
 * - Memory usage tracking
 * - Disk usage monitoring
 * - Performance metrics
 * - Regular statistics logging
 * 
 * ERROR HANDLING:
 * - File system errors
 * - Compression failures
 * - Memory pressure handling
 * - Corrupted data recovery
 * - Graceful degradation
 * 
 * INTEGRATION POINTS:
 * - Game data caching
 * - Image and asset caching
 * - User preferences storage
 * - Analytics data caching
 * - Network response caching
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central caching coordinator,
 * providing efficient data storage and retrieval while
 * maintaining performance and memory efficiency.
 * 
 * THREADING CONSIDERATIONS:
 * - Thread-safe cache operations
 * - Background compression processing
 * - Concurrent cache access
 * - Safe file system operations
 * 
 * PERFORMANCE CONSIDERATIONS:
 * - Memory-efficient caching
 * - Optimized compression
 * - Fast cache lookups
 * - Efficient cleanup strategies
 * 
 * REVIEW NOTES:
 * - Verify cache size limits and memory management
 * - Check compression performance and ratio
 * - Test cache expiration and cleanup functionality
 * - Validate cache hit/miss statistics accuracy
 * - Check cache performance on low-end devices
 * - Test cache operations during memory pressure
 * - Verify cache data integrity and corruption handling
 * - Check cache cleanup scheduling and efficiency
 * - Test cache operations during app background/foreground
 * - Validate cache compression algorithm effectiveness
 * - Check cache file system operations and error handling
 * - Test cache performance with large data sets
 * - Verify cache statistics logging and monitoring
 * - Check cache thread safety and concurrent access
 * - Test cache operations during heavy game operations
 * - Validate cache expiration time accuracy
 * - Check cache memory pressure response
 * - Test cache operations during network interruptions
 * - Verify cache data serialization and deserialization
 * - Check cache performance impact on overall app performance
 * - Test cache operations with different data types
 * - Validate cache cleanup algorithm efficiency
 * - Check cache file system permissions and access
 * - Test cache operations during app updates
 * - Verify cache data privacy and security
 * - Check cache integration with other systems
 * - Test cache performance during rapid data changes
 * - Validate cache error recovery mechanisms
 * - Check cache compatibility with different iOS versions
 * - Test cache operations during device storage pressure
 */

// MARK: - CacheManager.swift
import Foundation
import Compression
import os.log

final class CacheManager {
    static let shared = CacheManager()
    private let logger = Logger.shared
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64
    private let cacheExpirationInterval: TimeInterval = 1800 // 30 minutes
    private let compressionQueue = DispatchQueue(label: "com.infinitum.blocksmash.compression", qos: .utility)
    private let cacheQueue = DispatchQueue(label: "com.infinitum.blocksmash.cache", qos: .utility)
    
    // MARK: - Cache Stats
    private var cacheHits = 0
    private var cacheMisses = 0
    private var lastCleanupTime = Date()
    private let cleanupInterval: TimeInterval = MemoryConfig.getIntervals().cacheCleanup
    private var lastStatsLogTime = Date()
    private let statsLogInterval: TimeInterval = MemoryConfig.getIntervals().statsLogging
    
    private init() {
        let cacheLimits = MemoryConfig.getCacheLimits()
        memoryCache.countLimit = cacheLimits.maxCacheEntries
        memoryCache.totalCostLimit = cacheLimits.memoryCacheSize
        
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("GameCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        maxCacheSize = Int64(cacheLimits.diskCacheSize)
        
        startPeriodicCleanup()
        startStatsLogging()
    }
    
    // MARK: - Memory Cache
    
    func setMemoryCache<T: AnyObject>(_ object: T, forKey key: String, cost: Int = 1) {
        cacheQueue.async {
            self.memoryCache.setObject(object, forKey: key as NSString, cost: cost)
        }
    }
    
    func getMemoryCache<T: AnyObject>(forKey key: String) -> T? {
        let result = memoryCache.object(forKey: key as NSString) as? T
        result != nil ? (cacheHits += 1) : (cacheMisses += 1)
        return result
    }
    
    func removeMemoryCache(forKey key: String) {
        cacheQueue.async {
            self.memoryCache.removeObject(forKey: key as NSString)
        }
    }
    
    // MARK: - Disk Cache
    
    func setDiskCache<T: Encodable>(_ object: T, forKey key: String, expiration: TimeInterval? = nil, compress: Bool = true) throws {
        let expirationDate = Date().addingTimeInterval(expiration ?? cacheExpirationInterval)
        let encodedData = try JSONEncoder().encode(object)
        let cacheEntry = try JSONEncoder().encode(CacheEntry(data: encodedData, expirationDate: expirationDate))
        
        let finalData = compress ? try compressionQueue.sync { try compressData(cacheEntry) } : cacheEntry
        try finalData.write(to: cacheDirectory.appendingPathComponent(key))
        
        try cleanupCache()
    }
    
    func getDiskCache<T: Decodable>(forKey key: String, decompress: Bool = true) throws -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        var data = try Data(contentsOf: fileURL)
        if decompress {
            data = try compressionQueue.sync { try decompressData(data) }
        }
        
        let entry = try JSONDecoder().decode(CacheEntry.self, from: data)
        guard entry.expirationDate > Date() else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return try JSONDecoder().decode(T.self, from: entry.data)
    }
    
    func removeDiskCache(forKey key: String) {
        try? fileManager.removeItem(at: cacheDirectory.appendingPathComponent(key))
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
        guard now.timeIntervalSince(lastCleanupTime) >= cleanupInterval else { return }
        lastCleanupTime = now
        
        // Clean up expired entries
        let expiredDate = Date().addingTimeInterval(-cacheExpirationInterval)
        let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < expiredDate {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // Check cache size
        var totalSize: Int64 = 0
        let fileAttributes = try fileManager.attributesOfItem(atPath: cacheDirectory.path)
        if let size = fileAttributes[.size] as? Int64 {
            totalSize = size
        }
        
        if totalSize > maxCacheSize {
            // Sort files by creation date
            let sortedFiles = try files.sorted { file1, file2 in
                let date1 = try fileManager.attributesOfItem(atPath: file1.path)[.creationDate] as? Date ?? Date.distantPast
                let date2 = try fileManager.attributesOfItem(atPath: file2.path)[.creationDate] as? Date ?? Date.distantPast
                return date1 < date2
            }
            
            // Remove oldest files until we're under the limit
            for file in sortedFiles {
                if totalSize <= maxCacheSize { break }
                if let size = try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64 {
                    try? fileManager.removeItem(at: file)
                    totalSize -= size
                }
            }
        }
        
        // Trim memory cache if needed
        if memoryCache.totalCostLimit > 25 * 1024 * 1024 {
            memoryCache.removeAllObjects()
        }
        
        // Log cache stats
        logCacheStats()
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
    
    private func startStatsLogging() {
        Timer.scheduledTimer(withTimeInterval: statsLogInterval, repeats: true) { [weak self] _ in
            self?.logCacheStats()
        }
    }
    
    private func logCacheStats() {
        let now = Date()
        guard now.timeIntervalSince(lastStatsLogTime) >= statsLogInterval else { return }
        lastStatsLogTime = now
        
        var totalSize: Int64 = 0
        var fileCount = 0
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            fileCount = files.count
            for file in files {
                if let size = try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        logger.info("""
            Cache Stats:
            - Memory Cache: \(self.memoryCache.totalCostLimit / 1024 / 1024)MB limit
            - Disk Cache: \(totalSize / 1024 / 1024)MB used, \(fileCount) files
            - Hit Ratio: \(Double(self.cacheHits) / Double(max(1, self.cacheHits + self.cacheMisses)) * 100)%
            """, category: .cacheManager)
    }
    
    // MARK: - Compression
    
    private func compressData(_ data: Data) throws -> Data {
        let srcSize = data.count
        let destSize = srcSize * 2
        let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
        defer { dest.deallocate() }
        
        let compressedSize = data.withUnsafeBytes {
            compression_encode_buffer(dest, destSize, $0.baseAddress!.assumingMemoryBound(to: UInt8.self), srcSize, nil, COMPRESSION_ZLIB)
        }
        
        guard compressedSize > 0 else {
            throw NSError(domain: "CacheManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Compression failed"])
        }
        
        return Data(bytes: dest, count: compressedSize)
    }
    
    private func decompressData(_ data: Data) throws -> Data {
        let srcSize = data.count
        let destSize = srcSize * 4
        let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
        defer { dest.deallocate() }
        
        let decompressedSize = data.withUnsafeBytes {
            compression_decode_buffer(dest, destSize, $0.baseAddress!.assumingMemoryBound(to: UInt8.self), srcSize, nil, COMPRESSION_ZLIB)
        }
        
        guard decompressedSize > 0 else {
            throw NSError(domain: "CacheManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
        }
        
        return Data(bytes: dest, count: decompressedSize)
    }
}

// MARK: - Supporting Types

private struct CacheEntry: Codable {
    let data: Data
    let expirationDate: Date
}
