//
//  TangramEditorCoordinator.swift
//  Bemo
//
//  Coordinator for complex tangram editor operations
//

import Foundation
import CoreGraphics

/// Coordinates complex operations between services for the Tangram Editor
class TangramEditorCoordinator {
    
    private let placementService: PiecePlacementService
    private let connectionService: ConnectionService
    private let validationService: ValidationService
    private let geometryService: GeometryService
    private let constraintManager: ConstraintManager
    
    init(placementService: PiecePlacementService = PiecePlacementService(),
         connectionService: ConnectionService = ConnectionService(),
         validationService: ValidationService = ValidationService(),
         geometryService: GeometryService = GeometryService(),
         constraintManager: ConstraintManager = ConstraintManager()) {
        self.placementService = placementService
        self.connectionService = connectionService
        self.validationService = validationService
        self.geometryService = geometryService
        self.constraintManager = constraintManager
    }
    
    // MARK: - Complex Piece Placement
    
    /// Handle the complete flow of placing a piece with connections
    func placeConnectedPiece(
        type: PieceType,
        rotation: Double,
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
        
        // Create connection pairs
        let connections = zip(canvasConnections, pieceConnections).map { 
            (canvasPoint: $0, piecePoint: $1) 
        }
        
        // Calculate piece placement
        guard let newPiece = placementService.placeConnectedPiece(
            type: type,
            rotation: rotation,
            connections: connections,
            existingPieces: existingPieces
        ) else {
            return .failure(.placementCalculationFailed)
        }
        
        // Validate placement doesn't overlap
        // Need to scale vertices before transformation to match rendering
        let baseNewVertices = TangramGeometry.vertices(for: type)
        let scaledNewVertices = baseNewVertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale)
        }
        let newVertices = geometryService.transformVertices(
            scaledNewVertices,
            with: newPiece.transform
        )
        
        for existingPiece in existingPieces {
            let baseExistingVertices = TangramGeometry.vertices(for: existingPiece.type)
            let scaledExistingVertices = baseExistingVertices.map { 
                CGPoint(x: $0.x * TangramConstants.visualScale, 
                        y: $0.y * TangramConstants.visualScale)
            }
            let existingVertices = geometryService.transformVertices(
                scaledExistingVertices,
                with: existingPiece.transform
            )
            
            if geometryService.polygonsOverlap(newVertices, existingVertices) {
                return .failure(.overlappingPieces)
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
        return validationService.validate(puzzle: puzzle)
    }
    
    /// Check if a specific piece placement is valid
    func validatePiecePlacement(
        piece: TangramPiece,
        existingPieces: [TangramPiece]
    ) -> Bool {
        // Scale vertices before transformation to match rendering
        let basePieceVertices = TangramGeometry.vertices(for: piece.type)
        let scaledPieceVertices = basePieceVertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale)
        }
        let pieceVertices = geometryService.transformVertices(
            scaledPieceVertices,
            with: piece.transform
        )
        
        // Check for overlaps
        for existing in existingPieces {
            let baseExistingVertices = TangramGeometry.vertices(for: existing.type)
            let scaledExistingVertices = baseExistingVertices.map { 
                CGPoint(x: $0.x * TangramConstants.visualScale, 
                        y: $0.y * TangramConstants.visualScale)
            }
            let existingVertices = geometryService.transformVertices(
                scaledExistingVertices,
                with: existing.transform
            )
            
            if geometryService.polygonsOverlap(pieceVertices, existingVertices) {
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
        
        // Get constraints for this piece
        let constraints = getConstraintsForPiece(pieceId, in: puzzle)
        
        // Calculate final transform
        let finalTransform = placementService.calculateConstrainedTransform(
            for: pieceId,
            targetTransform: targetTransform,
            constraints: constraints,
            pieces: puzzle.pieces
        )
        
        // Apply transform
        puzzle.pieces[pieceIndex].transform = finalTransform
        
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
                pieceA: existingPiece.id,
                vertexA: indexA,
                pieceB: newPiece.id,
                vertexB: indexB
            )
            
        case let (.edge(indexA), .edge(indexB)):
            return .edgeToEdge(
                pieceA: existingPiece.id,
                edgeA: indexA,
                pieceB: newPiece.id,
                edgeB: indexB
            )
            
        case let (.vertex(vertexIndex), .edge(edgeIndex)):
            return .vertexToEdge(
                pieceA: existingPiece.id,
                vertex: vertexIndex,
                pieceB: newPiece.id,
                edge: edgeIndex
            )
            
        case let (.edge(edgeIndex), .vertex(vertexIndex)):
            return .vertexToEdge(
                pieceA: newPiece.id,
                vertex: vertexIndex,
                pieceB: existingPiece.id,
                edge: edgeIndex
            )
        }
    }
    
    private func getConstraintsForPiece(_ pieceId: String, in puzzle: TangramPuzzle) -> [Constraint] {
        var constraints: [Constraint] = []
        
        // Find connections involving this piece
        for connection in puzzle.connections {
            if connection.involvespiece(pieceId) {
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