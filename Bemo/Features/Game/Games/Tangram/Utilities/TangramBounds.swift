//
//  TangramBounds.swift
//  Bemo
//
//  Utility for computing puzzle bounds in SpriteKit coordinate space
//

// WHAT: Computes accurate bounds for puzzle pieces in SpriteKit space for proper centering
// ARCHITECTURE: Utility that works with TangramPoseMapper to ensure consistent coordinate conversion
// USAGE: Call static methods to get SK-space bounds for centering puzzle layers

import CoreGraphics
import Foundation

/// Utility for calculating puzzle bounds in SpriteKit coordinate space
/// Ensures consistent space usage when centering puzzle layers
struct TangramBounds {
    
    // MARK: - SK Space Vertex Computation
    
    /// Computes all vertices of a target piece transformed into SpriteKit space
    /// - Parameter target: The target piece with its transform
    /// - Returns: Array of vertices in SK coordinate space (Y-up)
    static func computeSKTransformedVertices(for target: GamePuzzleData.TargetPiece) -> [CGPoint] {
        // Step 1: Get normalized vertices for the piece type
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
        
        // Step 2: Scale vertices to visual size
        let scaledVertices = TangramGameGeometry.scaleVertices(
            normalizedVertices,
            by: TangramGameConstants.visualScale
        )
        
        // Step 3: Apply the target's raw transform to get world positions (RAW space)
        let transformedVerticesRaw = TangramGameGeometry.transformVertices(
            scaledVertices,
            with: target.transform
        )
        
        // Step 4: Map each RAW vertex to SK space using PoseMapper
        // This inverts Y to match SpriteKit's Y-up convention
        let skVertices = transformedVerticesRaw.map { rawVertex in
            TangramPoseMapper.spriteKitPosition(fromRawPosition: rawVertex)
        }
        
        return skVertices
    }
    
    // MARK: - Bounds Calculation
    
    /// Calculates the bounding rectangle of all target pieces in SpriteKit space
    /// - Parameter targets: Array of target pieces with their transforms
    /// - Returns: Bounding rectangle in SK coordinate space
    static func calculatePuzzleBoundsSK(targets: [GamePuzzleData.TargetPiece]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        // Process each target piece
        for target in targets {
            // Get all vertices in SK space
            let skVertices = computeSKTransformedVertices(for: target)
            
            // Accumulate min/max bounds
            for vertex in skVertices {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        // Return bounds rectangle in SK space
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    // MARK: - Centering Helpers
    
    /// Calculates the position offset needed to center puzzle bounds at a desired location
    /// - Parameters:
    ///   - boundsSK: Current bounds in SK space
    ///   - desiredCenter: Where we want the center to be
    /// - Returns: Offset to apply to puzzle layer position
    static func centeringOffset(
        boundsSK: CGRect,
        desiredCenter: CGPoint
    ) -> CGPoint {
        // Current center of the bounds
        let currentCenter = CGPoint(
            x: boundsSK.midX,
            y: boundsSK.midY
        )
        
        // Offset needed to move current center to desired center
        return CGPoint(
            x: desiredCenter.x - currentCenter.x,
            y: desiredCenter.y - currentCenter.y
        )
    }
    
    // MARK: - Debug Helpers
    
    /// Returns a debug string showing bounds information
    /// - Parameter boundsSK: Bounds in SK space
    /// - Returns: Formatted debug string
    static func debugString(for boundsSK: CGRect) -> String {
        return """
        SK Bounds Debug:
          Origin: (\(String(format: "%.1f", boundsSK.origin.x)), \(String(format: "%.1f", boundsSK.origin.y)))
          Size: \(String(format: "%.1f", boundsSK.width)) x \(String(format: "%.1f", boundsSK.height))
          Center: (\(String(format: "%.1f", boundsSK.midX)), \(String(format: "%.1f", boundsSK.midY)))
        """
    }
}

// MARK: - Documentation

/*
 This utility ensures that puzzle bounds are computed in the same coordinate space
 as the rendered pieces (SpriteKit Y-up). This prevents the coordinate space mismatch
 that was causing the puzzle to appear offset or "scattered".
 
 The flow is:
 1. Get piece vertices in normalized space
 2. Scale to visual size
 3. Apply raw transform (DB/CV convention)
 4. Convert to SK space via PoseMapper
 5. Compute bounds from SK vertices
 6. Use SK bounds to center the puzzle layer
 
 This maintains consistency with how individual pieces are rendered while ensuring
 the parent layer is positioned correctly.
 */