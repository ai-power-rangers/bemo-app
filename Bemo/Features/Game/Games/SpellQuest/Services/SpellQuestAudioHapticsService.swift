//
//  SpellQuestAudioHapticsService.swift
//  Bemo
//
//  Audio and haptic feedback for SpellQuest
//

// WHAT: Provides audio and haptic feedback for game events
// ARCHITECTURE: Service layer in MVVM-S
// USAGE: Called by ViewModels for user feedback on actions

import UIKit
import AVFoundation

class SpellQuestAudioHapticsService {
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    init() {
        prepareHaptics()
    }
    
    private func prepareHaptics() {
        impactLight.prepare()
        impactMedium.prepare()
        notificationFeedback.prepare()
    }
    
    func playCorrect() {
        impactLight.impactOccurred()
        // In Stage 1, we're using system sounds
        AudioServicesPlaySystemSound(1057) // Tink sound
    }
    
    func playIncorrect() {
        notificationFeedback.notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1053) // Error sound
    }
    
    func playComplete() {
        notificationFeedback.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1025) // Success sound
    }
    
    func playHintTick() {
        impactLight.impactOccurred(intensity: 0.5)
        AudioServicesPlaySystemSound(1306) // Light tick
    }
}