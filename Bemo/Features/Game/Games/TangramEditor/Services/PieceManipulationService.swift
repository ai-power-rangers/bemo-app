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
    func calculateManipulationMode(piece: TangramPiece, connections: [Connection], allPieces: [TangramPiece], isFirstPiece: Bool = false) -> ManipulationMode {
        // Find connections involving this piece
        let pieceConnections = connections.filter { connection in
            connection.pieceAId == piece.id || connection.pieceBId == piece.id
        }
        
        // First piece is always fixed
        if isFirstPiece {
            return .fixed
        }
        
        // Multiple connections = fixed
        if pieceConnections.count >= 2 {
            return .fixed
        }
        
        // No connections = free movement
        if pieceConnections.isEmpty {
            return .free
        }
        
        // Single connection - determine type
        if let connection = pieceConnections.first {
            switch connection.type {
            case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
                // Get the pivot point from the OTHER piece (the stationary one)
                let isPieceA = piece.id == pieceAId
                
                // Find the other piece to get its vertex as the pivot
                let otherPieceId = isPieceA ? pieceBId : pieceAId
                let otherVertexIndex = isPieceA ? vertexB : vertexA
                
                guard let otherPiece = allPieces.first(where: { $0.id == otherPieceId }) else {
                    return .fixed
                }
                
                let otherWorldVertices = TangramCoordinateSystem.getWorldVertices(for: otherPiece)
                guard otherVertexIndex < otherWorldVertices.count else {
                    return .fixed
                }
                
                // Use the vertex from the OTHER piece as the pivot point
                let pivot = otherWorldVertices[otherVertexIndex]
                // Snap at exact 45° intervals for clean rotations
                let snapAngles: [Double] = [-180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0]
                
                return .rotatable(pivot: pivot, snapAngles: snapAngles)
                
            case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
                // Determine which piece is sliding and which is stationary
                let isPieceA = piece.id == pieceAId
                
                // Get BOTH pieces to determine proper sliding
                guard let pieceA = allPieces.first(where: { $0.id == pieceAId }),
                      let pieceB = allPieces.first(where: { $0.id == pieceBId }) else {
                    return .fixed
                }
                
                // Get edges for both pieces
                let edgesA = TangramGeometry.edges(for: pieceA.type)
                let edgesB = TangramGeometry.edges(for: pieceB.type)
                
                guard edgeA < edgesA.count, edgeB < edgesB.count else {
                    return .fixed
                }
                
                // Get world vertices for both pieces
                let worldVerticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
                let worldVerticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
                
                // Calculate both edge lengths
                let edgeDefA = edgesA[edgeA]
                let edgeStartA = worldVerticesA[edgeDefA.startVertex]
                let edgeEndA = worldVerticesA[edgeDefA.endVertex]
                let edgeLengthA = sqrt(pow(edgeEndA.x - edgeStartA.x, 2) + pow(edgeEndA.y - edgeStartA.y, 2))
                
                let edgeDefB = edgesB[edgeB]
                let edgeStartB = worldVerticesB[edgeDefB.startVertex]
                let edgeEndB = worldVerticesB[edgeDefB.endVertex]
                let edgeLengthB = sqrt(pow(edgeEndB.x - edgeStartB.x, 2) + pow(edgeEndB.y - edgeStartB.y, 2))
                
                // Determine which edge is longer (the track) and which piece slides
                // The LONGER edge is the track, the piece with SHORTER edge slides
                let isATrack = edgeLengthA >= edgeLengthB
                
                // Get the track edge (from the stationary piece)
                let (trackStart, trackEnd, trackLength, slidingLength) = isATrack ?
                    (edgeStartA, edgeEndA, edgeLengthA, edgeLengthB) :
                    (edgeStartB, edgeEndB, edgeLengthB, edgeLengthA)
                
                // Check if this piece is the sliding piece
                let isSlidingPiece = (isATrack && piece.id == pieceBId) || (!isATrack && piece.id == pieceAId)
                
                if !isSlidingPiece {
                    // This piece is the track/stationary piece - it's fixed
                    return .fixed
                }
                
                // Calculate edge vector for the track
                let dx = trackEnd.x - trackStart.x
                let dy = trackEnd.y - trackStart.y
                let normalizedVector = CGVector(dx: dx / trackLength, dy: dy / trackLength)
                
                // Sliding range is track length minus sliding piece edge length
                // This ensures the sliding piece's edge stays fully on the track
                let maxSlide = Double(max(0, trackLength - slidingLength))
                let slideRange = 0...maxSlide
                
                // Snap positions at exact 0%, 25%, 50%, 75%, 100% of the slide range
                let snapPositions: [Double] = maxSlide > 0 ? 
                    [0.0, maxSlide * 0.25, maxSlide * 0.5, maxSlide * 0.75, maxSlide].filter { $0 >= 0 && $0 <= maxSlide } : [0.0]
                
                return .slidable(
                    edge: ManipulationMode.Edge(
                        start: trackStart,
                        end: trackEnd,
                        vector: normalizedVector
                    ),
                    range: slideRange,
                    snapPositions: snapPositions
                )
                
            case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
                // IMPORTANT: For vertex-to-edge, the vertex piece can both:
                // 1. Slide along the edge
                // 2. Rotate while keeping the vertex on the edge
                
                // Determine if this piece is the vertex piece or edge piece
                let isPieceWithVertex = piece.id == pieceAId
                
                if !isPieceWithVertex {
                    // This is the edge piece, it should be fixed
                    return .fixed
                }
                
                // Get the edge piece (piece B)
                guard let edgePiece = allPieces.first(where: { $0.id == pieceBId }) else {
                    return .fixed
                }
                
                let worldVerticesB = TangramCoordinateSystem.getWorldVertices(for: edgePiece)
                let edgesB = TangramGeometry.edges(for: edgePiece.type)
                
                guard edge < edgesB.count else {
                    return .fixed
                }
                
                let edgeDef = edgesB[edge]
                let edgeStart = worldVerticesB[edgeDef.startVertex]
                let edgeEnd = worldVerticesB[edgeDef.endVertex]
                
                // Get current vertex position on the edge for rotation pivot
                let worldVerticesA = TangramCoordinateSystem.getWorldVertices(for: piece)
                guard vertex < worldVerticesA.count else {
                    return .fixed
                }
                let currentVertexPos = worldVerticesA[vertex]
                
                // For vertex-to-edge: Allow rotation with the vertex as pivot
                // The vertex must stay on the edge during rotation
                let snapAngles: [Double] = [-180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0]
                
                // Use the current vertex position as the rotation pivot
                // This vertex is constrained to stay on the edge
                return .rotatable(pivot: currentVertexPos, snapAngles: snapAngles)
            }
        }
        
        return .fixed
    }
    
    /// Check if a piece can be rotated
    func canRotate(piece: TangramPiece, connections: [Connection], allPieces: [TangramPiece]) -> Bool {
        let mode = calculateManipulationMode(piece: piece, connections: connections, allPieces: allPieces)
        switch mode {
        case .rotatable:
            return true
        default:
            return false
        }
    }
    
    /// Check if a piece can be flipped
    func canFlip(piece: TangramPiece, connections: [Connection], allPieces: [TangramPiece]) -> Bool {
        // Only parallelogram can flip, and only when rotatable
        guard piece.type == .parallelogram else { return false }
        return canRotate(piece: piece, connections: connections, allPieces: allPieces)
    }
    
    /// Check if a piece can slide
    func canSlide(piece: TangramPiece, connections: [Connection], allPieces: [TangramPiece]) -> SlideConstraints? {
        let mode = calculateManipulationMode(piece: piece, connections: connections, allPieces: allPieces)
        switch mode {
        case .slidable(let edge, let range, let snapPositions):
            return SlideConstraints(edge: edge, range: range, snapPositions: snapPositions)
        default:
            return nil
        }
    }
    
    /// Get the rotation pivot point for a piece
    func getRotationPivot(piece: TangramPiece, connections: [Connection], allPieces: [TangramPiece]) -> CGPoint? {
        let mode = calculateManipulationMode(piece: piece, connections: connections, allPieces: allPieces)
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
    
    /// Calculate valid sliding range considering obstacles
    func calculateSlideLimits(
        piece: TangramPiece,
        edge: ManipulationMode.Edge,
        baseRange: ClosedRange<Double>,
        otherPieces: [TangramPiece],
        stepSize: Double = 2.0
    ) -> ClosedRange<Double> {
        // No longer need validation service - using PieceTransformEngine
        var minValidDistance = baseRange.lowerBound
        var maxValidDistance = baseRange.upperBound
        
        // Get current position along edge (assumed to be 0 for initial placement)
        let currentPosition: Double = 0
        
        // Check forward (positive) direction from current position
        for distance in stride(from: currentPosition, through: baseRange.upperBound, by: stepSize) {
            let translation = CGAffineTransform(
                translationX: edge.vector.dx * CGFloat(distance),
                y: edge.vector.dy * CGFloat(distance)
            )
            
            let newTransform = piece.transform.concatenating(translation)
            let testPiece = TangramPiece(type: piece.type, transform: newTransform)
            
            var hasOverlap = false
            for other in otherPieces {
                if PieceTransformEngine.hasAreaOverlap(testPiece, other) {
                    hasOverlap = true
                    break
                }
            }
            
            if hasOverlap {
                maxValidDistance = max(currentPosition, distance - stepSize)
                break
            }
        }
        
        // Check backward (negative) direction from current position
        for distance in stride(from: currentPosition, through: baseRange.lowerBound, by: -stepSize) {
            let translation = CGAffineTransform(
                translationX: edge.vector.dx * CGFloat(distance),
                y: edge.vector.dy * CGFloat(distance)
            )
            
            let newTransform = piece.transform.concatenating(translation)
            let testPiece = TangramPiece(type: piece.type, transform: newTransform)
            
            var hasOverlap = false
            for other in otherPieces {
                if PieceTransformEngine.hasAreaOverlap(testPiece, other) {
                    hasOverlap = true
                    break
                }
            }
            
            if hasOverlap {
                minValidDistance = min(currentPosition, distance + stepSize)
                break
            }
        }
        
        return minValidDistance...maxValidDistance
    }
    
    /// Calculate the valid rotation range for a piece to prevent overlaps
    func calculateRotationLimits(
        piece: TangramPiece,
        pivot: CGPoint,
        otherPieces: [TangramPiece],
        stepDegrees: Double = 45.0  // Use 45° steps for tangram
    ) -> (minAngle: Double, maxAngle: Double) {
        // For vertex-to-vertex connections, test each 45° position
        // and return the full range if any positions are valid
        // The actual validation happens in handleRotation using PieceTransformEngine
        
        // For now, return full range to allow testing all positions
        // The centralized validation in PieceTransformEngine will handle
        // checking each position for validity
        return (-180, 180)
    }
}

// MARK: - Supporting Types

struct SlideConstraints {
    let edge: ManipulationMode.Edge
    let range: ClosedRange<Double>
    let snapPositions: [Double]
}