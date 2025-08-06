//
//  ValidationService.swift
//  Bemo
//
//  Validation logic for tangram puzzle assemblies
//

import Foundation
import CoreGraphics

class ValidationService {
    
    // MARK: - Geometric Relationships
    
    enum GeometricRelationship {
        case areaOverlap    // Interior intersection - ALWAYS INVALID
        case edgeContact    // Sharing edge - needs connection
        case vertexContact  // Touching at point - needs connection
        case noContact      // Not touching - breaks connectivity
    }
    
    // MARK: - Layer 1: Pure Geometric Detection
    
    /// Check if two pieces have interior area overlap (always invalid)
    func hasAreaOverlap(pieceA: TangramPiece, pieceB: TangramPiece) -> Bool {
        let verticesA = getTransformedVertices(for: pieceA)
        let verticesB = getTransformedVertices(for: pieceB)
        
        return GeometryEngine.polygonsOverlap(verticesA, verticesB)
    }
    
    /// Check if two pieces share an edge or part of an edge
    func hasEdgeContact(pieceA: TangramPiece, pieceB: TangramPiece) -> Bool {
        let verticesA = getTransformedVertices(for: pieceA)
        let verticesB = getTransformedVertices(for: pieceB)
        
        return !GeometryEngine.sharedEdges(verticesA, verticesB).isEmpty
    }
    
    /// Check if two pieces touch at exactly one vertex
    func hasVertexContact(pieceA: TangramPiece, pieceB: TangramPiece) -> Bool {
        let verticesA = getTransformedVertices(for: pieceA)
        let verticesB = getTransformedVertices(for: pieceB)
        
        return !GeometryEngine.sharedVertices(verticesA, verticesB).isEmpty
    }
    
    /// Get the geometric relationship between two pieces
    func getGeometricRelationship(pieceA: TangramPiece, pieceB: TangramPiece) -> GeometricRelationship {
        // Check in priority order
        if hasAreaOverlap(pieceA: pieceA, pieceB: pieceB) {
            return .areaOverlap
        } else if hasVertexContact(pieceA: pieceA, pieceB: pieceB) {
            return .vertexContact
        } else if hasEdgeContact(pieceA: pieceA, pieceB: pieceB) {
            return .edgeContact
        } else {
            return .noContact
        }
    }
    
    // MARK: - Layer 2: Semantic Validation
    
    /// Check if any pieces in the collection have area overlap
    func hasInvalidAreaOverlaps(pieces: [TangramPiece]) -> Bool {
        for i in 0..<pieces.count {
            for j in (i+1)..<pieces.count {
                if hasAreaOverlap(pieceA: pieces[i], pieceB: pieces[j]) {
                    return true
                }
            }
        }
        return false
    }
    
    /// Check if any pieces touch without a connection (only edge contacts need connections)
    func hasUnexplainedContacts(pieces: [TangramPiece], connections: [Connection]) -> Bool {
        for i in 0..<pieces.count {
            for j in (i+1)..<pieces.count {
                let relationship = getGeometricRelationship(pieceA: pieces[i], pieceB: pieces[j])
                
                switch relationship {
                case .edgeContact:
                    // Edge contact REQUIRES a connection
                    let hasConnection = connections.contains { connection in
                        let ids = [connection.pieceAId, connection.pieceBId]
                        return ids.contains(pieces[i].id) && ids.contains(pieces[j].id)
                    }
                    
                    if !hasConnection {
                        return true // Edge touching without connection is invalid
                    }
                    
                case .vertexContact:
                    // Vertex contact is ALWAYS valid, with or without connection
                    continue
                    
                case .areaOverlap, .noContact:
                    continue
                }
            }
        }
        return false
    }
    
    /// Check if all pieces form a connected graph through connections or vertex contacts
    func isConnected(pieces: [TangramPiece], connections: [Connection]) -> Bool {
        guard !pieces.isEmpty else { return true }
        
        var visited = Set<String>()
        var queue = [pieces[0].id]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if visited.contains(current) { continue }
            
            visited.insert(current)
            
            // Find the current piece
            guard let currentPiece = pieces.first(where: { $0.id == current }) else { continue }
            
            // Find all pieces connected to current through explicit connections
            for connection in connections {
                let other: String?
                if connection.pieceAId == current {
                    other = connection.pieceBId
                } else if connection.pieceBId == current {
                    other = connection.pieceAId
                } else {
                    continue
                }
                
                if let other = other, !visited.contains(other) {
                    queue.append(other)
                }
            }
            
            // Also find pieces connected through vertex contact (implicit connections)
            for piece in pieces {
                if piece.id != current && !visited.contains(piece.id) {
                    let relationship = getGeometricRelationship(pieceA: currentPiece, pieceB: piece)
                    if relationship == .vertexContact || relationship == .edgeContact {
                        queue.append(piece.id)
                    }
                }
            }
        }
        
        return visited.count == pieces.count
    }
    
    /// Main validation method - checks if the tangram assembly is valid
    func isValidAssembly(pieces: [TangramPiece], connections: [Connection]) -> Bool {
        return !hasInvalidAreaOverlaps(pieces: pieces) &&
               !hasUnexplainedContacts(pieces: pieces, connections: connections) &&
               isConnected(pieces: pieces, connections: connections)
    }
    
    // MARK: - Helpers
    
    private func getTransformedVertices(for piece: TangramPiece) -> [CGPoint] {
        let baseVertices = TangramGeometry.vertices(for: piece.type)
        // Apply the visual scale factor
        let scaledVertices = baseVertices.map { CGPoint(x: $0.x * TangramConstants.visualScale, y: $0.y * TangramConstants.visualScale) }
        return GeometryEngine.transformVertices(scaledVertices, with: piece.transform)
    }
}