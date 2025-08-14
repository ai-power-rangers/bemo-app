//
//  PieceState.swift
//  Bemo
//
//  State machine for tracking tangram piece interactions
//

// WHAT: Defines the state machine for piece detection and validation
// ARCHITECTURE: Model in MVVM-S, tracks piece lifecycle from detection to validation
// USAGE: Each piece maintains a PieceState to track movement and validation status

import Foundation
import CoreGraphics

/// Detection and validation states for tangram pieces
enum DetectionState: Equatable {
    case unobserved
    case detected(baseline: CGPoint, rotation: CGFloat, detectedAt: Date)
    case moved(from: CGPoint, rotation: CGFloat)
    case placed(at: Date)
    case validating
    case validated(connections: Set<String>)
    case invalid(reason: ValidationFailure)
    
    var isInteractable: Bool {
        switch self {
        case .unobserved, .detected:
            return false
        default:
            return true
        }
    }
    
    var canValidate: Bool {
        switch self {
        case .placed, .validating, .validated, .invalid:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .unobserved: return "Unobserved"
        case .detected: return "Detected"
        case .moved: return "Moved"
        case .placed: return "Placed"
        case .validating: return "Validating"
        case .validated: return "Validated"
        case .invalid: return "Invalid"
        }
    }
}

/// Reasons why validation failed
enum ValidationFailure: Equatable {
    case wrongPosition(offset: CGFloat)
    case wrongRotation(degreesOff: CGFloat)
    case needsFlip
    case wrongPiece
    case noValidatedPiecesNearby
    
    var nudgeMessage: String {
        switch self {
        case .wrongPosition(let offset):
            return offset > 50 ? "Try moving closer" : "Almost there!"
        case .wrongRotation(let degrees):
            return degrees > 45 ? "Try rotating" : "Slight rotation needed"
        case .needsFlip:
            return "Try flipping the piece"
        case .wrongPiece:
            return "Try a different piece"
        case .noValidatedPiecesNearby:
            return "Connect to other pieces"
        }
    }
}

/// Complete state tracking for a tangram piece
struct PieceState: Equatable {
    let pieceId: String
    let pieceType: TangramPieceType
    var state: DetectionState = .unobserved
    var currentPosition: CGPoint = .zero
    var currentRotation: CGFloat = 0
    var isFlipped: Bool = false
    var lastMovedTime: Date?
    var placementStartTime: Date?
    var interactionCount: Int = 0
    var isAnchor: Bool = false
    var validatedConnections: Set<String> = []
    
    // Movement detection thresholds
    static let movementThreshold: CGFloat = 20.0  // pixels
    static let rotationThreshold: CGFloat = 0.087 // ~5 degrees (stricter for settled/orientation gating)
    static let placementDelay: TimeInterval = 1.0 // seconds
    
    init(pieceId: String, pieceType: TangramPieceType) {
        self.pieceId = pieceId
        self.pieceType = pieceType
    }
    
    /// Check if piece has moved significantly from baseline
    func hasMoved(from baseline: CGPoint, rotation: CGFloat) -> Bool {
        let distance = hypot(currentPosition.x - baseline.x, 
                           currentPosition.y - baseline.y)
        let rotationDelta = abs(currentRotation - rotation)
        
        return distance > Self.movementThreshold || 
               rotationDelta > Self.rotationThreshold
    }
    
    /// Check if piece has been stationary long enough to be considered placed
    func isPlaced(currentTime: Date = Date()) -> Bool {
        guard let startTime = placementStartTime else { return false }
        return currentTime.timeIntervalSince(startTime) >= Self.placementDelay
    }
    
    /// Update position and check for state transitions
    mutating func updatePosition(_ position: CGPoint, rotation: CGFloat) {
        let previousPosition = currentPosition
        let previousRotation = currentRotation
        
        currentPosition = position
        currentRotation = rotation
        
        // Check for state transitions based on movement
        switch state {
        case .detected(let baseline, let baseRotation, _):
            if hasMoved(from: baseline, rotation: baseRotation) {
                state = .moved(from: baseline, rotation: baseRotation)
                interactionCount += 1
                lastMovedTime = Date()
            }
            
        case .placed:
            // If moved while placed, go back to moved state
            let distance = hypot(position.x - previousPosition.x,
                               position.y - previousPosition.y)
            let rotDelta = abs(rotation - previousRotation)
            
            if distance > Self.movementThreshold || rotDelta > Self.rotationThreshold {
                if case .detected(let baseline, let baseRot, _) = state {
                    state = .moved(from: baseline, rotation: baseRot)
                } else {
                    state = .moved(from: previousPosition, rotation: previousRotation)
                }
                lastMovedTime = Date()
                placementStartTime = nil
            }
            
        default:
            break
        }
    }
    
    /// Transition to placed state when movement stops
    mutating func markAsPlaced() {
        switch state {
        case .moved:
            placementStartTime = Date()
            state = .placed(at: Date())
            
        default:
            break
        }
    }
    
    /// Transition to validating state
    mutating func beginValidation() {
        guard state.canValidate else { return }
        state = .validating
    }
    
    /// Mark as validated with connections
    mutating func markAsValidated(connections: Set<String>) {
        state = .validated(connections: connections)
        validatedConnections = connections
    }
    
    /// Mark as invalid with reason
    mutating func markAsInvalid(reason: ValidationFailure) {
        state = .invalid(reason: reason)
    }
    
    /// Reset to detected state (for retry)
    mutating func resetToDetected() {
        if case .detected(let baseline, let rotation, let time) = state {
            // Keep the original baseline
            state = .detected(baseline: baseline, rotation: rotation, detectedAt: time)
        } else {
            // Use current position as new baseline
            state = .detected(baseline: currentPosition, rotation: currentRotation, detectedAt: Date())
        }
        placementStartTime = nil
        validatedConnections.removeAll()
        isAnchor = false
    }
}

// MARK: - State Visualization Helpers

extension PieceState {
    /// Opacity for visual representation
    var displayOpacity: CGFloat {
        switch state {
        case .unobserved: return 0.3
        case .detected: return 0.5
        case .moved: return 1.0
        case .placed: return 0.9
        case .validating: return 0.95
        case .validated: return 1.0
        case .invalid: return 0.7
        }
    }
    
    /// Color overlay for state visualization
    var stateColor: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        switch state {
        case .unobserved: return nil
        case .detected: return (0.5, 0.5, 0.5, 0.3)  // Gray
        case .moved: return (0.0, 0.5, 1.0, 0.3)     // Blue
        case .placed: return (1.0, 0.8, 0.0, 0.3)    // Yellow
        case .validating: return (0.5, 0.0, 1.0, 0.3) // Purple
        case .validated: return (0.0, 1.0, 0.0, 0.5)  // Green
        case .invalid: return (1.0, 0.0, 0.0, 0.5)    // Red
        }
    }
    
    /// Should show pulsing animation
    var shouldPulse: Bool {
        switch state {
        case .validating, .placed:
            return true
        default:
            return false
        }
    }
}