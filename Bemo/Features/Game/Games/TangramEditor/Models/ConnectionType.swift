//
//  ConnectionType.swift
//  Bemo
//
//  Pure data model for connection types
//

import Foundation

enum ConnectionType: Codable {
    case vertexToVertex(pieceA: String, vertexA: Int, pieceB: String, vertexB: Int)
    case edgeToEdge(pieceA: String, edgeA: Int, pieceB: String, edgeB: Int)
    case vertexToEdge(pieceA: String, vertex: Int, pieceB: String, edge: Int)
    
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