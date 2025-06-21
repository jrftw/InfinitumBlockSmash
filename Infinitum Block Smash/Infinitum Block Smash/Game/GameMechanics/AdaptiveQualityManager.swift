/*
 * AdaptiveQualityManager.swift
 * 
 * ADAPTIVE QUALITY MANAGEMENT SYSTEM
 * 
 * This service manages dynamic quality settings based on device thermal state,
 * battery level, and performance conditions to prevent overheating and optimize
 * battery life while maintaining good gameplay experience.
 * 
 * KEY RESPONSIBILITIES:
 * - Dynamic quality adjustment based on thermal state
 * - Battery-aware performance optimization
 * - Adaptive particle effect management
 * - Background animation control
 * - Performance recommendation system
 * - Quality level management
 * 
 * MAJOR DEPENDENCIES:
 * - FPSManager.swift: Thermal and battery state monitoring
 * - GameScene.swift: Visual quality adjustments
 * - DeviceSimulator.swift: Device capability detection
 * - Logger.swift: Performance logging
 */

import Foundation
import UIKit
import SpriteKit

class AdaptiveQualityManager: ObservableObject {
    static let shared = AdaptiveQualityManager()
    
    // MARK: - Published Properties
    @Published private(set) var currentQualityLevel: QualityLevel = .high
    @Published private(set) var isPerformanceReduced: Bool = false
    @Published private(set) var performanceReason: String = ""
    
    // MARK: - Quality Settings
    struct QualitySettings {
        let enableParticles: Bool
        let enableBackgroundAnimations: Bool
        let maxFPS: Int
        let enableShadows: Bool
        let particleIntensity: CGFloat
        let animationIntensity: CGFloat
        let textureQuality: TextureQuality
    }
    
    enum QualityLevel: String, CaseIterable, Comparable {
        case ultra = "Ultra"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case minimal = "Minimal"
        
        // Implement Comparable
        static func < (lhs: QualityLevel, rhs: QualityLevel) -> Bool {
            let order: [QualityLevel] = [.ultra, .high, .medium, .low, .minimal]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex > rhsIndex // Higher index = lower quality
        }
    }
    
    enum TextureQuality: String, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
    
