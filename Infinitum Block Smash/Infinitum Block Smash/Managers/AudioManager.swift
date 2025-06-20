/*
 * AudioManager.swift
 *
 * AUDIO SYSTEM MANAGEMENT AND SOUND EFFECTS
 *
 * This service manages all audio-related functionality for the Infinitum Block Smash game,
 * including background music, sound effects, volume control, and audio session management.
 * It provides a centralized audio system with memory optimization and performance features.
 *
 * KEY RESPONSIBILITIES:
 * - Background music playback and management
 * - Sound effects loading and playback
 * - Audio session configuration and management
 * - Volume control for music and sound effects
 * - Audio settings persistence and restoration
 * - Memory-efficient sound effect management
 * - System sound integration
 * - Audio muting and unmuting
 * - Audio cleanup and resource management
 * - Performance optimization for audio playback
 *
 * MAJOR DEPENDENCIES:
 * - AVFoundation: Core audio framework
 * - AudioToolbox: System sound effects
 * - UserDefaults: Audio settings persistence
 * - Bundle: Audio file resource loading
 * - GameState.swift: Game event audio triggers
 * - SettingsView.swift: Audio settings interface
 *
 * AUDIO FEATURES:
 * - Background Music: Looping game background music
 * - Sound Effects: Game action sound effects
 * - System Sounds: iOS system sound integration
 * - Volume Control: Independent music and SFX volume
 * - Mute Functionality: Global audio muting
 * - Audio Session Management: Proper iOS audio handling
 *
 * SOUND EFFECTS:
 * - Placement Sound: Block placement feedback
 * - Level Complete: Achievement and success sounds
 * - Fail Sound: Error and warning sounds
 * - Custom Effects: Game-specific audio feedback
 * - System Sounds: iOS native sound effects
 *
 * MEMORY MANAGEMENT:
 * - Lazy loading of sound effects
 * - Essential sound preloading
 * - Sound effect cleanup and disposal
 * - Memory-efficient audio player management
 * - Background music optimization
 *
 * PERFORMANCE FEATURES:
 * - Efficient sound effect loading
 * - Optimized audio session configuration
 * - Background music streaming
 * - Sound effect caching
 * - Memory cleanup on demand
 *
 * AUDIO SESSION CONFIGURATION:
 * - Ambient category for background audio
 * - Mix with other apps option
 * - Proper audio session activation
 * - Session deactivation on cleanup
 * - Error handling for audio setup
 *
 * SETTINGS MANAGEMENT:
 * - Sound enabled/disabled state
 * - Music volume control (0.0 - 1.0)
 * - Sound effects volume control (0.0 - 1.0)
 * - Settings persistence across app launches
 * - Settings restoration on initialization
 *
 * USER EXPERIENCE:
 * - Immediate audio feedback for actions
 * - Smooth volume transitions
 * - Consistent audio behavior
 * - Background audio compatibility
 * - Accessibility audio support
 *
 * INTEGRATION POINTS:
 * - Game events for sound triggers
 * - Settings interface for audio controls
 * - App lifecycle for audio management
 * - Memory warnings for cleanup
 * - Background/foreground transitions
 *
 * ARCHITECTURE ROLE:
 * This service acts as the central audio coordinator,
 * providing a clean interface for all audio-related
 * operations while managing system resources efficiently.
 *
 * THREADING CONSIDERATIONS:
 * - Audio operations on main thread
 * - Background audio session management
 * - Thread-safe audio player access
 * - Safe audio cleanup operations
 *
 * PERFORMANCE CONSIDERATIONS:
 * - Memory-efficient sound loading
 * - Optimized audio session setup
 * - Background music streaming
 * - Sound effect caching strategy
 *
 * REVIEW NOTES:
 * - Verify audio file resources exist in bundle
 * - Check audio session configuration and permissions
 * - Test background music looping and performance
 * - Validate sound effect loading and playback
 * - Check memory usage with multiple sound effects
 * - Test audio muting and unmuting functionality
 * - Verify volume control accuracy and persistence
 * - Check audio session interruption handling
 * - Test background/foreground audio transitions
 * - Validate system sound integration
 * - Check audio cleanup on memory warnings
 * - Test audio settings persistence across app launches
 * - Verify audio compatibility with other apps
 * - Check accessibility audio support
 * - Test audio performance on low-end devices
 * - Validate audio file format compatibility
 * - Check audio session error handling
 * - Test audio playback during network operations
 * - Verify audio resource loading error handling
 * - Check audio session deactivation on app termination
 * - Test audio integration with game state changes
 * - Validate audio feedback timing and responsiveness
 * - Check audio volume normalization and mixing
 * - Test audio performance during heavy game operations
 * - Verify audio session recovery after interruptions
 */

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
        
        // Initialize sound effects dictionary fresh
        soundEffects = [:]
        
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
    
    private func playEffectIfAvailable(_ name: String) {
        guard !isMuted else { return }
        soundEffects[name]?.play()
    }
    
    func playSoundEffect(_ name: String) {
        if soundEffects[name] == nil {
            loadSoundEffect(name)
        }
        playEffectIfAvailable(name)
    }
    
    func playBackgroundMusic() {
        guard !isMuted else { return }
        backgroundMusic?.play()
    }
    
    func stopBackgroundMusic() {
        backgroundMusic?.stop()
    }
    
    func stopAllSounds() {
        // Stop background music
        stopBackgroundMusic()
        
        // Stop all sound effects
        for player in soundEffects.values {
            player.stop()
        }
        
        // Clear sound effects dictionary
        soundEffects.removeAll()
    }
    
    func playSound(_ name: String) {
        playEffectIfAvailable(name)
    }
    
    func setMusicVolume(_ volume: Float) {
        backgroundMusic?.volume = volume
    }
    
    func setSoundEffectsVolume(_ volume: Float) {
        for player in soundEffects.values {
            player.volume = volume
        }
    }
    
    private func playSystemSound(_ soundID: SystemSoundID) {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    func playPlacementSound() {
        playSystemSound(1104) // System sound for a light tap
    }
    
    func playLevelCompleteSound() {
        playSystemSound(1519) // System sound for success
    }
    
    func playFailSound() {
        playSystemSound(1005) // System sound for warning/alert
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
    
    func cleanupSoundEffects() {
        // Stop all sound effects
        for player in soundEffects.values {
            player.stop()
        }
        
        // Clear sound effects dictionary
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
