import Foundation
import UIKit
import SpriteKit
import Combine

class FPSManager: ObservableObject {
    static let shared = FPSManager()
    
    private let userDefaults = UserDefaults.standard
    private let targetFPSKey = "targetFPS"
    
    // Available FPS options based on device capabilities
    @Published private(set) var availableFPSOptions: [Int]
    
    // Current target FPS
    @Published private(set) var targetFPS: Int
    
    private init() {
        // Get device's maximum refresh rate
        let maxRefreshRate = UIScreen.main.maximumFramesPerSecond
        
        // Build available FPS options based on device capabilities
        var options: [Int] = [30] // 30 FPS is always available
        
        if maxRefreshRate >= 60 {
            options.append(60)
        }
        
        if maxRefreshRate >= 120 {
            options.append(120)
        }
        
        // Add unlimited option (0) if device supports ProMotion
        if maxRefreshRate > 60 {
            options.append(0)
        }
        
        // Initialize properties in correct order
        self.availableFPSOptions = options
        
        // Load saved FPS or use default based on device capabilities
        let savedFPS = userDefaults.integer(forKey: targetFPSKey)
        if savedFPS == 0 || !options.contains(savedFPS) {
            self.targetFPS = options.first ?? 30
        } else {
            self.targetFPS = savedFPS
        }
    }
    
    func setTargetFPS(_ fps: Int) {
        // Only set if it's a valid option
        if availableFPSOptions.contains(fps) {
            targetFPS = fps
            userDefaults.set(fps, forKey: targetFPSKey)
            userDefaults.synchronize()
            
            // Notify any observers that FPS has changed
            NotificationCenter.default.post(name: .fpsDidChange, object: nil, userInfo: ["fps": fps])
        }
    }
    
    func getDisplayFPS(for targetFPS: Int) -> Int {
        // If unlimited (0) is selected, use device's maximum refresh rate
        if targetFPS == 0 {
            return UIScreen.main.maximumFramesPerSecond
        }
        return targetFPS
    }
    
    func getFPSDisplayName(for fps: Int) -> String {
        if fps == 0 {
            return "Unlimited"
        }
        return "\(fps) FPS"
    }
}
