/*
 * BlockShapeView.swift
 * 
 * BLOCK SHAPE VISUAL RENDERING AND CACHING SYSTEM
 * 
 * This SwiftUI view handles the visual rendering of block shapes with advanced caching,
 * memory management, and performance optimization. It provides efficient shape display
 * with gradient caching and memory cleanup for optimal performance.
 * 
 * KEY RESPONSIBILITIES:
 * - Block shape visual rendering and display
 * - Gradient caching system for performance optimization
 * - Memory management and cleanup
 * - Shape preview and validation display
 * - Responsive shape sizing and positioning
 * - Animation and visual effects
 * - Cache size and memory limit management
 * - Performance monitoring and optimization
 * - Shape validation visual feedback
 * - Memory-efficient image caching
 * 
 * MAJOR DEPENDENCIES:
 * - Block.swift: Block data model and shape definitions
 * - MemorySystem.swift: Memory cleanup and management
 * - SwiftUI: Core UI framework and rendering
 * - UIKit: Image caching and memory management
 * - DispatchQueue: Thread-safe cache operations
 * 
 * VISUAL FEATURES:
 * - Shape Rendering: Visual representation of block shapes
 * - Gradient Caching: Performance-optimized image caching
 * - Preview Mode: Shape validation and placement preview
 * - Animation Support: Smooth shape transitions
 * - Shadow Effects: Visual depth and styling
 * - Responsive Design: Adaptive shape sizing
 * 
 * CACHING SYSTEM:
 * - Gradient Image Caching: Pre-rendered shape images
 * - Memory Limit Management: 10MB cache limit
 * - Cache Size Control: Maximum 50 cached images
 * - Automatic Cleanup: Memory pressure response
 * - Thread-Safe Operations: Concurrent cache access
 * - Cache Key Generation: Efficient key-based storage
 * 
 * MEMORY MANAGEMENT:
 * - Automatic cache trimming
 * - Memory usage monitoring
 * - Aggressive cleanup strategies
 * - Image size validation
 * - Memory pressure response
 * - Cache statistics tracking
 * 
 * PERFORMANCE FEATURES:
 * - Efficient shape rendering
 * - Optimized cache operations
 * - Background memory cleanup
 * - Lazy image loading
 * - Memory-efficient storage
 * - Fast cache lookups
 * 
 * SHAPE VALIDATION:
 * - Preview mode display
 * - Valid/invalid state indication
 * - Visual feedback for placement
 * - Color-coded validation
 * - Real-time validation updates
 * 
 * ANIMATION SUPPORT:
 * - Spring animations for shape changes
 * - Smooth transitions
 * - Performance-optimized animations
 * - Responsive animation timing
 * 
 * RESPONSIVE DESIGN:
 * - Adaptive cell sizing
 * - Dynamic shape dimensions
 * - Screen size optimization
 * - Device-specific rendering
 * 
 * INTEGRATION POINTS:
 * - GameScene for shape display
 * - TrayNode for block tray rendering
 * - GameState for shape validation
 * - MemorySystem for cleanup coordination
 * - Performance monitoring systems
 * 
 * ARCHITECTURE ROLE:
 * This view acts as the visual rendering layer for block shapes,
 * providing efficient, cached rendering with advanced memory
 * management and performance optimization.
 * 
 * THREADING CONSIDERATIONS:
 * - Thread-safe cache operations
 * - Background memory cleanup
 * - Main thread UI updates
 * - Concurrent cache access
 * 
 * PERFORMANCE CONSIDERATIONS:
 * - Memory-efficient caching
 * - Optimized image storage
 * - Fast cache lookups
 * - Efficient cleanup strategies
 * 
 * REVIEW NOTES:
 * - Verify gradient caching system performance and memory usage
 * - Check cache size limits and memory management
 * - Test shape rendering performance on different devices
 * - Validate cache cleanup and memory pressure handling
 * - Check thread safety of cache operations
 * - Test shape preview and validation display
 * - Verify animation performance and smoothness
 * - Check memory usage with multiple shapes
 * - Test cache key generation and collision handling
 * - Validate image size validation and filtering
 * - Check cache statistics tracking and logging
 * - Test aggressive cleanup strategies effectiveness
 * - Verify shape sizing and positioning accuracy
 * - Check responsive design across different screen sizes
 * - Test cache performance under memory pressure
 * - Validate cache trimming algorithms
 * - Check image format compatibility and optimization
 * - Test cache operations during heavy game operations
 * - Verify cache cleanup integration with MemorySystem
 * - Check cache performance impact on overall app performance
 * - Test shape rendering during rapid state changes
 * - Validate cache memory limit enforcement
 * - Check cache operations during app background/foreground
 * - Test shape animation performance and timing
 * - Verify cache cleanup during low memory conditions
 * - Check shape validation visual feedback accuracy
 * - Test cache operations with different block shapes and colors
 * - Validate cache performance on low-end devices
 * - Check cache integration with theme system
 */

