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
        // Update CV render section with frame data
        // This simulates what the iPad would show based on CV input
        
        // Clear old pieces that aren't in the frame
        let frameIds = Set(frame.objects.map { pieceIdFromCVName($0.name) })
        for (pieceId, node) in cvPieces {
            if !frameIds.contains(pieceId) {
                node.removeFromParent()
                cvPieces.removeValue(forKey: pieceId)
            }
        }
        
        // Update or create pieces from frame
        for object in frame.objects {
            updateCVPiece(object)
        }
    }
    
    private func updateCVPiece(_ cvPiece: CVPieceEvent) {
        // Find or create CV visualization
        let pieceId = pieceIdFromCVName(cvPiece.name)
        
        // Only show pieces that have been moved or placed (not just detected)
        guard let state = pieceStates[pieceId] else {
            // Remove from CV render if it exists but we don't have state
            if let existingNode = cvPieces[pieceId] {
                existingNode.removeFromParent()
                cvPieces.removeValue(forKey: pieceId)
            }
            return
        }
        
        // Check if the state is not unobserved or detected
        switch state.state {
        case .unobserved, .detected:
            // Remove from CV render if it exists but shouldn't be shown
            if let existingNode = cvPieces[pieceId] {
                existingNode.removeFromParent()
                cvPieces.removeValue(forKey: pieceId)
            }
            return
        case .moved, .placed, .validating, .validated, .invalid:
            // Continue to show/update the piece in CV render
            break
        }
        
        if cvPieces[pieceId] == nil {
            createCVVisualization(for: pieceId)
        }
        
        guard let cvNode = cvPieces[pieceId] else { return }
        
        // Find the corresponding physical piece to get its position
        guard let physicalPiece = availablePieces.first(where: { $0.name == pieceId }) else { return }
        
        // Map position from physical world to mini CV display
        // Scale down significantly for the mini display
        let miniDisplaySize: CGFloat = min(size.width * 0.25, 150)
        let scale: CGFloat = miniDisplaySize / (size.width * 0.8)  // Scale relative to physical world width
        
        let cvPos = CGPoint(
            x: physicalPiece.position.x * scale,
            y: physicalPiece.position.y * scale
        )
        
        // Smooth position update - no jitter
        cvNode.position = cvPos
        cvNode.zRotation = physicalPiece.zRotation  // Use actual rotation from physical piece
        
        // Update flip state if it's a PuzzlePieceNode
        if let cvPuzzlePiece = cvNode as? PuzzlePieceNode {
            if cvPuzzlePiece.isFlipped != physicalPiece.isFlipped {
                cvPuzzlePiece.flip()  // Sync flip state
            }
            
            // Update visual state based on piece state
            if let state = pieceStates[pieceId] {
                updateCVPieceVisualState(cvPuzzlePiece, state: state)
            }
        }
    }
    
    // Note: createCVVisualization is implemented in TangramScenePieceFactory extension
    
    // MARK: - CV Visual Feedback
    
    private func updateCVPieceVisualState(_ cvPiece: PuzzlePieceNode, state: PieceState) {
        // Update visual appearance based on validation state
        switch state.state {
        case .validated:
            cvPiece.alpha = 1.0
            // Update shape color to indicate validation
            if let shape = cvPiece.shapeNode {
                shape.fillColor = shape.fillColor.withAlphaComponent(1.0)
                shape.strokeColor = .systemGreen
                shape.lineWidth = 3
            }
        case .invalid:
            cvPiece.alpha = 0.8
            // Update shape color to indicate invalid
            if let shape = cvPiece.shapeNode {
                shape.strokeColor = .systemRed
                shape.lineWidth = 2
            }
        case .validating:
            cvPiece.alpha = 0.9
            // Update shape color to indicate validating
            if let shape = cvPiece.shapeNode {
                shape.strokeColor = .systemYellow
                shape.lineWidth = 2
            }
        default:
            cvPiece.alpha = 0.7
            // Reset shape color to default
            if let shape = cvPiece.shapeNode, let pieceType = cvPiece.pieceType {
                shape.strokeColor = TangramColors.Sprite.uiColor(for: pieceType).darker(by: 20)
                shape.lineWidth = 2
            }
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
        
        cvMiniDisplay.addChild(feedbackNode)
        
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