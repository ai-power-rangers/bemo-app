//
//  TangramValidationEngine+FailureAndNudges.swift
//  Bemo
//
//  Failure analysis and nudge generation helpers
//

import Foundation
import CoreGraphics

extension TangramValidationEngine {
	fileprivate func determineFailureReason(
		observation: PieceObservation,
		targetId: String?,
		mapping: AnchorMapping?,
		anchorPosition: CGPoint,
		puzzle: GamePuzzleData
	) -> ValidationFailure {
		let mapped: (pos: CGPoint, rot: CGFloat, flip: Bool) = {
			if let m = mapping {
				let mp = mappingService.mapPieceToTargetSpace(
					piecePositionScene: observation.position,
					pieceRotation: observation.rotation,
					pieceIsFlipped: observation.isFlipped,
					mapping: m,
					anchorPositionScene: anchorPosition
				)
				return (mp.positionSK, mp.rotationSK, mp.isFlipped)
			} else {
				return (observation.position, observation.rotation, observation.isFlipped)
			}
		}()

		let candidates = puzzle.targetPieces.filter { $0.pieceType == observation.pieceType }

		let targetToUse: GamePuzzleData.TargetPiece? = {
			if let tid = targetId, let t = candidates.first(where: { $0.id == tid }) { return t }
			var best: (GamePuzzleData.TargetPiece, CGFloat)?
			for t in candidates {
				let centroid = TangramGeometryHelpers.targetCentroid(for: t)
				let targetFeature = TangramGeometryHelpers.targetFeatureAngle(transform: t.transform, pieceType: observation.pieceType)
				let pieceFeature = TangramGeometryHelpers.pieceFeatureAngle(rotation: mapped.rot, pieceType: observation.pieceType, isFlipped: mapped.flip)
				let posDist = TangramGeometryHelpers.distance(from: mapped.pos, to: centroid)
				let rotDiff = abs(TangramGeometryHelpers.angleDifference(pieceFeature, targetFeature))
				let cost = posDist + rotDiff * 180 / .pi
				if best == nil || cost < best!.1 { best = (t, cost) }
			}
			return best?.0
		}()

		guard let target = targetToUse else { return .wrongPiece }

		let targetCentroid = TangramGeometryHelpers.targetCentroid(for: target)
		let detailed = mappingService.validateMappedDetailed(
			mappedPose: (pos: mapped.pos, rot: mapped.rot, isFlipped: mapped.flip),
			pieceType: observation.pieceType,
			target: target,
			targetCentroidScene: targetCentroid,
			validator: validator
		)
		if !detailed.isValid, let reason = detailed.failure { return reason }

		let pieceFeature = TangramGeometryHelpers.pieceFeatureAngle(rotation: mapped.rot, pieceType: observation.pieceType, isFlipped: mapped.flip)
		let targetFeature = TangramGeometryHelpers.targetFeatureAngle(transform: target.transform, pieceType: observation.pieceType)
		let offset = TangramGeometryHelpers.distance(from: mapped.pos, to: targetCentroid)
		let rotDeltaDeg = TangramGeometryHelpers.angleDifferenceDegrees(pieceFeature, targetFeature)
		if offset > 0 { return .wrongPosition(offset: offset) }
		if rotDeltaDeg > 0 { return .wrongRotation(degreesOff: rotDeltaDeg) }
		return .wrongPiece
	}

	fileprivate func generateNudge(
		groups: [ConstructionGroup],
		failureReasons: [String: ValidationFailure],
		pieceTargets: [String: String]
	) -> (targetId: String, content: NudgeContent)? {
		var candidatePiece: (id: String, attempts: Int, reason: ValidationFailure)?
		for (pieceId, reason) in failureReasons {
			let attempts = pieceAttempts[pieceId] ?? 0
			if attempts >= 2 {
				if candidatePiece == nil || attempts > candidatePiece!.attempts {
					candidatePiece = (pieceId, attempts, reason)
				}
			}
		}
		guard let piece = candidatePiece else { return nil }
		let group = groups.first { $0.pieces.contains(piece.id) }
		let confidence = group?.confidence ?? 0
		let nudgeLevel = nudgeManager.determineNudgeLevel(
			confidence: confidence,
			attempts: piece.attempts,
			state: group?.validationState ?? .scattered
		)
		guard let targetId = pieceTargets[piece.id] else { return nil }
		let content: NudgeContent = nudgeManager.generateNudge(
			level: nudgeLevel,
			failure: piece.reason,
			targetInfo: nil
		)
		return (targetId: targetId, content: content)
	}
}


