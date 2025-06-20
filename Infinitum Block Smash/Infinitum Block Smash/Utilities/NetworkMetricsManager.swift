import Foundation
import Network
import UIKit

class NetworkMetricsManager: ObservableObject {
    static let shared = NetworkMetricsManager()
    
    @Published private(set) var ping: Double = 0.0
    @Published private(set) var bitrate: Double = 0.0
    @Published private(set) var jitter: Double = 0.0
    @Published private(set) var decodeTime: Double = 0.0
    @Published private(set) var packetLoss: Double = 0.0
    @Published private(set) var resolution: String = "Unknown"
    
    private var pingTimer: Timer?
    private var metricsTimer: Timer?
    private var pingHistory: [Double] = []
    private let maxPingHistory = 10
    
    private init() {
        updateResolution()
        startMetricsCollection()
    }
    
    deinit {
        stopMetricsCollection()
    }
    
    private func updateResolution() {
        let screen = UIScreen.main
        let scale = screen.scale
        let bounds = screen.bounds
        
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        
        resolution = "\(width) × \(height)"
    }
    
    private func startMetricsCollection() {
        // Update ping every 2 seconds
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updatePing()
        }
        
        // Update other metrics every 5 seconds
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateOtherMetrics()
        }
        
        // Initial update
        updatePing()
        updateOtherMetrics()
    }
    
    private func stopMetricsCollection() {
        pingTimer?.invalidate()
        pingTimer = nil
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    private func updatePing() {
        // Simulate ping measurement to a game server
        // In a real implementation, you would ping your actual game server
        let simulatedPing = Double.random(in: 15...150)
        
        pingHistory.append(simulatedPing)
        if pingHistory.count > maxPingHistory {
            pingHistory.removeFirst()
        }
        
        // Calculate average ping
        ping = pingHistory.reduce(0, +) / Double(pingHistory.count)
        
        // Calculate jitter (variation in ping times)
        if pingHistory.count > 1 {
            let differences = zip(pingHistory.dropFirst(), pingHistory).map { abs($0 - $1) }
            jitter = differences.reduce(0, +) / Double(differences.count)
        }
    }
    
    private func updateOtherMetrics() {
        // Simulate bitrate measurement
        // In a real implementation, you would measure actual network throughput
        bitrate = Double.random(in: 1.0...50.0) // Mbps
        
        // Simulate decode time (time to decode game data)
        // In a real implementation, you would measure actual decode performance
        decodeTime = Double.random(in: 0.1...5.0) // milliseconds
        
        // Simulate packet loss
        // In a real implementation, you would measure actual packet loss
        packetLoss = Double.random(in: 0.0...2.0) // percentage
    }
    
    // Public method to get current metrics as a dictionary
    func getCurrentMetrics() -> [String: Any] {
        return [
            "ping": ping,
            "bitrate": bitrate,
            "jitter": jitter,
            "decodeTime": decodeTime,
            "packetLoss": packetLoss,
            "resolution": resolution
        ]
    }
    
    // Method to manually trigger a ping update (useful for testing)
    func forceUpdate() {
        updatePing()
        updateOtherMetrics()
    }
} 