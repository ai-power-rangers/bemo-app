//
//  TangramPieceData.swift
//  Bemo
//
//  Pure data model for tangram pieces
//

import Foundation
import CoreGraphics

struct TangramPiece: Codable, Identifiable, Equatable {
    let id: String
    let type: PieceType
    var transform: CGAffineTransform
    var isLocked: Bool
    var zIndex: Int
    
    init(type: PieceType, transform: CGAffineTransform = .identity) {
        self.id = UUID().uuidString
        self.type = type
        self.transform = transform
        self.isLocked = false
        self.zIndex = 0
    }
}