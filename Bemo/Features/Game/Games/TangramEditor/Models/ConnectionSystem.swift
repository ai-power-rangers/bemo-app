//
//  ConnectionSystem.swift
//  Bemo
//
//  Constraint-based connection system for tangram pieces
//

import Foundation
import CoreGraphics

enum ConnectionType {
    case vertexToVertex(pieceA: String, vertexA: Int, pieceB: String, vertexB: Int)
    case edgeToEdge(pieceA: String, edgeA: Int, pieceB: String, edgeB: Int)
    
    var pieceAId: String {
        switch self {
        case .vertexToVertex(let pieceA, _, _, _), .edgeToEdge(let pieceA, _, _, _):
            return pieceA
        }
    }
    
    var pieceBId: String {
        switch self {
        case .vertexToVertex(_, _, let pieceB, _), .edgeToEdge(_, _, let pieceB, _):
            return pieceB
        }
    }
}

enum ConstraintType {
    case rotation(around: CGPoint, range: ClosedRange<Double>)
    case translation(along: CGVector, range: ClosedRange<Double>)
    case fixed
    
    var isFullyConstrained: Bool {
        switch self {
        case .fixed:
            return true
        case .rotation(_, let range):
            return range.upperBound - range.lowerBound < 0.001
        case .translation(_, let range):
            return range.upperBound - range.lowerBound < 0.001
        }
    }
}

struct Constraint {
    let type: ConstraintType
    let affectedPieceId: String
    
    func apply(to transform: CGAffineTransform, parameter: Double) -> CGAffineTransform {
        switch type {
        case .rotation(let center, let range):
            let clampedAngle = max(range.lowerBound, min(range.upperBound, parameter))
            let rotation = GeometryEngine.rotationMatrix(angle: clampedAngle)
            
            let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
            let fromOrigin = CGAffineTransform(translationX: center.x, y: center.y)
            
            return transform
                .concatenating(toOrigin)
                .concatenating(rotation)
                .concatenating(fromOrigin)
            
        case .translation(let vector, let range):
            let clampedT = max(range.lowerBound, min(range.upperBound, parameter))
            let translation = CGAffineTransform(
                translationX: vector.dx * CGFloat(clampedT),
                y: vector.dy * CGFloat(clampedT)
            )
            return transform.concatenating(translation)
            
        case .fixed:
            return transform
        }
    }
    
    func validParameters() -> [Double] {
        switch type {
        case .rotation(_, let range):
            let steps = Int((range.upperBound - range.lowerBound) / 15.0) + 1
            return (0..<steps).map { i in
                range.lowerBound + Double(i) * 15.0
            }
            
        case .translation(_, let range):
            let steps = Int((range.upperBound - range.lowerBound) / 0.1) + 1
            return (0..<steps).map { i in
                range.lowerBound + Double(i) * 0.1
            }
            
        case .fixed:
            return [0.0]
        }
    }
}

class ConnectionSystem {
    private var connections: [Connection] = []
    internal var localPieceTransforms: [String: CGAffineTransform] = [:]
    internal var pieceTypes: [String: TangramPieceGeometry.PieceType] = [:]
    
    func addPiece(id: String, type: TangramPieceGeometry.PieceType, transform: CGAffineTransform) {
        pieceTypes[id] = type
        localPieceTransforms[id] = transform
    }
    
    func removePiece(id: String) {
        pieceTypes.removeValue(forKey: id)
        localPieceTransforms.removeValue(forKey: id)
        connections.removeAll { connection in
            connection.type.pieceAId == id || connection.type.pieceBId == id
        }
    }
    
    func createConnection(type: ConnectionType) -> Connection? {
        guard let constraint = calculateConstraint(for: type) else { return nil }
        
        if !validateConnection(type) {
            return nil
        }
        
        let connection = Connection(type: type, constraint: constraint)
        connections.append(connection)
        return connection
    }
    
    func removeConnection(id: String) {
        connections.removeAll { $0.id == id }
    }
    
    func getConnections(for pieceId: String) -> [Connection] {
        return connections.filter { connection in
            connection.type.pieceAId == pieceId || connection.type.pieceBId == pieceId
        }
    }
    
    func getAllConnections() -> [Connection] {
        return connections
    }
    
