//
//  PlacedPiece.swift
//  Bemo
//
//  Model representing a tangram piece placed by the player via CV recognition
//

// WHAT: Bridges CV-recognized pieces to tangram game pieces, tracking placement and validation state
// ARCHITECTURE: Model in MVVM-S, created from RecognizedPiece data and enriched with game context
// USAGE: Created when CV detects pieces, used for validation and progress tracking

import Foundation
import CoreGraphics

struct PlacedPiece: Identifiable, Codable {
    
    // MARK: - Properties from CV
    
    let id: String // Consistent piece ID from CV
    let pieceType: TangramPieceType
    var position: CGPoint
    var rotation: Double
    var velocity: CGVector
    var isMoving: Bool
    let confidence: Double
    let timestamp: Date
    let frameNumber: Int
    
    // MARK: - Game Context
    
    var validationState: ValidationState = .pending
    var relativePosition: CGPoint? // Position relative to anchor piece
    var relativeRotation: Double? // Rotation relative to anchor piece
    var isPlaced: Bool = false // True when piece is stationary and placed
    var lastStationaryTime: Date? // When piece stopped moving
    var isFlipped: Bool = false // Track if piece is flipped (important for parallelogram)
    var assignedTargetId: String? // Instance-specific target binding for duplicates
    
    // MARK: - Validation State
    
    enum ValidationState: String, Codable {
        case pending    // Not yet validated
        case correct    // Correctly placed
        case incorrect  // Incorrectly placed
    }
    
    // MARK: - Initialization
    
    init(from recognized: RecognizedPiece) {
        self.id = recognized.id
        self.pieceType = TangramPieceType(rawValue: recognized.pieceTypeId) ?? .smallTriangle1
        self.position = recognized.position
        self.rotation = recognized.rotation
        self.velocity = recognized.velocity
        self.isMoving = recognized.isMoving
        self.confidence = recognized.confidence
        self.timestamp = recognized.timestamp
        self.frameNumber = recognized.frameNumber
        
        // Mark as placed if not moving
        if !isMoving {
            self.isPlaced = true
            self.lastStationaryTime = timestamp
        }
    }
    
    /// Convenience initializer for creating a manual placed piece (non-CV path)
    init(id: String = UUID().uuidString,
         pieceType: TangramPieceType,
         position: CGPoint,
         rotation: Double,
         isFlipped: Bool) {
        self.id = id
        self.pieceType = pieceType
        self.position = position
        self.rotation = rotation
        self.velocity = CGVector(dx: 0, dy: 0)
        self.isMoving = false
        self.confidence = 1.0
        self.timestamp = Date()
        self.frameNumber = 0
        self.validationState = .pending
        self.relativePosition = nil
        self.relativeRotation = nil
        self.isPlaced = true
        self.lastStationaryTime = self.timestamp
        self.isFlipped = isFlipped
        self.assignedTargetId = nil
    }
    
    // MARK: - Movement Analysis
    
    var isStationary: Bool {
        !isMoving && velocity.dx < 1.0 && velocity.dy < 1.0
    }
    
    var placementDuration: TimeInterval? {
        guard let stationaryTime = lastStationaryTime else { return nil }
        return Date().timeIntervalSince(stationaryTime)
    }
    
    func isPlacedLongEnough(threshold: TimeInterval = 0.5) -> Bool {
        guard let duration = placementDuration else { return false }
        return duration >= threshold
    }
    
    // MARK: - Helper Methods
    
    func calculateRelativePosition(to anchor: PlacedPiece) -> CGPoint {
        CGPoint(
            x: position.x - anchor.position.x,
            y: position.y - anchor.position.y
        )
    }
    
    func calculateRelativeRotation(to anchor: PlacedPiece) -> Double {
        var diff = rotation - anchor.rotation
        // Normalize to -180 to 180 range
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }
    
    func updateRelativeToAnchor(_ anchor: PlacedPiece) -> PlacedPiece {
        var updated = self
        updated.relativePosition = calculateRelativePosition(to: anchor)
        updated.relativeRotation = calculateRelativeRotation(to: anchor)
        return updated
    }
}

// MARK: - Extensions

extension PlacedPiece {
    
    var isValidPlacement: Bool {
        validationState == .correct
    }
    
    var area: Double {
        // Actual mathematical areas from tangram-101.md
        switch pieceType {
        case .largeTriangle1, .largeTriangle2:
            return 2.0  // 2 square units each
        case .mediumTriangle:
            return 1.0  // 1 square unit
        case .smallTriangle1, .smallTriangle2:
            return 0.5  // 0.5 square units each
        case .square:
            return 1.0  // 1 square unit
        case .parallelogram:
            return 1.0  // 1 square unit
        }
    }
    
    /// Calculates distance from the center of the canvas
    /// - Parameter canvasSize: The size of the canvas. Defaults to standard 600x600 if not provided
    /// - Returns: Distance from center in pixels
    func distanceFromCenter(canvasSize: CGSize = CGSize(width: 600, height: 600)) -> Double {
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        let dx = position.x - centerX
        let dy = position.y - centerY
        return sqrt(dx * dx + dy * dy)
    }
}