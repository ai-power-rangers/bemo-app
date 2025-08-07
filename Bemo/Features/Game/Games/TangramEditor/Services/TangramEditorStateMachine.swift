//
//  TangramEditorStateMachine.swift
//  Bemo
//
//  Manages all state transitions and validation for the Tangram Editor
//

// WHAT: Centralized state management for Tangram Editor workflow
// ARCHITECTURE: Service that handles all state transitions, validation, and state-based logic
// USAGE: Injected into TangramEditorViewModel to manage editor states

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class TangramEditorStateMachine {
    
    // MARK: - Type Aliases
    typealias ConnectionPoint = PiecePlacementService.ConnectionPoint
    
    // MARK: - State
    
    private(set) var currentState: EditorState = .idle
    
    // MARK: - Public Methods
    
    /// Validates and performs state transitions
    func transition(to newState: EditorState, puzzle: TangramPuzzle) -> Bool {
        // Validate transition is allowed
        guard isValidTransition(from: currentState, to: newState, puzzle: puzzle) else {
            print("[TangramEditor] Invalid state transition: \(currentState) -> \(newState)")
            return false
        }
        
        print("[TangramEditor] State transition: \(currentState) -> \(newState)")
        
        // Update state
        currentState = newState
        
        print("[TangramEditor] New state active: \(currentState)")
        print("[TangramEditor] State description: \(stateDescription)")
        
        return true
    }
    
    /// Human-readable description of current state
    var stateDescription: String {
        switch currentState {
        case .idle:
            return "Select a shape to add or tap a piece to edit"
        case .selectingFirstPiece:
            return "Select your first shape"
        case .manipulatingFirstPiece:
            return "Rotate or flip to position the piece"
        case .selectingNextPiece:
            return "Select the next shape to add"
        case .selectingCanvasConnections(let maxPoints):
            return "Select up to \(maxPoints) connection point(s) on existing pieces"
        case .selectingPendingConnections(_, let maxPoints):
            return "Select up to \(maxPoints) matching connection point(s) on the new piece"
        case .manipulatingPendingPiece(_, let mode, _):
            switch mode {
            case .rotatable:
                return "Rotate the piece around the connection point"
            case .slidable:
                return "Slide the piece along the edge"
            case .locked:
                return "Piece position is locked by connections"
            }
        case .previewingPlacement:
            return "Confirm or cancel piece placement"
        case .pieceSelected(_, let isLocked):
            return isLocked ? "Piece is locked. Unlock to edit" : "Piece selected for editing"
        case .unlockingPiece:
            return "Unlocking piece for manipulation"
        case .manipulatingExistingPiece(_, let mode):
            switch mode {
            case .rotatable:
                return "Rotate the piece around the connection point"
            case .slidable:
                return "Slide the piece along the edge"
            case .locked:
                return "Piece cannot be manipulated"
            }
        case .error(let message):
            return message
        }
    }
    
    /// Set initial state based on puzzle content
    func setInitialState(for puzzle: TangramPuzzle) {
        if puzzle.pieces.isEmpty {
            currentState = .selectingFirstPiece
        } else {
            currentState = .idle
        }
    }
    
    /// Reset to appropriate state based on puzzle
    func resetState(for puzzle: TangramPuzzle) {
        if puzzle.pieces.isEmpty {
            currentState = .selectingFirstPiece
        } else {
            currentState = .selectingNextPiece
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if a state transition is valid
    private func isValidTransition(from currentState: EditorState, to newState: EditorState, puzzle: TangramPuzzle) -> Bool {
        switch (currentState, newState) {
        // From idle
        case (.idle, .selectingFirstPiece) where puzzle.pieces.isEmpty:
            return true
        case (.idle, .selectingNextPiece) where !puzzle.pieces.isEmpty:
            return true
        case (.idle, .pieceSelected):
            return true
            
        // First piece flow
        case (.selectingFirstPiece, .manipulatingFirstPiece):
            return true
        case (.manipulatingFirstPiece, .manipulatingFirstPiece):
            return true  // Allow rotation/flip updates
        case (.manipulatingFirstPiece, .selectingNextPiece):
            return true  // After placing first piece, select next
        case (.manipulatingFirstPiece, .selectingFirstPiece):
            return true  // Cancel and reselect
            
        // Subsequent pieces flow
        case (.selectingNextPiece, .selectingCanvasConnections):
            return true
        case (.selectingNextPiece, .pieceSelected):
            return true  // Allow selecting existing pieces while in selectingNextPiece
        case (.selectingCanvasConnections, .selectingPendingConnections):
            return true
        case (.selectingPendingConnections, .manipulatingPendingPiece):
            return true
        case (.selectingPendingConnections, .previewingPlacement):
            return true
        case (.selectingPendingConnections, .selectingNextPiece):
            return true  // Allow direct transition after placing connected piece
        case (.manipulatingPendingPiece, .manipulatingPendingPiece):
            return true  // Allow rotation updates
        case (.manipulatingPendingPiece, .previewingPlacement):
            return true
        case (.manipulatingPendingPiece, .selectingNextPiece):
            return true  // Allow direct transition after placing connected piece
        case (.previewingPlacement, .selectingNextPiece):
            return true  // After placing piece, select next
        case (.previewingPlacement, .idle):
            return true  // For cancellation
            
        // Editing flow
        case (.pieceSelected, .unlockingPiece):
            return true
        case (.pieceSelected, .idle):
            return true
        case (.unlockingPiece, .manipulatingExistingPiece):
            return true
        case (.manipulatingExistingPiece, .idle):
            return true
            
        // Error recovery
        case (_, .error):
            return true
        case (.error, _):
            return true
            
        // Cancel operations
        case (_, .idle):
            return true
            
        default:
            return false
        }
    }
}

// MARK: - EditorState Definition

enum EditorState: Equatable {
    case idle
    
    // First piece workflow
    case selectingFirstPiece
    case manipulatingFirstPiece(type: PieceType, rotation: Double, isFlipped: Bool)
    
    // Subsequent pieces workflow
    case selectingNextPiece
    case selectingCanvasConnections(maxPoints: Int)
    case selectingPendingConnections(pieceType: PieceType, maxPoints: Int)
    case manipulatingPendingPiece(type: PieceType, mode: ManipulationMode, rotation: Double)
    case previewingPlacement(piece: TangramPiece)
    
    // Editing existing pieces
    case pieceSelected(id: String, isLocked: Bool)
    case unlockingPiece(id: String)
    case manipulatingExistingPiece(id: String, mode: ManipulationMode)
    
    // Error recovery
    case error(String)
    
    static func == (lhs: EditorState, rhs: EditorState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), 
             (.selectingFirstPiece, .selectingFirstPiece),
             (.selectingNextPiece, .selectingNextPiece):
            return true
        case (.manipulatingFirstPiece(let lType, let lRot, let lFlip), 
              .manipulatingFirstPiece(let rType, let rRot, let rFlip)):
            return lType == rType && lRot == rRot && lFlip == rFlip
        case (.selectingCanvasConnections(let lMax), .selectingCanvasConnections(let rMax)):
            return lMax == rMax
        case (.selectingPendingConnections(let lType, let lMax), 
              .selectingPendingConnections(let rType, let rMax)):
            return lType == rType && lMax == rMax
        case (.manipulatingPendingPiece(let lType, let lMode, let lRot), 
              .manipulatingPendingPiece(let rType, let rMode, let rRot)):
            return lType == rType && lMode == rMode && lRot == rRot
        case (.previewingPlacement(let lPiece), .previewingPlacement(let rPiece)):
            return lPiece == rPiece
        case (.pieceSelected(let lId, let lLocked), .pieceSelected(let rId, let rLocked)):
            return lId == rId && lLocked == rLocked
        case (.unlockingPiece(let lId), .unlockingPiece(let rId)):
            return lId == rId
        case (.manipulatingExistingPiece(let lId, let lMode), 
              .manipulatingExistingPiece(let rId, let rMode)):
            return lId == rId && lMode == rMode
        case (.error(let lMsg), .error(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}