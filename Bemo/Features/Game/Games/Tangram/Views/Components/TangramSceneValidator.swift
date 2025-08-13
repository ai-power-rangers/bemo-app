//
//  TangramSceneValidator.swift
//  Bemo
//
//  Handles all validation logic for TangramPuzzleScene
//

// WHAT: Validation logic extracted from TangramPuzzleScene for piece placement validation
// ARCHITECTURE: Component of TangramPuzzleScene handling validation state and logic
// USAGE: Called by scene when pieces need validation, manages validation state and visual feedback

import SpriteKit
import Foundation

extension TangramPuzzleScene {
    
    // MARK: - Validation Entry Point
    
    func validatePlacedPiece(_ piece: PuzzlePieceNode) {
        guard let puzzle = puzzle,
              let pieceType = piece.pieceType,
              let pieceId = piece.name else { return }
        
        // Update construction groups
        constructionGroups = groupManager.updateGroups(with: availablePieces)
        
        // Find this piece's group
        var pieceGroup = constructionGroups.first { $0.pieces.contains(pieceId) }
        // Fallback: attach to nearest mapped group within dynamic radius (more robust for large pieces)
        if pieceGroup == nil {
            var best: (group: ConstructionGroup, dist: CGFloat, radius: CGFloat)?
            for g in constructionGroups {
                guard mappingService.mapping(for: g.id) != nil else { continue }
                let d = hypot(piece.position.x - g.centerOfMass.x, piece.position.y - g.centerOfMass.y)
                let dynRadius: CGFloat = max(160, g.boundingRadius + 120)
                if best == nil || d < best!.dist { best = (g, d, dynRadius) }
            }
            if let best = best, best.dist <= best.radius {
                pieceGroup = best.group
            }
        }
        
        if let group = pieceGroup {
            print("[VALIDATION] Group: \(group.pieces.count) pieces, confidence: \(String(format: "%.2f", group.confidence))")
        }
        
        // Only validate pieces in PLACED state or later
        guard var state = pieceStates[pieceId],
              state.state.canValidate else {
            return
        }
        
        // Begin validation
        state.beginValidation()
        pieceStates[pieceId] = state
        piece.pieceState = state
        piece.updateStateIndicator()
        
        // Get piece's current position in scene coordinates
        let pieceScenePos = physicalWorldSection.convert(piece.position, to: self)
        let degZ = piece.zRotation * 180 / .pi
        print("[PIECE] Validate request id=\(pieceId) type=\(pieceType.rawValue) pos=(\(Int(pieceScenePos.x)),\(Int(pieceScenePos.y))) rot=\(Int(degZ))° flipped=\(piece.isFlipped)")
        
        // Calculate feature angles for validation
        let localFeatureAngle = piece.userData?["localFeatureAngleSK"] as? CGFloat ?? 0
        let pieceFeatureAngle = piece.zRotation + localFeatureAngle
        
        // Mapping-based validation only (preferred realistic flow)
        if let group = pieceGroup {
            if tryAnchorBasedValidation(piece: piece, pieceType: pieceType, pieceId: pieceId,
                                        pieceScenePos: pieceScenePos, pieceFeatureAngle: pieceFeatureAngle,
                                        group: group, state: state, puzzle: puzzle) {
                return
            }
        }
        
        // Validation failed - handle failure
        handleValidationFailure(piece: piece, pieceType: pieceType, pieceId: pieceId,
                               pieceScenePos: pieceScenePos, pieceFeatureAngle: pieceFeatureAngle,
                               pieceGroup: pieceGroup, state: state, puzzle: puzzle)
    }
    
    // MARK: - Anchor-Based Validation
    
