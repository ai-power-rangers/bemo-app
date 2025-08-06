//
//  ConnectionService.swift
//  Bemo
//
//  Service for managing connections between tangram pieces
//

import Foundation
import CoreGraphics

class ConnectionService {
    
    private let constraintManager = ConstraintManager()
    private let geometryService = GeometryService()
    
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
            let worldVerticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
            let worldVerticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
            
            guard vertexA < worldVerticesA.count, vertexB < worldVerticesB.count else { 
                return nil 
            }
            
            let worldVertexA = worldVerticesA[vertexA]
            let worldVertexB = worldVerticesB[vertexB]
            
            if geometryService.pointsEqual(worldVertexA, worldVertexB) {
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
            let worldVerticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
            let worldVerticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
            
            let edgeStartA = worldVerticesA[edgesA[edgeA].startVertex]
            let edgeEndA = worldVerticesA[edgesA[edgeA].endVertex]
            
            // Calculate actual edge lengths in world space
            let edgeLengthA = geometryService.distance(from: edgeStartA, to: edgeEndA)
            let edgeStartB = worldVerticesB[edgesB[edgeB].startVertex]
            let edgeEndB = worldVerticesB[edgesB[edgeB].endVertex]
            let edgeLengthB = geometryService.distance(from: edgeStartB, to: edgeEndB)
            
            // Determine which edge is longer (the track) and which is sliding
            let (trackStart, trackEnd, trackLength, slidingLength, affectedPiece) = 
                edgeLengthA > edgeLengthB ? 
                (edgeStartA, edgeEndA, edgeLengthA, edgeLengthB, pieceBId) :
                (edgeStartB, edgeEndB, edgeLengthB, edgeLengthA, pieceAId)
            
            let edgeVector = geometryService.edgeVector(from: trackStart, to: trackEnd)
            let normalizedVector = geometryService.normalizeVector(edgeVector)
            
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
            let worldVerticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
            let worldVerticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
            let edgesB = TangramGeometry.edges(for: pieceB.type)
            
            guard vertex < worldVerticesA.count, edge < edgesB.count else {
                return nil
            }
            
            let edgeStartB = worldVerticesB[edgesB[edge].startVertex]
            let edgeEndB = worldVerticesB[edgesB[edge].endVertex]
            
            let edgeVector = geometryService.edgeVector(from: edgeStartB, to: edgeEndB)
            let normalizedVector = geometryService.normalizeVector(edgeVector)
            let edgeLength = geometryService.distance(from: edgeStartB, to: edgeEndB)
            
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
                resultTransform = constraintManager.applyConstraint(connection.constraint, to: resultTransform, parameter: parameter)
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
        let verticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
        let verticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
        
        let tolerance: CGFloat = 1e-5
        
        switch connection.type {
        case .vertexToVertex(_, let vertexA, _, let vertexB):
            guard vertexA < verticesA.count && vertexB < verticesB.count else {
                return false
            }
            
            let pointA = verticesA[vertexA]
            let pointB = verticesB[vertexB]
            return geometryService.pointsEqual(pointA, pointB, tolerance: tolerance)
            
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
            if geometryService.edgesCoincide(edgeA, edgeB, tolerance: tolerance) {
                return true
            }
            
            // Check if the shorter edge lies along the longer edge
            let lengthA = geometryService.distance(from: edgeStartA, to: edgeEndA)
            let lengthB = geometryService.distance(from: edgeStartB, to: edgeEndB)
            
            if lengthA > lengthB {
                return geometryService.edgePartiallyCoincides(
                    shorterEdge: edgeB, 
                    longerEdge: edgeA, 
                    tolerance: tolerance
                )
            } else {
                return geometryService.edgePartiallyCoincides(
                    shorterEdge: edgeA, 
                    longerEdge: edgeB, 
                    tolerance: tolerance
                )
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
            return geometryService.pointOnLineSegment(vertexPoint, edgeStartB, edgeEndB)
        }
    }
}