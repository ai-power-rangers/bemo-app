//
//  PieceManipulationService.swift
//  Bemo
//
//  Service for managing piece manipulation based on connections
//

// WHAT: Calculates and validates manipulation modes for tangram pieces based on their connections
// ARCHITECTURE: Service layer in MVVM-S pattern, provides business logic for piece manipulation
// USAGE: Injected into ViewModel via DependencyContainer, determines how pieces can be moved

import Foundation
import CoreGraphics

@MainActor
class PieceManipulationService {
    
    // MARK: - Public Methods
    
    /// Calculate the manipulation mode for a piece based on its connections
    func calculateManipulationMode(piece: TangramPiece, connections: [Connection]) -> ManipulationMode {
        // Find connections involving this piece
        let pieceConnections = connections.filter { connection in
            connection.pieceAId == piece.id || connection.pieceBId == piece.id
        }
        
        // Multiple connections = locked
        if pieceConnections.count >= 2 {
            return .locked
        }
        
        // No connections = free manipulation (but we still lock the first piece)
        if pieceConnections.isEmpty {
            // First piece is always locked even without connections
            return .locked
        }
        
        // Single connection - determine type
        if let connection = pieceConnections.first {
            switch connection.type {
            case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
                // Get the pivot point (vertex in world space)
                let isPieceA = piece.id == pieceAId
                let vertexIndex = isPieceA ? vertexA : vertexB
                let worldVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
                
                guard vertexIndex < worldVertices.count else {
                    return .locked
                }
                
                let pivot = worldVertices[vertexIndex]
                // Snap at 45° intervals
                let snapAngles = [0, 45, 90, 135, 180, 225, 270, 315].map { Double($0) }
                
                return .rotatable(pivot: pivot, snapAngles: snapAngles)
                
            case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
                // Determine which piece is sliding and which is stationary
                let isPieceA = piece.id == pieceAId
                
                // For edge-to-edge, we need to get the other piece to determine the slide track
                // This is a simplified version - in production we'd need the other piece's data
                let edgeIndex = isPieceA ? edgeA : edgeB
                let worldVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
                let edges = TangramGeometry.edges(for: piece.type)
                
                guard edgeIndex < edges.count else {
                    return .locked
                }
                
                let edgeDef = edges[edgeIndex]
                let edgeStart = worldVertices[edgeDef.startVertex]
                let edgeEnd = worldVertices[edgeDef.endVertex]
                
                // Calculate edge vector
                let dx = edgeEnd.x - edgeStart.x
                let dy = edgeEnd.y - edgeStart.y
                let edgeLength = sqrt(dx * dx + dy * dy)
                let normalizedVector = CGVector(dx: dx / edgeLength, dy: dy / edgeLength)
                
                // Simplified slide range
                let slideRange = 0...Double(edgeLength)
                let snapPositions = [0.0, 0.5, 1.0]
                
                return .slidable(
                    edge: ManipulationMode.Edge(
                        start: edgeStart,
                        end: edgeEnd,
                        vector: normalizedVector
                    ),
                    range: slideRange,
                    snapPositions: snapPositions
                )
                
            case .vertexToEdge:
                // Vertex on edge - for now, lock it
                // Could potentially allow sliding along the edge
                return .locked
            }
        }
        
        return .locked
    }
    
    /// Check if a piece can be rotated
    func canRotate(piece: TangramPiece, connections: [Connection]) -> Bool {
        let mode = calculateManipulationMode(piece: piece, connections: connections)
        switch mode {
        case .rotatable:
            return true
        default:
            return false
        }
    }
    
    /// Check if a piece can be flipped
    func canFlip(piece: TangramPiece, connections: [Connection]) -> Bool {
        // Only parallelogram can flip, and only when rotatable
        guard piece.type == .parallelogram else { return false }
        return canRotate(piece: piece, connections: connections)
    }
    
    /// Check if a piece can slide
    func canSlide(piece: TangramPiece, connections: [Connection]) -> SlideConstraints? {
        let mode = calculateManipulationMode(piece: piece, connections: connections)
        switch mode {
        case .slidable(let edge, let range, let snapPositions):
            return SlideConstraints(edge: edge, range: range, snapPositions: snapPositions)
        default:
            return nil
        }
    }
    
    /// Get the rotation pivot point for a piece
    func getRotationPivot(piece: TangramPiece, connections: [Connection]) -> CGPoint? {
        let mode = calculateManipulationMode(piece: piece, connections: connections)
        switch mode {
        case .rotatable(let pivot, _):
            return pivot
        default:
            return nil
        }
    }
    
    /// Apply rotation to a piece
    func applyRotation(to piece: inout TangramPiece, angle: Double, pivot: CGPoint) {
        // Calculate rotation transform around pivot
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: pivot.x, y: pivot.y)
        transform = transform.rotated(by: angle)
        transform = transform.translatedBy(x: -pivot.x, y: -pivot.y)
        
        // Apply to piece's existing transform
        piece.transform = piece.transform.concatenating(transform)
    }
    
    /// Apply slide to a piece
    func applySlide(to piece: inout TangramPiece, distance: Double, along edge: ManipulationMode.Edge) {
        // Calculate translation along edge
        let translation = CGAffineTransform(
            translationX: edge.vector.dx * CGFloat(distance),
            y: edge.vector.dy * CGFloat(distance)
        )
        
        // Apply to piece's existing transform
        piece.transform = piece.transform.concatenating(translation)
    }
    
    /// Snap rotation to nearest angle
    func snapRotation(_ angle: Double, to snapAngles: [Double]) -> Double {
        let degrees = angle * 180 / .pi
        
        // Find nearest snap angle
        var nearestAngle = snapAngles[0]
        var minDifference = abs(degrees - nearestAngle)
        
        for snapAngle in snapAngles {
            let difference = abs(degrees - snapAngle)
            if difference < minDifference {
                minDifference = difference
                nearestAngle = snapAngle
            }
        }
        
        // Return in radians
        return nearestAngle * .pi / 180
    }
    
    /// Snap slide position to nearest snap point
    func snapSlide(_ distance: Double, to snapPositions: [Double], range: ClosedRange<Double>) -> Double {
        let normalizedDistance = (distance - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        // Find nearest snap position
        var nearestPosition = snapPositions[0]
        var minDifference = abs(normalizedDistance - nearestPosition)
        
        for snapPosition in snapPositions {
            let difference = abs(normalizedDistance - snapPosition)
            if difference < minDifference {
                minDifference = difference
                nearestPosition = snapPosition
            }
        }
        
        // Convert back to actual distance
        return range.lowerBound + nearestPosition * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Supporting Types

struct SlideConstraints {
    let edge: ManipulationMode.Edge
    let range: ClosedRange<Double>
    let snapPositions: [Double]
}