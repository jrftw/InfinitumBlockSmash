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
            memoryCheck: 120.0,     // Check every 120 seconds (increased from 60)
            memoryCleanup: 900.0,   // Cleanup every 15 minutes (increased from 10)
            cacheCleanup: 2400.0,   // Cache cleanup every 40 minutes (increased from 30)
            statsLogging: 1800.0    // Log stats every 30 minutes (increased from 20)
        )
        
        // Mid-range devices (iPhone 11, iPhone SE, iPad Air)
        static let midRangeDevice = DeviceIntervals(
            memoryCheck: 180.0,     // Check every 180 seconds (increased from 90)
            memoryCleanup: 1200.0,  // Cleanup every 20 minutes (increased from 15)
            cacheCleanup: 3000.0,   // Cache cleanup every 50 minutes (increased from 30)
            statsLogging: 1800.0    // Log stats every 30 minutes (increased from 15)
        )
        
        // Low-end devices (iPhone 8, older iPads)
        static let lowEndDevice = DeviceIntervals(
            memoryCheck: 240.0,     // Check every 240 seconds (increased from 120)
            memoryCleanup: 1800.0,  // Cleanup every 30 minutes (increased from 20)
            cacheCleanup: 3600.0,   // Cache cleanup every 60 minutes (increased from 40)
            statsLogging: 2400.0    // Log stats every 40 minutes (increased from 20)
        )
        
        // Simulator settings (for testing)
        static let simulator = DeviceIntervals(
            memoryCheck: 60.0,      // More frequent for testing (increased from 30)
            memoryCleanup: 600.0,   // Cleanup every 10 minutes (increased from 5)
            cacheCleanup: 1800.0,   // Cache cleanup every 30 minutes (increased from 15)
            statsLogging: 600.0     // Log stats every 10 minutes (increased from 5)
        )
    }
    
    // MARK: - Memory Thresholds
    
    /// Memory usage thresholds for different actions
    struct Thresholds {
        // Much more conservative thresholds to prevent app killing
        static let warningLevel: Double = 0.35     // 35% memory usage (reduced from 40%)
        static let criticalLevel: Double = 0.45    // 45% memory usage (reduced from 55%)
        static let extremeLevel: Double = 0.55     // 55% memory usage (reduced from 65%)
    }
    
    // MARK: - Cache Limits
    
    /// Cache size limits based on device type
    static let highEndDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 10 * 1024 * 1024,  // 10MB (reduced from 15MB)
        diskCacheSize: 20 * 1024 * 1024,   // 20MB (reduced from 30MB)
        maxCacheEntries: 50
    )
    
    static let midRangeDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 5 * 1024 * 1024,   // 5MB (reduced from 8MB)
        diskCacheSize: 10 * 1024 * 1024,    // 10MB (reduced from 15MB)
        maxCacheEntries: 25
    )
    
    static let lowEndDeviceCacheLimits = CacheLimits(
        memoryCacheSize: 2 * 1024 * 1024,   // 2MB (reduced from 3MB)
        diskCacheSize: 5 * 1024 * 1024,     // 5MB (reduced from 8MB)
        maxCacheEntries: 10
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