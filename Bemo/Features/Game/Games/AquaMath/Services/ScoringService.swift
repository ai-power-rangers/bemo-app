//
//  ScoringService.swift
//  Bemo
//
//  Handles score calculations and combo logic
//

// WHAT: Service calculating scores, combos, and XP based on game events
// ARCHITECTURE: Service in MVVM-S pattern
// USAGE: Used by AquaMathGameViewModel to calculate points and track combos

import Foundation

class ScoringService {
    
    // MARK: - Score Result
    
    struct ScoreResult {
        let points: Int
        let isCombo: Bool
        let newComboCount: Int
    }
    
    // MARK: - Constants
    
    private let basePointsPerBubble = 10
    private let comboMultiplier = 1.5
    private let comboTimeWindow: TimeInterval = 2.0
    
    // MARK: - State
    
    private var lastPopTime: TimeInterval = 0
    
    // MARK: - Score Calculation
    
    func calculateScore(
        poppedBubbles: Int,
        bubbleValue: Int,
        mode: GameMode,
        comboCount: Int
    ) -> ScoreResult {
        
        let currentTime = Date().timeIntervalSince1970
        let isCombo = poppedBubbles >= 2 || (currentTime - lastPopTime < comboTimeWindow && comboCount > 0)
        lastPopTime = currentTime
        
        // Base score
        var score = basePointsPerBubble * poppedBubbles
        
        // Add bubble value bonus
        score += bubbleValue * Int(mode.modeMultiplier)
        
        // Apply combo multiplier
        let newComboCount = isCombo ? comboCount + 1 : 0
        if isCombo {
            let multiplier = pow(comboMultiplier, Double(newComboCount))
            score = Int(Double(score) * multiplier)
        }
        
        return ScoreResult(
            points: score,
            isCombo: isCombo,
            newComboCount: newComboCount
        )
    }
    
    // MARK: - XP Calculation
    
    func calculateXP(score: Int, level: Int) -> Int {
        // Base XP from score
        let baseXP = score / 10
        
        // Level bonus
        let levelBonus = level * 50
        
        return baseXP + levelBonus
    }
    
    // MARK: - Special Bonuses
    
    func crateBonus(level: Int) -> Int {
        // Random bonus based on level
        let minBonus = 50 * level
        let maxBonus = 150 * level
        return Int.random(in: minBonus...maxBonus)
    }
    
    func perfectLevelBonus(score: Int) -> Int {
        // Bonus for completing level without mistakes
        return score / 2
    }
}