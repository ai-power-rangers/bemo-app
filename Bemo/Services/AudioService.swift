//
//  AudioService.swift
//  Bemo
//
//  Service for managing background music and sound effects throughout the app
//

// WHAT: Manages background music playback and sound effects. Controls audio sessions, volume, and track switching.
// ARCHITECTURE: Service layer in MVVM-S. Injected via DependencyContainer and accessible to all ViewModels.
// USAGE: Access via DependencyContainer. Call playBackgroundMusic() to switch tracks, playSoundEffect() for one-shot sounds.

import Foundation
import AVFoundation
import Observation

@Observable
class AudioService {
    // MARK: - Properties
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var soundEffectPlayers: [AVAudioPlayer] = []
    private weak var profileService: ProfileService?
    
    // Observable properties
    var isBackgroundMusicEnabled: Bool = true {
        didSet {
            if isBackgroundMusicEnabled {
                resumeBackgroundMusic()
            } else {
                pauseBackgroundMusic()
            }
        }
    }
    
    var isSoundEffectsEnabled: Bool = true
    
    var backgroundMusicVolume: Float = 0.5 {
        didSet {
            backgroundMusicPlayer?.volume = backgroundMusicVolume
        }
    }
    
    var soundEffectVolume: Float = 0.7
    
    private(set) var currentBackgroundTrack: String?
    private(set) var isPlaying: Bool = false
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        // Start playing default background music after initialization
        Task {
            await MainActor.run {
                playBackgroundMusic("BemoBounce.mp3")
            }
        }
    }
    
    // MARK: - Profile Service Integration
    func setProfileService(_ profileService: ProfileService) {
        self.profileService = profileService
        // Apply current profile preferences
        if let preferences = profileService.activeProfile?.preferences {
            isBackgroundMusicEnabled = preferences.musicEnabled
            isSoundEffectsEnabled = preferences.soundEnabled
        }
        
        // Observe profile changes
        setupProfileObserver()
    }
    
    private func setupProfileObserver() {
        guard let profileService = profileService else { return }
        
        withObservationTracking {
            // Observe activeProfile changes
            _ = profileService.activeProfile
        } onChange: { [weak self] in
            Task { @MainActor in
                // Apply new profile preferences
                if let preferences = profileService.activeProfile?.preferences {
                    self?.isBackgroundMusicEnabled = preferences.musicEnabled
                    self?.isSoundEffectsEnabled = preferences.soundEnabled
                }
                // Re-establish observation
                self?.setupProfileObserver()
            }
        }
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            // Use playback category to ensure audio plays even in silent mode
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("AudioService: Audio session setup successfully")
        } catch {
            print("AudioService: Failed to setup audio session - \(error)")
        }
    }
    
    // MARK: - Background Music
    func playBackgroundMusic(_ filename: String, fadeIn: Bool = true) {
        print("AudioService: playBackgroundMusic called with \(filename)")
        guard isBackgroundMusicEnabled else { 
            print("AudioService: Background music is disabled")
            return 
        }
        
        // Don't restart if already playing this track
        if currentBackgroundTrack == filename && isPlaying {
            print("AudioService: Already playing \(filename)")
            return
        }
        
        // Stop current music
        if let currentPlayer = backgroundMusicPlayer {
            if fadeIn {
                fadeOut(player: currentPlayer) {
                    currentPlayer.stop()
                }
            } else {
                currentPlayer.stop()
            }
        }
        
        // Load and play new track
        let fileNameWithoutExtension = filename.replacingOccurrences(of: ".mp3", with: "")
        
        // Try to find the file with subdirectory first, then without
        var url: URL?
        
        // First try with BackgroundMusic subdirectory
        url = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3", subdirectory: "BackgroundMusic")
        
        // If not found, try without subdirectory (in case files are in Resources root)
        if url == nil {
            url = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3")
        }
        
        // If still not found, try the full path in Resources/BackgroundMusic
        if url == nil {
            url = Bundle.main.url(forResource: "BackgroundMusic/\(fileNameWithoutExtension)", withExtension: "mp3")
        }
        
        guard let finalUrl = url else {
            print("AudioService: Could not find background music file: \(filename)")
            print("AudioService: Searched for: \(fileNameWithoutExtension).mp3")
            return
        }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: finalUrl)
            backgroundMusicPlayer?.numberOfLoops = -1 // Loop indefinitely
            backgroundMusicPlayer?.volume = fadeIn ? 0 : backgroundMusicVolume
            backgroundMusicPlayer?.prepareToPlay()
            
            let success = backgroundMusicPlayer?.play() ?? false
            print("AudioService: Play started: \(success), volume: \(backgroundMusicPlayer?.volume ?? 0)")
            
            currentBackgroundTrack = filename
            isPlaying = true
            
            if fadeIn {
                self.fadeIn(player: backgroundMusicPlayer!)
            }
            
            print("AudioService: Successfully started playing \(filename)")
        } catch {
            print("AudioService: Error playing background music - \(error)")
        }
    }
    
    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
        isPlaying = false
    }
    
    func resumeBackgroundMusic() {
        guard isBackgroundMusicEnabled else { return }
        backgroundMusicPlayer?.play()
        isPlaying = backgroundMusicPlayer?.isPlaying ?? false
    }
    
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
        currentBackgroundTrack = nil
        isPlaying = false
    }
    
    // MARK: - Sound Effects
    func playSoundEffect(_ filename: String, volume: Float? = nil) {
        guard isSoundEffectsEnabled else { return }
        
        let fileNameWithoutExtension = filename.replacingOccurrences(of: ".mp3", with: "")
        guard let url = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3", subdirectory: "SoundFX") else {
            print("AudioService: Could not find sound effect file: \(filename)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume ?? soundEffectVolume
            player.prepareToPlay()
            player.play()
            
            // Keep reference to prevent deallocation
            soundEffectPlayers.append(player)
            
            // Clean up finished players
            cleanupFinishedPlayers()
        } catch {
            print("AudioService: Error playing sound effect - \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func fadeIn(player: AVAudioPlayer, duration: TimeInterval = 0.5) {
        player.volume = 0
        let targetVolume = backgroundMusicVolume
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeIncrement = targetVolume / Float(steps)
        
        for step in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                player.volume = volumeIncrement * Float(step + 1)
            }
        }
    }
    
    private func fadeOut(player: AVAudioPlayer, duration: TimeInterval = 0.5, completion: @escaping () -> Void) {
        let startVolume = player.volume
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeDecrement = startVolume / Float(steps)
        
        for step in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                player.volume = startVolume - (volumeDecrement * Float(step + 1))
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }
    
    private func cleanupFinishedPlayers() {
        soundEffectPlayers.removeAll { !$0.isPlaying }
    }
    
    // MARK: - Track Management
    func switchToGameMusic(for gameId: String) {
        switch gameId {
        case "tangram":
            playBackgroundMusic("TangramTunes.mp3")
        case "aqua_math":
            playBackgroundMusic("OceanWonders.mp3")
        case "spell_quest":
            playBackgroundMusic("ShapesAndLetters.mp3")
        default:
            playBackgroundMusic("BemoBounce.mp3")
        }
    }
    
    func switchToLobbyMusic() {
        playBackgroundMusic("BemoBounce.mp3")
    }
}
