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
    
    // MARK: - Initialization
    
    init(positionTolerance: CGFloat = TangramGameConstants.Validation.positionTolerance,
         rotationTolerance: CGFloat = TangramGameConstants.Validation.rotationTolerance) {
        self.positionTolerance = positionTolerance
        self.rotationTolerance = rotationTolerance
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
        
        // Validate position
        let distance = hypot(piecePosition.x - targetWorldPos.x, piecePosition.y - targetWorldPos.y)
        let positionValid = distance < positionTolerance
        
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
    
    // MARK: - Legacy Support (Deprecated)
    
    /// Legacy validation method - DEPRECATED, use validateForSpriteKitWithFeatures instead
    /// This method mixes raw angles with feature angles and causes validation issues
    @available(*, deprecated, message: "Use validateForSpriteKitWithFeatures for consistent feature-based validation")
    func validateForSpriteKit(
        piecePosition: CGPoint,
        pieceRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> ValidationResult {
        // This legacy path should not be used
        // Return false for all validations to force migration to feature-based validation
        return (false, false, false)
    }
    
    // MARK: - PlacedPiece Support
    
    /// Validates if a placed piece matches a target position within tolerances
    /// DEPRECATED: This method uses raw angles instead of feature angles and causes validation issues.
    /// Use GamePuzzleData.TargetPiece.matches() instead, which internally uses validateForSpriteKitWithFeatures
    @available(*, deprecated, message: "Use GamePuzzleData.TargetPiece.matches() which uses feature-based validation")
    func validate(placed: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool {
        // This method is deprecated - it mixes raw angles with validation logic
        // The correct path is through GamePuzzleData.TargetPiece.matches() which uses feature angles
        // Returning false to force migration to the correct validation path
        print("[WARNING] TangramPieceValidator.validate(placed:target:) is deprecated. Use target.matches(placed) instead.")
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Detects if a transform represents a flipped piece
    private func detectFlip(from transform: CGAffineTransform) -> Bool {
        let determinant = transform.a * transform.d - transform.b * transform.c
        return determinant < 0
    }
}