//
//  SmartNudgeManager.swift
//  Bemo
//
//  Intelligent nudge management system
//

// WHAT: Manages when and how to show nudges based on context
// ARCHITECTURE: Service in MVVM-S, controls nudge timing and progression
// USAGE: Determines appropriate nudge level and content based on user behavior

import Foundation
import CoreGraphics
import SpriteKit

/// Content for a nudge
struct NudgeContent {
    let level: NudgeLevel
    let message: String
    let visualHint: VisualHint?
    let duration: TimeInterval
    
    enum VisualHint {
        case colorChange(color: SKColor, alpha: CGFloat)
        case arrow(direction: CGFloat)  // Angle in radians
        case ghostPiece(position: CGPoint, rotation: CGFloat)
        case pulse(intensity: CGFloat)
    }
}

class SmartNudgeManager {
    // MARK: - Properties
    
    private var nudgeHistories: [String: NudgeHistory] = [:]
    private var pieceAttempts: [String: [(date: Date, position: CGPoint)]] = [:]
    private let baseNudgeInterval: TimeInterval = 3.0
    private let maxNudgeLevel: NudgeLevel = .solution
    
    // MARK: - Public Interface
    
    /// Determine if a nudge should be shown for a piece
    func shouldShowNudge(for piece: PuzzlePieceNode,
                         in group: ConstructionGroup?) -> Bool {
        
        guard let pieceId = piece.name else { return false }
        
        // Check if piece is part of a group
        guard let group = group else { return false }
        
        // Check group state
        guard group.validationState.shouldValidate else { return false }
        
        // Check confidence threshold - intent-based, not zone-based
        if group.confidence < 0.3 { return false }  // Lower threshold for intent detection
        
        // Check attempt count
        let attempts = group.attemptHistory[pieceId] ?? 0
        if attempts < 2 { return false } // Need at least 2 attempts
        
        // Check nudge cooldown
        let history = nudgeHistories[pieceId] ?? NudgeHistory()
        if !history.shouldShowNudge(baseInterval: baseNudgeInterval) {
            return false
        }
        
        // Intent-based checks (confidence and attempts)
        // Higher confidence = more likely to nudge
        // More attempts = more likely to nudge
        return (attempts >= 2 && group.confidence > 0.25) ||
               (attempts >= 3 && group.confidence > 0.45) ||
               (attempts >= 5)
    }
    
    /// Determine appropriate nudge level
    func determineNudgeLevel(confidence: Float,
                            attempts: Int,
                            state: GroupValidationState) -> NudgeLevel {
        
        // Base level from validation state
        var level: NudgeLevel
        
        switch state {
        case .scattered, .exploring:
            level = .none
        case .constructing:
            level = confidence > 0.6 ? .gentle : .visual
        case .building:
            level = confidence > 0.6 ? .specific : .gentle
        case .completing:
            level = .directed
        }
        
        // Escalate based on attempts
        if attempts > 5 {
            level = min(maxNudgeLevel, NudgeLevel(rawValue: level.rawValue + 2) ?? level)
        } else if attempts > 3 {
            level = min(maxNudgeLevel, NudgeLevel(rawValue: level.rawValue + 1) ?? level)
        }
        
        // Intent-based adjustment: higher confidence = more specific nudges
        if confidence > 0.8 && level.rawValue < NudgeLevel.specific.rawValue {
            level = .specific
        }
        
        return level
    }
    
