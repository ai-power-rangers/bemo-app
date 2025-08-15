//
//  TangramRelativeMappingService.swift
//  Bemo
//
//  WHAT: Centralized per-group rigid mapping (anchor-based) and validation helpers
//  ARCHITECTURE: Service in MVVM-S shared by Scene and ViewModel
//

import Foundation
import CoreGraphics

struct AnchorMapping {
    var translationOffset: CGVector  // Changed to CGVector for consistency
    var rotationDelta: CGFloat
    var flipParity: Bool
    var anchorPieceId: String
    var anchorTargetId: String
    var version: Int
    var pairCount: Int
    var confidence: Float  // Added confidence from optimization
}

final class TangramRelativeMappingService {
    private let groupManager = ConstructionGroupManager()
    private var groupAnchorMappings: [UUID: AnchorMapping] = [:]
    private var groupValidatedTargets: [UUID: Set<String>] = [:]
    private var groupValidatedPairs: [UUID: [(pieceId: String, targetId: String)]] = [:]
    // Stable mapping reuse across frames (cluster signature → canonical group id)
    private var groupSignatureIndex: [String: UUID] = [:]
    // Track group membership to invalidate stale mappings when membership changes
    private var groupMembers: [UUID: Set<String>] = [:]

    // MARK: - Groups
    func updateGroups<T: GroupablePiece>(pieces: [T]) -> [ConstructionGroup] {
        // Simple adapter: map to pseudo SK nodes via position/id
        // We reuse the existing manager by synthesizing minimal PuzzlePieceNode-like data
        // Instead of over-engineering, rely on SK-path in scene; in VM we can port a generic path later if needed.
        // For now, this is a placeholder return; the Scene will continue calling groupManager directly.
        return []
    }

    // MARK: - Establish / Update Mapping
    func establishOrUpdateMapping(
        groupId: UUID,
        groupPieceIds: Set<String>,
        pickAnchor: () -> (anchorPieceId: String, anchorPositionScene: CGPoint, anchorRotation: CGFloat, anchorIsFlipped: Bool, anchorPieceType: TangramPieceType),
        candidateTargets: () -> [(target: GamePuzzleData.TargetPiece, centroidScene: CGPoint, expectedZ: CGFloat, isFlipped: Bool)],
        minFeatureAgreementDeg: CGFloat? = nil,
        hasAnchorEdgeContact: (() -> Bool)? = nil
    ) -> AnchorMapping? {
        if let existing = groupAnchorMappings[groupId] { return existing }

        // Choose anchor
        let anchor = pickAnchor()

        // Find nearest target for anchor among candidates
        var best: (target: GamePuzzleData.TargetPiece, centroid: CGPoint, expectedZ: CGFloat, isFlipped: Bool, dist: CGFloat)?
        for c in candidateTargets() {
            let d = hypot(anchor.anchorPositionScene.x - c.centroidScene.x, anchor.anchorPositionScene.y - c.centroidScene.y)
            if best == nil || d < best!.dist { best = (c.target, c.centroidScene, c.expectedZ, c.isFlipped, d) }
        }

        guard let bestMatch = best else { return nil }

        // Compute rotation delta in FEATURE-ANGLE space so triangles align correctly (45° target vs 135° piece)
        let canonicalTarget: CGFloat = anchor.anchorPieceType.isTriangle ? (.pi/4) : 0
        let canonicalPiece: CGFloat  = anchor.anchorPieceType.isTriangle ? (3 * .pi/4) : 0
        let anchorFeature = TangramRotationValidator.normalizeAngle(anchor.anchorRotation + (anchor.anchorIsFlipped ? -canonicalPiece : canonicalPiece))
        let targetFeature = TangramRotationValidator.normalizeAngle(bestMatch.expectedZ + canonicalTarget)
        let rotationDelta = TangramRotationValidator.normalizeAngle(targetFeature - anchorFeature)
        let parity = bestMatch.isFlipped != anchor.anchorIsFlipped
        let mapping = AnchorMapping(
            translationOffset: CGVector(dx: bestMatch.centroid.x - anchor.anchorPositionScene.x,
                                        dy: bestMatch.centroid.y - anchor.anchorPositionScene.y),
            rotationDelta: rotationDelta,
            flipParity: parity,
            anchorPieceId: anchor.anchorPieceId,
            anchorTargetId: bestMatch.target.id,
            version: 1,
            pairCount: 1,
            confidence: 1.0
        )
        // Optional gating: require minimum feature-angle agreement
        let deg = abs(rotationDelta) * 180 / .pi
        if let minAgree = minFeatureAgreementDeg, deg > minAgree {
            return nil
        }
        // Optional gating: require anchor to have an edge contact to some neighbor
        if let contactCheck = hasAnchorEdgeContact, contactCheck() == false {
            return nil
        }
        groupAnchorMappings[groupId] = mapping
        // Do NOT consume/validate anchor target here. Only consume when a non-anchor piece validates,
        // then validate the anchor afterwards.
        print("[MAPPING] Established group=\(groupId) anchorPiece=\(anchor.anchorPieceId) → anchorTarget=\(bestMatch.target.id) rotDelta=\(String(format: "%.1f", deg))° (feature) trans=(\(Int(mapping.translationOffset.dx)),\(Int(mapping.translationOffset.dy))) flipParity=\(parity)")
        return mapping
    }

