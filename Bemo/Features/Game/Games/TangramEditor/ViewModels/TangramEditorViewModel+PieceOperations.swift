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
        print("[CONFIRM] Starting confirmPendingPiece")
        print("[CONFIRM] Current editorState: \(editorState)")
        print("[CONFIRM] Current stateManager.currentState: \(stateManager.currentState)")
        
        undoManager.saveState(puzzle: puzzle)
        
        let size = canvasSize ?? uiState.currentCanvasSize
        
        switch editorState {
        case .manipulatingFirstPiece(let type, let rotation, _):
            // Place first piece at center (convert degrees to radians)
            var piece = placementService.placeFirstPiece(
                type: type,
                rotation: rotation * .pi / 180,
                canvasSize: size
            )
            piece.isLocked = true  // First piece is always locked
            puzzle.pieces.append(piece)
            // Clear pending piece type after successful placement
            uiState.pendingPieceType = nil
            uiState.pendingPieceRotation = 0
            // After placing first piece, transition to selecting next piece
            _ = transitionToState(.selectingNextPiece)
            setupNewState()  // Clear pending state properly
            autoLockPieces()  // Auto-lock based on connections
            updateManipulationModes()
            validate()
            notifyPuzzleChanged()
            toastService.showSuccess("First piece placed")
            
        case .selectingPendingConnections, .manipulatingPendingPiece:
            print("[DEBUG] confirmPendingPiece - Current state: \(editorState)")
            print("[DEBUG] Preview piece: \(uiState.previewPiece != nil)")
            print("[DEBUG] Selected canvas points: \(uiState.selectedCanvasPoints.count)")
            print("[DEBUG] Selected pending points: \(uiState.selectedPendingPoints.count)")
            
            // Use the preview piece if available
            if let preview = uiState.previewPiece {
                puzzle.pieces.append(preview)
                
                // Create connections based on the selected points
                if let type = uiState.pendingPieceType {
                    let result = coordinator.placeConnectedPiece(
                        type: type,
                        rotation: uiState.pendingPieceRotation * .pi / 180,
                        canvasConnections: uiState.selectedCanvasPoints,
                        pieceConnections: uiState.selectedPendingPoints,
                        existingPieces: Array(puzzle.pieces.dropLast()), // Don't include the just-added piece
                        puzzle: &puzzle
                    )
                    
                    if case .failure(_) = result {
                        // Remove the piece if connection creation failed
                        puzzle.pieces.removeLast()
                        handleError(.placementCalculationFailed("Failed to create connections"))
                        return
                    }
                }
                
                print("[DEBUG] Before transition - State: \(editorState)")
                
                // Transition to next state FIRST
                let transitionSuccess = transitionToState(.selectingNextPiece)
                print("[DEBUG] Transition success: \(transitionSuccess)")
                print("[DEBUG] After transition - State: \(editorState)")
                
                // Force clear ALL pending state immediately
                uiState.pendingPieceType = nil
                uiState.pendingPieceRotation = 0
                uiState.previewPiece = nil
                uiState.previewTransform = nil
                uiState.selectedCanvasPoints.removeAll()
                uiState.selectedPendingPoints.removeAll()
                availableConnectionPoints.removeAll()
                
                // Setup the new state (additional cleanup if needed)
                setupNewState()
                
                print("[DEBUG] After force cleanup - pendingPieceType: \(String(describing: uiState.pendingPieceType))")
                print("[DEBUG] After force cleanup - selectedCanvasPoints: \(uiState.selectedCanvasPoints.count)")
                print("[DEBUG] After force cleanup - selectedPendingPoints: \(uiState.selectedPendingPoints.count)")
                print("[DEBUG] Final state: \(editorState)")
                
                autoLockPieces()
                updateManipulationModes()
                validate()
                notifyPuzzleChanged()
                toastService.showSuccess("Piece connected successfully")
            } else {
                // No preview available, shouldn't happen but handle gracefully
                print("[TangramEditor] ERROR: No preview piece available in confirm")
                _ = transitionToState(.selectingNextPiece)
                setupNewState()
            }
            
        case .previewingPlacement(let piece):
            // Add the previewed piece to the puzzle
            puzzle.pieces.append(piece)
            
            // Transition to next state FIRST
            _ = transitionToState(.selectingNextPiece)
            
            // Setup the new state (clears pending state)
            setupNewState()
            
            autoLockPieces()  // Auto-lock based on connections
            updateManipulationModes()
            validate()
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
            print("[TangramEditor] Rotating first piece from \(currentRotation)° to \(newRotation)°")
            let success = transitionToState(.manipulatingFirstPiece(type: type, rotation: newRotation, isFlipped: isFlipped))
            print("[TangramEditor] Transition success: \(success)")
            
        case .selectingPendingConnections, .previewingPlacement:
            // Allow rotation while selecting connections
            uiState.pendingPieceRotation += degrees
            print("[TangramEditor] Rotating pending piece to \(uiState.pendingPieceRotation)°")
            updatePreviewIfNeeded()
            
        case .manipulatingPendingPiece(let type, let mode, let currentRotation):
            let newRotation = currentRotation + degrees
            uiState.pendingPieceRotation = newRotation
            print("[TangramEditor] Rotating pending piece from \(currentRotation)° to \(newRotation)°")
            let success = transitionToState(.manipulatingPendingPiece(type: type, mode: mode, rotation: newRotation))
            print("[TangramEditor] Transition success: \(success)")
            
        default:
            print("[TangramEditor] rotatePendingPiece called in wrong state: \(stateManager.currentState)")
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
        default:
            break
        }
        
        updatePreviewIfNeeded()
    }
    
    // MARK: - Piece Operations
    
    func removePiece(id: String) {
        // Check if piece is locked
        guard let piece = puzzle.pieces.first(where: { $0.id == id }) else { return }
        
        if piece.isLocked {
            handleError(.operationNotAllowed("Piece must be unlocked before deletion"))
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces.removeAll { $0.id == id }
        puzzle.connections.removeAll { $0.involvesPiece(id) }
        validate()
        notifyPuzzleChanged()
        // After removing piece, go to appropriate selection state
        stateManager.resetState(for: puzzle)
        editorState = stateManager.currentState
    }
    
    func removeSelectedPieces() {
        // Check if any selected pieces are locked
        let selectedPieces = puzzle.pieces.filter { uiState.selectedPieceIds.contains($0.id) }
        let lockedPieces = selectedPieces.filter { $0.isLocked }
        
        if !lockedPieces.isEmpty {
            handleError(.operationNotAllowed("\(lockedPieces.count) piece(s) must be unlocked before deletion"))
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        let idsToRemove = uiState.selectedPieceIds
        puzzle.pieces.removeAll { idsToRemove.contains($0.id) }
        puzzle.connections.removeAll { connection in
            idsToRemove.contains { connection.involvesPiece($0) }
        }
        uiState.selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
        // After removing pieces, go to appropriate selection state
        stateManager.resetState(for: puzzle)
        editorState = stateManager.currentState
    }
    
    func updatePieceTransform(id: String, transform: CGAffineTransform) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else { return }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces[index].transform = transform
        validate()
        notifyPuzzleChanged()
    }
    
    // MARK: - Piece Locking
    
    func togglePieceLock(id: String) {
        undoManager.saveState(puzzle: puzzle)
        
        let result = lockingService.toggleLock(id: id, in: &puzzle)
        switch result {
        case .success(let isNowLocked):
            if isNowLocked {
                _ = transitionToState(.pieceSelected(id: id, isLocked: true))
                toastService.showInfo("Piece locked")
            } else {
                _ = transitionToState(.pieceSelected(id: id, isLocked: false))
                toastService.showSuccess("Piece unlocked")
            }
            updateManipulationModes()
            notifyPuzzleChanged()
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    func unlockPiece(id: String) {
        undoManager.saveState(puzzle: puzzle)
        
        let result = lockingService.unlockPiece(id: id, in: &puzzle)
        switch result {
        case .success:
            _ = transitionToState(.manipulatingExistingPiece(id: id, mode: determineManipulationMode(for: id)))
            updateManipulationModes()
            notifyPuzzleChanged()
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    func autoLockPieces() {
        lockingService.autoLockPieces(in: &puzzle)
        updateManipulationModes()
    }
    
    // MARK: - Manipulation Mode Management
    
    /// Determine manipulation mode for a piece based on its connections
    func determineManipulationMode(for pieceId: String) -> ManipulationMode {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return .locked
        }
        
        return manipulationService.calculateManipulationMode(piece: piece, connections: puzzle.connections)
    }
    
    /// Update manipulation modes for all pieces
    func updateManipulationModes() {
        pieceManipulationModes.removeAll()
        
        for piece in puzzle.pieces {
            let mode = determineManipulationMode(for: piece.id)
            pieceManipulationModes[piece.id] = mode
        }
    }
    
    // MARK: - Manipulation Handlers
    
    /// Handle rotation gesture for a piece with single vertex connection
    func handleRotation(pieceId: String, angle: Double) {
        guard let mode = pieceManipulationModes[pieceId],
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        switch mode {
        case .rotatable(let pivot, let snapAngles):
            let piece = puzzle.pieces[pieceIndex]
            
            // Convert angle to degrees for snapping
            let angleDegrees = angle * 180 / .pi
            
            // Find nearest snap angle
            let snappedAngle = snapAngles.min(by: { 
                abs($0 - angleDegrees) < abs($1 - angleDegrees) 
            }) ?? angleDegrees
            
            // Convert back to radians
            let snappedRadians = snappedAngle * .pi / 180
            
            // Create rotation transform around pivot
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: pivot.x, y: pivot.y)
            transform = transform.rotated(by: snappedRadians)
            transform = transform.translatedBy(x: -pivot.x, y: -pivot.y)
            
            // Apply to piece's base transform
            let newTransform = piece.transform.concatenating(transform)
            
            // Check for overlaps with validation service
            let testPiece = TangramPiece(type: piece.type, transform: newTransform)
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            
            var hasOverlap = false
            for other in otherPieces {
                if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                    hasOverlap = true
                    break
                }
            }
            
            if !hasOverlap {
                // Update ghost preview
                uiState.ghostTransform = newTransform
                uiState.showSnapIndicator = abs(angle - snappedRadians) < 0.1
                
                // Store as manipulating piece
                uiState.manipulatingPieceId = pieceId
            }
            
        default:
            break
        }
    }
    
    /// Confirm the rotation and apply it to the piece
    func confirmRotation() {
        guard let pieceId = uiState.manipulatingPieceId,
              let transform = uiState.ghostTransform,
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces[pieceIndex].transform = transform
        
        // Clear manipulation state
        uiState.manipulatingPieceId = nil
        uiState.ghostTransform = nil
        uiState.showSnapIndicator = false
        
        validate()
        notifyPuzzleChanged()
    }
    
    /// Handle sliding gesture for a piece with single edge connection
    func handleSlide(pieceId: String, distance: Double) {
        guard let mode = pieceManipulationModes[pieceId],
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        switch mode {
        case .slidable(let edge, let range, let snapPositions):
            let piece = puzzle.pieces[pieceIndex]
            
            // Clamp distance to valid range
            let clampedDistance = max(range.lowerBound, min(range.upperBound, distance))
            
            // Find nearest snap position
            let normalizedDistance = (clampedDistance - range.lowerBound) / (range.upperBound - range.lowerBound)
            let snappedPosition = snapPositions.min(by: {
                abs($0 - normalizedDistance) < abs($1 - normalizedDistance)
            }) ?? normalizedDistance
            
            // Convert back to actual distance
            let snappedDistance = range.lowerBound + snappedPosition * (range.upperBound - range.lowerBound)
            
            // Calculate translation along edge vector
            let translation = CGVector(
                dx: edge.vector.dx * snappedDistance,
                dy: edge.vector.dy * snappedDistance
            )
            
            // Create new transform
            var newTransform = piece.transform
            newTransform.tx += translation.dx
            newTransform.ty += translation.dy
            
            // Check for overlaps
            let testPiece = TangramPiece(type: piece.type, transform: newTransform)
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            
            var hasOverlap = false
            for other in otherPieces {
                if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                    hasOverlap = true
                    break
                }
            }
            
            if !hasOverlap {
                // Update ghost preview
                uiState.ghostTransform = newTransform
                uiState.showSnapIndicator = snapPositions.contains(snappedPosition)
                
                // Store as manipulating piece
                uiState.manipulatingPieceId = pieceId
            }
            
        default:
            break
        }
    }
    
    /// Confirm the slide and apply it to the piece
    func confirmSlide() {
        guard let pieceId = uiState.manipulatingPieceId,
              let transform = uiState.ghostTransform,
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces[pieceIndex].transform = transform
        
        // Clear manipulation state
        uiState.manipulatingPieceId = nil
        uiState.ghostTransform = nil
        uiState.showSnapIndicator = false
        
        validate()
        notifyPuzzleChanged()
    }
    
    /// Cancel any ongoing manipulation
    func cancelManipulation() {
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
        uiState.previewPiece = nil
        uiState.previewTransform = nil
        uiState.selectedCanvasPoints.removeAll()
        uiState.selectedPendingPoints.removeAll()
        availableConnectionPoints.removeAll()
        
        // Clear UI state as well
        uiState.pendingPieceType = nil
        uiState.pendingPieceRotation = 0
        uiState.previewTransform = nil
        uiState.previewPiece = nil
        uiState.selectedCanvasPoints.removeAll()
        uiState.selectedPendingPoints.removeAll()
    }
}