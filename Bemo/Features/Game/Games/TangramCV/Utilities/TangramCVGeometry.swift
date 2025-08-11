//
//  TangramCVGeometry.swift
//  Bemo
//
//  Geometry calculations for TangramCV pieces
//

// WHAT: Provides normalized vertices and transformation utilities for tangram pieces
// ARCHITECTURE: Utility layer for geometric calculations
// USAGE: Use static methods to get piece vertices and apply transformations

import CoreGraphics

enum TangramCVGeometry {
    
    // MARK: - Normalized Vertices (0-2 coordinate system)
    
    /// Returns normalized vertices for a piece type (0-2 coordinate system)
    static func normalizedVertices(for pieceType: TangramPieceType) -> [CGPoint] {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2:
            // Right triangle with legs of length 1
            return [
                CGPoint(x: 0, y: 0),    // Right angle vertex
                CGPoint(x: 1, y: 0),    // Horizontal leg end
                CGPoint(x: 0, y: 1)     // Vertical leg end
            ]
            
        case .mediumTriangle:
            // Right triangle with legs of length √2
            let sqrt2 = CGFloat(sqrt(2.0))
            return [
                CGPoint(x: 0, y: 0),         // Right angle vertex
                CGPoint(x: sqrt2, y: 0),     // Horizontal leg end
                CGPoint(x: 0, y: sqrt2)      // Vertical leg end
            ]
            
        case .largeTriangle1, .largeTriangle2:
            // Right triangle with legs of length 2
            return [
                CGPoint(x: 0, y: 0),    // Right angle vertex
                CGPoint(x: 2, y: 0),    // Horizontal leg end
                CGPoint(x: 0, y: 2)     // Vertical leg end
            ]
            
        case .square:
            // 1×1 square
            return [
                CGPoint(x: 0, y: 0),    // Bottom-left
                CGPoint(x: 1, y: 0),    // Bottom-right
                CGPoint(x: 1, y: 1),    // Top-right
                CGPoint(x: 0, y: 1)     // Top-left
            ]
            
        case .parallelogram:
            // Parallelogram with specific tangram dimensions (matching original)
            let sqrt2 = CGFloat(sqrt(2.0))
            let halfSqrt2 = sqrt2 / 2.0
            return [
                CGPoint(x: 0, y: 0),                    // Origin vertex
                CGPoint(x: sqrt2, y: 0),                // Right vertex
                CGPoint(x: halfSqrt2, y: halfSqrt2),    // Top-right vertex
                CGPoint(x: -halfSqrt2, y: halfSqrt2)    // Top-left vertex (negative x!)
            ]
        }
    }
    
    // MARK: - Vertex Transformations
    
    /// Scale vertices by a factor
    static func scaleVertices(_ vertices: [CGPoint], by scale: CGFloat) -> [CGPoint] {
        return vertices.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
    }
    
    /// Apply CGAffineTransform to vertices
    static func transformVertices(_ vertices: [CGPoint], with transform: CGAffineTransform) -> [CGPoint] {
        return vertices.map { $0.applying(transform) }
    }
    
    /// Calculate centroid of vertices
    static func centroid(of vertices: [CGPoint]) -> CGPoint {
        guard !vertices.isEmpty else { return .zero }
        
        let sumX = vertices.reduce(0) { $0 + $1.x }
        let sumY = vertices.reduce(0) { $0 + $1.y }
        
        return CGPoint(
            x: sumX / CGFloat(vertices.count),
            y: sumY / CGFloat(vertices.count)
        )
    }
    
    /// Center vertices around origin by subtracting centroid
    static func centerVertices(_ vertices: [CGPoint]) -> [CGPoint] {
        let center = centroid(of: vertices)
        return vertices.map { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }
    }
    
    /// Calculate bounding box of vertices
    static func boundingBox(of vertices: [CGPoint]) -> CGRect {
        guard !vertices.isEmpty else { return .zero }
        
        let xs = vertices.map { $0.x }
        let ys = vertices.map { $0.y }
        
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - Transform Extraction
    
    /// Extract rotation angle from CGAffineTransform (in radians)
    static func extractRotation(from transform: CGAffineTransform) -> CGFloat {
        return atan2(transform.b, transform.a)
    }
    
    /// Extract rotation angle for SpriteKit scene space (negated to account for Y-flip)
    /// This converts from the stored transform's rotation to the scene's coordinate space
    static func sceneRotation(from transform: CGAffineTransform) -> CGFloat {
        return -extractRotation(from: transform)
    }
    
    /// Check if transform represents a flip (negative determinant)
    static func isTransformFlipped(_ transform: CGAffineTransform) -> Bool {
        let determinant = transform.a * transform.d - transform.b * transform.c
        return determinant < 0
    }
    
    // MARK: - Piece Area Calculation
    
    /// Get the normalized area of a piece type (square = 1.0)
    static func getPieceArea(for type: TangramPieceType) -> Double {
        switch type {
        case .smallTriangle1, .smallTriangle2:
            return 0.5  // Half of square
        case .mediumTriangle, .parallelogram, .square:
            return 1.0  // Same as square
        case .largeTriangle1, .largeTriangle2:
            return 2.0  // Double the square
        }
    }
    
    // MARK: - Angle Utilities
    
    /// Normalize angle to (-π, π] range
    static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var result = angle
        while result > .pi { result -= 2 * .pi }
        while result <= -.pi { result += 2 * .pi }
        return result
    }
    
    /// Convert degrees to radians
    static func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
        return degrees * .pi / 180.0
    }
    
    /// Convert radians to degrees
    static func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        return radians * 180.0 / .pi
    }
}