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
    
    // MARK: - Dependencies
    
    private let groupManager: ConstructionGroupManager
    let mappingService: TangramRelativeMappingService
    let validator: TangramPieceValidator
    let nudgeManager: SmartNudgeManager
    private let hintEngine: TangramHintEngine
    private let optimizationValidator: OptimizationValidator
    let pairScorer: TangramPairScorer
    let anchorMapper: TangramAnchorMapper
    private var currentDifficulty: UserPreferences.DifficultySetting
    
    // MARK: - State
    
    private var validatedTargets: Set<String> = []
    private var pieceBindings: [String: String] = [:] // pieceId -> targetId
    private var lastValidationTime: TimeInterval = 0
    var pieceAttempts: [String: Int] = [:]
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

    // Precomputed target relations (cached per puzzle id)
    private var cachedPairLibraries: [String: TargetPairLibrary] = [:]
    private var cachedAdjacencyGraphs: [String: TargetAdjacencyGraph] = [:]
    
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
        self.pairScorer = TangramPairScorer()
        self.anchorMapper = TangramAnchorMapper(
            mappingService: mappingService,
            validator: validator
        )
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
        // Ensure target relations are built for this puzzle id
        if cachedPairLibraries[puzzle.id] == nil {
            cachedPairLibraries[puzzle.id] = TargetPairLibrary.build(for: puzzle)
        }
        if cachedAdjacencyGraphs[puzzle.id] == nil {
            cachedAdjacencyGraphs[puzzle.id] = TargetAdjacencyGraph.build(for: puzzle)
        }
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

                // Use the new helper to select the candidate anchor pair
                var candidatePair: (PieceObservation, PieceObservation)? = nil
                if let selected = selectCandidateAnchorPair(
                    from: settled,
                    puzzle: puzzle,
                    orientationToleranceDeg: options.orientationToleranceDeg,
                    focusPieceId: options.focusPieceId,
                    pairLibrary: cachedPairLibraries[puzzle.id]
                ) {
                    candidatePair = selected.pair
                    #if DEBUG
                    print("[ANCHOR-SELECT] Oriented pair selected via \(selected.reason): \(selected.pair.0.pieceId), \(selected.pair.1.pieceId)")
                    #endif
                }

                if let pair = candidatePair {
                    let groupId: UUID = mainGroupId ?? UUID()
                    // Compute mapping using plan doc method (pair-centric centroid + relative rotation)
                    if var mapping = computeMappingForPair(
                        observedPair: pair,
                        puzzle: puzzle,
                        preferredTargetIds: nil,
                        pairLibrary: cachedPairLibraries[puzzle.id]
                    ) {
                        // Validate both pieces under this mapping
                        let pairObs: [PieceObservation] = [pair.0, pair.1]
                        var localStates: [String: PieceValidationState] = [:]
                        var localValidatedTargets: Set<String> = []
                        for obs in pairObs {
                            let st = validateMappedPiece(
                                observation: obs,
                                mapping: mapping,
                                anchorPosition: idToObs[mapping.anchorPieceId]?.position ?? .zero, // Fallback if anchor not found
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
                        #if DEBUG
                        print("[ANCHOR-VALIDATE] Pair validation: \(pairObs[0].pieceType.rawValue)=\(localStates[pairObs[0].pieceId]?.isValid ?? false), \(pairObs[1].pieceType.rawValue)=\(localStates[pairObs[1].pieceId]?.isValid ?? false), bothStrict=\(bothStrict)")
                        #endif
                        var bothRelaxed = false
                        if !bothStrict {
                            // Compute residuals and apply relaxed thresholds (tempered)
                            let tolerances = TangramGameConstants.Validation.tolerances(for: difficulty)
                            let posRelax = tolerances.position * 1.6
                            let rotRelaxDeg = tolerances.rotationDeg * 1.2
                            var okCount = 0
                            var maxObservedPos: CGFloat = 0
                            var maxObservedRotDeg: CGFloat = 0
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
                                        anchorPositionScene: idToObs[mapping.anchorPieceId]?.position ?? .zero // Fallback if anchor not found
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
                                    let rotDiffDeg = abs(TangramGeometryHelpers.angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                                    maxObservedPos = max(maxObservedPos, posDist)
                                    maxObservedRotDeg = max(maxObservedRotDeg, rotDiffDeg)
                                    let passesRelaxed = posDist <= posRelax && rotDiffDeg <= rotRelaxDeg
                                    if passesRelaxed { okCount += 1 }
                                    #if DEBUG
                                    print("[ANCHOR-RESIDUALS] piece=\(obs.pieceType.rawValue) posDist=\(Int(posDist))/\(Int(posRelax)) rotDiff=\(Int(rotDiffDeg))°/\(Int(rotRelaxDeg))° passes=\(passesRelaxed)")
                                    #endif
                                }
                            }
                            bothRelaxed = (okCount == pairObs.count)
                            #if DEBUG
                            print("[ANCHOR-VALIDATE] Relaxed validation: okCount=\(okCount)/\(pairObs.count), bothRelaxed=\(bothRelaxed)")
                            #endif
                        }
                        // Enforce maximum distance between the two observed anchors before allowing commit
                        // Tie to difficulty connection tolerance to avoid far-apart validation
                        let baseConn = TangramGameConstants.Validation.tolerances(for: difficulty).connection
                        let maxPairSeparation: CGFloat = baseConn * 1.25
                        let pA = pairObs[0].position
                        let pB = pairObs[1].position
                        let pairDist = hypot(pA.x - pB.x, pA.y - pB.y)
                        #if DEBUG
                        print("[ANCHOR-VALIDATE] Pair distance=\(Int(pairDist)) (max=\(Int(maxPairSeparation))), ready=\(bothStrict || bothRelaxed)")
                        #endif

                        if (bothStrict || bothRelaxed) && pairDist <= maxPairSeparation {
                            // Refine mapping using the actual target ids selected for the pair (avoids first-of-type skew)
                            if let t0 = localStates[pair.0.pieceId]?.targetId, let t1 = localStates[pair.1.pieceId]?.targetId,
                               let refined = computeMappingForPair(
                                   observedPair: pair,
                                   puzzle: puzzle,
                                   preferredTargetIds: (t0, t1),
                                   pairLibrary: cachedPairLibraries[puzzle.id]
                               ) {
                                mapping = refined
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
                                let dTheta = abs(TangramGeometryHelpers.angleDifference(existing.rotationDelta, mapping.rotationDelta)) * 180 / .pi
                                let dTrans = hypot(existing.translationOffset.dx - mapping.translationOffset.dx,
                                                   existing.translationOffset.dy - mapping.translationOffset.dy)
                                let sameAnchor = (existing.anchorPieceId == mapping.anchorPieceId) && (existing.anchorTargetId == mapping.anchorTargetId)
                                // Tighten reuse window to avoid orbiting/flip-flopping mapping
                                if sameAnchor && dTheta <= 2.0 && dTrans <= 4.0 {
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
                                                anchorPositionScene: idToObs[mapping.anchorPieceId]?.position ?? .zero // Fallback if anchor not found
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
                                            let rotDiffDeg = abs(TangramGeometryHelpers.angleDifference(pieceFeature, targetFeature)) * 180 / .pi
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
                                            anchorPositionScene: idToObs[mapping.anchorPieceId]?.position ?? .zero // Fallback if anchor not found
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
                                        let rotDiffDeg = abs(TangramGeometryHelpers.angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                                        print("[VALIDATION-DETAIL] piece=\(obs.pieceId) target=\(tid) posDist=\(Int(posDist)) rotDiff=\(Int(rotDiffDeg))°")
                                    }
                                }
                                #endif
                            }
                            
                            // After committing the anchor pair, attempt to validate exactly one adjacent neighbor
                            if let adj = cachedAdjacencyGraphs[puzzle.id] {
                                // Get neighbor target ids of the committed targets
                                let committedTargetIds: [String] = [pair.0.pieceId, pair.1.pieceId].compactMap { pieceBindings[$0] }
                                var neighborTargetWhitelist: Set<String> = []
                                for tid in committedTargetIds {
                                    neighborTargetWhitelist.formUnion(adj.neighbors(of: tid))
                                }
                                // Remove already validated targets and the two anchors
                                neighborTargetWhitelist.subtract(validatedTargets)
                                neighborTargetWhitelist.subtract(committedTargetIds)
                                
                                if !neighborTargetWhitelist.isEmpty {
                                    // Try to find one observed piece of matching type that validates under the mapping
                                    var bestNeighbor: (pid: String, st: PieceValidationState)? = nil
                                    for obs in frame where !committedTargetIds.contains(obs.pieceId) {
                                        let st = validateMappedPiece(
                                            observation: obs,
                                            mapping: mapping,
                                            anchorPosition: idToObs[mapping.anchorPieceId]?.position ?? .zero, // Fallback if anchor not found
                                            puzzle: puzzle,
                                            difficulty: difficulty,
                                            allowedTargetIds: neighborTargetWhitelist
                                        )
                                        if st.isValid, let _ = st.targetId {
                                            bestNeighbor = (obs.pieceId, st)
                                            break
                                        }
                                    }
                                    if let add = bestNeighbor, let tid = add.st.targetId {
                                        pieceStates[add.pid] = add.st
                                        pieceBindings[add.pid] = tid
                                        validatedTargets.insert(tid)
                                        // Initialize a conservative lock for neighbor with small slack to prevent oscillation
                                        lockedValidations[add.pid] = LockedValidation(
                                            pieceId: add.pid,
                                            targetId: tid,
                                            lastValidPose: (
                                                pos: CGPoint.zero,
                                                rot: 0,
                                                flip: false
                                            ),
                                            lockedAt: CACurrentMediaTime(),
                                            allowedPositionSlack: TangramGameConstants.Validation.tolerances(for: difficulty).position * 1.1,
                                            allowedRotationSlackDeg: TangramGameConstants.Validation.tolerances(for: difficulty).rotationDeg * 1.1
                                        )
                                        #if DEBUG
                                        print("[ADJ-EXPAND] Added neighbor piece=\(add.pid) -> target=\(tid)")
                                        #endif
                                    }
                                }
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
                                            anchorPositionScene: idToObs[mapping.anchorPieceId]?.position ?? .zero // Fallback if anchor not found
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
                                        let rotDiffDeg = abs(TangramGeometryHelpers.angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                                        print("    · residuals posDist=\(Int(posDist)) rotDiff=\(Int(rotDiffDeg))°")
                                    }
                                }
                            }
                            #endif
                        }
                    } else {
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
                       let updated = computeMappingForPair(
                           observedPair: (obs0, obs1),
                           puzzle: puzzle,
                           preferredTargetIds: (t0, t1),
                           pairLibrary: cachedPairLibraries[puzzle.id]
                       ) {
                        // Only accept updated mapping if change is within tight bounds to prevent orbiting jitter
                        if anchorMapper.shouldReuseMapping(existing: mapping, new: updated) {
                            mapping = updated
                            mappingService.setMapping(for: gid, mapping: updated)
                        }
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
                        let rotDiffDeg = abs(TangramGeometryHelpers.angleDifference(pieceFeature, targetFeature)) * 180 / .pi
                        let tol = TangramGameConstants.Validation.tolerances(for: difficulty)
                        let posLimit = tol.position + invalidationSlackPosition
                        let rotLimit = tol.rotationDeg + invalidationSlackRotationDeg
                        // Prefer per-lock dynamic slack if available (1.1x of commit residuals), else global slack
                        let effPosLimit = lock.allowedPositionSlack ?? posLimit
                        let effRotLimit = lock.allowedRotationSlackDeg ?? rotLimit
                        if posDist <= effPosLimit && rotDiffDeg <= effRotLimit {
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
        
        // Only do orientation-only feedback when we DON'T have an anchor mapping
        // Once we have a mapping, everything should validate through the mapped space
        if mainGroupId == nil {
            let res = computeOrientationOnlyFeedback(
                observations: significant,
                puzzle: puzzle,
                options: options,
                currentPieceStates: pieceStates
            )
            orientedTargets.formUnion(res.orientedTargets)
            for (k, v) in res.pieceNudges { pieceNudges[k] = v }
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
        difficulty: UserPreferences.DifficultySetting,
        allowedTargetIds: Set<String>? = nil
    ) -> PieceValidationState {
        // Build candidate targets by type, then optionally restrict by allowedTargetIds
        var candidateTargets: [GamePuzzleData.TargetPiece] = puzzle.targetPieces.filter { target in
            target.pieceType == observation.pieceType && !validatedTargets.contains(target.id)
        }
        if let whitelist = allowedTargetIds {
            candidateTargets = candidateTargets.filter { whitelist.contains($0.id) }
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
            let rotDiff = TangramGeometryHelpers.angleDifference(pieceFeatureAngle, targetFeatureAngle)
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
}

