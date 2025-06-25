/******************************************************
 * FILE: NodePool.swift
 * MARK: SpriteKit Node Object Pooling System
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides object pooling for SpriteKit nodes to optimize memory usage
 * and performance by reusing node instances instead of creating new ones.
 *
 * KEY RESPONSIBILITIES:
 * - Pool management for block nodes, particle emitters, and highlight nodes
 * - Node lifecycle management and cleanup
 * - Memory optimization through object reuse
 * - Pool size management and limits
 * - Pre-warming pools for better performance
 * - Thread-safe pool operations
 *
 * MAJOR DEPENDENCIES:
 * - SpriteKit: Core framework for node types
 * - Logger.swift: Logging pool operations
 * - Foundation: Core framework for data structures
 * - MainActor: Thread safety for UI operations
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SpriteKit: Game development framework for nodes
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as a performance optimization layer that reduces
 * memory allocation overhead and improves game performance.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Pool operations must be thread-safe
 * - Node cleanup must be thorough and complete
 * - Pool sizes must be managed to prevent memory leaks
 * - Pre-warming must occur on main thread
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify pool memory usage stays within limits
 * - Test node reuse efficiency and correctness
 * - Check thread safety of pool operations
 * - Validate pool cleanup effectiveness
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add pool analytics and metrics
 * - Implement adaptive pool sizing
 * - Add more node type pools
 ******************************************************/

import SpriteKit

final class NodePool {
    static let shared = NodePool()
    
    // MARK: - Properties
    private var blockNodePool: [SKNode] = []
    private var particleEmitterPool: [SKEmitterNode] = []
    private var highlightNodePool: [SKNode] = []
    private var previewNodePool: [SKNode] = []
    
    private let maxPoolSize = 30
    private let minPoolSize = 5
    
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
            node.removeFromParent()
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
            emitter.removeFromParent()
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
            node.removeFromParent()
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
            node.removeFromParent()
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
            for _ in 0..<3 {
                let previewNode = SKNode()
                previewNode.name = "preview_block"
                previewNode.zPosition = 5
                previewNodePool.append(previewNode)
            }
            
            // Pre-create some highlight containers
            for _ in 0..<2 {
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
        Logger.shared.log("Clearing all node pools", category: .systemMemory, level: .info)
        
        // Clear all pools
        blockNodePool.removeAll()
        particleEmitterPool.removeAll()
        highlightNodePool.removeAll()
        previewNodePool.removeAll()
        
        Logger.shared.log("All node pools cleared", category: .systemMemory, level: .info)
    }
    
    /// Get pool status for diagnostics
    func getPoolStatus() -> String {
        return """
        Pool Status:
        - Block Nodes: \(blockNodePool.count)/\(maxPoolSize)
        - Particle Emitters: \(particleEmitterPool.count)/\(maxPoolSize)
        - Highlight Nodes: \(highlightNodePool.count)/\(maxPoolSize)
        - Preview Nodes: \(previewNodePool.count)/\(maxPoolSize)
        """
    }
} 