//
//  SpellQuestScoringService.swift
//  Bemo
//
//  Calculates XP and scoring for SpellQuest
//

// WHAT: Manages XP calculation and scoring rules for all game modes
// ARCHITECTURE: Service layer in MVVM-S
// USAGE: Called by ViewModels to calculate XP for various game events

import Foundation

class SpellQuestScoringService {
    
    func calculateLetterXP() -> Int {
        SpellQuestConstants.Scoring.xpPerCorrectLetter
    }
    
    func calculateWordCompletionXP(boardState: PlayerBoardState, mode: SpellQuestGameMode) -> Int {
        var xp = SpellQuestConstants.Scoring.xpPerWordComplete
        
        // Bonus for no hints
        if boardState.hintsUsedThisPuzzle == 0 {
            xp += SpellQuestConstants.Scoring.xpBonusNoHints
        }
        
        // Bonus for minimal errors
        if boardState.errorsThisPuzzle <= 1 {
            xp += SpellQuestConstants.Scoring.xpBonusMinimalErrors
        }
        
        return xp
    }
    
    func calculateSessionXP(completedWords: Int, totalHints: Int, totalErrors: Int) -> Int {
        var totalXP = completedWords * SpellQuestConstants.Scoring.xpPerWordComplete
        
        // Penalty for excessive hints (mild)
        if totalHints > completedWords * 2 {
            totalXP = Int(Double(totalXP) * 0.9)
        }
        
        return max(totalXP, 1) // Always award at least 1 XP
    }
}