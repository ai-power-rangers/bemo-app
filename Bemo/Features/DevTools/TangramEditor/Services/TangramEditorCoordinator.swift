//
//  TangramEditorCoordinator.swift
//  Bemo
//
//  Coordinator for complex tangram editor operations
//

import Foundation
import CoreGraphics
import OSLog

/// Coordinates complex operations between services for the Tangram Editor
@MainActor
class TangramEditorCoordinator {
    
    private let placementService: PiecePlacementService
    private let connectionService: ConnectionService
    private let validationService: TangramValidationService
    
    init(placementService: PiecePlacementService,
         connectionService: ConnectionService,
         validationService: TangramValidationService) {
        self.placementService = placementService
        self.connectionService = connectionService
        self.validationService = validationService
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
        guard let newPiece = placementService.placeConnectedPiece(
            type: type,
            rotation: rotation,
            isFlipped: isFlipped,
            connections: connections,
            existingPieces: existingPieces
        ) else {
            return .failure(.placementCalculationFailed)
        }
        
        // Flip is now handled inside placeConnectedPiece, no need to apply here
        
        // Validate placement using unified validation service
        // Create validation context with connection info if available
        var validationConnection: Connection? = nil
        if let firstConnection = connections.first,
           let canvasPieceId = firstConnection.canvasPoint.pieceId.split(separator: "_").first {
            let canvasPieceIdStr = String(canvasPieceId)
            
            // Create connection for validation based on connection types
            if case .vertex(let canvasVertex) = firstConnection.canvasPoint.type,
               case .vertex(let pieceVertex) = firstConnection.piecePoint.type {
                validationConnection = Connection(
                    type: .vertexToVertex(
                        pieceAId: canvasPieceIdStr,
                        vertexA: canvasVertex,
                        pieceBId: newPiece.id,
                        vertexB: pieceVertex
                    ),
                    constraint: Constraint(type: .fixed, affectedPieceId: newPiece.id)
                )
            }
            // Add other connection type handling as needed
        }
        
        let validationContext = TangramValidationService.ValidationContext(
            connection: validationConnection,
            otherPieces: existingPieces,
            canvasSize: CGSize(width: 800, height: 600),
            allowOutOfBounds: true
        )
        
        let validationResult = validationService.validatePlacement(newPiece, context: validationContext)
        if !validationResult.isValid {
            return .failure(.overlappingPieces)
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
        // Check if puzzle has at least one piece
        if puzzle.pieces.isEmpty {
            return .unknown
        }
        
        // Use validation service for comprehensive puzzle validation
        for i in 0..<puzzle.pieces.count {
            // Get connections for this piece
            let pieceConnections = puzzle.connections.filter { conn in
                conn.pieceAId == puzzle.pieces[i].id || conn.pieceBId == puzzle.pieces[i].id
            }
            
            // Validate each piece with its connections
            for connection in pieceConnections {
                let context = TangramValidationService.ValidationContext(
                    connection: connection,
                    otherPieces: puzzle.pieces.filter { $0.id != puzzle.pieces[i].id },
                    canvasSize: CGSize(width: 800, height: 600),
                    allowOutOfBounds: true
                )
                
                let result = validationService.validatePlacement(puzzle.pieces[i], context: context)
                if !result.isValid {
                    if let violation = result.violations.first {
                        Logger.tangramEditorValidation.warning("[Validation] \(violation.message)")
                        return .invalid(reason: violation.message)
                    }
                }
            }
        }
        
        // Check for orphaned pieces (not connected to any other piece)
        // Only check if we have more than one piece
        if puzzle.pieces.count > 1 {
            var connectedPieceIds = Set<String>()
            
            // Build graph of connected pieces
            for connection in puzzle.connections {
                connectedPieceIds.insert(connection.pieceAId)
                connectedPieceIds.insert(connection.pieceBId)
            }
            
            // Check if all pieces are connected (except single piece puzzles)
            for piece in puzzle.pieces {
                if !connectedPieceIds.contains(piece.id) {
                    Logger.tangramEditorValidation.warning("[Validation] Orphaned piece: \(piece.type.rawValue) has no connections")
                    return .invalid(reason: "Piece '\(piece.type.rawValue)' is not connected to other pieces")
                }
            }
            
            // Additional check: ensure all pieces form a single connected component
            // (no separate islands of connected pieces)
            if !connectedPieceIds.isEmpty {
                if !isFullyConnected(puzzle: puzzle) {
                    Logger.tangramEditorValidation.warning("[Validation] Disconnected islands detected - pieces must form single connected shape")
                    return .invalid(reason: "Pieces must form a single connected shape")
                }
            }
        }
        
        return .valid
    }
    
    /// Check if all pieces form a single connected component (no islands)
    private func isFullyConnected(puzzle: TangramPuzzle) -> Bool {
        guard puzzle.pieces.count > 1 else { return true }
        
        // Build adjacency list
        var adjacencyList: [String: Set<String>] = [:]
        for piece in puzzle.pieces {
            adjacencyList[piece.id] = Set<String>()
        }
        
        for connection in puzzle.connections {
            adjacencyList[connection.pieceAId]?.insert(connection.pieceBId)
            adjacencyList[connection.pieceBId]?.insert(connection.pieceAId)
        }
        
        // BFS to find all connected pieces starting from first piece
        guard let startPiece = puzzle.pieces.first else { return true }
        var visited = Set<String>()
        var queue = [startPiece.id]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if visited.contains(current) { continue }
            visited.insert(current)
            
            if let neighbors = adjacencyList[current] {
                for neighbor in neighbors {
                    if !visited.contains(neighbor) {
                        queue.append(neighbor)
                    }
                }
            }
        }
        
        // Check if all pieces were visited (single connected component)
        return visited.count == puzzle.pieces.count
    }
    
    /// Check if a specific piece placement is valid
    func validatePiecePlacement(
        piece: TangramPiece,
        existingPieces: [TangramPiece],
        connection: Connection? = nil
    ) -> Bool {
        let context = TangramValidationService.ValidationContext(
            connection: connection,
            otherPieces: existingPieces,
            canvasSize: CGSize(width: 800, height: 600),
            allowOutOfBounds: true
        )
        
        let result = validationService.validatePlacement(piece, context: context)
        return result.isValid
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