    // MARK: - Map Piece -> Target Space
    func mapPieceToTargetSpace(piecePositionScene: CGPoint, pieceRotation: CGFloat, pieceIsFlipped: Bool, mapping: AnchorMapping, anchorPositionScene: CGPoint) -> (positionSK: CGPoint, rotationSK: CGFloat, isFlipped: Bool) {
        let cosD = cos(mapping.rotationDelta)
        let sinD = sin(mapping.rotationDelta)
        if mapping.version >= 2 || mapping.pairCount >= 2 {
            // Global doc mapping: p' = R * p + T (anchorPositionScene not used)
            let rotated = CGPoint(
                x: piecePositionScene.x * cosD - piecePositionScene.y * sinD,
                y: piecePositionScene.x * sinD + piecePositionScene.y * cosD
            )
            let mappedPos = CGPoint(x: rotated.x + mapping.translationOffset.dx,
                                    y: rotated.y + mapping.translationOffset.dy)
            let mappedRot = pieceRotation + mapping.rotationDelta
            let mappedFlip = mapping.flipParity ? !pieceIsFlipped : pieceIsFlipped
            return (mappedPos, mappedRot, mappedFlip)
        } else {
            // Legacy anchor-relative mapping
            let rel = CGVector(dx: piecePositionScene.x - anchorPositionScene.x, dy: piecePositionScene.y - anchorPositionScene.y)
            let rotatedRel = CGVector(dx: rel.dx * cosD - rel.dy * sinD, dy: rel.dx * sinD + rel.dy * cosD)
            let mappedPos = CGPoint(x: anchorPositionScene.x + mapping.translationOffset.dx + rotatedRel.dx,
                                    y: anchorPositionScene.y + mapping.translationOffset.dy + rotatedRel.dy)
            let mappedRot = pieceRotation + mapping.rotationDelta
            let mappedFlip = mapping.flipParity ? !pieceIsFlipped : pieceIsFlipped
            return (mappedPos, mappedRot, mappedFlip)
        }
    }

    // MARK: - Validate via feature angles
    func validateMapped(
        mappedPose: (pos: CGPoint, rot: CGFloat, isFlipped: Bool),
        pieceType: TangramPieceType,
        target: GamePuzzleData.TargetPiece,
        targetCentroidScene: CGPoint,
        validator: TangramPieceValidator
    ) -> Bool {
        let canonicalTarget: CGFloat = pieceType.isTriangle ? (.pi/4) : 0
        let canonicalPiece: CGFloat = pieceType.isTriangle ? (3 * .pi/4) : 0
        let targetRawAngle = TangramPoseMapper.rawAngle(from: target.transform)
        let targetZ = TangramPoseMapper.spriteKitAngle(fromRawAngle: targetRawAngle)
        let targetFeatureAngle = targetZ + canonicalTarget
        let pieceFeatureAngle = mappedPose.rot + (mappedPose.isFlipped ? -canonicalPiece : canonicalPiece)
        let result = validator.validateForSpriteKitWithFeatures(
            piecePosition: mappedPose.pos,
            pieceFeatureAngle: pieceFeatureAngle,
            targetFeatureAngle: targetFeatureAngle,
            pieceType: pieceType,
            isFlipped: mappedPose.isFlipped,
            targetTransform: target.transform,
            targetWorldPos: targetCentroidScene
        )
        return result.positionValid && result.rotationValid && result.flipValid
    }

