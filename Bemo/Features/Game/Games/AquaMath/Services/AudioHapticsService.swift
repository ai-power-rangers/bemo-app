//
//  AudioHapticsService.swift
//  Bemo
//
//  Manages sound effects and haptic feedback
//

// WHAT: Service handling all audio and haptic feedback for AquaMath
// ARCHITECTURE: Service in MVVM-S pattern
// USAGE: Used by AquaMathGameViewModel to trigger audio and haptics

import UIKit
import AVFoundation

class AudioHapticsService {
    
    // MARK: - Properties
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Initialization
    
    init() {
        prepareHaptics()
    }
    
    private func prepareHaptics() {
        impactFeedback.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Tile Sounds
    
    func playTilePickup() {
        selectionFeedback.selectionChanged()
        // Play pickup sound
    }
    
    func playTileDrop() {
        impactFeedback.impactOccurred()
        // Play drop sound
    }
    
    func playSnapFeedback() {
        impactFeedback.impactOccurred(intensity: 0.7)
        // Play snap sound
    }
    
    func playPoof() {
        // Play poof sound for tile removal
    }
    
    // MARK: - Bubble Sounds
    
    func playBubblePop() {
        impactFeedback.impactOccurred(intensity: 0.5)
        // Play pop sound
    }
    
    func playComboSound(level: Int) {
        notificationFeedback.notificationOccurred(.success)
        // Play combo sound with increasing pitch based on level
    }
    
    // MARK: - Power-up Sounds
    
    func playLightning() {
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        heavyImpact.impactOccurred()
        // Play lightning sound
    }
    
    func playExplosion() {
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        heavyImpact.impactOccurred()
        // Play explosion sound
    }
    
    func playSpongeSound() {
        // Play water absorption sound
    }
    
    func playCrateOpen() {
        notificationFeedback.notificationOccurred(.success)
        // Play crate opening sound
    }
    
    // MARK: - Game Flow Sounds
    
    func playLevelComplete() {
        notificationFeedback.notificationOccurred(.success)
        // Play level complete fanfare
    }
    
    func playFishUnlock() {
        notificationFeedback.notificationOccurred(.success)
        // Play fish unlock sound
    }
    
    func playWaterFilling() {
        // Play water filling sound
    }
    
    // MARK: - Background Music
    
    func startBackgroundMusic() {
        // Start underwater ambient music
    }
    
    func stopBackgroundMusic() {
        // Stop background music
    }
    
    func setMusicVolume(_ volume: Float) {
        // Adjust music volume
    }
}