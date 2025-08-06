//
//  ConstraintManager.swift
//  Bemo
//
//  Manages constraint-aware transformations for tangram pieces
//

import Foundation
import CoreGraphics

class ConstraintManager {
    
    // MARK: - Constraint Application
    
    /// Apply a single constraint to a transform
    func applyConstraint(_ constraint: Constraint, to transform: CGAffineTransform, parameter: Double) -> CGAffineTransform {
        switch constraint.type {
        case .rotation(let center, let range):
            let clampedAngle = max(range.lowerBound, min(range.upperBound, parameter))
            let rotation = CGAffineTransform(rotationAngle: CGFloat(clampedAngle))
            
            let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
            let fromOrigin = CGAffineTransform(translationX: center.x, y: center.y)
            
            return transform
                .concatenating(toOrigin)
                .concatenating(rotation)
                .concatenating(fromOrigin)
            
        case .translation(let vector, let range):
            let clampedT = max(range.lowerBound, min(range.upperBound, parameter))
            let translation = CGAffineTransform(
                translationX: vector.dx * CGFloat(clampedT),
                y: vector.dy * CGFloat(clampedT)
            )
            return transform.concatenating(translation)
            
        case .fixed:
            return transform
        }
    }
    
    /// Apply rotation constraint around a vertex
    func applyRotationConstraint(
        transform: CGAffineTransform,
        around vertex: CGPoint,
        range: ClosedRange<Double>
    ) -> CGAffineTransform {
        
        // Calculate current rotation
        let currentAngle = atan2(transform.b, transform.a)
        
        // Clamp to range
        let clampedAngle = min(max(currentAngle, range.lowerBound), range.upperBound)
        
        // Create rotation transform around vertex
        var result = CGAffineTransform.identity
        result = result.translatedBy(x: vertex.x, y: vertex.y)
        result = result.rotated(by: clampedAngle)
        result = result.translatedBy(x: -vertex.x, y: -vertex.y)
        
        // Preserve translation
        result.tx = transform.tx
        result.ty = transform.ty
        
        return result
    }
    
    /// Apply translation constraint along an edge
    func applyTranslationConstraint(
        transform: CGAffineTransform,
        along vector: CGVector,
        range: ClosedRange<Double>
    ) -> CGAffineTransform {
        
        // Get current position
        let currentPos = CGPoint(x: transform.tx, y: transform.ty)
        
        // Normalize the constraint vector
        let normalizedVector = normalizeVector(vector)
        
        // Calculate signed distance along the vector using dot product
        let signedDistance = Double(currentPos.x * normalizedVector.dx + currentPos.y * normalizedVector.dy)
        
        // Clamp the signed distance to the allowed range
        let clampedDistance = min(max(signedDistance, range.lowerBound), range.upperBound)
        
        // Calculate new position along the constraint vector
        let newPos = CGPoint(
            x: normalizedVector.dx * clampedDistance,
            y: normalizedVector.dy * clampedDistance
        )
        
        var result = transform
        result.tx = newPos.x
        result.ty = newPos.y
        
        return result
    }
    
    /// Check if transform satisfies all constraints
    func validateTransform(
        _ transform: CGAffineTransform,
        against constraints: [Constraint]
    ) -> Bool {
        for constraint in constraints {
            switch constraint.type {
            case .rotation(let vertex, let range):
                let angle = calculateRotationAroundVertex(transform, vertex)
                if !range.contains(angle) { return false }
                
            case .translation(let vector, let range):
                let distance = calculateTranslationAlongVector(transform, vector)
                if !range.contains(distance) { return false }
                
            case .fixed:
                // Fixed constraint means no movement allowed from base position
                // This is simplified - in practice would need reference transform
                break
            }
        }
        return true
    }
    
    /// Apply multiple constraints to a transform
    func applyConstraints(
        _ transform: CGAffineTransform,
        constraints: [Constraint]
    ) -> CGAffineTransform {
        var result = transform
        
        for constraint in constraints {
            switch constraint.type {
            case .rotation(let vertex, let range):
                result = applyRotationConstraint(transform: result, around: vertex, range: range)
                
            case .translation(let vector, let range):
                result = applyTranslationConstraint(transform: result, along: vector, range: range)
                
            case .fixed:
                // Fixed means no change
                break
            }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    /// Project point onto vector
    private func projectPointOntoVector(_ point: CGPoint, _ vector: CGVector) -> CGPoint {
        let dotProduct = point.x * vector.dx + point.y * vector.dy
        let vectorLengthSquared = vector.dx * vector.dx + vector.dy * vector.dy
        
        guard vectorLengthSquared > 0 else { return .zero }
        
        let scalar = dotProduct / vectorLengthSquared
        return CGPoint(x: scalar * vector.dx, y: scalar * vector.dy)
    }
    
    /// Normalize vector to unit length
    private func normalizeVector(_ vector: CGVector) -> CGVector {
        let length = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard length > 0 else { return .zero }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
    
    /// Calculate rotation angle around vertex
    private func calculateRotationAroundVertex(_ transform: CGAffineTransform, _ vertex: CGPoint) -> Double {
        // Simplified - assumes rotation is primary transform component
        return atan2(transform.b, transform.a)
    }
    
    /// Calculate translation distance along vector
    private func calculateTranslationAlongVector(_ transform: CGAffineTransform, _ vector: CGVector) -> Double {
        let position = CGPoint(x: transform.tx, y: transform.ty)
        let projection = projectPointOntoVector(position, vector)
        return sqrt(projection.x * projection.x + projection.y * projection.y)
    }
    
    // MARK: - Rotation Helpers
    
    /// Create rotation transform around a specific point
    func rotateAroundPoint(_ transform: CGAffineTransform, angle: Double, point: CGPoint) -> CGAffineTransform {
        // Get the current position of the origin in world space
        let currentOrigin = CGPoint(x: transform.tx, y: transform.ty)
        
        // Calculate vector from rotation point to current origin
        let dx = currentOrigin.x - point.x
        let dy = currentOrigin.y - point.y
        
        // Rotate this vector by the angle
        let cos = cos(angle)
        let sin = sin(angle)
        let rotatedX = dx * cos - dy * sin
        let rotatedY = dx * sin + dy * cos
        
        // New position is rotation point plus rotated vector
        let newX = point.x + rotatedX
        let newY = point.y + rotatedY
        
        // Create new transform with rotation and new position
        var result = CGAffineTransform(rotationAngle: angle)
        result.tx = newX
        result.ty = newY
        
        return result
    }
    
    // MARK: - Translation Helpers
    
    /// Calculate edge vector from two points
    func edgeVector(from start: CGPoint, to end: CGPoint) -> CGVector {
        return CGVector(dx: end.x - start.x, dy: end.y - start.y)
    }
    
    /// Check if two edges are parallel (within tolerance)
    func areEdgesParallel(_ edge1: CGVector, _ edge2: CGVector, tolerance: Double = 0.01) -> Bool {
        let normalized1 = normalizeVector(edge1)
        let normalized2 = normalizeVector(edge2)
        
        // Check if parallel or anti-parallel
        let dotProduct = abs(normalized1.dx * normalized2.dx + normalized1.dy * normalized2.dy)
        return abs(dotProduct - 1.0) < tolerance
    }
    
    /// Calculate sliding range for edge-to-edge connection
    func calculateSlidingRange(edge1Length: Double, edge2Length: Double) -> ClosedRange<Double> {
        let difference = abs(edge1Length - edge2Length)
        if difference < 0.01 {
            // Same length - no sliding
            return 0...0
        } else {
            // Different lengths - can slide
            return 0...difference
        }
    }
}