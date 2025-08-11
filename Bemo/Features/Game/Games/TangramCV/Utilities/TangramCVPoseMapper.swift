//
//  TangramCVPoseMapper.swift
//  Bemo
//
//  Centralized utility for coordinate space transformations between raw (DB/CV) and SpriteKit spaces for CV game
//

// WHAT: Maps between raw puzzle/CV space and SpriteKit rendering space with consistent conventions
// ARCHITECTURE: Self-contained utility for CV game coordinate conversions
// USAGE: Call static methods to convert angles and positions between coordinate spaces

import CoreGraphics
import Foundation

public struct TangramCVPoseMapper {
    
    // MARK: - Raw Space Extraction (DB/CV Convention)
    
    /// Extracts raw angle from transform using atan2(b, a), normalized to [-π, π]
    /// This is the angle as stored in DB or received from CV
    public static func rawAngle(from transform: CGAffineTransform) -> CGFloat {
        return atan2(transform.b, transform.a)
    }
    
    /// Extracts raw position from transform (tx, ty) with Y-down screen convention
    /// This is the position as stored in DB or received from CV
    public static func rawPosition(from transform: CGAffineTransform) -> CGPoint {
        return CGPoint(x: transform.tx, y: transform.ty)
    }
    
    // MARK: - Raw to SpriteKit Conversion
    
    /// Converts raw angle to SpriteKit zRotation
    /// Policy: SK angle = -raw angle (inverts sign for Y-up coordinate system)
    public static func spriteKitAngle(fromRawAngle rawAngle: CGFloat) -> CGFloat {
        return -rawAngle
    }
    
    /// Converts raw position to SpriteKit position
    /// Policy: SK position = (raw.x, -raw.y) (inverts Y for Y-up coordinate system)
    public static func spriteKitPosition(fromRawPosition rawPosition: CGPoint) -> CGPoint {
        return CGPoint(x: rawPosition.x, y: -rawPosition.y)
    }
    
    // MARK: - SpriteKit to Raw Conversion (Inverse)
    
    /// Converts SpriteKit zRotation back to raw angle
    /// Inverse of spriteKitAngle conversion
    public static func rawAngle(fromSpriteKitAngle skAngle: CGFloat) -> CGFloat {
        return -skAngle
    }
    
    /// Converts SpriteKit position back to raw position
    /// Inverse of spriteKitPosition conversion
    public static func rawPosition(fromSpriteKitPosition skPosition: CGPoint) -> CGPoint {
        return CGPoint(x: skPosition.x, y: -skPosition.y)
    }
    
    // MARK: - Transform Builders
    
    /// Creates a CGAffineTransform from raw angle and position
    /// Useful for constructing transforms from CV data or DB storage
    public static func rawTransform(angle: CGFloat, position: CGPoint) -> CGAffineTransform {
        let rotation = CGAffineTransform(rotationAngle: angle)
        let translation = CGAffineTransform(translationX: position.x, y: position.y)
        return rotation.concatenating(translation)
    }
    
    /// Creates transform components for SpriteKit from raw transform
    /// Returns tuple of (skAngle, skPosition) ready for node assignment
    public static func spriteKitComponents(fromRawTransform transform: CGAffineTransform) -> (angle: CGFloat, position: CGPoint) {
        let rawAngle = self.rawAngle(from: transform)
        let rawPos = self.rawPosition(from: transform)
        return (
            angle: spriteKitAngle(fromRawAngle: rawAngle),
            position: spriteKitPosition(fromRawPosition: rawPos)
        )
    }
    
    // MARK: - Angle Normalization
    
    /// Normalizes angle to [-π, π] range
    /// Ensures consistent angle representation across conversions
    public static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle
        while normalized > .pi {
            normalized -= 2 * .pi
        }
        while normalized < -.pi {
            normalized += 2 * .pi
        }
        return normalized
    }
    
    // MARK: - Debugging Helpers
    
    /// Returns a debug string showing both raw and SK representations
    /// Useful for logging and debugging coordinate conversions
    public static func debugString(forRawTransform transform: CGAffineTransform) -> String {
        let rawAng = rawAngle(from: transform)
        let rawPos = rawPosition(from: transform)
        let skAng = spriteKitAngle(fromRawAngle: rawAng)
        let skPos = spriteKitPosition(fromRawPosition: rawPos)
        
        let rawDegrees = rawAng * 180 / .pi
        let skDegrees = skAng * 180 / .pi
        
        return """
        Transform Debug:
          Raw: angle=\(String(format: "%.1f°", rawDegrees)) pos=(\(String(format: "%.1f", rawPos.x)), \(String(format: "%.1f", rawPos.y)))
          SK:  angle=\(String(format: "%.1f°", skDegrees)) pos=(\(String(format: "%.1f", skPos.x)), \(String(format: "%.1f", skPos.y)))
        """
    }
}

// MARK: - Future Flexibility Note

/*
 If we later decide to flip the entire SpriteKit layer (e.g., puzzleLayer.yScale = -1)
 to get a Y-down visual space, we only need to change the two conversion functions:
 - spriteKitAngle(fromRawAngle:) 
 - spriteKitPosition(fromRawPosition:)
 
 All other code using this mapper will automatically adapt to the new convention.
 This is the power of having a single conversion utility as the source of truth.
 */