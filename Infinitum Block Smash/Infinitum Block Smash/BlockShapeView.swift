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

            if totalMemory > maxCacheMemoryBytes {
                // Sort by size (largest first)
                let sorted = imageSizes.sorted { $0.size > $1.size }

                // Remove largest images until we're under the limit
                var memoryUsed = totalMemory
                for entry in sorted {
                    gradientCache.removeValue(forKey: entry.key)
                    memoryUsed -= entry.size
                    if memoryUsed <= maxCacheMemoryBytes { break }
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
