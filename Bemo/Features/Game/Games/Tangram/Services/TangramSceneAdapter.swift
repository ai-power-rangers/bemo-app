//
//  TangramSceneAdapter.swift
//  Bemo
//
//  WHAT: Adapters and helpers to bridge Scene nodes to the mapping service
//

import CoreGraphics
import SpriteKit

struct ScenePieceAdapter: GroupablePiece {
    let node: PuzzlePieceNode
    var id: String { node.name ?? "" }
    var position: CGPoint { node.parent?.convert(node.position, to: node.scene!) ?? node.position }
    var rotation: CGFloat { node.zRotation }
    var isFlipped: Bool { node.isFlipped }
}


