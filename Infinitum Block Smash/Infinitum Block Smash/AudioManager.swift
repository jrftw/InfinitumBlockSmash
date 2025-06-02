import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var backgroundMusic: AVAudioPlayer?
    private var soundEffects: [String: AVAudioPlayer] = [:]
    private var isMuted: Bool = false
    
    private init() {
        setupAudioSession()
        loadSounds()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func loadSounds() {
        // Load background music
        if let musicURL = Bundle.main.url(forResource: "background_music", withExtension: "mp3") {
            do {
                backgroundMusic = try AVAudioPlayer(contentsOf: musicURL)
                backgroundMusic?.numberOfLoops = -1 // Infinite loop
                backgroundMusic?.prepareToPlay()
            } catch {
                print("Failed to load background music: \(error)")
            }
        }
        
        // Load sound effects
        let soundEffects = [
            "placement": "placement",
            "combo": "combo",
            "level_up": "level_up",
            "game_over": "game_over"
        ]
        
        for (key, filename) in soundEffects {
            if let url = Bundle.main.url(forResource: filename, withExtension: "wav") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    self.soundEffects[key] = player
                } catch {
                    print("Failed to load sound effect \(filename): \(error)")
                }
            }
        }
    }
    
    func playBackgroundMusic() {
        guard !isMuted else { return }
        backgroundMusic?.play()
    }
    
    func stopBackgroundMusic() {
        backgroundMusic?.stop()
    }
    
    func playSound(_ name: String) {
        guard !isMuted else { return }
        soundEffects[name]?.play()
    }
    
    func setMusicVolume(_ volume: Float) {
        backgroundMusic?.volume = volume
    }
    
    func setSoundEffectsVolume(_ volume: Float) {
        for player in soundEffects.values {
            player.volume = volume
        }
    }
    
    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            stopBackgroundMusic()
        } else {
            playBackgroundMusic()
        }
    }
    
    func updateSettings(soundEnabled: Bool, musicVolume: Double, sfxVolume: Double) {
        isMuted = !soundEnabled
        setMusicVolume(Float(musicVolume))
        setSoundEffectsVolume(Float(sfxVolume))
        
        if soundEnabled {
            playBackgroundMusic()
        } else {
            stopBackgroundMusic()
        }
    }
} 