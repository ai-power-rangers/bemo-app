//
//  Connection.swift
//  Bemo
//
//  Connection definitions between tangram pieces
//

import Foundation
import CoreGraphics

struct Connection: Codable, Identifiable {
    let id: String
    let type: ConnectionType
    let constraint: Constraint
    let createdAt: Date
    
    init(type: ConnectionType, constraint: Constraint) {
        self.id = UUID().uuidString
        self.type = type
        self.constraint = constraint
        self.createdAt = Date()
    }
}

extension Connection {
    var involvedPieceIds: [String] {
        switch type {
        case .vertexToVertex(let pieceA, _, let pieceB, _),
             .edgeToEdge(let pieceA, _, let pieceB, _):
            return [pieceA, pieceB]
        }
    }
    
    func involves(pieceId: String) -> Bool {
        return involvedPieceIds.contains(pieceId)
    }
    
    var connectionDescription: String {
        switch type {
        case .vertexToVertex(_, let vertexA, _, let vertexB):
            return "Vertex \(vertexA) to Vertex \(vertexB)"
        case .edgeToEdge(_, let edgeA, _, let edgeB):
            return "Edge \(edgeA) to Edge \(edgeB)"
        }
    }
}

extension ConnectionType: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case pieceA
        case indexA
        case pieceB
        case indexB
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let pieceA = try container.decode(String.self, forKey: .pieceA)
        let indexA = try container.decode(Int.self, forKey: .indexA)
        let pieceB = try container.decode(String.self, forKey: .pieceB)
        let indexB = try container.decode(Int.self, forKey: .indexB)
        
        switch type {
        case "vertexToVertex":
            self = .vertexToVertex(pieceA: pieceA, vertexA: indexA, pieceB: pieceB, vertexB: indexB)
        case "edgeToEdge":
            self = .edgeToEdge(pieceA: pieceA, edgeA: indexA, pieceB: pieceB, edgeB: indexB)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown connection type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .vertexToVertex(let pieceA, let vertexA, let pieceB, let vertexB):
            try container.encode("vertexToVertex", forKey: .type)
            try container.encode(pieceA, forKey: .pieceA)
            try container.encode(vertexA, forKey: .indexA)
            try container.encode(pieceB, forKey: .pieceB)
            try container.encode(vertexB, forKey: .indexB)
            
        case .edgeToEdge(let pieceA, let edgeA, let pieceB, let edgeB):
            try container.encode("edgeToEdge", forKey: .type)
            try container.encode(pieceA, forKey: .pieceA)
            try container.encode(edgeA, forKey: .indexA)
            try container.encode(pieceB, forKey: .pieceB)
            try container.encode(edgeB, forKey: .indexB)
        }
    }
}

extension Constraint: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case affectedPieceId
        case centerX, centerY
        case vectorDx, vectorDy
        case rangeLower, rangeUpper
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.affectedPieceId = try container.decode(String.self, forKey: .affectedPieceId)
        
        let typeString = try container.decode(String.self, forKey: .type)
        
        switch typeString {
        case "rotation":
            let centerX = try container.decode(Double.self, forKey: .centerX)
            let centerY = try container.decode(Double.self, forKey: .centerY)
            let lower = try container.decode(Double.self, forKey: .rangeLower)
            let upper = try container.decode(Double.self, forKey: .rangeUpper)
            self.type = .rotation(
                around: CGPoint(x: centerX, y: centerY),
                range: lower...upper
            )
            
        case "translation":
            let dx = try container.decode(Double.self, forKey: .vectorDx)
            let dy = try container.decode(Double.self, forKey: .vectorDy)
            let lower = try container.decode(Double.self, forKey: .rangeLower)
            let upper = try container.decode(Double.self, forKey: .rangeUpper)
            self.type = .translation(
                along: CGVector(dx: dx, dy: dy),
                range: lower...upper
            )
            
        case "fixed":
            self.type = .fixed
            
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown constraint type: \(typeString)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(affectedPieceId, forKey: .affectedPieceId)
        
        switch type {
        case .rotation(let center, let range):
            try container.encode("rotation", forKey: .type)
            try container.encode(Double(center.x), forKey: .centerX)
            try container.encode(Double(center.y), forKey: .centerY)
            try container.encode(range.lowerBound, forKey: .rangeLower)
            try container.encode(range.upperBound, forKey: .rangeUpper)
            
        case .translation(let vector, let range):
            try container.encode("translation", forKey: .type)
            try container.encode(Double(vector.dx), forKey: .vectorDx)
            try container.encode(Double(vector.dy), forKey: .vectorDy)
            try container.encode(range.lowerBound, forKey: .rangeLower)
            try container.encode(range.upperBound, forKey: .rangeUpper)
            
        case .fixed:
            try container.encode("fixed", forKey: .type)
        }
    }
}

extension Connection {
    static func validateConnection(
        _ type: ConnectionType,
        pieceA: TangramPiece,
        pieceB: TangramPiece
    ) -> Bool {
        switch type {
        case .vertexToVertex(_, let vertexA, _, let vertexB):
            return vertexA < pieceA.vertices.count && vertexB < pieceB.vertices.count
            
        case .edgeToEdge(_, let edgeA, _, let edgeB):
            let edgesA = pieceA.edges
            let edgesB = pieceB.edges
            
            guard edgeA < edgesA.count && edgeB < edgesB.count else { return false }
            
            return GeometryEngine.edgesEqual(edgesA[edgeA].length, edgesB[edgeB].length)
        }
    }
}