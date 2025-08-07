//
//  ConnectionType.swift
//  Bemo
//
//  Pure data model for connection types
//

import Foundation

enum ConnectionType: Codable, Equatable {
    case vertexToVertex(pieceAId: String, vertexA: Int, pieceBId: String, vertexB: Int)
    case edgeToEdge(pieceAId: String, edgeA: Int, pieceBId: String, edgeB: Int)
    case vertexToEdge(pieceAId: String, vertex: Int, pieceBId: String, edge: Int)
    
    var pieceAId: String {
        switch self {
        case .vertexToVertex(let pieceA, _, _, _), 
             .edgeToEdge(let pieceA, _, _, _),
             .vertexToEdge(let pieceA, _, _, _):
            return pieceA
        }
    }
    
    var pieceBId: String {
        switch self {
        case .vertexToVertex(_, _, let pieceB, _), 
             .edgeToEdge(_, _, let pieceB, _),
             .vertexToEdge(_, _, let pieceB, _):
            return pieceB
        }
    }
}