//
//  TangramGeometryUtilities.swift
//  Bemo
//
//  Centralized geometry utilities for Tangram game
//

// WHAT: Shared geometry calculations and transformations for Tangram pieces
// ARCHITECTURE: Utility enum with static methods, no state
// USAGE: Used throughout Tangram for consistent geometry operations

import Foundation
import CoreGraphics

/// Centralized geometry utilities for Tangram game
enum TangramGeometryUtilities {
    
    // MARK: - Transform Operations
    
    /// Extracts rotation angle from CGAffineTransform with robust floating-point handling
    /// Handles cases where sin/cos values have floating-point precision errors (e.g., 180° rotations)
    static func extractRotation(from transform: CGAffineTransform) -> Double {
        let a = Double(transform.a)
        let b = Double(transform.b)
        
        // Handle floating-point precision errors for common angles
        let epsilon: Double = 1e-10
        
        // Check for 180° rotation: a ≈ -1, b ≈ 0
        if abs(a + 1) < epsilon && abs(b) < epsilon {
            return .pi  // 180 degrees in radians
        }
        
        // Check for 0° rotation: a ≈ 1, b ≈ 0
        if abs(a - 1) < epsilon && abs(b) < epsilon {
            return 0  // 0 degrees
        }
        
        // Check for 90° rotation: a ≈ 0, b ≈ 1
        if abs(a) < epsilon && abs(b - 1) < epsilon {
            return .pi / 2  // 90 degrees
        }
        
        // Check for -90° (270°) rotation: a ≈ 0, b ≈ -1
        if abs(a) < epsilon && abs(b + 1) < epsilon {
            return -.pi / 2  // -90 degrees
        }
        
        // For all other cases, use standard atan2
        return atan2(b, a)
    }

    // MARK: - Polygon Utilities

    /// Returns the vertices of a piece in scene space given flip, rotation and translation
    static func transformedVertices(for pieceType: TangramPieceType,
                                    isFlipped: Bool,
                                    zRotation: CGFloat,
                                    translation: CGPoint) -> [CGPoint] {
        let base = TangramGameGeometry.scaleVertices(
            TangramGameGeometry.normalizedVertices(for: pieceType),
            by: TangramGameConstants.visualScale
        )
        let flipped = isFlipped ? base.map { CGPoint(x: -$0.x, y: $0.y) } : base
        let cosA = cos(zRotation)
        let sinA = sin(zRotation)
        let rotated = flipped.map { v in CGPoint(x: v.x * cosA - v.y * sinA, y: v.x * sinA + v.y * cosA) }
        return rotated.map { CGPoint(x: $0.x + translation.x, y: $0.y + translation.y) }
    }

