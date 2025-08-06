//
//  ConnectionData.swift
//  Bemo
//
//  Pure data model for connections between tangram pieces
//

import Foundation

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
    
    var pieceAId: String { type.pieceAId }
    var pieceBId: String { type.pieceBId }
    
    func involvesPiece(_ pieceId: String) -> Bool {
        return pieceAId == pieceId || pieceBId == pieceId
    }
}