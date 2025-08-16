//
//  TangramValidationEngine+OrientationFeedback.swift
//  Bemo
//
//  Orientation-only feedback when no anchor mapping is established
//

import Foundation
import CoreGraphics

extension TangramValidationEngine {
	func computeOrientationOnlyFeedback(
		observations: [PieceObservation],
		puzzle: GamePuzzleData,
		options: ValidationOptions,
		currentPieceStates: [String: PieceValidationState]
	) -> (orientedTargets: Set<String>, pieceNudges: [String: NudgeContent]) {
		var orientedTargets: Set<String> = []
		var pieceNudges: [String: NudgeContent] = [:]

		for obs in observations {
			let candidates = puzzle.targetPieces.filter { $0.pieceType == obs.pieceType }
			guard !candidates.isEmpty else { continue }

			let pieceFeature = TangramGeometryHelpers.pieceFeatureAngle(
				rotation: obs.rotation,
				pieceType: obs.pieceType,
				isFlipped: obs.isFlipped
			)

			var best: (id: String, rotDeg: CGFloat, targetFeature: CGFloat, targetIsFlipped: Bool)?
			for t in candidates {
				let targetFeature = TangramGeometryHelpers.targetFeatureAngle(
					transform: t.transform,
					pieceType: obs.pieceType
				)
				let symDiff = TangramRotationValidator.rotationDifferenceToNearest(
					currentRotation: pieceFeature,
					targetRotation: targetFeature,
					pieceType: obs.pieceType,
					isFlipped: obs.isFlipped
				)
				let delta = abs(symDiff) * 180 / .pi
				let targFlipped = TangramGeometryHelpers.isTransformFlipped(t.transform)
				if best == nil || delta < best!.rotDeg {
					best = (t.id, delta, targetFeature, targFlipped)
				}
			}
			guard let picked = best else { continue }
			let flipOK = (obs.pieceType != .parallelogram) || (obs.isFlipped != picked.targetIsFlipped)

			let rotOK = TangramRotationValidator.isRotationValid(
				currentRotation: pieceFeature,
				targetRotation: picked.targetFeature,
				pieceType: obs.pieceType,
				isFlipped: obs.isFlipped,
				toleranceDegrees: options.orientationToleranceDeg
			)
			if rotOK && flipOK {
				orientedTargets.insert(picked.id)
				if currentPieceStates[obs.pieceId]?.isValid != true {
					pieceNudges[obs.pieceId] = NudgeContent(level: .gentle, message: "✅ Good job!", visualHint: .pulse(intensity: 0.4), duration: 1.2)
				}
			} else if obs.pieceType == .parallelogram && !flipOK {
				pieceNudges[obs.pieceId] = NudgeContent(level: .specific, message: "🔁 Try flipping", visualHint: .flipDemo, duration: 2.0)
			} else if picked.rotDeg > options.orientationToleranceDeg && picked.rotDeg < options.rotationNudgeUpperDeg {
				let raw = TangramPoseMapper.rawAngle(from: puzzle.targetPieces.first { $0.id == picked.id }?.transform ?? .identity)
				let targetExpectedZ = TangramPoseMapper.spriteKitAngle(fromRawAngle: raw)
				let canonicalTarget = TangramGeometryHelpers.canonicalTargetAngle(for: obs.pieceType)
				let canonicalPiece = TangramGeometryHelpers.canonicalPieceAngle(for: obs.pieceType)
				let signAdjustedCanonicalPiece: CGFloat = obs.isFlipped ? -canonicalPiece : canonicalPiece
				let desiredNodeZ = TangramRotationValidator.normalizeAngle(targetExpectedZ + canonicalTarget - signAdjustedCanonicalPiece)
				pieceNudges[obs.pieceId] = NudgeContent(
					level: .specific,
					message: "🔄 Try rotating",
					visualHint: .rotationDemo(current: obs.rotation, target: desiredNodeZ),
					duration: 2.0
				)
			}
		}

		return (orientedTargets, pieceNudges)
	}
}


