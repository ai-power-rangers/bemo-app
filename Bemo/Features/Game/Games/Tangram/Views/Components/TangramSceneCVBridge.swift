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
        // Update CV render section with frame data by mapping physical world → mini display
        // 1) Build a similarity transform from physicalWorldSection bounds into cvMiniDisplay square
        let miniSize = min(size.width * 0.25, 150)
        let physWidth = physicalBounds.width
        let physHeight = physicalBounds.height
        guard physWidth > 0, physHeight > 0 else { return }
        let scaleX = miniSize / physWidth
        let scaleY = miniSize / physHeight
        let uniformScale = min(scaleX, scaleY)

        // Center the physical world into the mini square preserving aspect ratio
        // Keep cvContent at origin and apply uniform scale; cvMiniDisplay itself is already positioned in the corner.
        cvContent.setScale(uniformScale)
        cvContent.position = .zero

        // 2) Remove old nodes that are not present in the current frame
        let frameIds = Set(frame.objects.map { pieceIdFromCVName($0.name) })
        for (pieceId, node) in cvPieces where !frameIds.contains(pieceId) {
            node.removeFromParent()
            cvPieces.removeValue(forKey: pieceId)
        }

        // 3) Update or create each CV piece visualization using proper shape and color
        for object in frame.objects {
            updateCVPiece(object)
        }
    }
    
    private func updateCVPiece(_ cvPiece: CVPieceEvent) {
        // Find or create CV visualization
        let pieceId = pieceIdFromCVName(cvPiece.name)
        
        // Only show pieces that have been interacted with (not purely unobserved)
        if let state = pieceStates[pieceId] {
            switch state.state {
            case .unobserved, .detected:
                if let existingNode = cvPieces[pieceId] { existingNode.removeFromParent(); cvPieces.removeValue(forKey: pieceId) }
                return
            default: break
            }
        }
        
        if cvPieces[pieceId] == nil {
            createCVVisualization(for: pieceId)
        }
        
        guard let cvNode = cvPieces[pieceId] else { return }
        
        // Find the corresponding physical piece to get its position
        guard let physicalPiece = availablePieces.first(where: { $0.name == pieceId }) else { return }
        
        // Position/rotation: use a direct mapping via cvContent's transform (uniformScale + center offset)
        // Place cvNode as a child of cvContent to inherit uniform scaling and centering
        if cvNode.parent !== cvContent { cvNode.removeFromParent(); cvContent.addChild(cvNode) }
        cvNode.position = physicalPiece.position
        cvNode.zRotation = physicalPiece.zRotation
        
        // Update flip state and visuals for SKShapeNode-based CV piece
        if let shape = cvNode as? SKShapeNode {
            // Match bottom piece scale, using xScale sign to encode flip
            let baseScaleX = max(0.0001, abs(physicalPiece.xScale))
            let baseScaleY = max(0.0001, abs(physicalPiece.yScale))
            let desiredSign: CGFloat = physicalPiece.isFlipped ? -1 : 1
            shape.xScale = desiredSign * baseScaleX
            shape.yScale = baseScaleY

            if let pieceType = physicalPiece.pieceType {
                shape.fillColor = TangramColors.Sprite.uiColor(for: pieceType).withAlphaComponent(0.6)
                shape.strokeColor = TangramColors.Sprite.uiColor(for: pieceType)
                shape.lineWidth = 1.0
                if let state = pieceStates[pieceId] {
                    updateCVShapeVisualState(shape, pieceType: pieceType, state: state)
                }
            }
        }
    }
    
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
        
        cvContent.addChild(feedbackNode)
        
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
        // Emit current state as CV frame event
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