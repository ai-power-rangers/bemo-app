//
//  TangramPieceValidator.swift
//  Bemo
//
//  Centralized validation logic for tangram piece placement
//

// WHAT: Single source of truth for validating if a placed piece matches a target position
// ARCHITECTURE: Service in MVVM-S, used by all components that need placement validation
// USAGE: Call validatePiece() to check if a piece is correctly placed

import Foundation
import CoreGraphics

/// Service for validating tangram piece placements
class TangramPieceValidator {
    
    // MARK: - Properties
    
    private let positionTolerance: CGFloat
    private let rotationTolerance: CGFloat
    private let edgeContactTolerance: CGFloat
    
    // MARK: - Initialization
    
    init(positionTolerance: CGFloat = TangramGameConstants.Validation.positionTolerance,
         rotationTolerance: CGFloat = TangramGameConstants.Validation.rotationTolerance,
         edgeContactTolerance: CGFloat = 14.0) {
        self.positionTolerance = positionTolerance
        self.rotationTolerance = rotationTolerance
        self.edgeContactTolerance = edgeContactTolerance
    }
    
    // MARK: - Validation Result Type
    
    typealias ValidationResult = (positionValid: Bool, rotationValid: Bool, flipValid: Bool)
    
    // MARK: - Main Validation Method
    
    /// Validates placement using feature angles for consistent comparison
    /// - Parameters:
    ///   - piecePosition: Current position of the piece (in scene space)
    ///   - pieceFeatureAngle: Current feature angle of the piece (zRotation + localFeature)
    ///   - targetFeatureAngle: Target feature angle from the puzzle
    ///   - pieceType: Type of the piece
    ///   - isFlipped: Whether the piece is flipped
    ///   - targetTransform: Transform from puzzle data (for flip detection)
    ///   - targetWorldPos: World position for the target (in scene space)
    /// - Returns: Tuple of (positionValid, rotationValid, flipValid)
    func validateForSpriteKitWithFeatures(
        piecePosition: CGPoint,
        pieceFeatureAngle: CGFloat,
        targetFeatureAngle: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> ValidationResult {
        
        // Validate position (allow polygon contact override)
        let centroidDistance = hypot(piecePosition.x - targetWorldPos.x, piecePosition.y - targetWorldPos.y)
        var positionValid = centroidDistance < positionTolerance
        if !positionValid {
            // Try polygon-to-polygon min distance as contact override
            let targetVertsSK = TangramGeometryUtilities.transformedVertices(
                for: pieceType,
                isFlipped: detectFlip(from: targetTransform),
                zRotation: TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: targetTransform)),
                translation: targetWorldPos
            )
            let pieceVertsSK = TangramGeometryUtilities.transformedVertices(
                for: pieceType,
                isFlipped: isFlipped,
                zRotation: pieceFeatureAngle, // approximate; feature angle differs by local baseline but fine for proximity check
                translation: piecePosition
            )
            let minDist = TangramGeometryUtilities.minimumDistanceBetweenPolygons(targetVertsSK, pieceVertsSK)
            positionValid = minDist < edgeContactTolerance
        }
        
        // Validate rotation - feature angle comparison with symmetry
        let rotationValid = TangramRotationValidator.isRotationValid(
            currentRotation: pieceFeatureAngle,
            targetRotation: targetFeatureAngle,
            pieceType: pieceType,
            isFlipped: isFlipped,
            toleranceDegrees: rotationTolerance
        )
        
        // Validate flip state (for parallelogram only)
        let flipValid: Bool
        if pieceType == .parallelogram {
            let targetIsFlipped = detectFlip(from: targetTransform)
            // Inverted logic for parallelograms due to coordinate system handedness
            flipValid = (isFlipped != targetIsFlipped)
        } else {
            flipValid = true
        }
        
        return (positionValid, rotationValid, flipValid)
    }
    
    // MARK: - Legacy Methods Removed
    // All deprecated validation methods have been removed.
    // Use validateForSpriteKitWithFeatures for all validation needs.
    // For placed piece validation, use the TangramValidationEngine instead.
    
    // MARK: - Helper Methods
    
    /// Detects if a transform represents a flipped piece
    private func detectFlip(from transform: CGAffineTransform) -> Bool {
        let determinant = transform.a * transform.d - transform.b * transform.c
        return determinant < 0
    }
}