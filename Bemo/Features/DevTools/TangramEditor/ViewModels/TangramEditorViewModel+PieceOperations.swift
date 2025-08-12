//
//  TangramEditorViewModel+PieceOperations.swift
//  Bemo
//
//  Piece manipulation and operations for Tangram Editor
//

// WHAT: Extension handling all piece-related operations (add, remove, rotate, flip, etc.)
// ARCHITECTURE: ViewModel extension for piece manipulation logic
// USAGE: Contains all methods for manipulating tangram pieces in the editor

import Foundation
import SwiftUI

extension TangramEditorViewModel {
    
    // MARK: - Transaction Pattern
    
    /// Performs a puzzle modification with automatic undo, validation, and notification
    private func performPuzzleModification(_ operation: () -> Void) {
        undoManager.saveState(puzzle: puzzle)
        operation()
        validate()
        notifyPuzzleChanged()
    }
    
    // MARK: - UI Actions
    
    func startAddingPiece(type: PieceType) {
        guard !isPieceTypeAlreadyPlaced(type) else { 
            handleError(.pieceAlreadyPlaced(type.rawValue))
            return 
        }
        
        uiState.pendingPieceType = type
        uiState.pendingPieceRotation = 0
        
        if puzzle.pieces.isEmpty {
            // First piece flow - we should already be in selectingFirstPiece state
            // Transition to manipulating the first piece
            _ = transitionToState(.manipulatingFirstPiece(type: type, rotation: 0, isFlipped: false))
        } else {
            // Subsequent pieces flow - need to select connections first
            _ = transitionToState(.selectingCanvasConnections(maxPoints: 2))
            setupNewState()  // This will update available connection points
        }
    }
    
    func confirmPendingPiece(canvasSize: CGSize? = nil) {
        
        undoManager.saveState(puzzle: puzzle)
        
        let size = canvasSize ?? uiState.currentCanvasSize
        
        switch editorState {
        case .manipulatingFirstPiece(let type, let rotation, let isFlipped):
            // Use transform engine to calculate placement transform
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let tempPiece = TangramPiece(type: type, transform: .identity)
            
            let result = transformEngine.calculateTransform(
                for: tempPiece,
                operation: .place(center: center, rotation: rotation * .pi / 180),
                connection: nil,
                otherPieces: [],
                canvasSize: size
            )
            
            // Apply flip if needed (PieceTransformEngine doesn't handle flip for placement)
            var finalTransform = result.transform
            if isFlipped && type == .parallelogram {
                // Apply horizontal flip after rotation
                finalTransform = finalTransform.scaledBy(x: -1, y: 1)
            }
            
            // Create piece with the calculated transform
            let piece = TangramPiece(type: type, transform: finalTransform)
            puzzle.pieces.append(piece)
            // Clear pending piece type after successful placement
            uiState.pendingPieceType = nil
            uiState.pendingPieceRotation = 0
            uiState.pendingPieceIsFlipped = false
            // After placing first piece, transition to selecting next piece
            _ = transitionToState(.selectingNextPiece)
            setupNewState()  // Clear pending state properly
            updateManipulationModes()
            validate()
            // No need to recenter for first piece - it's already centered
            notifyPuzzleChanged()
            toastService.showSuccess("First piece placed")
            
        case .selectingPendingConnections, .manipulatingPendingPiece:
            
            // Use the preview piece if available
            guard uiState.previewPiece != nil else {
                // No valid preview available - this shouldn't happen with proper UI validation
                handleError(.placementCalculationFailed("No valid placement found for the selected connections"))
                return
            }
            
            // Proceed with the preview piece (already validated when created)
            // Create connections based on the selected points
            if let type = uiState.pendingPieceType {
                let result = coordinator.placeConnectedPiece(
                    type: type,
                    rotation: uiState.pendingPieceRotation * .pi / 180,
                    isFlipped: uiState.pendingPieceIsFlipped && type == .parallelogram,
                    canvasConnections: uiState.selectedCanvasPoints,
                    pieceConnections: uiState.selectedPendingPoints,
                    existingPieces: puzzle.pieces, // Pass ALL pieces since we didn't append preview
                    puzzle: &puzzle
                )
                
                if case .failure(let error) = result {
                    // No piece to remove since we didn't append
                    handleError(.placementCalculationFailed("Failed to create connections: \(error)"))
                    return
                }
            }
            
            // Transition to next state FIRST
            _ = transitionToState(.selectingNextPiece)
            
            // Clear pending state and setup new state
            clearPendingState()
            setupNewState()
            
            updateManipulationModes()
            validate()
            // Recenter puzzle after adding connected piece
            recenterPuzzle()
            notifyPuzzleChanged()
            toastService.showSuccess("Piece connected successfully")
            
        case .previewingPlacement(let piece):
            // Add the previewed piece to the puzzle
            puzzle.pieces.append(piece)
            
            // Transition to next state FIRST
            _ = transitionToState(.selectingNextPiece)
            
            // Setup the new state (clears pending state)
            setupNewState()
            
            updateManipulationModes()
            validate()
            // Recenter puzzle after preview placement
            recenterPuzzle()
            notifyPuzzleChanged()
            toastService.showSuccess("Piece placed successfully")
            
        default:
            break
        }
    }
    
