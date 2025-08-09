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
    
    // proceedToPendingPiece is in Navigation extension
    
    func getConnectionPoints(for pieceId: String) -> [ConnectionPoint] {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return []
        }
        // Use centralized coordinate system directly for better performance
        return TangramEditorCoordinateSystem.getConnectionPoints(for: piece)
    }
    
    // MARK: - Selection Management
    
    func selectPiece(id: String) {
        // Check if piece exists
        guard puzzle.pieces.first(where: { $0.id == id }) != nil else { return }
        
        // Transition to piece selected state
        _ = transitionToState(.pieceSelected(pieceId: id))
        
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
    
    // validate is in Validation extension
    
    // MARK: - UI State Methods
    
    func toggleSettings() {
        uiState.showSettings.toggle()
    }
    
    // requestSave is in Navigation extension
    
    // reset is in Navigation extension
    
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
        guard let currentCenter = TangramEditorCoordinateSystem.getCenter(of: puzzle.pieces) else {
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
                
                // Calculate placement - add debug for parallelogram issues
                if type == .parallelogram {
                    print("🔍 PARALLELOGRAM PLACEMENT DEBUG:")
                    print("  - isFlipped: \(uiState.pendingPieceIsFlipped)")
                    print("  - rotation: \(uiState.pendingPieceRotation)°")
                    print("  - connections:")
                    for (i, conn) in connections.enumerated() {
                        let canvasType = conn.canvasPoint.type
                        let pieceType = conn.piecePoint.type
                        print("    \(i): canvas=\(canvasType) -> piece=\(pieceType)")
                    }
                }
                
                if let placedPiece = placementService.placeConnectedPiece(
                    type: type,
                    rotation: uiState.pendingPieceRotation * .pi / 180,
                    isFlipped: uiState.pendingPieceIsFlipped && type == .parallelogram,
                    connections: connections,
                    existingPieces: puzzle.pieces
                ) {
                    for _ in connections {
                    }
                    
                    // Create a Connection object for validation based on the connection points
                    // This tells the validator that these pieces are supposed to be connected
                    var validationConnection: Connection? = nil
                    if let firstConnection = connections.first,
                       let canvasPieceId = firstConnection.canvasPoint.pieceId.split(separator: "_").first {
                        let canvasPieceIdStr = String(canvasPieceId)
                        
                        // For flipped parallelogram, remap the piece indices to match the physical vertices/edges
                        // after the flip transform has been applied
                        var actualPieceVertexIndex: Int? = nil
                        var actualPieceEdgeIndex: Int? = nil
                        
                        if placedPiece.type == .parallelogram && uiState.pendingPieceIsFlipped {
                            // Apply remapping for flipped parallelogram
                            if case .vertex(let index) = firstConnection.piecePoint.type {
                                actualPieceVertexIndex = TangramEditorCoordinateSystem.remapParallelogramVertexIndex(index)
                            } else if case .edge(let index) = firstConnection.piecePoint.type {
                                actualPieceEdgeIndex = TangramEditorCoordinateSystem.remapParallelogramEdgeIndex(index)
                            }
                        } else {
                            // No remapping for other pieces or non-flipped parallelogram
                            if case .vertex(let index) = firstConnection.piecePoint.type {
                                actualPieceVertexIndex = index
                            } else if case .edge(let index) = firstConnection.piecePoint.type {
                                actualPieceEdgeIndex = index
                            }
                        }
                        
                        // Determine connection type based on the points (using actual indices)
                        if case .vertex(let canvasVertexIndex) = firstConnection.canvasPoint.type,
                           let pieceVertexIndex = actualPieceVertexIndex {
                            validationConnection = Connection(
                                type: .vertexToVertex(
                                    pieceAId: canvasPieceIdStr,
                                    vertexA: canvasVertexIndex,
                                    pieceBId: placedPiece.id,
                                    vertexB: pieceVertexIndex
                                ),
                                constraint: Constraint(type: .fixed, affectedPieceId: placedPiece.id)
                            )
                        } else if case .edge(let canvasEdgeIndex) = firstConnection.canvasPoint.type,
                                  let pieceEdgeIndex = actualPieceEdgeIndex {
                            let connectionType = ConnectionType.edgeToEdge(
                                pieceAId: canvasPieceIdStr,
                                edgeA: canvasEdgeIndex,
                                pieceBId: placedPiece.id,
                                edgeB: pieceEdgeIndex
                            )
                            // Create connection service temporarily for constraint calculation
                            let connectionService = ConnectionService()
                            validationConnection = connectionService.createConnection(
                                type: connectionType,
                                pieces: puzzle.pieces + [placedPiece]
                            )
                        } else if case .vertex(let canvasVertexIndex) = firstConnection.canvasPoint.type,
                                  let pieceEdgeIndex = actualPieceEdgeIndex {
                            let connectionType = ConnectionType.vertexToEdge(
                                pieceAId: canvasPieceIdStr,
                                vertex: canvasVertexIndex,
                                pieceBId: placedPiece.id,
                                edge: pieceEdgeIndex
                            )
                            // Create connection service temporarily for constraint calculation
                            let connectionService = ConnectionService()
                            validationConnection = connectionService.createConnection(
                                type: connectionType,
                                pieces: puzzle.pieces + [placedPiece]
                            )
                        } else if case .edge(let canvasEdgeIndex) = firstConnection.canvasPoint.type,
                                  let pieceVertexIndex = actualPieceVertexIndex {
                            let connectionType = ConnectionType.vertexToEdge(
                                pieceAId: placedPiece.id,
                                vertex: pieceVertexIndex,
                                pieceBId: canvasPieceIdStr,
                                edge: canvasEdgeIndex
                            )
                            // Create connection service temporarily for constraint calculation
                            let connectionService = ConnectionService()
                            validationConnection = connectionService.createConnection(
                                type: connectionType,
                                pieces: puzzle.pieces + [placedPiece]
                            )
                        }
                    }
                    
                    // Use transform engine for validation WITH connection info
                    // Calculate the current center of the placed piece from its world vertices
                    let placedVertices = TangramEditorCoordinateSystem.getWorldVertices(for: placedPiece)
                    var centerX: CGFloat = 0
                    var centerY: CGFloat = 0
                    for vertex in placedVertices {
                        centerX += vertex.x
                        centerY += vertex.y
                    }
                    centerX /= CGFloat(placedVertices.count)
                    centerY /= CGFloat(placedVertices.count)
                    let currentCenter = CGPoint(x: centerX, y: centerY)
                    
                    // Use .drag(to: currentCenter) which is a no-op that preserves the transform
                    // while still running the connection and overlap checks
                    let result = transformEngine.calculateTransform(
                        for: placedPiece,
                        operation: .drag(to: currentCenter), // Preserves as-placed transform
                        connection: validationConnection,
                        otherPieces: puzzle.pieces,
                        canvasSize: uiState.currentCanvasSize
                    )
                    
                    if result.isValid {
                        uiState.previewPiece = placedPiece
                        uiState.previewTransform = placedPiece.transform
                    } else {
                        // Try to find a valid placement nearby
                        if let validPlacement = findValidPlacement(
                            for: placedPiece,
                            connections: connections,
                            existingPieces: puzzle.pieces
                        ) {
                            uiState.previewPiece = validPlacement
                            uiState.previewTransform = validPlacement.transform
                        } else {
                            // Only clear preview if we can't find ANY valid placement
                            uiState.previewPiece = nil
                            uiState.previewTransform = nil
                        }
                    }
                } else {
                    print("[DEBUG] Initial placement FAILED!")
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
    
    // MARK: - Placement Helpers
    
    /// Try to find a valid placement for a piece with given connections
    /// This includes trying different rotations and sliding along edges for tight fits
    private func findValidPlacement(
        for piece: TangramPiece,
        connections: [(canvasPoint: ConnectionPoint, piecePoint: ConnectionPoint)],
        existingPieces: [TangramPiece]
    ) -> TangramPiece? {
        // For edge-to-edge connections, the placeConnectedPiece method already
        // includes sliding search, so we just need to try it with the current rotation
        if connections.count == 1,
           case .edge = connections[0].canvasPoint.type,
           case .edge = connections[0].piecePoint.type {
            
            // Try with current rotation first (sliding search is built-in)
            if let placedPiece = placementService.placeConnectedPiece(
                type: piece.type,
                rotation: uiState.pendingPieceRotation * .pi / 180,
                isFlipped: uiState.pendingPieceIsFlipped && piece.type == .parallelogram,
                connections: connections,
                existingPieces: existingPieces
            ) {
                // Validate "as placed" - DO NOT reset transform with .place(center: .zero)!
                // Calculate current center from world vertices
                let placedVertices = TangramEditorCoordinateSystem.getWorldVertices(for: placedPiece)
                let currentCenter = TangramEditorCoordinateSystem.calculateCenter(of: placedVertices)
                
                // Use .drag which preserves the transform
                let result = transformEngine.calculateTransform(
                    for: placedPiece,
                    operation: .drag(to: currentCenter),
                    connection: nil,
                    otherPieces: existingPieces,
                    canvasSize: uiState.currentCanvasSize
                )
                
                if result.isValid {
                    return placedPiece
                }
            }
        }
        
        // For vertex connections or if edge sliding failed, try different rotation angles
        let rotationAngles = [0, 45, 90, 135, 180, -135, -90, -45].map { Double($0) }
        
        for angle in rotationAngles {
            // Try placing with this rotation
            if let placedPiece = placementService.placeConnectedPiece(
                type: piece.type,
                rotation: angle * .pi / 180,
                isFlipped: uiState.pendingPieceIsFlipped && piece.type == .parallelogram,
                connections: connections,
                existingPieces: existingPieces
            ) {
                // Validate "as placed" - DO NOT reset transform!
                let placedVertices = TangramEditorCoordinateSystem.getWorldVertices(for: placedPiece)
                let currentCenter = TangramEditorCoordinateSystem.calculateCenter(of: placedVertices)
                
                let result = transformEngine.calculateTransform(
                    for: placedPiece,
                    operation: .drag(to: currentCenter),
                    connection: nil,
                    otherPieces: existingPieces,
                    canvasSize: uiState.currentCanvasSize
                )
                
                if result.isValid {
                    // Found a valid placement!
                    // Update the pending piece rotation to match
                    uiState.pendingPieceRotation = angle
                    return placedPiece
                }
            }
        }
        
        // No valid placement found
        return nil
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
    
    // setupNewState is defined in Navigation extension
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