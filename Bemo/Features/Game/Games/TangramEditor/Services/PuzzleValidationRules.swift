//
//  PuzzleValidationRules.swift
//  Bemo
//
//  Centralized validation rules for tangram puzzle validity
//

// WHAT: Single source of truth for tangram puzzle validation rules
// ARCHITECTURE: Service in MVVM-S pattern, provides consistent validation logic
// USAGE: Used by all components to validate piece placement, rotation, and sliding

import Foundation
import CoreGraphics

/// Centralized validation rules for tangram puzzles
enum PuzzleValidationRules {
    
    // MARK: - Core Rules
    
    /// Minimum distance for pieces to be considered "touching"
    static let touchTolerance: CGFloat = 2.0
    
    /// Maximum distance for vertices to be considered "connected"
    static let vertexConnectionTolerance: CGFloat = 1.0
    
    /// Minimum overlap area to be considered invalid (prevents floating point errors)
    static let minimumOverlapArea: CGFloat = 0.1
    
    // MARK: - Validation Methods
    
    /// Check if a piece placement is valid (no overlaps, maintains connections)
    static func isValidPlacement(
        piece: TangramPiece,
        withTransform transform: CGAffineTransform,
        amongPieces otherPieces: [TangramPiece],
        maintainingConnection connection: Connection? = nil
    ) -> Bool {
        // Create test piece with new transform
        let testPiece = TangramPiece(type: piece.type, transform: transform)
        
        // Check 1: No area overlap with other pieces
        let validationService = ValidationService()
        for other in otherPieces where other.id != piece.id {
            if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                return false
            }
        }
        
        // Check 2: If there's a connection, verify it's maintained
        if let connection = connection {
            if !isConnectionMaintained(connection: connection, 
                                      piece: testPiece, 
                                      amongPieces: otherPieces) {
                return false
            }
        }
        
