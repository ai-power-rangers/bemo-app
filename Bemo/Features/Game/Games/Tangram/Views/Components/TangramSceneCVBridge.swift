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
import ImageIO
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
        // Centralized transformer
        if userData == nil { userData = NSMutableDictionary() }
        if userData?["cvTransformer"] == nil { userData?["cvTransformer"] = TangramCVTransform() }
        guard let transformer = userData?["cvTransformer"] as? TangramCVTransform else { return }
        // Schedule validation only when enabled and the frame meaningfully changed
        if TangramCVTuning.shared.validationEnabled, let bridge = validationBridge {
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

        // Render pipeline-composited overlay image behind ghosts (prototype parity)
        if let data = frame.overlayPNGData,
           let src = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            let name = "pipeline_overlay_sprite"
            let sprite: SKSpriteNode
            if let existing = targetSection.childNode(withName: name) as? SKSpriteNode {
                sprite = existing
            } else {
                sprite = SKSpriteNode(texture: SKTexture(cgImage: cgImage))
                sprite.name = name
                sprite.zPosition = 0 // behind ghosts and plane overlay
                targetSection.addChild(sprite)
            }
            // Aspect fit the overlay into targetBounds
            sprite.texture = SKTexture(cgImage: cgImage)
            let imgW = CGFloat(cgImage.width)
            let imgH = CGFloat(cgImage.height)
            let scale = min(targetBounds.width / imgW, targetBounds.height / imgH)
            sprite.size = CGSize(width: imgW * scale, height: imgH * scale)
            sprite.position = CGPoint(x: 0, y: 0) // targetSection is centered; keep centered
            sprite.alpha = 1.0
            sprite.isHidden = false
        } else {
            targetSection.childNode(withName: "pipeline_overlay_sprite")?.isHidden = true
        }

        // Optional: debug overlay of plane model polygons (like PolygonPlotView)
        if let plane = frame.planeModelPolygons, !plane.isEmpty {
            let debugName = "plane_debug_overlay"
            let existing = targetSection.childNode(withName: debugName)
            let container: SKNode
            if let node = existing { container = node } else {
                let node = SKNode()
                node.name = debugName
                node.zPosition = 1 // below ghosts
                targetSection.addChild(node)
                container = node
            }
            container.removeAllChildren()

            // Build all points to compute bounds
            var pointsByClass: [Int: [CGPoint]] = [:]
            var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
            for (key, arr) in plane {
                var pts: [CGPoint] = []
                var i = 0
                while i + 1 < arr.count {
                    let x = CGFloat(arr[i])
                    let y = CGFloat(arr[i+1])
                    let p = CGPoint(x: x, y: y)
                    pts.append(p)
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                    i += 2
                }
                pointsByClass[key] = pts
            }
            let srcW = max(1, maxX - minX)
            let srcH = max(1, maxY - minY)
            let pad: CGFloat = 8
            let bounds = CGRect(x: 0, y: targetBounds.minY, width: targetBounds.width, height: targetBounds.height)
            let scale = min((bounds.width - 2*pad)/srcW, (bounds.height - 2*pad)/srcH)
            let offset = CGPoint(x: (bounds.width - scale*srcW)/2 - scale*minX,
                                 y: (bounds.height - scale*srcH)/2 - scale*minY)

            // Draw
            for (cid, pts) in pointsByClass {
                guard pts.count >= 3 else { continue }
                let path = CGMutablePath()
                let p0 = CGPoint(x: pts[0].x*scale + offset.x - bounds.width/2,
                                 y: pts[0].y*scale + offset.y - bounds.height/2)
                path.move(to: p0)
                for k in 1..<pts.count {
                    let pk = CGPoint(x: pts[k].x*scale + offset.x - bounds.width/2,
                                     y: pts[k].y*scale + offset.y - bounds.height/2)
                    path.addLine(to: pk)
                }
                path.closeSubpath()
                let shape = SKShapeNode(path: path)
                shape.lineWidth = 1.5
                shape.strokeColor = .white
                // Color per classId: prefer modelColorsRGB from frame; fallback to app colors by type
                if let rgb = frame.modelColorsRGB?[cid], rgb.count >= 3 {
                    let r = CGFloat(rgb[0]) / 255.0
                    let g = CGFloat(rgb[1]) / 255.0
                    let b = CGFloat(rgb[2]) / 255.0
                    shape.fillColor = SKColor(red: r, green: g, blue: b, alpha: 0.35)
                } else {
                    let type: TangramPieceType = {
                        switch cid {
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
                    shape.fillColor = TangramColors.Sprite.uiColor(for: type).withAlphaComponent(0.35)
                }
                container.addChild(shape)
            }
        } else {
            targetSection.childNode(withName: "plane_debug_overlay")?.removeFromParent()
        }

        // Mirror CV-detected pieces directly into top panel
        let mirror = topMirrorContent!
        let topSize = CGSize(width: targetBounds.width, height: targetBounds.height)
        guard topSize.width > 0, topSize.height > 0 else { return }
        // Do not scale container; map CV points explicitly using homography → target coords
        topMirrorContent.setScale(1.0)
        topMirrorContent.position = .zero
        var seen: Set<String> = []
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

            // Map normalized coords through centralized transformer
            let nx = CGFloat(object.pose.translation.first ?? 0)
            let ny = CGFloat(object.pose.translation.dropFirst().first ?? 0)
            let mapped = transformer.mapToTarget(nx: nx, ny: ny, frame: frame, targetSize: topSize)
            let now = CACurrentMediaTime()

            // Prototype parity: raw application without gating/smoothing
            var rotRad = transformer.adjustedRotationRadians(fromDegrees: object.pose.rotationDegrees)
            // Fallback: derive angle from vertices when rotationDegrees is missing/zero
            if abs(CGFloat(object.pose.rotationDegrees)) < 0.001, object.vertices.count >= 2 {
                let verts = object.vertices.map { CGPoint(x: CGFloat($0[0]), y: CGFloat($0[1])) }
                if let ang = estimateAngleFromVertices(points: verts) {
                    // Apply same mirror/rotate adjustments as degrees path
                    rotRad = ang
                    if TangramCVTuning.shared.mirrorX { rotRad = -rotRad }
                    if TangramCVTuning.shared.rotate180 { rotRad += .pi }
                }
            }
            g.position = mapped
            g.zRotation = rotRad

            cvSmoothedPose[pieceId] = (mapped, rotRad)
            seen.insert(nodeName)
            cvLastSeenAt[pieceId] = now
            g.isHidden = false
            g.setScale(1.0)
            // Flip parity disabled until we detect flip
            g.xScale = abs(g.xScale)

            // Base visual at 30–40% for visibility while debugging mapping
            var fillAlpha: CGFloat = 0.3
            // No validation/nudge logic in prototype parity path
            // Do NOT rebuild path each frame; keep geometry stable and only adjust colors
            // Apply color matching the piece type with lower fill
            let baseColor = TangramColors.Sprite.uiColor(for: resolvedType)
            g.fillColor = baseColor.withAlphaComponent(fillAlpha)
            g.strokeColor = baseColor.withAlphaComponent(0.7)
            g.lineWidth = 2.0
        }

        // Remove ghosts not present in this frame for exact parity with current detections
        mirror.enumerateChildNodes(withName: "mirror_*") { node, _ in
            if let name = node.name, !seen.contains(name) {
                node.removeFromParent()
            }
        }

        // Mini CV display removed; no dedicated per-piece CV rendering below
    }

    // MARK: - Angle Helpers
    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }

    private func shortestAngleDelta(from: CGFloat, to: CGFloat) -> CGFloat {
        var d = to - from
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    // Estimate principal direction from vertices (fallback when theta is not provided)
    private func estimateAngleFromVertices(points: [CGPoint]) -> CGFloat? {
        guard points.count >= 2 else { return nil }
        // Use PCA-like approach via second moments around centroid for robustness
        let cx = points.reduce(0) { $0 + $1.x } / CGFloat(points.count)
        let cy = points.reduce(0) { $0 + $1.y } / CGFloat(points.count)
        var sxx: CGFloat = 0, sxy: CGFloat = 0, syy: CGFloat = 0
        for p in points {
            let dx = p.x - cx, dy = p.y - cy
            sxx += dx*dx; sxy += dx*dy; syy += dy*dy
        }
        // Principal axis angle = 0.5 * atan2(2*sxy, sxx - syy)
        let angle = 0.5 * atan2(2*sxy, sxx - syy)
        return angle
    }

    // MARK: - Homography Mapping
    private func mapCVToTarget(cvX: CGFloat, cvY: CGFloat, frame: CVFrameEvent, targetSize: CGSize) -> CGPoint {
        // Homography: maps from plane↔camera. We treat input as camera pixels in reference space and apply inverse of H.
        // Frame.homography is 3x3 in row-major order. We’ll compute inverse and map to plane coordinates, then center/scale into target.
        let H = frame.homography
        guard H.count == 3, H[0].count == 3 else {
            // Fallback to simple mapping with Y inversion
            let ref = CGSize(width: 1080, height: 1920)
            return CGPoint(x: (cvX / ref.width - 0.5) * targetSize.width,
                           y: (0.5 - cvY / ref.height) * targetSize.height)
        }
        // Build matrix and inverse
        let h00 = H[0][0], h01 = H[0][1], h02 = H[0][2]
        let h10 = H[1][0], h11 = H[1][1], h12 = H[1][2]
        let h20 = H[2][0], h21 = H[2][1], h22 = H[2][2]

        let det = h00*(h11*h22 - h12*h21) - h01*(h10*h22 - h12*h20) + h02*(h10*h21 - h11*h20)
        if abs(det) < 1e-9 {
            let ref = CGSize(width: 1080, height: 1920)
            return CGPoint(x: (cvX / ref.width - 0.5) * targetSize.width,
                           y: (0.5 - cvY / ref.height) * targetSize.height)
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
        let ty = (0.5 - ny / ref.height) * targetSize.height
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