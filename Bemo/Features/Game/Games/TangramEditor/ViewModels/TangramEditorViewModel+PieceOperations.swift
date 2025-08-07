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
            // First piece doesn't need special treatment anymore
            puzzle.pieces.append(piece)
            // Clear pending piece type after successful placement
            uiState.pendingPieceType = nil
            uiState.pendingPieceRotation = 0
            // After placing first piece, transition to selecting next piece
            _ = transitionToState(.selectingNextPiece)
            setupNewState()  // Clear pending state properly
            updateManipulationModes()
            validate()
            // No need to recenter for first piece - it's already centered
            notifyPuzzleChanged()
            toastService.showSuccess("First piece placed")
            
        case .selectingPendingConnections, .manipulatingPendingPiece:
            print("[DEBUG] confirmPendingPiece - Current state: \(editorState)")
            print("[DEBUG] Preview piece: \(uiState.previewPiece != nil)")
            print("[DEBUG] Selected canvas points: \(uiState.selectedCanvasPoints.count)")
            print("[DEBUG] Selected pending points: \(uiState.selectedPendingPoints.count)")
            
            // Use the preview piece if available
            if let preview = uiState.previewPiece {
                // DON'T append preview here - coordinator.placeConnectedPiece will create and append the piece
                // This was causing duplicate pieces bug!
                // puzzle.pieces.append(preview)  // REMOVED - FIX FOR DUPLICATE PIECES
                
                // Create connections based on the selected points
                if let type = uiState.pendingPieceType {
                    let result = coordinator.placeConnectedPiece(
                        type: type,
                        rotation: uiState.pendingPieceRotation * .pi / 180,
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
                
                updateManipulationModes()
                validate()
                // Recenter puzzle after adding connected piece
                recenterPuzzle()
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
        // Check if piece can be removed (not structurally critical)
        guard puzzle.pieces.first(where: { $0.id == id }) != nil else { return }
        
        // For now, allow deletion of any piece except the first one
        if puzzle.pieces.first?.id == id && puzzle.pieces.count > 1 {
            handleError(.operationNotAllowed("Cannot delete the base piece while other pieces exist"))
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
        // Check if any selected pieces are the base piece
        let selectedPieces = puzzle.pieces.filter { uiState.selectedPieceIds.contains($0.id) }
        
        if let firstPiece = puzzle.pieces.first,
           selectedPieces.contains(where: { $0.id == firstPiece.id }) && puzzle.pieces.count > 1 {
            handleError(.operationNotAllowed("Cannot delete the base piece while other pieces exist"))
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
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        switch mode {
        case .rotatable(let pivot, _):
            let piece = puzzle.pieces[pieceIndex]
            
            // Store initial transform if not already stored
            if initialManipulationTransforms[pieceId] == nil {
                initialManipulationTransforms[pieceId] = piece.transform
            }
            
            guard let initialTransform = initialManipulationTransforms[pieceId] else { return }
            
            // IMPORTANT: 'angle' is already a DELTA in RADIANS, already snapped by PieceView
            // No conversion or snapping needed!
            let deltaRadians = angle
            
            // Find the connection for this piece
            let relevantConnection = puzzle.connections.first { conn in
                conn.involvesPiece(pieceId)
            }
            
            // Get which vertex of this piece is connected
            var pieceVertexIndex = 0
            if let connection = relevantConnection {
                switch connection.type {
                case .vertexToVertex(let pieceAId, let vertexA, _, let vertexB):
                    pieceVertexIndex = (pieceAId == pieceId) ? vertexA : vertexB
                case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
                    if pieceAId == pieceId {
                        pieceVertexIndex = vertex
                        // For vertex-to-edge, we need special handling
                        // The vertex can slide along the edge during rotation
                        // This requires calculating where on the edge the vertex projects to
                    } else {
                        return // This piece is the edge, not the vertex
                    }
                default:
                    return // Edge-to-edge connections don't rotate
                }
            }
            
            // Get the piece's LOCAL vertex (in piece coordinate space)
            let geometry = TangramGeometry.vertices(for: piece.type)
            guard pieceVertexIndex < geometry.count else { return }
            let localVertex = geometry[pieceVertexIndex]
            
            // Scale to visual space
            let visualVertex = CGPoint(
                x: localVertex.x * CGFloat(TangramConstants.visualScale),
                y: localVertex.y * CGFloat(TangramConstants.visualScale)
            )
            
            // Get the initial rotation from the initial transform
            let initialRotation = atan2(initialTransform.b, initialTransform.a)
            
            // Calculate the new total rotation (initial + delta)
            let totalRotation = initialRotation + deltaRadians
            
            // CORRECT APPROACH: Rotate around the pivot point, not the origin
            // The connected vertex must stay exactly at the pivot point
            
            // First apply the initial transform to get current vertex position
            let currentVertex = visualVertex.applying(initialTransform)
            
            // Calculate the offset from the pivot to maintain connection
            let offsetX = pivot.x - currentVertex.x
            let offsetY = pivot.y - currentVertex.y
            
            // Special handling for vertex-to-edge connections
            var correctedTransform: CGAffineTransform
            
            if let connection = relevantConnection,
               case .vertexToEdge(_, _, let pieceBId, let edgeIndex) = connection.type {
                // For vertex-to-edge: the vertex can slide along the edge during rotation
                // Calculate the rotated position, then project it onto the edge
                
                // First, create the standard rotation transform
                var rotTransform = CGAffineTransform.identity
                rotTransform = rotTransform.translatedBy(x: pivot.x, y: pivot.y)
                rotTransform = rotTransform.rotated(by: totalRotation)
                rotTransform = rotTransform.translatedBy(x: -visualVertex.x, y: -visualVertex.y)
                
                // Apply this transform to find where the vertex would be
                let rotatedVertex = visualVertex.applying(rotTransform)
                
                // Get the edge piece and its edge
                if let edgePiece = puzzle.pieces.first(where: { $0.id == pieceBId }) {
                    let edgeVertices = TangramCoordinateSystem.getWorldVertices(for: edgePiece)
                    let edges = TangramGeometry.edges(for: edgePiece.type)
                    
                    if edgeIndex < edges.count {
                        let edgeDef = edges[edgeIndex]
                        let edgeStart = edgeVertices[edgeDef.startVertex]
                        let edgeEnd = edgeVertices[edgeDef.endVertex]
                        
                        // Project the rotated vertex onto the edge
                        let edgeVector = CGVector(dx: edgeEnd.x - edgeStart.x, dy: edgeEnd.y - edgeStart.y)
                        let edgeLength = sqrt(edgeVector.dx * edgeVector.dx + edgeVector.dy * edgeVector.dy)
                        
                        if edgeLength > 0.001 {
                            // Calculate projection
                            let toVertex = CGVector(dx: rotatedVertex.x - edgeStart.x, dy: rotatedVertex.y - edgeStart.y)
                            let t = max(0, min(1, (toVertex.dx * edgeVector.dx + toVertex.dy * edgeVector.dy) / (edgeLength * edgeLength)))
                            
                            // Find the closest point on the edge
                            let projectedPoint = CGPoint(
                                x: edgeStart.x + t * edgeVector.dx,
                                y: edgeStart.y + t * edgeVector.dy
                            )
                            
                            // Adjust the transform to place vertex at the projected point
                            correctedTransform = CGAffineTransform.identity
                            correctedTransform = correctedTransform.translatedBy(x: projectedPoint.x, y: projectedPoint.y)
                            correctedTransform = correctedTransform.rotated(by: totalRotation)
                            correctedTransform = correctedTransform.translatedBy(x: -visualVertex.x, y: -visualVertex.y)
                        } else {
                            correctedTransform = rotTransform
                        }
                    } else {
                        correctedTransform = rotTransform
                    }
                } else {
                    correctedTransform = rotTransform
                }
            } else {
                // Standard vertex-to-vertex rotation
                // Create transform that:
                // 1. Translates piece so connected vertex is at origin
                // 2. Rotates by the total angle
                // 3. Translates back so vertex is at pivot
                correctedTransform = CGAffineTransform.identity
                correctedTransform = correctedTransform.translatedBy(x: pivot.x, y: pivot.y)
                correctedTransform = correctedTransform.rotated(by: totalRotation)
                correctedTransform = correctedTransform.translatedBy(x: -visualVertex.x, y: -visualVertex.y)
            }
            
            // CRITICAL: Use comprehensive validation
            // Create a test piece with the same ID for connection validation
            var testPiece = piece  // Copy the existing piece
            testPiece.transform = correctedTransform  // Update only the transform
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            
            if PuzzleValidationRules.isValidPlacement(
                piece: testPiece,
                withTransform: correctedTransform,
                amongPieces: otherPieces,
                maintainingConnection: relevantConnection
            ) {
                // Only show preview if valid
                uiState.ghostTransform = correctedTransform
                uiState.showSnapIndicator = true
                uiState.manipulatingPieceId = pieceId
            } else {
                // NO PREVIEW for invalid positions
                uiState.ghostTransform = nil
                uiState.showSnapIndicator = false
                // Keep manipulatingPieceId to track we're still manipulating
                uiState.manipulatingPieceId = pieceId
            }
            
        default:
            break
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
            undoManager.saveState(puzzle: puzzle)
            puzzle.pieces[pieceIndex].transform = transform
            
            // Update manipulation modes after confirming rotation
            updateManipulationModes()
            validate()
            notifyPuzzleChanged()
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
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        switch mode {
        case .slidable(let edge, let baseRange, _):
            let piece = puzzle.pieces[pieceIndex]
            
            // Store initial transform if not already stored
            if initialManipulationTransforms[pieceId] == nil {
                initialManipulationTransforms[pieceId] = piece.transform
            }
            
            guard let initialTransform = initialManipulationTransforms[pieceId] else { return }
            
            // IMPORTANT: 'distance' is already snapped by PieceView
            // No additional snapping needed!
            let snappedDistance = distance
            
            // Create translation from initial position
            let translation = CGAffineTransform(
                translationX: edge.vector.dx * CGFloat(snappedDistance),
                y: edge.vector.dy * CGFloat(snappedDistance)
            )
            
            // Apply to initial transform
            let finalTransform = initialTransform.concatenating(translation)
            
            // Find the connection this piece is maintaining
            let relevantConnection = puzzle.connections.first { conn in
                conn.pieceAId == pieceId || conn.pieceBId == pieceId
            }
            
            // CRITICAL: Use comprehensive validation
            // Create a test piece with the same ID for connection validation
            var testPiece = piece  // Copy the existing piece
            testPiece.transform = finalTransform  // Update only the transform
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            
            if PuzzleValidationRules.isValidPlacement(
                piece: testPiece,
                withTransform: finalTransform,
                amongPieces: otherPieces,
                maintainingConnection: relevantConnection
            ) {
                // Only show preview if valid
                uiState.ghostTransform = finalTransform
                uiState.showSnapIndicator = true
                uiState.manipulatingPieceId = pieceId
            } else {
                // NO PREVIEW for invalid positions
                uiState.ghostTransform = nil
                uiState.showSnapIndicator = false
                // Keep manipulatingPieceId to track we're still manipulating
                uiState.manipulatingPieceId = pieceId
            }
            
        default:
            break
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
            undoManager.saveState(puzzle: puzzle)
            puzzle.pieces[pieceIndex].transform = transform
            
            // Update manipulation modes after confirming slide
            updateManipulationModes()
            validate()
            notifyPuzzleChanged()
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