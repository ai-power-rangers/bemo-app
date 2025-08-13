//
//  TangramPiecePositioningService.swift
//  Bemo
//
//  Service for handling piece positioning and alignment logic
//

// WHAT: Business logic for piece positioning and layout (snapping removed)
// ARCHITECTURE: Service in MVVM-S pattern, stateless positioning calculations
// USAGE: Used by scene and gameplay service for piece positioning operations

import Foundation
import CoreGraphics
import SpriteKit

/// Service handling piece positioning and alignment calculations
class TangramPiecePositioningService {
    
    // MARK: - Properties
    
    private let geometryUtilities: TangramGeometryUtilities.Type = TangramGeometryUtilities.self
    
    // MARK: - Snap Detection (removed)
    // All snap-related logic removed for realism
    
    // MARK: - Piece Layout
    
    /// Calculates initial layout positions for available pieces
    func calculatePieceLayout(pieceCount: Int, containerSize: CGSize, yPosition: CGFloat) -> [Int: CGPoint] {
        var positions: [Int: CGPoint] = [:]
        
        let spacing = containerSize.width / CGFloat(pieceCount + 1)
        
        for index in 0..<pieceCount {
            let x = spacing * CGFloat(index + 1)
            positions[index] = CGPoint(x: x, y: yPosition)
        }
        
        return positions
    }
    
    /// Arranges pieces in a grid layout
    func arrangeInGrid(pieceCount: Int, containerSize: CGSize, padding: CGFloat = 20) -> [Int: CGPoint] {
        var positions: [Int: CGPoint] = [:]
        
        // Calculate optimal grid dimensions
        let columns = Int(ceil(sqrt(Double(pieceCount))))
        let rows = Int(ceil(Double(pieceCount) / Double(columns)))
        
        let cellWidth = (containerSize.width - padding * 2) / CGFloat(columns)
        let cellHeight = (containerSize.height - padding * 2) / CGFloat(rows)
        
        for index in 0..<pieceCount {
            let row = index / columns
            let col = index % columns
            
            let x = padding + cellWidth * (CGFloat(col) + 0.5)
            let y = padding + cellHeight * (CGFloat(row) + 0.5)
            
            positions[index] = CGPoint(x: x, y: y)
        }
        
        return positions
    }
    
    // MARK: - Alignment Helpers
    
    // Removed nearestValidRotation: no auto-rotation alignment
    
    // Removed alignToGrid / snapToGrid: no grid alignment
    
    // MARK: - Bounds Calculations
    
    /// Calculates the bounds of all target pieces
    func calculatePuzzleBounds(targetPieces: [GamePuzzleData.TargetPiece]) -> CGRect {
        var allPoints: [CGPoint] = []
        
        for piece in targetPieces {
            // Get piece vertices
            let vertices = getPieceVertices(for: piece.pieceType)
            
            // Transform vertices
            for vertex in vertices {
                let transformed = vertex.applying(piece.transform)
                allPoints.append(transformed)
            }
        }
        
        return geometryUtilities.calculateBounds(for: allPoints)
    }
    
    /// Gets the base vertices for a piece type
    private func getPieceVertices(for pieceType: TangramPieceType) -> [CGPoint] {
        // Use the geometry data from TangramGameGeometry
        return TangramGameGeometry.normalizedVertices(for: pieceType)
    }
    
    // MARK: - Transform Helpers
    
    /// Creates a transform for piece placement
    func createPieceTransform(position: CGPoint, rotation: Double, scale: CGFloat = 1.0) -> CGAffineTransform {
        return geometryUtilities.createTransform(position: position, rotation: rotation, scale: scale)
    }
    
    /// Decomposes a transform for piece state
    func decomposePieceTransform(_ transform: CGAffineTransform) -> PieceTransformState {
        let components = geometryUtilities.decomposeTransform(transform)
        return PieceTransformState(
            position: components.position,
            rotation: components.rotation,
            scale: components.scale.width // Assume uniform scale
        )
    }
    
    struct PieceTransformState {
        let position: CGPoint
        let rotation: Double
        let scale: CGFloat
    }
    
    // MARK: - Relative Positioning
    
    /// Calculates relative position between two pieces
    func calculateRelativePosition(from piece1: CGPoint, to piece2: CGPoint) -> CGVector {
        return CGVector(dx: piece2.x - piece1.x, dy: piece2.y - piece1.y)
    }
    
    /// Applies relative position to a piece
    func applyRelativePosition(basePosition: CGPoint, offset: CGVector) -> CGPoint {
        return CGPoint(x: basePosition.x + offset.dx, y: basePosition.y + offset.dy)
    }
}

// MARK: - Protocol Conformance

extension TangramPiecePositioningService {
    func calculateLayout(for pieces: [TangramPieceType], in bounds: CGRect) -> [TangramPieceType: CGPoint] {
        var result: [TangramPieceType: CGPoint] = [:]
        
        // Use existing grid arrangement logic
        let positions = arrangeInGrid(
            pieceCount: pieces.count,
            containerSize: CGSize(width: bounds.width, height: bounds.height),
            padding: 20
        )
        
        for (index, piece) in pieces.enumerated() {
            if let position = positions[index] {
                // Adjust position relative to bounds origin
                let adjustedPosition = CGPoint(
                    x: bounds.origin.x + position.x,
                    y: bounds.origin.y + position.y
                )
                result[piece] = adjustedPosition
            }
        }
        
        return result
    }
    
    // snapToGrid removed
}