    /// Detailed validation that also yields a primary failure reason for nudges
    func validateMappedDetailed(
        mappedPose: (pos: CGPoint, rot: CGFloat, isFlipped: Bool),
        pieceType: TangramPieceType,
        target: GamePuzzleData.TargetPiece,
        targetCentroidScene: CGPoint,
        validator: TangramPieceValidator
    ) -> (isValid: Bool, failure: ValidationFailure?) {
        let canonicalTarget: CGFloat = pieceType.isTriangle ? (.pi/4) : 0
        let canonicalPiece: CGFloat = pieceType.isTriangle ? (3 * .pi/4) : 0
        let targetRawAngle = TangramPoseMapper.rawAngle(from: target.transform)
        let targetZ = TangramPoseMapper.spriteKitAngle(fromRawAngle: targetRawAngle)
        let targetFeatureAngle = targetZ + canonicalTarget
        let pieceFeatureAngle = mappedPose.rot + (mappedPose.isFlipped ? -canonicalPiece : canonicalPiece)
        let result = validator.validateForSpriteKitWithFeatures(
            piecePosition: mappedPose.pos,
            pieceFeatureAngle: pieceFeatureAngle,
            targetFeatureAngle: targetFeatureAngle,
            pieceType: pieceType,
            isFlipped: mappedPose.isFlipped,
            targetTransform: target.transform,
            targetWorldPos: targetCentroidScene
        )
        let isValid = result.positionValid && result.rotationValid && result.flipValid
        if isValid { return (true, nil) }
        // Determine primary blocker – prefer flip > position > rotation for clarity
        if !result.flipValid { return (false, .needsFlip) }
        if !result.positionValid {
            let offset = hypot(mappedPose.pos.x - targetCentroidScene.x, mappedPose.pos.y - targetCentroidScene.y)
            return (false, .wrongPosition(offset: offset))
        }
        if !result.rotationValid {
            // Rough rotation delta for messaging
            let delta = TangramRotationValidator.normalizeAngle(pieceFeatureAngle - targetFeatureAngle)
            return (false, .wrongRotation(degreesOff: abs(delta) * 180 / .pi))
        }
        return (false, .wrongPiece)
    }

    // MARK: - Refinement
    func refineMapping(groupId: UUID,
                       pairs: [(pieceId: String, targetId: String)],
                       anchorPieceId: String,
                       anchorTargetId: String,
                       pieceScenePosProvider: (String) -> CGPoint?,
                       targetScenePosProvider: (String) -> CGPoint?) -> AnchorMapping? {
        guard let mapping = groupAnchorMappings[groupId], pairs.count >= 2 else { return groupAnchorMappings[groupId] }
        guard let anchorPieceScene = pieceScenePosProvider(anchorPieceId), let anchorTargetScene = targetScenePosProvider(anchorTargetId) else {
            return groupAnchorMappings[groupId]
        }

        var src: [CGPoint] = []
        var dst: [CGPoint] = []
        for (pid, tid) in pairs {
            guard let p = pieceScenePosProvider(pid), let t = targetScenePosProvider(tid) else { continue }
            src.append(CGPoint(x: p.x - anchorPieceScene.x, y: p.y - anchorPieceScene.y))
            dst.append(CGPoint(x: t.x - anchorTargetScene.x, y: t.y - anchorTargetScene.y))
        }
        guard src.count == dst.count, src.count >= 2 else { return groupAnchorMappings[groupId] }

        var sumCos: CGFloat = 0, sumSin: CGFloat = 0
        for i in 0..<src.count {
            let a = atan2(src[i].y, src[i].x)
            let b = atan2(dst[i].y, dst[i].x)
            let d = b - a
            sumCos += cos(d)
            sumSin += sin(d)
        }
        let rot = atan2(sumSin, sumCos)
        let rotatedSrc = src.map { pt -> CGPoint in
            CGPoint(x: pt.x * cos(rot) - pt.y * sin(rot), y: pt.x * sin(rot) + pt.y * cos(rot))
        }
        let meanDst = dst.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let meanSrc = rotatedSrc.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let n = CGFloat(dst.count)
        let trans = CGPoint(x: (meanDst.x - meanSrc.x) / n, y: (meanDst.y - meanSrc.y) / n)

        var updated = mapping
        updated.rotationDelta = rot
        updated.translationOffset = CGVector(dx: mapping.translationOffset.dx + trans.x, dy: mapping.translationOffset.dy + trans.y)
        updated.version = mapping.version + 1
        updated.pairCount = pairs.count
        groupAnchorMappings[groupId] = updated
        return updated
    }