        return true
    }
    
    /// Check if a vertex-to-vertex connection is maintained
    static func isVertexToVertexConnectionValid(
        pieceA: TangramPiece,
        vertexA: Int,
        pieceB: TangramPiece,
        vertexB: Int
    ) -> Bool {
        let verticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
        let verticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
        
        guard vertexA < verticesA.count, vertexB < verticesB.count else {
            return false
        }
        
        let pointA = verticesA[vertexA]
        let pointB = verticesB[vertexB]
        
        let distance = sqrt(pow(pointA.x - pointB.x, 2) + pow(pointA.y - pointB.y, 2))
        return distance <= vertexConnectionTolerance
    }
    
    /// Check if an edge-to-edge connection is maintained
    static func isEdgeToEdgeConnectionValid(
        pieceA: TangramPiece,
        edgeA: Int,
        pieceB: TangramPiece,
        edgeB: Int
    ) -> Bool {
        let verticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
        let verticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
        
        let edgesA = TangramGeometry.edges(for: pieceA.type)
        let edgesB = TangramGeometry.edges(for: pieceB.type)
        
        guard edgeA < edgesA.count, edgeB < edgesB.count else {
            return false
        }
        
        let edgeDefA = edgesA[edgeA]
        let edgeDefB = edgesB[edgeB]
        
        let edgeStartA = verticesA[edgeDefA.startVertex]
        let edgeEndA = verticesA[edgeDefA.endVertex]
        let edgeStartB = verticesB[edgeDefB.startVertex]
        let edgeEndB = verticesB[edgeDefB.endVertex]
        
        // Calculate edge vectors
        let vectorA = CGVector(dx: edgeEndA.x - edgeStartA.x, dy: edgeEndA.y - edgeStartA.y)
        let vectorB = CGVector(dx: edgeEndB.x - edgeStartB.x, dy: edgeEndB.y - edgeStartB.y)
        
        let lengthA = sqrt(vectorA.dx * vectorA.dx + vectorA.dy * vectorA.dy)
        let lengthB = sqrt(vectorB.dx * vectorB.dx + vectorB.dy * vectorB.dy)
        
        // Avoid division by zero
        guard lengthA > 0.001 && lengthB > 0.001 else {
            return false
        }
        
        let normalizedA = CGVector(dx: vectorA.dx / lengthA, dy: vectorA.dy / lengthA)
        let normalizedB = CGVector(dx: vectorB.dx / lengthB, dy: vectorB.dy / lengthB)
        
        // Check if edges are parallel (dot product should be -1 for opposite or 1 for same direction)
        let dotProduct = normalizedA.dx * normalizedB.dx + normalizedA.dy * normalizedB.dy
        let isParallel = abs(abs(dotProduct) - 1.0) < 0.01  // Tolerance for floating point
        
        if !isParallel {
            return false
        }
        
        // Check if edges overlap/touch
        // For edge-to-edge sliding, we need to verify that at least part of the edges are aligned
        
        // Project all endpoints onto the line defined by edge A
        let projectPointOntoLine = { (point: CGPoint) -> CGFloat in
            let dx = point.x - edgeStartA.x
            let dy = point.y - edgeStartA.y
            return (dx * normalizedA.dx + dy * normalizedA.dy)
        }
        
        // Get projections of all edge endpoints
        let projStartA: CGFloat = 0  // By definition
        let projEndA = lengthA
        let projStartB = projectPointOntoLine(edgeStartB)
        let projEndB = projectPointOntoLine(edgeEndB)
        
        // Ensure B's projections are in the correct order
        let minProjB = min(projStartB, projEndB)
        let maxProjB = max(projStartB, projEndB)
        
        // Check if the projections overlap
        let overlapStart = max(projStartA, minProjB)
        let overlapEnd = min(projEndA, maxProjB)
        let hasOverlap = overlapEnd > overlapStart + 0.1  // Small tolerance
        
        if !hasOverlap {
            return false
        }
        
        // Check perpendicular distance (edges should be touching)
        // Calculate distance from edge B start to line A
        let perpDistance = abs(
            (edgeEndA.y - edgeStartA.y) * edgeStartB.x -
            (edgeEndA.x - edgeStartA.x) * edgeStartB.y +
            edgeEndA.x * edgeStartA.y -
            edgeEndA.y * edgeStartA.x
        ) / lengthA
        
        // Edges should be touching (within tolerance)
        return perpDistance <= touchTolerance
    }
    
    /// Check if a vertex-to-edge connection is maintained
    static func isVertexToEdgeConnectionValid(
        piece: TangramPiece,
        vertex: Int,
        edgePiece: TangramPiece,
        edge: Int
    ) -> Bool {
        let vertices = TangramCoordinateSystem.getWorldVertices(for: piece)
        guard vertex < vertices.count else { return false }
        
        let vertexPoint = vertices[vertex]
        let edgeVertices = TangramCoordinateSystem.getWorldVertices(for: edgePiece)
        let edges = TangramGeometry.edges(for: edgePiece.type)
        
        guard edge < edges.count else { return false }
        
        let edgeDef = edges[edge]
        let edgeStart = edgeVertices[edgeDef.startVertex]
        let edgeEnd = edgeVertices[edgeDef.endVertex]
        
        // Check if vertex is on the edge line
        return isPointOnLineSegment(point: vertexPoint, 
                                   lineStart: edgeStart, 
                                   lineEnd: edgeEnd,
                                   tolerance: vertexConnectionTolerance)
    }
    
    /// Check if any connection is maintained after transform
    private static func isConnectionMaintained(
        connection: Connection,
        piece: TangramPiece,
        amongPieces: [TangramPiece]
    ) -> Bool {
        switch connection.type {
        case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
            guard let otherPiece = amongPieces.first(where: { 
                $0.id == (piece.id == pieceAId ? pieceBId : pieceAId) 
            }) else { return false }
            
            if piece.id == pieceAId {
                return isVertexToVertexConnectionValid(pieceA: piece, vertexA: vertexA,
                                                      pieceB: otherPiece, vertexB: vertexB)
            } else {
                return isVertexToVertexConnectionValid(pieceA: otherPiece, vertexA: vertexA,
                                                      pieceB: piece, vertexB: vertexB)
            }
            
        case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
            guard let otherPiece = amongPieces.first(where: { 
                $0.id == (piece.id == pieceAId ? pieceBId : pieceAId) 
            }) else { return false }
            
            if piece.id == pieceAId {
                return isEdgeToEdgeConnectionValid(pieceA: piece, edgeA: edgeA,
                                                  pieceB: otherPiece, edgeB: edgeB)
            } else {
                return isEdgeToEdgeConnectionValid(pieceA: otherPiece, edgeA: edgeA,
                                                  pieceB: piece, edgeB: edgeB)
            }
            
        case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
            guard let otherPiece = amongPieces.first(where: { 
                $0.id == (piece.id == pieceAId ? pieceBId : pieceAId) 
            }) else { return false }
            
            if piece.id == pieceAId {
                return isVertexToEdgeConnectionValid(piece: piece, vertex: vertex,
                                                    edgePiece: otherPiece, edge: edge)
            } else {
                return isVertexToEdgeConnectionValid(piece: otherPiece, vertex: vertex,
                                                    edgePiece: piece, edge: edge)
            }
        }
    }
    
    /// Helper to check if a point is on a line segment
    private static func isPointOnLineSegment(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        // Calculate distance from point to line
        let lineLength = sqrt(pow(lineEnd.x - lineStart.x, 2) + pow(lineEnd.y - lineStart.y, 2))
        
        if lineLength < 0.001 { // Line is actually a point
            let distance = sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2))
            return distance <= tolerance
        }
        
        // Calculate perpendicular distance from point to line
        let t = max(0, min(1, ((point.x - lineStart.x) * (lineEnd.x - lineStart.x) + 
                               (point.y - lineStart.y) * (lineEnd.y - lineStart.y)) / 
                               (lineLength * lineLength)))
        
        let projection = CGPoint(x: lineStart.x + t * (lineEnd.x - lineStart.x),
                                y: lineStart.y + t * (lineEnd.y - lineStart.y))
        
        let distance = sqrt(pow(point.x - projection.x, 2) + pow(point.y - projection.y, 2))
        return distance <= tolerance
    }
    
    // MARK: - Rotation Validation
    
    /// Calculate valid rotation angles for a piece with vertex connection
    static func validRotationAngles(
        for piece: TangramPiece,
        withConnection connection: Connection,
        pivot: CGPoint,
        amongPieces otherPieces: [TangramPiece]
    ) -> [Double] {
        var validAngles: [Double] = []
        let testAngles: [Double] = [-180, -135, -90, -45, 0, 45, 90, 135, 180]
        
        for angle in testAngles {
            let radians = angle * .pi / 180
            
            // Calculate transform that keeps vertex at pivot
            let transform = calculateRotationTransform(
                for: piece,
                angle: radians,
                pivot: pivot,
                connection: connection
            )
            
            if isValidPlacement(piece: piece, 
                               withTransform: transform,
                               amongPieces: otherPieces,
                               maintainingConnection: connection) {
                validAngles.append(angle)
            }
        }
        
        return validAngles
    }
    
    /// Calculate the correct transform for rotating a piece around a pivot
    static func calculateRotationTransform(
        for piece: TangramPiece,
        angle: Double,
        pivot: CGPoint,
        connection: Connection
    ) -> CGAffineTransform {
        // Get the vertex that needs to stay at the pivot
        var pieceVertexIndex = 0
        
        switch connection.type {
        case .vertexToVertex(let pieceAId, let vertexA, _, let vertexB):
            pieceVertexIndex = (pieceAId == piece.id) ? vertexA : vertexB
        default:
            break
        }
        
        // Get the piece's base vertex in visual space (no transform)
        let geometry = TangramGeometry.vertices(for: piece.type)
        guard pieceVertexIndex < geometry.count else {
            return piece.transform
        }
        
        let localVertex = geometry[pieceVertexIndex]
        let visualVertex = CGPoint(
            x: localVertex.x * CGFloat(TangramConstants.visualScale),
            y: localVertex.y * CGFloat(TangramConstants.visualScale)
        )
        
        // Create rotation transform
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: angle)
        
        // Find where the vertex ends up after rotation
        let rotatedVertex = visualVertex.applying(transform)
        
        // Translate so the rotated vertex is at the pivot
        transform.tx = pivot.x - rotatedVertex.x
        transform.ty = pivot.y - rotatedVertex.y
        
        return transform
    }
}