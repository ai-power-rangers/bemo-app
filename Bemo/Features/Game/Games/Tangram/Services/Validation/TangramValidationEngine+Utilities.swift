//
//  TangramValidationEngine+Utilities.swift
//  Bemo
//
//  Small helpers for the validation engine
//

import Foundation
import CoreGraphics

extension TangramValidationEngine {
	func poseHash(for group: ConstructionGroup, from frame: [PieceObservation]) -> Int {
		var acc: UInt64 = 1469598103934665603 // FNV-1a offset basis
		for pid in group.pieces.sorted() {
			guard let obs = frame.first(where: { $0.pieceId == pid }) else { continue }
			let qx = Int(obs.position.x.rounded())
			let qy = Int(obs.position.y.rounded())
			let qd = Int((obs.rotation * 180 / .pi).rounded())
			let s = "\(pid)|\(qx)|\(qy)|\(qd)"
			for b in s.utf8 {
				acc ^= UInt64(b)
				acc = acc &* 1099511628211
			}
		}
		return Int(truncatingIfNeeded: acc)
	}

	func createPuzzlePieceNode(from observation: PieceObservation) -> PuzzlePieceNode {
		let node = PuzzlePieceNode(pieceType: observation.pieceType)
		node.name = observation.pieceId
		node.position = observation.position
		node.zRotation = observation.rotation
		node.isFlipped = observation.isFlipped
		return node
	}
}