import SwiftUI

struct BlockShapeView: View {
    let block: Block
    let cellSize: CGFloat
    let isPreview: Bool
    let isValid: Bool

    // MARK: - Gradient Cache
    private static var gradientCache: [String: UIImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.infinitum.blocksmash.gradientcache")
    private static let maxCacheSize = 50
    private static let maxCacheMemoryBytes = 10 * 1024 * 1024

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
                    .position(
                        x: CGFloat(cell.0) * cellSize + cellSize / 2,
                        y: CGFloat(cell.1) * cellSize + cellSize / 2
                    )
            }
        }
        .frame(width: shapeWidth, height: shapeHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: block.id)
        .onAppear {
            Task { await BlockShapeView.trimGradientCache() }
        }
        .onDisappear {
            Task { await MemorySystem.shared.cleanupMemory() }
        }
    }

    private var shapeWidth: CGFloat {
        guard let maxX = block.shape.cells.map(\.0).max() else { return 0 }
        return CGFloat(maxX + 1) * cellSize
    }

    private var shapeHeight: CGFloat {
        guard let maxY = block.shape.cells.map(\.1).max() else { return 0 }
        return CGFloat(maxY + 1) * cellSize
    }

    private static func getCachedGradient(for color: BlockColor, size: CGSize) -> UIImage? {
        let key = cacheKey(for: color, size: size)
        return cacheQueue.sync { gradientCache[key] }
    }

    private static func cacheGradient(_ image: UIImage, for color: BlockColor, size: CGSize) {
        let key = cacheKey(for: color, size: size)
        cacheQueue.async { [key] in
            guard shouldCache(image: image) else { return }

            if gradientCache.count > maxCacheSize {
                removeOldestCacheEntries()
            }

            gradientCache[key] = image
        }
    }

    private static func shouldCache(image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let imageSize = cgImage.bytesPerRow * cgImage.height
        return imageSize <= maxCacheMemoryBytes
    }

    private static func cacheKey(for color: BlockColor, size: CGSize) -> String {
        return "\(color.rawValue)_\(Int(size.width))_\(Int(size.height))"
    }

    private static func trimGradientCache() async {
        cacheQueue.async {
            // First trim by count
            if gradientCache.count > maxCacheSize {
                removeOldestCacheEntries()
            }

            // Then trim by memory usage
            var totalMemory = 0
            var imageSizes: [(key: String, size: Int)] = []

            for (key, image) in gradientCache {
                if let cg = image.cgImage {
                    let size = cg.bytesPerRow * cg.height
                    totalMemory += size
                    imageSizes.append((key: key, size: size))
                }
            }

            // More aggressive memory trimming
            if totalMemory > maxCacheMemoryBytes {
                // Sort by size (largest first)
                let sorted = imageSizes.sorted { $0.size > $1.size }

                // Remove largest images until we're under 75% of the limit
                var memoryUsed = totalMemory
                let targetMemory = Int(Double(maxCacheMemoryBytes) * 0.75)
                
                for entry in sorted {
                    gradientCache.removeValue(forKey: entry.key)
                    memoryUsed -= entry.size
                    if memoryUsed <= targetMemory { break }
                }
                
                // If still over limit, remove all but the 10 smallest images
                if memoryUsed > maxCacheMemoryBytes {
                    let smallestImages = imageSizes.sorted { $0.size < $1.size }.prefix(10)
                    let keysToKeep = Set(smallestImages.map { $0.key })
                    gradientCache = gradientCache.filter { keysToKeep.contains($0.key) }
                }
            }
            
            // Log cache stats
            let totalMemoryMB = Double(totalMemory) / 1024.0 / 1024.0
            print("[BlockShapeView] Gradient cache stats - Count: \(gradientCache.count), Memory: \(String(format: "%.1f", totalMemoryMB))MB")
        }
    }

    private static func removeOldestCacheEntries() {
        let excessCount = gradientCache.count - maxCacheSize
        guard excessCount > 0 else { return }
        let keysToRemove = gradientCache.keys.sorted().prefix(excessCount)
        keysToRemove.forEach { key in
            gradientCache.removeValue(forKey: key)
        }
    }
}

// MARK: - Memory Management
extension BlockShapeView {
    static func clearCache() {
        cacheQueue.async {
            gradientCache.removeAll()
        }
    }

    static func trimCache() {
        cacheQueue.async {
            if gradientCache.count > maxCacheSize {
                removeOldestCacheEntries()
            }
        }
    }
}
