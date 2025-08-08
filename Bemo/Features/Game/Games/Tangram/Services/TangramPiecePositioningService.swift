//
//  TangramPiecePositioningService.swift
//  Bemo
//
//  Service for handling piece positioning and alignment logic
//

// WHAT: Business logic for piece positioning, snapping, and alignment
// ARCHITECTURE: Service in MVVM-S pattern, stateless positioning calculations
// USAGE: Used by scene and gameplay service for piece positioning operations

import Foundation
import CoreGraphics
import SpriteKit

/// Service handling piece positioning and alignment calculations
class TangramPiecePositioningService {
    
    // MARK: - Properties
    
    private let geometryUtilities: TangramGeometryUtilities.Type = TangramGeometryUtilities.self
    
    // MARK: - Snap Detection
    
    /// Determines if a piece should snap to target position
    func shouldSnapToTarget(piecePosition: CGPoint, targetPosition: CGPoint) -> Bool {
        let distance = geometryUtilities.calculateDistance(from: piecePosition, to: targetPosition)
        return distance <= Double(TangramGameConstants.Validation.positionTolerance)
    }
    
    /// Calculates snap strength for visual feedback
    func calculateSnapStrength(piecePosition: CGPoint, targetPosition: CGPoint) -> SnapStrength {
        let distance = geometryUtilities.calculateDistance(from: piecePosition, to: targetPosition)
        let tolerance = Double(TangramGameConstants.Validation.positionTolerance)
        
        if distance <= tolerance {
            return .strong
        } else if distance <= tolerance * 2.5 {
            return .medium
        } else if distance <= tolerance * 4.0 {
            return .weak
        } else {
            return .none
        }
    }
    
    enum SnapStrength {
        case none
        case weak
        case medium
        case strong
        
        var alpha: CGFloat {
            switch self {
            case .none: return 0.3
            case .weak: return 0.4
            case .medium: return 0.5
            case .strong: return 0.7
            }
        }
        
        var lineWidth: CGFloat {
            switch self {
            case .none: return 1.0
            case .weak: return 1.5
            case .medium: return 2.0
            case .strong: return 3.0
            }
        }
        
        var color: SKColor {
            switch self {
            case .none: return SKColor.darkGray
            case .weak, .medium, .strong: return SKColor.systemGreen
            }
        }
    }
    
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
    
    /// Finds the nearest valid rotation for a piece
    func nearestValidRotation(currentRotation: Double, validRotations: [Double]) -> Double {
        guard !validRotations.isEmpty else { return currentRotation }
        
        let normalized = geometryUtilities.normalizeAngle(currentRotation)
        
        var nearestRotation = validRotations[0]
        var minDifference = Double.greatestFiniteMagnitude
        
        for rotation in validRotations {
            let diff = abs(geometryUtilities.normalizeAngle(normalized - rotation))
            if diff < minDifference {
                minDifference = diff
                nearestRotation = rotation
            }
        }
        
        return nearestRotation
    }
    
    /// Aligns a position to grid if within threshold
    func alignToGrid(position: CGPoint, gridSize: CGFloat = 10) -> CGPoint {
        let x = round(position.x / gridSize) * gridSize
        let y = round(position.y / gridSize) * gridSize
        return CGPoint(x: x, y: y)
    }
    
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
    
    func snapToGrid(_ position: CGPoint, gridSize: CGFloat) -> CGPoint {
        // Use existing alignToGrid method
        return alignToGrid(position: position, gridSize: gridSize)
    }
}