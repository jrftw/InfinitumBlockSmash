import SwiftUI

struct BlockShapeView: View {
    let block: Block
    let cellSize: CGFloat
    let isPreview: Bool
    let isValid: Bool
    
    // Cache for gradient images with size limit
    private static var gradientCache: [String: UIImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.infinitum.blocksmash.gradientcache")
    private static let maxCacheSize = 100 // Increased from 50
    private static var cacheHits = 0
    private static var cacheMisses = 0
    private static var lastCleanupTime = Date()
    private static let cleanupInterval: TimeInterval = 60 // Cleanup every minute
    
    var body: some View {
        ZStack {
            ForEach(0..<block.shape.cells.count, id: \.self) { idx in
                let cell = block.shape.cells[idx]
                Rectangle()
                    .fill(block.color.color)
                    .frame(width: cellSize, height: cellSize)
                    .cornerRadius(cellSize * 0.2)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: cellSize * 0.2)
                            .stroke(isPreview ? (isValid ? Color.green : Color.red) : Color.clear, lineWidth: isPreview ? 3 : 0)
                    )
                    .position(x: CGFloat(cell.0) * cellSize + cellSize/2, y: CGFloat(cell.1) * cellSize + cellSize/2)
            }
        }
        .frame(width: shapeWidth, height: shapeHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: block.id)
        .onDisappear {
            cleanupMemory()
        }
    }
    
    private var shapeWidth: CGFloat {
        let maxX = block.shape.cells.map { $0.0 }.max() ?? 0
        return CGFloat(maxX + 1) * cellSize
    }
    
    private var shapeHeight: CGFloat {
        let maxY = block.shape.cells.map { $0.1 }.max() ?? 0
        return CGFloat(maxY + 1) * cellSize
    }
    
    private func cleanupMemory() {
        // Clear gradient cache if it gets too large
        BlockShapeView.cacheQueue.async {
            let now = Date()
            
            // Only cleanup if enough time has passed
            guard now.timeIntervalSince(BlockShapeView.lastCleanupTime) >= BlockShapeView.cleanupInterval else {
                return
            }
            
            BlockShapeView.lastCleanupTime = now
            
            if BlockShapeView.gradientCache.count > BlockShapeView.maxCacheSize {
                // Remove least recently used entries when cache is full
                let sortedKeys = BlockShapeView.gradientCache.keys.sorted()
                let keysToRemove = sortedKeys.prefix(BlockShapeView.gradientCache.count - BlockShapeView.maxCacheSize)
                keysToRemove.forEach { BlockShapeView.gradientCache.removeValue(forKey: $0) }
            }
            
            // Log cache statistics
            let hitRate = Double(BlockShapeView.cacheHits) / Double(BlockShapeView.cacheHits + BlockShapeView.cacheMisses)
            print("[BlockShapeView] Cache hit rate: \(hitRate * 100)%")
            
            // Reset statistics
            BlockShapeView.cacheHits = 0
            BlockShapeView.cacheMisses = 0
        }
    }
    
    // MARK: - Gradient Cache
    private static func getCachedGradient(for color: BlockColor, size: CGSize) -> UIImage? {
        let key = "\(color.rawValue)_\(size.width)_\(size.height)"
        return cacheQueue.sync {
            let result = gradientCache[key]
            if result != nil {
                cacheHits += 1
            } else {
                cacheMisses += 1
            }
            return result
        }
    }
    
    private static func cacheGradient(_ image: UIImage, for color: BlockColor, size: CGSize) {
        let key = "\(color.rawValue)_\(size.width)_\(size.height)"
        cacheQueue.async {
            // Check cache size before adding new entry
            if gradientCache.count >= maxCacheSize {
                // Remove least recently used entry
                if let oldestKey = gradientCache.keys.first {
                    gradientCache.removeValue(forKey: oldestKey)
                }
            }
            gradientCache[key] = image
        }
    }
}

// MARK: - Memory Management
extension BlockShapeView {
    static func clearCache() {
        cacheQueue.async {
            gradientCache.removeAll()
            cacheHits = 0
            cacheMisses = 0
        }
    }
    
    static func trimCache() {
        cacheQueue.async {
            if gradientCache.count > maxCacheSize {
                let sortedKeys = gradientCache.keys.sorted()
                let keysToRemove = sortedKeys.prefix(gradientCache.count - maxCacheSize)
                keysToRemove.forEach { gradientCache.removeValue(forKey: $0) }
            }
        }
    }
    
    static func getCacheStats() -> (hits: Int, misses: Int, size: Int) {
        return cacheQueue.sync {
            (cacheHits, cacheMisses, gradientCache.count)
        }
    }
} 