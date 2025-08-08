//
//  TangramEditorCoordinateSystem.swift
//  Bemo
//
//  Centralized coordinate system management for Tangram Editor
//

// WHAT: Single source of truth for all coordinate transformations in Tangram Editor
// ARCHITECTURE: Utility class that manages normalized, visual, and world coordinate spaces
// USAGE: Replace all scattered coordinate math with calls to this centralized system

import Foundation
import CoreGraphics

/// Centralized coordinate system management for Tangram Editor
/// Handles all transformations between normalized, visual, and world spaces
class TangramEditorCoordinateSystem {
    
    // MARK: - Constants
    
    /// Visual scaling factor from normalized to screen coordinates
    static let visualScale: CGFloat = TangramConstants.visualScale
    
    // MARK: - Space Conversions
    
    /// Convert a point from normalized space (0-2) to visual space (0-100)
    static func normalizedToVisual(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * visualScale, y: point.y * visualScale)
    }
    
    /// Convert points from normalized space to visual space
    static func normalizedToVisual(_ points: [CGPoint]) -> [CGPoint] {
        points.map { normalizedToVisual($0) }
    }
    
    /// Convert a point from visual space to normalized space
    static func visualToNormalized(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / visualScale, y: point.y / visualScale)
    }
    
    // MARK: - Vertex Operations
    
    /// Get vertices for a piece type in visual space (scaled)
    static func getVisualVertices(for type: PieceType) -> [CGPoint] {
        let normalized = TangramGeometry.vertices(for: type)
        return normalizedToVisual(normalized)
    }
    
    /// Get vertices for a piece in world space (scaled and transformed)
    static func getWorldVertices(for piece: TangramPiece) -> [CGPoint] {
        let visual = getVisualVertices(for: piece.type)
        return visual.map { $0.applying(piece.transform) }
    }
    
    // MARK: - Transform Creation
    
    /// Create a transform with rotation and translation
    /// CRITICAL: Translation is applied in world space, not rotated space
    static func createTransform(rotation: Double, translation: CGPoint) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: rotation)
        // Apply translation in world space by modifying tx/ty directly
        transform.tx = translation.x
        transform.ty = translation.y
        return transform
    }
    
    /// Create a transform that centers a piece at a specific point
    static func createCenteringTransform(
        type: PieceType,
        targetCenter: CGPoint,
        rotation: Double = 0
    ) -> CGAffineTransform {
        // Get piece center in visual space
        let visualVertices = getVisualVertices(for: type)
        let pieceCenter = calculateCenter(of: visualVertices)
        
        // Create rotation transform first
        var transform = CGAffineTransform.identity
            .rotated(by: rotation)
        
        // Apply rotation to piece center to get rotated center
        let rotatedCenter = pieceCenter.applying(transform)
        
        // Calculate world space translation
        let translation = CGPoint(
            x: targetCenter.x - rotatedCenter.x,
            y: targetCenter.y - rotatedCenter.y
        )
        
        // Apply translation in world space
        transform.tx = translation.x
        transform.ty = translation.y
        
        return transform
    }
    
    // MARK: - Connection Points
    
    /// Get all connection points for a piece in world space
    static func getConnectionPoints(for piece: TangramPiece) -> [PiecePlacementService.ConnectionPoint] {
        var points: [PiecePlacementService.ConnectionPoint] = []
        let visualVertices = getVisualVertices(for: piece.type)
        
        // Add vertex connection points
        for (index, vertex) in visualVertices.enumerated() {
            let worldPos = vertex.applying(piece.transform)
            points.append(PiecePlacementService.ConnectionPoint(
                type: .vertex(index: index),
                position: worldPos,
                pieceId: piece.id
            ))
        }
        
        // Add edge midpoint connection points
        for i in 0..<visualVertices.count {
            let start = visualVertices[i]
            let end = visualVertices[(i + 1) % visualVertices.count]
            let midpoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            let worldPos = midpoint.applying(piece.transform)
            points.append(PiecePlacementService.ConnectionPoint(
                type: .edge(index: i),
                position: worldPos,
                pieceId: piece.id
            ))
        }
        
        return points
    }
    
    /// Get a specific connection point in local visual space (not transformed)
    static func getLocalConnectionPoint(
        for type: PieceType,
        connectionType: PiecePlacementService.ConnectionPoint.PointType
    ) -> CGPoint {
        let visualVertices = getVisualVertices(for: type)
        
        switch connectionType {
        case .vertex(let index):
            guard index < visualVertices.count else { return .zero }
            return visualVertices[index]
            
        case .edge(let index):
            guard index < visualVertices.count else { return .zero }
            let start = visualVertices[index]
            let end = visualVertices[(index + 1) % visualVertices.count]
            return CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
        }
    }
    
    // MARK: - Alignment Calculations
    
    /// Calculate transform to align a piece with connection points
    static func calculateAlignmentTransform(
        pieceType: PieceType,
        baseRotation: Double,
        connections: [(canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint)],
        existingPieces: [TangramPiece] = []
    ) -> CGAffineTransform? {
        
        guard !connections.isEmpty else { return nil }
        
        switch connections.count {
        case 1:
            // Single connection - simple alignment
            return calculateSinglePointAlignment(
                pieceType: pieceType,
                baseRotation: baseRotation,
                connection: connections[0],
                existingPieces: existingPieces
            )
            
        default:
            // Two or more connections - must satisfy all
            return calculateMultiPointAlignment(
                pieceType: pieceType,
                baseRotation: baseRotation,
                connections: Array(connections.prefix(2)), // Use first 2 for dual alignment
                existingPieces: existingPieces
            )
        }
    }
    
    /// Calculate transform for single connection point
    private static func calculateSinglePointAlignment(
        pieceType: PieceType,
        baseRotation: Double,
        connection: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint),
        existingPieces: [TangramPiece]
    ) -> CGAffineTransform? {
        
        var finalRotation = baseRotation
        
        // Special handling for edge-to-edge connections - auto-rotate to align
        if case .edge(let canvasEdgeIndex) = connection.canvas.type,
           case .edge(let pieceEdgeIndex) = connection.piece.type {
            
            // Find the canvas piece that owns this connection point
            if let canvasPiece = existingPieces.first(where: { $0.id == connection.canvas.pieceId }) {
                let canvasVertices = getWorldVertices(for: canvasPiece)
                let canvasEdges = TangramGeometry.edges(for: canvasPiece.type)
                
                if canvasEdgeIndex < canvasEdges.count {
                    let canvasEdgeDef = canvasEdges[canvasEdgeIndex]
                    let canvasEdgeStart = canvasVertices[canvasEdgeDef.startVertex]
                    let canvasEdgeEnd = canvasVertices[canvasEdgeDef.endVertex]
                    let canvasEdgeAngle = atan2(
                        canvasEdgeEnd.y - canvasEdgeStart.y,
                        canvasEdgeEnd.x - canvasEdgeStart.x
                    )
                    
                    // Get the piece edge direction in local space
                    let localVertices = getVisualVertices(for: pieceType)
                    let pieceEdges = TangramGeometry.edges(for: pieceType)
                    
                    if pieceEdgeIndex < pieceEdges.count {
                        let pieceEdgeDef = pieceEdges[pieceEdgeIndex]
                        let pieceEdgeStart = localVertices[pieceEdgeDef.startVertex]
                        let pieceEdgeEnd = localVertices[pieceEdgeDef.endVertex]
                        let pieceEdgeAngle = atan2(
                            pieceEdgeEnd.y - pieceEdgeStart.y,
                            pieceEdgeEnd.x - pieceEdgeStart.x
                        )
                        
                        // Calculate rotation needed to align edges (edges should be anti-parallel)
                        // Add π to make edges face opposite directions
                        finalRotation = canvasEdgeAngle - pieceEdgeAngle + .pi
                        
                    }
                }
            }
        }
        
        // Start with calculated rotation
        var transform = CGAffineTransform.identity.rotated(by: finalRotation)
        
        // Get local position of piece connection point
        let localPiecePos = getLocalConnectionPoint(for: pieceType, connectionType: connection.piece.type)
        let rotatedPiecePos = localPiecePos.applying(transform)
        
        // Calculate translation in world space
        let dx = connection.canvas.position.x - rotatedPiecePos.x
        let dy = connection.canvas.position.y - rotatedPiecePos.y
        
        // Apply translation directly (world space)
        transform.tx = dx
        transform.ty = dy
        
        // Validate transform
        if !isValidTransform(transform) {
            return nil
        }
        
        return transform
    }
    
    /// Calculate transform for multiple connection points (must satisfy all)
    private static func calculateMultiPointAlignment(
        pieceType: PieceType,
        baseRotation: Double,
        connections: [(canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint)],
        existingPieces: [TangramPiece]
    ) -> CGAffineTransform? {
        
        guard connections.count >= 2 else {
            return calculateSinglePointAlignment(
                pieceType: pieceType,
                baseRotation: baseRotation,
                connection: connections[0],
                existingPieces: existingPieces
            )
        }
        
        // Get local positions for piece connection points
        let local1 = getLocalConnectionPoint(for: pieceType, connectionType: connections[0].piece.type)
        let local2 = getLocalConnectionPoint(for: pieceType, connectionType: connections[1].piece.type)
        
        
        // Get canvas positions
        let canvas1 = connections[0].canvas.position
        let canvas2 = connections[1].canvas.position
        
        
        // Calculate vectors between connection points
        let canvasVector = CGVector(
            dx: canvas2.x - canvas1.x,
            dy: canvas2.y - canvas1.y
        )
        
        let localVector = CGVector(
            dx: local2.x - local1.x,
            dy: local2.y - local1.y
        )
        
        
        // Calculate rotation needed to align vectors
        let canvasAngle = atan2(canvasVector.dy, canvasVector.dx)
        let localAngle = atan2(localVector.dy, localVector.dx)
        let rotationNeeded = canvasAngle - localAngle + baseRotation
        
        
        // Create transform with calculated rotation
        var transform = CGAffineTransform.identity.rotated(by: rotationNeeded)
        
        // Calculate translation to align first point
        let rotatedLocal1 = local1.applying(transform)
        
        transform.tx = canvas1.x - rotatedLocal1.x
        transform.ty = canvas1.y - rotatedLocal1.y
        
        
        // Verify second point aligns (within tolerance)
        let rotatedLocal2 = local2.applying(transform)
        let secondaryError = distance(from: rotatedLocal2, to: canvas2)
        
        
        // Define tolerance based on connection types
        let tolerance: CGFloat = determineAlignmentTolerance(
            connection1: connections[0],
            connection2: connections[1]
        )
        
        // Check if both connections can be satisfied
        if secondaryError > tolerance {
            
            // Check connection types
            if connections.count == 2 {
                let conn1Type = (canvas: connections[0].canvas.type, piece: connections[0].piece.type)
                let conn2Type = (canvas: connections[1].canvas.type, piece: connections[1].piece.type)
                
                
                // Check if we have at least one edge connection
                let hasEdgeConnection = conn1Type.piece.isEdge || conn2Type.piece.isEdge
                
                if hasEdgeConnection {
                    // With an edge connection, different lengths are expected and valid
                    // The piece can slide along the edge after placement
                    return transform
                }
            }
            
            // For pure vertex-to-vertex connections, we need tight tolerance
            let bothVertices = connections[0].piece.type.isVertex && connections[1].piece.type.isVertex
            if bothVertices && secondaryError > tolerance {
                return nil
            }
            
            return nil
        }
        
        // Validate transform
        if !isValidTransform(transform) {
            return nil
        }
        
        return transform
    }
    
    /// Determine appropriate tolerance based on connection types
    private static func determineAlignmentTolerance(
        connection1: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint),
        connection2: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint)
    ) -> CGFloat {
        
        // Check what types of connections we have
        let hasVertex = (connection1.piece.type.isVertex || connection2.piece.type.isVertex)
        let hasEdge = (connection1.piece.type.isEdge || connection2.piece.type.isEdge)
        
        
        // For vertex+edge combination, we need more tolerance
        // The edge might not be exactly the same length
        if hasVertex && hasEdge {
            return TangramConstants.mixedConnectionTolerance
        }
        
        // Both vertices - need tight alignment
        if connection1.piece.type.isVertex && connection2.piece.type.isVertex {
            return TangramConstants.vertexToVertexTolerance
        }
        
        // Both edges - can have more tolerance (for sliding)
        if connection1.piece.type.isEdge && connection2.piece.type.isEdge {
            return TangramConstants.edgeToEdgeTolerance
        }
        
        // Default
        return TangramConstants.defaultConnectionTolerance
    }
    
    /// Check if connection configuration allows sliding
    private static func isSlideableConfiguration(
        connections: [(canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint)],
        error: CGFloat
    ) -> Bool {
        
        // Only allow sliding for single edge connection
        // (Multi-point should lock the piece)
        if connections.count > 1 {
            // Check if one is edge and error is along edge direction
            for connection in connections {
                if case .edge = connection.piece.type,
                   case .edge = connection.canvas.type {
                    // TODO: Check if error vector is parallel to edge
                    // For now, be conservative
                    return error < 10.0
                }
            }
        }
        
        return false
    }
    
    /// Calculate distance between two points
    private static func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Bounding Box Operations
    
    /// Get bounding box for a single piece in world space
    static func getBoundingBox(for piece: TangramPiece) -> (min: CGPoint, max: CGPoint) {
        let worldVertices = getWorldVertices(for: piece)
        
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for vertex in worldVertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
        }
        
        return (
            min: CGPoint(x: minX, y: minY),
            max: CGPoint(x: maxX, y: maxY)
        )
    }
    
    /// Get combined bounding box for multiple pieces
    static func getBoundingBox(for pieces: [TangramPiece]) -> (min: CGPoint, max: CGPoint)? {
        guard !pieces.isEmpty else { return nil }
        
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in pieces {
            let bounds = getBoundingBox(for: piece)
            minX = min(minX, bounds.min.x)
            maxX = max(maxX, bounds.max.x)
            minY = min(minY, bounds.min.y)
            maxY = max(maxY, bounds.max.y)
        }
        
        return (
            min: CGPoint(x: minX, y: minY),
            max: CGPoint(x: maxX, y: maxY)
        )
    }
    
    /// Get center point of pieces
    static func getCenter(of pieces: [TangramPiece]) -> CGPoint? {
        guard let bounds = getBoundingBox(for: pieces) else { return nil }
        
        return CGPoint(
            x: (bounds.min.x + bounds.max.x) / 2,
            y: (bounds.min.y + bounds.max.y) / 2
        )
    }
    
    // MARK: - Utility Functions
    
    /// Calculate center of points
    static func calculateCenter(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        
        return CGPoint(
            x: sumX / CGFloat(points.count),
            y: sumY / CGFloat(points.count)
        )
    }
    
    /// Check if transform is valid (finite values)
    static func isValidTransform(_ transform: CGAffineTransform) -> Bool {
        return transform.a.isFinite && transform.b.isFinite &&
               transform.c.isFinite && transform.d.isFinite &&
               transform.tx.isFinite && transform.ty.isFinite
    }
    
    /// Debug helper to print transform in readable format
    static func debugPrintTransform(_ transform: CGAffineTransform, label: String = "Transform") {
        #if DEBUG
        #endif
    }
}