    // MARK: - Private Properties
    private let fpsManager = FPSManager.shared
    private let deviceSimulator = DeviceSimulator.shared
    private var qualityUpdateTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        startQualityMonitoring()
    }
    
    deinit {
        qualityUpdateTimer?.invalidate()
    }
    
    // MARK: - Quality Monitoring
    
    private func startQualityMonitoring() {
        // Update quality settings every 3 seconds
        qualityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateQualitySettings()
        }
    }
    
    private func updateQualitySettings() {
        let newQualityLevel = determineOptimalQualityLevel()
        let newSettings = getQualitySettings(for: newQualityLevel)
        
        if newQualityLevel != currentQualityLevel {
            currentQualityLevel = newQualityLevel
            Logger.shared.debug("[Quality] Quality level changed to: \(newQualityLevel.rawValue)", category: .systemMemory)
        }
        
        // Update performance reduction status
        let shouldReduce = fpsManager.shouldReducePerformance
        if shouldReduce != isPerformanceReduced {
            isPerformanceReduced = shouldReduce
            performanceReason = getPerformanceReductionReason()
            
            if shouldReduce {
                Logger.shared.debug("[Quality] Performance reduced: \(performanceReason)", category: .systemMemory)
            } else {
                Logger.shared.debug("[Quality] Performance restored - conditions improved", category: .systemMemory)
            }
        }
        
        // Apply quality settings
        applyQualitySettings(newSettings)
    }
    
    // MARK: - Quality Level Determination
    
    private func determineOptimalQualityLevel() -> QualityLevel {
        // Start with device capability
        var qualityLevel: QualityLevel = .high
        
        // Apply thermal state adjustments
        switch fpsManager.thermalState {
        case .critical:
            qualityLevel = .minimal
        case .serious:
            qualityLevel = .low
        case .fair:
            qualityLevel = .medium
        case .nominal:
            qualityLevel = .high
        @unknown default:
            qualityLevel = .medium
        }
        
        // Apply battery level adjustments
        if fpsManager.batteryLevel < 0.1 { // Below 10%
            qualityLevel = .minimal
        } else if fpsManager.batteryLevel < 0.2 { // Below 20%
            qualityLevel = min(qualityLevel, .low)
        } else if fpsManager.batteryLevel < 0.3 { // Below 30%
            qualityLevel = min(qualityLevel, .medium)
        }
        
        // Apply low power mode adjustment
        if fpsManager.isLowPowerMode {
            qualityLevel = min(qualityLevel, .low)
        }
        
        // Apply device-specific adjustments
        if deviceSimulator.isLowEndDevice() {
            qualityLevel = min(qualityLevel, .medium)
        }
        
        return qualityLevel
    }
    
    // MARK: - Quality Settings
    
    func getQualitySettings(for level: QualityLevel) -> QualitySettings {
        switch level {
        case .ultra:
            return QualitySettings(
                enableParticles: true,
                enableBackgroundAnimations: true,
                maxFPS: 120,
                enableShadows: true,
                particleIntensity: 1.0,
                animationIntensity: 1.0,
                textureQuality: .high
            )
        case .high:
            return QualitySettings(
                enableParticles: true,
                enableBackgroundAnimations: true,
                maxFPS: 60,
                enableShadows: true,
                particleIntensity: 0.8,
                animationIntensity: 0.8,
                textureQuality: .high
            )
        case .medium:
            return QualitySettings(
                enableParticles: true,
                enableBackgroundAnimations: false,
                maxFPS: 60,
                enableShadows: false,
                particleIntensity: 0.5,
                animationIntensity: 0.0,
                textureQuality: .medium
            )
        case .low:
            return QualitySettings(
                enableParticles: false,
                enableBackgroundAnimations: false,
                maxFPS: 30,
                enableShadows: false,
                particleIntensity: 0.0,
                animationIntensity: 0.0,
                textureQuality: .low
            )
        case .minimal:
            return QualitySettings(
                enableParticles: false,
                enableBackgroundAnimations: false,
                maxFPS: 30,
                enableShadows: false,
                particleIntensity: 0.0,
                animationIntensity: 0.0,
                textureQuality: .low
            )
        }
    }
    
    // MARK: - Quality Application
    
    private func applyQualitySettings(_ settings: QualitySettings) {
        // Notify observers of quality changes
        NotificationCenter.default.post(
            name: .qualitySettingsDidChange,
            object: nil,
            userInfo: ["settings": settings]
        )
    }
    
    // MARK: - Performance Monitoring
    
    private func getPerformanceReductionReason() -> String {
        var reasons: [String] = []
        
        switch fpsManager.thermalState {
        case .critical:
            reasons.append("Critical thermal state")
        case .serious:
            reasons.append("High thermal state")
        case .fair:
            reasons.append("Moderate thermal state")
        case .nominal:
            break
        @unknown default:
            break
        }
        
        if fpsManager.batteryLevel < 0.2 {
            reasons.append("Low battery (\(Int(fpsManager.batteryLevel * 100))%)")
        }
        
        if fpsManager.isLowPowerMode {
            reasons.append("Low power mode")
        }
        
        return reasons.joined(separator: ", ")
    }
    
    // MARK: - Public Interface
    
    /// Get current quality settings
    func getCurrentQualitySettings() -> QualitySettings {
        return getQualitySettings(for: currentQualityLevel)
    }
    
    /// Check if particles should be enabled
    func shouldEnableParticles() -> Bool {
        return getCurrentQualitySettings().enableParticles
    }
    
    /// Check if background animations should be enabled
    func shouldEnableBackgroundAnimations() -> Bool {
        return getCurrentQualitySettings().enableBackgroundAnimations
    }
    
    /// Get recommended particle intensity
    func getParticleIntensity() -> CGFloat {
        return getCurrentQualitySettings().particleIntensity
    }
    
    /// Get recommended animation intensity
    func getAnimationIntensity() -> CGFloat {
        return getCurrentQualitySettings().animationIntensity
    }
    
    /// Get performance recommendations
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if fpsManager.thermalState == .critical {
            recommendations.append("Device is overheating. Consider taking a break or reducing usage.")
        } else if fpsManager.thermalState == .serious {
            recommendations.append("Device is getting warm. Performance reduced to prevent overheating.")
        }
        
        if fpsManager.batteryLevel < 0.2 {
            recommendations.append("Low battery detected. Performance optimized for battery life.")
        }
        
        if fpsManager.isLowPowerMode {
            recommendations.append("Low power mode enabled. Performance reduced to save battery.")
        }
        
        if deviceSimulator.isLowEndDevice() {
            recommendations.append("Running on a device with limited resources. Performance optimized.")
        }
        
        return recommendations
    }
    
    /// Force quality update
    func forceQualityUpdate() {
        updateQualitySettings()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let qualitySettingsDidChange = Notification.Name("qualitySettingsDidChange")
} 