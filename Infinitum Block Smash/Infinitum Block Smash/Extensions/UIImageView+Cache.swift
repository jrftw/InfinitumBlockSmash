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