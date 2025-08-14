//
//  TangramValidationEngine.swift
//  Bemo
//
//  Unified validation, hints, and nudges engine for Tangram game
//

// WHAT: Single source of truth for validation, mapping, hints, and nudges with CV integration
// ARCHITECTURE: Service in MVVM-S, wraps all validation subsystems into one coherent API
// USAGE: Call process() with CV observations, get back validation results with hints/nudges

import Foundation
import QuartzCore
import CoreGraphics

/// Unified engine for all Tangram validation, hints, and nudges
class TangramValidationEngine {
    
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
        
        static let `default` = ValidationOptions(
            validateOnMove: true,
            enableNudges: true,
            enableHints: true,
            nudgeCooldown: 3.0,
            dwellValidateInterval: 1.0,
            orientationToleranceDeg: 5.0,
            rotationNudgeUpperDeg: 45.0
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
    
    // MARK: - Dependencies
    
    private let groupManager: ConstructionGroupManager
    private let mappingService: TangramRelativeMappingService
    private let validator: TangramPieceValidator
    private let nudgeManager: SmartNudgeManager
    private let hintEngine: TangramHintEngine
    private let optimizationValidator: OptimizationValidator
    private var currentDifficulty: UserPreferences.DifficultySetting
    
    // MARK: - State
    
    private var validatedTargets: Set<String> = []
    private var pieceBindings: [String: String] = [:] // pieceId -> targetId
    private var lastValidationTime: TimeInterval = 0
    private var pieceAttempts: [String: Int] = [:]
    private var lastObservedPose: [String: (pos: CGPoint, rot: CGFloat)] = [:]
    private var groupRunState: [UUID: (lastRunAt: TimeInterval, poseHash: Int)] = [:]
    
    // MARK: - Initialization
    
    init(difficulty: UserPreferences.DifficultySetting = .normal) {
        self.groupManager = ConstructionGroupManager()
        self.mappingService = TangramRelativeMappingService()
        
        // Get tolerances from unified source
        let tolerances = TangramGameConstants.Validation.tolerances(for: difficulty)
        self.validator = TangramPieceValidator(
            positionTolerance: tolerances.position,
            rotationTolerance: tolerances.rotationDeg,
            edgeContactTolerance: tolerances.edgeContact
        )
        
        self.nudgeManager = SmartNudgeManager()
        self.hintEngine = TangramHintEngine()
        self.optimizationValidator = OptimizationValidator(difficulty: difficulty)
        self.currentDifficulty = difficulty
    }
    
    // MARK: - Main Processing
    
    /// Process CV frame and return validation results with hints/nudges
    func process(
        frame: [PieceObservation],
        puzzle: GamePuzzleData,
        difficulty: UserPreferences.DifficultySetting,
        options: ValidationOptions = .default
    ) -> ValidationResult {
        
        // Filter observations to significant pose deltas (only track pieces once moved)
        let significant: [PieceObservation] = frame.filter { obs in
            if let last = lastObservedPose[obs.pieceId] {
                let dp = hypot(obs.position.x - last.pos.x, obs.position.y - last.pos.y)
                let dr = abs(TangramRotationValidator.normalizeAngle(obs.rotation - last.rot))
                if dp < 2.0 && dr < (3.0 * .pi / 180.0) { return false }
            }
            return true
        }
        // Update pose cache for all observations
        for obs in frame { lastObservedPose[obs.pieceId] = (obs.position, obs.rotation) }
        // SIMPLE ORIENTATION-ONLY MODE
        var orientedTargets: Set<String> = []
        let pieceStates: [String: PieceValidationState] = [:]
        var nudge: (targetId: String, content: NudgeContent)? = nil
        var pieceNudges: [String: NudgeContent] = [:]
        
        for obs in significant {
            // Candidates by type
            let candidates = puzzle.targetPieces.filter { $0.pieceType == obs.pieceType }
            guard !candidates.isEmpty else { continue }
            
            // Compute piece feature angle (no mapping, rotation-only)
            let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
            let pieceFeature = TangramRotationValidator.normalizeAngle(
                obs.rotation + (obs.isFlipped ? -canonicalPiece : canonicalPiece)
            )
            
            // Pick best target by minimal rotation delta with symmetry awareness (square: 4-fold, etc.)
            var best: (id: String, rotDeg: CGFloat, targetFeature: CGFloat, targetIsFlipped: Bool)?
            for t in candidates {
                let raw = TangramPoseMapper.rawAngle(from: t.transform)
                let targRot = TangramPoseMapper.spriteKitAngle(fromRawAngle: raw)
                let canonicalTarget: CGFloat = obs.pieceType.isTriangle ? (.pi / 4) : 0
                let targetFeature = TangramRotationValidator.normalizeAngle(targRot + canonicalTarget)
                let symDiff = TangramRotationValidator.rotationDifferenceToNearest(
                    currentRotation: pieceFeature,
                    targetRotation: targetFeature,
                    pieceType: obs.pieceType,
                    isFlipped: obs.isFlipped
                )
                let delta = abs(symDiff) * 180 / .pi
                let det = t.transform.a * t.transform.d - t.transform.b * t.transform.c
                let targFlipped = det < 0
                if best == nil || delta < best!.rotDeg {
                    best = (t.id, delta, targetFeature, targFlipped)
                }
            }
            guard let picked = best else { continue }
            let flipOK = (obs.pieceType != .parallelogram) || (obs.isFlipped != picked.targetIsFlipped)
            
            // Log minimal info per moved piece
            #if DEBUG
            let pieceDeg = obs.rotation * 180 / .pi
            let targDeg = picked.targetFeature * 180 / .pi
            print("[ORIENT] piece=\(obs.pieceId) type=\(obs.pieceType.rawValue) pieceRot=\(Int(pieceDeg))° targetRot=\(Int(targDeg))° delta=\(Int(picked.rotDeg))° flipOk=\(flipOK) target=\(picked.id)")
            #endif
            
            // 40% display in future on silhouette; for now we only use it to decide nudges
            let rotOK = TangramRotationValidator.isRotationValid(
                currentRotation: pieceFeature,
                targetRotation: picked.targetFeature,
                pieceType: obs.pieceType,
                isFlipped: obs.isFlipped,
                toleranceDegrees: options.orientationToleranceDeg
            )
            if rotOK && flipOK {
                orientedTargets.insert(picked.id)
                // Piece-focused positive reinforcement (engine as single producer)
                pieceNudges[obs.pieceId] = NudgeContent(level: .gentle, message: "✅ Good job!", visualHint: .pulse(intensity: 0.4), duration: 1.2)
            } else if obs.pieceType == .parallelogram && !flipOK {
                pieceNudges[obs.pieceId] = NudgeContent(level: .specific, message: "🔁 Try flipping", visualHint: .flipDemo, duration: 2.0)
                #if DEBUG
                print("[NUDGE] flip piece=\(obs.pieceId) target=\(picked.id)")
                #endif
            } else if picked.rotDeg > options.orientationToleranceDeg && picked.rotDeg < options.rotationNudgeUpperDeg {
                // Direction to rotate: sign of angle difference
                let signed = TangramRotationValidator.rotationDifferenceToNearest(
                    currentRotation: pieceFeature,
                    targetRotation: picked.targetFeature,
                    pieceType: obs.pieceType,
                    isFlipped: obs.isFlipped
                )
                let direction = signed >= 0 ? 1.0 : -1.0
                pieceNudges[obs.pieceId] = NudgeContent(level: .specific, message: "🔄 Try rotating", visualHint: .arrow(direction: CGFloat(direction)), duration: 2.0)
                #if DEBUG
                print("[NUDGE] rotate piece=\(obs.pieceId) delta=\(Int(picked.rotDeg))° target=\(picked.id)")
                #endif
            }
        }
        
        // Update lastValidationTime when anything processed
        if !significant.isEmpty { lastValidationTime = CACurrentMediaTime() }
        
        return ValidationResult(
            validatedTargets: validatedTargets,
            pieceStates: pieceStates,
            bindings: pieceBindings,
            nudgeContent: nudge,
            pieceNudges: pieceNudges,
            groupMappings: [:],
            failureReasons: [:],
            orientedTargets: orientedTargets
        )
    }
    
    /// Request a hint based on current context
    func requestHint(puzzle: GamePuzzleData, context: HintContext) -> TangramHintEngine.HintData? {
        // Ensure hint engine has current difficulty
        hintEngine.setDifficulty(currentDifficulty)
        
        // Use validated targets from engine state
        let hint = hintEngine.determineNextHint(
            puzzle: puzzle,
            placedPieces: context.placedPieces,
            lastMovedPiece: context.lastMovedPiece,
            timeSinceLastProgress: context.timeSinceLastProgress,
            previousHints: context.previousHints,
            validatedTargetIds: validatedTargets,
            difficultySetting: currentDifficulty
        )
        
        return hint
    }
    
    // MARK: - Mapping with Service
    
    private func establishOptimizedMapping(
        for group: ConstructionGroup,
        pieces: [PieceObservation],
        puzzle: GamePuzzleData,
        difficulty: UserPreferences.DifficultySetting
    ) -> AnchorMapping? {
        
        // Convert observations to mapping service format
        let mappingPieces = pieces.map { obs in
            (id: obs.pieceId,
             type: obs.pieceType,
             pos: obs.position,
             rot: obs.rotation,
             isFlipped: obs.isFlipped)
        }
        
        // Use mapping service's optimized method
        return mappingService.establishOrUpdateMappingOptimized(
            groupId: group.id,
            pieces: mappingPieces,
            candidateTargets: puzzle.targetPieces.filter { 
                !validatedTargets.contains($0.id) 
            },
            difficulty: difficulty
        )
    }
    
    // MARK: - Validation
    
    private func validateMappedPiece(
        observation: PieceObservation,
        mapping: AnchorMapping,
        anchorPosition: CGPoint,
        puzzle: GamePuzzleData,
        difficulty: UserPreferences.DifficultySetting
    ) -> PieceValidationState {
        // Build candidate targets by type
        let candidateTargets: [GamePuzzleData.TargetPiece] = puzzle.targetPieces.filter { target in
            target.pieceType == observation.pieceType && !validatedTargets.contains(target.id)
        }

        // Map the observed piece pose into target (SK) space using the group's mapping
        let mapped = mappingService.mapPieceToTargetSpace(
            piecePositionScene: observation.position,
            pieceRotation: observation.rotation,
            pieceIsFlipped: observation.isFlipped,
            mapping: mapping,
            anchorPositionScene: anchorPosition
        )

        // Precompute piece feature angle using mapped rotation and mapped flip
        let canonicalPiece: CGFloat = observation.pieceType.isTriangle ? (3 * .pi / 4) : 0
        let pieceFeatureAngle = TangramRotationValidator.normalizeAngle(
            mapped.rotationSK + (mapped.isFlipped ? -canonicalPiece : canonicalPiece)
        )

        var bestTargetId: String?
        var bestValid: Bool = false
        var bestConfidence: CGFloat = 0
        var bestTransform: CGAffineTransform?
        var bestCost: CGFloat = .infinity

        for target in candidateTargets {
            // Target centroid and rotation in SK space
            let targetPoly = TangramBounds.computeSKTransformedVertices(for: target)
            let targetCentroid = CGPoint(
                x: targetPoly.map { $0.x }.reduce(0, +) / CGFloat(max(1, targetPoly.count)),
                y: targetPoly.map { $0.y }.reduce(0, +) / CGFloat(max(1, targetPoly.count))
            )
            let targetRawAngle = TangramPoseMapper.rawAngle(from: target.transform)
            let targetRotationSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: targetRawAngle)
            let canonicalTarget: CGFloat = observation.pieceType.isTriangle ? (.pi / 4) : 0
            let targetFeatureAngle = TangramRotationValidator.normalizeAngle(targetRotationSK + canonicalTarget)

            // Validate using mapped piece pose vs target centroid and feature angles
            let resultTuple = validator.validateForSpriteKitWithFeatures(
                piecePosition: mapped.positionSK,
                pieceFeatureAngle: pieceFeatureAngle,
                targetFeatureAngle: targetFeatureAngle,
                pieceType: observation.pieceType,
                isFlipped: mapped.isFlipped,
                targetTransform: target.transform,
                targetWorldPos: targetCentroid
            )

            // Confidence based on residuals in mapped space
            let posDist = hypot(mapped.positionSK.x - targetCentroid.x, mapped.positionSK.y - targetCentroid.y)
            let rotDiff = angleDifference(pieceFeatureAngle, targetFeatureAngle)
            let posConf = max(0, 1 - posDist / 100)
            let rotConf = max(0, 1 - abs(rotDiff) / .pi)
            let conf = (posConf + rotConf) / 2

            // Combine into a cost (lower is better)
            let tolerances = TangramGameConstants.Validation.tolerances(for: difficulty)
            let cost = posDist / max(1, tolerances.position) + (abs(rotDiff) / max(0.0001, tolerances.rotationDeg * .pi / 180))

            let isValid = resultTuple.positionValid && resultTuple.rotationValid && resultTuple.flipValid
            if isValid {
                if cost < bestCost {
                    bestCost = cost
                    bestValid = true
                    bestConfidence = conf
                    bestTargetId = target.id
                    bestTransform = target.transform
                }
            } else if !bestValid {
                // Track best non-valid for potential feedback
                if cost < bestCost {
                    bestCost = cost
                    bestConfidence = conf
                    bestTargetId = target.id
                    bestTransform = target.transform
                }
            }
        }

        return PieceValidationState(
            pieceId: observation.pieceId,
            isValid: bestValid,
            confidence: bestConfidence,
            targetId: bestValid ? bestTargetId : nil,
            optimalTransform: bestTransform
        )
    }
    
    
    // MARK: - Failure Analysis
    