    /// Generate nudge content based on level and failure reason
    func generateNudge(level: NudgeLevel,
                      failure: ValidationFailure?,
                      targetInfo: (position: CGPoint, rotation: CGFloat)? = nil) -> NudgeContent {
        
        var message: String
        var visualHint: NudgeContent.VisualHint?
        var duration: TimeInterval
        
        switch level {
        case .none:
            return NudgeContent(level: .none, message: "", visualHint: nil, duration: 0)
            
        case .visual:
            message = ""
            visualHint = .colorChange(color: .systemOrange, alpha: 0.3)
            duration = 2.0
            
        case .gentle:
            // If there's a specific failure (rotation/flip), escalate message but keep subtle visual
            switch failure {
            case .wrongRotation:
                message = "Try rotating"
            case .needsFlip:
                message = "Try flipping"
            default:
                message = failure?.nudgeMessage ?? "Try adjusting this piece"
            }
            visualHint = .pulse(intensity: 0.5)
            duration = 3.0
            
        case .specific:
            switch failure {
            case .wrongRotation(let degrees):
                message = degrees > 45 ? "Rotate significantly" : "Slight rotation needed"
                if let target = targetInfo {
                    visualHint = .ghostPiece(position: target.position, rotation: target.rotation)
                } else {
                    visualHint = .colorChange(color: .systemYellow, alpha: 0.5)
                }
            case .needsFlip:
                message = "Flip the piece"
                if let target = targetInfo {
                    visualHint = .ghostPiece(position: target.position, rotation: target.rotation)
                } else {
                    visualHint = .pulse(intensity: 0.7)
                }
            case .wrongPosition:
                message = "Move closer to other pieces"
                visualHint = .colorChange(color: .systemBlue, alpha: 0.5)
            default:
                message = "This piece needs adjustment"
                visualHint = .pulse(intensity: 0.5)
            }
            duration = 4.0
            
        case .directed:
            if let target = targetInfo {
                let angle = atan2(target.position.y, target.position.x)
                message = "Move this way"
                visualHint = .arrow(direction: angle)
            } else {
                message = "Try a different approach"
                visualHint = .pulse(intensity: 1.0)
            }
            duration = 5.0
            
        case .solution:
            if let target = targetInfo {
                message = "Place here"
                visualHint = .ghostPiece(position: target.position, rotation: target.rotation)
            } else {
                message = "See the target shape"
                visualHint = .colorChange(color: .systemGreen, alpha: 0.7)
            }
            duration = 6.0
        }
        
        return NudgeContent(
            level: level,
            message: message,
            visualHint: visualHint,
            duration: duration
        )
    }
    
    /// Record that a nudge was shown
    func recordNudgeShown(for pieceId: String) {
        var history = nudgeHistories[pieceId] ?? NudgeHistory()
        history.recordNudge()
        nudgeHistories[pieceId] = history
    }
    
    /// Record a piece placement attempt
    func recordAttempt(for pieceId: String, at position: CGPoint) {
        var attempts = pieceAttempts[pieceId] ?? []
        attempts.append((Date(), position))
        
        // Keep only recent attempts (last 10)
        if attempts.count > 10 {
            attempts.removeFirst(attempts.count - 10)
        }
        
        pieceAttempts[pieceId] = attempts
    }
    
    /// Check if piece is being repeatedly placed in same area
    func isRepeatingPlacement(for pieceId: String, at position: CGPoint, threshold: CGFloat = 30) -> Bool {
        guard let attempts = pieceAttempts[pieceId],
              attempts.count >= 2 else { return false }
        
        // Check last 3 attempts
        let recentAttempts = attempts.suffix(3)
        let similarPlacements = recentAttempts.filter { attempt in
            let distance = hypot(attempt.position.x - position.x, attempt.position.y - position.y)
            return distance < threshold
        }
        
        return similarPlacements.count >= 2
    }
    
    /// Apply progressive cooldown based on nudge history
    func applyProgressiveCooldown(history: NudgeHistory) -> TimeInterval {
        let baseCooldown = baseNudgeInterval
        let multiplier = Double(history.cooldownMultiplier)
        let attemptBonus = Double(history.attemptsSinceNudge) * 0.5
        
        return max(baseCooldown, baseCooldown * multiplier - attemptBonus)
    }
    
    /// Reset nudge history for a piece
    func resetHistory(for pieceId: String) {
        nudgeHistories.removeValue(forKey: pieceId)
        pieceAttempts.removeValue(forKey: pieceId)
    }
    
    /// Clear all nudge histories
    func clearAllHistories() {
        nudgeHistories.removeAll()
        pieceAttempts.removeAll()
    }
    
    // MARK: - Analytics
    
    /// Get nudge statistics for analytics
    func getNudgeStats() -> [String: Any] {
        var totalNudges = 0
        var averageCooldown = 0.0
        var pieceWithMostNudges: (id: String, count: Int)? = nil
        
        for (pieceId, history) in nudgeHistories {
            totalNudges += history.nudgeCount
            averageCooldown += Double(history.cooldownMultiplier)
            
            if pieceWithMostNudges == nil || history.nudgeCount > pieceWithMostNudges!.count {
                pieceWithMostNudges = (pieceId, history.nudgeCount)
            }
        }
        
        let pieceCount = max(1, nudgeHistories.count)
        
        return [
            "totalNudges": totalNudges,
            "averageCooldownMultiplier": averageCooldown / Double(pieceCount),
            "piecesNudged": nudgeHistories.count,
            "mostNudgedPiece": pieceWithMostNudges?.id ?? "none",
            "maxNudgeCount": pieceWithMostNudges?.count ?? 0
        ]
    }
}