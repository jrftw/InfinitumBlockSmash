// MARK: - CacheManager.swift
import Foundation
import Compression
import os.log

final class CacheManager {
    static let shared = CacheManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.infinitum.blocksmash", category: "CacheManager")
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    private let compressionQueue = DispatchQueue(label: "com.infinitum.blocksmash.compression", qos: .utility)
    private let cacheQueue = DispatchQueue(label: "com.infinitum.blocksmash.cache", qos: .utility)
    
    // MARK: - Cache Stats
    private var cacheHits = 0
    private var cacheMisses = 0
    private var lastCleanupTime = Date()
    private let cleanupInterval: TimeInterval = 300 // 5 minutes
    private var lastStatsLogTime = Date()
    private let statsLogInterval: TimeInterval = 60 // 1 minute
    
    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 75 * 1024 * 1024
        
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("GameCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
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
        if memoryCache.totalCostLimit > 75 * 1024 * 1024 {
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
            """)
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
