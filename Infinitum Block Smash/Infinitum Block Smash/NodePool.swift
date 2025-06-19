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
            node.removeAllActions()
            node.removeAllChildren()
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
            emitter.removeAllActions()
            emitter.particleBirthRate = 0
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
            node.removeAllActions()
            node.removeAllChildren()
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
            node.removeAllActions()
            node.removeAllChildren()
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
        
        // Pre-create some common node types for better performance
        await MainActor.run {
            // Pre-create some preview nodes with common shapes
            for _ in 0..<5 {
                let previewNode = SKNode()
                previewNode.name = "preview_block"
                previewNode.zPosition = 5
                previewNodePool.append(previewNode)
            }
            
            // Pre-create some highlight containers
            for _ in 0..<3 {
                let highlightNode = SKNode()
                highlightNode.name = "highlight_container"
                highlightNode.zPosition = 10
                highlightNodePool.append(highlightNode)
            }
        }
    }
    
    func cleanupPools() {
        Logger.shared.log("Cleaning up node pools", category: .systemMemory, level: .info)
        
        // Trim pools to minimum size
        while blockNodePool.count > minPoolSize {
            let node = blockNodePool.removeLast()
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        while particleEmitterPool.count > minPoolSize {
            let emitter = particleEmitterPool.removeLast()
            emitter.removeAllActions()
            emitter.particleBirthRate = 0
            emitter.removeFromParent()
        }
        while highlightNodePool.count > minPoolSize {
            let node = highlightNodePool.removeLast()
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        while previewNodePool.count > minPoolSize {
            let node = previewNodePool.removeLast()
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        
        Logger.shared.log("Node pools cleaned up", category: .systemMemory, level: .info)
    }
    
    func clearAllPools() {
        Logger.shared.log("Clearing all node pools", category: .systemMemory, level: .warning)
        
        // Clear all pools completely
        blockNodePool.forEach { node in
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        blockNodePool.removeAll()
        
        particleEmitterPool.forEach { emitter in
            emitter.removeAllActions()
            emitter.particleBirthRate = 0
            emitter.removeFromParent()
        }
        particleEmitterPool.removeAll()
        
        highlightNodePool.forEach { node in
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        highlightNodePool.removeAll()
        
        previewNodePool.forEach { node in
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        previewNodePool.removeAll()
        
        Logger.shared.log("All node pools cleared", category: .systemMemory, level: .info)
    }
} 