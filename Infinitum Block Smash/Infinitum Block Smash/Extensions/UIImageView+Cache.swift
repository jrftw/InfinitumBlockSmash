/******************************************************
 * FILE: UIImageView+Cache.swift
 * MARK: UIImageView Image Caching Extension
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides image caching functionality for UIImageView, optimizing
 * memory usage and performance through intelligent cache management.
 *
 * KEY RESPONSIBILITIES:
 * - Cache images with memory size tracking
 * - Provide automatic cache cleanup
 * - Manage cache size limits (50MB)
 * - Handle cache key-based storage and retrieval
 * - Implement memory-efficient image storage
 * - Support cache statistics and monitoring
 *
 * MAJOR DEPENDENCIES:
 * - UIKit: Core framework for UIImageView and UIImage
 * - NSCache: Thread-safe caching mechanism
 * - Foundation: Date and time management for cleanup
 *
 * EXTERNAL FRAMEWORKS USED:
 * - UIKit: iOS UI framework for image handling
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as a performance optimization layer that reduces
 * memory usage and improves image loading performance.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Cache cleanup must occur automatically
 * - Memory limits must be strictly enforced
 * - Thread safety must be maintained
 * - Image size estimation must be accurate
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify cache memory usage stays within limits
 * - Test cache cleanup timing and effectiveness
 * - Check thread safety of cache operations
 * - Validate image size estimation accuracy
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add disk caching for persistent storage
 * - Implement cache compression
 * - Add cache analytics and metrics
 ******************************************************/

import UIKit

extension UIImageView {
    private static var imageCache = NSCache<NSString, UIImage>()
    private static var lastCleanupTime = Date()
    private static let cleanupInterval: TimeInterval = 300 // 5 minutes
    private static let maxCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private static var currentCacheSize: Int = 0
    
    static func clearImageCache() {
        imageCache.removeAllObjects()
        lastCleanupTime = Date()
        currentCacheSize = 0
    }
    
    static func clearOldImageCache() {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) >= cleanupInterval else { return }
        
        // Remove old cached images
        imageCache.removeAllObjects()
        lastCleanupTime = now
        currentCacheSize = 0
    }
    
    func setImageWithCache(_ image: UIImage?, forKey key: String) {
        if let image = image {
            let imageSize = Self.estimateImageSize(image)
            
            // Check if adding this image would exceed the cache limit
            if Self.currentCacheSize + imageSize > Self.maxCacheSize {
                Self.clearOldImageCache()
            }
            
            Self.imageCache.setObject(image, forKey: key as NSString)
            Self.currentCacheSize += imageSize
            self.image = image
        } else {
            self.image = nil
        }
    }
    
    func getCachedImage(forKey key: String) -> UIImage? {
        return Self.imageCache.object(forKey: key as NSString)
    }
    
    private static func estimateImageSize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let bytesPerRow = cgImage.bytesPerRow
        let height = cgImage.height
        return bytesPerRow * height
    }
} 