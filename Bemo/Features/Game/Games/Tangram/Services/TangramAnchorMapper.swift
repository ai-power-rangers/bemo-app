//
//  TangramAnchorMapper.swift
//  Bemo
//
//  Anchor mapping establishment and management for Tangram validation
//

// WHAT: Manages anchor pair establishment, mapping computation, and coordinate system transformations
// ARCHITECTURE: Service that establishes and maintains the relative coordinate system for validation
// USAGE: Called by TangramValidationEngine to establish and update anchor mappings

import Foundation
import CoreGraphics

class TangramAnchorMapper {
    
    // MARK: - Dependencies
    
    private let mappingService: TangramRelativeMappingService
    private let validator: TangramPieceValidator
    
    // MARK: - Initialization
    
    init(mappingService: TangramRelativeMappingService, validator: TangramPieceValidator) {
        self.mappingService = mappingService
        self.validator = validator
    }
    
    // MARK: - Pair Mapping
    
    /// Compute mapping from an observed pair to a target pair using the doc method
    func computePairMapping(
        observedPair: (p0: TangramValidationEngine.PieceObservation, p1: TangramValidationEngine.PieceObservation),
        targetPair: (t0: GamePuzzleData.TargetPiece, t1: GamePuzzleData.TargetPiece)
    ) -> AnchorMapping? {
        let p0 = observedPair.p0
        let p1 = observedPair.p1
        let t0 = targetPair.t0
        let t1 = targetPair.t1
        
        // Compute target centroids in SK space
        let c0 = TangramGeometryHelpers.targetCentroid(for: t0)
        let c1 = TangramGeometryHelpers.targetCentroid(for: t1)
        
        // Direct two-point alignment: rotate (p1 - p0) onto (c1 - c0), then translate p0 to c0
        let vp = TangramGeometryHelpers.vector(from: p0.position, to: p1.position)
        let vt = TangramGeometryHelpers.vector(from: c0, to: c1)
        
        // Compute rotation that maps vp to vt
        let dot = vp.dx * vt.dx + vp.dy * vt.dy
        let cross = vp.dx * vt.dy - vp.dy * vt.dx
        let theta = atan2(cross, dot)
        
        // Translation that takes rotated p0 exactly to c0
        let p0Rot = TangramGeometryHelpers.rotatePoint(p0.position, by: theta)
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
        
        // Set flip parity for parallelogram
        if p0.pieceType == .parallelogram {
            let targetIsFlipped = TangramGeometryHelpers.isTransformFlipped(t0.transform)
            mapping.flipParity = (p0.isFlipped != targetIsFlipped)
        }
        
        return mapping
    }
    
    // MARK: - Validation
    
    /// Validate a pair under a mapping
    func validatePairUnderMapping(
        pair: (TangramValidationEngine.PieceObservation, TangramValidationEngine.PieceObservation),
        mapping: AnchorMapping,
        puzzle: GamePuzzleData,
        difficulty: UserPreferences.DifficultySetting
    ) -> (bothValid: Bool, states: [String: TangramValidationEngine.PieceValidationState]) {
        let anchorPosition = pair.0.pieceId == mapping.anchorPieceId ? pair.0.position : pair.1.position
        var states: [String: TangramValidationEngine.PieceValidationState] = [:]
        
        for obs in [pair.0, pair.1] {
            let state = validateMappedPiece(
                observation: obs,
                mapping: mapping,
                anchorPosition: anchorPosition,
                puzzle: puzzle,
                difficulty: difficulty
            )
            states[obs.pieceId] = state
        }
        
        let bothValid = states.values.allSatisfy { $0.isValid }
        return (bothValid, states)
    }
    
    /// Check if a pair passes relaxed validation thresholds
    func checkRelaxedValidation(
        pair: (TangramValidationEngine.PieceObservation, TangramValidationEngine.PieceObservation),
        mapping: AnchorMapping,
        states: [String: TangramValidationEngine.PieceValidationState],
        puzzle: GamePuzzleData,
        difficulty: UserPreferences.DifficultySetting
    ) -> (passes: Bool, maxPosDist: CGFloat, maxRotDeg: CGFloat) {
        let tolerances = TangramGameConstants.Validation.tolerances(for: difficulty)
        let posRelax = tolerances.position * 1.6
        let rotRelaxDeg = tolerances.rotationDeg * 1.2
        
        let anchorPosition = pair.0.pieceId == mapping.anchorPieceId ? pair.0.position : pair.1.position
        var okCount = 0
        var maxPosDist: CGFloat = 0
        var maxRotDeg: CGFloat = 0
        
        for obs in [pair.0, pair.1] {
            // Get target from state or find by type
            let targetId = states[obs.pieceId]?.targetId ?? 
                puzzle.targetPieces.first(where: { $0.pieceType == obs.pieceType })?.id
            
            guard let tid = targetId,
                  let target = puzzle.targetPieces.first(where: { $0.id == tid }) else { continue }
            
            let mapped = mappingService.mapPieceToTargetSpace(
                piecePositionScene: obs.position,
                pieceRotation: obs.rotation,
                pieceIsFlipped: obs.isFlipped,
                mapping: mapping,
                anchorPositionScene: anchorPosition
            )
            
            let centroid = TangramGeometryHelpers.targetCentroid(for: target)
            let posDist = TangramGeometryHelpers.distance(from: mapped.positionSK, to: centroid)
            
            let pieceFeature = TangramGeometryHelpers.pieceFeatureAngle(
                rotation: mapped.rotationSK,
                pieceType: obs.pieceType,
                isFlipped: mapped.isFlipped
            )
            let targetFeature = TangramGeometryHelpers.targetFeatureAngle(
                transform: target.transform,
                pieceType: obs.pieceType
            )
            let rotDiffDeg = TangramGeometryHelpers.angleDifferenceDegrees(pieceFeature, targetFeature)
            
            maxPosDist = max(maxPosDist, posDist)
            maxRotDeg = max(maxRotDeg, rotDiffDeg)
            
            let passesRelaxed = posDist <= posRelax && rotDiffDeg <= rotRelaxDeg
            if passesRelaxed { okCount += 1 }
            
            #if DEBUG
            print("[ANCHOR-RESIDUALS] piece=\(obs.pieceType.rawValue) posDist=\(Int(posDist))/\(Int(posRelax)) rotDiff=\(Int(rotDiffDeg))°/\(Int(rotRelaxDeg))° passes=\(passesRelaxed)")
            #endif
        }
        
        let bothRelaxed = (okCount == 2)
        return (bothRelaxed, maxPosDist, maxRotDeg)
    }
    
