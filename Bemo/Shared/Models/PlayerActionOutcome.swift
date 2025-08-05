//
//  PlayerActionOutcome.swift
//  Bemo
//
//  Model representing the result of a player's action in a game
//

// WHAT: Enum representing possible outcomes from processing player actions. Returned by Game.processRecognizedPieces().
// ARCHITECTURE: Data model in MVVM-S. Communication type between Game logic and GameHostViewModel for action results.
// USAGE: Games return this from processRecognizedPieces(). Host uses to award points, show feedback, or progress levels.

import Foundation

enum PlayerActionOutcome {
    /// The player placed a piece correctly
    case correctPlacement(points: Int)
    
    /// The player placed a piece incorrectly
    case incorrectPlacement
    
    /// The player completed the current level
    case levelComplete(xpAwarded: Int)
    
    /// No significant action occurred
    case noAction
    
    /// The player achieved a special milestone
    case specialAchievement(name: String, bonusXP: Int)
    
    /// The player requested help
    case hintUsed
    
    /// The game state was updated but no feedback needed
    case stateUpdated
}

extension PlayerActionOutcome {
    /// Whether this outcome represents a successful action
    var isSuccess: Bool {
        switch self {
        case .correctPlacement, .levelComplete, .specialAchievement:
            return true
        case .incorrectPlacement, .noAction, .hintUsed, .stateUpdated:
            return false
        }
    }
    
    /// The total points/XP awarded for this outcome
    var totalPoints: Int {
        switch self {
        case .correctPlacement(let points):
            return points
        case .levelComplete(let xp):
            return xp
        case .specialAchievement(_, let bonusXP):
            return bonusXP
        default:
            return 0
        }
    }
    
    /// A user-friendly message for this outcome
    var feedbackMessage: String {
        switch self {
        case .correctPlacement:
            return "Great job!"
        case .incorrectPlacement:
            return "Try again!"
        case .levelComplete:
            return "Level Complete! 🎉"
        case .specialAchievement(let name, _):
            return "Achievement: \(name)!"
        case .hintUsed:
            return "Here's a hint..."
        case .noAction, .stateUpdated:
            return ""
        }
    }
}