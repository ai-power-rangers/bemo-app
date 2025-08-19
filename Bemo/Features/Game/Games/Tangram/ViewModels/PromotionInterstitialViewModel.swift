//
//  PromotionInterstitialViewModel.swift
//  Bemo
//
//  ViewModel for the difficulty promotion celebration screen
//

// WHAT: Manages state for promotion celebration screen shown between difficulty levels
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses @Observable for state management
// USAGE: Created when user completes all puzzles in a difficulty, handles auto-advance and user actions

import SwiftUI
import Observation

@Observable
class PromotionInterstitialViewModel {
    
    // MARK: - Properties
    
    let fromDifficulty: UserPreferences.DifficultySetting
    let toDifficulty: UserPreferences.DifficultySetting
    let completedPuzzleCount: Int
    let totalTimeSpent: TimeInterval?
    
    private let onContinue: () -> Void
    private let onSkip: () -> Void
    
    var isAutoAdvancing: Bool = true
    var remainingAutoAdvanceTime: TimeInterval = 3.0
    private var autoAdvanceTimer: Timer?
    
    // MARK: - Initialization
    
    init(
        fromDifficulty: UserPreferences.DifficultySetting,
        toDifficulty: UserPreferences.DifficultySetting,
        completedPuzzleCount: Int,
        totalTimeSpent: TimeInterval? = nil,
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.fromDifficulty = fromDifficulty
        self.toDifficulty = toDifficulty
        self.completedPuzzleCount = completedPuzzleCount
        self.totalTimeSpent = totalTimeSpent
        self.onContinue = onContinue
        self.onSkip = onSkip
        
        startAutoAdvanceTimer()
    }
    
    // MARK: - Auto-Advance Timer
    
    private func startAutoAdvanceTimer() {
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.remainingAutoAdvanceTime -= 0.1
            
            if self.remainingAutoAdvanceTime <= 0 {
                timer.invalidate()
                self.continueToNextDifficulty()
            }
        }
    }
    
    // MARK: - User Actions
    
    func continueToNextDifficulty() {
        autoAdvanceTimer?.invalidate()
        isAutoAdvancing = false
        onContinue()
    }
    
    func skipToMap() {
        autoAdvanceTimer?.invalidate()
        isAutoAdvancing = false
        onSkip()
    }
    
    // MARK: - Computed Properties
    
    var promotionTitle: String {
        return "Congratulations! 🎉"
    }
    
    var completionMessage: String {
        return "You completed all \(fromDifficulty.displayName) puzzles!"
    }
    
    var nextDifficultyMessage: String {
        return "Ready for \(toDifficulty.displayName) Difficulty"
    }
    
    var autoAdvanceMessage: String {
        let seconds = Int(ceil(remainingAutoAdvanceTime))
        return "Auto-continuing in \(seconds) second\(seconds == 1 ? "" : "s")..."
    }
    
    var promotionIcon: String {
        switch toDifficulty {
        case .easy:
            return "star.fill"
        case .normal:
            return "star.leadinghalf.filled"
        case .hard:
            return "crown.fill"
        }
    }
    
    var promotionColor: Color {
        switch toDifficulty {
        case .easy:
            return .green
        case .normal:
            return .blue
        case .hard:
            return .purple
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        autoAdvanceTimer?.invalidate()
    }
}
