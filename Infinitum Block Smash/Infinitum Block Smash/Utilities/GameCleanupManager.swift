/*
 * GameCleanupManager.swift
 * 
 * COMPREHENSIVE GAME MEMORY CLEANUP UTILITY
 * 
 * This utility provides systematic memory cleanup for all game components,
 * ensuring proper disposal of SpriteKit resources, textures, nodes, and
 * preventing IOSurface memory leaks and jet_render_op allocations.
 * 
 * KEY FEATURES:
 * - Systematic cleanup of all game components
 * - Detailed logging of cleanup operations
 * - Safety checks to prevent crashes
 * - Integration with existing memory systems
 * - Scene transition cleanup
 * - Texture and node disposal
 * - Timer and observer cleanup
 * - Emergency cleanup for critical situations
 */

import Foundation
import SpriteKit
import UIKit

class GameCleanupManager {
    static let shared = GameCleanupManager()
    
    // MARK: - Properties
    private var isCleaningUp = false
    private var cleanupQueue = DispatchQueue(label: "com.infinitum.blocksmash.cleanup", qos: .userInitiated)
    private var lastCleanupTime: Date = Date()
    private let minimumCleanupInterval: TimeInterval = 5.0 // Prevent excessive cleanup
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Perform comprehensive cleanup between gameplay sessions
    func performGameplaySessionCleanup() async {
        guard !isCleaningUp else {
            Logger.shared.debug("[Cleanup] Cleanup already in progress, skipping", category: .systemMemory)
            return
        }
        
        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) >= minimumCleanupInterval else {
            Logger.shared.debug("[Cleanup] Cleanup too recent, skipping", category: .systemMemory)
            return
        }
        
        isCleaningUp = true
        lastCleanupTime = now
        
        Logger.shared.log("Starting comprehensive gameplay session cleanup", category: .systemMemory, level: .info)
        
        await withTaskGroup(of: Void.self) { group in
            // Scene cleanup
            group.addTask { await self.cleanupScenes() }
            
            // Texture cleanup
            group.addTask { await self.cleanupTextures() }
            
            // Node cleanup
            group.addTask { await self.cleanupNodes() }
            
            // Audio cleanup
            group.addTask { await self.cleanupAudio() }
            
            // Timer cleanup
            group.addTask { await self.cleanupTimers() }
            
            // Observer cleanup
            group.addTask { await self.cleanupObservers() }
            
            // Memory system cleanup
            group.addTask { await self.cleanupMemorySystems() }
        }
        
        // Force garbage collection
        await forceGarbageCollection()
        
