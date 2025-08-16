//
//  TangramValidationEngine+Pairing.swift
//  Bemo
//
//  Pair selection and mapping helpers extracted from the engine
//

import Foundation
import CoreGraphics

extension TangramValidationEngine {

	// Select a candidate anchor pair using oriented pieces and library scoring
	func selectCandidateAnchorPair(
		from observations: [PieceObservation],
		puzzle: GamePuzzleData,
		orientationToleranceDeg: CGFloat,
		focusPieceId: String?,
		pairLibrary: TargetPairLibrary?
	) -> (pair: (PieceObservation, PieceObservation), reason: String)? {
		let oriented = pairScorer.findOrientedPieces(
			from: observations,
			puzzle: puzzle,
			orientationToleranceDeg: orientationToleranceDeg
		)
		if let best = pairScorer.selectBestPair(
			from: oriented,
			puzzle: puzzle,
			pairLibrary: pairLibrary,
			focusPieceId: focusPieceId
		) {
			return ((best.pair.0, best.pair.1), best.reason)
		}
		return nil
	}

	// Compute mapping for an observed pair against target pair using anchor mapper
	func computeMappingForPair(
		observedPair: (PieceObservation, PieceObservation),
		puzzle: GamePuzzleData,
		preferredTargetIds: (String, String)? = nil,
		pairLibrary: TargetPairLibrary?
	) -> AnchorMapping? {
		if let pref = preferredTargetIds,
		   let t0 = puzzle.targetPieces.first(where: { $0.id == pref.0 }),
		   let t1 = puzzle.targetPieces.first(where: { $0.id == pref.1 }) {
			return anchorMapper.computePairMapping(
				observedPair: (observedPair.0, observedPair.1),
				targetPair: (t0, t1)
			)
		}

		if let library = pairLibrary,
		   let match = pairScorer.findBestTargetPair(
			observedPair: (p0: observedPair.0, p1: observedPair.1),
			puzzle: puzzle,
			library: library,
			focusPieceId: nil
		   ) {
			return anchorMapper.computePairMapping(
				observedPair: (observedPair.0, observedPair.1),
				targetPair: (match.t0, match.t1)
			)
		}

		// Fallback: type-based mapping
		if let t0 = puzzle.targetPieces.first(where: { $0.pieceType == observedPair.0.pieceType }),
		   let t1 = puzzle.targetPieces.first(where: { $0.pieceType == observedPair.1.pieceType }) {
			return anchorMapper.computePairMapping(
				observedPair: (observedPair.0, observedPair.1),
				targetPair: (t0, t1)
			)
		}
		return nil
	}
}


