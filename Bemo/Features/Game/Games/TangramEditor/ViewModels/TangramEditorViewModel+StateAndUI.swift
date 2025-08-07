//
//  TangramEditorViewModel+StateAndUI.swift
//  Bemo
//
//  UI state and connection management for Tangram Editor
//

// WHAT: Extension handling UI interactions, connections, and validation
// ARCHITECTURE: ViewModel extension for UI-related logic and state management
// USAGE: Contains selection, connection points, preview updates, and UI state management

import Foundation
import SwiftUI

extension TangramEditorViewModel {
    
    // MARK: - Connection Management
    
    func getConnectionPointsForPendingPiece(type: PieceType, scale: CGFloat) -> [ConnectionPoint] {
        // For the pending piece preview, we need connection points in local space
        // (not transformed) because PendingConnectionPoint will apply rotation and centering
        var points: [ConnectionPoint] = []
        let vertices = TangramGeometry.vertices(for: type)
        
        // Always use TangramConstants.visualScale for consistency
        let scaledVertices = vertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale)
        }
        
        // Create a dummy piece ID for consistency
        let pieceId = "pending_\(type.rawValue)"
        
        // Add vertex points (in local space, will be rotated by PendingConnectionPoint)
        for (index, vertex) in scaledVertices.enumerated() {
            points.append(ConnectionPoint(
                type: .vertex(index: index),
                position: vertex,
                pieceId: pieceId
            ))
        }
        
        // Add edge midpoints (in local space)
        for i in 0..<scaledVertices.count {
            let start = scaledVertices[i]
            let end = scaledVertices[(i + 1) % scaledVertices.count]
            let midpoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            points.append(ConnectionPoint(
                type: .edge(index: i),
                position: midpoint,
                pieceId: pieceId
            ))
        }
        
        return points
    }
    
    func togglePendingPoint(_ point: ConnectionPoint) {
        if let index = uiState.selectedPendingPoints.firstIndex(where: { $0.id == point.id }) {
            uiState.selectedPendingPoints.remove(at: index)
        } else {
            uiState.selectedPendingPoints.append(point)
        }
        
        // Update preview whenever selection changes
        updatePreviewIfNeeded()
        
        // Don't automatically transition - let user confirm when ready
    }
    
    func toggleCanvasPoint(_ point: ConnectionPoint) {
        if let index = uiState.selectedCanvasPoints.firstIndex(where: { $0.id == point.id }) {
            uiState.selectedCanvasPoints.remove(at: index)
        } else {
            uiState.selectedCanvasPoints.append(point)
        }
        
        // Check if we have the maximum number of points
        if uiState.selectedCanvasPoints.count >= 2 {
            proceedToPendingPiece()
        }
    }
    
    func proceedToPendingPiece() {
        // Transition to selecting pending piece connections
        if !uiState.selectedCanvasPoints.isEmpty, let type = uiState.pendingPieceType {
            _ = transitionToState(.selectingPendingConnections(pieceType: type, maxPoints: uiState.selectedCanvasPoints.count))
        }
    }
    
    func getConnectionPoints(for pieceId: String) -> [ConnectionPoint] {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return []
        }
        // Use centralized coordinate system directly for better performance
        return TangramCoordinateSystem.getConnectionPoints(for: piece)
    }
    
    // MARK: - Selection Management
    
    func selectPiece(id: String) {
        // Check if piece exists
        guard puzzle.pieces.first(where: { $0.id == id }) != nil else { return }
        
        // Transition to piece selected state
        _ = transitionToState(.pieceSelected(id: id))
        
        if uiState.editMode == .select {
            uiState.selectedPieceIds.insert(id)
        }
    }
    
    func togglePieceSelection(_ pieceId: String) {
        if uiState.selectedPieceIds.contains(pieceId) {
            uiState.selectedPieceIds.remove(pieceId)
        } else {
            uiState.selectedPieceIds.insert(pieceId)
        }
    }
    
    func clearSelection() {
        uiState.selectedPieceIds.removeAll()
    }
    
    func selectAllPieces() {
        uiState.selectedPieceIds = Set(puzzle.pieces.map { $0.id })
    }
    
    // MARK: - Validation
    
    func validate() {
        validationState = coordinator.validatePuzzle(puzzle)
    }
    
    // MARK: - UI State Methods
    
    func toggleSettings() {
        uiState.showSettings.toggle()
    }
    
    func requestSave() {
        uiState.showSaveDialog = true
    }
    
    func reset() {
        puzzle = TangramPuzzle(name: "New Puzzle")
        uiState.selectedPieceIds.removeAll()
        validationState = .unknown
        uiState.editMode = .select
        // Start in selectingFirstPiece for new empty puzzles
        stateManager.setInitialState(for: puzzle)
        editorState = stateManager.currentState
        undoManager.clearHistory()
    }
    
    func clearPuzzle() {
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces.removeAll()
        puzzle.connections.removeAll()
        uiState.selectedPieceIds.removeAll()
        validationState = .unknown
        // After clearing, start selecting first piece
        stateManager.setInitialState(for: puzzle)
        editorState = stateManager.currentState
        notifyPuzzleChanged()
    }
    
    func recenterPuzzle() {
        guard !puzzle.pieces.isEmpty else { 
            return 
        }
        
        // Don't recenter if canvas size is not properly set
        guard uiState.currentCanvasSize.width > 0 && uiState.currentCanvasSize.height > 0 else {
            return
        }
        
        // Use centralized coordinate system to get current center
        guard let currentCenter = TangramCoordinateSystem.getCenter(of: puzzle.pieces) else {
            return
        }
        
        // Calculate target center
        let targetCenter = CGPoint(
            x: uiState.currentCanvasSize.width / 2,
            y: uiState.currentCanvasSize.height / 2
        )
        
        // Calculate translation needed
        let dx = targetCenter.x - currentCenter.x
        let dy = targetCenter.y - currentCenter.y
        
        // Check for valid translation values
        if !dx.isFinite || !dy.isFinite {
            return
        }
        
        // Apply translation to all pieces
        undoManager.saveState(puzzle: puzzle)
        for i in 0..<puzzle.pieces.count {
            // Use direct world-space translation (centralized system pattern)
            var newTransform = puzzle.pieces[i].transform
            newTransform.tx += dx
            newTransform.ty += dy
            puzzle.pieces[i].transform = newTransform
        }
        
        notifyPuzzleChanged()
    }
    
    // MARK: - Preview Management
    
    func updatePreviewIfNeeded() {
        // Update preview based on current selection
        guard let type = uiState.pendingPieceType else { return }
        
        // Only update preview when we're in the right state
        switch editorState {
        case .selectingPendingConnections, .manipulatingPendingPiece:
            // Check if we have matching connection counts
            if !uiState.selectedCanvasPoints.isEmpty && 
               uiState.selectedCanvasPoints.count == uiState.selectedPendingPoints.count {
                
                // Create connection pairs
                var connections: [(canvasPoint: ConnectionPoint, piecePoint: ConnectionPoint)] = []
                
                // Group by type to ensure proper pairing
                let canvasVertices = uiState.selectedCanvasPoints.filter { 
                    if case .vertex = $0.type { return true } else { return false }
                }
                let canvasEdges = uiState.selectedCanvasPoints.filter { 
                    if case .edge = $0.type { return true } else { return false }
                }
                let pieceVertices = uiState.selectedPendingPoints.filter { 
                    if case .vertex = $0.type { return true } else { return false }
                }
                let pieceEdges = uiState.selectedPendingPoints.filter { 
                    if case .edge = $0.type { return true } else { return false }
                }
                
                // Pair vertices with vertices
                for (canvasVertex, pieceVertex) in zip(canvasVertices, pieceVertices) {
                    connections.append((canvasPoint: canvasVertex, piecePoint: pieceVertex))
                }
                
                // Pair edges with edges
                for (canvasEdge, pieceEdge) in zip(canvasEdges, pieceEdges) {
                    connections.append((canvasPoint: canvasEdge, piecePoint: pieceEdge))
                }
                
                // Calculate placement
                if let placedPiece = placementService.placeConnectedPiece(
                    type: type,
                    rotation: uiState.pendingPieceRotation * .pi / 180,
                    connections: connections,
                    existingPieces: puzzle.pieces
                ) {
                    // Use transform engine for validation
                    let result = transformEngine.calculateTransform(
                        for: placedPiece,
                        operation: .place(center: CGPoint.zero, rotation: 0), // Already positioned
                        connection: nil,
                        otherPieces: puzzle.pieces,
                        canvasSize: uiState.currentCanvasSize
                    )
                    
                    if result.isValid {
                        uiState.previewPiece = placedPiece
                        uiState.previewTransform = placedPiece.transform
                    } else {
                        // NO PREVIEW for invalid positions
                        uiState.previewPiece = nil
                        uiState.previewTransform = nil
                    }
                } else {
                    uiState.previewPiece = nil
                    uiState.previewTransform = nil
                }
            } else {
                uiState.previewPiece = nil
                uiState.previewTransform = nil
            }
            
        default:
            break
        }
    }
    
    func updateAvailableConnectionPoints() {
        availableConnectionPoints = puzzle.pieces.flatMap { piece in
            placementService.getConnectionPoints(for: piece)
        }
    }
    
    func clearSelectionState() {
        uiState.clearSelectionState()
        availableConnectionPoints.removeAll()
    }
    
    func notifyPuzzleChanged() {
        onPuzzleChanged?(puzzle)
    }
    
    // MARK: - State Management Helpers
    
    /// Cleanup when leaving current state (called by state machine transitions)
    func cleanupCurrentState() {
        switch editorState {
        case .selectingCanvasConnections:
            // Don't clear canvas points when transitioning to pending selection
            // They need to be preserved for the connection matching
            break
        case .selectingPendingConnections:
            // Clear both when leaving pending connections (either placing or cancelling)
            uiState.selectedCanvasPoints.removeAll()
            uiState.selectedPendingPoints.removeAll()
        case .manipulatingPendingPiece, .manipulatingExistingPiece:
            uiState.ghostTransform = nil
            uiState.manipulatingPieceId = nil
            uiState.showSnapIndicator = false
        default:
            break
        }
    }
    
    /// Setup when entering new state (called after state transitions)
    func setupNewState() {
        switch editorState {
        case .selectingFirstPiece:
            clearSelectionState()
        case .selectingNextPiece:
            // Clear all pending state when starting to select a new piece
            uiState.pendingPieceType = nil
            uiState.pendingPieceRotation = 0
            uiState.previewPiece = nil
            uiState.previewTransform = nil
            uiState.selectedCanvasPoints.removeAll()
            uiState.selectedPendingPoints.removeAll()
            availableConnectionPoints.removeAll()
        case .selectingCanvasConnections:
            updateAvailableConnectionPoints()
        default:
            break
        }
    }
}

// MARK: - Extension for PlacementError

extension TangramEditorCoordinator.PlacementError {
    var localizedDescription: String {
        switch self {
        case .invalidConnections:
            return "Invalid connection points selected"
        case .placementCalculationFailed:
            return "Could not calculate piece placement"
        case .overlappingPieces:
            return "Piece would overlap with existing pieces"
        case .validationFailed:
            return "Placement validation failed"
        }
    }
}