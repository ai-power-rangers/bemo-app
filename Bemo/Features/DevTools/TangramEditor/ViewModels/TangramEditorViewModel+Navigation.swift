//
//  TangramEditorViewModel+Navigation.swift
//  Bemo
//
//  Navigation and workflow management for Tangram Editor
//

// WHAT: Extension handling navigation between editor states and library
// ARCHITECTURE: ViewModel extension separating navigation concerns
// USAGE: Contains methods for managing editor navigation and state transitions

import Foundation
import SwiftUI

extension TangramEditorViewModel {
    
    // MARK: - Navigation Methods
    
    /// Navigate to puzzle library
    func navigateToLibrary(saveChanges: Bool = false) {
        if saveChanges && hasUnsavedChanges {
            Task {
                do {
                    try await save()
                    uiState.navigationState = .library
                } catch {
                    handleError(.saveFailed(error.localizedDescription))
                }
            }
        } else {
            uiState.navigationState = .library
        }
    }
    
    /// Navigate to editor with optional puzzle
    func navigateToEditor(with puzzle: TangramPuzzle? = nil) {
        if let puzzle = puzzle {
            loadPuzzle(from: puzzle)
        }
        uiState.navigationState = .editor
    }
    
    /// Request to quit the editor
    func requestQuit() {
        delegate?.devToolDidRequestQuit()
    }
    
    /// Request to save puzzle
    func requestSave() {
        if canSavePuzzle {
            uiState.showSaveDialog = true
        } else {
            handleError(.validationFailed("Puzzle must be valid and have at least 2 pieces"))
        }
    }
    
    // MARK: - State Management
    
    /// Create a new puzzle and navigate to editor
    func createNewPuzzle() {
        // Check for unsaved changes
        if hasUnsavedChanges {
            showLibraryNavigationAlert = true
        } else {
            startNewPuzzle()
        }
    }
    
    /// Start a new puzzle (internal)
    private func startNewPuzzle() {
        puzzle = TangramPuzzle(name: "New Puzzle")
        originalPuzzleData = nil
        stateManager.setInitialState(for: puzzle)
        editorState = stateManager.currentState
        uiState.clearSelectionState()
        uiState.navigationState = .editor
    }
    
    /// Load existing puzzle and navigate to editor
    func loadPuzzle(from puzzle: TangramPuzzle) {
        self.puzzle = puzzle
        
        // Store original data for change detection
        if let data = try? JSONEncoder().encode(puzzle) {
            originalPuzzleData = data
        }
        
        // Reset state for loaded puzzle
        stateManager.setInitialState(for: puzzle)
        editorState = stateManager.currentState
        uiState.clearSelectionState()
        
        // Update manipulation modes
        updateManipulationModes()
        
        // Validate loaded puzzle
        validate()
        
        // Navigate to editor if not already there
        if uiState.navigationState != .editor {
            uiState.navigationState = .editor
        }
    }
    
    /// Reset editor to initial state
    func reset() {
        puzzle = TangramPuzzle(name: "New Puzzle")
        originalPuzzleData = nil
        validationState = .unknown
        availableConnectionPoints.removeAll()
        pieceManipulationModes.removeAll()
        manipulationConstraints.removeAll()
        initialManipulationTransforms.removeAll()
        
        uiState.clearSelectionState()
        uiState.clearManipulationState()
        
        stateManager.resetState(for: puzzle)
        editorState = stateManager.currentState
        
        toastService.showInfo("Editor reset")
    }
    
    // MARK: - Workflow Navigation
    
    /// Proceed to next step in workflow
    func proceedToNextStep() {
        switch editorState {
        case .selectingCanvasConnections:
            proceedToPendingPiece()
        case .selectingPendingConnections:
            if validateConnectionPoints() {
                updatePreviewIfNeeded()
            }
        default:
            break
        }
    }
    
    /// Go back to previous step in workflow
    func goBackToPreviousStep() {
        switch editorState {
        case .selectingPendingConnections:
            _ = transitionToState(.selectingCanvasConnections(maxPoints: 2))
        case .selectingCanvasConnections:
            _ = transitionToState(.selectingNextPiece)
        default:
            break
        }
    }
    
    /// Proceed from canvas connection selection to pending piece
    func proceedToPendingPiece() {
        guard let type = uiState.pendingPieceType else { return }
        
        let maxPoints = uiState.selectedCanvasPoints.count
        if maxPoints > 0 {
            _ = transitionToState(.selectingPendingConnections(type: type, maxPoints: maxPoints))
            setupNewState()
        }
    }
    
    // MARK: - Alert Handling
    
    /// Handle library navigation with unsaved changes
    func handleLibraryNavigationAlert(saveChanges: Bool) {
        if saveChanges {
            navigateToLibrary(saveChanges: true)
        } else {
            // Discard changes and navigate
            originalPuzzleData = nil
            navigateToLibrary(saveChanges: false)
        }
    }
    
    // MARK: - State Helpers
    
    /// Setup state after transition
    func setupNewState() {
        switch editorState {
        case .selectingCanvasConnections:
            updateAvailableConnectionPoints()
            uiState.selectedCanvasPoints.removeAll()
            uiState.selectedPendingPoints.removeAll()
            
        case .selectingPendingConnections(let type, _):
            if let pendingType = uiState.pendingPieceType ?? type as PieceType? {
                let pendingPoints = getConnectionPointsForPendingPiece(type: pendingType, scale: TangramConstants.visualScale)
                availableConnectionPoints = pendingPoints
            }
            uiState.selectedPendingPoints.removeAll()
            
        case .selectingNextPiece, .idle:
            clearPendingState()
            
        default:
            break
        }
    }
    
    /// Clear all pending state
    private func clearPendingState() {
        uiState.pendingPieceType = nil
        uiState.pendingPieceRotation = 0
        uiState.pendingPieceIsFlipped = false
        uiState.previewPiece = nil
        uiState.previewTransform = nil
        uiState.selectedCanvasPoints.removeAll()
        uiState.selectedPendingPoints.removeAll()
        availableConnectionPoints.removeAll()
    }
}