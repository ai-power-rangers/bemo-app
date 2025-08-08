//
//  ConnectionService.swift
//  Bemo
//
//  Service for managing connections between tangram pieces
//

import Foundation
import CoreGraphics

class ConnectionService {
    
    // MARK: - Connection Creation
    
    /// Create a connection between two pieces
    func createConnection(type: ConnectionType, pieces: [TangramPiece]) -> Connection? {
        guard let constraint = calculateConstraint(for: type, pieces: pieces) else { 
            return nil 
        }
        
        if !validateConnection(type, pieces: pieces) {
            return nil
        }
        
        return Connection(type: type, constraint: constraint)
    }
    
    /// Check if two pieces are connected
    func areConnected(pieceA: String, pieceB: String, connections: [Connection]) -> Bool {
        return connectionBetween(pieceA, pieceB, connections: connections) != nil
    }
    
    /// Get the connection between two pieces if it exists
    func connectionBetween(_ pieceA: String, _ pieceB: String, connections: [Connection]) -> Connection? {
        return connections.first { connection in
            let connectedPieces = Set([connection.pieceAId, connection.pieceBId])
            return connectedPieces == Set([pieceA, pieceB])
        }
    }
    
    // MARK: - Constraint Calculation
    
    private func calculateConstraint(for connectionType: ConnectionType, pieces: [TangramPiece]) -> Constraint? {
        switch connectionType {
        case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
            guard let pieceA = pieces.first(where: { $0.id == pieceAId }),
                  let pieceB = pieces.first(where: { $0.id == pieceBId }) else { 
                return nil 
            }
            
            // Use centralized coordinate system for vertex positions
            let worldVerticesA = TangramEditorCoordinateSystem.getWorldVertices(for: pieceA)
            let worldVerticesB = TangramEditorCoordinateSystem.getWorldVertices(for: pieceB)
            
            guard vertexA < worldVerticesA.count, vertexB < worldVerticesB.count else { 
                return nil 
            }
            
            let worldVertexA = worldVerticesA[vertexA]
            let worldVertexB = worldVerticesB[vertexB]
            
            // Check if vertices are equal with tolerance
            let tolerance: CGFloat = 1e-5
            if abs(worldVertexA.x - worldVertexB.x) < tolerance && abs(worldVertexA.y - worldVertexB.y) < tolerance {
                return Constraint(
                    type: .rotation(around: worldVertexA, range: 0...360),
                    affectedPieceId: pieceBId
                )
            } else {
                return nil
            }
            
        case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
            guard let pieceA = pieces.first(where: { $0.id == pieceAId }),
                  let pieceB = pieces.first(where: { $0.id == pieceBId }) else { 
                return nil 
            }
            
            let edgesA = TangramGeometry.edges(for: pieceA.type)
            let edgesB = TangramGeometry.edges(for: pieceB.type)
            
            guard edgeA < edgesA.count, edgeB < edgesB.count else { 
                return nil 
            }
            
            // Use centralized coordinate system for edge positions
            let worldVerticesA = TangramEditorCoordinateSystem.getWorldVertices(for: pieceA)
            let worldVerticesB = TangramEditorCoordinateSystem.getWorldVertices(for: pieceB)
            
            let edgeStartA = worldVerticesA[edgesA[edgeA].startVertex]
            let edgeEndA = worldVerticesA[edgesA[edgeA].endVertex]
            
            // Calculate actual edge lengths in world space
            let edgeLengthA = sqrt(pow(edgeEndA.x - edgeStartA.x, 2) + pow(edgeEndA.y - edgeStartA.y, 2))
            let edgeStartB = worldVerticesB[edgesB[edgeB].startVertex]
            let edgeEndB = worldVerticesB[edgesB[edgeB].endVertex]
            let edgeLengthB = sqrt(pow(edgeEndB.x - edgeStartB.x, 2) + pow(edgeEndB.y - edgeStartB.y, 2))
            
            // Determine which edge is longer (the track) and which is sliding
            let (trackStart, trackEnd, trackLength, slidingLength, affectedPiece) = 
                edgeLengthA > edgeLengthB ? 
                (edgeStartA, edgeEndA, edgeLengthA, edgeLengthB, pieceBId) :
                (edgeStartB, edgeEndB, edgeLengthB, edgeLengthA, pieceAId)
            
            let edgeVector = CGVector(dx: trackEnd.x - trackStart.x, dy: trackEnd.y - trackStart.y)
            let magnitude = sqrt(edgeVector.dx * edgeVector.dx + edgeVector.dy * edgeVector.dy)
            let normalizedVector = CGVector(dx: edgeVector.dx / magnitude, dy: edgeVector.dy / magnitude)
            
            // Sliding range is the track length minus the sliding piece length
            let slidingRange: Double = max(0, trackLength - slidingLength)
            
            return Constraint(
                type: .translation(along: normalizedVector, range: 0...slidingRange),
                affectedPieceId: affectedPiece
            )
            
        case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
            // For vertex-to-edge connections, constrain the vertex to slide along the edge
            guard let pieceA = pieces.first(where: { $0.id == pieceAId }),
                  let pieceB = pieces.first(where: { $0.id == pieceBId }) else {
                return nil
            }
            
            // Use centralized coordinate system for vertex and edge positions
            let worldVerticesA = TangramEditorCoordinateSystem.getWorldVertices(for: pieceA)
            let worldVerticesB = TangramEditorCoordinateSystem.getWorldVertices(for: pieceB)
            let edgesB = TangramGeometry.edges(for: pieceB.type)
            
            guard vertex < worldVerticesA.count, edge < edgesB.count else {
                return nil
            }
            
            let edgeStartB = worldVerticesB[edgesB[edge].startVertex]
            let edgeEndB = worldVerticesB[edgesB[edge].endVertex]
            
            let edgeVector = CGVector(dx: edgeEndB.x - edgeStartB.x, dy: edgeEndB.y - edgeStartB.y)
            let magnitude = sqrt(edgeVector.dx * edgeVector.dx + edgeVector.dy * edgeVector.dy)
            let normalizedVector = CGVector(dx: edgeVector.dx / magnitude, dy: edgeVector.dy / magnitude)
            let edgeLength = magnitude
            
            return Constraint(
                type: .translation(along: normalizedVector, range: 0...edgeLength),
                affectedPieceId: pieceAId
            )
        }
    }
    