    func cancelPendingPiece() {
        // Clear ALL pending state when cancelling
        clearPendingState()
        
        // Go back to selecting state based on puzzle content
        if puzzle.pieces.isEmpty {
            _ = transitionToState(.selectingFirstPiece)
        } else {
            _ = transitionToState(.selectingNextPiece)
        }
        setupNewState()  // Ensure clean state
    }
    
    func rotatePendingPiece(by degrees: Double) {
        // Update the rotation in the current state
        switch editorState {
        case .manipulatingFirstPiece(let type, let currentRotation, let isFlipped):
            let newRotation = currentRotation + degrees
            uiState.pendingPieceRotation = newRotation
            _ = transitionToState(.manipulatingFirstPiece(type: type, rotation: newRotation, isFlipped: isFlipped))
            
        case .selectingPendingConnections, .previewingPlacement:
            // Allow rotation while selecting connections
            uiState.pendingPieceRotation += degrees
            updatePreviewIfNeeded()
            
        case .manipulatingPendingPiece(let type, let mode, let currentRotation):
            let newRotation = currentRotation + degrees
            uiState.pendingPieceRotation = newRotation
            _ = transitionToState(.manipulatingPendingPiece(type: type, mode: mode, rotation: newRotation))
            
        default:
            break
        }
        
        updatePreviewIfNeeded()
    }
    
    func flipPendingPiece() {
        // Only parallelogram can flip
        guard let pieceType = uiState.pendingPieceType, pieceType == .parallelogram else { return }
        
        switch editorState {
        case .manipulatingFirstPiece(let type, let rotation, let isFlipped):
            _ = transitionToState(.manipulatingFirstPiece(type: type, rotation: rotation, isFlipped: !isFlipped))
        case .manipulatingPendingPiece(_, _, _):
            // For pending pieces, toggle the flip state
            uiState.pendingPieceIsFlipped.toggle()
        case .selectingPendingConnections(_, _):
            // Allow flipping while selecting connections
            uiState.pendingPieceIsFlipped.toggle()
        default:
            break
        }
        
        updatePreviewIfNeeded()
    }
    
    // MARK: - Piece Operations
    
    func removePiece(id: String) {
        // Check if piece can be removed (not structurally critical)
        guard puzzle.pieces.first(where: { $0.id == id }) != nil else { return }
        
        // For now, allow deletion of any piece except the first one
        if puzzle.pieces.first?.id == id && puzzle.pieces.count > 1 {
            handleError(.operationNotAllowed("Cannot delete the base piece while other pieces exist"))
            return
        }
        
        performPuzzleModification {
            puzzle.pieces.removeAll { $0.id == id }
            puzzle.connections.removeAll { $0.involvesPiece(id) }
        }
        // After removing piece, go to appropriate selection state
        stateManager.resetState(for: puzzle)
        editorState = stateManager.currentState
    }
    
    func removeSelectedPieces() {
        // Check if any selected pieces are the base piece
        let selectedPieces = puzzle.pieces.filter { uiState.selectedPieceIds.contains($0.id) }
        
        if let firstPiece = puzzle.pieces.first,
           selectedPieces.contains(where: { $0.id == firstPiece.id }) && puzzle.pieces.count > 1 {
            handleError(.operationNotAllowed("Cannot delete the base piece while other pieces exist"))
            return
        }
        
        performPuzzleModification {
            let idsToRemove = uiState.selectedPieceIds
            puzzle.pieces.removeAll { idsToRemove.contains($0.id) }
            puzzle.connections.removeAll { connection in
                idsToRemove.contains { connection.involvesPiece($0) }
            }
            uiState.selectedPieceIds.removeAll()
        }
        // After removing pieces, go to appropriate selection state
        stateManager.resetState(for: puzzle)
        editorState = stateManager.currentState
    }
    
