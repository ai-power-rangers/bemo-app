//
//  TangramPieceValidator.swift
//  Bemo
//
//  Centralized validation logic for tangram piece placement
//

// WHAT: Single source of truth for validating if a placed piece matches a target position
// ARCHITECTURE: Service in MVVM-S, used by all components that need placement validation
// USAGE: Inject as service, call validate() to check if a piece is correctly placed

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
    
    // MARK: - Main Validation Method
    
    /// Validates if a placed piece matches a target position within tolerances
    /// - Parameters:
    ///   - placed: The piece placed by the player
    ///   - target: The target position from the puzzle solution
    /// - Returns: True if the piece matches within position and rotation tolerances
    func validate(placed: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool {
        // 1. Piece type must match
        guard placed.pieceType == target.pieceType else { 
            return false 
        }
        
        // 2. Extract target position and rotation from transform
        let targetPosition = CGPoint(x: target.transform.tx, y: target.transform.ty)
        // Use sceneRotation for consistency with Y-flipped rendering
        let targetRotation = CGFloat(TangramGeometryUtilities.sceneRotation(from: target.transform))
        
        // 3. Check if position is within tolerance
        let distance = hypot(
            placed.position.x - targetPosition.x,
            placed.position.y - targetPosition.y
        )
        
        guard distance < positionTolerance else {
            return false
        }
        
        // 4. Check if flip state matches (for parallelogram)
        let targetIsFlipped = detectFlip(from: target.transform)
        
        // For parallelogram, flip state must match
        if placed.pieceType == .parallelogram && placed.isFlipped != targetIsFlipped {
            return false
        }
        
        // 5. Check if rotation matches (accounting for symmetry and flip state)
        let rotationValid = TangramRotationValidator.isRotationValid(
            currentRotation: placed.rotation * .pi / 180, // Convert to radians
            targetRotation: targetRotation,
            pieceType: placed.pieceType,
            isFlipped: placed.isFlipped,  // Use actual flip state from placed piece
            toleranceDegrees: rotationTolerance
        )
        
        return rotationValid
    }
    
    // MARK: - SpriteKit Validation
    
    typealias ValidationResult = (positionValid: Bool, rotationValid: Bool, flipValid: Bool)
    
    /// Validates placement for SpriteKit scene (uses radians for rotation)
    /// - Parameters:
    ///   - piecePosition: Current position of the piece
    ///   - pieceRotation: Current rotation in radians
    ///   - pieceType: Type of the piece
    ///   - isFlipped: Whether the piece is flipped
    ///   - targetTransform: ORIGINAL transform from puzzle data (not adjusted)
    ///   - targetWorldPos: World position for the target (already adjusted for SpriteKit)
    /// - Returns: Tuple of (positionValid, rotationValid, flipValid)
    func validateForSpriteKit(
        piecePosition: CGPoint,
        pieceRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> ValidationResult {
        
        // Extract rotation from the ORIGINAL transform (not the sprite's)
        // IMPORTANT: Target silhouettes are rendered with Y inverted in SpriteKit.
        // Use sceneRotation to convert to the scene's coordinate space.
        let targetRotation = TangramGeometryUtilities.sceneRotation(from: targetTransform)
        
        #if DEBUG
        print("  🎯 \(pieceType.rawValue) validation:")
        print("    Transform a,b,c,d: \(targetTransform.a), \(targetTransform.b), \(targetTransform.c), \(targetTransform.d)")
        print("    Raw rotation from transform: \(TangramGeometryUtilities.extractRotation(from: targetTransform) * 180 / .pi)°")
        print("    Scene-space target rotation: \(targetRotation * 180 / .pi)°")
        print("    Current piece rotation: \(pieceRotation * 180 / .pi)°")
        print("    Rotation difference: \((pieceRotation - targetRotation) * 180 / .pi)°")
        print("    Tolerance: \(rotationTolerance)°")
        print("    Is flipped: \(isFlipped)")
        #endif
        
        // Validate position
        let distance = hypot(piecePosition.x - targetWorldPos.x, piecePosition.y - targetWorldPos.y)
        let positionValid = distance < positionTolerance
        
        // Validate rotation (accounting for symmetry)
        let rotationValid = TangramRotationValidator.isRotationValid(
            currentRotation: pieceRotation,
            targetRotation: targetRotation,
            pieceType: pieceType,
            isFlipped: isFlipped,
            toleranceDegrees: rotationTolerance
        )
        
        // Validate flip state (for parallelogram)
        var flipValid = true
        if pieceType == .parallelogram {
            let targetIsFlipped = detectFlip(from: targetTransform)
            // IMPORTANT: The piece's isFlipped state is INVERTED from what the transform indicates
            // When piece isFlipped = true, it shows the normal parallelogram
            // When transform determinant > 0 (not flipped), we need piece isFlipped = true
            // So we need to invert the comparison
            flipValid = (isFlipped != targetIsFlipped)  // INVERTED!
        } else {
            flipValid = true  // Other pieces don't need flip validation
        }
        
        return (positionValid, rotationValid, flipValid)
    }
    
    // MARK: - Helper Methods
    
    
    /// Detects if a transform represents a flipped piece
    /// A negative determinant indicates a flip transformation
    private func detectFlip(from transform: CGAffineTransform) -> Bool {
        return TangramGeometryUtilities.isTransformFlipped(transform)
    }
}

// MARK: - Static Compatibility Layer (for migration)

extension TangramPieceValidator {
    /// Static validation method for backward compatibility
    /// @deprecated: Use instance method instead
    static func validate(placed: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool {
        let validator = TangramPieceValidator()
        return validator.validate(placed: placed, target: target)
    }
    
    /// Static SpriteKit validation for backward compatibility
    /// @deprecated: Use instance method instead
    static func validateForSpriteKit(
        piecePosition: CGPoint,
        pieceRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> ValidationResult {
        let validator = TangramPieceValidator()
        return validator.validateForSpriteKit(
            piecePosition: piecePosition,
            pieceRotation: pieceRotation,
            pieceType: pieceType,
            isFlipped: isFlipped,
            targetTransform: targetTransform,
            targetWorldPos: targetWorldPos
        )
    }
}