    // MARK: - Connection Validation
    
    private func validateConnection(_ connectionType: ConnectionType, pieces: [TangramPiece]) -> Bool {
        switch connectionType {
        case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
            guard let pieceA = pieces.first(where: { $0.id == pieceAId }),
                  let pieceB = pieces.first(where: { $0.id == pieceBId }) else { 
                return false 
            }
            
            let verticesA = TangramGeometry.vertices(for: pieceA.type)
            let verticesB = TangramGeometry.vertices(for: pieceB.type)
            
            return vertexA < verticesA.count && vertexB < verticesB.count
            
        case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
            guard let pieceA = pieces.first(where: { $0.id == pieceAId }),
                  let pieceB = pieces.first(where: { $0.id == pieceBId }) else { 
                return false 
            }
            
            let edgesA = TangramGeometry.edges(for: pieceA.type)
            let edgesB = TangramGeometry.edges(for: pieceB.type)
            
            guard edgeA < edgesA.count, edgeB < edgesB.count else { 
                return false 
            }
            
            // Allow edge connections even with different lengths
            return true
            
        case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
            guard let pieceA = pieces.first(where: { $0.id == pieceAId }),
                  let pieceB = pieces.first(where: { $0.id == pieceBId }) else {
                return false
            }
            
            let verticesA = TangramGeometry.vertices(for: pieceA.type)
            let edgesB = TangramGeometry.edges(for: pieceB.type)
            
            return vertex < verticesA.count && edge < edgesB.count
        }
    }
    
