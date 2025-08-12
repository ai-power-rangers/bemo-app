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
    var translationOffset: CGPoint
    var rotationDelta: CGFloat
    var flipParity: Bool
    var anchorPieceId: String
    var anchorTargetId: String
    var version: Int
    var pairCount: Int
}

final class TangramRelativeMappingService {
    private let groupManager = ConstructionGroupManager()
    private var groupAnchorMappings: [UUID: AnchorMapping] = [:]
    private var groupValidatedTargets: [UUID: Set<String>] = [:]
    private var groupValidatedPairs: [UUID: [(pieceId: String, targetId: String)]] = [:]

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
        candidateTargets: () -> [(target: GamePuzzleData.TargetPiece, centroidScene: CGPoint, expectedZ: CGFloat, isFlipped: Bool)]
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
            translationOffset: CGPoint(x: bestMatch.centroid.x - anchor.anchorPositionScene.x,
                                        y: bestMatch.centroid.y - anchor.anchorPositionScene.y),
            rotationDelta: rotationDelta,
            flipParity: parity,
            anchorPieceId: anchor.anchorPieceId,
            anchorTargetId: bestMatch.target.id,
            version: 1,
            pairCount: 1
        )
        groupAnchorMappings[groupId] = mapping
        // Do NOT consume/validate anchor target here. Only consume when a piece actually validates.
        let deg = rotationDelta * 180 / .pi
        print("[MAPPING] Established group=\(groupId) anchorPiece=\(anchor.anchorPieceId) → anchorTarget=\(bestMatch.target.id) rotDelta=\(String(format: "%.1f", deg))° (feature) trans=(\(Int(mapping.translationOffset.x)),\(Int(mapping.translationOffset.y))) flipParity=\(parity)")
        return mapping
    }

    // MARK: - Map Piece -> Target Space
    func mapPieceToTargetSpace(piecePositionScene: CGPoint, pieceRotation: CGFloat, pieceIsFlipped: Bool, mapping: AnchorMapping, anchorPositionScene: CGPoint) -> (positionSK: CGPoint, rotationSK: CGFloat, isFlipped: Bool) {
        let rel = CGVector(dx: piecePositionScene.x - anchorPositionScene.x, dy: piecePositionScene.y - anchorPositionScene.y)
        let cosD = cos(mapping.rotationDelta)
        let sinD = sin(mapping.rotationDelta)
        let rotatedRel = CGVector(dx: rel.dx * cosD - rel.dy * sinD, dy: rel.dx * sinD + rel.dy * cosD)
        let mappedPos = CGPoint(x: anchorPositionScene.x + mapping.translationOffset.x + rotatedRel.dx,
                                y: anchorPositionScene.y + mapping.translationOffset.y + rotatedRel.dy)
        let mappedRot = pieceRotation + mapping.rotationDelta
        let mappedFlip = mapping.flipParity ? !pieceIsFlipped : pieceIsFlipped
        return (mappedPos, mappedRot, mappedFlip)
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
        updated.translationOffset = CGPoint(x: mapping.translationOffset.x + trans.x, y: mapping.translationOffset.y + trans.y)
        updated.version = mapping.version + 1
        updated.pairCount = pairs.count
        groupAnchorMappings[groupId] = updated
        return updated
    }

    // MARK: - Inverse mapping for nudges
    func inverseMapTargetToPhysical(mapping: AnchorMapping,
                                    anchorScenePos: CGPoint,
                                    targetScenePos: CGPoint) -> CGPoint {
        let dx = targetScenePos.x - anchorScenePos.x - mapping.translationOffset.x
        let dy = targetScenePos.y - anchorScenePos.y - mapping.translationOffset.y
        let cosD = cos(-mapping.rotationDelta)
        let sinD = sin(-mapping.rotationDelta)
        let invRel = CGPoint(x: dx * cosD - dy * sinD, y: dx * sinD + dy * cosD)
        return CGPoint(x: anchorScenePos.x + invRel.x, y: anchorScenePos.y + invRel.y)
    }

    // MARK: - Accessors
    func mapping(for groupId: UUID) -> AnchorMapping? { groupAnchorMappings[groupId] }
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