    func applyConstraints(for pieceId: String, parameter: Double = 0.0) -> CGAffineTransform? {
        guard let currentTransform = localPieceTransforms[pieceId] else { return nil }
        
        let pieceConnections = getConnections(for: pieceId)
        var resultTransform = currentTransform
        
        for connection in pieceConnections {
            if connection.constraint.affectedPieceId == pieceId {
                resultTransform = connection.constraint.apply(to: resultTransform, parameter: parameter)
            }
        }
        
        return resultTransform
    }
    
    func updatePieceTransform(id: String, transform: CGAffineTransform) {
        localPieceTransforms[id] = transform
    }
    
    func addConnection(_ connection: Connection) {
        connections.append(connection)
    }
    
    private func calculateConstraint(for connectionType: ConnectionType) -> Constraint? {
        switch connectionType {
        case .vertexToVertex(let pieceA, let vertexA, let pieceB, let vertexB):
            guard let typeA = pieceTypes[pieceA],
                  let typeB = pieceTypes[pieceB],
                  let transformA = localPieceTransforms[pieceA],
                  let transformB = localPieceTransforms[pieceB] else { return nil }
            
            let verticesA = TangramPieceGeometry.vertices(for: typeA)
            let verticesB = TangramPieceGeometry.vertices(for: typeB)
            
            guard vertexA < verticesA.count, vertexB < verticesB.count else { return nil }
            
            let worldVertexA = verticesA[vertexA].applying(transformA)
            let worldVertexB = verticesB[vertexB].applying(transformB)
            
            if GeometryEngine.pointsEqual(worldVertexA, worldVertexB) {
                return Constraint(
                    type: .rotation(around: worldVertexA, range: 0...360),
                    affectedPieceId: pieceB
                )
            } else {
                return nil
            }
            
        case .edgeToEdge(let pieceA, let edgeA, let pieceB, let edgeB):
            guard let typeA = pieceTypes[pieceA],
                  let typeB = pieceTypes[pieceB],
                  let transformA = localPieceTransforms[pieceA],
                  let transformB = localPieceTransforms[pieceB] else { return nil }
            
            let edgesA = TangramPieceGeometry.edges(for: typeA)
            let edgesB = TangramPieceGeometry.edges(for: typeB)
            
            guard edgeA < edgesA.count, edgeB < edgesB.count else { return nil }
            
            let edgeLengthA = edgesA[edgeA].length
            let edgeLengthB = edgesB[edgeB].length
            
            // Allow connections between edges of different lengths
            // The shorter edge can slide along the longer edge
            let verticesA = TangramPieceGeometry.vertices(for: typeA)
            let verticesB = TangramPieceGeometry.vertices(for: typeB)
            
            let edgeStartA = verticesA[edgesA[edgeA].startVertex].applying(transformA)
            let edgeEndA = verticesA[edgesA[edgeA].endVertex].applying(transformA)
            
            let edgeVector = GeometryEngine.edgeVector(from: edgeStartA, to: edgeEndA)
            let normalizedVector = GeometryEngine.normalizeVector(edgeVector)
            
            // Calculate sliding range based on edge length difference
            // If pieceB's edge is shorter, it can slide along pieceA's edge
            let slidingRange: Double = max(0, edgeLengthA - edgeLengthB)
            
            return Constraint(
                type: .translation(along: normalizedVector, range: 0...slidingRange),
                affectedPieceId: pieceB
            )
        }
    }
    
    private func validateConnection(_ connectionType: ConnectionType) -> Bool {
        switch connectionType {
        case .vertexToVertex(let pieceA, let vertexA, let pieceB, let vertexB):
            guard let typeA = pieceTypes[pieceA],
                  let typeB = pieceTypes[pieceB] else { return false }
            
            let verticesA = TangramPieceGeometry.vertices(for: typeA)
            let verticesB = TangramPieceGeometry.vertices(for: typeB)
            
            return vertexA < verticesA.count && vertexB < verticesB.count
            
        case .edgeToEdge(let pieceA, let edgeA, let pieceB, let edgeB):
            guard let typeA = pieceTypes[pieceA],
                  let typeB = pieceTypes[pieceB] else { return false }
            
            let edgesA = TangramPieceGeometry.edges(for: typeA)
            let edgesB = TangramPieceGeometry.edges(for: typeB)
            
            guard edgeA < edgesA.count, edgeB < edgesB.count else { return false }
            
            // Allow edge connections even with different lengths
            // The only requirement is that both edges exist
            return true
        }
    }
    