    private func tryAnchorBasedValidation(piece: PuzzlePieceNode, pieceType: TangramPieceType, pieceId: String,
                                         pieceScenePos: CGPoint, pieceFeatureAngle: CGFloat,
                                         group: ConstructionGroup, state: PieceState, puzzle: GamePuzzleData) -> Bool {
        // Establish or refresh per-group anchor mapping
        if mappingService.mapping(for: group.id) == nil {
            establishAnchorMapping(for: group, puzzle: puzzle)
        }
        
        guard let mapping = mappingService.mapping(for: group.id) else { return false }
        
        // Skip anchor piece mapped-validation
        if piece.name == mapping.anchorPieceId {
            print("[MAP] Skipping anchor piece mapped-validation id=\(pieceId)")
            return false
        }
        
        // Apply anchor transformation to get expected target position
        guard let anchorNode = availablePieces.first(where: { $0.name == mapping.anchorPieceId }) else { return false }
        let anchorScenePos = physicalWorldSection.convert(anchorNode.position, to: self)
        let rel = CGVector(dx: pieceScenePos.x - anchorScenePos.x, dy: pieceScenePos.y - anchorScenePos.y)
        let cosD = cos(mapping.rotationDelta)
        let sinD = sin(mapping.rotationDelta)
        let rotatedRel = CGVector(dx: rel.dx * cosD - rel.dy * sinD, dy: rel.dx * sinD + rel.dy * cosD)
        let mappedPosition = CGPoint(x: anchorScenePos.x + mapping.translationOffset.x + rotatedRel.dx,
                                     y: anchorScenePos.y + mapping.translationOffset.y + rotatedRel.dy)
        let mappedRotation = piece.zRotation + mapping.rotationDelta
        let mappedFlipped = mapping.flipParity ? !piece.isFlipped : piece.isFlipped
        
        // Find matching target
        let match = findBestMatchingTarget(piece: piece, pieceType: pieceType,
                                          mappedPosition: mappedPosition, mappedRotation: mappedRotation,
                                          mappedFlipped: mappedFlipped, group: group, puzzle: puzzle)
        
        if let match = match {
            // Bind piece to target if not already bound
            if piece.userData?["assignedTargetId"] as? String == nil {
                piece.userData?["assignedTargetId"] = match.target.id
                print("[BIND] Assigned piece id=\(pieceId) → target=\(match.target.id)")
            }
            
            // Enforce instance-binding
            if piece.userData?["assignedTargetId"] as? String != match.target.id {
                print("[VALIDATION] ❌ assignedTargetId mismatch")
                return false
            }
            
            // Validation successful!
            completeValidation(piece: piece, pieceType: pieceType, pieceId: pieceId,
                             target: match.target, group: group, mapping: mapping,
                             mappedPosition: mappedPosition, pieceFeatureAngle: pieceFeatureAngle,
                             state: state)
            return true
        }
        
        return false
    }
    
    // MARK: - Direct Validation
    
