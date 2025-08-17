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
        
        // Disable anchor/mapped overlay path for now; always show CV mirror
        topMirrorContent?.isHidden = false

        // Mirror CV-detected pieces directly into top panel
        let mirror = topMirrorContent!
        let topSize = CGSize(width: targetBounds.width, height: targetBounds.height)
        guard topSize.width > 0, topSize.height > 0 else { return }
        // Do not scale container; map CV points explicitly using homography → target coords
        topMirrorContent.setScale(1.0)
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

            // Map CV pixel coords; use simple mapping unless tuning enables homography
            let px = CGFloat(object.pose.translation.first ?? 0)
            let py = CGFloat(object.pose.translation.dropFirst().first ?? 0)
            let mapped: CGPoint = {
                if TangramCVTuning.shared.useHomography {
                    return mapCVToTarget(cvX: px, cvY: py, frame: frame, targetSize: topSize)
                } else {
                    let ref = CGSize(width: 1080, height: 1920)
                    return CGPoint(x: (px / ref.width - 0.5) * topSize.width,
                                   y: (py / ref.height - 0.5) * topSize.height)
                }
            }()
            let now = CACurrentMediaTime()

            // Smoothing + threshold gating
            let last = cvSmoothedPose[pieceId]?.pos ?? mapped
            let lastRot = cvSmoothedPose[pieceId]?.rot ?? 0
            let rotRad = CGFloat(object.pose.rotationDegrees) * .pi / 180
            let alpha = cvRenderConfig.smoothingAlpha
            let blendedPos = CGPoint(x: last.x * (1 - alpha) + mapped.x * alpha,
                                     y: last.y * (1 - alpha) + mapped.y * alpha)
            let blendedRot = lastRot * (1 - alpha) + rotRad * alpha
            let moved = hypot(blendedPos.x - g.position.x, blendedPos.y - g.position.y) > cvRenderConfig.positionThreshold
            let rotChanged = abs((blendedRot - g.zRotation) * 180 / .pi) > cvRenderConfig.rotationThresholdDeg
            // Stability gate: apply only after N consecutive frames
            let required = 3
            let key = "stable_\(pieceId)"
            var count = (userData?[key] as? Int) ?? 0
            if moved || rotChanged {
                count += 1
                if count >= required {
                    if moved { g.position = blendedPos }
                    if rotChanged { g.zRotation = blendedRot }
                    count = 0
                }
            } else {
                count = 0
            }
            if userData == nil { userData = NSMutableDictionary() }
            userData?[key] = count
            cvSmoothedPose[pieceId] = (blendedPos, blendedRot)
            cvLastSeenAt[pieceId] = now
            g.isHidden = false
            g.setScale(1.0)
            // Flip parity disabled until we detect flip
            g.xScale = abs(g.xScale)

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
            // Enforce canonical shape size for each piece type; do not use distorted vertices
            let shapeNode = g
            let canonical = TangramGameGeometry.normalizedVertices(for: resolvedType)
            let scaled = TangramGameGeometry.scaleVertices(canonical, by: TangramGameConstants.visualScale)
            let centroid = TangramGameGeometry.centerOfVertices(scaled)
            let path = CGMutablePath()
            if let first = scaled.first {
                path.move(to: CGPoint(x: first.x - centroid.x, y: first.y - centroid.y))
                for v in scaled.dropFirst() {
                    path.addLine(to: CGPoint(x: v.x - centroid.x, y: v.y - centroid.y))
                }
                path.closeSubpath()
            }
            shapeNode.path = path
            // Apply color matching the piece type with lower fill
            g.fillColor = TangramColors.Sprite.uiColor(for: resolvedType).withAlphaComponent(fillAlpha)
            g.strokeColor = TangramColors.Sprite.uiColor(for: resolvedType).withAlphaComponent(0.5)
            g.lineWidth = 1.0
        }

        // Hide ghosts that have not been seen recently
        let now = CACurrentMediaTime()
        mirror.enumerateChildNodes(withName: "mirror_*") { [weak self] node, _ in
            guard let strongSelf = self else { return }
            let id = String(node.name?.dropFirst(7) ?? "")
            if let last = strongSelf.cvLastSeenAt[id] {
                node.isHidden = (now - last) > strongSelf.cvRenderConfig.lingerSeconds
            } else {
                node.isHidden = true
            }
        }

        // Mini CV display removed; no dedicated per-piece CV rendering below
    }

    // MARK: - Homography Mapping
    private func mapCVToTarget(cvX: CGFloat, cvY: CGFloat, frame: CVFrameEvent, targetSize: CGSize) -> CGPoint {
        // Homography: maps from plane↔camera. We treat input as camera pixels in reference space and apply inverse of H.
        // Frame.homography is 3x3 in row-major order. We’ll compute inverse and map to plane coordinates, then center/scale into target.
        let H = frame.homography
        guard H.count == 3, H[0].count == 3 else {
            // Fallback to simple reference mapping
            let ref = CGSize(width: 1080, height: 1920)
            return CGPoint(x: (cvX / ref.width - 0.5) * targetSize.width,
                           y: (cvY / ref.height - 0.5) * targetSize.height)
        }
        // Build matrix and inverse
        let h00 = H[0][0], h01 = H[0][1], h02 = H[0][2]
        let h10 = H[1][0], h11 = H[1][1], h12 = H[1][2]
        let h20 = H[2][0], h21 = H[2][1], h22 = H[2][2]

        let det = h00*(h11*h22 - h12*h21) - h01*(h10*h22 - h12*h20) + h02*(h10*h21 - h11*h20)
        if abs(det) < 1e-9 {
            let ref = CGSize(width: 1080, height: 1920)
            return CGPoint(x: (cvX / ref.width - 0.5) * targetSize.width,
                           y: (cvY / ref.height - 0.5) * targetSize.height)
        }
        let inv00 =  (h11*h22 - h12*h21) / det
        let inv01 = -(h01*h22 - h02*h21) / det
        let inv02 =  (h01*h12 - h02*h11) / det
        let inv10 = -(h10*h22 - h12*h20) / det
        let inv11 =  (h00*h22 - h02*h20) / det
        let inv12 = -(h00*h12 - h02*h10) / det
        let inv20 =  (h10*h21 - h11*h20) / det
        let inv21 = -(h00*h21 - h01*h20) / det
        let inv22 =  (h00*h11 - h01*h10) / det

        // Apply inverse homography to camera point (cvX, cvY, 1)
        let x = Double(cvX), y = Double(cvY)
        let X = inv00*x + inv01*y + inv02*1.0
        let Y = inv10*x + inv11*y + inv12*1.0
        let W = inv20*x + inv21*y + inv22*1.0
        let nx = CGFloat(X / W)
        let ny = CGFloat(Y / W)

        // Normalize plane coords into target section (centered). We assume plane ranges are similar to reference pixels; apply a simple recentring.
        // This is a pragmatic initial mapping; Phase B calibration will refine this.
        let ref = CGSize(width: 1080, height: 1920)
        let tx = (nx / ref.width - 0.5) * targetSize.width
        let ty = (ny / ref.height - 0.5) * targetSize.height
        return CGPoint(x: tx, y: ty)
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
    
    // MARK: - Helper Methods
    
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