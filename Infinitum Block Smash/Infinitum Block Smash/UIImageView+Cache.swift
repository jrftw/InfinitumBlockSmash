import UIKit

extension UIImageView {
    private static var imageCache = NSCache<NSString, UIImage>()
    private static var lastCleanupTime = Date()
    private static let cleanupInterval: TimeInterval = 300 // 5 minutes
    
    static func clearImageCache() {
        imageCache.removeAllObjects()
        lastCleanupTime = Date()
    }
    
    static func clearOldImageCache() {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) >= cleanupInterval else { return }
        
        // Remove old cached images
        imageCache.removeAllObjects()
        lastCleanupTime = now
    }
    
    func setImageWithCache(_ image: UIImage?, forKey key: String) {
        if let image = image {
            UIImageView.imageCache.setObject(image, forKey: key as NSString)
            self.image = image
        } else {
            self.image = nil
        }
    }
    
    func getCachedImage(forKey key: String) -> UIImage? {
        return UIImageView.imageCache.object(forKey: key as NSString)
    }
} 