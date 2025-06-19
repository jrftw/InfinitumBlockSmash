/*
 * MemoryConfig.swift
 * 
 * MEMORY MANAGEMENT CONFIGURATION
 * 
 * This file centralizes all memory management settings and intervals
 * to optimize performance across different device types and usage patterns.
 * 
 * KEY FEATURES:
 * - Device-specific optimization settings
 * - Configurable cleanup intervals
 * - Performance-based adjustments
 * - Battery optimization settings
 * - Thermal management configuration
 */

import Foundation

struct MemoryConfig {
    
    // MARK: - Device-Specific Settings
    
    /// Memory cleanup intervals based on device type
    struct Intervals {
        // High-end devices (iPhone 12 Pro and newer, iPad Pro)
        static let highEndDevice = DeviceIntervals(
            memoryCheck: 10.0,      // Check every 10 seconds
            memoryCleanup: 180.0,   // Cleanup every 3 minutes
            cacheCleanup: 900.0,    // Cache cleanup every 15 minutes
            statsLogging: 300.0     // Log stats every 5 minutes
        )
        
        // Mid-range devices (iPhone 11, iPhone SE, iPad Air)
        static let midRangeDevice = DeviceIntervals(
            memoryCheck: 15.0,      // Check every 15 seconds
            memoryCleanup: 300.0,   // Cleanup every 5 minutes
            cacheCleanup: 600.0,    // Cache cleanup every 10 minutes
            statsLogging: 180.0     // Log stats every 3 minutes
        )
        
        // Low-end devices (iPhone 8, older iPads)
        static let lowEndDevice = DeviceIntervals(
            memoryCheck: 20.0,      // Check every 20 seconds
            memoryCleanup: 420.0,   // Cleanup every 7 minutes
            cacheCleanup: 900.0,    // Cache cleanup every 15 minutes
            statsLogging: 300.0     // Log stats every 5 minutes
        )
        
        // Simulator settings (for testing)
        static let simulator = DeviceIntervals(
            memoryCheck: 5.0,       // More frequent for testing
            memoryCleanup: 120.0,   // Cleanup every 2 minutes
            cacheCleanup: 300.0,    // Cache cleanup every 5 minutes
            statsLogging: 60.0      // Log stats every minute
        )
    }
    
    // MARK: - Memory Thresholds
    
    /// Memory usage thresholds for different actions
    struct Thresholds {
        static let warningLevel: Double = 0.7      // 70% memory usage
        static let criticalLevel: Double = 0.85    // 85% memory usage
        static let extremeLevel: Double = 0.95     // 95% memory usage
    }
    
    // MARK: - Cache Limits
    
    /// Cache size limits based on device type
    static let highEndDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 50 * 1024 * 1024,  // 50MB
        diskCacheSize: 100 * 1024 * 1024,   // 100MB
        maxCacheEntries: 200
    )
    
    static let midRangeDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 25 * 1024 * 1024,  // 25MB
        diskCacheSize: 50 * 1024 * 1024,    // 50MB
        maxCacheEntries: 100
    )
    
    static let lowEndDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 15 * 1024 * 1024,  // 15MB
        diskCacheSize: 25 * 1024 * 1024,    // 25MB
        maxCacheEntries: 50
    )
    
    // MARK: - Performance Settings
    
    /// Performance optimization settings
    struct Performance {
        static let enableBackgroundCleanup = true
        static let enableAsyncOperations = true
        static let enableThermalThrottling = true
        static let enableBatteryOptimization = true
        static let enableMemoryPressureHandling = true
    }
    
    // MARK: - Helper Methods
    
    /// Get appropriate intervals for current device
    static func getIntervals() -> DeviceIntervals {
        // Check if running in simulator
        #if targetEnvironment(simulator)
        return Intervals.simulator
        #else
        // Determine device type based on available memory
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        
        if totalMemory >= 6144 { // 6GB or more (high-end)
            return Intervals.highEndDevice
        } else if totalMemory >= 3072 { // 3GB or more (mid-range)
            return Intervals.midRangeDevice
        } else { // Less than 3GB (low-end)
            return Intervals.lowEndDevice
        }
        #endif
    }
    
    /// Get appropriate cache limits for current device
    static func getCacheLimits() -> CacheLimits {
        // Check if running in simulator
        #if targetEnvironment(simulator)
        return midRangeDeviceCacheLimits
        #else
        // Determine device type based on available memory
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        
        if totalMemory >= 6144 { // 6GB or more (high-end)
            return highEndDeviceCacheLimits
        } else if totalMemory >= 3072 { // 3GB or more (mid-range)
            return midRangeDeviceCacheLimits
        } else { // Less than 3GB (low-end)
            return lowEndDeviceCacheLimits
        }
        #endif
    }
    
    // MARK: - Test Function (for debugging)
    
    /// Test function to verify MemoryConfig is working correctly
    static func testMemoryConfig() -> String {
        let intervals = getIntervals()
        let cacheLimits = getCacheLimits()
        
        return """
        MemoryConfig Test Results:
        - Memory Check Interval: \(intervals.memoryCheck)s
        - Memory Cleanup Interval: \(intervals.memoryCleanup)s
        - Cache Cleanup Interval: \(intervals.cacheCleanup)s
        - Memory Cache Size: \(cacheLimits.memoryCacheSize / 1024 / 1024)MB
        - Disk Cache Size: \(cacheLimits.diskCacheSize / 1024 / 1024)MB
        - Max Cache Entries: \(cacheLimits.maxCacheEntries)
        """
    }
}

// MARK: - Supporting Types

struct DeviceIntervals {
    let memoryCheck: TimeInterval
    let memoryCleanup: TimeInterval
    let cacheCleanup: TimeInterval
    let statsLogging: TimeInterval
}

struct CacheLimits {
    let memoryCacheSize: Int
    let diskCacheSize: Int64
    let maxCacheEntries: Int
} 