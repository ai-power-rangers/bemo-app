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
        // This is now handled by the view model and direct scene updates.
    }
    
    // MARK: - CV Event Handling
    
    private func handleCVEvent(_ event: TangramCVEvent) {
        // This is now handled by the view model and direct scene updates.
    }
    
    // MARK: - CV Frame Rendering
    
    private func updateCVRender(_ frame: CVFrameEvent) {
        // This logic has been moved to updateFromViewModel(placedPieces:)
    }
    
    private func updateCVPiece(_ cvPiece: CVPieceEvent) {
        // This logic is now part of updateFromViewModel
    }
    
    // Note: createCVVisualization is implemented in TangramScenePieceFactory extension
    
    // MARK: - CV Visual Feedback
    
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
        // This was for the mock system and is no longer needed.
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
        // This is now handled by the view model and direct scene updates.
    }
}