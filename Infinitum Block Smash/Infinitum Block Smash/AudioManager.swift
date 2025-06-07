import Foundation
import AVFoundation
import AudioToolbox

class AudioManager {
    static let shared = AudioManager()
    
    private var backgroundMusic: AVAudioPlayer?
    private var soundEffects: [String: AVAudioPlayer] = [:]
    private var isMuted: Bool = false
    private var audioSession: AVAudioSession?
    
    private init() {
        setupAudioSession()
        loadSounds()
        loadSettings() // Load saved settings on init
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func loadSounds() {
        // Load background music with reduced memory usage
        if let musicURL = Bundle.main.url(forResource: "background_music", withExtension: "mp3") {
            do {
                let data = try Data(contentsOf: musicURL)
                backgroundMusic = try AVAudioPlayer(data: data)
                backgroundMusic?.numberOfLoops = -1
                backgroundMusic?.prepareToPlay()
            } catch {
                print("Failed to load background music: \(error)")
            }
        }
        
        // Clear existing sound effects
        cleanupSoundEffects()
        
        // Load only essential sound effects initially
        loadEssentialSoundEffects()
    }
    
    private func loadEssentialSoundEffects() {
        // Only load the most frequently used sound effect
        if let url = Bundle.main.url(forResource: "placement", withExtension: "wav") {
            do {
                let data = try Data(contentsOf: url)
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay()
                self.soundEffects["placement"] = player
            } catch {
                print("Failed to load placement sound effect: \(error)")
            }
        }
    }
    
    func loadSoundEffect(_ name: String) {
        guard soundEffects[name] == nil else { return }
        
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            do {
                let data = try Data(contentsOf: url)
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay()
                self.soundEffects[name] = player
            } catch {
                print("Failed to load sound effect \(name): \(error)")
            }
        }
    }
    
    func playSoundEffect(_ name: String) {
        if soundEffects[name] == nil {
            loadSoundEffect(name)
        }
        guard !isMuted else { return }
        soundEffects[name]?.play()
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
    
    func playPlacementSound() {
        guard !isMuted else { return }
        // System sound for block placement (a light tap sound)
        AudioServicesPlaySystemSound(1104) // System sound for a light tap
    }
    
    func playLevelCompleteSound() {
        guard !isMuted else { return }
        // System sound for level completion (a success sound)
        AudioServicesPlaySystemSound(1519) // System sound for success
    }
    
    func playFailSound() {
        guard !isMuted else { return }
        // System sound for failure (warning sound)
        AudioServicesPlaySystemSound(1005) // System sound for warning/alert
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
        
        // Save settings to UserDefaults
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
        UserDefaults.standard.set(sfxVolume, forKey: "sfxVolume")
        UserDefaults.standard.synchronize()
        
        if soundEnabled {
            playBackgroundMusic()
        } else {
            stopBackgroundMusic()
        }
    }
    
    private func loadSettings() {
        let soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        let musicVolume = UserDefaults.standard.double(forKey: "musicVolume")
        let sfxVolume = UserDefaults.standard.double(forKey: "sfxVolume")
        
        updateSettings(soundEnabled: soundEnabled, musicVolume: musicVolume, sfxVolume: sfxVolume)
    }
    
    private func cleanupSoundEffects() {
        for (_, player) in soundEffects {
            player.stop()
        }
        soundEffects.removeAll()
    }
    
    func cleanup() {
        // Stop and cleanup all audio
        stopBackgroundMusic()
        cleanupSoundEffects()
        backgroundMusic = nil
        
        // Deactivate audio session
        try? audioSession?.setActive(false)
        audioSession = nil
    }
    
    deinit {
        cleanup()
    }
} 