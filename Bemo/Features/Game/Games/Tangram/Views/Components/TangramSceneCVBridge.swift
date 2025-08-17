//
//  TangramSceneCVBridge.swift
//  Bemo
//
//  Handles CV event subscription and rendering for TangramPuzzleScene
//

// WHAT: Bridge between CV events and scene visualization, manages mini CV display
// ARCHITECTURE: Component of TangramPuzzleScene handling CV event processing and rendering
// USAGE: Subscribes to CV events and updates the mini CV display in top-right corner

import SpriteKit
import Foundation

extension TangramPuzzleScene {
    
    // MARK: - Event Subscription
    
    func subscribeToEvents() {
        // Subscribe to individual events
        eventSubscriptionId = eventBus.subscribe { [weak self] event in
            self?.handleCVEvent(event)
        }
        
        // Subscribe to frame events for CV render
        frameSubscriptionId = eventBus.subscribeToFrames { [weak self] frame in
            self?.updateCVRender(frame)
        }
    }
    
    // MARK: - CV Event Handling
    
    private func handleCVEvent(_ event: TangramCVEvent) {
        switch event {
        case .validationChanged(let pieceIdOrTargetId, let isValid):
            updateTargetValidation(pieceId: pieceIdOrTargetId, isValid: isValid)
            // For CV mini display, map target ids to piece ids if needed
            let mappedPieceId: String? = {
                // If cvPieces already contains this id, use it directly
                if cvPieces[pieceIdOrTargetId] != nil { return pieceIdOrTargetId }
                // Otherwise find the piece that validated against this target id
                for node in availablePieces {
                    if let vid = node.userData?["validatedTargetId"] as? String, vid == pieceIdOrTargetId {
                        return node.name
                    }
                }
                return nil
            }()
            if let pid = mappedPieceId {
                showCVValidationFeedback(pieceId: pid, isValid: isValid)
            }
            
        case .pieceFlipped(let id, _):
            // Update CV display when piece is flipped
            if let cvNode = cvPieces[id] as? PuzzlePieceNode,
               let physicalPiece = availablePieces.first(where: { $0.name == id }) {
                if cvNode.isFlipped != physicalPiece.isFlipped {
                    cvNode.flip()
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - CV Frame Rendering
    
    private func updateCVRender(_ frame: CVFrameEvent) {
        // Schedule validation only when the frame meaningfully changed
        if let bridge = validationBridge {
            if userData == nil { userData = NSMutableDictionary() }
            // Build a quantized signature of the frame (pieceId|x|y|rot) sorted
            let items: [String] = frame.objects.map { obj in
                let pid = pieceIdFromCVName(obj.name)
                let x = Int((obj.pose.translation.first ?? 0).rounded())
                let y = Int((obj.pose.translation.dropFirst().first ?? 0).rounded())
                let r = Int(obj.pose.rotationDegrees.rounded())
                return "\(pid)|\(x)|\(y)|\(r)"
            }.sorted()
            let signature = items.joined(separator: ",")
            let lastSignature = userData?["lastCVSignature"] as? String
            if lastSignature != signature {
                userData?["lastCVSignature"] = signature
                Task { @MainActor in
                    // Small delay to batch multiple frame updates
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    bridge.validateAllPieces()
                }
            }
        }
        
        // If we have an established anchor mapping, render non-validated pieces in target-space
        if let mapping = userData?["mainGroupMapping"] as? AnchorMapping,
           let anchorId = userData?["mainAnchorPieceId"] as? String,
           let anchorNode = availablePieces.first(where: { $0.name == anchorId }),
           let container = targetSection.childNode(withName: "puzzleContainer") {
            // Hide the generic physical mirror to avoid duplicates
            topMirrorContent?.isHidden = true
            let anchorScenePos = physicalWorldSection.convert(anchorNode.position, to: self)
            var usedOverlayNames: Set<String> = []
            for piece in availablePieces {
                guard let pid = piece.name, let ptype = piece.pieceType else { continue }
                // Skip pieces that have already validated (they are shown via filled silhouette)
                if piece.userData?["validatedTargetId"] != nil {
                    if let existing = container.childNode(withName: "mapped_\(pid)") { existing.removeFromParent() }
                    continue
                }
                // Map physical scene pose → SK target space using committed mapping
                let scenePos = physicalWorldSection.convert(piece.position, to: self)
                let mapped = mappingService.mapPieceToTargetSpace(
                    piecePositionScene: scenePos,
                    pieceRotation: piece.zRotation,
                    pieceIsFlipped: piece.isFlipped,
                    mapping: mapping,
                    anchorPositionScene: anchorScenePos
                )
                // Convert SK target space → puzzleContainer local coordinates
                let localPos: CGPoint = {
                    // Place directly at mapped SK position relative to the silhouette container (same math as silhouettes)
                    let x = (mapped.positionSK.x - puzzleBoundsCenterSK.x) * targetDisplayScale
                    let y = (mapped.positionSK.y - puzzleBoundsCenterSK.y) * targetDisplayScale
                    return CGPoint(x: x, y: y)
                }()
                let nodeName = "mapped_\(pid)"
                var ghost = container.childNode(withName: nodeName) as? SKShapeNode
                if ghost == nil {
                    ghost = createGhostPiece(pieceType: ptype, at: localPos, rotation: mapped.rotationSK)
                    ghost?.name = nodeName
                    // Slightly lighter than validated fill
                    ghost?.alpha = 0.25
                    container.addChild(ghost!)
                } else {
                    ghost?.position = localPos
                    ghost?.zRotation = mapped.rotationSK
                }
                // Apply flip parity in container
                if let g = ghost {
                    // Ghost paths are centroid-anchored; apply flip by xScale sign only
                    g.xScale = (mapped.isFlipped ? -abs(g.xScale) : abs(g.xScale))
                    g.yScale = abs(g.yScale)
                }
                usedOverlayNames.insert(nodeName)
            }
            // Clean up overlays for pieces no longer needed
            container.enumerateChildNodes(withName: "mapped_*") { node, _ in
                if let name = node.name, !usedOverlayNames.contains(name) { node.removeFromParent() }
            }
            return
        } else {
            // No mapping yet → show physical mirror and remove any mapped overlays
            topMirrorContent?.isHidden = false
            if let container = targetSection.childNode(withName: "puzzleContainer") {
                container.enumerateChildNodes(withName: "mapped_*") { node, _ in node.removeFromParent() }
            }
        }

        // Mirror CV-detected pieces directly into top panel
        let mirror = topMirrorContent!
        let topSize = CGSize(width: targetBounds.width, height: targetBounds.height)
        guard topSize.width > 0, topSize.height > 0 else { return }
        // Reference view size must match adapter/pipeline
        let ref = CGSize(width: 1080, height: 1920)
        let sx = topSize.width / ref.width
        let sy = topSize.height / ref.height
        let uniform = min(sx, sy)
        topMirrorContent.setScale(uniform)
        topMirrorContent.position = .zero
        for object in frame.objects {
            let pieceId = pieceIdFromCVName(object.name)
            let nodeName = "mirror_\(pieceId)"
            var ghost = mirror.childNode(withName: nodeName) as? SKShapeNode

            // Resolve type directly from classId mapping
            let resolvedType: TangramPieceType = {
                switch object.classId {
                case 0: return .parallelogram
                case 1: return .square
                case 2: return .largeTriangle1
                case 3: return .largeTriangle2
                case 4: return .mediumTriangle
                case 5: return .smallTriangle1
                case 6: return .smallTriangle2
                default: return .smallTriangle1
                }
            }()
            let isFlippedPiece = false

            if ghost == nil {
                ghost = createGhostPiece(pieceType: resolvedType, at: CGPoint.zero, rotation: 0)
                ghost?.name = nodeName
                mirror.addChild(ghost!)
            }
            guard let g = ghost else { continue }

            // Position mapping phys → scene → targetSection → scaled into mirror
            let pos = CGPoint(
                x: object.pose.translation.first ?? 0,
                y: object.pose.translation.dropFirst().first ?? 0
            )
            g.position = pos
            g.setScale(1.0)
            // Apply flip parity with the physical piece
            g.xScale = isFlippedPiece ? -abs(g.xScale) : abs(g.xScale)
            // Rotation
            g.zRotation = CGFloat(object.pose.rotationDegrees) * .pi / 180

            // Base visual at 10–20% (use 0.2 = 20% for tracked mirror)
            var fillAlpha: CGFloat = 0.2
            // Orientation-only correctness bumps to 40% and triggers top checkmark once
            if let puz = puzzle {
                // Compute feature angle for piece
                let pieceRad = CGFloat(object.pose.rotationDegrees) * .pi / 180
                let canonicalPiece: CGFloat = resolvedType.isTriangle ? (3 * .pi / 4) : 0
                let pieceFeature = TangramRotationValidator.normalizeAngle(
                    pieceRad + (isFlippedPiece ? -canonicalPiece : canonicalPiece)
                )
                // Check against same-type targets
                let targets = puz.targetPieces.filter { $0.pieceType == resolvedType }
                for t in targets {
                    let raw = TangramPoseMapper.rawAngle(from: t.transform)
                    let targRot = TangramPoseMapper.spriteKitAngle(fromRawAngle: raw)
                    let canonicalTarget: CGFloat = resolvedType.isTriangle ? (.pi / 4) : 0
                    let targetFeature = TangramRotationValidator.normalizeAngle(targRot + canonicalTarget)
                    let symDiff = TangramRotationValidator.rotationDifferenceToNearest(
                        currentRotation: pieceFeature,
                        targetRotation: targetFeature,
                        pieceType: resolvedType,
                        isFlipped: isFlippedPiece
                    )
                    let deltaDeg = abs(symDiff) * 180 / .pi
                    var flipOK = true
                    if resolvedType == .parallelogram {
                        let det = t.transform.a * t.transform.d - t.transform.b * t.transform.c
                        let targetIsFlipped = det < 0
                        flipOK = (isFlippedPiece != targetIsFlipped)
                    }
                    if deltaDeg <= 5.0 && flipOK {
                        fillAlpha = 0.4
                        break
                    }
                }
            }
            // Apply color matching the physical piece's type with lower fill
            g.fillColor = TangramColors.Sprite.uiColor(for: resolvedType).withAlphaComponent(fillAlpha)
            g.strokeColor = TangramColors.Sprite.uiColor(for: resolvedType).withAlphaComponent(0.5)
            g.lineWidth = 1.0

            // No checkmark overlays; fillAlpha is the only orientation feedback here
        }

        // Mini CV display removed; no dedicated per-piece CV rendering below
    }
    
    // updateCVPiece removed with mini display
    
    // Note: createCVVisualization is implemented in TangramScenePieceFactory extension
    
    // MARK: - CV Visual Feedback
    
    private func updateCVShapeVisualState(_ shape: SKShapeNode, pieceType: TangramPieceType, state: PieceState) {
        switch state.state {
        case .validated:
            shape.alpha = 1.0
            shape.fillColor = shape.fillColor.withAlphaComponent(1.0)
            shape.strokeColor = .systemGreen
            shape.lineWidth = 3
        case .invalid:
            shape.alpha = 0.8
            shape.strokeColor = .systemRed
            shape.lineWidth = 2
        case .validating:
            shape.alpha = 0.9
            shape.strokeColor = .systemYellow
            shape.lineWidth = 2
        default:
            shape.alpha = 0.7
            shape.strokeColor = TangramColors.Sprite.uiColor(for: pieceType).darker(by: 20)
            shape.lineWidth = 2
        }
    }
    
    private func showCVValidationFeedback(pieceId: String, isValid: Bool) {
        guard let cvNode = cvPieces[pieceId] else { return }
        
        // Create validation feedback
        let feedbackNode = SKShapeNode(circleOfRadius: 8)
        feedbackNode.fillColor = isValid ? .systemGreen : .systemRed
        feedbackNode.strokeColor = .clear
        feedbackNode.alpha = 0.8
        feedbackNode.position = cvNode.position
        feedbackNode.zPosition = cvNode.zPosition + 10
        
        // Mini CV display removed; no parent container for dedicated CV content
        
        // Animate feedback
        let expand = SKAction.scale(to: 2, duration: 0.3)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        feedbackNode.run(SKAction.sequence([
            SKAction.group([expand, fade]),
            remove
        ]))
        
        // Update piece visual state if it's a PuzzlePieceNode
        if let cvPuzzlePiece = cvNode as? PuzzlePieceNode,
           let shape = cvPuzzlePiece.shapeNode {
            shape.strokeColor = isValid ? .systemGreen : .systemRed
            shape.lineWidth = isValid ? 3 : 2
        }
    }
    
    private func updateTargetValidation(pieceId: String, isValid: Bool) {
        // Update target silhouette based on validation state
        // This is called from CV events
        
        // Find the target that matches this piece
        guard let physicalPiece = availablePieces.first(where: { $0.name == pieceId }),
              let targetId = physicalPiece.userData?["validatedTargetId"] as? String,
              let targetNode = targetSilhouettes[targetId] else {
            return
        }
        
        if isValid {
            // Piece is valid - update target appearance
            if let pieceType = physicalPiece.pieceType {
                targetNode.fillColor = TangramColors.Sprite.uiColor(for: pieceType).withAlphaComponent(0.5)
            }
        } else {
            // Piece is invalid - reset target appearance
            targetNode.fillColor = .clear
        }
    }
    
    // MARK: - CV Frame Emission
    
    func emitCVFrameUpdate() {
        // Mini display disabled; still emit frame for engine processing
        var cvObjects: [CVPieceEvent] = []
        
        for piece in availablePieces {
            guard let pieceId = piece.name,
                  let state = pieceStates[pieceId] else { continue }
            
            // Only emit pieces that have been moved or placed
            switch state.state {
            case .moved, .placed, .validating, .validated, .invalid:
                // Create CV event with required fields
                let pose = CVPieceEvent.Pose(
                    rotationDegrees: piece.zRotation * 180 / .pi,
                    translation: [Double(piece.position.x), Double(piece.position.y)]
                )
                
                let vertices = calculateVertices(for: piece)
                let classId = classIdFromPieceType(piece.pieceType ?? .square)
                
                let cvEvent = CVPieceEvent(
                    name: "cv_\(pieceId)",
                    classId: classId,
                    pose: pose,
                    vertices: vertices
                )
                cvObjects.append(cvEvent)
            default:
                break
            }
        }
        
        // Create frame with objects
        let frame = CVFrameEvent(objects: cvObjects)
        
        eventBus.emitFrame(frame)
    }
    
    // MARK: - Helper Methods
    
    private func calculateVertices(for piece: PuzzlePieceNode) -> [[Double]] {
        guard let pieceType = piece.pieceType else { return [] }
        
        // Get normalized vertices
        let vertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        
        // Apply piece transform and scale
        let transformed = vertices.map { vertex in
            let scaled = CGPoint(x: vertex.x * TangramGameConstants.visualScale, y: vertex.y * TangramGameConstants.visualScale)
            let rotated = scaled.applying(CGAffineTransform(rotationAngle: piece.zRotation))
            let translated = CGPoint(x: rotated.x + piece.position.x, y: rotated.y + piece.position.y)
            return [Double(translated.x), Double(translated.y)]
        }
        
        return transformed
    }
    
    private func classIdFromPieceType(_ type: TangramPieceType) -> Int {
        switch type {
        case .smallTriangle1, .smallTriangle2: return 0
        case .mediumTriangle: return 1
        case .largeTriangle1, .largeTriangle2: return 2
        case .square: return 3
        case .parallelogram: return 4
        }
    }
    
    func pieceIdFromCVName(_ cvName: String) -> String {
        // Convert CV piece name to standard piece ID
        // e.g., "cv_piece_square" -> "piece_square"
        if cvName.hasPrefix("cv_") {
            return String(cvName.dropFirst(3))
        }
        return cvName
    }
    
    // MARK: - Cleanup
    
    func unsubscribeFromEvents() {
        if let subId = eventSubscriptionId {
            eventBus.unsubscribe(subId)
            eventSubscriptionId = nil
        }
        // Frame unsubscription handled through regular unsubscribe
        frameSubscriptionId = nil
    }
}