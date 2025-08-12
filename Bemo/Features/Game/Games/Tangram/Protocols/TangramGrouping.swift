//
//  TangramGrouping.swift
//  Bemo
//
//  WHAT: Protocols to allow grouping/mapping over generic piece types (SK nodes or CV pieces)
//  ARCHITECTURE: Protocol-oriented; adapters can conform without leaking UI types into services
//

import CoreGraphics

protocol GroupablePiece {
    var id: String { get }
    var position: CGPoint { get }
    var rotation: CGFloat { get }   // SpriteKit-style radians (CW positive)
    var isFlipped: Bool { get }
}


