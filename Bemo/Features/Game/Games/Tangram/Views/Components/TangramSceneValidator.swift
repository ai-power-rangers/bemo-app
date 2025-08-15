//
//  TangramSceneValidator.swift
//  Bemo
//
//  Handles validation delegation for TangramPuzzleScene
//

// WHAT: Thin delegation layer for validation - routes all validation through CVValidationBridge
// ARCHITECTURE: Component of TangramPuzzleScene delegating to unified validation engine
// USAGE: Called by scene when pieces need validation, delegates to CVValidationBridge

import SpriteKit
import Foundation

extension TangramPuzzleScene {
    
    // MARK: - Validation Entry Point
    
    /// Main validation entry point - delegates to CVValidationBridge
    func validatePlacedPiece(_ piece: PuzzlePieceNode) {
        // Use the unified validation bridge
        validationBridge?.validatePiece(piece)
    }
    
    // MARK: - Validation Result Handlers
    
    /// Complete validation for a piece (called by CVValidationBridge)
    func completeValidation(piece: PuzzlePieceNode, targetId: String, state: PieceState) {
        guard let pieceId = piece.name,
              let pieceType = piece.pieceType else { return }
        
        print("[VALIDATION] ✅ piece=\(pieceId) type=\(pieceType.rawValue) → target=\(targetId)")
        
        // Update state
        pieceStates[pieceId] = state
        piece.pieceState = state
        piece.updateStateIndicator()
        
        // Mark as completed
        completedPieces.insert(targetId)
        validatedTargets.insert(targetId)
        onValidatedTargetsChanged?(validatedTargets)
        
        // Update visual
        if let targetNode = targetSilhouettes[targetId] {
            applyValidatedFill(to: targetNode, for: pieceType)
            
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            targetNode.run(pulse)
        }
        
        // Check puzzle completion
        if completedPieces.count == puzzle?.targetPieces.count {
            handlePuzzleComplete()
        }
    }
    
    /// Handle validation failure (called by CVValidationBridge)
    func handleValidationFailure(piece: PuzzlePieceNode, failure: ValidationFailure?) {
        guard let pieceId = piece.name else { return }
        
        // Update state to invalid
        if var state = pieceStates[pieceId] {
            state.markAsInvalid(reason: failure ?? .wrongPiece)
            pieceStates[pieceId] = state
            piece.pieceState = state
            piece.updateStateIndicator()
        }
        
        // Visual feedback
        if let failure = failure {
            print("[VALIDATION] ❌ piece=\(pieceId) - \(failure.nudgeMessage)")
        }
    }
    
    // MARK: - Visual Updates
    
    private func handlePuzzleComplete() {
        print("[PUZZLE] 🎉 Puzzle completed!")
        
        // Notify view model
        onPuzzleCompleted?()
        
        // Celebration animation
        let celebrationNode = SKLabelNode(text: "🎉")
        celebrationNode.fontSize = 100
        celebrationNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        celebrationNode.zPosition = 1000
        addChild(celebrationNode)
        
        let sequence = SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.5),
            SKAction.wait(forDuration: 2),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        celebrationNode.run(sequence)
    }
}