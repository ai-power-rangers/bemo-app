//
//  SpellQuestConstants.swift
//  Bemo
//
//  Configuration constants for SpellQuest game
//

// WHAT: Central configuration values for gameplay, scoring, and UI
// ARCHITECTURE: Constants in MVVM-S
// USAGE: Reference throughout SpellQuest for consistent values

import Foundation
import SwiftUI

enum SpellQuestConstants {
    // MARK: - Scoring
    enum Scoring {
        static let xpPerCorrectLetter = 1
        static let xpPerWordComplete = 10
        static let xpBonusNoHints = 5
        static let xpBonusMinimalErrors = 3
        static let xpWinBonus = 10
    }
    
    // MARK: - Gameplay
    enum Gameplay {
        static let maxErrorsBeforePenalty = 3
        static let hintCooldownSeconds = 2.0
        static let celebrationDuration = 2.0
        static let autoAdvanceDelay = 1.5
        static let zenJuniorAutoHintDelay = 5.0
    }
    
    // MARK: - UI
    enum UI {
        static let letterTileSize: CGFloat = 50
        static let slotSize: CGFloat = 55
        static let slotSpacing: CGFloat = 8
        static let dragFeedbackScale: CGFloat = 1.2
        static let shakeAnimationDuration = 0.3
        static let correctPlacementScale: CGFloat = 1.1
        static let minTouchTargetSize: CGFloat = 44
        static let zenJuniorScaleFactor: CGFloat = 1.3
    }
    
    // MARK: - Colors
    enum Colors {
        static let slotEmpty = Color.gray.opacity(0.2)
        static let slotFilled = Color.green.opacity(0.3)
        static let slotHinted = Color.yellow.opacity(0.3)
        static let letterTile = Color.blue
        static let letterTileText = Color.white
        static let correctHighlight = Color.green
        static let incorrectHighlight = Color.red
    }
    
    // MARK: - Animation
    enum Animation {
        static let dragAnimation = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let shakeAnimation = SwiftUI.Animation.default.repeatCount(2, autoreverses: true)
        static let hintAnimation = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let celebrationAnimation = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}