    func rotateSelectedPieces(by degrees: Double) {
        guard !uiState.selectedPieceIds.isEmpty else { return }
        
        performPuzzleModification {
            for pieceId in uiState.selectedPieceIds {
                guard let index = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else { continue }
                
                let piece = puzzle.pieces[index]
                let currentTransform = piece.transform
                
                // Extract current rotation and apply additional rotation
                let angle = degrees * .pi / 180
                let rotationTransform = CGAffineTransform(rotationAngle: angle)
                
                // Apply rotation to the existing transform
                puzzle.pieces[index].transform = currentTransform.concatenating(rotationTransform)
            }
        }
    }
    
    func flipSelectedPieces() {
        guard !uiState.selectedPieceIds.isEmpty else { return }
        
        performPuzzleModification {
            for pieceId in uiState.selectedPieceIds {
                guard let index = puzzle.pieces.firstIndex(where: { $0.id == pieceId }),
                      puzzle.pieces[index].type == .parallelogram else { continue }
                
                let piece = puzzle.pieces[index]
                let currentTransform = piece.transform
                
                // Apply horizontal flip by scaling x by -1
                let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
                puzzle.pieces[index].transform = currentTransform.concatenating(flipTransform)
            }
        }
    }
    
    func updatePieceTransform(id: String, transform: CGAffineTransform) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else { return }
        