    /// Check if an existing mapping should be reused
    func shouldReuseMapping(
        existing: AnchorMapping,
        new: AnchorMapping
    ) -> Bool {
        let dTheta = TangramGeometryHelpers.angleDifferenceDegrees(existing.rotationDelta, new.rotationDelta)
        let dTrans = hypot(
            existing.translationOffset.dx - new.translationOffset.dx,
            existing.translationOffset.dy - new.translationOffset.dy
        )
        let sameAnchor = (existing.anchorPieceId == new.anchorPieceId) && 
                        (existing.anchorTargetId == new.anchorTargetId)
        
        // Tight bounds to prevent jitter
        return sameAnchor && dTheta <= 2.0 && dTrans <= 4.0
    }
    
    /// Update an existing mapping from live anchor observations
    func updateMappingFromAnchors(
        anchorIds: [String],
        observations: [TangramValidationEngine.PieceObservation],
        bindings: [String: String],
        puzzle: GamePuzzleData
    ) -> AnchorMapping? {
        guard anchorIds.count == 2,
              let obs0 = observations.first(where: { $0.pieceId == anchorIds[0] }),
              let obs1 = observations.first(where: { $0.pieceId == anchorIds[1] }),
              let t0 = bindings[obs0.pieceId],
              let t1 = bindings[obs1.pieceId],
              let target0 = puzzle.targetPieces.first(where: { $0.id == t0 }),
              let target1 = puzzle.targetPieces.first(where: { $0.id == t1 }) else {
            return nil
        }
        
        return computePairMapping(
            observedPair: (obs0, obs1),
            targetPair: (target0, target1)
        )
    }
    
    // MARK: - Private Methods
    
    private func validateMappedPiece(
        observation: TangramValidationEngine.PieceObservation,
        mapping: AnchorMapping,
        anchorPosition: CGPoint,
        puzzle: GamePuzzleData,
        difficulty: UserPreferences.DifficultySetting
    ) -> TangramValidationEngine.PieceValidationState {
        // Get candidate targets
        let candidateTargets = puzzle.targetPieces.filter { 
            $0.pieceType == observation.pieceType 
        }
        
        // Map piece to target space
        let mapped = mappingService.mapPieceToTargetSpace(
            piecePositionScene: observation.position,
            pieceRotation: observation.rotation,
            pieceIsFlipped: observation.isFlipped,
            mapping: mapping,
            anchorPositionScene: anchorPosition
        )
        
        // Compute piece feature angle
        let pieceFeatureAngle = TangramGeometryHelpers.pieceFeatureAngle(
            rotation: mapped.rotationSK,
            pieceType: observation.pieceType,
            isFlipped: mapped.isFlipped
        )
        
        var bestTargetId: String?
        var bestValid = false
        var bestConfidence: CGFloat = 0
        var bestCost: CGFloat = .infinity
        
        for target in candidateTargets {
            let targetCentroid = TangramGeometryHelpers.targetCentroid(for: target)
            let targetFeatureAngle = TangramGeometryHelpers.targetFeatureAngle(
                transform: target.transform,
                pieceType: observation.pieceType
            )
            
            // Validate using mapped pose
            let resultTuple = validator.validateForSpriteKitWithFeatures(
                piecePosition: mapped.positionSK,
                pieceFeatureAngle: pieceFeatureAngle,
                targetFeatureAngle: targetFeatureAngle,
                pieceType: observation.pieceType,
                isFlipped: mapped.isFlipped,
                targetTransform: target.transform,
                targetWorldPos: targetCentroid
            )
            
            // Compute confidence
            let posDist = TangramGeometryHelpers.distance(from: mapped.positionSK, to: targetCentroid)
            let rotDiff = TangramGeometryHelpers.angleDifference(pieceFeatureAngle, targetFeatureAngle)
            let posConf = max(0, 1 - posDist / 100)
            let rotConf = max(0, 1 - abs(rotDiff) / .pi)
            let conf = (posConf + rotConf) / 2
            
            // Compute cost
            let tolerances = TangramGameConstants.Validation.tolerances(for: difficulty)
            let cost = posDist / max(1, tolerances.position) + 
                      (abs(rotDiff) / max(0.0001, tolerances.rotationDeg * .pi / 180))
            
            let isValid = resultTuple.positionValid && resultTuple.rotationValid && resultTuple.flipValid
            if isValid && cost < bestCost {
                bestCost = cost
                bestValid = true
                bestConfidence = conf
                bestTargetId = target.id
            } else if !bestValid && cost < bestCost {
                bestCost = cost
                bestConfidence = conf
                bestTargetId = target.id
            }
        }
        
        return TangramValidationEngine.PieceValidationState(
            pieceId: observation.pieceId,
            isValid: bestValid,
            confidence: bestConfidence,
            targetId: bestValid ? bestTargetId : nil,
            optimalTransform: nil
        )
    }
}