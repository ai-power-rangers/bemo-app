//
//  ConstructionGroup.swift
//  Bemo
//
//  Construction group tracking for smart validation
//

// WHAT: Tracks groups of pieces that show construction intent
// ARCHITECTURE: Model in MVVM-S, used by validation system
// USAGE: Groups pieces by proximity to determine when to validate

import Foundation
import CoreGraphics

/// Validation state for a construction group
enum GroupValidationState: Equatable {
    case scattered      // Pieces spread out, no validation
    case exploring      // 2 pieces, observing only
    case constructing   // 3+ pieces, soft validation
    case building       // 4+ pieces or valid connections, active validation
    case completing     // >60% done, aggressive help
    
    var shouldValidate: Bool {
        switch self {
        case .scattered, .exploring:
            return false
        case .constructing, .building, .completing:
            return true
        }
    }
    
    var nudgeIntensity: Float {
        switch self {
        case .scattered: return 0.0
        case .exploring: return 0.0
        case .constructing: return 0.3
        case .building: return 0.6
        case .completing: return 1.0
        }
    }
}

/// Nudge level progression
enum NudgeLevel: Int, Comparable {
    case none = 0
    case visual = 1         // Color/opacity change only
    case gentle = 2         // Generic hint like "Try rotating"
    case specific = 3       // Specific action like "Flip this piece"
    case directed = 4       // Arrow showing direction
    case solution = 5       // Ghost piece showing exact placement
    
    static func < (lhs: NudgeLevel, rhs: NudgeLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// History of nudges shown for a group
struct NudgeHistory: Equatable {
    var lastNudgeTime: Date?
    var nudgeCount: Int = 0
    var attemptsSinceNudge: Int = 0
    var cooldownMultiplier: Int = 1
    
    /// Check if enough time has passed for next nudge
    func shouldShowNudge(baseInterval: TimeInterval = 5.0) -> Bool {
        guard let last = lastNudgeTime else { return true }
        let cooldown = baseInterval * Double(cooldownMultiplier)
        return Date().timeIntervalSince(last) > cooldown
    }
    
    /// Update after showing a nudge
    mutating func recordNudge() {
        lastNudgeTime = Date()
        nudgeCount += 1
        attemptsSinceNudge = 0
        cooldownMultiplier = min(cooldownMultiplier + 1, 5) // Cap at 5x
    }
}

/// Represents a group of pieces being constructed together
struct ConstructionGroup: Identifiable {
    let id = UUID()
    var pieces: Set<String> = []                      // Piece IDs in group
    var anchorPiece: String?                          // First piece (reference frame)
    var confidence: Float = 0                         // Construction intent (0-1)
    var createdAt = Date()                           // When group was created
    var lastActivity = Date()                         // For timeout/decay
    var validatedConnections: Set<PieceConnection> = []
    var validationState: GroupValidationState = .scattered
    var attemptHistory: [String: Int] = [:]          // Attempts per piece
    var nudgeHistory = NudgeHistory()
    var centerOfMass: CGPoint = .zero                // Geometric center
    var boundingRadius: CGFloat = 0                  // Spread of pieces
    
    /// Check if group has been inactive too long
    func isStale(timeout: TimeInterval = 30) -> Bool {
        return Date().timeIntervalSince(lastActivity) > timeout
    }
    
    /// Update state based on piece count and connections
    mutating func updateState() {
        let pieceCount = pieces.count
        let connectionCount = validatedConnections.count
        let completionRatio = Float(connectionCount) / 6.0 // Max 6 connections in tangram
        let timeSinceCreation = Date().timeIntervalSince(createdAt)
        let avgAttemptsPerPiece = attemptHistory.values.reduce(0, +) / max(1, attemptHistory.count)
        
        // Single piece is always scattered
        if pieceCount <= 1 {
            validationState = GroupValidationState.scattered
            return
        }
        
        // Two pieces with no connections and recent creation = exploring
        if pieceCount == 2 && connectionCount == 0 && timeSinceCreation < 10 {
            validationState = GroupValidationState.exploring
            return
        }
        
        // Multiple pieces or validated connections = active construction
        if pieceCount >= 2 {
            // High completion ratio = completing phase
            if completionRatio > 0.6 || (pieceCount >= 5 && connectionCount >= 3) {
                validationState = GroupValidationState.completing
            }
            // Good progress = building phase
            else if (pieceCount >= 4 && connectionCount >= 2) || 
                    (pieceCount >= 3 && connectionCount >= 1 && confidence > 0.6) {
                validationState = GroupValidationState.building
            }
            // Early construction with clear intent
            else if (pieceCount >= 3) || 
                    (pieceCount >= 2 && connectionCount >= 1) ||
                    (pieceCount >= 2 && confidence > 0.5 && avgAttemptsPerPiece >= 2) {
                validationState = GroupValidationState.constructing
            }
            // Default to exploring for 2 pieces
            else {
                validationState = GroupValidationState.exploring
            }
        }
    }
    
    /// Record an attempt for a piece
    mutating func recordAttempt(for pieceId: String) {
        attemptHistory[pieceId, default: 0] += 1
        nudgeHistory.attemptsSinceNudge += 1
        lastActivity = Date()
    }
    
    /// Check if piece has had too many failed attempts
    func shouldShowNudge(for pieceId: String, threshold: Int = 3) -> Bool {
        let attempts = attemptHistory[pieceId, default: 0]
        return attempts >= threshold && nudgeHistory.shouldShowNudge()
    }
}

/// Connection between two pieces
struct PieceConnection: Hashable, Equatable {
    let piece1: String
    let piece2: String
    let isValid: Bool
    
    init(_ p1: String, _ p2: String, valid: Bool = true) {
        // Order pieces consistently for equality
        if p1 < p2 {
            piece1 = p1
            piece2 = p2
        } else {
            piece1 = p2
            piece2 = p1
        }
        isValid = valid
    }
}

/// Spatial signals for intent detection
struct SpatialSignals {
    var edgeProximity: Float = 0      // 0-1, how close edges are
    var angleAlignment: Float = 0      // 0-1, how aligned to valid angles
    var clusterDensity: Float = 0      // 0-1, pieces per area
    var centerOfMass: CGPoint = .zero  // Group center
    var averageDistance: CGFloat = 0   // Average distance between pieces
}

/// Temporal signals for intent detection
struct TemporalSignals {
    var placementSpeed: Float = 0      // Time between placements
    var stabilityDuration: Float = 0   // How long stationary
    var focusTime: Float = 0          // Time in same area
    var activityRecency: Float = 0     // Time since last action
}

/// Behavioral signals for intent detection
struct BehavioralSignals {
    var fineAdjustments: Int = 0       // Small rotation count
    var repeatAttempts: Int = 0        // Times piece moved back
    var validConnections: Int = 0      // Successful connections
    var progressionRate: Float = 0     // Valid/total ratio
}