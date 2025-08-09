//
//  TangramRotationValidator.swift
//  Bemo
//
//  Validates piece rotations accounting for symmetry
//

// WHAT: Handles rotation validation with proper symmetry for each piece type
// ARCHITECTURE: Model/Service in MVVM-S, used by puzzle validation logic
// USAGE: Call isRotationValid to check if a piece's rotation matches target

import Foundation
import CoreGraphics

struct TangramRotationValidator {
    
    // MARK: - Symmetry Definitions
    
    /// Returns the rotational symmetry fold for each piece type
    /// e.g., 4 means the piece looks identical at 0°, 90°, 180°, 270°
    static func rotationalSymmetryFold(for pieceType: TangramPieceType, isFlipped: Bool) -> Int {
        switch pieceType {
        case .square:
            // Square has 4-fold symmetry (90° rotations)
            return 4
            
        case .smallTriangle1, .smallTriangle2,
             .mediumTriangle, .largeTriangle1, .largeTriangle2:
            // Right triangles have NO rotational symmetry
            // Each orientation is unique (right angle position matters)
            return 1
            
        case .parallelogram:
            // Parallelogram has 2-fold symmetry (180° rotation)
            // But only when not flipped (flipping breaks the symmetry)
            return isFlipped ? 1 : 2
        }
    }
    
    // MARK: - Validation
    
    /// Validates if a piece's rotation matches the target, accounting for symmetry
    /// - Parameters:
    ///   - currentRotation: The current rotation of the piece (in radians)
    ///   - targetRotation: The target rotation from the puzzle (in radians)
    ///   - pieceType: The type of piece being validated
    ///   - isFlipped: Whether the piece is currently flipped
    ///   - tolerance: Rotation tolerance in degrees (converted to radians)
    /// - Returns: True if the rotation is valid considering symmetry
    static func isRotationValid(
        currentRotation: CGFloat,
        targetRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        toleranceDegrees: CGFloat = 25.0
    ) -> Bool {
        
        let toleranceRadians = toleranceDegrees * .pi / 180
        let symmetryFold = rotationalSymmetryFold(for: pieceType, isFlipped: isFlipped)
        
        #if DEBUG
        print("       🔄 Rotation validation for \(pieceType.rawValue):")
        print("          Current: \(currentRotation * 180 / .pi)°")
        print("          Target: \(targetRotation * 180 / .pi)°")
        print("          Is flipped: \(isFlipped)")
        print("          Symmetry fold: \(symmetryFold)")
        print("          Tolerance: \(toleranceDegrees)°")
        #endif
        
        // If no symmetry (fold = 1), just check direct match
        if symmetryFold == 1 {
            let diff = normalizeAngle(currentRotation - targetRotation)
            let isValid = abs(diff) < toleranceRadians
            #if DEBUG
            print("          Direct match check: diff=\(diff * 180 / .pi)°, valid=\(isValid)")
            #endif
            return isValid
        }
        
        // For pieces with symmetry, check all equivalent rotations
        let symmetryAngle = (2 * .pi) / CGFloat(symmetryFold)
        
        for i in 0..<symmetryFold {
            let equivalentRotation = targetRotation + (CGFloat(i) * symmetryAngle)
            let diff = normalizeAngle(currentRotation - equivalentRotation)
            
            #if DEBUG
            print("          Checking equivalent rotation \(i): \(equivalentRotation * 180 / .pi)°")
            print("             Difference: \(diff * 180 / .pi)°")
            #endif
            
            if abs(diff) < toleranceRadians {
                #if DEBUG
                print("          ✅ Match found at equivalent rotation!")
                #endif
                return true
            }
        }
        
        return false
    }
    
    /// Finds the nearest valid rotation for a piece given its symmetry
    /// - Parameters:
    ///   - currentRotation: The current rotation of the piece
    ///   - targetRotation: The target rotation from the puzzle
    ///   - pieceType: The type of piece
    ///   - isFlipped: Whether the piece is flipped
    /// - Returns: The nearest valid rotation accounting for symmetry
    static func nearestValidRotation(
        currentRotation: CGFloat,
        targetRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool
    ) -> CGFloat {
        
        let symmetryFold = rotationalSymmetryFold(for: pieceType, isFlipped: isFlipped)
        
        // If no symmetry, target is the only valid rotation
        if symmetryFold == 1 {
            return targetRotation
        }
        
        // Find the equivalent rotation that's closest to current
        let symmetryAngle = (2 * .pi) / CGFloat(symmetryFold)
        var closestRotation = targetRotation
        var minDifference = abs(normalizeAngle(currentRotation - targetRotation))
        
        for i in 1..<symmetryFold {
            let equivalentRotation = targetRotation + (CGFloat(i) * symmetryAngle)
            let diff = abs(normalizeAngle(currentRotation - equivalentRotation))
            
            if diff < minDifference {
                minDifference = diff
                closestRotation = equivalentRotation
            }
        }
        
        return closestRotation
    }
    
    /// Calculates rotation difference to nearest valid orientation
    /// - Parameters:
    ///   - currentRotation: Current rotation in radians
    ///   - targetRotation: Target rotation in radians
    ///   - pieceType: Type of piece
    ///   - isFlipped: Whether piece is flipped
    /// - Returns: Smallest rotation difference to any valid orientation
    static func rotationDifferenceToNearest(
        currentRotation: CGFloat,
        targetRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool
    ) -> CGFloat {
        
        let nearest = nearestValidRotation(
            currentRotation: currentRotation,
            targetRotation: targetRotation,
            pieceType: pieceType,
            isFlipped: isFlipped
        )
        
        return normalizeAngle(currentRotation - nearest)
    }
    
    // MARK: - Helpers
    
    /// Normalizes an angle to the range [-π, π]
    private static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle
        
        // Bring to range [-2π, 2π]
        normalized = normalized.truncatingRemainder(dividingBy: 2 * .pi)
        
        // Bring to range [-π, π]
        if normalized > .pi {
            normalized -= 2 * .pi
        } else if normalized < -.pi {
            normalized += 2 * .pi
        }
        
        return normalized
    }
}