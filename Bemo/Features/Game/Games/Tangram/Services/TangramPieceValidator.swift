//
//  TangramPieceValidator.swift
//  Bemo
//
//  Centralized validation logic for tangram piece placement
//

// WHAT: Single source of truth for validating if a placed piece matches a target position
// ARCHITECTURE: Service in MVVM-S, used by all components that need placement validation
// USAGE: Call validate() to check if a piece is correctly placed within tolerances

import Foundation
import CoreGraphics

struct TangramPieceValidator {
    
    // MARK: - Main Validation Method
    
    /// Validates if a placed piece matches a target position within tolerances
    /// - Parameters:
    ///   - placed: The piece placed by the player
    ///   - target: The target position from the puzzle solution
    /// - Returns: True if the piece matches within position and rotation tolerances
    static func validate(placed: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool {
        // 1. Piece type must match
        guard placed.pieceType == target.pieceType else { 
            return false 
        }
        
        // 2. Extract target position and rotation from transform
        let targetPosition = CGPoint(x: target.transform.tx, y: target.transform.ty)
        let targetRotation = atan2(target.transform.b, target.transform.a)
        
        // 3. Check if position is within tolerance
        let distance = hypot(
            placed.position.x - targetPosition.x,
            placed.position.y - targetPosition.y
        )
        
        guard distance < TangramGameConstants.Validation.positionTolerance else {
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
            toleranceDegrees: TangramGameConstants.Validation.rotationTolerance
        )
        
        return rotationValid
    }
    
    // MARK: - SpriteKit Validation
    
    /// Validates placement for SpriteKit scene (uses radians for rotation)
    /// - Parameters:
    ///   - piecePosition: Current position of the piece
    ///   - pieceRotation: Current rotation in radians
    ///   - pieceType: Type of the piece
    ///   - isFlipped: Whether the piece is flipped
    ///   - targetTransform: ORIGINAL transform from puzzle data (not adjusted)
    ///   - targetWorldPos: World position for the target (already adjusted for SpriteKit)
    /// - Returns: Tuple of (positionValid, rotationValid, flipValid)
    static func validateForSpriteKit(
        piecePosition: CGPoint,
        pieceRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> (positionValid: Bool, rotationValid: Bool, flipValid: Bool) {
        
        // Extract rotation from ORIGINAL transform (CoreGraphics coordinates)
        // IMPORTANT: Both CoreGraphics and SpriteKit use the same rotation convention
        // when angles are in radians. The Y-flip only affects coordinates, not rotation angles!
        let targetRotation = atan2(targetTransform.b, targetTransform.a)
        
        // Check position using provided world position
        let distance = hypot(
            piecePosition.x - targetWorldPos.x,
            piecePosition.y - targetWorldPos.y
        )
        let positionValid = distance < TangramGameConstants.Validation.positionTolerance
        
        // Check rotation with symmetry
        let rotationValid = TangramRotationValidator.isRotationValid(
            currentRotation: pieceRotation,
            targetRotation: targetRotation,
            pieceType: pieceType,
            isFlipped: isFlipped,
            toleranceDegrees: TangramGameConstants.Validation.rotationTolerance
        )
        
        // Detect flip from ORIGINAL transform
        let targetIsFlipped = detectFlip(from: targetTransform)
        
        // For parallelogram, flip MUST match exactly
        // For other pieces, flip doesn't matter (they're symmetric)
        let flipValid: Bool
        if pieceType == .parallelogram {
            // IMPORTANT: The piece's isFlipped state is INVERTED from what the transform indicates
            // When piece isFlipped = true, it shows the normal parallelogram
            // When transform determinant > 0 (not flipped), we need piece isFlipped = true
            // So we need to invert the comparison
            flipValid = (isFlipped != targetIsFlipped)  // INVERTED!
            
            #if DEBUG
            print("DEBUG: Parallelogram flip check:")
            print("  Piece isFlipped: \(isFlipped)")
            print("  Target transform determinant: \(targetTransform.a * targetTransform.d - targetTransform.b * targetTransform.c)")
            print("  Target detected as flipped: \(targetIsFlipped)")
            print("  Flip valid: \(flipValid)")
            if !flipValid {
                print("  MISMATCH! Piece flip state doesn't match target")
            }
            #endif
        } else {
            flipValid = true  // Other pieces don't need flip validation
        }
        
        #if DEBUG
        print("\n=== Validation for \(pieceType.rawValue) ===")
        print("Transform: a=\(targetTransform.a), b=\(targetTransform.b), c=\(targetTransform.c), d=\(targetTransform.d)")
        // Normalize angles for display
        let normalizedPieceRot = atan2(sin(pieceRotation), cos(pieceRotation))
        let normalizedTargetRot = atan2(sin(targetRotation), cos(targetRotation))
        print("Rotations:")
        print("  Target: \(targetRotation * 180 / .pi)° (normalized: \(normalizedTargetRot * 180 / .pi)°)")
        print("  Piece: \(pieceRotation * 180 / .pi)° (normalized: \(normalizedPieceRot * 180 / .pi)°)")
        print("  Difference: \((normalizedPieceRot - normalizedTargetRot) * 180 / .pi)°")
        print("Position:")
        print("  Target: (\(targetWorldPos.x), \(targetWorldPos.y))")
        print("  Piece: (\(piecePosition.x), \(piecePosition.y))")
        print("  Distance: \(distance) (tolerance: \(TangramGameConstants.Validation.positionTolerance))")
        print("Flip:")
        print("  Transform determinant: \(targetTransform.a * targetTransform.d - targetTransform.b * targetTransform.c)")
        print("  Target flipped: \(targetIsFlipped)")
        print("  Piece flipped: \(isFlipped)")
        print("  Piece type: \(pieceType.rawValue)")
        print("  Flip validation required: \(pieceType == .parallelogram)")
        print("Results: pos=\(positionValid), rot=\(rotationValid), flip=\(flipValid)")
        print("===================================\n")
        #endif
        
        return (positionValid, rotationValid, flipValid)
    }
    
    // MARK: - Helper Methods
    
    /// Detects if a transform represents a flipped piece
    /// A negative determinant indicates a flip transformation
    private static func detectFlip(from transform: CGAffineTransform) -> Bool {
        let determinant = transform.a * transform.d - transform.b * transform.c
        
        #if DEBUG
        if abs(determinant) < 0.01 {
            print("WARNING: Transform determinant is near zero: \(determinant)")
        }
        #endif
        
        return determinant < 0
    }
    
    // MARK: - Legacy Vertex-Based Validation
    
    /// Legacy validation method that compares vertices after transformation
    /// This is kept for backwards compatibility but should be phased out
    static func validateByVertices(placed: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool {
        guard placed.pieceType == target.pieceType else { return false }
        
        // Get transformed vertices for both pieces
        let targetVertices = getTargetVertices(target)
        let placedVertices = getPlacedVertices(placed)
        
        // Check if vertices match within tolerance
        return verticesMatch(
            targetVertices, 
            placedVertices, 
            tolerance: TangramGameConstants.Validation.vertexTolerance
        )
    }
    
    private static func getTargetVertices(_ target: GamePuzzleData.TargetPiece) -> [CGPoint] {
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        return TangramGameGeometry.transformVertices(scaledVertices, with: target.transform)
    }
    
    private static func getPlacedVertices(_ placed: PlacedPiece) -> [CGPoint] {
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: placed.pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        
        // Create transform from placed piece position and rotation
        var pieceTransform = CGAffineTransform.identity
        pieceTransform = pieceTransform.translatedBy(x: placed.position.x, y: placed.position.y)
        pieceTransform = pieceTransform.rotated(by: placed.rotation * .pi / 180)
        
        return TangramGameGeometry.transformVertices(scaledVertices, with: pieceTransform)
    }
    
    private static func verticesMatch(_ vertices1: [CGPoint], _ vertices2: [CGPoint], tolerance: CGFloat) -> Bool {
        guard vertices1.count == vertices2.count else { return false }
        
        for i in 0..<vertices1.count {
            let distance = hypot(vertices1[i].x - vertices2[i].x, vertices1[i].y - vertices2[i].y)
            if distance > tolerance { return false }
        }
        return true
    }
}