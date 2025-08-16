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
    // Primary two-piece anchor group for relative-world validation
    private var mainGroupId: UUID? = nil
    private var anchorPieceIds: Set<String> = []
    // Hysteresis state for stable validations
    private var lockedValidations: [String: LockedValidation] = [:] // pieceId -> lock
    private var invalidationStartAt: [String: TimeInterval] = [:] // pieceId -> start time
    private let invalidationSlackPosition: CGFloat = 18 // px
    private let invalidationSlackRotationDeg: CGFloat = 8 // deg
    private let invalidationDwellSeconds: TimeInterval = 0.5
    
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
        // Follow plan doc: two-piece rigid mapping commit, then relative validation
        let enableAnchorMapping = true
        
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
        // Detect moving pieces (velocity-based) to freeze mapping persistence during manipulation
        let _ = frame.contains { hypot($0.velocity.dx, $0.velocity.dy) > 10.0 }
        // SIMPLE TWO-PIECE ANCHOR + ORIENTATION-ONLY FEEDBACK
        var orientedTargets: Set<String> = []
        var pieceStates: [String: PieceValidationState] = [:]
        var pieceNudges: [String: NudgeContent] = [:]
        var groupMappingsOut: [UUID: AnchorMapping] = [:]
        var failureReasons: [String: ValidationFailure] = [:]
        var anchorIds: Set<String> = []

        // Establish or maintain a two-piece anchor mapping if possible
        if enableAnchorMapping && frame.count >= 2 {
            // Consider only settled pieces for anchor selection (avoid moving pieces)
            let settled: [PieceObservation] = frame.filter { hypot($0.velocity.dx, $0.velocity.dy) <= options.settleVelocityThreshold }
            if settled.count >= 2 {
                // Map for quick lookup
                let idToObs: [String: PieceObservation] = Dictionary(uniqueKeysWithValues: settled.map { ($0.pieceId, $0) })

            // Prefer existing anchor pair if still present; otherwise choose best oriented pair (then closest)
            var candidatePair: (PieceObservation, PieceObservation)? = nil
            if anchorPieceIds.count == 2 {
                // Stabilize ordering: anchor first is the committed mapping's anchorPieceId when available
                if let gid = mainGroupId, let committed = mappingService.mapping(for: gid),
                   let obs0 = idToObs[committed.anchorPieceId],
                   let otherId = anchorPieceIds.first(where: { $0 != committed.anchorPieceId }),
                   let obs1 = idToObs[otherId ?? ""] {
                    candidatePair = (obs0, obs1)
                } else if let a = anchorPieceIds.sorted().first,
                          let b = anchorPieceIds.sorted().last,
                          let obsA = idToObs[a], let obsB = idToObs[b] {
                    candidatePair = (obsA, obsB)
                }
            }
            if candidatePair == nil {
                // Compute orientation deltas to pick a pair likely to be aligned to targets
                struct OrientInfo { let obs: PieceObservation; let bestTargetId: String; let deltaDeg: CGFloat; let flipOK: Bool }
                var oriented: [OrientInfo] = []
                for obs in settled {
                    let candidates = puzzle.targetPieces.filter { $0.pieceType == obs.pieceType }
                    guard !candidates.isEmpty else { continue }
                    let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
                    let pieceFeature = TangramRotationValidator.normalizeAngle(
                        obs.rotation + (obs.isFlipped ? -canonicalPiece : canonicalPiece)
                    )
                    var best: (id: String, deltaDeg: CGFloat, flippedOK: Bool)?
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
                        let flipOK = (obs.pieceType != .parallelogram) || (obs.isFlipped != targFlipped)
                        if best == nil || delta < best!.deltaDeg { best = (t.id, delta, flipOK) }
                    }
                    if let b = best, b.flippedOK, b.deltaDeg <= max(5, options.orientationToleranceDeg) {
                        oriented.append(OrientInfo(obs: obs, bestTargetId: b.id, deltaDeg: b.deltaDeg, flipOK: b.flippedOK))
                    }
                }
                if oriented.count >= 2 {
                    // Prefer focus-based oriented pairs first, else closest among oriented
                    if let focus = options.focusPieceId, let focusInfo = oriented.first(where: { $0.obs.pieceId == focus }) {
                        var bestPair: (PieceObservation, PieceObservation)? = nil
                        var bestDist: CGFloat = .infinity
                        for item in oriented where item.obs.pieceId != focusInfo.obs.pieceId {
                            let p = focusInfo.obs.position
                            let q = item.obs.position
                            let d = hypot(p.x - q.x, p.y - q.y)
                            if d < bestDist { bestDist = d; bestPair = (focusInfo.obs, item.obs) }
                        }
                        candidatePair = bestPair
                    }
                    if candidatePair == nil {
                        var bestPair: (PieceObservation, PieceObservation)? = nil
                        var bestDist: CGFloat = .infinity
                        for i in 0..<(oriented.count - 1) {
                            for j in (i + 1)..<oriented.count {
                                let p = oriented[i].obs.position
                                let q = oriented[j].obs.position
                                let d = hypot(p.x - q.x, p.y - q.y)
                                if d < bestDist { bestDist = d; bestPair = (oriented[i].obs, oriented[j].obs) }
                            }
                        }
                        candidatePair = bestPair
                    }
                    #if DEBUG
                    if let cp = candidatePair {
                        if let focus = options.focusPieceId, (cp.0.pieceId == focus || cp.1.pieceId == focus) {
                            print("[ANCHOR] Oriented pair selected (focus prioritized): \(cp.0.pieceId), \(cp.1.pieceId)")
                        } else {
                            print("[ANCHOR] Oriented pair selected: \(cp.0.pieceId), \(cp.1.pieceId) (closest among oriented)")
                        }
                    }
                    #endif
                }
                if candidatePair == nil {
                    // Fallback to closest pair among settled; prefer focus when provided
                    var bestPair: (PieceObservation, PieceObservation)? = nil
                    var bestDist: CGFloat = .infinity
                    if let focus = options.focusPieceId, let focusObs = settled.first(where: { $0.pieceId == focus }) {
                        for item in settled where item.pieceId != focusObs.pieceId {
                            let d = hypot(focusObs.position.x - item.position.x, focusObs.position.y - item.position.y)
                            if d < bestDist { bestDist = d; bestPair = (focusObs, item) }
                        }
                    }
                    if bestPair == nil {
                        for i in 0..<(settled.count - 1) {
                            for j in (i + 1)..<settled.count {
                                let p = settled[i].position
                                let q = settled[j].position
                                let d = hypot(p.x - q.x, p.y - q.y)
                                if d < bestDist { bestDist = d; bestPair = (settled[i], settled[j]) }
                            }
                        }
                    }
                    candidatePair = bestPair
                    #if DEBUG
                    if let cp = candidatePair {
                        print("[ANCHOR] Fallback closest pair selected: \(cp.0.pieceId), \(cp.1.pieceId)")
                    }
                    #endif
                }
            }

            if let pair = candidatePair {
                let groupId: UUID = mainGroupId ?? UUID()
                // Compute mapping using plan doc method (pair-centric centroid + relative rotation)
                if var mapping = computePairDocMapping(pair: pair, puzzle: puzzle, preferredTargetIds: nil),
                   let anchorObs = idToObs[mapping.anchorPieceId] {
                    // Validate both pieces under this mapping
                    let pairObs: [PieceObservation] = [pair.0, pair.1]
                    var localStates: [String: PieceValidationState] = [:]
                    var localValidatedTargets: Set<String> = []
                    for obs in pairObs {
                        let st = validateMappedPiece(
                            observation: obs,
                            mapping: mapping,
                            anchorPosition: anchorObs.position,
                            puzzle: puzzle,
                            difficulty: difficulty
                        )
                        localStates[obs.pieceId] = st
                        if st.isValid, let tid = st.targetId { localValidatedTargets.insert(tid) }
                    }

                    // Anchor is established if both pass strict validation, or
                    // both pass relaxed gating based on residuals (doc spirit: enable when geometry matches)
                    // Add pair-separation guard to avoid validating pieces far apart
                    let bothStrict = pairObs.allSatisfy { localStates[$0.pieceId]?.isValid == true }
                    var bothRelaxed = false
                    if !bothStrict {
                        // Compute residuals and apply relaxed thresholds
                        let tolerances = TangramGameConstants.Validation.tolerances(for: difficulty)
                        let posRelax = tolerances.position * 1.6
                        let rotRelaxDeg = tolerances.rotationDeg * 1.2
                        var okCount = 0
                        for obs in pairObs {
                            // Determine target from local state if available, else pick best by type
                            var targetId: String? = localStates[obs.pieceId]?.targetId
                            if targetId == nil {
                                targetId = puzzle.targetPieces.first(where: { $0.pieceType == obs.pieceType })?.id
                            }
                            if let tid = targetId, let target = puzzle.targetPieces.first(where: { $0.id == tid }) {
                                let mapped = mappingService.mapPieceToTargetSpace(
                                    piecePositionScene: obs.position,
                                    pieceRotation: obs.rotation,
                                    pieceIsFlipped: obs.isFlipped,
                                    mapping: mapping,
                                    anchorPositionScene: anchorObs.position
                                )
                                let verts = TangramBounds.computeSKTransformedVertices(for: target)
                                let centroid = CGPoint(
                                    x: verts.map { $0.x }.reduce(0, +) / CGFloat(max(1, verts.count)),
                                    y: verts.map { $0.y }.reduce(0, +) / CGFloat(max(1, verts.count))
                                )
                                let posDist = hypot(mapped.positionSK.x - centroid.x, mapped.positionSK.y - centroid.y)
                                let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
                                let canonicalTarget: CGFloat = obs.pieceType.isTriangle ? (.pi / 4) : 0
                                let pieceFeature = TangramRotationValidator.normalizeAngle(
                                    mapped.rotationSK + (mapped.isFlipped ? -canonicalPiece : canonicalPiece)
                                )
                                let targetFeature = TangramRotationValidator.normalizeAngle(
                                    TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform)) + canonicalTarget
                                )
                                let rotDiffDeg = abs(angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                                if posDist <= posRelax && rotDiffDeg <= rotRelaxDeg { okCount += 1 }
                            }
                        }
                        bothRelaxed = (okCount == pairObs.count)
                    }
                    // Enforce maximum distance between the two observed anchors before allowing commit
                    let maxPairSeparation: CGFloat = 140 // px in scene space; adjust per level
                    let pA = pairObs[0].position
                    let pB = pairObs[1].position
                    let pairDist = hypot(pA.x - pB.x, pA.y - pB.y)

                    if (bothStrict || bothRelaxed) && pairDist <= maxPairSeparation {
                        // Refine mapping using the actual target ids selected for the pair (avoids first-of-type skew)
                        if let t0 = localStates[pair.0.pieceId]?.targetId, let t1 = localStates[pair.1.pieceId]?.targetId {
                            if let refined = computePairDocMapping(pair: pair, puzzle: puzzle, preferredTargetIds: (t0, t1)) {
                                mapping = refined
                            }
                        }
                        // Optional: further refine using mapping service with committed pairs to minimize residuals
                        let committedPairs: [(pieceId: String, targetId: String)] = [pair.0.pieceId, pair.1.pieceId].compactMap { pid in
                            if let tid = localStates[pid]?.targetId { return (pid, tid) }
                            return nil
                        }
                        if !committedPairs.isEmpty {
                            for (pid, tid) in committedPairs {
                                mappingService.appendPair(groupId: groupId, pieceId: pid, targetId: tid)
                            }
                            if let refined = mappingService.refineMapping(
                                groupId: groupId,
                                pairs: committedPairs,
                                anchorPieceId: mapping.anchorPieceId,
                                anchorTargetId: mapping.anchorTargetId,
                                pieceScenePosProvider: { id in idToObs[id]?.position },
                                targetScenePosProvider: { tid in
                                    if let t = puzzle.targetPieces.first(where: { $0.id == tid }) {
                                        let verts = TangramBounds.computeSKTransformedVertices(for: t)
                                        let cx = verts.map { $0.x }.reduce(0, +) / CGFloat(max(1, verts.count))
                                        let cy = verts.map { $0.y }.reduce(0, +) / CGFloat(max(1, verts.count))
                                        return CGPoint(x: cx, y: cy)
                                    }
                                    return nil
                                }
                            ) {
                                mapping = refined
                            }
                        }
                        // Reuse existing mapping if very similar to avoid noisy re-commits
                        if let existing = mappingService.mapping(for: groupId) {
                            let dTheta = abs(angleDifference(existing.rotationDelta, mapping.rotationDelta)) * 180 / .pi
                            let dTrans = hypot(existing.translationOffset.dx - mapping.translationOffset.dx,
                                               existing.translationOffset.dy - mapping.translationOffset.dy)
                            let sameAnchor = (existing.anchorPieceId == mapping.anchorPieceId) && (existing.anchorTargetId == mapping.anchorTargetId)
                            if sameAnchor && dTheta <= 2.0 && dTrans <= 3.0 {
                                mainGroupId = groupId
                                anchorPieceIds = Set(pairObs.map { $0.pieceId })
                                anchorIds = anchorPieceIds
                                groupMappingsOut[groupId] = existing
                            } else {
                                mainGroupId = groupId
                                anchorPieceIds = Set(pairObs.map { $0.pieceId })
                                anchorIds = anchorPieceIds
                                var stable = mapping
                                stable.version = max(mapping.version, 2) // mark as global mapping
                                stable.pairCount = max(mapping.pairCount, 2)
                                groupMappingsOut[groupId] = stable
                                mappingService.setMapping(for: groupId, mapping: stable)
                                for (pid, st) in localStates {
                                    pieceStates[pid] = st
                                    if let tid = st.targetId {
                                        pieceBindings[pid] = tid
                                        validatedTargets.insert(tid)
                                    }
                                }
                                #if DEBUG
                                let deg = mapping.rotationDelta * 180 / .pi
                                print("[ANCHOR] Committed group=\(groupId) theta=\(Int(deg))° pieces=\(pair.0.pieceId),\(pair.1.pieceId) mode=\(bothStrict ? "strict" : "relaxed")")
                                for obs in pairObs {
                                    if let st = localStates[obs.pieceId], let tid = st.targetId,
                                       let target = puzzle.targetPieces.first(where: { $0.id == tid }) {
                                        let mapped = mappingService.mapPieceToTargetSpace(
                                            piecePositionScene: obs.position,
                                            pieceRotation: obs.rotation,
                                            pieceIsFlipped: obs.isFlipped,
                                            mapping: mapping,
                                            anchorPositionScene: anchorObs.position
                                        )
                                        let verts = TangramBounds.computeSKTransformedVertices(for: target)
                                        let centroid = CGPoint(
                                            x: verts.map { $0.x }.reduce(0, +) / CGFloat(max(1, verts.count)),
                                            y: verts.map { $0.y }.reduce(0, +) / CGFloat(max(1, verts.count))
                                        )
                                        let posDist = hypot(mapped.positionSK.x - centroid.x, mapped.positionSK.y - centroid.y)
                                        let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
                                        let canonicalTarget: CGFloat = obs.pieceType.isTriangle ? (.pi / 4) : 0
                                        let pieceFeature = TangramRotationValidator.normalizeAngle(
                                            mapped.rotationSK + (mapped.isFlipped ? -canonicalPiece : canonicalPiece)
                                        )
                                        let targetFeature = TangramRotationValidator.normalizeAngle(
                                            TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform)) + canonicalTarget
                                        )
                                        let rotDiffDeg = abs(angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                                        print("[VALIDATION-DETAIL] piece=\(obs.pieceId) target=\(tid) posDist=\(Int(posDist)) rotDiff=\(Int(rotDiffDeg))°")
                                    }
                                }
                                #endif
                            }
                        } else {
                            mainGroupId = groupId
                            anchorPieceIds = Set(pairObs.map { $0.pieceId })
                            anchorIds = anchorPieceIds
                            var stable = mapping
                            stable.version = max(mapping.version, 2)
                            stable.pairCount = max(mapping.pairCount, 2)
                            groupMappingsOut[groupId] = stable
                            mappingService.setMapping(for: groupId, mapping: stable)
                            for (pid, st) in localStates {
                                pieceStates[pid] = st
                                if let tid = st.targetId {
                                    pieceBindings[pid] = tid
                                    validatedTargets.insert(tid)
                                }
                            }
                            #if DEBUG
                            let deg = mapping.rotationDelta * 180 / .pi
                            print("[ANCHOR] Committed group=\(groupId) theta=\(Int(deg))° pieces=\(pair.0.pieceId),\(pair.1.pieceId) mode=\(bothStrict ? "strict" : "relaxed")")
                            for obs in pairObs {
                                if let st = localStates[obs.pieceId], let tid = st.targetId,
                                   let target = puzzle.targetPieces.first(where: { $0.id == tid }) {
                                    let mapped = mappingService.mapPieceToTargetSpace(
                                        piecePositionScene: obs.position,
                                        pieceRotation: obs.rotation,
                                        pieceIsFlipped: obs.isFlipped,
                                        mapping: mapping,
                                        anchorPositionScene: anchorObs.position
                                    )
                                    let verts = TangramBounds.computeSKTransformedVertices(for: target)
                                    let centroid = CGPoint(
                                        x: verts.map { $0.x }.reduce(0, +) / CGFloat(max(1, verts.count)),
                                        y: verts.map { $0.y }.reduce(0, +) / CGFloat(max(1, verts.count))
                                    )
                                    let posDist = hypot(mapped.positionSK.x - centroid.x, mapped.positionSK.y - centroid.y)
                                    let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
                                    let canonicalTarget: CGFloat = obs.pieceType.isTriangle ? (.pi / 4) : 0
                                    let pieceFeature = TangramRotationValidator.normalizeAngle(
                                        mapped.rotationSK + (mapped.isFlipped ? -canonicalPiece : canonicalPiece)
                                    )
                                    let targetFeature = TangramRotationValidator.normalizeAngle(
                                        TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform)) + canonicalTarget
                                    )
                                    let rotDiffDeg = abs(angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                                    print("[VALIDATION-DETAIL] piece=\(obs.pieceId) target=\(tid) posDist=\(Int(posDist)) rotDiff=\(Int(rotDiffDeg))°")
                                }
                            }
                            #endif
                        }
                    } else {
                        // Soft failure: keep anchor for a bit, but emit failure reasons for UI feedback
                        for obs in pairObs {
                            if localStates[obs.pieceId]?.isValid != true {
                                failureReasons[obs.pieceId] = .wrongPiece
                            }
                        }
                        #if DEBUG
                        print("[ANCHOR] Not committed — pair failed validation")
                        for obs in pairObs {
                            if let st = localStates[obs.pieceId] {
                                print("  - piece=\(obs.pieceId) valid=\(st.isValid) target=\(st.targetId ?? "nil")")
                                if let tid = st.targetId, let target = puzzle.targetPieces.first(where: { $0.id == tid }) {
                                    let mapped = mappingService.mapPieceToTargetSpace(
                                        piecePositionScene: obs.position,
                                        pieceRotation: obs.rotation,
                                        pieceIsFlipped: obs.isFlipped,
                                        mapping: mapping,
                                        anchorPositionScene: anchorObs.position
                                    )
                                    let verts = TangramBounds.computeSKTransformedVertices(for: target)
                                    let centroid = CGPoint(
                                        x: verts.map { $0.x }.reduce(0, +) / CGFloat(max(1, verts.count)),
                                        y: verts.map { $0.y }.reduce(0, +) / CGFloat(max(1, verts.count))
                                    )
                                    let posDist = hypot(mapped.positionSK.x - centroid.x, mapped.positionSK.y - centroid.y)
                                    let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
                                    let canonicalTarget: CGFloat = obs.pieceType.isTriangle ? (.pi / 4) : 0
                                    let pieceFeature = TangramRotationValidator.normalizeAngle(
                                        mapped.rotationSK + (mapped.isFlipped ? -canonicalPiece : canonicalPiece)
                                    )
                                    let targetFeature = TangramRotationValidator.normalizeAngle(
                                        TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform)) + canonicalTarget
                                    )
                                    let rotDiffDeg = abs(angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                                    print("    · residuals posDist=\(Int(posDist)) rotDiff=\(Int(rotDiffDeg))°")
                                }
                            }
                        }
                        #endif
                    }
                }
            } // settled.count >= 2
        }

        // If we have an established anchor mapping, update it from live anchors then validate relative to it
        if enableAnchorMapping, let gid = mainGroupId, var mapping = mappingService.mapping(for: gid) {
            // Recompute mapping from current anchor observations to ensure the top world follows live movement
            if anchorPieceIds.count == 2 {
                let anchors = Array(anchorPieceIds)
                if let obs0 = frame.first(where: { $0.pieceId == anchors[0] }),
                   let obs1 = frame.first(where: { $0.pieceId == anchors[1] }) {
                    // Use committed target ids for anchors if available
                    let t0 = pieceBindings[obs0.pieceId]
                    let t1 = pieceBindings[obs1.pieceId]
                    if let t0 = t0, let t1 = t1,
                       let updated = computePairDocMapping(pair: (obs0, obs1), puzzle: puzzle, preferredTargetIds: (t0, t1)) {
                        mapping = updated
                        mappingService.setMapping(for: gid, mapping: updated)
                    }
                }
            }
            // Find current anchor observation (fallback to committed anchor id)
            let anchorId = mapping.anchorPieceId
            let anchorObs: PieceObservation? = frame.first(where: { $0.pieceId == anchorId })
            if let anchorObs = anchorObs {
                for obs in frame {
                    // Evaluate all pieces including anchors for lock maintenance
                    let st = validateMappedPiece(
                        observation: obs,
                        mapping: mapping,
                        anchorPosition: anchorObs.position,
                        puzzle: puzzle,
                        difficulty: difficulty
                    )
                    pieceStates[obs.pieceId] = st
                    if let lock = lockedValidations[obs.pieceId], let target = puzzle.targetPieces.first(where: { $0.id == lock.targetId }) {
                        // Check sustained violation beyond slack
                        let mapped = mappingService.mapPieceToTargetSpace(
                            piecePositionScene: obs.position,
                            pieceRotation: obs.rotation,
                            pieceIsFlipped: obs.isFlipped,
                            mapping: mapping,
                            anchorPositionScene: anchorObs.position
                        )
                        let targetPoly = TangramBounds.computeSKTransformedVertices(for: target)
                        let centroid = CGPoint(
                            x: targetPoly.map { $0.x }.reduce(0, +) / CGFloat(max(1, targetPoly.count)),
                            y: targetPoly.map { $0.y }.reduce(0, +) / CGFloat(max(1, targetPoly.count))
                        )
                        let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
                        let pieceFeature = TangramRotationValidator.normalizeAngle(mapped.rotationSK + (mapped.isFlipped ? -canonicalPiece : canonicalPiece))
                        let targetRawAngle = TangramPoseMapper.rawAngle(from: target.transform)
                        let targetRotationSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: targetRawAngle)
                        let canonicalTarget: CGFloat = obs.pieceType.isTriangle ? (.pi / 4) : 0
                        let targetFeature = TangramRotationValidator.normalizeAngle(targetRotationSK + canonicalTarget)
                        let posDist = hypot(mapped.positionSK.x - centroid.x, mapped.positionSK.y - centroid.y)
                        let rotDiffDeg = abs(angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                        let tol = TangramGameConstants.Validation.tolerances(for: difficulty)
                        let posLimit = tol.position + invalidationSlackPosition
                        let rotLimit = tol.rotationDeg + invalidationSlackRotationDeg
                        if posDist <= posLimit && rotDiffDeg <= rotLimit {
                            // Refresh lock
                            lockedValidations[obs.pieceId]?.lastValidPose = (mapped.positionSK, mapped.rotationSK, mapped.isFlipped)
                            invalidationStartAt.removeValue(forKey: obs.pieceId)
                            pieceBindings[obs.pieceId] = lock.targetId
                            pieceStates[obs.pieceId] = PieceValidationState(pieceId: obs.pieceId, isValid: true, confidence: 1.0, targetId: lock.targetId, optimalTransform: target.transform)
                        } else {
                            let now = CACurrentMediaTime()
                            if invalidationStartAt[obs.pieceId] == nil {
                                invalidationStartAt[obs.pieceId] = now
                                // Keep valid during dwell
                                pieceBindings[obs.pieceId] = lock.targetId
                                pieceStates[obs.pieceId] = PieceValidationState(pieceId: obs.pieceId, isValid: true, confidence: 0.9, targetId: lock.targetId, optimalTransform: target.transform)
                            } else if let start = invalidationStartAt[obs.pieceId], (now - start) < invalidationDwellSeconds {
                                // Still dwelling: keep valid
                                pieceBindings[obs.pieceId] = lock.targetId
                                pieceStates[obs.pieceId] = PieceValidationState(pieceId: obs.pieceId, isValid: true, confidence: 0.85, targetId: lock.targetId, optimalTransform: target.transform)
                            } else {
                                // Dwell exceeded: unlock
                                lockedValidations.removeValue(forKey: obs.pieceId)
                                invalidationStartAt.removeValue(forKey: obs.pieceId)
                                // Fall through to normal st state below
                            }
                        }
                        continue
                    }
                    if st.isValid, let tid = st.targetId {
                        pieceBindings[obs.pieceId] = tid
                        // Lock new validation
                        let mapped = mappingService.mapPieceToTargetSpace(
                            piecePositionScene: obs.position,
                            pieceRotation: obs.rotation,
                            pieceIsFlipped: obs.isFlipped,
                            mapping: mapping,
                            anchorPositionScene: anchorObs.position
                        )
                        lockedValidations[obs.pieceId] = LockedValidation(
                            pieceId: obs.pieceId,
                            targetId: tid,
                            lastValidPose: (mapped.positionSK, mapped.rotationSK, mapped.isFlipped),
                            lockedAt: CACurrentMediaTime()
                        )
                    }
                }
                groupMappingsOut[gid] = mapping
                anchorIds = anchorPieceIds
            }
        }
        }
        
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
                // Positive reinforcement unless already validated as part of anchor
                if pieceStates[obs.pieceId]?.isValid != true {
                    pieceNudges[obs.pieceId] = NudgeContent(level: .gentle, message: "✅ Good job!", visualHint: .pulse(intensity: 0.4), duration: 1.2)
                }
            } else if obs.pieceType == .parallelogram && !flipOK {
                pieceNudges[obs.pieceId] = NudgeContent(level: .specific, message: "🔁 Try flipping", visualHint: .flipDemo, duration: 2.0)
                #if DEBUG
                print("[NUDGE] flip piece=\(obs.pieceId) target=\(picked.id)")
                #endif
            } else if picked.rotDeg > options.orientationToleranceDeg && picked.rotDeg < options.rotationNudgeUpperDeg {
                // Compute target node zRotation that satisfies feature-angle equality
                // targetNodeZ = targetExpectedZ + canonicalTarget - sign(canonicalPiece)
                let raw = TangramPoseMapper.rawAngle(from: puzzle.targetPieces.first { $0.id == picked.id }?.transform ?? .identity)
                let targetExpectedZ = TangramPoseMapper.spriteKitAngle(fromRawAngle: raw)
                let canonicalTarget: CGFloat = obs.pieceType.isTriangle ? (.pi / 4) : 0
                let canonicalPiece: CGFloat = obs.pieceType.isTriangle ? (3 * .pi / 4) : 0
                let signAdjustedCanonicalPiece: CGFloat = obs.isFlipped ? -canonicalPiece : canonicalPiece
                let desiredNodeZ = TangramRotationValidator.normalizeAngle(targetExpectedZ + canonicalTarget - signAdjustedCanonicalPiece)

                // Emit rotation demo visual hint (animate current → target orientation)
                pieceNudges[obs.pieceId] = NudgeContent(
                    level: .specific,
                    message: "🔄 Try rotating",
                    visualHint: .rotationDemo(current: obs.rotation, target: desiredNodeZ),
                    duration: 2.0
                )
                #if DEBUG
                print("[NUDGE] rotate-demo piece=\(obs.pieceId) delta=\(Int(picked.rotDeg))° target=\(picked.id) currZ=\(Int(obs.rotation * 180 / .pi))° desiredZ=\(Int(desiredNodeZ * 180 / .pi))°")
                #endif
            }
        }
        
        // Absolute fallback: removed to honor the plan doc (relative until anchor, target-space after anchor)

        // Stable validatedTargets from locks only; removals propagate
        validatedTargets = Set(lockedValidations.values.map { $0.targetId })

        // Update lastValidationTime when anything processed
        if !significant.isEmpty { lastValidationTime = CACurrentMediaTime() }
        
        return ValidationResult(
            validatedTargets: validatedTargets,
            pieceStates: pieceStates,
            bindings: pieceBindings,
            nudgeContent: nil,
            pieceNudges: pieceNudges,
            groupMappings: groupMappingsOut,
            failureReasons: failureReasons,
            orientedTargets: orientedTargets,
            anchorPieceIds: anchorIds
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
            validatedTargetIds: context.validatedTargets,
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

    // MARK: - Pair Mapping per plan doc (centroid + relative)
    private func computePairDocMapping(
        pair: (TangramValidationEngine.PieceObservation, TangramValidationEngine.PieceObservation),
        puzzle: GamePuzzleData,
        preferredTargetIds: (String, String)?
    ) -> AnchorMapping? {
        let p0 = pair.0
        let p1 = pair.1
        // Choose concrete targets
        let tPair: (GamePuzzleData.TargetPiece, GamePuzzleData.TargetPiece)? = {
            if let pref = preferredTargetIds {
                if let a = puzzle.targetPieces.first(where: { $0.id == pref.0 }),
                   let b = puzzle.targetPieces.first(where: { $0.id == pref.1 }) {
                    return (a, b)
                }
                return nil
            }
            // No preferred ids: select the target pair that best matches observed pair by angle + length
            let candA = puzzle.targetPieces.filter { $0.pieceType == p0.pieceType }
            let candB = puzzle.targetPieces.filter { $0.pieceType == p1.pieceType }
            if candA.isEmpty || candB.isEmpty { return nil }
            let vp = CGVector(dx: p1.position.x - p0.position.x, dy: p1.position.y - p0.position.y)
            let vpLen = hypot(vp.dx, vp.dy)
            if vpLen < 1e-3 { return nil }
            var best: (pair: (GamePuzzleData.TargetPiece, GamePuzzleData.TargetPiece), cost: CGFloat)? = nil
            for a in candA {
                let cA = TangramBounds.computeSKTransformedVertices(for: a)
                let cAc = CGPoint(x: cA.map { $0.x }.reduce(0, +) / CGFloat(max(1, cA.count)),
                                  y: cA.map { $0.y }.reduce(0, +) / CGFloat(max(1, cA.count)))
                for b in candB {
                    let cB = TangramBounds.computeSKTransformedVertices(for: b)
                    let cBc = CGPoint(x: cB.map { $0.x }.reduce(0, +) / CGFloat(max(1, cB.count)),
                                      y: cB.map { $0.y }.reduce(0, +) / CGFloat(max(1, cB.count)))
                    let vt = CGVector(dx: cBc.x - cAc.x, dy: cBc.y - cAc.y)
                    let vtLen = hypot(vt.dx, vt.dy)
                    if vtLen < 1e-3 { continue }
                    // angle residual
                    let dot = vp.dx * vt.dx + vp.dy * vt.dy
                    let cross = vp.dx * vt.dy - vp.dy * vt.dx
                    let angle = abs(atan2(cross, dot))
                    // length residual (absolute difference)
                    let lenDiff = abs(vpLen - vtLen)
                    let cost = angle * 180 / .pi * 2.0 + lenDiff * 0.2 // weights: 2 deg weight, 0.2 px weight
                    if best == nil || cost < best!.cost { best = ((a, b), cost) }
                }
            }
            return best?.pair
        }()
        guard let (t0, t1) = tPair else { return nil }
        // Compute target centroids in SK space
        func centroid(of verts: [CGPoint]) -> CGPoint {
            guard !verts.isEmpty else { return .zero }
            let sx = verts.reduce(0) { $0 + $1.x }
            let sy = verts.reduce(0) { $0 + $1.y }
            return CGPoint(x: sx / CGFloat(verts.count), y: sy / CGFloat(verts.count))
        }
        let c0 = centroid(of: TangramBounds.computeSKTransformedVertices(for: t0))
        let c1 = centroid(of: TangramBounds.computeSKTransformedVertices(for: t1))
        
        // Direct two-point alignment: rotate (p1 - p0) onto (c1 - c0), then translate p0 to c0
        let vp = CGVector(dx: p1.position.x - p0.position.x, dy: p1.position.y - p0.position.y)
        let vt = CGVector(dx: c1.x - c0.x, dy: c1.y - c0.y)
        // Compute rotation that maps vp to vt
        let dot = vp.dx * vt.dx + vp.dy * vt.dy
        let cross = vp.dx * vt.dy - vp.dy * vt.dx
        let theta = atan2(cross, dot)
        let cosT = cos(theta), sinT = sin(theta)
        // Translation that takes rotated p0 exactly to c0
        let p0Rot = CGPoint(x: p0.position.x * cosT - p0.position.y * sinT,
                            y: p0.position.x * sinT + p0.position.y * cosT)
        let Tdx = c0.x - p0Rot.x
        let Tdy = c0.y - p0Rot.y
        // Build mapping (anchor first piece)
        var mapping = AnchorMapping(
            translationOffset: CGVector(dx: Tdx, dy: Tdy),
            rotationDelta: theta,
            flipParity: false,
            anchorPieceId: p0.pieceId,
            anchorTargetId: t0.id,
            version: 1,
            pairCount: 2,
            confidence: 1.0
        )
        // Set flip parity for parallelogram based on anchor vs target parity
        if p0.pieceType == .parallelogram {
            let targetDet = t0.transform.a * t0.transform.d - t0.transform.b * t0.transform.c
            let targetIsFlipped = targetDet < 0
            mapping.flipParity = (targetIsFlipped != p0.isFlipped)
        }
        return mapping
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

