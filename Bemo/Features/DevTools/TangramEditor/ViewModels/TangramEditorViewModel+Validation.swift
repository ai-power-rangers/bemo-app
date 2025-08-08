//
//  TangramEditorViewModel+Validation.swift
//  Bemo
//
//  Validation logic for Tangram Editor
//

// WHAT: Extension handling all validation operations for the editor
// ARCHITECTURE: ViewModel extension separating validation concerns
// USAGE: Contains methods for validating puzzle state, pieces, and connections

import Foundation
import SwiftUI

extension TangramEditorViewModel {
    
    // MARK: - Public Validation Methods
    
    /// Validate the entire puzzle and update validation state
    func validate() {
        validationState = coordinator.validatePuzzle(puzzle)
        
        // Additional validation for editor-specific rules
        if puzzle.pieces.isEmpty {
            validationState = .unknown
        } else if puzzle.pieces.count < 2 {
            validationState = .invalid(reason: "At least 2 pieces required")
        }
    }
    
    /// Check if a piece type has already been placed
    func isPieceTypeAlreadyPlaced(_ type: PieceType) -> Bool {
        puzzle.pieces.contains { $0.type == type }
    }
    
    /// Validate if a piece can be removed
    func canRemovePiece(_ pieceId: String) -> Bool {
        // Check if piece exists
        guard puzzle.pieces.first(where: { $0.id == pieceId }) != nil else {
            return false
        }
        
        // For now, allow deletion of any piece except the first one if others exist
        if puzzle.pieces.first?.id == pieceId && puzzle.pieces.count > 1 {
            return false // Cannot delete base piece while others exist
        }
        
        return true
    }
    
    /// Validate if pieces can be removed
    func canRemovePieces(_ pieceIds: Set<String>) -> Bool {
        // Check if any selected pieces are the base piece
        if let firstPiece = puzzle.pieces.first,
           pieceIds.contains(firstPiece.id) && puzzle.pieces.count > 1 {
            return false // Cannot delete base piece while others exist
        }
        
        return true
    }
    
    /// Validate if a transform is valid for a piece
    func isValidTransform(_ transform: CGAffineTransform, for pieceId: String) -> Bool {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return false
        }
        
        // Create temporary piece with new transform
        var testPiece = piece
        testPiece.transform = transform
        
        // Check for overlaps with other pieces
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        for otherPiece in otherPieces {
            if PieceTransformEngine.hasAreaOverlap(testPiece, otherPiece) {
                return false
            }
        }
        
        return true
    }
    
    /// Validate connection points selection
    func validateConnectionPoints() -> Bool {
        // Check if we have matching connection types
        let canvasVertexCount = uiState.selectedCanvasPoints.filter { 
            if case .vertex = $0.type { return true } else { return false }
        }.count
        let canvasEdgeCount = uiState.selectedCanvasPoints.filter { 
            if case .edge = $0.type { return true } else { return false }
        }.count
        let pendingVertexCount = uiState.selectedPendingPoints.filter { 
            if case .vertex = $0.type { return true } else { return false }
        }.count
        let pendingEdgeCount = uiState.selectedPendingPoints.filter { 
            if case .edge = $0.type { return true } else { return false }
        }.count
        
        // Types must match
        return canvasVertexCount == pendingVertexCount && canvasEdgeCount == pendingEdgeCount
    }
    
    /// Validate if preview placement is valid
    func validatePreview() -> Bool {
        guard let preview = uiState.previewPiece else {
            return false
        }
        
        // Use transform engine to validate
        let result = transformEngine.calculateTransform(
            for: preview,
            operation: .place(center: CGPoint.zero, rotation: 0),
            connection: nil,
            otherPieces: puzzle.pieces,
            canvasSize: uiState.currentCanvasSize
        )
        
        return result.isValid
    }
    
    // MARK: - Manipulation Validation
    
    /// Check if a piece can be rotated
    func canRotatePiece(_ pieceId: String) -> Bool {
        guard let mode = pieceManipulationModes[pieceId] else {
            return false
        }
        
        if case .rotatable = mode {
            return true
        }
        
        return false
    }
    
    /// Check if a piece can slide
    func canSlidePiece(_ pieceId: String) -> Bool {
        guard let mode = pieceManipulationModes[pieceId] else {
            return false
        }
        
        if case .slidable = mode {
            return true
        }
        
        return false
    }
    
    /// Check if a piece is fixed
    func isPieceFixed(_ pieceId: String) -> Bool {
        guard let mode = pieceManipulationModes[pieceId] else {
            return true // Default to fixed if no mode
        }
        
        if case .fixed = mode {
            return true
        }
        
        return false
    }
    
    // MARK: - State Validation
    
    /// Check if current state allows piece selection
    var canSelectPieces: Bool {
        switch editorState {
        case .idle, .selectingNextPiece, .selectingFirstPiece, .pieceSelected:
            return true
        default:
            return false
        }
    }
    
    /// Check if current state allows piece placement
    var canPlacePiece: Bool {
        switch editorState {
        case .manipulatingFirstPiece:
            return true
        case .manipulatingPendingPiece, .selectingPendingConnections:
            return validateConnectionPoints() && uiState.previewPiece != nil
        case .previewingPlacement:
            return true
        default:
            return false
        }
    }
    
    /// Check if current state allows cancellation
    var canCancelOperation: Bool {
        switch editorState {
        case .idle:
            return false
        default:
            return true
        }
    }
    
    // MARK: - Save Validation
    
    /// Check if puzzle can be saved
    var canSavePuzzle: Bool {
        return validationState.isValid && puzzle.pieces.count >= 2
    }
    
    /// Check if puzzle has minimum requirements for saving
    var meetsMinimumRequirements: Bool {
        return puzzle.pieces.count >= 2
    }
}