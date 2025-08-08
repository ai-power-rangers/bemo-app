//
//  TangramEditorCoordinator.swift
//  Bemo
//
//  Coordinator for complex tangram editor operations
//

import Foundation
import CoreGraphics

/// Coordinates complex operations between services for the Tangram Editor
@MainActor
class TangramEditorCoordinator {
    
    private let placementService: PiecePlacementService
    private let connectionService: ConnectionService
    
    init(placementService: PiecePlacementService,
         connectionService: ConnectionService) {
        self.placementService = placementService
        self.connectionService = connectionService
    }
    
    // MARK: - Complex Piece Placement
    
    /// Handle the complete flow of placing a piece with connections
    func placeConnectedPiece(
        type: PieceType,
        rotation: Double,
        isFlipped: Bool = false,
        canvasConnections: [PiecePlacementService.ConnectionPoint],
        pieceConnections: [PiecePlacementService.ConnectionPoint],
        existingPieces: [TangramPiece],
        puzzle: inout TangramPuzzle
    ) -> PlacementResult {
        
        // Validate connection points match
        guard canvasConnections.count == pieceConnections.count,
              !canvasConnections.isEmpty else {
            return .failure(.invalidConnections)
        }
        
        // Create connection pairs by matching types, not by selection order
        // Group connections by type
        let canvasVertices = canvasConnections.filter { 
            if case .vertex = $0.type { return true } else { return false }
        }
        let canvasEdges = canvasConnections.filter { 
            if case .edge = $0.type { return true } else { return false }
        }
        
        let pieceVertices = pieceConnections.filter { 
            if case .vertex = $0.type { return true } else { return false }
        }
        let pieceEdges = pieceConnections.filter { 
            if case .edge = $0.type { return true } else { return false }
        }
        
        // Validate that we have matching counts for each type
        guard canvasVertices.count == pieceVertices.count,
              canvasEdges.count == pieceEdges.count else {
            return .failure(.invalidConnections)
        }
        
        // Pair vertices with vertices and edges with edges
        var connections: [(canvasPoint: PiecePlacementService.ConnectionPoint, 
                          piecePoint: PiecePlacementService.ConnectionPoint)] = []
        
        // Add vertex-to-vertex connections first (for prioritization)
        for (canvasVertex, pieceVertex) in zip(canvasVertices, pieceVertices) {
            connections.append((canvasPoint: canvasVertex, piecePoint: pieceVertex))
        }
        
        // Then add edge-to-edge connections
        for (canvasEdge, pieceEdge) in zip(canvasEdges, pieceEdges) {
            connections.append((canvasPoint: canvasEdge, piecePoint: pieceEdge))
        }
        
        
        // Calculate piece placement (flip is now handled inside placeConnectedPiece)
        guard var newPiece = placementService.placeConnectedPiece(
            type: type,
            rotation: rotation,
            isFlipped: isFlipped,
            connections: connections,
            existingPieces: existingPieces
        ) else {
            return .failure(.placementCalculationFailed)
        }
        
        // Flip is now handled inside placeConnectedPiece, no need to apply here
        
        // Validate placement doesn't overlap using centralized coordinate system
        let newVertices = TangramEditorCoordinateSystem.getWorldVertices(for: newPiece)
        
        
        for existingPiece in existingPieces {
            let existingVertices = TangramEditorCoordinateSystem.getWorldVertices(for: existingPiece)
            
            
            // Use PieceTransformEngine's overlap detection
            let testPiece = newPiece
            if PieceTransformEngine.hasAreaOverlap(testPiece, existingPiece) {
                return .failure(.overlappingPieces)
            } else {
            }
        }
        
        // Add piece and create connections
        puzzle.pieces.append(newPiece)
        
        // Create formal connections based on connection points
        for connection in connections {
            if let connectionType = createConnectionType(
                from: connection,
                newPiece: newPiece,
                existingPieces: existingPieces
            ) {
                if let formalConnection = connectionService.createConnection(
                    type: connectionType,
                    pieces: puzzle.pieces
                ) {
                    puzzle.connections.append(formalConnection)
                }
            }
        }
        
        return .success(newPiece)
    }
    