    /// Computes the minimum distance between two polygons (arrays of points) in the same coordinate space
    static func minimumDistanceBetweenPolygons(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        func edges(_ poly: [CGPoint]) -> [(CGPoint, CGPoint)] {
            guard poly.count >= 2 else { return [] }
            return (0..<poly.count).map { i in (poly[i], poly[(i+1) % poly.count]) }
        }
        func segmentDistance(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGFloat {
            let u = CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
            let v = CGVector(dx: p4.x - p3.x, dy: p4.y - p3.y)
            let w = CGVector(dx: p1.x - p3.x, dy: p1.y - p3.y)
            let a = u.dx*u.dx + u.dy*u.dy
            let b = u.dx*v.dx + u.dy*v.dy
            let c = v.dx*v.dx + v.dy*v.dy
            let d = u.dx*w.dx + u.dy*w.dy
            let e = v.dx*w.dx + v.dy*w.dy
            let denom = a*c - b*b
            var sc: CGFloat = 0
            var tc: CGFloat = 0
            func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, x)) }
            if denom < 1e-6 {
                sc = 0
                tc = clamp(e/c, 0, 1)
            } else {
                sc = clamp((b*e - c*d)/denom, 0, 1)
                tc = clamp((a*e - b*d)/denom, 0, 1)
            }
            let dpx = w.dx + sc*u.dx - tc*v.dx
            let dpy = w.dy + sc*u.dy - tc*v.dy
            return hypot(dpx, dpy)
        }
        let ea = edges(a)
        let eb = edges(b)
        var minDist: CGFloat = .greatestFiniteMagnitude
        for (a0, a1) in ea { for (b0, b1) in eb {
            let d = segmentDistance(a0, a1, b0, b1)
            if d < minDist { minDist = d }
            if minDist == 0 { return 0 }
        }}
        return minDist
    }
    
    /// Extracts rotation angle for SpriteKit scene space (negated to account for Y-flip in target rendering)
    /// This converts from the stored transform's rotation to the scene's coordinate space
    /// where target silhouettes are rendered with Y inverted
    static func sceneRotation(from transform: CGAffineTransform) -> Double {
        return -extractRotation(from: transform)
    }
    
    /// Extracts rotation angle for SpriteKit scene space (negated to account for Y-flip in target rendering)
    /// This converts from the stored transform's rotation to the scene's coordinate space
    /// where target silhouettes are rendered with Y inverted
    static func sceneRotation(from transform: CGAffineTransform) -> Double {
        return -extractRotation(from: transform)
    }
    
    /// Creates a CGAffineTransform from position, rotation, and scale
    static func createTransform(position: CGPoint, rotation: Double, scale: CGFloat = 1.0) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: position.x, y: position.y)
        transform = transform.rotated(by: rotation)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }
    
    /// Normalizes an angle to the range [-π, π]
    static func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized > .pi {
            normalized -= 2 * .pi
        }
        while normalized < -.pi {
            normalized += 2 * .pi
        }
        return normalized
    }
    
    // MARK: - Distance Calculations
    
    /// Calculates Euclidean distance between two points
    static func calculateDistance(from point1: CGPoint, to point2: CGPoint) -> Double {
        return Double(hypot(point1.x - point2.x, point1.y - point2.y))
    }
    
    /// Checks if two points are within a given tolerance
    static func arePointsWithinTolerance(_ point1: CGPoint, _ point2: CGPoint, tolerance: CGFloat) -> Bool {
        let distance = calculateDistance(from: point1, to: point2)
        return distance <= Double(tolerance)
    }
    
    // MARK: - Angle Calculations
    
    /// Calculates angle between two points
    static func angleBetween(from: CGPoint, to: CGPoint) -> CGFloat {
        return atan2(to.y - from.y, to.x - from.x)
    }
    
    /// Converts degrees to radians
    static func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }
    
    /// Converts radians to degrees
    static func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }
    
    // MARK: - Rotation Equivalence
    
    /// Checks if two angles are equivalent (within tolerance)
    static func areAnglesEquivalent(_ angle1: Double, _ angle2: Double, tolerance: Double = TangramGameConstants.Validation.rotationTolerance) -> Bool {
        let normalized1 = normalizeAngle(angle1)
        let normalized2 = normalizeAngle(angle2)
        let diff = abs(normalized1 - normalized2)
        
        // Check direct difference
        if diff <= tolerance {
            return true
        }
        
        // Check wraparound case (e.g., -π and π are equivalent)
        if abs(diff - 2 * .pi) <= tolerance {
            return true
        }
        
        return false
    }
    
    /// Checks if angle matches any of the valid rotations
    static func matchesValidRotation(_ angle: Double, validRotations: [Double], tolerance: Double = TangramGameConstants.Validation.rotationTolerance) -> Bool {
        let normalizedAngle = normalizeAngle(angle)
        
        for validRotation in validRotations {
            if areAnglesEquivalent(normalizedAngle, validRotation, tolerance: tolerance) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Flip Detection
    
    /// Detects if a transform represents a flipped piece
    /// A negative determinant indicates a flip transformation
    static func isTransformFlipped(_ transform: CGAffineTransform) -> Bool {
        let determinant = transform.a * transform.d - transform.b * transform.c
        return determinant < 0
    }
    
    // MARK: - Piece Geometry
    
    /// Get vertices for a piece type in normalized space (reuse from TangramGameGeometry)
    static func normalizedVertices(for pieceType: TangramPieceType) -> [CGPoint] {
        return TangramGameGeometry.normalizedVertices(for: pieceType)
    }
    
    /// Get centroid (center point) of a piece in normalized space
    static func normalizedCentroid(for pieceType: TangramPieceType) -> CGPoint {
        return TangramGameGeometry.normalizedCentroid(for: pieceType)
    }
    
    /// Apply transform to vertices
    static func transformVertices(_ vertices: [CGPoint], with transform: CGAffineTransform) -> [CGPoint] {
        return TangramGameGeometry.transformVertices(vertices, with: transform)
    }
    
    // MARK: - Rotation Normalization
    
    /// Normalizes an angle to the range [-π, π] (overload for CGFloat)
    static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        return CGFloat(normalizeAngle(Double(angle)))
    }
    
    /// Calculates the smallest angular difference between two angles
    static func angularDifference(from angle1: Double, to angle2: Double) -> Double {
        let diff = normalizeAngle(angle2 - angle1)
        return diff
    }
    
    // MARK: - Bounds Calculations
    
    /// Calculates bounding box for a set of points
    static func calculateBounds(for points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// Calculates center point of a bounding box
    static func centerOfBounds(_ bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    // MARK: - Transform Decomposition
    
    /// Decomposes a transform into its components
    static func decomposeTransform(_ transform: CGAffineTransform) -> TransformComponents {
        let position = CGPoint(x: transform.tx, y: transform.ty)
        let rotation = extractRotation(from: transform)
        let scaleX = sqrt(transform.a * transform.a + transform.b * transform.b)
        let scaleY = sqrt(transform.c * transform.c + transform.d * transform.d)
        
        return TransformComponents(
            position: position,
            rotation: rotation,
            scale: CGSize(width: scaleX, height: scaleY)
        )
    }
    
    struct TransformComponents {
        let position: CGPoint
        let rotation: Double
        let scale: CGSize
    }
}