        performPuzzleModification {
            puzzle.pieces[index].transform = transform
        }
    }
    
    // MARK: - Piece Manipulation Management
    
    // MARK: - Manipulation Mode Management
    
    /// Determine manipulation mode for a piece based on its connections
    func determineManipulationMode(for pieceId: String) -> ManipulationMode {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return .fixed
        }
        
        // Check if it's the first piece
        let isFirstPiece = puzzle.pieces.first?.id == pieceId
        return manipulationService.calculateManipulationMode(piece: piece, connections: puzzle.connections, allPieces: puzzle.pieces, isFirstPiece: isFirstPiece)
    }
    
    /// Update manipulation modes for all pieces
    func updateManipulationModes() {
        pieceManipulationModes.removeAll()
        manipulationConstraints.removeAll()  // Clear cached constraints
        
        for piece in puzzle.pieces {
            let mode = determineManipulationMode(for: piece.id)
            pieceManipulationModes[piece.id] = mode
            
            // Pre-calculate constraints for each piece based on its mode
            let otherPieces = puzzle.pieces.filter { $0.id != piece.id }
            
            switch mode {
            case .rotatable(let pivot, _):
                // Calculate rotation limits upfront
                let limits = manipulationService.calculateRotationLimits(
                    piece: piece,
                    pivot: pivot,
                    otherPieces: otherPieces,
                    stepDegrees: 5.0
                )
                manipulationConstraints[piece.id] = ManipulationConstraints(
                    rotationLimits: (min: limits.minAngle, max: limits.maxAngle),
                    slideLimits: nil
                )
                
            case .slidable(let edge, let baseRange, _):
                // Calculate slide limits upfront
                let limits = manipulationService.calculateSlideLimits(
                    piece: piece,
                    edge: edge,
                    baseRange: baseRange,
                    otherPieces: otherPieces,
                    stepSize: 2.0
                )
                manipulationConstraints[piece.id] = ManipulationConstraints(
                    rotationLimits: nil,
                    slideLimits: limits
                )
                
            default:
                // Fixed or free pieces don't need constraints
                break
            }
        }
    }
    
    // MARK: - Manipulation Handlers
    
    /// Handle rotation gesture for a piece with single vertex connection
    func handleRotation(pieceId: String, angle: Double) {
        guard let mode = pieceManipulationModes[pieceId],
              case .rotatable(let pivot, _) = mode,
              let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return
        }
        
        // Store initial transform if this is the first manipulation
        if initialManipulationTransforms[pieceId] == nil {
            initialManipulationTransforms[pieceId] = piece.transform
        }
        
        // Get the initial transform (before any rotation in this gesture)
        guard let initialTransform = initialManipulationTransforms[pieceId] else {
            return
        }
        
        // Create a piece with the initial transform to apply the rotation to
        var rotatingPiece = piece
        rotatingPiece.transform = initialTransform
        
        // Get the connection for this piece
        let connection = puzzle.connections.first { $0.involvesPiece(pieceId) }
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        
        // Use unified transform engine - angle is the delta from the initial position
        let result = transformEngine.calculateTransform(
            for: rotatingPiece,
            operation: .rotate(angle: angle, pivot: pivot),
            connection: connection,
            otherPieces: otherPieces,
            canvasSize: uiState.currentCanvasSize
        )
        
        // Apply result to UI state
        if result.isValid {
            uiState.ghostTransform = result.transform
            uiState.showSnapIndicator = true
            uiState.manipulatingPieceId = pieceId
            
            // Store snap indicators if available
            if let _ = result.snapInfo {
                // Could be used to show snap points in UI
            }
        } else {
            // No preview for invalid positions
            uiState.ghostTransform = nil
            uiState.showSnapIndicator = false
            uiState.manipulatingPieceId = pieceId
            
            // Show validation feedback
            if let violation = result.violations.first {
                switch violation.type {
                case .overlap:
                    // Silent - visual feedback is enough
                    break
                case .connectionBroken:
                    // Silent - shouldn't happen with proper constraints
                    break
                case .outOfBounds:
                    // Silent - allow temporary out of bounds during manipulation
                    break
                }
            }
        }
    }
    
    /// Confirm the rotation and apply it to the piece
    func confirmRotation() {
        guard let pieceId = uiState.manipulatingPieceId else {
            return  // No piece being manipulated
        }
        
        // Only apply transform if we have a valid ghost position
        if let transform = uiState.ghostTransform,
           let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) {
            performPuzzleModification {
                puzzle.pieces[pieceIndex].transform = transform
            }
            // Update manipulation modes after confirming rotation
            updateManipulationModes()
        }
        
        // ALWAYS clear manipulation state, even if no valid transform
        initialManipulationTransforms.removeValue(forKey: pieceId)  // Clear before setting to nil
        uiState.manipulatingPieceId = nil
        uiState.ghostTransform = nil
        uiState.showSnapIndicator = false
    }
    
    /// Handle sliding gesture for a piece with single edge connection
    func handleSlide(pieceId: String, distance: Double) {
        guard let mode = pieceManipulationModes[pieceId],
              case .slidable(let edge, _, _) = mode,
              let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return
        }
        
        // Store initial transform if this is the first manipulation
        if initialManipulationTransforms[pieceId] == nil {
            initialManipulationTransforms[pieceId] = piece.transform
        }
        
        // Get the initial transform (before any sliding in this gesture)
        guard let initialTransform = initialManipulationTransforms[pieceId] else {
            return
        }
        
        // Create a piece with the initial transform to apply the slide to
        var slidingPiece = piece
        slidingPiece.transform = initialTransform
        
        // Get the connection for this piece
        let connection = puzzle.connections.first { $0.involvesPiece(pieceId) }
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        
        // Convert ManipulationMode.Edge to PieceTransformEngine.Edge
        let engineEdge = PieceTransformEngine.Edge(
            start: edge.start,
            end: edge.end,
            vector: edge.vector
        )
        
        // Use unified transform engine - distance is the delta from the initial position
        let result = transformEngine.calculateTransform(
            for: slidingPiece,
            operation: .slide(distance: distance, edge: engineEdge),
            connection: connection,
            otherPieces: otherPieces,
            canvasSize: uiState.currentCanvasSize
        )
        
        // Apply result to UI state (same as rotation)
        if result.isValid {
            uiState.ghostTransform = result.transform
            uiState.showSnapIndicator = true
            uiState.manipulatingPieceId = pieceId
        } else {
            // No preview for invalid positions
            uiState.ghostTransform = nil
            uiState.showSnapIndicator = false
            uiState.manipulatingPieceId = pieceId
        }
    }
    
    /// Confirm the slide and apply it to the piece
    func confirmSlide() {
        guard let pieceId = uiState.manipulatingPieceId else {
            return  // No piece being manipulated
        }
        
        // Only apply transform if we have a valid ghost position
        if let transform = uiState.ghostTransform,
           let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) {
            performPuzzleModification {
                puzzle.pieces[pieceIndex].transform = transform
            }
            // Update manipulation modes after confirming slide
            updateManipulationModes()
        }
        
        // ALWAYS clear manipulation state, even if no valid transform
        initialManipulationTransforms.removeValue(forKey: pieceId)  // Clear before setting to nil
        uiState.manipulatingPieceId = nil
        uiState.ghostTransform = nil
        uiState.showSnapIndicator = false
    }
    
    /// Cancel any ongoing manipulation
    func cancelManipulation() {
        if let pieceId = uiState.manipulatingPieceId {
            initialManipulationTransforms.removeValue(forKey: pieceId)  // Clear initial transform
        }
        uiState.manipulatingPieceId = nil
        uiState.ghostTransform = nil
        uiState.showSnapIndicator = false
    }
    
    // MARK: - State Transition Helper
    
    func transitionToState(_ newState: EditorState) -> Bool {
        let success = stateManager.transition(to: newState, puzzle: puzzle)
        if success {
            // Update the observable editorState to trigger UI updates
            editorState = stateManager.currentState
        }
        return success
    }
    
    // MARK: - Private Helpers
    
    func isPieceTypeAlreadyPlaced(_ type: PieceType) -> Bool {
        puzzle.pieces.contains { $0.type == type }
    }
    
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