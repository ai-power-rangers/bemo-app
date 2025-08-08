//
//  TangramEditorStateMachine.swift
//  Bemo
//
//  State management for Tangram Editor workflow
//

// WHAT: Manages editor state transitions and validates workflow progression
// ARCHITECTURE: Service layer in MVVM-S, enforces valid state transitions
// USAGE: Used by ViewModel to manage editor workflow states

import Foundation
import Observation

@Observable
@MainActor
class TangramEditorStateMachine {
    
    // MARK: - Properties
    
    private(set) var currentState: EditorState = .idle
    
    var stateDescription: String {
        currentState.description
    }
    
    // MARK: - Public Methods
    
    /// Initialize state based on puzzle content
    func setInitialState(for puzzle: TangramPuzzle) {
        if puzzle.pieces.isEmpty {
            currentState = .selectingFirstPiece
        } else {
            currentState = .selectingNextPiece
        }
    }
    
    /// Reset state based on puzzle content
    func resetState(for puzzle: TangramPuzzle) {
        setInitialState(for: puzzle)
    }
    
    /// Attempt to transition to a new state
    func transition(to newState: EditorState, puzzle: TangramPuzzle) -> Bool {
        guard isValidTransition(from: currentState, to: newState, puzzle: puzzle) else {
            return false
        }
        
        currentState = newState
        return true
    }
    
    /// Force state (use carefully, only for error recovery)
    func forceState(_ state: EditorState) {
        currentState = state
    }
    
    // MARK: - State Transition Rules
    
    private func isValidTransition(from: EditorState, to: EditorState, puzzle: TangramPuzzle) -> Bool {
        // Build transition table for clarity
        let transition = StateTransition(from: from, to: to)
        
        // Check if transition is in allowed set
        return allowedTransitions.contains(transition) || 
               isConditionalTransitionValid(from: from, to: to, puzzle: puzzle)
    }
    
    private func isConditionalTransitionValid(from: EditorState, to: EditorState, puzzle: TangramPuzzle) -> Bool {
        switch (from, to) {
        // Conditional transitions based on puzzle state
        case (.idle, .selectingFirstPiece):
            return puzzle.pieces.isEmpty
        case (.idle, .selectingNextPiece):
            return !puzzle.pieces.isEmpty
            
        // Always allow error states
        case (_, .error):
            return true
        case (.error, _):
            return true
            
        // Allow cancellation to idle from most states
        case (_, .idle) where from != .idle:
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Transition Table
    
    private struct StateTransition: Hashable {
        let from: EditorState
        let to: EditorState
    }
    
    private let allowedTransitions: Set<StateTransition> = [
        // First piece workflow
        StateTransition(from: .selectingFirstPiece, to: .manipulatingFirstPiece),
        StateTransition(from: .manipulatingFirstPiece, to: .manipulatingFirstPiece), // Updates
        StateTransition(from: .manipulatingFirstPiece, to: .selectingNextPiece),
        StateTransition(from: .manipulatingFirstPiece, to: .selectingFirstPiece),
        
        // Subsequent pieces workflow
        StateTransition(from: .selectingNextPiece, to: .selectingCanvasConnections),
        StateTransition(from: .selectingNextPiece, to: .pieceSelected),
        StateTransition(from: .selectingCanvasConnections, to: .selectingPendingConnections),
        StateTransition(from: .selectingPendingConnections, to: .manipulatingPendingPiece),
        StateTransition(from: .selectingPendingConnections, to: .previewingPlacement),
        StateTransition(from: .selectingPendingConnections, to: .selectingNextPiece),
        StateTransition(from: .manipulatingPendingPiece, to: .manipulatingPendingPiece), // Updates
        StateTransition(from: .manipulatingPendingPiece, to: .previewingPlacement),
        StateTransition(from: .manipulatingPendingPiece, to: .selectingNextPiece),
        StateTransition(from: .previewingPlacement, to: .selectingNextPiece),
        StateTransition(from: .previewingPlacement, to: .idle),
        
        // Editing existing pieces
        StateTransition(from: .pieceSelected, to: .manipulatingExistingPiece),
        StateTransition(from: .pieceSelected, to: .idle),
        StateTransition(from: .manipulatingExistingPiece, to: .idle),
        
        // General transitions
        StateTransition(from: .idle, to: .pieceSelected),
    ]
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
    case selectingPendingConnections(type: PieceType, maxPoints: Int)
    case manipulatingPendingPiece(type: PieceType, mode: ManipulationMode, rotation: Double)
    case previewingPlacement(piece: TangramPiece)
    
    // Editing existing pieces
    case pieceSelected(pieceId: String)
    case manipulatingExistingPiece(pieceId: String, mode: ManipulationMode)
    
    // Error state
    case error(message: String)
    
    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .selectingFirstPiece:
            return "Select a piece to place"
        case .manipulatingFirstPiece(let type, _, _):
            return "Placing \(type.rawValue)"
        case .selectingNextPiece:
            return "Select next piece"
        case .selectingCanvasConnections:
            return "Select connection points on canvas"
        case .selectingPendingConnections(let type, _):
            return "Select connection points on \(type.rawValue)"
        case .manipulatingPendingPiece(let type, _, _):
            return "Adjusting \(type.rawValue)"
        case .previewingPlacement:
            return "Preview placement"
        case .pieceSelected:
            return "Piece selected"
        case .manipulatingExistingPiece:
            return "Manipulating piece"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}