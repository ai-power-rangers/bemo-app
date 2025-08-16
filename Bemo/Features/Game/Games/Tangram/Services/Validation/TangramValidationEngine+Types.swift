//
//  TangramValidationEngine+Types.swift
//  Bemo
//
//  Nested types for TangramValidationEngine extracted for clarity
//

import Foundation
import CoreGraphics

extension TangramValidationEngine {

	// MARK: - Types

	struct PieceObservation {
		let pieceId: String
		let pieceType: TangramPieceType
		let position: CGPoint // In scene coordinates
		let rotation: CGFloat // In radians
		let isFlipped: Bool
		let velocity: CGVector
		let timestamp: TimeInterval
	}

	struct ValidationOptions {
		let validateOnMove: Bool
		let enableNudges: Bool
		let enableHints: Bool
		let nudgeCooldown: TimeInterval
		let dwellValidateInterval: TimeInterval
		let orientationToleranceDeg: CGFloat
		let rotationNudgeUpperDeg: CGFloat
		let focusPieceId: String?
		let settleVelocityThreshold: CGFloat

		static let `default` = ValidationOptions(
			validateOnMove: true,
			enableNudges: true,
			enableHints: true,
			nudgeCooldown: 3.0,
			dwellValidateInterval: 1.0,
			orientationToleranceDeg: 5.0,
			rotationNudgeUpperDeg: 45.0,
			focusPieceId: nil,
			settleVelocityThreshold: 12.0
		)
	}

	struct ValidationResult {
		let validatedTargets: Set<String>
		let pieceStates: [String: PieceValidationState]
		let bindings: [String: String] // pieceId -> targetId
		let nudgeContent: (targetId: String, content: NudgeContent)?
		let pieceNudges: [String: NudgeContent] // pieceId -> content
		let groupMappings: [UUID: AnchorMapping]
		let failureReasons: [String: ValidationFailure]
		let orientedTargets: Set<String> // targets that match orientation-only (50% fill)
		let anchorPieceIds: Set<String>
	}

	struct LockedValidation {
		let pieceId: String
		let targetId: String
		var lastValidPose: (pos: CGPoint, rot: CGFloat, flip: Bool)
		let lockedAt: TimeInterval
		// Dynamic hysteresis per lock (optional). If nil, fall back to global slack.
		var allowedPositionSlack: CGFloat? = nil
		var allowedRotationSlackDeg: CGFloat? = nil
	}

	struct PieceValidationState {
		let pieceId: String
		let isValid: Bool
		let confidence: CGFloat
		let targetId: String?
		let optimalTransform: CGAffineTransform?
	}

	struct HintContext {
		let validatedTargets: Set<String>
		let placedPieces: [PlacedPiece]
		let lastMovedPiece: TangramPieceType?
		let timeSinceLastProgress: TimeInterval
		let previousHints: [TangramHintEngine.HintData]
	}
}


