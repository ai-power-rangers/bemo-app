//
//  TangramCVAdapter.swift
//  Bemo
//
//  WHAT: Adapter to treat PlacedPiece as GroupablePiece
//

import CoreGraphics

struct CVPieceAdapter: GroupablePiece {
    let piece: PlacedPiece
    var id: String { piece.id }
    var position: CGPoint { piece.position }
    var rotation: CGFloat { CGFloat(piece.rotation * .pi / 180) }
    var isFlipped: Bool { piece.isFlipped }
}


