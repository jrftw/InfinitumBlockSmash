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
            memoryCheck: 30.0,      // Check every 30 seconds (increased from 10)
            memoryCleanup: 300.0,   // Cleanup every 5 minutes (increased from 3)
            cacheCleanup: 1200.0,   // Cache cleanup every 20 minutes (increased from 15)
            statsLogging: 600.0     // Log stats every 10 minutes (increased from 5)
        )
        
        // Mid-range devices (iPhone 11, iPhone SE, iPad Air)
        static let midRangeDevice = DeviceIntervals(
            memoryCheck: 45.0,      // Check every 45 seconds (increased from 15)
            memoryCleanup: 420.0,   // Cleanup every 7 minutes (increased from 5)
            cacheCleanup: 900.0,    // Cache cleanup every 15 minutes (increased from 10)
            statsLogging: 300.0     // Log stats every 5 minutes (increased from 3)
        )
        
        // Low-end devices (iPhone 8, older iPads)
        static let lowEndDevice = DeviceIntervals(
            memoryCheck: 60.0,      // Check every 60 seconds (increased from 20)
            memoryCleanup: 600.0,   // Cleanup every 10 minutes (increased from 7)
            cacheCleanup: 1200.0,   // Cache cleanup every 20 minutes (increased from 15)
            statsLogging: 600.0     // Log stats every 10 minutes (increased from 5)
        )
        
        // Simulator settings (for testing)
        static let simulator = DeviceIntervals(
            memoryCheck: 15.0,      // More frequent for testing (increased from 5)
            memoryCleanup: 180.0,   // Cleanup every 3 minutes (increased from 2)
            cacheCleanup: 600.0,    // Cache cleanup every 10 minutes (increased from 5)
            statsLogging: 120.0     // Log stats every 2 minutes (increased from 1)
        )
    }
    
    // MARK: - Memory Thresholds
    
    /// Memory usage thresholds for different actions
    struct Thresholds {
        // Less aggressive thresholds to prevent app killing
        static let warningLevel: Double = 0.6      // 60% memory usage (reduced from 70%)
        static let criticalLevel: Double = 0.75    // 75% memory usage (reduced from 85%)
        static let extremeLevel: Double = 0.85     // 85% memory usage (reduced from 95%)
    }
    
    // MARK: - Cache Limits
    
    /// Cache size limits based on device type
    static let highEndDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 30 * 1024 * 1024,  // 30MB (reduced from 50MB)
        diskCacheSize: 60 * 1024 * 1024,   // 60MB (reduced from 100MB)
        maxCacheEntries: 150
    )
    
    static let midRangeDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 15 * 1024 * 1024,  // 15MB (reduced from 25MB)
        diskCacheSize: 30 * 1024 * 1024,    // 30MB (reduced from 50MB)
        maxCacheEntries: 75
    )
    
    static let lowEndDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 8 * 1024 * 1024,   // 8MB (reduced from 15MB)
        diskCacheSize: 15 * 1024 * 1024,    // 15MB (reduced from 25MB)
        maxCacheEntries: 30
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