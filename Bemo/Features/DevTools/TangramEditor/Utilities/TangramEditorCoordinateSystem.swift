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
import OSLog

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
    
    /// Check if a transform represents a flipped state (negative determinant)
    static func isFlipped(_ transform: CGAffineTransform) -> Bool {
        // A transform is flipped if determinant is negative
        // det = a*d - b*c
        return transform.a * transform.d - transform.b * transform.c < 0
    }
    
    /// Remap vertex index for flipped parallelogram
    static func remapParallelogramVertexIndexForFlip(_ index: Int) -> Int {
        // When parallelogram is flipped horizontally, vertices swap: 0↔1, 2↔3
        switch index {
        case 0: return 1
        case 1: return 0
        case 2: return 3
        case 3: return 2
        default: return index
        }
    }
    
    /// Remap edge index for flipped parallelogram
    static func remapParallelogramEdgeIndexForFlip(_ index: Int) -> Int {
        // When parallelogram is flipped, edges need remapping
        // Original edges: 0(0→1), 1(1→2), 2(2→3), 3(3→0)
        // Flipped edges: 0(1→0), 1(0→3), 2(3→2), 3(2→1)
        // So mapping is: 0→0, 1→3, 2→2, 3→1
        switch index {
        case 0: return 0
        case 1: return 3
        case 2: return 2
        case 3: return 1
        default: return index
        }
    }
    
    // Keep internal versions for both internal and external use
    static func remapParallelogramVertexIndex(_ index: Int) -> Int {
        return remapParallelogramVertexIndexForFlip(index)
    }
    
    static func remapParallelogramEdgeIndex(_ index: Int) -> Int {
        return remapParallelogramEdgeIndexForFlip(index)
    }
    
    /// Get all connection points for a piece in world space
    static func getConnectionPoints(for piece: TangramPiece) -> [PiecePlacementService.ConnectionPoint] {
        var points: [PiecePlacementService.ConnectionPoint] = []
        let visualVertices = getVisualVertices(for: piece.type)
        
        // IMPORTANT: Do NOT remap indices here! Connection points should always use
        // the actual vertex/edge indices. The placement logic handles any necessary
        // remapping internally when calculating transforms for flipped pieces.
        // Remapping here causes inconsistency with getWorldVertices which returns
        // vertices in their natural order.
        
        // Add vertex connection points
        for (index, vertex) in visualVertices.enumerated() {
            let worldPos = vertex.applying(piece.transform)
            
            points.append(PiecePlacementService.ConnectionPoint(
                type: .vertex(index: index), // Use actual index, no remapping
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
                type: .edge(index: i), // Use actual index, no remapping
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
        isFlipped: Bool = false,
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
                isFlipped: isFlipped,
                connection: connections[0],
                existingPieces: existingPieces
            )
            
        default:
            // Two or more connections - must satisfy all
            return calculateMultiPointAlignment(
                pieceType: pieceType,
                baseRotation: baseRotation,
                isFlipped: isFlipped,
                connections: Array(connections.prefix(2)), // Use first 2 for dual alignment
                existingPieces: existingPieces
            )
        }
    }
    
    /// Calculate transform for single connection point
    private static func calculateSinglePointAlignment(
        pieceType: PieceType,
        baseRotation: Double,
        isFlipped: Bool,
        connection: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint),
        existingPieces: [TangramPiece]
    ) -> CGAffineTransform? {
        
        // For single connections, use user's rotation
        let finalRotation = baseRotation
        
        // Get local position of piece connection point
        let localPiecePos = getLocalConnectionPoint(for: pieceType, connectionType: connection.piece.type)
        
        // Build transform: Flip -> Rotation -> Translation
        // This order ensures flip is always horizontal in world space
        var transform = CGAffineTransform.identity
        
        // Apply flip first if needed
        if isFlipped && pieceType == .parallelogram {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        
        // Apply rotation
        transform = transform.rotated(by: finalRotation)
        
        // Calculate where the connection point ends up after flip and rotation
        let rotatedPiecePos = localPiecePos.applying(transform)
        
        // Calculate translation in world space
        let dx = connection.canvas.position.x - rotatedPiecePos.x
        let dy = connection.canvas.position.y - rotatedPiecePos.y
        
        // Apply translation directly (world space)
        transform.tx = dx
        transform.ty = dy
        
        // Validate transform
        if !isValidTransform(transform) {
            Logger.tangramPlacement.error("[CoordinateSystem] Single-point alignment produced invalid transform")
            return nil
        }
        
        Logger.tangramPlacement.info("[CoordinateSystem] Single-point alignment successful")
        return transform
    }
    
    /// Calculate transform for multiple connection points (must satisfy all)
    private static func calculateMultiPointAlignment(
        pieceType: PieceType,
        baseRotation: Double,
        isFlipped: Bool,
        connections: [(canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint)],
        existingPieces: [TangramPiece]
    ) -> CGAffineTransform? {
        
        guard connections.count >= 2 else {
            return calculateSinglePointAlignment(
                pieceType: pieceType,
                baseRotation: baseRotation,
                isFlipped: isFlipped,
                connection: connections[0],
                existingPieces: existingPieces
            )
        }
        
        // Special handling for dual connections
        if connections.count == 2 {
            let hasVertex = connections.contains { $0.piece.type.isVertex }
            let hasEdge = connections.contains { $0.piece.type.isEdge }

            if hasVertex && hasEdge {
                // Vertex + Edge: pivot at vertex, align edge directions
                let vertexConnection = connections.first { $0.piece.type.isVertex }!
                let edgeConnection = connections.first { $0.piece.type.isEdge }!

                return calculateVertexEdgeAlignment(
                    pieceType: pieceType,
                    isFlipped: isFlipped,
                    vertexConnection: vertexConnection,
                    edgeConnection: edgeConnection,
                    existingPieces: existingPieces,
                    baseRotation: baseRotation
                )
            } else if connections.allSatisfy({ $0.piece.type.isEdge }) {
                // Edge + Edge: align edge directions and midpoints
                return calculateEdgeEdgeAlignment(
                    pieceType: pieceType,
                    isFlipped: isFlipped,
                    edgeConnection1: connections[0],
                    edgeConnection2: connections[1],
                    existingPieces: existingPieces,
                    baseRotation: baseRotation
                )
            }
        }
        
        // Get local positions for piece connection points
        let local1 = getLocalConnectionPoint(for: pieceType, connectionType: connections[0].piece.type)
        let local2 = getLocalConnectionPoint(for: pieceType, connectionType: connections[1].piece.type)
        
        // Get canvas positions
        let canvas1 = connections[0].canvas.position
        let canvas2 = connections[1].canvas.position
        
        // Build transform: Flip -> Rotation -> Translation
        var transform = CGAffineTransform.identity
        
        // Apply flip first if needed
        if isFlipped && pieceType == .parallelogram {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        
        // Calculate vectors using actual transformed positions
        let flippedLocal1 = local1.applying(transform)
        let flippedLocal2 = local2.applying(transform)
        
        let localVector = CGVector(
            dx: flippedLocal2.x - flippedLocal1.x,
            dy: flippedLocal2.y - flippedLocal1.y
        )
        
        let canvasVector = CGVector(
            dx: canvas2.x - canvas1.x,
            dy: canvas2.y - canvas1.y
        )
        
        // Calculate rotation needed to align vectors
        let localAngle = atan2(localVector.dy, localVector.dx)
        let canvasAngle = atan2(canvasVector.dy, canvasVector.dx)
        let rotationNeeded = canvasAngle - localAngle + baseRotation
        
        // Apply rotation to the existing transform (which may already have flip)
        transform = transform.rotated(by: rotationNeeded)
        
        // Calculate translation to align first point
        let rotatedLocal1 = local1.applying(transform)
        
        transform.tx = canvas1.x - rotatedLocal1.x
        transform.ty = canvas1.y - rotatedLocal1.y
        
        
        // Verify second point aligns (within tolerance)
        let rotatedLocal2 = local2.applying(transform)
        let secondaryError = distance(from: rotatedLocal2, to: canvas2)
        
        Logger.tangramPlacement.debug("[CoordinateSystem] Multi-point alignment check: error=\(String(format: "%.2f", secondaryError))")
        
        
        // Define tolerance based on connection types
        let tolerance: CGFloat = determineAlignmentTolerance(
            connection1: connections[0],
            connection2: connections[1]
        )
        
        // Check if both connections can be satisfied
        if secondaryError > tolerance {
            Logger.tangramPlacement.warning("[CoordinateSystem] Multi-point alignment error: \(String(format: "%.2f", secondaryError)) > tolerance: \(String(format: "%.2f", tolerance))")
            
            // Check connection types
            if connections.count == 2 {
                let conn1Type = (canvas: connections[0].canvas.type, piece: connections[0].piece.type)
                let conn2Type = (canvas: connections[1].canvas.type, piece: connections[1].piece.type)
                
                
                // Check if we have at least one edge connection
                let hasEdgeConnection = conn1Type.piece.isEdge || conn2Type.piece.isEdge
                
                if hasEdgeConnection {
                    Logger.tangramPlacement.info("[CoordinateSystem] Has edge connection - allowing sliding tolerance")
                    // With an edge connection, different lengths are expected and valid
                    // The piece can slide along the edge after placement
                    return transform
                }
            }
            
            // For pure vertex-to-vertex connections, we need tight tolerance
            let bothVertices = connections[0].piece.type.isVertex && connections[1].piece.type.isVertex
            if bothVertices && secondaryError > tolerance {
                Logger.tangramPlacement.error("[CoordinateSystem] Multi-point alignment failed: both vertices, error too large")
                return nil
            }
            
            Logger.tangramPlacement.error("[CoordinateSystem] Multi-point alignment failed: secondary point doesn't align")
            return nil
        }
        
        Logger.tangramPlacement.info("[CoordinateSystem] Multi-point alignment successful")
        
        // Validate transform
        if !isValidTransform(transform) {
            Logger.tangramPlacement.error("[CoordinateSystem] Multi-point alignment produced invalid transform")
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
        
        // For vertex+edge combination, use mixed tolerance
        if hasVertex && hasEdge {
            return TangramConstants.mixedConnectionTolerance  // 2.0
        }
        
        // Both vertices - need tight alignment
        if connection1.piece.type.isVertex && connection2.piece.type.isVertex {
            return TangramConstants.vertexToVertexTolerance  // 1.5
        }
        
        // Both edges - use consistent edge tolerance
        if connection1.piece.type.isEdge && connection2.piece.type.isEdge {
            return TangramConstants.edgeToEdgeTolerance  // 2.0
        }
        
        // Default to mixed tolerance for consistency
        return TangramConstants.mixedConnectionTolerance  // 2.0
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
    
    /// Calculate transform for vertex+edge dual connection
    /// This uses true edge directions and pivots around the vertex for exact alignment
    private static func calculateVertexEdgeAlignment(
        pieceType: PieceType,
        isFlipped: Bool,
        vertexConnection: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint),
        edgeConnection: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint),
        existingPieces: [TangramPiece],
        baseRotation: Double
    ) -> CGAffineTransform? {
        
        // Get the canvas edge owner piece and edge definition
        // Note: Canvas vertex and edge can be from DIFFERENT pieces (cross-piece constraint)
        guard case .edge(let canvasEdgeIndex) = edgeConnection.canvas.type,
              let canvasEdgePiece = existingPieces.first(where: { $0.id == edgeConnection.canvas.pieceId }) else {
            return nil
        }
        
        let canvasEdges = TangramGeometry.edges(for: canvasEdgePiece.type)
        guard canvasEdgeIndex < canvasEdges.count else { return nil }
        let canvasEdgeDef = canvasEdges[canvasEdgeIndex]
        
        // Get canvas edge endpoints in world coordinates
        let canvasEdgeVertices = getWorldVertices(for: canvasEdgePiece)
        let canvasEdgeStart = canvasEdgeVertices[canvasEdgeDef.startVertex]
        let canvasEdgeEnd = canvasEdgeVertices[canvasEdgeDef.endVertex]
        
        // Get canvas vertex position (can be from a different piece)
        let canvasVertexPos = vertexConnection.canvas.position
        
        // Log canvas edge for debugging
        Logger.tangramPlacement.debug("[CoordinateSystem] Canvas edge: start=(\(String(format: "%.1f", canvasEdgeStart.x)), \(String(format: "%.1f", canvasEdgeStart.y))) end=(\(String(format: "%.1f", canvasEdgeEnd.x)), \(String(format: "%.1f", canvasEdgeEnd.y)))")
        
        // Get canvas edge direction vector
        let canvasEdgeVector = CGVector(
            dx: canvasEdgeEnd.x - canvasEdgeStart.x,
            dy: canvasEdgeEnd.y - canvasEdgeStart.y
        )
        let canvasEdgeAngle = atan2(canvasEdgeVector.dy, canvasEdgeVector.dx)
        
        // Get local piece edge and vertex positions
        var localVertexIndex: Int
        var localEdgeIndex: Int
        
        if case .vertex(let vIdx) = vertexConnection.piece.type {
            localVertexIndex = vIdx
        } else { return nil }
        
        if case .edge(let eIdx) = edgeConnection.piece.type {
            localEdgeIndex = eIdx
        } else { return nil }
        
        // Get local piece geometry
        let visualVertices = getVisualVertices(for: pieceType)
        let pieceEdges = TangramGeometry.edges(for: pieceType)
        guard localVertexIndex < visualVertices.count,
              localEdgeIndex < pieceEdges.count else { return nil }
        
        // CRITICAL FIX: For flipped pieces, we need to get the actual transformed geometry
        // instead of trying to use shortcuts with angle negation
        
        // Step 1: Get the base vertices and edge definition
        let baseVertex = visualVertices[localVertexIndex]
        let baseEdgeDef = pieceEdges[localEdgeIndex]
        let baseEdgeStart = visualVertices[baseEdgeDef.startVertex]
        let baseEdgeEnd = visualVertices[baseEdgeDef.endVertex]
        
        // Step 2: Apply flip transformation to get actual positions if flipped
        var actualVertex: CGPoint
        var actualEdgeStart: CGPoint
        var actualEdgeEnd: CGPoint
        
        if isFlipped && pieceType == .parallelogram {
            // Apply horizontal flip to get actual positions
            let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
            actualVertex = baseVertex.applying(flipTransform)
            actualEdgeStart = baseEdgeStart.applying(flipTransform)
            actualEdgeEnd = baseEdgeEnd.applying(flipTransform)
            
            Logger.tangramPlacement.debug("[CoordinateSystem] Flipped parallelogram - vertex transformed from (\(String(format: "%.1f", baseVertex.x)), \(String(format: "%.1f", baseVertex.y))) to (\(String(format: "%.1f", actualVertex.x)), \(String(format: "%.1f", actualVertex.y)))")
        } else {
            actualVertex = baseVertex
            actualEdgeStart = baseEdgeStart
            actualEdgeEnd = baseEdgeEnd
        }
        
        // Step 3: Log if vertex is incident to edge (for debugging)
        // NOTE: We DO NOT require the vertex to be an endpoint of the edge.
        // Any vertex can align with the canvas vertex while any edge aligns with the canvas edge.
        let vertexAtStart = (abs(actualVertex.x - actualEdgeStart.x) < 0.001 && 
                            abs(actualVertex.y - actualEdgeStart.y) < 0.001)
        let vertexAtEnd = (abs(actualVertex.x - actualEdgeEnd.x) < 0.001 && 
                          abs(actualVertex.y - actualEdgeEnd.y) < 0.001)
        
        if vertexAtStart || vertexAtEnd {
            Logger.tangramPlacement.debug("[CoordinateSystem] Vertex is incident to edge (at \(vertexAtStart ? "start" : "end"))")
        } else {
            Logger.tangramPlacement.debug("[CoordinateSystem] Vertex is NOT incident to edge - this is allowed for vertex+edge dual constraints")
        }
        
        // Step 4: Calculate the actual edge direction after flip
        let actualEdgeVector = CGVector(
            dx: actualEdgeEnd.x - actualEdgeStart.x,
            dy: actualEdgeEnd.y - actualEdgeStart.y
        )
        let actualEdgeAngle = atan2(actualEdgeVector.dy, actualEdgeVector.dx)
        
        Logger.tangramPlacement.debug("[CoordinateSystem] Actual edge angle after flip: \(String(format: "%.1f", actualEdgeAngle * 180 / .pi))°, Canvas edge angle: \(String(format: "%.1f", canvasEdgeAngle * 180 / .pi))°")
        
        // Step 5: Calculate rotation needed to align the actual edge with canvas edge, INCLUDING user's base rotation
        var rotationNeeded = canvasEdgeAngle - actualEdgeAngle + baseRotation
        
        // Log rotation before snapping
        let degrees = rotationNeeded * 180 / .pi
        Logger.tangramPlacement.debug("[CoordinateSystem] Rotation needed before snap: \(String(format: "%.1f", degrees))°")
        
        // Snap rotation to nearest 45° ONLY if within small epsilon
        let snappedDegrees = round(degrees / 45) * 45
        if abs(degrees - snappedDegrees) <= 1.0 {  // Within 1° of a 45° multiple
            rotationNeeded = snappedDegrees * .pi / 180
            Logger.tangramPlacement.debug("[CoordinateSystem] Snapped rotation to \(String(format: "%.0f", snappedDegrees))°")
        }
        
        // Step 6: Build the complete transform
        // We need to compose: Flip (if needed) -> Rotation -> Translation
        var transform = CGAffineTransform.identity
        
        // Apply flip first if needed
        if isFlipped && pieceType == .parallelogram {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        
        // Apply rotation
        transform = transform.rotated(by: rotationNeeded)
        
        // Calculate where the vertex ends up after flip and rotation
        let transformedVertex = baseVertex.applying(transform)
        
        // Translate so the vertex aligns exactly with canvas vertex
        transform.tx = canvasVertexPos.x - transformedVertex.x
        transform.ty = canvasVertexPos.y - transformedVertex.y
        
        Logger.tangramPlacement.debug("[CoordinateSystem] Vertex pivot at (\(String(format: "%.1f", canvasVertexPos.x)), \(String(format: "%.1f", canvasVertexPos.y)))")
        
        // Step 7: Verify edge collinearity
        // Transform the original edge endpoints with the complete transform
        let transformedEdgeStart = baseEdgeStart.applying(transform)
        let transformedEdgeEnd = baseEdgeEnd.applying(transform)
        
        // Calculate perpendicular distances from both endpoints to the canvas edge line
        let startDistance = perpendicularDistanceToLine(
            point: transformedEdgeStart,
            lineStart: canvasEdgeStart,
            lineEnd: canvasEdgeEnd
        )
        let endDistance = perpendicularDistanceToLine(
            point: transformedEdgeEnd,
            lineStart: canvasEdgeStart,
            lineEnd: canvasEdgeEnd
        )
        
        // Log the perpendicular distances for debugging
        Logger.tangramPlacement.debug("[CoordinateSystem] Edge endpoint distances to canvas line: start=\(String(format: "%.2f", startDistance)), end=\(String(format: "%.2f", endDistance))")
        
        // Both endpoints should be within tolerance of the canvas edge line for collinearity
        let maxDistance = max(startDistance, endDistance)
        if maxDistance > TangramConstants.mixedConnectionTolerance {
            Logger.tangramPlacement.warning("[CoordinateSystem] Vertex+edge alignment failed: collinearity error \(String(format: "%.2f", maxDistance)) exceeds tolerance \(TangramConstants.mixedConnectionTolerance)")
            return nil
        }
        
        // CRITICAL: Ensure piece is on the correct side of the canvas edge to prevent SAT overlaps
        // Compute centroids to determine which half-plane each piece occupies
        
        // Get canvas edge owner's centroid
        let canvasOwnerCentroid = calculatePieceCentroid(canvasEdgePiece)
        
        // Get pending piece centroid after transform
        let pendingPieceCentroid = calculateTransformedPieceCentroid(
            pieceType: pieceType,
            transform: transform
        )
        
        // Calculate the normal to the canvas edge (perpendicular vector)
        let edgeNormal = CGVector(
            dx: -(canvasEdgeEnd.y - canvasEdgeStart.y),
            dy: canvasEdgeEnd.x - canvasEdgeStart.x
        )
        
        // Normalize the normal vector
        let normalLength = sqrt(edgeNormal.dx * edgeNormal.dx + edgeNormal.dy * edgeNormal.dy)
        let unitNormal = CGVector(
            dx: edgeNormal.dx / normalLength,
            dy: edgeNormal.dy / normalLength
        )
        
        // Calculate signed distances from edge line to determine which side each piece is on
        let canvasOwnerSide = signedDistanceToLine(
            point: canvasOwnerCentroid,
            lineStart: canvasEdgeStart,
            lineEnd: canvasEdgeEnd,
            normal: unitNormal
        )
        
        let pendingPieceSide = signedDistanceToLine(
            point: pendingPieceCentroid,
            lineStart: canvasEdgeStart,
            lineEnd: canvasEdgeEnd,
            normal: unitNormal
        )
        
        Logger.tangramPlacement.debug("[CoordinateSystem] Half-plane check: canvas owner side=\(String(format: "%.1f", canvasOwnerSide)), pending piece side=\(String(format: "%.1f", pendingPieceSide))")
        
        // If both pieces are on the same side of the edge, flip the orientation
        if canvasOwnerSide * pendingPieceSide > 0 {  // Same sign means same side
            Logger.tangramPlacement.info("[CoordinateSystem] Pieces on same side of edge - flipping orientation by π")
            
            // Add π to rotation to place piece on opposite side
            rotationNeeded += .pi
            
            // Re-apply the transform with flipped orientation
            transform = CGAffineTransform.identity
            if isFlipped && pieceType == .parallelogram {
                transform = transform.scaledBy(x: -1, y: 1)
            }
            transform = transform.rotated(by: rotationNeeded)
            
            // Re-apply translation to keep vertex at canvas vertex
            let reRotatedVertex = baseVertex.applying(transform)
            transform.tx = canvasVertexPos.x - reRotatedVertex.x
            transform.ty = canvasVertexPos.y - reRotatedVertex.y
            
            // Re-check collinearity after flip
            let flippedEdgeStart = baseEdgeStart.applying(transform)
            let flippedEdgeEnd = baseEdgeEnd.applying(transform)
            
            let flippedStartDistance = perpendicularDistanceToLine(
                point: flippedEdgeStart,
                lineStart: canvasEdgeStart,
                lineEnd: canvasEdgeEnd
            )
            let flippedEndDistance = perpendicularDistanceToLine(
                point: flippedEdgeEnd,
                lineStart: canvasEdgeStart,
                lineEnd: canvasEdgeEnd
            )
            
            let flippedMaxDistance = max(flippedStartDistance, flippedEndDistance)
            if flippedMaxDistance > TangramConstants.mixedConnectionTolerance {
                Logger.tangramPlacement.warning("[CoordinateSystem] After flip, collinearity error \(String(format: "%.2f", flippedMaxDistance)) exceeds tolerance")
                return nil
            }
            
            Logger.tangramPlacement.debug("[CoordinateSystem] After flip, edge distances: start=\(String(format: "%.2f", flippedStartDistance)), end=\(String(format: "%.2f", flippedEndDistance))")
        }
        
        Logger.tangramPlacement.info("[CoordinateSystem] Vertex+edge alignment successful with final rotation \(String(format: "%.1f", rotationNeeded * 180 / .pi))°")
        
        return transform
    }

    /// Calculate transform for edge+edge dual connection
    /// Aligns the piece's selected edge to the canvas selected edge using direction + midpoint
    private static func calculateEdgeEdgeAlignment(
        pieceType: PieceType,
        isFlipped: Bool,
        edgeConnection1: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint),
        edgeConnection2: (canvas: PiecePlacementService.ConnectionPoint, piece: PiecePlacementService.ConnectionPoint),
        existingPieces: [TangramPiece],
        baseRotation: Double
    ) -> CGAffineTransform? {
        // Extract indices
        guard case .edge(let canvasEdgeIndex1) = edgeConnection1.canvas.type,
              case .edge(let pieceEdgeIndex1) = edgeConnection1.piece.type,
              let canvasEdgePiece1 = existingPieces.first(where: { $0.id == edgeConnection1.canvas.pieceId }) else {
            return nil
        }

        // Canvas edge 1 world data
        let canvasEdges1 = TangramGeometry.edges(for: canvasEdgePiece1.type)
        guard canvasEdgeIndex1 < canvasEdges1.count else { return nil }
        let canvasEdgeDef1 = canvasEdges1[canvasEdgeIndex1]
        let canvasVertices1 = getWorldVertices(for: canvasEdgePiece1)
        let canvasEdge1Start = canvasVertices1[canvasEdgeDef1.startVertex]
        let canvasEdge1End = canvasVertices1[canvasEdgeDef1.endVertex]
        let canvasEdge1Vector = CGVector(dx: canvasEdge1End.x - canvasEdge1Start.x, dy: canvasEdge1End.y - canvasEdge1Start.y)
        let canvasEdge1Angle = atan2(canvasEdge1Vector.dy, canvasEdge1Vector.dx)

        // Piece local edge 1 geometry
        let visualVertices = getVisualVertices(for: pieceType)
        let pieceEdges = TangramGeometry.edges(for: pieceType)
        guard pieceEdgeIndex1 < pieceEdges.count else { return nil }
        let pieceEdgeDef1 = pieceEdges[pieceEdgeIndex1]
        var pieceEdge1Start = visualVertices[pieceEdgeDef1.startVertex]
        var pieceEdge1End = visualVertices[pieceEdgeDef1.endVertex]

        // Apply flip in local space if parallelogram flipped
        if isFlipped && pieceType == .parallelogram {
            let flip = CGAffineTransform(scaleX: -1, y: 1)
            pieceEdge1Start = pieceEdge1Start.applying(flip)
            pieceEdge1End = pieceEdge1End.applying(flip)
        }

        // Compute rotation to align edge directions, including base rotation
        let pieceEdge1Vector = CGVector(dx: pieceEdge1End.x - pieceEdge1Start.x, dy: pieceEdge1End.y - pieceEdge1Start.y)
        let pieceEdge1Angle = atan2(pieceEdge1Vector.dy, pieceEdge1Vector.dx)
        var rotationNeeded = canvasEdge1Angle - pieceEdge1Angle + baseRotation

        // Snap if near 45° grid
        let deg = rotationNeeded * 180 / .pi
        let snapDeg = round(deg / 45) * 45
        if abs(deg - snapDeg) <= 1.0 {
            rotationNeeded = snapDeg * .pi / 180
        }

        // Build transform: Flip -> Rotate -> Translate(midpoints)
        var transform = CGAffineTransform.identity
        if isFlipped && pieceType == .parallelogram {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        transform = transform.rotated(by: rotationNeeded)

        // Compute midpoints
        let pieceEdge1MidLocal = CGPoint(x: (pieceEdge1Start.x + pieceEdge1End.x) / 2, y: (pieceEdge1Start.y + pieceEdge1End.y) / 2)
        let pieceEdge1MidTransformed = pieceEdge1MidLocal.applying(transform)
        let canvasEdge1Mid = CGPoint(x: (canvasEdge1Start.x + canvasEdge1End.x) / 2, y: (canvasEdge1Start.y + canvasEdge1End.y) / 2)

        // Translate to align midpoints
        transform.tx = canvasEdge1Mid.x - pieceEdge1MidTransformed.x
        transform.ty = canvasEdge1Mid.y - pieceEdge1MidTransformed.y

        // Verify collinearity for edge 1
        let transformedPieceEdge1Start = pieceEdge1Start.applying(transform)
        let transformedPieceEdge1End = pieceEdge1End.applying(transform)
        let d1Start = perpendicularDistanceToLine(point: transformedPieceEdge1Start, lineStart: canvasEdge1Start, lineEnd: canvasEdge1End)
        let d1End = perpendicularDistanceToLine(point: transformedPieceEdge1End, lineStart: canvasEdge1Start, lineEnd: canvasEdge1End)
        let maxD1 = max(d1Start, d1End)
        if maxD1 > TangramConstants.edgeToEdgeTolerance {
            return nil
        }

        // If we have a second edge connection, also verify it aligns to its canvas edge
        if case .edge(let canvasEdgeIndex2) = edgeConnection2.canvas.type,
           case .edge(let pieceEdgeIndex2) = edgeConnection2.piece.type,
           let canvasEdgePiece2 = existingPieces.first(where: { $0.id == edgeConnection2.canvas.pieceId }) {
            let canvasEdges2 = TangramGeometry.edges(for: canvasEdgePiece2.type)
            if canvasEdgeIndex2 < canvasEdges2.count {
                let canvasEdgeDef2 = canvasEdges2[canvasEdgeIndex2]
                let canvasVertices2 = getWorldVertices(for: canvasEdgePiece2)
                let canvasEdge2Start = canvasVertices2[canvasEdgeDef2.startVertex]
                let canvasEdge2End = canvasVertices2[canvasEdgeDef2.endVertex]

                if pieceEdgeIndex2 < pieceEdges.count {
                    let def2 = pieceEdges[pieceEdgeIndex2]
                    var p2Start = visualVertices[def2.startVertex]
                    var p2End = visualVertices[def2.endVertex]
                    if isFlipped && pieceType == .parallelogram {
                        let flip = CGAffineTransform(scaleX: -1, y: 1)
                        p2Start = p2Start.applying(flip)
                        p2End = p2End.applying(flip)
                    }
                    let tp2Start = p2Start.applying(transform)
                    let tp2End = p2End.applying(transform)
                    let d2Start = perpendicularDistanceToLine(point: tp2Start, lineStart: canvasEdge2Start, lineEnd: canvasEdge2End)
                    let d2End = perpendicularDistanceToLine(point: tp2End, lineStart: canvasEdge2Start, lineEnd: canvasEdge2End)
                    let maxD2 = max(d2Start, d2End)
                    if maxD2 > TangramConstants.edgeToEdgeTolerance {
                        return nil
                    }
                }
            }
        }

        // Final safety
        if !isValidTransform(transform) { return nil }
        return transform
    }
    
    /// Project a point onto a line segment
    private static func projectPointOntoLineSegment(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> CGPoint {
        let lineVector = CGVector(dx: lineEnd.x - lineStart.x, dy: lineEnd.y - lineStart.y)
        let lineLength = sqrt(lineVector.dx * lineVector.dx + lineVector.dy * lineVector.dy)
        
        if lineLength < 0.001 {
            return lineStart
        }
        
        let toPoint = CGVector(dx: point.x - lineStart.x, dy: point.y - lineStart.y)
        let t = max(0, min(1, (toPoint.dx * lineVector.dx + toPoint.dy * lineVector.dy) / (lineLength * lineLength)))
        
        return CGPoint(
            x: lineStart.x + t * lineVector.dx,
            y: lineStart.y + t * lineVector.dy
        )
    }
    
    /// Calculate perpendicular distance from a point to an infinite line
    private static func perpendicularDistanceToLine(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> CGFloat {
        let lineVector = CGVector(dx: lineEnd.x - lineStart.x, dy: lineEnd.y - lineStart.y)
        let lineLength = sqrt(lineVector.dx * lineVector.dx + lineVector.dy * lineVector.dy)
        
        if lineLength < 0.001 {
            // Degenerate line - return distance to point
            return distance(from: point, to: lineStart)
        }
        
        // Calculate perpendicular distance using cross product formula
        // Distance = |ax + by + c| / sqrt(a^2 + b^2)
        // Where line equation is: a(x - x1) + b(y - y1) = 0
        // And a = -(y2 - y1), b = (x2 - x1)
        
        let a = -(lineEnd.y - lineStart.y)
        let b = lineEnd.x - lineStart.x
        let c = -(a * lineStart.x + b * lineStart.y)
        
        let distance = abs(a * point.x + b * point.y + c) / sqrt(a * a + b * b)
        return distance
    }
    
    /// Calculate signed distance from a point to a line (positive on one side, negative on the other)
    private static func signedDistanceToLine(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint,
        normal: CGVector
    ) -> CGFloat {
        // Vector from line start to point
        let toPoint = CGVector(dx: point.x - lineStart.x, dy: point.y - lineStart.y)
        
        // Dot product with normal gives signed distance
        return toPoint.dx * normal.dx + toPoint.dy * normal.dy
    }
    
    /// Calculate centroid of a placed piece in world coordinates
    private static func calculatePieceCentroid(_ piece: TangramPiece) -> CGPoint {
        let vertices = getWorldVertices(for: piece)
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        
        for vertex in vertices {
            centerX += vertex.x
            centerY += vertex.y
        }
        
        centerX /= CGFloat(vertices.count)
        centerY /= CGFloat(vertices.count)
        
        return CGPoint(x: centerX, y: centerY)
    }
    
    /// Calculate centroid of a piece type after applying a transform
    private static func calculateTransformedPieceCentroid(
        pieceType: PieceType,
        transform: CGAffineTransform
    ) -> CGPoint {
        let visualVertices = getVisualVertices(for: pieceType)
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        
        for vertex in visualVertices {
            let transformed = vertex.applying(transform)
            centerX += transformed.x
            centerY += transformed.y
        }
        
        centerX /= CGFloat(visualVertices.count)
        centerY /= CGFloat(visualVertices.count)
        
        return CGPoint(x: centerX, y: centerY)
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