    // MARK: - Inverse mapping for nudges
    func inverseMapTargetToPhysical(mapping: AnchorMapping,
                                    anchorScenePos: CGPoint,
                                    targetScenePos: CGPoint) -> CGPoint {
        let dx = targetScenePos.x - anchorScenePos.x - mapping.translationOffset.dx
        let dy = targetScenePos.y - anchorScenePos.y - mapping.translationOffset.dy
        let cosD = cos(-mapping.rotationDelta)
        let sinD = sin(-mapping.rotationDelta)
        let invRel = CGPoint(x: dx * cosD - dy * sinD, y: dx * sinD + dy * cosD)
        return CGPoint(x: anchorScenePos.x + invRel.x, y: anchorScenePos.y + invRel.y)
    }

    // MARK: - Optimization-based Mapping
    
    /// Establish mapping using global optimization from .mitch-docs
    func establishOrUpdateMappingOptimized(
        groupId: UUID,
        pieces: [(id: String, type: TangramPieceType, pos: CGPoint, rot: CGFloat, isFlipped: Bool)],
        candidateTargets: [GamePuzzleData.TargetPiece],
        difficulty: UserPreferences.DifficultySetting
    ) -> AnchorMapping? {
        // Compute stable signature for this cluster
        let signature = pieces.map { $0.id }.sorted().joined(separator: "|")
        // Reuse mapping by signature if available
        if let mappedGroupId = groupSignatureIndex[signature], let existing = groupAnchorMappings[mappedGroupId] {
            return existing
        }
        // Reuse direct group id mapping only if membership is unchanged
        let currentMembers: Set<String> = Set(pieces.map { $0.id })
        if let existing = groupAnchorMappings[groupId], groupMembers[groupId] == currentMembers {
            return existing
        }
        guard pieces.count >= 2 else {
            // Need at least 2 pieces for meaningful optimization
            return nil
        }
        
        // Get tolerances for difficulty (unused in simplified path)
        _ = TangramGameConstants.Validation.tolerances(for: difficulty)
        let wt: CGFloat = 1.0  // Translation weight
        let wr: CGFloat = 0.5  // Rotation weight (degrees matter less than position)
        
        // Step 1: Calculate centroids
        let pieceCentroid = calculateCentroid(of: pieces.map { $0.pos })
        let targetCentroid = calculateCentroid(of: candidateTargets.map {
            // Convert target transform position into SpriteKit scene coordinates
            let raw = CGPoint(x: $0.transform.tx, y: $0.transform.ty)
            return TangramPoseMapper.spriteKitPosition(fromRawPosition: raw)
        })
        
        // Step 2: Grid search for optimal rotation (coarse then fine)
        var bestTheta: CGFloat = 0
        var bestCost: CGFloat = .infinity
        
        // Coarse search: every 5 degrees
        for degrees in stride(from: 0, to: 360, by: 5) {
            let theta = CGFloat(degrees) * .pi / 180
            let cost = calculateRotationCost(
                theta: theta,
                pieces: pieces,
                targets: candidateTargets,
                pieceCentroid: pieceCentroid,
                targetCentroid: targetCentroid,
                wt: wt,
                wr: wr
            )
            if cost < bestCost {
                bestCost = cost
                bestTheta = theta
            }
        }
        
        // Fine search: ±5 degrees around best, every 0.5 degrees
        let searchStart = bestTheta - 5 * .pi / 180
        let _ = bestTheta + 5 * .pi / 180
        for i in 0...20 {
            let theta = searchStart + CGFloat(i) * 0.5 * .pi / 180
            let cost = calculateRotationCost(
                theta: theta,
                pieces: pieces,
                targets: candidateTargets,
                pieceCentroid: pieceCentroid,
                targetCentroid: targetCentroid,
                wt: wt,
                wr: wr
            )
            if cost < bestCost {
                bestCost = cost
                bestTheta = theta
            }
        }
        
        // Step 3: Calculate optimal translation for best rotation
        let _ = CGVector(
            dx: pieceCentroid.x - (targetCentroid.x * cos(bestTheta) - targetCentroid.y * sin(bestTheta)),
            dy: pieceCentroid.y - (targetCentroid.x * sin(bestTheta) + targetCentroid.y * cos(bestTheta))
        )
        
        // Use first piece as anchor
        let anchor = pieces[0]
        
        // Find best matching target for anchor using combined position+rotation cost in SK space
        var bestAnchorTarget: GamePuzzleData.TargetPiece?
        var bestAnchorCost: CGFloat = .infinity
        for target in candidateTargets where target.pieceType == anchor.type {
            // Target position/rotation in SK space
            let rawPos = CGPoint(x: target.transform.tx, y: target.transform.ty)
            let targetPos = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)
            let rawAngle = TangramPoseMapper.rawAngle(from: target.transform)
            let targetRotSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
            
            // Position cost: current anchor piece position vs target position
            let posCost = hypot(anchor.pos.x - targetPos.x, anchor.pos.y - targetPos.y)
            
            // Rotation cost using feature angles and bestTheta
            let canonicalTarget: CGFloat = anchor.type.isTriangle ? (.pi / 4) : 0
            let canonicalPiece: CGFloat = anchor.type.isTriangle ? (3 * .pi / 4) : 0
            let targetFeature = TangramRotationValidator.normalizeAngle(targetRotSK + canonicalTarget)
            let pieceFeature = TangramRotationValidator.normalizeAngle((anchor.rot + bestTheta) + (anchor.isFlipped ? -canonicalPiece : canonicalPiece))
            let rotCost = abs(angleDifference(pieceFeature, targetFeature)) * 180 / .pi
            
            let total = wt * posCost + wr * rotCost
            if total < bestAnchorCost {
                bestAnchorCost = total
                bestAnchorTarget = target
            }
        }
        