    func isFullyConstrained(pieceId: String) -> Bool {
        let connections = getConnections(for: pieceId)
        
        if connections.count >= 2 {
            return true
        }
        
        return connections.contains { $0.constraint.type.isFullyConstrained }
    }
    
    // MARK: - New Clean Validation System
    
    enum GeometricRelationship {
        case areaOverlap
        case edgeContact
        case vertexContact
        case noContact
    }
    
    // LEVEL 1: Pure Geometric Detection
    
    /// Check if two pieces have interior area overlap (always invalid)
    func hasAreaOverlap(_ pieceA: String, _ pieceB: String) -> Bool {
        guard let typeA = pieceTypes[pieceA],
              let typeB = pieceTypes[pieceB],
              let transformA = localPieceTransforms[pieceA],
              let transformB = localPieceTransforms[pieceB] else { return false }
        
        let verticesA = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeA),
            with: transformA
        )
        let verticesB = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeB),
            with: transformB
        )
        
        return GeometryEngine.polygonsOverlap(verticesA, verticesB)
    }
    
    /// Check if two pieces share an edge or part of an edge
    func hasEdgeContact(_ pieceA: String, _ pieceB: String) -> Bool {
        guard let typeA = pieceTypes[pieceA],
              let typeB = pieceTypes[pieceB],
              let transformA = localPieceTransforms[pieceA],
              let transformB = localPieceTransforms[pieceB] else { return false }
        
        let verticesA = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeA),
            with: transformA
        )
        let verticesB = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeB),
            with: transformB
        )
        
        return !GeometryEngine.sharedEdges(verticesA, verticesB).isEmpty
    }
    
    /// Check if two pieces touch at exactly one vertex
    func hasVertexContact(_ pieceA: String, _ pieceB: String) -> Bool {
        guard let typeA = pieceTypes[pieceA],
              let typeB = pieceTypes[pieceB],
              let transformA = localPieceTransforms[pieceA],
              let transformB = localPieceTransforms[pieceB] else { return false }
        
        let verticesA = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeA),
            with: transformA
        )
        let verticesB = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeB),
            with: transformB
        )
        
        return !GeometryEngine.sharedVertices(verticesA, verticesB).isEmpty
    }
    
    /// Get the geometric relationship between two pieces
    func getGeometricRelationship(_ pieceA: String, _ pieceB: String) -> GeometricRelationship {
        // Check in priority order
        if hasAreaOverlap(pieceA, pieceB) {
            return .areaOverlap
        } else if hasEdgeContact(pieceA, pieceB) {
            return .edgeContact
        } else if hasVertexContact(pieceA, pieceB) {
            return .vertexContact
        } else {
            return .noContact
        }
    }
    
    // LEVEL 2: Connection Queries
    
    /// Check if two pieces have a declared connection
    func areConnected(_ pieceA: String, _ pieceB: String) -> Bool {
        return connectionBetween(pieceA, pieceB) != nil
    }
    
    // LEVEL 3: Semantic Validation
    
    /// Check if any pieces have area overlap (always invalid)
    func hasInvalidAreaOverlaps() -> Bool {
        let pieceIds = Array(pieceTypes.keys)
        
        for i in 0..<pieceIds.count {
            for j in (i+1)..<pieceIds.count {
                if hasAreaOverlap(pieceIds[i], pieceIds[j]) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check if any pieces touch without a connection
    func hasUnexplainedContacts() -> Bool {
        let pieceIds = Array(pieceTypes.keys)
        
        for i in 0..<pieceIds.count {
            for j in (i+1)..<pieceIds.count {
                let relationship = getGeometricRelationship(pieceIds[i], pieceIds[j])
                
                switch relationship {
                case .edgeContact, .vertexContact:
                    if !areConnected(pieceIds[i], pieceIds[j]) {
                        return true // Touching without connection
                    }
                case .areaOverlap, .noContact:
                    continue
                }
            }
        }
        
        return false
    }
    
    /// Main validation method - clear and simple
    func isValidAssembly() -> Bool {
        // 1. No area overlaps
        // 2. All contacts have connections
        // 3. All pieces connected (graph connectivity)
        return !hasInvalidAreaOverlaps() && 
               !hasUnexplainedContacts() && 
               isConnected()
    }
    
    
    
    func isConnected() -> Bool {
        guard !pieceTypes.isEmpty else { return true }
        
        var visited = Set<String>()
        var queue = [Array(pieceTypes.keys).first!]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if visited.contains(current) { continue }
            
            visited.insert(current)
            
            let connections = getConnections(for: current)
            for connection in connections {
                let other = connection.type.pieceAId == current ? 
                           connection.type.pieceBId : connection.type.pieceAId
                if !visited.contains(other) {
                    queue.append(other)
                }
            }
        }
        
        return visited.count == pieceTypes.count
    }
    
    // MARK: - Semantic Validation Helpers
    
    /// Get the connection between two specific pieces, if one exists
    func connectionBetween(_ pieceA: String, _ pieceB: String) -> Connection? {
        return connections.first { connection in
            let connectedPieces = Set([connection.type.pieceAId, connection.type.pieceBId])
            return connectedPieces == Set([pieceA, pieceB])
        }
    }
    
    /// Check if a geometric overlap between two pieces is explained by a declared connection
    func isOverlapExplainedByConnection(_ pieceA: String, _ pieceB: String) -> Bool {
        // First check if pieces are actually touching/overlapping
        let relationship = getGeometricRelationship(pieceA, pieceB)
        if relationship == .noContact {
            return true // No overlap to explain
        }
        
        guard let connection = connectionBetween(pieceA, pieceB) else { 
            return false // Overlap exists but no connection to explain it
        }
        
        // Connection exists, verify it's geometrically satisfied
        guard let typeA = pieceTypes[pieceA],
              let typeB = pieceTypes[pieceB],
              let transformA = localPieceTransforms[pieceA],
              let transformB = localPieceTransforms[pieceB] else { 
            return false 
        }
        
        let verticesA = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeA),
            with: transformA
        )
        let verticesB = GeometryEngine.transformVertices(
            TangramPieceGeometry.vertices(for: typeB),
            with: transformB
        )
        
        let tolerance: CGFloat = 1e-5
        
        switch connection.type {
        case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
            // Determine which piece is A and which is B in the connection
            let (actualVertexA, actualVertexB) = if pieceAId == pieceA {
                (vertexA, vertexB)
            } else {
                (vertexB, vertexA)
            }
            
            // Check that the specified vertices actually coincide
            guard actualVertexA < verticesA.count && actualVertexB < verticesB.count else {
                return false
            }
            
            let pointA = verticesA[actualVertexA]
            let pointB = verticesB[actualVertexB]
            return GeometryEngine.pointsEqual(pointA, pointB, tolerance: tolerance)
            
        case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
            // Determine which piece is A and which is B in the connection
            let (actualEdgeA, actualEdgeB) = if pieceAId == pieceA {
                (edgeA, edgeB)
            } else {
                (edgeB, edgeA)
            }
            
            // Get edges from TangramPieceGeometry edge definitions
            let edgesA = TangramPieceGeometry.edges(for: typeA)
            let edgesB = TangramPieceGeometry.edges(for: typeB)
            
            guard actualEdgeA < edgesA.count && actualEdgeB < edgesB.count else {
                return false
            }
            
            let edgeDefA = edgesA[actualEdgeA]
            let edgeDefB = edgesB[actualEdgeB]
            
            let edgeStartA = verticesA[edgeDefA.startVertex]
            let edgeEndA = verticesA[edgeDefA.endVertex]
            let edgeStartB = verticesB[edgeDefB.startVertex]
            let edgeEndB = verticesB[edgeDefB.endVertex]
            
            let edgeA = (edgeStartA, edgeEndA)
            let edgeB = (edgeStartB, edgeEndB)
            
            // Check if edges coincide (same length) or partially coincide (different lengths)
            if GeometryEngine.edgesCoincide(edgeA, edgeB, tolerance: tolerance) {
                return true
            }
            
            // Check if the shorter edge lies along the longer edge
            let lengthA = GeometryEngine.distance(from: edgeStartA, to: edgeEndA)
            let lengthB = GeometryEngine.distance(from: edgeStartB, to: edgeEndB)
            
            if lengthA > lengthB {
                return GeometryEngine.edgePartiallyCoincides(shorterEdge: edgeB, longerEdge: edgeA, tolerance: tolerance)
            } else {
                return GeometryEngine.edgePartiallyCoincides(shorterEdge: edgeA, longerEdge: edgeB, tolerance: tolerance)
            }
        }
    }
    
}