    // MARK: - Validation Coordination
    
    /// Perform complete validation of puzzle state
    func validatePuzzle(_ puzzle: TangramPuzzle) -> ValidationState {
        // Check for overlaps between all pieces
        for i in 0..<puzzle.pieces.count {
            for j in (i+1)..<puzzle.pieces.count {
                if PieceTransformEngine.hasAreaOverlap(puzzle.pieces[i], puzzle.pieces[j]) {
                    return .invalid(reason: "Pieces overlap")
                }
            }
        }
        
        // Check if puzzle has at least one piece
        if puzzle.pieces.isEmpty {
            return .unknown
        }
        
        return .valid
    }
    
    /// Check if a specific piece placement is valid
    func validatePiecePlacement(
        piece: TangramPiece,
        existingPieces: [TangramPiece]
    ) -> Bool {
        // Check for overlaps
        for existing in existingPieces {
            if PieceTransformEngine.hasAreaOverlap(piece, existing) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Transform Coordination
    
    /// Apply constrained transformation to a piece
    func applyConstrainedTransform(
        to pieceId: String,
        targetTransform: CGAffineTransform,
        in puzzle: inout TangramPuzzle
    ) -> Bool {
        guard let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return false
        }
        
        // For now, directly apply the transform
        // Future enhancement: validate against constraints using transformEngine
        puzzle.pieces[pieceIndex].transform = targetTransform
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func createConnectionType(
        from connection: (canvasPoint: PiecePlacementService.ConnectionPoint, 
                         piecePoint: PiecePlacementService.ConnectionPoint),
        newPiece: TangramPiece,
        existingPieces: [TangramPiece]
    ) -> ConnectionType? {
        
        let canvasPoint = connection.canvasPoint
        let piecePoint = connection.piecePoint
        
        // Find the existing piece that owns the canvas point
        guard let existingPiece = existingPieces.first(where: { $0.id == canvasPoint.pieceId }) else {
            return nil
        }
        
        switch (canvasPoint.type, piecePoint.type) {
        case let (.vertex(indexA), .vertex(indexB)):
            return .vertexToVertex(
                pieceAId: existingPiece.id,
                vertexA: indexA,
                pieceBId: newPiece.id,
                vertexB: indexB
            )
            
        case let (.edge(indexA), .edge(indexB)):
            return .edgeToEdge(
                pieceAId: existingPiece.id,
                edgeA: indexA,
                pieceBId: newPiece.id,
                edgeB: indexB
            )
            
        case let (.vertex(vertexIndex), .edge(edgeIndex)):
            return .vertexToEdge(
                pieceAId: existingPiece.id,
                vertex: vertexIndex,
                pieceBId: newPiece.id,
                edge: edgeIndex
            )
            
        case let (.edge(edgeIndex), .vertex(vertexIndex)):
            return .vertexToEdge(
                pieceAId: newPiece.id,
                vertex: vertexIndex,
                pieceBId: existingPiece.id,
                edge: edgeIndex
            )
        }
    }
    
    private func getConstraintsForPiece(_ pieceId: String, in puzzle: TangramPuzzle) -> [Constraint] {
        var constraints: [Constraint] = []
        
        // Find connections involving this piece
        for connection in puzzle.connections {
            if connection.involvesPiece(pieceId) {
                constraints.append(connection.constraint)
            }
        }
        
        return constraints
    }
    
    // MARK: - Result Types
    
    enum PlacementResult {
        case success(TangramPiece)
        case failure(PlacementError)
    }
    
    enum PlacementError {
        case invalidConnections
        case placementCalculationFailed
        case overlappingPieces
        case validationFailed
    }
}