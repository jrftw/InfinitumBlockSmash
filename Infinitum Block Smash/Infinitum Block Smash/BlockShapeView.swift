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
            Task {
                await MemorySystem.shared.cleanupMemory()
            }
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
    
    // MARK: - Gradient Cache
    private static func getCachedGradient(for color: BlockColor, size: CGSize) -> UIImage? {
        let key = "\(color.rawValue)_\(size.width)_\(size.height)"
        return cacheQueue.sync {
            gradientCache[key]
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
} 