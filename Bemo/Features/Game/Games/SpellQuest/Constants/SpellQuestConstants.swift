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
        static let zenJuniorDirectRevealThreshold = 2
    }
    
    // MARK: - UI
    enum UI {
        static let letterTileSize: CGFloat = 50
        static let slotSize: CGFloat = 55
        static let slotSpacing: CGFloat = 8
        static let dragFeedbackScale: CGFloat = 1.2
        static let shakeAnimationDuration: TimeInterval = 0.3
        static let correctPlacementScale: CGFloat = 1.1
        static let minTouchTargetSize: CGFloat = 44
        static let zenJuniorScaleFactor: CGFloat = 1.3
    }
    
    // MARK: - Colors
    enum Colors {
        static let slotEmpty = BemoTheme.Colors.gray2.opacity(0.2)
        static let slotFilled = BemoTheme.Colors.card2Foreground.opacity(0.3)
        static let slotHinted = BemoTheme.Colors.card3Foreground.opacity(0.3)
        static let letterTileBackground = Color.white
        static let letterTileBorder = Color.gray.opacity(0.3)
        static let correctHighlight = BemoTheme.Colors.card2Foreground
        static let incorrectHighlight = BemoTheme.Colors.card4Foreground
        
        // Individual letter colors based on educational color scheme
        static func letterColor(for letter: Character) -> Color {
            switch letter {
            case "A": return Color(red: 220/255, green: 38/255, blue: 127/255)  // Pink
            case "B": return Color(red: 218/255, green: 112/255, blue: 214/255) // Orchid
            case "C": return Color(red: 255/255, green: 140/255, blue: 0/255)   // Dark Orange
            case "D": return Color(red: 70/255, green: 130/255, blue: 180/255)  // Steel Blue
            case "E": return Color(red: 138/255, green: 43/255, blue: 226/255)  // Blue Violet
            case "F": return Color(red: 255/255, green: 105/255, blue: 180/255) // Hot Pink
            case "G": return Color(red: 255/255, green: 215/255, blue: 0/255)   // Gold
            case "H": return Color(red: 50/255, green: 205/255, blue: 50/255)   // Lime Green
            case "I": return Color(red: 255/255, green: 69/255, blue: 0/255)    // Red Orange
            case "J": return Color(red: 30/255, green: 144/255, blue: 255/255)  // Dodger Blue
            case "K": return Color(red: 128/255, green: 0/255, blue: 128/255)   // Purple
            case "L": return Color(red: 255/255, green: 20/255, blue: 147/255)  // Deep Pink
            case "M": return Color(red: 139/255, green: 69/255, blue: 19/255)   // Saddle Brown
            case "N": return Color(red: 0/255, green: 191/255, blue: 255/255)   // Deep Sky Blue
            case "O": return Color(red: 64/255, green: 224/255, blue: 208/255)  // Turquoise
            case "P": return Color(red: 186/255, green: 85/255, blue: 211/255)  // Medium Orchid
            case "Q": return Color(red: 220/255, green: 20/255, blue: 60/255)   // Crimson
            case "R": return Color(red: 255/255, green: 127/255, blue: 80/255)  // Coral
            case "S": return Color(red: 255/255, green: 165/255, blue: 0/255)   // Orange
            case "T": return Color(red: 128/255, green: 128/255, blue: 128/255) // Gray
            case "U": return Color(red: 72/255, green: 61/255, blue: 139/255)   // Dark Slate Blue
            case "V": return Color(red: 199/255, green: 21/255, blue: 133/255)  // Medium Violet Red
            case "W": return Color(red: 148/255, green: 0/255, blue: 211/255)   // Dark Violet
            case "X": return Color(red: 46/255, green: 139/255, blue: 87/255)   // Sea Green
            case "Y": return Color(red: 0/255, green: 128/255, blue: 128/255)   // Teal
            case "Z": return Color(red: 65/255, green: 105/255, blue: 225/255)  // Royal Blue
            default: return Color.gray
            }
        }
    }
    
    // MARK: - Animation
    enum Animation {
        static let dragAnimation = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let shakeAnimation = SwiftUI.Animation.default.repeatCount(2, autoreverses: true)
        static let hintAnimation = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let celebrationAnimation = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}