    /// Apply constraints to a piece based on its connections
    func applyConstraints(for pieceId: String, 
                         connections: [Connection], 
                         currentTransform: CGAffineTransform, 
                         parameter: Double = 0.0) -> CGAffineTransform {
        
        var resultTransform = currentTransform
        
        let pieceConnections = connections.filter { connection in
            connection.pieceAId == pieceId || connection.pieceBId == pieceId
        }
        
        for connection in pieceConnections {
            if connection.constraint.affectedPieceId == pieceId {
                // Apply constraint based on type
                switch connection.constraint.type {
                case .rotation(let pivot, _):
                    // Apply rotation constraint around pivot
                    resultTransform = resultTransform.translatedBy(x: pivot.x, y: pivot.y)
                        .rotated(by: parameter)
                        .translatedBy(x: -pivot.x, y: -pivot.y)
                case .translation(let direction, let range):
                    // Apply translation constraint along direction
                    let distance = max(range.lowerBound, min(parameter, range.upperBound))
                    resultTransform = resultTransform.translatedBy(
                        x: direction.dx * distance,
                        y: direction.dy * distance
                    )
                case .fixed:
                    // Fixed constraint - no transformation applied
                    break
                }
            }
        }
        
        return resultTransform
    }
    
    /// Check if a connection is geometrically satisfied
    func isConnectionSatisfied(_ connection: Connection, pieces: [TangramPiece]) -> Bool {
        let pieceA = pieces.first { $0.id == connection.pieceAId }
        let pieceB = pieces.first { $0.id == connection.pieceBId }
        
        guard let pieceA = pieceA, let pieceB = pieceB else { 
            return false 
        }
        
        // Use centralized coordinate system for world vertices
        let verticesA = TangramEditorCoordinateSystem.getWorldVertices(for: pieceA)
        let verticesB = TangramEditorCoordinateSystem.getWorldVertices(for: pieceB)
        
        let tolerance: CGFloat = 1e-5
        
        switch connection.type {
        case .vertexToVertex(_, let vertexA, _, let vertexB):
            guard vertexA < verticesA.count && vertexB < verticesB.count else {
                return false
            }
            
            let pointA = verticesA[vertexA]
            let pointB = verticesB[vertexB]
            return abs(pointA.x - pointB.x) < tolerance && abs(pointA.y - pointB.y) < tolerance
            
        case .edgeToEdge(let pieceAId, let edgeA, _, let edgeB):
            guard let pieceAObj = pieces.first(where: { $0.id == pieceAId }) else {
                return false
            }
            
            let edgesA = TangramGeometry.edges(for: pieceAObj.type)
            let edgesB = TangramGeometry.edges(for: pieceB.type)
            
            guard edgeA < edgesA.count && edgeB < edgesB.count else {
                return false
            }
            
            let edgeDefA = edgesA[edgeA]
            let edgeDefB = edgesB[edgeB]
            
            let edgeStartA = verticesA[edgeDefA.startVertex]
            let edgeEndA = verticesA[edgeDefA.endVertex]
            let edgeStartB = verticesB[edgeDefB.startVertex]
            let edgeEndB = verticesB[edgeDefB.endVertex]
            
            let edgeA = (edgeStartA, edgeEndA)
            let edgeB = (edgeStartB, edgeEndB)
            
            // Check if edges coincide or partially coincide
            // Check if edges coincide (same line, overlapping)
            // This is a simplified check - edges coincide if endpoints match
            let aStartMatchesBStart = abs(edgeStartA.x - edgeStartB.x) < tolerance && abs(edgeStartA.y - edgeStartB.y) < tolerance
            let aStartMatchesBEnd = abs(edgeStartA.x - edgeEndB.x) < tolerance && abs(edgeStartA.y - edgeEndB.y) < tolerance
            let aEndMatchesBStart = abs(edgeEndA.x - edgeStartB.x) < tolerance && abs(edgeEndA.y - edgeStartB.y) < tolerance
            let aEndMatchesBEnd = abs(edgeEndA.x - edgeEndB.x) < tolerance && abs(edgeEndA.y - edgeEndB.y) < tolerance
            
            if (aStartMatchesBStart && aEndMatchesBEnd) || (aStartMatchesBEnd && aEndMatchesBStart) {
                return true
            }
            
            // Check if the shorter edge lies along the longer edge
            let lengthA = sqrt(pow(edgeEndA.x - edgeStartA.x, 2) + pow(edgeEndA.y - edgeStartA.y, 2))
            let lengthB = sqrt(pow(edgeEndB.x - edgeStartB.x, 2) + pow(edgeEndB.y - edgeStartB.y, 2))
            
            if lengthA > lengthB {
                // Check if shorter edge lies along longer edge
                return isEdgeOnLine(edge: edgeB, line: edgeA, tolerance: tolerance)
            } else {
                // Check if shorter edge lies along longer edge
                return isEdgeOnLine(edge: edgeA, line: edgeB, tolerance: tolerance)
            }
            
        case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
            guard vertex < verticesA.count,
                  let pieceAObj = pieces.first(where: { $0.id == pieceAId }),
                  let pieceBObj = pieces.first(where: { $0.id == pieceBId }) else {
                return false
            }
            
            let edgesB = TangramGeometry.edges(for: pieceBObj.type)
            guard edge < edgesB.count else {
                return false
            }
            
            let vertexPoint = verticesA[vertex]
            let edgeDefB = edgesB[edge]
            let edgeStartB = verticesB[edgeDefB.startVertex]
            let edgeEndB = verticesB[edgeDefB.endVertex]
            
            // Check if vertex lies on the edge
            // Check if vertex lies on the edge
            return isPointOnLineSegment(vertexPoint, edgeStartB, edgeEndB)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isEdgeOnLine(edge: (CGPoint, CGPoint), line: (CGPoint, CGPoint), tolerance: CGFloat) -> Bool {
        // Check if both endpoints of the edge lie on the line
        return isPointOnLineSegment(edge.0, line.0, line.1, tolerance: tolerance) &&
               isPointOnLineSegment(edge.1, line.0, line.1, tolerance: tolerance)
    }
    
    private func isPointOnLineSegment(_ point: CGPoint, _ lineStart: CGPoint, _ lineEnd: CGPoint, tolerance: CGFloat = 1e-5) -> Bool {
        // Vector from lineStart to lineEnd
        let lineVec = CGVector(dx: lineEnd.x - lineStart.x, dy: lineEnd.y - lineStart.y)
        // Vector from lineStart to point
        let pointVec = CGVector(dx: point.x - lineStart.x, dy: point.y - lineStart.y)
        
        // Calculate parameter t for projection
        let lineLengthSquared = lineVec.dx * lineVec.dx + lineVec.dy * lineVec.dy
        if lineLengthSquared < tolerance {
            // Line is essentially a point
            return abs(point.x - lineStart.x) < tolerance && abs(point.y - lineStart.y) < tolerance
        }
        
        let t = (pointVec.dx * lineVec.dx + pointVec.dy * lineVec.dy) / lineLengthSquared
        
        // Check if projection is within segment bounds
        if t < -tolerance || t > 1 + tolerance {
            return false
        }
        
        // Calculate perpendicular distance
        let projectedPoint = CGPoint(
            x: lineStart.x + t * lineVec.dx,
            y: lineStart.y + t * lineVec.dy
        )
        
        let distance = sqrt(pow(point.x - projectedPoint.x, 2) + pow(point.y - projectedPoint.y, 2))
        return distance < tolerance
    }
}