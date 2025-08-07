//
//  TangramGameGeometry.swift
//  Bemo
//
//  Self-contained tangram geometry definitions for gameplay
//

// WHAT: Provides exact mathematical vertices for all 7 tangram pieces
// ARCHITECTURE: Model in MVVM-S, used for accurate piece rendering and validation
// USAGE: Get vertices for any piece type, apply transforms for world positioning

import Foundation
import CoreGraphics

enum TangramGameGeometry {
    
    /// Get vertices for a piece type in normalized space (0-2 coordinate system)
    /// Vertices are ordered counter-clockwise starting from origin
    static func normalizedVertices(for pieceType: TangramPieceType) -> [CGPoint] {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2:
            // Right triangle with legs of length 1
            return [
                CGPoint(x: 0, y: 0),     // Origin vertex
                CGPoint(x: 1, y: 0),     // Right vertex
                CGPoint(x: 0, y: 1)      // Top vertex
            ]
            
        case .mediumTriangle:
            // Right triangle with legs of length √2
            let sqrt2 = sqrt(2.0)
            return [
                CGPoint(x: 0, y: 0),         // Origin vertex
                CGPoint(x: sqrt2, y: 0),     // Right vertex
                CGPoint(x: 0, y: sqrt2)      // Top vertex
            ]
            
        case .largeTriangle1, .largeTriangle2:
            // Right triangle with legs of length 2
            return [
                CGPoint(x: 0, y: 0),     // Origin vertex
                CGPoint(x: 2, y: 0),     // Right vertex
                CGPoint(x: 0, y: 2)      // Top vertex
            ]
            
        case .square:
            // Square with side length 1
            return [
                CGPoint(x: 0, y: 0),     // Bottom-left
                CGPoint(x: 1, y: 0),     // Bottom-right
                CGPoint(x: 1, y: 1),     // Top-right
                CGPoint(x: 0, y: 1)      // Top-left
            ]
            
        case .parallelogram:
            // Parallelogram with specific tangram dimensions
            let sqrt2 = sqrt(2.0)
            let halfSqrt2 = sqrt2 / 2.0
            return [
                CGPoint(x: 0, y: 0),                    // Origin vertex
                CGPoint(x: sqrt2, y: 0),                // Right vertex
                CGPoint(x: halfSqrt2, y: halfSqrt2),    // Top-right vertex
                CGPoint(x: -halfSqrt2, y: halfSqrt2)    // Top-left vertex
            ]
        }
    }
    
    /// Get centroid (center point) of a piece in normalized space
    static func normalizedCentroid(for pieceType: TangramPieceType) -> CGPoint {
        let vertices = normalizedVertices(for: pieceType)
        let sumX = vertices.reduce(0) { $0 + $1.x }
        let sumY = vertices.reduce(0) { $0 + $1.y }
        return CGPoint(
            x: sumX / CGFloat(vertices.count),
            y: sumY / CGFloat(vertices.count)
        )
    }
    
    /// Get bounding box for a piece in normalized space
    static func normalizedBoundingBox(for pieceType: TangramPieceType) -> CGRect {
        let vertices = normalizedVertices(for: pieceType)
        guard !vertices.isEmpty else { return .zero }
        
        var minX = vertices[0].x
        var maxX = vertices[0].x
        var minY = vertices[0].y
        var maxY = vertices[0].y
        
        for vertex in vertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// Get area of a piece in normalized units
    static func normalizedArea(for pieceType: TangramPieceType) -> Double {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2:
            return 0.5  // (1 * 1) / 2
        case .mediumTriangle:
            return 1.0  // (√2 * √2) / 2
        case .largeTriangle1, .largeTriangle2:
            return 2.0  // (2 * 2) / 2
        case .square:
            return 1.0  // 1 * 1
        case .parallelogram:
            return 1.0  // Base * height
        }
    }
    
    /// Apply transform to vertices
    static func transformVertices(_ vertices: [CGPoint], with transform: CGAffineTransform) -> [CGPoint] {
        vertices.map { $0.applying(transform) }
    }
    
    /// Scale vertices by a factor
    static func scaleVertices(_ vertices: [CGPoint], by scale: CGFloat) -> [CGPoint] {
        vertices.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
    }
    
    /// Calculate the center of a set of vertices
    static func centerOfVertices(_ vertices: [CGPoint]) -> CGPoint {
        guard !vertices.isEmpty else { return .zero }
        let sumX = vertices.reduce(0) { $0 + $1.x }
        let sumY = vertices.reduce(0) { $0 + $1.y }
        return CGPoint(
            x: sumX / CGFloat(vertices.count),
            y: sumY / CGFloat(vertices.count)
        )
    }
}