        guard let anchorTarget = bestAnchorTarget else { return nil }
        
        // Compute flip parity for parallelogram mapping
        let flipParity: Bool = {
            // Only relevant for parallelogram
            guard anchor.type == .parallelogram else { return false }
            
            // Check if target is flipped (negative determinant)
            let targetDet = anchorTarget.transform.a * anchorTarget.transform.d - 
                           anchorTarget.transform.b * anchorTarget.transform.c
            let targetIsFlipped = targetDet < 0
            
            // Parity is true if anchor and target have different flip states
            return anchor.isFlipped != targetIsFlipped
        }()
        
        // Create mapping with optimization results; anchor translation aligns anchor directly to its target in SK space
        // Compute target anchor position in SK coordinates
        let anchorTargetRawPos = CGPoint(x: anchorTarget.transform.tx, y: anchorTarget.transform.ty)
        let anchorTargetPosSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: anchorTargetRawPos)
        let mapping = AnchorMapping(
            translationOffset: CGVector(dx: anchorTargetPosSK.x - anchor.pos.x, dy: anchorTargetPosSK.y - anchor.pos.y),
            rotationDelta: bestTheta,
            flipParity: flipParity,
            anchorPieceId: anchor.id,
            anchorTargetId: anchorTarget.id,
            version: 1,
            pairCount: pieces.count,
            confidence: Float(1.0 / max(1.0, bestCost))
        )
        
        groupAnchorMappings[groupId] = mapping
        groupMembers[groupId] = currentMembers
        groupSignatureIndex[signature] = groupId
        print("[MAPPING-OPT] Established optimized mapping for group=\(groupId) theta=\(bestTheta * 180 / .pi)° cost=\(bestCost)")
        return mapping
    }
    
    private func calculateRotationCost(
        theta: CGFloat,
        pieces: [(id: String, type: TangramPieceType, pos: CGPoint, rot: CGFloat, isFlipped: Bool)],
        targets: [GamePuzzleData.TargetPiece],
        pieceCentroid: CGPoint,
        targetCentroid: CGPoint,
        wt: CGFloat,
        wr: CGFloat
    ) -> CGFloat {
        // Build type-buckets for pieces and targets
        var typeToPieceIdxs: [TangramPieceType: [Int]] = [:]
        for (idx, p) in pieces.enumerated() {
            typeToPieceIdxs[p.type, default: []].append(idx)
        }
        var typeToTargetIdxs: [TangramPieceType: [Int]] = [:]
        for (idx, t) in targets.enumerated() {
            typeToTargetIdxs[t.pieceType, default: []].append(idx)
        }

        var totalCost: CGFloat = 0

        for (ptype, pIdxs) in typeToPieceIdxs {
            let tIdxs = typeToTargetIdxs[ptype] ?? []
            if tIdxs.isEmpty { continue }

            // Build cost matrix rows=pieces(of this type), cols=targets(of this type)
            var costMatrix: [[CGFloat]] = Array(repeating: Array(repeating: 1_000_000, count: tIdxs.count), count: pIdxs.count)
            for (ri, pIndex) in pIdxs.enumerated() {
                let piece = pieces[pIndex]
                // Center piece position then rotate by theta
                let centered = CGPoint(x: piece.pos.x - pieceCentroid.x, y: piece.pos.y - pieceCentroid.y)
                let rotated = CGPoint(
                    x: centered.x * cos(theta) - centered.y * sin(theta),
                    y: centered.x * sin(theta) + centered.y * cos(theta)
                )
                let pieceFeature = featureAngle(for: piece.type, angle: piece.rot + theta, flipped: piece.isFlipped)
                for (cj, tIndex) in tIdxs.enumerated() {
                    let target = targets[tIndex]
                    let rawPos = CGPoint(x: target.transform.tx, y: target.transform.ty)
                    let targetPos = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)
                    let targetCentered = CGPoint(x: targetPos.x - targetCentroid.x, y: targetPos.y - targetCentroid.y)
                    let posDist = hypot(rotated.x - targetCentered.x, rotated.y - targetCentered.y)
                    let targetRotSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
                    let targetFeature = featureAngle(for: piece.type, angle: targetRotSK, flipped: false)
                    let rotDiff = symmetricAngleDistance(for: piece.type, a: pieceFeature, b: targetFeature)
                    costMatrix[ri][cj] = wt * posDist + wr * rotDiff * 180 / .pi
                }
            }

            let (_, blockCost) = hungarianMinCost(costMatrix)
            totalCost += blockCost
        }

        return totalCost
    }
    
    private func calculateCentroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { 
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
    
    private func angleDifference(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
        var diff = a2 - a1
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return diff
    }

    // MARK: - Shape-aware angle helpers
    private func period(for type: TangramPieceType) -> CGFloat {
        switch type {
        case .square: return .pi / 2
        case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2, .parallelogram:
            return .pi
        }
    }
    private func symmetricAngleDistance(for type: TangramPieceType, a: CGFloat, b: CGFloat) -> CGFloat {
        let P = period(for: type)
        var d = fmod(a - b, P)
        if d > P / 2 { d -= P }
        if d < -P / 2 { d += P }
        return abs(d)
    }
    private func featureAngle(for type: TangramPieceType, angle: CGFloat, flipped: Bool) -> CGFloat {
        let canonicalTarget: CGFloat = (type.isTriangle ? (.pi / 4) : 0)
        let canonicalPiece: CGFloat = (type.isTriangle ? (3 * .pi / 4) : 0)
        // For feature angle, add canonical offset; flip inverts local baseline for triangles
        return TangramRotationValidator.normalizeAngle(angle + (flipped ? -canonicalPiece : canonicalPiece) - canonicalTarget)
    }

    // MARK: - Hungarian (min cost) for small matrices
    private func hungarianMinCost(_ cost: [[CGFloat]]) -> (assignment: [Int], totalCost: CGFloat) {
        let n = max(cost.count, cost.first?.count ?? 0)
        if n == 0 { return ([], 0) }
        // Build square matrix padded with large costs
        var a: [[Double]] = Array(repeating: Array(repeating: 1_000_000, count: n), count: n)
        for i in 0..<cost.count {
            for j in 0..<(cost.first?.count ?? 0) {
                a[i][j] = Double(cost[i][j])
            }
        }
        // Hungarian algorithm (O(n^3))
        var u = Array(repeating: 0.0, count: n + 1)
        var v = Array(repeating: 0.0, count: n + 1)
        var p = Array(repeating: 0, count: n + 1)
        var way = Array(repeating: 0, count: n + 1)
        for i in 1...n {
            p[0] = i
            var j0 = 0
            var minv = Array(repeating: Double.infinity, count: n + 1)
            var used = Array(repeating: false, count: n + 1)
            used[0] = true
            repeat {
                used[j0] = true
                let i0 = p[j0]
                var delta = Double.infinity
                var j1 = 0
                for j in 1...n where !used[j] {
                    let cur = a[i0 - 1][j - 1] - u[i0] - v[j]
                    if cur < minv[j] { minv[j] = cur; way[j] = j0 }
                    if minv[j] < delta { delta = minv[j]; j1 = j }
                }
                for j in 0...n {
                    if used[j] { u[p[j]] += delta; v[j] -= delta }
                    else { minv[j] -= delta }
                }
                j0 = j1
            } while p[j0] != 0
            repeat {
                let j1 = way[j0]
                p[j0] = p[j1]
                j0 = j1
            } while j0 != 0
        }
        var assignment = Array(repeating: -1, count: n)
        for j in 1...n { if p[j] > 0 { assignment[p[j] - 1] = j - 1 } }
        var total = 0.0
        for i in 0..<min(cost.count, n) {
            let j = assignment[i]
            if j >= 0 && j < (cost.first?.count ?? 0) { total += Double(cost[i][j]) }
        }
        return (assignment, CGFloat(total))
    }
    
    // MARK: - Accessors
    func mapping(for groupId: UUID) -> AnchorMapping? { groupAnchorMappings[groupId] }
    func setMapping(for groupId: UUID, mapping: AnchorMapping) { groupAnchorMappings[groupId] = mapping }
    func markTargetConsumed(groupId: UUID, targetId: String) { groupValidatedTargets[groupId, default: []].insert(targetId) }
    func consumedTargets(groupId: UUID) -> Set<String> { groupValidatedTargets[groupId] ?? [] }
    func appendPair(groupId: UUID, pieceId: String, targetId: String) { groupValidatedPairs[groupId, default: []].append((pieceId, targetId)) }
    func pairs(groupId: UUID) -> [(pieceId: String, targetId: String)] { groupValidatedPairs[groupId] ?? [] }

    // Unconsume a target when a previously validated piece is moved out of valid position
    func unmarkTargetConsumed(groupId: UUID, targetId: String) {
        var set = groupValidatedTargets[groupId] ?? []
        set.remove(targetId)
        groupValidatedTargets[groupId] = set
    }

    // Remove an established pair for refinement bookkeeping
    func removePair(groupId: UUID, pieceId: String, targetId: String) {
        guard var list = groupValidatedPairs[groupId] else { return }
        list.removeAll { $0.pieceId == pieceId && $0.targetId == targetId }
        groupValidatedPairs[groupId] = list
    }
}


