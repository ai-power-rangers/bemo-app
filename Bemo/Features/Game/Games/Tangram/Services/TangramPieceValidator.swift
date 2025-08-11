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
    func validate(placed: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool {
        // Piece type must match
        guard placed.pieceType == target.pieceType else {
            return false
        }
        
        // Extract target position and TRUE expected SK rotation (no baseline adjustment)
        let rawPosition = TangramPoseMapper.rawPosition(from: target.transform)
        let targetPosition = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPosition)
        
        let rawAngle = TangramPoseMapper.rawAngle(from: target.transform)
        let expectedZRotationSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
        
        // Check position
        let distance = hypot(placed.position.x - targetPosition.x, placed.position.y - targetPosition.y)
        guard distance < positionTolerance else {
            return false
        }
        
        // Check flip state for parallelogram
        if placed.pieceType == .parallelogram {
            let targetIsFlipped = detectFlip(from: target.transform)
            // Inverted logic for parallelograms
            guard placed.isFlipped != targetIsFlipped else {
                return false
            }
        }
        
        // Check rotation with symmetry
        let placedRotationRad = placed.rotation * .pi / 180
        let rotationValid = TangramRotationValidator.isRotationValid(
            currentRotation: placedRotationRad,
            targetRotation: expectedZRotationSK,
            pieceType: placed.pieceType,
            isFlipped: placed.isFlipped,
            toleranceDegrees: rotationTolerance
        )
        
        return rotationValid
    }
    
    // MARK: - Helper Methods
    
    /// Detects if a transform represents a flipped piece
    private func detectFlip(from transform: CGAffineTransform) -> Bool {
        let determinant = transform.a * transform.d - transform.b * transform.c
        return determinant < 0
    }
}