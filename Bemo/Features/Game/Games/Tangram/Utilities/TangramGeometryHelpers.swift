//
//  TangramGeometryHelpers.swift
//  Bemo
//
//  Geometric calculations and utilities for Tangram validation
//

// WHAT: Pure functions for angle calculations, centroid computation, and feature extraction
// ARCHITECTURE: Utility functions with no state, used by validation services
// USAGE: Import and call static methods for geometric computations

import Foundation
import CoreGraphics

enum TangramGeometryHelpers {
    
    // MARK: - Angle Calculations
    
    /// Compute the signed angle difference between two angles, normalized to [-π, π]
    static func angleDifference(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var diff = a - b
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return diff
    }
    
    /// Convert angle difference to degrees
    static func angleDifferenceDegrees(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        return abs(angleDifference(a, b)) * 180 / .pi
    }
    
    // MARK: - Feature Angles
    
    /// Compute the canonical angle offset for a piece type
    static func canonicalPieceAngle(for type: TangramPieceType) -> CGFloat {
        return type.isTriangle ? (3 * .pi / 4) : 0
    }
    
    /// Compute the canonical angle offset for a target of given type
    static func canonicalTargetAngle(for type: TangramPieceType) -> CGFloat {
        return type.isTriangle ? (.pi / 4) : 0
    }
    
    /// Compute piece feature angle from rotation and flip state
    static func pieceFeatureAngle(
        rotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool
    ) -> CGFloat {
        let canonical = canonicalPieceAngle(for: pieceType)
        let adjusted = isFlipped ? -canonical : canonical
        return TangramRotationValidator.normalizeAngle(rotation + adjusted)
    }
    
    /// Compute target feature angle from transform
    static func targetFeatureAngle(
        transform: CGAffineTransform,
        pieceType: TangramPieceType
    ) -> CGFloat {
        let raw = TangramPoseMapper.rawAngle(from: transform)
        let rotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: raw)
        let canonical = canonicalTargetAngle(for: pieceType)
        return TangramRotationValidator.normalizeAngle(rotation + canonical)
    }
    
    // MARK: - Centroid Calculations
    
    /// Compute centroid of a polygon defined by vertices
    static func centroid(of vertices: [CGPoint]) -> CGPoint {
        guard !vertices.isEmpty else { return .zero }
        let sx = vertices.reduce(0) { $0 + $1.x }
        let sy = vertices.reduce(0) { $0 + $1.y }
        return CGPoint(x: sx / CGFloat(vertices.count), y: sy / CGFloat(vertices.count))
    }
    
    /// Compute centroid of a target piece in SK space
    static func targetCentroid(for target: GamePuzzleData.TargetPiece) -> CGPoint {
        let vertices = TangramBounds.computeSKTransformedVertices(for: target)
        return centroid(of: vertices)
    }
    
    // MARK: - Transform Detection
    
    /// Check if a transform represents a flipped state
    static func isTransformFlipped(_ transform: CGAffineTransform) -> Bool {
        let determinant = transform.a * transform.d - transform.b * transform.c
        return determinant < 0
    }
    
    // MARK: - Distance Calculations
    
    /// Compute Euclidean distance between two points
    static func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }
    
    /// Compute vector from one point to another
    static func vector(from p1: CGPoint, to p2: CGPoint) -> CGVector {
        return CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
    }
    
    /// Compute length of a vector
    static func vectorLength(_ v: CGVector) -> CGFloat {
        return hypot(v.dx, v.dy)
    }
    
    /// Compute angle of a vector
    static func vectorAngle(_ v: CGVector) -> CGFloat {
        return atan2(v.dy, v.dx)
    }
    
    // MARK: - Rotation Matrix
    
    /// Create 2D rotation matrix
    static func rotationMatrix(angle: CGFloat) -> (cos: CGFloat, sin: CGFloat) {
        return (cos(angle), sin(angle))
    }
    
    /// Apply rotation to a point
    static func rotatePoint(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let (cosT, sinT) = rotationMatrix(angle: angle)
        return CGPoint(
            x: point.x * cosT - point.y * sinT,
            y: point.x * sinT + point.y * cosT
        )
    }
    
    /// Apply rotation to a vector
    static func rotateVector(_ vector: CGVector, by angle: CGFloat) -> CGVector {
        let (cosT, sinT) = rotationMatrix(angle: angle)
        return CGVector(
            dx: vector.dx * cosT - vector.dy * sinT,
            dy: vector.dx * sinT + vector.dy * cosT
        )
    }
}