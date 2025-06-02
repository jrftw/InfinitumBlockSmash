import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var backgroundMusic: AVAudioPlayer?
    private var soundEffects: [String: AVAudioPlayer] = [:]
    private var isMuted: Bool = false
    private var volume: Float = 1.0
    private var musicVolume: Float = 0.7
    private var sfxVolume: Float = 0.7
    private var preloadedSounds: Set<String> = []
    
    private init() {
        setupAudioSession()
        loadSettings()
        loadSounds()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isMuted = !defaults.bool(forKey: "soundEnabled")
        musicVolume = Float(defaults.double(forKey: "musicVolume"))
        sfxVolume = Float(defaults.double(forKey: "sfxVolume"))
    }
    
    private func loadSounds() {
        // Load background music
        if let musicURL = Bundle.main.url(forResource: "background_music", withExtension: "mp3") {
            do {
                backgroundMusic = try AVAudioPlayer(contentsOf: musicURL)
                backgroundMusic?.numberOfLoops = -1 // Infinite loop
                backgroundMusic?.volume = musicVolume
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
                    player.volume = sfxVolume
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
        guard !isMuted, let player = soundEffects[name] else { return }
        
        // If the sound is already playing, stop it and reset to beginning
        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        
        player.play()
    }
    
    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            stopBackgroundMusic()
        } else {
            playBackgroundMusic()
        }
        UserDefaults.standard.set(!muted, forKey: "soundEnabled")
    }
    
    func setMusicVolume(_ volume: Float) {
        musicVolume = volume
        backgroundMusic?.volume = volume
        UserDefaults.standard.set(Double(volume), forKey: "musicVolume")
    }
    
    func setSFXVolume(_ volume: Float) {
        sfxVolume = volume
        for player in soundEffects.values {
            player.volume = volume
        }
        UserDefaults.standard.set(Double(volume), forKey: "sfxVolume")
    }
    
    func preloadSound(_ name: String) {
        guard !preloadedSounds.contains(name),
              let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = sfxVolume
            soundEffects[name] = player
            preloadedSounds.insert(name)
        } catch {
            print("Failed to preload sound effect \(name): \(error)")
        }
    }
    
    func cleanup() {
        stopBackgroundMusic()
        for player in soundEffects.values {
            player.stop()
        }
        soundEffects.removeAll()
        preloadedSounds.removeAll()
    }
} 