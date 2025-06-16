import SpriteKit

final class NodePool {
    static let shared = NodePool()
    
    // MARK: - Properties
    private var blockNodePool: [SKNode] = []
    private var particleEmitterPool: [SKEmitterNode] = []
    private var highlightNodePool: [SKNode] = []
    private var previewNodePool: [SKNode] = []
    
    private let maxPoolSize = 50
    private let minPoolSize = 10
    
    // MARK: - Initialization
    private init() {
        // Pre-warm pools
        Task { @MainActor in
            await preWarmPools()
        }
    }
    
    // MARK: - Block Nodes
    func getBlockNode() -> SKNode {
        if let node = blockNodePool.popLast() {
            node.removeAllActions()
            node.removeAllChildren()
            node.alpha = 1.0
            return node
        }
        return SKNode()
    }
    
    func returnBlockNode(_ node: SKNode) {
        guard blockNodePool.count < maxPoolSize else {
            node.removeFromParent()
            return
        }
        
        node.removeAllActions()
        node.removeAllChildren()
        node.alpha = 0
        blockNodePool.append(node)
    }
    
    // MARK: - Particle Emitters
    func getParticleEmitter() -> SKEmitterNode {
        if let emitter = particleEmitterPool.popLast() {
            emitter.removeAllActions()
            emitter.particleBirthRate = 0
            return emitter
        }
        return SKEmitterNode()
    }
    
    func returnParticleEmitter(_ emitter: SKEmitterNode) {
        guard particleEmitterPool.count < maxPoolSize else {
            emitter.removeFromParent()
            return
        }
        
        emitter.removeAllActions()
        emitter.particleBirthRate = 0
        particleEmitterPool.append(emitter)
    }
    
    // MARK: - Highlight Nodes
    func getHighlightNode() -> SKNode {
        if let node = highlightNodePool.popLast() {
            node.removeAllActions()
            node.removeAllChildren()
            node.alpha = 1.0
            return node
        }
        return SKNode()
    }
    
    func returnHighlightNode(_ node: SKNode) {
        guard highlightNodePool.count < maxPoolSize else {
            node.removeFromParent()
            return
        }
        
        node.removeAllActions()
        node.removeAllChildren()
        node.alpha = 0
        highlightNodePool.append(node)
    }
    
    // MARK: - Preview Nodes
    func getPreviewNode() -> SKNode {
        if let node = previewNodePool.popLast() {
            node.removeAllActions()
            node.removeAllChildren()
            node.alpha = 1.0
            return node
        }
        return SKNode()
    }
    
    func returnPreviewNode(_ node: SKNode) {
        guard previewNodePool.count < maxPoolSize else {
            node.removeFromParent()
            return
        }
        
        node.removeAllActions()
        node.removeAllChildren()
        node.alpha = 0
        previewNodePool.append(node)
    }
    
    // MARK: - Pool Management
    private func preWarmPools() async {
        // Create initial pool of nodes
        for _ in 0..<minPoolSize {
            await MainActor.run {
                blockNodePool.append(SKNode())
                highlightNodePool.append(SKNode())
                previewNodePool.append(SKNode())
                if let emitter = SKEmitterNode(fileNamed: "ParticleEffect") {
                    particleEmitterPool.append(emitter)
                }
            }
        }
    }
    
    func cleanupPools() {
        // Trim pools to minimum size
        while blockNodePool.count > minPoolSize {
            blockNodePool.removeLast().removeFromParent()
        }
        while particleEmitterPool.count > minPoolSize {
            particleEmitterPool.removeLast().removeFromParent()
        }
        while highlightNodePool.count > minPoolSize {
            highlightNodePool.removeLast().removeFromParent()
        }
        while previewNodePool.count > minPoolSize {
            previewNodePool.removeLast().removeFromParent()
        }
    }
    
    func clearAllPools() {
        blockNodePool.forEach { $0.removeFromParent() }
        particleEmitterPool.forEach { $0.removeFromParent() }
        highlightNodePool.forEach { $0.removeFromParent() }
        previewNodePool.forEach { $0.removeFromParent() }
        
        blockNodePool.removeAll()
        particleEmitterPool.removeAll()
        highlightNodePool.removeAll()
        previewNodePool.removeAll()
    }
} 