    private func determineFailureReason(
        observation: PieceObservation,
        targetId: String?,
        mapping: AnchorMapping?,
        anchorPosition: CGPoint,
        puzzle: GamePuzzleData
    ) -> ValidationFailure {
        // Ensure we have a mapped pose when mapping is available
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

        // Build candidate targets (same type)
        let candidates = puzzle.targetPieces.filter { $0.pieceType == observation.pieceType }

        // Resolve concrete target to analyze, preferring provided targetId if valid
        let targetToUse: GamePuzzleData.TargetPiece? = {
            if let tid = targetId, let t = candidates.first(where: { $0.id == tid }) { return t }
            // Pick the closest by combined cost in mapped space
            var best: (GamePuzzleData.TargetPiece, CGFloat)?
            for t in candidates {
                // Target centroid and feature angle
                let verts = TangramBounds.computeSKTransformedVertices(for: t)
                let centroid = CGPoint(
                    x: verts.map { $0.x }.reduce(0, +) / CGFloat(max(1, verts.count)),
                    y: verts.map { $0.y }.reduce(0, +) / CGFloat(max(1, verts.count))
                )
                let raw = TangramPoseMapper.rawAngle(from: t.transform)
                let targRot = TangramPoseMapper.spriteKitAngle(fromRawAngle: raw)
                let canonicalTarget: CGFloat = observation.pieceType.isTriangle ? (.pi / 4) : 0
                let targetFeature = TangramRotationValidator.normalizeAngle(targRot + canonicalTarget)

                let canonicalPiece: CGFloat = observation.pieceType.isTriangle ? (3 * .pi / 4) : 0
                let pieceFeature = TangramRotationValidator.normalizeAngle(
                    mapped.rot + (mapped.flip ? -canonicalPiece : canonicalPiece)
                )
                let posDist = hypot(mapped.pos.x - centroid.x, mapped.pos.y - centroid.y)
                let rotDiff = abs(angleDifference(pieceFeature, targetFeature))
                let cost = posDist + rotDiff * 180 / .pi
                if best == nil || cost < best!.1 { best = (t, cost) }
            }
            return best?.0
        }()

        guard let target = targetToUse else { return .wrongPiece }

        // Compute centroid for chosen target
        let targetPoly = TangramBounds.computeSKTransformedVertices(for: target)
        let targetCentroid = CGPoint(
            x: targetPoly.map { $0.x }.reduce(0, +) / CGFloat(max(1, targetPoly.count)),
            y: targetPoly.map { $0.y }.reduce(0, +) / CGFloat(max(1, targetPoly.count))
        )

        // Use detailed validator on mapped pose to determine primary blocker
        let detailed = mappingService.validateMappedDetailed(
            mappedPose: (pos: mapped.pos, rot: mapped.rot, isFlipped: mapped.flip),
            pieceType: observation.pieceType,
            target: target,
            targetCentroidScene: targetCentroid,
            validator: validator
        )
        if !detailed.isValid, let reason = detailed.failure { return reason }

        // Fallback: infer from residuals
        let canonicalPiece: CGFloat = observation.pieceType.isTriangle ? (3 * .pi / 4) : 0
        let canonicalTarget: CGFloat = observation.pieceType.isTriangle ? (.pi / 4) : 0
        let pieceFeature = TangramRotationValidator.normalizeAngle(
            mapped.rot + (mapped.flip ? -canonicalPiece : canonicalPiece)
        )
        let targetFeature = TangramRotationValidator.normalizeAngle(
            TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform)) + canonicalTarget
        )
        let offset = hypot(mapped.pos.x - targetCentroid.x, mapped.pos.y - targetCentroid.y)
        let rotDeltaDeg = abs(angleDifference(pieceFeature, targetFeature)) * 180 / .pi
        if offset > 0 { return .wrongPosition(offset: offset) }
        if rotDeltaDeg > 0 { return .wrongRotation(degreesOff: rotDeltaDeg) }
        return .wrongPiece
    }
    
    private func angleDifference(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
        var diff = a2 - a1
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return diff
    }
    
    // MARK: - Nudge Generation
    
    private func generateNudge(
        groups: [ConstructionGroup],
        failureReasons: [String: ValidationFailure],
        pieceTargets: [String: String]
    ) -> (targetId: String, content: NudgeContent)? {
        
        // Find the piece with most attempts that's still failing
        var candidatePiece: (id: String, attempts: Int, reason: ValidationFailure)?
        
        for (pieceId, reason) in failureReasons {
            let attempts = pieceAttempts[pieceId] ?? 0
            if attempts >= 2 { // Minimum attempts before nudging
                if candidatePiece == nil || attempts > candidatePiece!.attempts {
                    candidatePiece = (pieceId, attempts, reason)
                }
            }
        }
        
        guard let piece = candidatePiece else { return nil }
        
        // Find the piece's group for confidence
        let group = groups.first { $0.pieces.contains(piece.id) }
        let confidence = group?.confidence ?? 0
        
        // Determine nudge level based on attempts and confidence
        let nudgeLevel = nudgeManager.determineNudgeLevel(
            confidence: confidence,
            attempts: piece.attempts,
            state: group?.validationState ?? .scattered
        )
        
        // Get target ID for the nudge
        guard let targetId = pieceTargets[piece.id] else { return nil }
        
        // Generate nudge content
        let content = nudgeManager.generateNudge(
            level: nudgeLevel,
            failure: piece.reason,
            targetInfo: nil // Could add target position if needed
        )
        
        return (targetId: targetId, content: content)
    }
    
    // MARK: - Helper Methods
    
    /// Quantized pose hash for a group's members to detect meaningful state changes
    private func poseHash(for group: ConstructionGroup, from frame: [PieceObservation]) -> Int {
        var acc: UInt64 = 1469598103934665603 // FNV-1a offset basis
        for pid in group.pieces.sorted() {
            guard let obs = frame.first(where: { $0.pieceId == pid }) else { continue }
            // Quantize
            let qx = Int(obs.position.x.rounded())
            let qy = Int(obs.position.y.rounded())
            let qd = Int((obs.rotation * 180 / .pi).rounded())
            let s = "\(pid)|\(qx)|\(qy)|\(qd)"
            // FNV-1a hash
            for b in s.utf8 {
                acc ^= UInt64(b)
                acc = acc &* 1099511628211
            }
        }
        return Int(truncatingIfNeeded: acc)
    }

    private func createPuzzlePieceNode(from observation: PieceObservation) -> PuzzlePieceNode {
        let node = PuzzlePieceNode(pieceType: observation.pieceType)
        node.name = observation.pieceId
        node.position = observation.position
        node.zRotation = observation.rotation
        node.isFlipped = observation.isFlipped
        return node
    }
}