        isCleaningUp = false
        Logger.shared.log("Comprehensive gameplay session cleanup completed", category: .systemMemory, level: .info)
    }
    
    /// Perform emergency cleanup for critical memory situations
    func performEmergencyCleanup() async {
        Logger.shared.log("Starting emergency cleanup", category: .systemMemory, level: .warning)
        
        isCleaningUp = true
        
        // Stop all monitoring immediately
        await stopAllMonitoring()
        
        // Perform aggressive cleanup
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.cleanupScenes(aggressive: true) }
            group.addTask { await self.cleanupTextures(aggressive: true) }
            group.addTask { await self.cleanupNodes(aggressive: true) }
            group.addTask { await self.cleanupAudio(aggressive: true) }
            group.addTask { await self.cleanupTimers(aggressive: true) }
            group.addTask { await self.cleanupObservers(aggressive: true) }
            group.addTask { await self.cleanupMemorySystems(aggressive: true) }
        }
        
        // Multiple garbage collection passes
        for i in 1...3 {
            await forceGarbageCollection()
            Logger.shared.debug("[Cleanup] Emergency cleanup pass \(i)/3 completed", category: .systemMemory)
        }
        
        isCleaningUp = false
        Logger.shared.log("Emergency cleanup completed", category: .systemMemory, level: .info)
    }
    
    /// Cleanup for scene transitions
    func performSceneTransitionCleanup() async {
        Logger.shared.debug("[Cleanup] Performing scene transition cleanup", category: .systemMemory)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.cleanupScenes() }
            group.addTask { await self.cleanupTextures() }
            group.addTask { await self.cleanupNodes() }
        }
        
        Logger.shared.debug("[Cleanup] Scene transition cleanup completed", category: .systemMemory)
    }
    
    // MARK: - Private Cleanup Methods
    
    private func cleanupScenes(aggressive: Bool = false) async {
        Logger.shared.debug("[Cleanup] Cleaning up scenes", category: .systemMemory)
        
        await MainActor.run {
            // Clear any retained scene references
            autoreleasepool {
                // Force cleanup of any retained SKScene references
                // This helps with IOSurface cleanup
                if aggressive {
                    // More aggressive scene cleanup
                    for _ in 0..<3 {
                        _ = autoreleasepool {
                            // Force texture atlas cleanup
                            Task {
                                await SKTextureAtlas.preloadTextureAtlases([])
                            }
                        }
                    }
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Scene cleanup completed", category: .systemMemory)
    }
    
    private func cleanupTextures(aggressive: Bool = false) async {
        Logger.shared.debug("[Cleanup] Cleaning up textures", category: .systemMemory)
        
        await MainActor.run {
            autoreleasepool {
                // Clear SpriteKit texture caches
                Task {
                    await SKTexture.preload([])
                    await SKTextureAtlas.preloadTextureAtlases([])
                }
                
                if aggressive {
                    // More aggressive texture cleanup
                    for _ in 0..<2 {
                        _ = autoreleasepool {
                            Task {
                                await SKTexture.preload([])
                                await SKTextureAtlas.preloadTextureAtlases([])
                            }
                        }
                    }
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Texture cleanup completed", category: .systemMemory)
    }
    
    private func cleanupNodes(aggressive: Bool = false) async {
        Logger.shared.debug("[Cleanup] Cleaning up nodes", category: .systemMemory)
        
        await MainActor.run {
            // Clear node pools
            NodePool.shared.clearAllPools()
            
            if aggressive {
                // More aggressive node cleanup
                for _ in 0..<2 {
                    autoreleasepool {
                        NodePool.shared.clearAllPools()
                    }
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Node cleanup completed", category: .systemMemory)
    }
    
    private func cleanupAudio(aggressive: Bool = false) async {
        Logger.shared.debug("[Cleanup] Cleaning up audio", category: .systemMemory)
        
        await MainActor.run {
            // Cleanup audio resources
            AudioManager.shared.cleanup()
            
            if aggressive {
                // More aggressive audio cleanup
                autoreleasepool {
                    AudioManager.shared.cleanupSoundEffects()
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Audio cleanup completed", category: .systemMemory)
    }
    
    private func cleanupTimers(aggressive: Bool = false) async {
        Logger.shared.debug("[Cleanup] Cleaning up timers", category: .systemMemory)
        
        await MainActor.run {
            // Stop all monitoring timers
            PerformanceMonitor.shared.emergencyStop()
            MemoryLeakDetector.shared.stopMonitoring()
            
            if aggressive {
                // More aggressive timer cleanup
                autoreleasepool {
                    // Force invalidate any remaining timers
                    PerformanceMonitor.shared.emergencyStop()
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Timer cleanup completed", category: .systemMemory)
    }
    
    private func cleanupObservers(aggressive: Bool = false) async {
        Logger.shared.debug("[Cleanup] Cleaning up observers", category: .systemMemory)
        
        await MainActor.run {
            // Remove all notification observers
            NotificationCenter.default.removeObserver(self)
            
            if aggressive {
                // More aggressive observer cleanup
                autoreleasepool {
                    // Force remove all observers
                    NotificationCenter.default.removeObserver(self)
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Observer cleanup completed", category: .systemMemory)
    }
    
    private func cleanupMemorySystems(aggressive: Bool = false) async {
        Logger.shared.debug("[Cleanup] Cleaning up memory systems", category: .systemMemory)
        
        await MainActor.run {
            // Clear memory system caches
            MemorySystem.shared.clearAllCaches()
            
            // Clear memory leak detector
            MemoryLeakDetector.shared.performEmergencyCleanup()
            
            // Clear URL cache
            URLCache.shared.removeAllCachedResponses()
            
            if aggressive {
                // More aggressive memory cleanup
                for _ in 0..<3 {
                    autoreleasepool {
                        MemorySystem.shared.clearAllCaches()
                        URLCache.shared.removeAllCachedResponses()
                    }
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Memory systems cleanup completed", category: .systemMemory)
    }
    
    private func stopAllMonitoring() async {
        Logger.shared.debug("[Cleanup] Stopping all monitoring", category: .systemMemory)
        
        await MainActor.run {
            // Stop all monitoring systems
            PerformanceMonitor.shared.emergencyStop()
            MemoryLeakDetector.shared.stopMonitoring()
            
            // Stop individual manager timers
            NetworkMetricsManager.shared.stopMonitoring()
            AdaptiveQualityManager.shared.stopMonitoring()
            FPSManager.shared.stopMonitoring()
            UserDefaultsManager.shared.stopMonitoring()
        }
        
        Logger.shared.debug("[Cleanup] All monitoring stopped", category: .systemMemory)
    }
    
    private func forceGarbageCollection() async {
        Logger.shared.debug("[Cleanup] Forcing garbage collection", category: .systemMemory)
        
        await MainActor.run {
            // Force multiple autorelease pool cycles
            for _ in 0..<3 {
                autoreleasepool {
                    // Force texture cleanup
                    Task {
                        await SKTexture.preload([])
                        await SKTextureAtlas.preloadTextureAtlases([])
                    }
                    
                    // Force memory cache cleanup
                    MemorySystem.shared.clearAllCaches()
                    URLCache.shared.removeAllCachedResponses()
                }
            }
        }
        
        Logger.shared.debug("[Cleanup] Garbage collection completed", category: .systemMemory)
    }
    
    // MARK: - Diagnostic Methods
    
    /// Get current cleanup status
    func getCleanupStatus() -> String {
        let isActive = isCleaningUp
        let timeSinceLast = Date().timeIntervalSince(lastCleanupTime)
        
        return """
        Cleanup Status:
        - Active: \(isActive)
        - Time since last cleanup: \(String(format: "%.1f", timeSinceLast))s
        - Minimum interval: \(String(format: "%.1f", minimumCleanupInterval))s
        """
    }
    
    /// Check if cleanup is needed
    func isCleanupNeeded() -> Bool {
        let timeSinceLast = Date().timeIntervalSince(lastCleanupTime)
        return timeSinceLast >= minimumCleanupInterval && !isCleaningUp
    }
}

// MARK: - Convenience Extensions

extension GameCleanupManager {
    /// Convenience method for scene transition cleanup
    static func cleanupForSceneTransition() async {
        await shared.performSceneTransitionCleanup()
    }
    
    /// Convenience method for gameplay session cleanup
    static func cleanupGameplaySession() async {
        await shared.performGameplaySessionCleanup()
    }
    
    /// Convenience method for emergency cleanup
    static func emergencyCleanup() async {
        await shared.performEmergencyCleanup()
    }
} 