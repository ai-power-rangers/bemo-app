//
//  CVToInternalConverter.swift
//  Bemo
//
//  Converts CV detection data to internal raw transform format
//

// WHAT: Converts computer vision output (rotation, translation, homography) to raw CGAffineTransform
// ARCHITECTURE: Service layer converter for CV→internal data transformation
// USAGE: Call convertToRawTransform with CV detection data to get raw space transform

import CoreGraphics
import Foundation

struct CVToInternalConverter {
    
    // MARK: - Constants
    
    /// Visual scale factor matching TangramGameConstants
    private static let visualScale: CGFloat = 50.0
    
    /// Camera correction angle (if camera is inverted)
    private static let cameraInversionAngle: CGFloat = .pi  // 180 degrees
    
    // MARK: - Main Conversion
    
    /// Converts CV detection data to raw CGAffineTransform
    /// - Parameters:
    ///   - rotationDegrees: Rotation angle in degrees from CV
    ///   - translation: [x, y] translation from CV
    ///   - homography: Optional 3x3 homography matrix for planar transformation
    ///   - needsCameraInversion: Whether to apply camera inversion (180° rotation + reflection)
    /// - Returns: Raw CGAffineTransform in DB/game convention
    static func convertToRawTransform(
        rotationDegrees: Double,
        translation: [Double],
        homography: [[Double]]? = nil,
        needsCameraInversion: Bool = false
    ) -> CGAffineTransform {
        
        // 1. Convert rotation to radians
        var rotationRadians = CGFloat(rotationDegrees * .pi / 180)
        
        // 2. Extract translation
        var tx = CGFloat(translation[0])
        var ty = CGFloat(translation[1])
        
        // 3. Apply homography if provided (for planar coordinate transformation)
        if let homography = homography, homography.count == 3 {
            let planarCoords = applyHomography(
                point: CGPoint(x: tx, y: ty),
                homography: homography
            )
            tx = planarCoords.x
            ty = planarCoords.y
        }
        
        // 4. Apply camera inversion if needed
        // When camera is inverted: add 180° to rotation and reflect center position
        if needsCameraInversion {
            rotationRadians += cameraInversionAngle
            // Normalize rotation to [-π, π]
            rotationRadians = normalizeAngle(rotationRadians)
            
            // Reflect position around origin (camera center)
            tx = -tx
            ty = -ty
        }
        
        // 5. Scale to game visual scale
        tx *= visualScale
        ty *= visualScale
        
        // 6. Build raw transform (DB/game space convention)
        // This matches the convention used in GamePuzzleData
        let rotation = CGAffineTransform(rotationAngle: rotationRadians)
        let translation = CGAffineTransform(translationX: tx, y: ty)
        
        return rotation.concatenating(translation)
    }
    
    // MARK: - Homography Application
    
    /// Applies a 3x3 homography matrix to transform a point
    /// - Parameters:
    ///   - point: Original 2D point
    ///   - homography: 3x3 homography matrix
    /// - Returns: Transformed point in planar coordinates
    private static func applyHomography(point: CGPoint, homography: [[Double]]) -> CGPoint {
        guard homography.count == 3,
              homography[0].count == 3,
              homography[1].count == 3,
              homography[2].count == 3 else {
            // Invalid homography, return original point
            return point
        }
        
        // Convert point to homogeneous coordinates [x, y, 1]
        let x = Double(point.x)
        let y = Double(point.y)
        
        // Apply homography: [x', y', w'] = H * [x, y, 1]
        let xPrime = homography[0][0] * x + homography[0][1] * y + homography[0][2]
        let yPrime = homography[1][0] * x + homography[1][1] * y + homography[1][2]
        let wPrime = homography[2][0] * x + homography[2][1] * y + homography[2][2]
        
        // Convert back from homogeneous coordinates
        if abs(wPrime) > 0.0001 {  // Avoid division by zero
            return CGPoint(x: CGFloat(xPrime / wPrime), y: CGFloat(yPrime / wPrime))
        } else {
            return point  // Fallback to original if transformation fails
        }
    }
    
    // MARK: - Helper Methods
    
    /// Normalizes angle to [-π, π] range
    private static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle
        while normalized > .pi {
            normalized -= 2 * .pi
        }
        while normalized < -.pi {
            normalized += 2 * .pi
        }
        return normalized
    }
    
    // MARK: - Batch Conversion
    
    /// Converts an array of CV detections to raw transforms
    /// Useful for processing multiple detected pieces at once
    static func convertBatch(
        detections: [(rotation: Double, translation: [Double], pieceType: String)],
        homography: [[Double]]? = nil,
        needsCameraInversion: Bool = false
    ) -> [(transform: CGAffineTransform, pieceType: String)] {
        
        return detections.map { detection in
            let transform = convertToRawTransform(
                rotationDegrees: detection.rotation,
                translation: detection.translation,
                homography: homography,
                needsCameraInversion: needsCameraInversion
            )
            return (transform: transform, pieceType: detection.pieceType)
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Returns debug string for CV to raw conversion
    static func debugString(
        cvRotationDegrees: Double,
        cvTranslation: [Double],
        rawTransform: CGAffineTransform
    ) -> String {
        let rawAngle = TangramCVPoseMapper.rawAngle(from: rawTransform)
        let rawPos = TangramCVPoseMapper.rawPosition(from: rawTransform)
        let rawDegrees = rawAngle * 180 / .pi
        
        return """
        CV to Raw Conversion:
          CV Input: rotation=\(cvRotationDegrees)° translation=[\(cvTranslation[0]), \(cvTranslation[1])]
          Raw Output: angle=\(String(format: "%.1f°", rawDegrees)) pos=(\(String(format: "%.1f", rawPos.x)), \(String(format: "%.1f", rawPos.y)))
        """
    }
}

// MARK: - CV Data Structures

/// Structure matching expected CV output format
struct CVDetection {
    let pieceType: String
    let rotationDegrees: Double
    let translation: [Double]
    let confidence: Double
    let homography: [[Double]]?
    
    /// Converts to raw transform
    func toRawTransform(needsCameraInversion: Bool = false) -> CGAffineTransform {
        return CVToInternalConverter.convertToRawTransform(
            rotationDegrees: rotationDegrees,
            translation: translation,
            homography: homography,
            needsCameraInversion: needsCameraInversion
        )
    }
}