    private func tryDirectValidation(piece: PuzzlePieceNode, pieceType: TangramPieceType, pieceId: String,
                                    pieceScenePos: CGPoint, pieceFeatureAngle: CGFloat,
                                    pieceGroup: ConstructionGroup?, state: PieceState, puzzle: GamePuzzleData) -> Bool {
        // Gate direct validation by requiring at least 2 pieces in the group
        if let group = pieceGroup, group.pieces.count < 2 {
            eventBus.emit(.validationChanged(pieceId: pieceId, isValid: false))
            return false
        }
        
        let assignedId = piece.userData?["assignedTargetId"] as? String
        let groupTargetsConsumed = pieceGroup.map { mappingService.consumedTargets(groupId: $0.id) } ?? []
        let availableTargets: [GamePuzzleData.TargetPiece]
        
        if let assignedId = assignedId {
            availableTargets = puzzle.targetPieces.filter { $0.id == assignedId && !groupTargetsConsumed.contains($0.id) }
        } else {
            availableTargets = puzzle.targetPieces.filter { $0.pieceType == pieceType && !groupTargetsConsumed.contains($0.id) }
        }
        
        print("[DIRECT] Candidates for piece id=\(pieceId): \(availableTargets.map{ $0.id }.joined(separator: ","))")
        
        for target in availableTargets {
            guard targetSilhouettes[target.id] != nil else { continue }
            guard let tPose = resolvePose(for: target) else { continue }
            
            let targetScenePos = targetSection.convert(tPose.centroidInContainer, to: self)
            let targetRotation = tPose.zRotationSK
            let targetLocalFeature = pieceType.isTriangle ? (3 * CGFloat.pi / 4) : 0
            let targetFeatureAngle = targetRotation + targetLocalFeature
            
            let tolVals = currentValidationTolerances()
            let difficultyValidator = TangramPieceValidator(
                positionTolerance: tolVals.pos,
                rotationTolerance: tolVals.rotDeg,
                edgeContactTolerance: tolVals.edge
            )
            
            let result = difficultyValidator.validateForSpriteKitWithFeatures(
                piecePosition: pieceScenePos,
                pieceFeatureAngle: pieceFeatureAngle,
                targetFeatureAngle: targetFeatureAngle,
                pieceType: pieceType,
                isFlipped: piece.isFlipped,
                targetTransform: target.transform,
                targetWorldPos: targetScenePos
            )
            
            // Check polygon contact for position validation
            var isValid = result.rotationValid && result.flipValid
            var effectiveDistance = hypot(pieceScenePos.x - targetScenePos.x, pieceScenePos.y - targetScenePos.y)
            
            if effectiveDistance > tolVals.pos {
                let piecePoly = TangramGeometryUtilities.transformedVertices(
                    for: pieceType,
                    isFlipped: piece.isFlipped,
                    zRotation: piece.zRotation,
                    translation: pieceScenePos
                )
                let targetPoly = TangramBounds.computeSKTransformedVertices(for: target)
                let polyDist = TangramGeometryUtilities.minimumDistanceBetweenPolygons(piecePoly, targetPoly)
                if polyDist <= tolVals.edge { effectiveDistance = tolVals.pos - 1 }
            }
            
            isValid = isValid && (effectiveDistance <= tolVals.pos)
            
            // Additional gating: must be within connection distance
            let centerDistance = hypot(pieceScenePos.x - targetScenePos.x, pieceScenePos.y - targetScenePos.y)
            print("[DIRECT] Check target=\(target.id) dist=\(Int(centerDistance)) valid=\(isValid)")
            
            if isValid && centerDistance <= dynamicConnectionThreshold() {
                // Bind on first success if not yet assigned
                if piece.userData?["assignedTargetId"] as? String == nil {
                    piece.userData?["assignedTargetId"] = target.id
                    print("[BIND] Assigned piece id=\(pieceId) → target=\(target.id) [DIRECT]")
                } else if piece.userData?["assignedTargetId"] as? String != target.id {
                    print("[DIRECT] ❌ assignedTargetId mismatch")
                    continue
                }
                
                // Direct validation successful
                completeDirectValidation(piece: piece, pieceType: pieceType, pieceId: pieceId,
                                        target: target, pieceScenePos: pieceScenePos,
                                        pieceFeatureAngle: pieceFeatureAngle, pieceGroup: pieceGroup,
                                        state: state, puzzle: puzzle)
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Validation Completion
    
    private func completeValidation(piece: PuzzlePieceNode, pieceType: TangramPieceType, pieceId: String,
                                   target: GamePuzzleData.TargetPiece, group: ConstructionGroup,
                                   mapping: AnchorMapping,
                                   mappedPosition: CGPoint, pieceFeatureAngle: CGFloat, state: PieceState) {
        print("[VALIDATION] ✅ MAPPED piece=\(pieceId) type=\(pieceType.rawValue) → target=\(target.id)")
        
        mappingService.markTargetConsumed(groupId: group.id, targetId: target.id)
        validatedTargets.insert(target.id)
        onValidatedTargetsChanged?(validatedTargets)
        completedPieces.insert(target.id)
        
        var updatedState = state
        updatedState.markAsValidated(connections: [])
        pieceStates[pieceId] = updatedState
        piece.pieceState = updatedState
        piece.updateStateIndicator()
        
        // Update target visual
        if let targetNode = targetSilhouettes[target.id] {
            applyValidatedFill(to: targetNode, for: pieceType)
            
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            targetNode.run(pulse)
            showValidationCheckmark(over: targetNode)
        }
        
        // Store validation info
        piece.userData!["validatedTargetId"] = target.id
        lastValidPose[pieceId] = (position: mappedPosition, rotation: pieceFeatureAngle, targetId: target.id)
        mappingService.appendPair(groupId: group.id, pieceId: pieceId, targetId: target.id)
        
        // Refine mapping if we have enough pairs
        if mappingService.pairs(groupId: group.id).count >= 2,
           let anchorId = mapping.anchorPieceId as String?,
           let anchorTargetId = mapping.anchorTargetId as String? {
            _ = mappingService.refineMapping(
                groupId: group.id,
                pairs: mappingService.pairs(groupId: group.id),
                anchorPieceId: anchorId,
                anchorTargetId: anchorTargetId,
                pieceScenePosProvider: { pid in
                    self.availablePieces.first(where: { $0.name == pid }).map { self.physicalWorldSection.convert($0.position, to: self) }
                },
                targetScenePosProvider: { tid in
                    self.targetSilhouettes[tid].map {
                        let c = ($0.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                        return self.targetSection.convert(c, to: self)
                    }
                }
            )
            revalidateUnvalidatedPieces(in: group, excluding: pieceId)
        }
        
        // Also validate the anchor piece now
        validateAnchorPiece(mapping: mapping, group: group)
        
        showPieceCelebration(piece)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        eventBus.emit(.validationChanged(pieceId: target.id, isValid: true))
        onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
        
        // Check if puzzle complete
        if let puzzle = puzzle, completedPieces.count == puzzle.targetPieces.count {
            showPuzzleCompleteCelebration()
            onPuzzleCompleted?()
        }
        
        revalidateUnvalidatedPieces(in: group, excluding: pieceId)
    }
    
    private func completeDirectValidation(piece: PuzzlePieceNode, pieceType: TangramPieceType, pieceId: String,
                                         target: GamePuzzleData.TargetPiece, pieceScenePos: CGPoint,
                                         pieceFeatureAngle: CGFloat, pieceGroup: ConstructionGroup?,
                                         state: PieceState, puzzle: GamePuzzleData) {
        print("[VALIDATION] ✅ DIRECT piece=\(pieceId) type=\(pieceType.rawValue) → target=\(target.id)")
        
        validatedTargets.insert(target.id)
        completedPieces.insert(target.id)
        eventBus.emit(.validationChanged(pieceId: target.id, isValid: true))
        
        var updatedState = state
        updatedState.markAsValidated(connections: [])
        pieceStates[pieceId] = updatedState
        piece.pieceState = updatedState
        piece.updateStateIndicator()
        
        piece.userData!["validatedTargetId"] = target.id
        lastValidPose[pieceId] = (position: pieceScenePos, rotation: pieceFeatureAngle, targetId: target.id)
        
        if let group = pieceGroup {
            mappingService.markTargetConsumed(groupId: group.id, targetId: target.id)
        }
        
        // Update target visual
        if let targetNode = targetSilhouettes[target.id] {
            applyValidatedFill(to: targetNode, for: pieceType)
            
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            targetNode.run(pulse)
            showValidationCheckmark(over: targetNode)
        }
        
        showPieceCelebration(piece)
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Check if puzzle complete
        if completedPieces.count == puzzle.targetPieces.count {
            showPuzzleCompleteCelebration()
            onPuzzleCompleted?()
        }
        
        onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
    }
    
    // MARK: - Validation Failure
    
    private func handleValidationFailure(piece: PuzzlePieceNode, pieceType: TangramPieceType, pieceId: String,
                                        pieceScenePos: CGPoint, pieceFeatureAngle: CGFloat,
                                        pieceGroup: ConstructionGroup?, state: PieceState, puzzle: GamePuzzleData) {
        // Apply hysteresis before marking invalid
        if let last = lastValidPose[pieceId] {
            let tol = currentValidationTolerances()
            let posDelta = hypot(pieceScenePos.x - last.position.x, pieceScenePos.y - last.position.y)
            let rotDelta = abs(TangramRotationValidator.normalizeAngle(pieceFeatureAngle - last.rotation)) * 180 / .pi
            let relaxedPos = tol.pos * 1.5
            let relaxedRot = tol.rotDeg * 1.5
            
            if posDelta <= relaxedPos && rotDelta <= relaxedRot {
                eventBus.emit(.validationChanged(pieceId: pieceId, isValid: true))
                return
            }
        }
        
        let current = pieceInvalidStreak[pieceId] ?? 0
        let next = current + 1
        pieceInvalidStreak[pieceId] = next
        
        if let group = pieceGroup {
            groupManager.recordAttempt(in: group.id, pieceId: pieceId)
        }
        
        if next >= invalidStreakThreshold {
            var updatedState = state
            updatedState.markAsInvalid(reason: .wrongPosition(offset: 100))
            pieceStates[pieceId] = updatedState
            piece.pieceState = updatedState
            piece.updateStateIndicator()
            
            // Clear previous validation if any
            if let group = pieceGroup,
               let validatedId = piece.userData?["validatedTargetId"] as? String {
                mappingService.unmarkTargetConsumed(groupId: group.id, targetId: validatedId)
                validatedTargets.remove(validatedId)
                completedPieces.remove(validatedId)
                onValidatedTargetsChanged?(validatedTargets)
                
                if let tNode = targetSilhouettes[validatedId] {
                    tNode.fillColor = .clear
                    tNode.alpha = 1.0
                }
                
                piece.userData?["validatedTargetId"] = nil
                piece.userData?["assignedTargetId"] = nil
                mappingService.removePair(groupId: group.id, pieceId: pieceId, targetId: validatedId)
                lastValidPose.removeValue(forKey: pieceId)
            }
        } else {
            pieceStates[pieceId] = state
            piece.pieceState = state
            piece.updateStateIndicator()
        }
        
        // Record attempt and potentially show nudge
        nudgeManager.recordAttempt(for: pieceId, at: piece.position)
        
        if let group = pieceGroup {
            showSmartNudgeIfNeeded(piece: piece, pieceType: pieceType, pieceId: pieceId,
                                  pieceScenePos: pieceScenePos, pieceFeatureAngle: pieceFeatureAngle,
                                  group: group, puzzle: puzzle)
        }
        
        eventBus.emit(.validationChanged(pieceId: pieceId, isValid: false))
    }
    
    // MARK: - Helper Methods
    
    private func establishAnchorMapping(for group: ConstructionGroup, puzzle: GamePuzzleData) {
        let groupNodes = availablePieces.filter { node in
            guard let id = node.name else { return false }
            return group.pieces.contains(id)
        }
        
        let validatedNodes = groupNodes.filter { node in
            guard let id = node.name, let st = pieceStates[id] else { return false }
            if case .validated = st.state { return true }
            return false
        }
        
        let rankedAnchor: PuzzlePieceNode = validatedNodes.first ?? groupNodes.sorted { a, b in
            func rank(_ t: TangramPieceType?) -> Int {
                switch t {
                case .largeTriangle1, .largeTriangle2: return 3
                case .mediumTriangle: return 2
                case .square, .parallelogram: return 2
                case .smallTriangle1, .smallTriangle2: return 1
                default: return 0
                }
            }
            if rank(a.pieceType) != rank(b.pieceType) { return rank(a.pieceType) > rank(b.pieceType) }
            let c = group.centerOfMass
            let da = hypot(a.position.x - c.x, a.position.y - c.y)
            let db = hypot(b.position.x - c.x, b.position.y - c.y)
            return da < db
        }.first ?? availablePieces.first!
        
        if mappingService.mapping(for: group.id)?.anchorPieceId != rankedAnchor.name {
            let anchorType = rankedAnchor.pieceType ?? .square
            let anchorScenePos = physicalWorldSection.convert(rankedAnchor.position, to: self)
            
            let mapping = mappingService.establishOrUpdateMapping(
                groupId: group.id,
                groupPieceIds: group.pieces,
                pickAnchor: { () -> (anchorPieceId: String, anchorPositionScene: CGPoint, anchorRotation: CGFloat, anchorIsFlipped: Bool, anchorPieceType: TangramPieceType) in
                    let isFlipped = self.pieceStates[rankedAnchor.name ?? ""]?.isFlipped ?? false
                    return (rankedAnchor.name ?? "", anchorScenePos, rankedAnchor.zRotation, isFlipped, anchorType)
                },
                candidateTargets: { () -> [(target: GamePuzzleData.TargetPiece, centroidScene: CGPoint, expectedZ: CGFloat, isFlipped: Bool)] in
                    puzzle.targetPieces
                        .filter { $0.pieceType == anchorType && !self.mappingService.consumedTargets(groupId: group.id).contains($0.id) }
                        .compactMap { t in
                            guard let tNode = self.targetSilhouettes[t.id] else { return nil }
                            let centroid = (tNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                            let tScene = self.targetSection.convert(centroid, to: self)
                            let z = (tNode.userData?["expectedZRotationSK"] as? CGFloat) ?? 0
                            let flipped = (tNode.userData?["isFlipped"] as? Bool) ?? false
                            return (t, tScene, z, flipped)
                        }
                },
                minFeatureAgreementDeg: 45, // relax mapping acceptance to 45° feature agreement
                hasAnchorEdgeContact: { () -> Bool in
                    // Prefer true contact, but allow fallback when construction intent is strong or pieces are very close
                    let nodes = self.availablePieces.filter { n in
                        guard let id = n.name else { return false }
                        return group.pieces.contains(id)
                    }
                    guard let anchor = nodes.first(where: { $0.name == rankedAnchor.name }) else { return false }
                    var minPolyDist: CGFloat = .greatestFiniteMagnitude
                    var minCentroidDist: CGFloat = .greatestFiniteMagnitude
                    for n in nodes where n !== anchor {
                        minPolyDist = min(minPolyDist, self.groupManager.minimumPolygonDistance(between: anchor, and: n))
                        let cDist = hypot(anchor.position.x - n.position.x, anchor.position.y - n.position.y)
                        minCentroidDist = min(minCentroidDist, cDist)
                    }
                    let contact = (minPolyDist <= 16)
                    let centroidClose = (minCentroidDist <= 110)
                    let strongIntent = (group.confidence >= 0.55)
                    return contact || centroidClose || strongIntent
                }
            )
            
            if let m = mapping {
                rankedAnchor.userData?["assignedTargetId"] = m.anchorTargetId
                // Record the anchor→target pair for future refinement, but do NOT auto-validate the anchor yet.
                // We only validate the anchor after at least one additional piece validates via mapping.
                mappingService.appendPair(groupId: group.id, pieceId: rankedAnchor.name ?? "", targetId: m.anchorTargetId)
                // Revalidate the rest of the unvalidated pieces in this group using the new mapping
                revalidateUnvalidatedPieces(in: group, excluding: rankedAnchor.name)
            }
        }
    }
    
    private func findBestMatchingTarget(piece: PuzzlePieceNode, pieceType: TangramPieceType,
                                       mappedPosition: CGPoint, mappedRotation: CGFloat, mappedFlipped: Bool,
                                       group: ConstructionGroup, puzzle: GamePuzzleData) -> (target: GamePuzzleData.TargetPiece, distance: CGFloat)? {
        let assignedId = piece.userData?["assignedTargetId"] as? String
        let availableTargets: [GamePuzzleData.TargetPiece]
        
        if let assignedId = assignedId {
            availableTargets = puzzle.targetPieces.filter { $0.id == assignedId && !mappingService.consumedTargets(groupId: group.id).contains($0.id) }
        } else {
            availableTargets = puzzle.targetPieces.filter { $0.pieceType == pieceType && !mappingService.consumedTargets(groupId: group.id).contains($0.id) }
        }
        
        var bestMatch: (target: GamePuzzleData.TargetPiece, distance: CGFloat)?
        
        for target in availableTargets {
            guard targetSilhouettes[target.id] != nil else { continue }
            guard let targetPose = resolvePose(for: target) else { continue }
            
            let targetScenePos = targetSection.convert(targetPose.centroidInContainer, to: self)
            let distance = hypot(mappedPosition.x - targetScenePos.x, mappedPosition.y - targetScenePos.y)
            
            let canonicalTarget: CGFloat = pieceType.isTriangle ? (.pi/4) : 0
            let canonicalPiece: CGFloat = pieceType.isTriangle ? (3 * .pi/4) : 0
            let targetFeatureAngle = TangramRotationValidator.normalizeAngle(targetPose.zRotationSK + canonicalTarget)
            let pieceFeatureAngle = TangramRotationValidator.normalizeAngle(mappedRotation + (mappedFlipped ? -canonicalPiece : canonicalPiece))
            
            let tolVals = currentValidationTolerances()
            let difficultyValidator = TangramPieceValidator(
                positionTolerance: tolVals.pos,
                rotationTolerance: tolVals.rotDeg,
                edgeContactTolerance: tolVals.edge
            )
            
            let res = difficultyValidator.validateForSpriteKitWithFeatures(
                piecePosition: mappedPosition,
                pieceFeatureAngle: pieceFeatureAngle,
                targetFeatureAngle: targetFeatureAngle,
                pieceType: pieceType,
                isFlipped: mappedFlipped,
                targetTransform: target.transform,
                targetWorldPos: targetScenePos
            )
            
            var effectiveDistance = distance
            if effectiveDistance > tolVals.pos {
                let piecePoly = TangramGeometryUtilities.transformedVertices(
                    for: pieceType,
                    isFlipped: mappedFlipped,
                    zRotation: mappedRotation,
                    translation: mappedPosition
                )
                let targetPoly = TangramBounds.computeSKTransformedVertices(for: target)
                let polyDist = TangramGeometryUtilities.minimumDistanceBetweenPolygons(piecePoly, targetPoly)
                if polyDist <= tolVals.edge { effectiveDistance = tolVals.pos - 1 }
            }
            
            let isValid = res.rotationValid && res.flipValid && (effectiveDistance <= tolVals.pos)
            
            if isValid {
                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (target, distance)
                }
            }
        }
        
        return bestMatch
    }
    
    private func validateAnchorPiece(mapping: AnchorMapping, group: ConstructionGroup) {
        guard let anchorNode = availablePieces.first(where: { $0.name == mapping.anchorPieceId }),
              let anchorId = anchorNode.name,
              let anchorType = anchorNode.pieceType else { return }
        
        let existing = pieceStates[anchorId]
        var aState = existing ?? PieceState(pieceId: anchorId, pieceType: anchorType)
        
        if case .validated = aState.state {
            return // Already validated
        }
        
        // Guard: only validate anchor if there's at least one additional validated pair in this group
        let pairs = mappingService.pairs(groupId: group.id)
        if pairs.filter({ $0.pieceId != anchorId && $0.targetId != mapping.anchorTargetId }).isEmpty {
            // Defer anchor validation until another piece validates via mapping
            return
        }
        print("[VALIDATION] ✅ ANCHOR piece=\(anchorId) type=\(anchorType.rawValue) → target=\(mapping.anchorTargetId)")
        aState.markAsValidated(connections: [])
        pieceStates[anchorId] = aState
        anchorNode.pieceState = aState
        anchorNode.userData?["validatedTargetId"] = mapping.anchorTargetId
        validatedTargets.insert(mapping.anchorTargetId)
        onValidatedTargetsChanged?(validatedTargets)
        completedPieces.insert(mapping.anchorTargetId)
        
        if let tNode = targetSilhouettes[mapping.anchorTargetId] {
            applyValidatedFill(to: tNode, for: anchorType)
            // Defensive: remove any lingering red/outline styles and hint overlays
            tNode.strokeColor = TangramColors.Sprite.uiColor(for: anchorType)
            tNode.lineWidth = 2
            // Remove any nudge overlays for this target
            let nudgeName = "nudge_\(tNode.name ?? "")"
            targetSection.childNode(withName: nudgeName)?.removeFromParent()
            if let container = targetSection.childNode(withName: "puzzleContainer") {
                container.childNode(withName: nudgeName)?.removeFromParent()
            }
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            tNode.run(pulse)
            showValidationCheckmark(over: tNode)
        }
        
        eventBus.emit(.validationChanged(pieceId: mapping.anchorTargetId, isValid: true))
    }
    
    private func showSmartNudgeIfNeeded(piece: PuzzlePieceNode, pieceType: TangramPieceType, pieceId: String,
                                       pieceScenePos: CGPoint, pieceFeatureAngle: CGFloat,
                                       group: ConstructionGroup, puzzle: GamePuzzleData) {
        var shouldNudge = nudgeManager.shouldShowNudge(for: piece, in: group)
        
        // If parallelogram and near-correct except flip, force a flip-specific nudge even on first attempt
        if pieceType == .parallelogram {
            let tol = currentValidationTolerances()
            // Try to derive failure reason even if not validated yet
            if let target = puzzle.targetPieces.first(where: { $0.pieceType == pieceType && !validatedTargets.contains($0.id) }) {
                let tPose = resolvePose(for: target)
                let targetScenePos = tPose.map { targetSection.convert($0.centroidInContainer, to: self) } ?? .zero
                let detailed = mappingService.validateMappedDetailed(
                    mappedPose: (pos: pieceScenePos, rot: pieceFeatureAngle, isFlipped: piece.isFlipped),
                    pieceType: pieceType,
                    target: target,
                    targetCentroidScene: targetScenePos,
                    validator: TangramPieceValidator(
                        positionTolerance: tol.pos,
                        rotationTolerance: tol.rotDeg,
                        edgeContactTolerance: tol.edge
                    )
                )
                if detailed.failure == .needsFlip {
                    shouldNudge = true
                }
            }
        }
        guard shouldNudge else { return }
        
        let nudgeLevel = nudgeManager.determineNudgeLevel(
            confidence: group.confidence,
            attempts: group.attemptHistory[pieceId] ?? 0,
            state: group.validationState
        )
        
        // Find a target to nudge towards
        if let target = puzzle.targetPieces.first(where: {
            $0.pieceType == pieceType && !validatedTargets.contains($0.id)
        }), let targetNode = targetSilhouettes[target.id] {
            let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
            let targetPosPhysical = targetSection.convert(targetCentroid, to: physicalWorldSection)
            let tPose = resolvePose(for: target)
            let targetScenePos = tPose.map { targetSection.convert($0.centroidInContainer, to: self) } ?? .zero
            let targetRotation = tPose?.zRotationSK ?? 0
            let canonicalTarget: CGFloat = pieceType.isTriangle ? (.pi/4) : 0
            let canonicalPiece: CGFloat = pieceType.isTriangle ? (3 * .pi/4) : 0
            let desiredZ = TangramRotationValidator.normalizeAngle(targetRotation + canonicalTarget - canonicalPiece)
            
            let detailed = mappingService.validateMappedDetailed(
                mappedPose: (pos: pieceScenePos, rot: pieceFeatureAngle, isFlipped: piece.isFlipped),
                pieceType: pieceType,
                target: target,
                targetCentroidScene: targetScenePos,
                validator: validator
            )
            
            let centerDistance = hypot(pieceScenePos.x - targetScenePos.x, pieceScenePos.y - targetScenePos.y)
            let failureReason: ValidationFailure = detailed.failure ?? .wrongPosition(offset: centerDistance)
            
            let effectiveLevel: NudgeLevel = {
                switch failureReason {
                case .wrongRotation, .needsFlip: return max(nudgeLevel, .specific)
                default: return nudgeLevel
                }
            }()
            
            let promoteDirected = (centerDistance < 140) && (failureReason == .wrongPosition(offset: centerDistance))
            var levelToUse: NudgeLevel = promoteDirected ? max(effectiveLevel, .directed) : effectiveLevel
            // Elevate flip-needed nudges to specific for clarity
            if failureReason == .needsFlip {
                levelToUse = max(levelToUse, .specific)
            }
            
            let nudgeContent = nudgeManager.generateNudge(
                level: levelToUse,
                failure: failureReason,
                targetInfo: (position: targetPosPhysical, rotation: desiredZ)
            )
            
            showSmartNudgeInTarget(targetNode: targetNode, content: nudgeContent, pieceType: pieceType)
            nudgeManager.recordNudgeShown(for: pieceId)
        }
    }
    
    // MARK: - Internal Helpers (referenced from main scene)
    
    internal func currentValidationTolerances() -> (pos: CGFloat, rotDeg: CGFloat, edge: CGFloat) {
        let tol = TangramGameConstants.Validation.tolerances(for: difficultySetting)
        return (tol.position, tol.rotationDeg, tol.edgeContact)
    }
    
    internal func dynamicConnectionThreshold() -> CGFloat {
        let tol = TangramGameConstants.Validation.tolerances(for: difficultySetting)
        return tol.connection
    }
    
    internal func revalidateUnvalidatedPieces(in group: ConstructionGroup, excluding excludeId: String?) {
        for pieceId in group.pieces {
            guard pieceId != excludeId,
                  let piece = availablePieces.first(where: { $0.name == pieceId }),
                  let state = pieceStates[pieceId] else { continue }
            
            switch state.state {
            case .placed, .validating:
                validatePlacedPiece(piece)
            case .invalid:
                // After mapping creation/refinement or another piece validation, retry invalid pieces in the group
                validatePlacedPiece(piece)
            default:
                break
            }
        }
    }
    
    internal func resolvePose(for target: GamePuzzleData.TargetPiece) -> (centroidInContainer: CGPoint, zRotationSK: CGFloat)? {
        guard let targetNode = targetSilhouettes[target.id] else { return nil }
        let centroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
        let zRotation = (targetNode.userData?["expectedZRotationSK"] as? CGFloat) ?? 0
        return (centroid, zRotation)
    }
}