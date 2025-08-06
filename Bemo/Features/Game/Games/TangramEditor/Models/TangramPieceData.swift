//
//  TangramPieceData.swift
//  Bemo
//
//  Pure data model for tangram pieces
//

import Foundation
import CoreGraphics

// Simple data structure to track connections on a piece
struct ConnectionData: Codable, Equatable {
    let otherPieceId: String
    let type: ConnectionType
}

struct TangramPiece: Identifiable, Equatable {
    let id: String
    let type: PieceType
    var transform: CGAffineTransform
    var isLocked: Bool
    var zIndex: Int
    var connectionPoints: [ConnectionData]  // Track active connections
    
    init(type: PieceType, transform: CGAffineTransform = .identity, isLocked: Bool = true) {
        self.id = UUID().uuidString
        self.type = type
        self.transform = transform
        self.isLocked = isLocked  // Default to locked
        self.zIndex = 0
        self.connectionPoints = []
    }
    
    // MARK: - Equatable
    static func == (lhs: TangramPiece, rhs: TangramPiece) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.transform == rhs.transform &&
               lhs.isLocked == rhs.isLocked &&
               lhs.zIndex == rhs.zIndex &&
               lhs.connectionPoints == rhs.connectionPoints
    }
}

// MARK: - Codable conformance with CGAffineTransform support
extension TangramPiece: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case transform
        case isLocked
        case zIndex
        case connectionPoints
    }
    
    // Custom encoding to handle CGAffineTransform
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(TransformData(transform: transform), forKey: .transform)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(connectionPoints, forKey: .connectionPoints)
    }
    
    // Custom decoding to handle CGAffineTransform
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(PieceType.self, forKey: .type)
        let transformData = try container.decode(TransformData.self, forKey: .transform)
        transform = transformData.toCGAffineTransform()
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        connectionPoints = try container.decode([ConnectionData].self, forKey: .connectionPoints)
    }
}

// Helper struct to make CGAffineTransform codable
private struct TransformData: Codable {
    let a: CGFloat
    let b: CGFloat
    let c: CGFloat
    let d: CGFloat
    let tx: CGFloat
    let ty: CGFloat
    
    init(transform: CGAffineTransform) {
        self.a = transform.a
        self.b = transform.b
        self.c = transform.c
        self.d = transform.d
        self.tx = transform.tx
        self.ty = transform.ty
    }
    
    func toCGAffineTransform() -> CGAffineTransform {
        return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
}