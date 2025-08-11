//
//  TangramValidationService.swift
//  Bemo
//
//  Unified validation service for Tangram Editor - single source of truth
//

// WHAT: Single source of truth for ALL tangram piece validation logic
// ARCHITECTURE: Service layer in MVVM-S, injected via DependencyContainer
// USAGE: Replace all scattered validation logic with calls to this service
//
// RESPONSIBILITIES:
// - Transform validation (as-placed, no re-centering)
// - Connection integrity checking (ALL connections, not just first)
// - Overlap detection using SAT
// - Tolerance management (single, consistent definitions)
// - Parallelogram remapping (centralized)
//
// NOT RESPONSIBLE FOR:
// - Transform calculations (use PieceTransformEngine)
// - UI state management (handled by ViewModel)
// - Connection creation (use ConnectionService)

import Foundation
import CoreGraphics
import OSLog

@MainActor
class TangramValidationService {
    
    // MARK: - Types
    
    struct ValidationResult {
        let isValid: Bool
        let violations: [ValidationViolation]
        
        static let valid = ValidationResult(isValid: true, violations: [])
    }
    
    struct ValidationViolation {
        enum ViolationType {
            case overlap(with: String)
            case connectionBroken(type: String)
            case outOfBounds
            case invalidTransform
        }
        let type: ViolationType
        let message: String
    }
    
    struct ValidationContext {
        let connection: Connection?
        let otherPieces: [TangramPiece]
        let canvasSize: CGSize
        let allowOutOfBounds: Bool
        
        init(
            connection: Connection? = nil,
            otherPieces: [TangramPiece] = [],
            canvasSize: CGSize = CGSize(width: 800, height: 600),
            allowOutOfBounds: Bool = false
        ) {
            self.connection = connection
            self.otherPieces = otherPieces
            self.canvasSize = canvasSize
            self.allowOutOfBounds = allowOutOfBounds
        }
    }
    
    // MARK: - Tolerance Configuration
    
    enum ToleranceType {
        case vertexToVertex
        case edgeToEdge
        case vertexToEdge
        case mixed
        case overlap
        
        var value: CGFloat {
            switch self {
            case .vertexToVertex:
                return TangramConstants.vertexToVertexTolerance
            case .edgeToEdge:
                return TangramConstants.edgeToEdgeTolerance
            case .vertexToEdge:
                return TangramConstants.vertexToEdgeTolerance
            case .mixed:
                return TangramConstants.mixedConnectionTolerance
            case .overlap:
                return TangramConstants.overlapTolerance
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Validate a piece placement with its current transform (as-placed)
    /// This is THE ONLY validation method - used for both preview and final placement
    func validatePlacement(
        _ piece: TangramPiece,
        context: ValidationContext
    ) -> ValidationResult {
        
        var violations: [ValidationViolation] = []
        
        // Step 1: Validate transform is valid (not degenerate)
        if !isValidTransform(piece.transform) {
            violations.append(ValidationViolation(
                type: .invalidTransform,
                message: "Transform is invalid or degenerate"
            ))
            return ValidationResult(isValid: false, violations: violations)
        }
        
        // Step 2: Validate ALL connection constraints (not just the first)
        if let connection = context.connection {
            let connectionViolations = validateConnectionIntegrity(
                piece: piece,
                connection: connection,
                otherPieces: context.otherPieces
            )
            violations.append(contentsOf: connectionViolations)
        }
        
        // Step 3: Check overlap ONLY if no connection violations
        // AND exclude directly connected piece from overlap check
        if violations.isEmpty {
            let overlapViolations = validateNoOverlap(
                piece: piece,
                otherPieces: context.otherPieces,
                excludeConnectedPiece: context.connection
            )
            violations.append(contentsOf: overlapViolations)
        }
        
        // Step 4: Check canvas bounds (optional, warning only)
        if !context.allowOutOfBounds {
            let boundsViolations = validateCanvasBounds(
                piece: piece,
                canvasSize: context.canvasSize
            )
            violations.append(contentsOf: boundsViolations)
        }
        
        return ValidationResult(
            isValid: violations.isEmpty,
            violations: violations
        )
    }
    
    /// Validate multiple connections at once (for dual-connection scenarios)
    func validateMultipleConnections(
        _ piece: TangramPiece,
        connections: [Connection],
        otherPieces: [TangramPiece]
    ) -> ValidationResult {
        
        var violations: [ValidationViolation] = []
        
        // Validate EACH connection independently
        for connection in connections {
            let connectionViolations = validateConnectionIntegrity(
                piece: piece,
                connection: connection,
                otherPieces: otherPieces
            )
            violations.append(contentsOf: connectionViolations)
        }
        
        return ValidationResult(
            isValid: violations.isEmpty,
            violations: violations
        )
    }
    
    // MARK: - Connection Validation
    
    private func validateConnectionIntegrity(
        piece: TangramPiece,
        connection: Connection,
        otherPieces: [TangramPiece]
    ) -> [ValidationViolation] {
        
        switch connection.type {
        case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
            return validateVertexToVertex(
                piece: piece,
                pieceAId: pieceAId,
                vertexA: vertexA,
                pieceBId: pieceBId,
                vertexB: vertexB,
                otherPieces: otherPieces
            )
            
        case .vertexToEdge(let vertexPieceId, let vertex, let edgePieceId, let edge):
            return validateVertexToEdge(
                piece: piece,
                vertexPieceId: vertexPieceId,
                vertex: vertex,
                edgePieceId: edgePieceId,
                edge: edge,
                otherPieces: otherPieces
            )
            
        case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
            return validateEdgeToEdge(
                piece: piece,
                pieceAId: pieceAId,
                edgeA: edgeA,
                pieceBId: pieceBId,
                edgeB: edgeB,
                otherPieces: otherPieces
            )
        }
    }
    
    private func validateVertexToVertex(
        piece: TangramPiece,
        pieceAId: String,
        vertexA: Int,
        pieceBId: String,
        vertexB: Int,
        otherPieces: [TangramPiece]
    ) -> [ValidationViolation] {
        
        guard let otherPiece = otherPieces.first(where: {
            $0.id == (piece.id == pieceAId ? pieceBId : pieceAId)
        }) else {
            return [ValidationViolation(
                type: .connectionBroken(type: "vertex-to-vertex"),
                message: "Connected piece not found"
            )]
        }
        
        let verticesThis = TangramEditorCoordinateSystem.getWorldVertices(for: piece)
        let verticesOther = TangramEditorCoordinateSystem.getWorldVertices(for: otherPiece)
        
        let thisVertex = piece.id == pieceAId ? vertexA : vertexB
        let otherVertex = piece.id == pieceAId ? vertexB : vertexA
        
        guard thisVertex < verticesThis.count, otherVertex < verticesOther.count else {
            return [ValidationViolation(
                type: .connectionBroken(type: "vertex-to-vertex"),
                message: "Invalid vertex index"
            )]
        }
        
        let distance = hypot(
            verticesThis[thisVertex].x - verticesOther[otherVertex].x,
            verticesThis[thisVertex].y - verticesOther[otherVertex].y
        )
        
        if distance > ToleranceType.vertexToVertex.value {
            return [ValidationViolation(
                type: .connectionBroken(type: "vertex-to-vertex"),
                message: "Vertices are too far apart: \(String(format: "%.2f", distance))"
            )]
        }
        
        return []
    }
    
    private func validateVertexToEdge(
        piece: TangramPiece,
        vertexPieceId: String,
        vertex: Int,
        edgePieceId: String,
        edge: Int,
        otherPieces: [TangramPiece]
    ) -> [ValidationViolation] {
        
        let isVertexPiece = piece.id == vertexPieceId
        
        if isVertexPiece {
            guard let edgePiece = otherPieces.first(where: { $0.id == edgePieceId }) else {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Edge piece not found"
                )]
            }
            
            let vertices = TangramEditorCoordinateSystem.getWorldVertices(for: piece)
            guard vertex < vertices.count else {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Invalid vertex index"
                )]
            }
            
            let vertexPoint = vertices[vertex]
            let edgeVertices = TangramEditorCoordinateSystem.getWorldVertices(for: edgePiece)
            let edges = TangramGeometry.edges(for: edgePiece.type)
            
            guard edge < edges.count else {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Invalid edge index"
                )]
            }
            
            let edgeDef = edges[edge]
            let edgeStart = edgeVertices[edgeDef.startVertex]
            let edgeEnd = edgeVertices[edgeDef.endVertex]
            
            if !isPointOnLineSegment(
                point: vertexPoint,
                lineStart: edgeStart,
                lineEnd: edgeEnd,
                tolerance: ToleranceType.vertexToEdge.value
            ) {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Vertex is not on edge"
                )]
            }
        } else {
            guard let vertexPiece = otherPieces.first(where: { $0.id == vertexPieceId }) else {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Vertex piece not found"
                )]
            }
            
            let vertexPieceVertices = TangramEditorCoordinateSystem.getWorldVertices(for: vertexPiece)
            guard vertex < vertexPieceVertices.count else {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Invalid vertex index"
                )]
            }
            
            let vertexPoint = vertexPieceVertices[vertex]
            let edgeVertices = TangramEditorCoordinateSystem.getWorldVertices(for: piece)
            let edges = TangramGeometry.edges(for: piece.type)
            
            guard edge < edges.count else {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Invalid edge index"
                )]
            }
            
            let edgeDef = edges[edge]
            let edgeStart = edgeVertices[edgeDef.startVertex]
            let edgeEnd = edgeVertices[edgeDef.endVertex]
            
            if !isPointOnLineSegment(
                point: vertexPoint,
                lineStart: edgeStart,
                lineEnd: edgeEnd,
                tolerance: ToleranceType.vertexToEdge.value
            ) {
                return [ValidationViolation(
                    type: .connectionBroken(type: "vertex-to-edge"),
                    message: "Vertex is not on edge"
                )]
            }
        }
        
        return []
    }
    
    private func validateEdgeToEdge(
        piece: TangramPiece,
        pieceAId: String,
        edgeA: Int,
        pieceBId: String,
        edgeB: Int,
        otherPieces: [TangramPiece]
    ) -> [ValidationViolation] {
        
        guard let otherPiece = otherPieces.first(where: {
            $0.id == (piece.id == pieceAId ? pieceBId : pieceAId)
        }) else {
            return [ValidationViolation(
                type: .connectionBroken(type: "edge-to-edge"),
                message: "Connected piece not found"
            )]
        }
        
        let verticesThis = TangramEditorCoordinateSystem.getWorldVertices(for: piece)
        let verticesOther = TangramEditorCoordinateSystem.getWorldVertices(for: otherPiece)
        
        let edgesThis = TangramGeometry.edges(for: piece.type)
        let edgesOther = TangramGeometry.edges(for: otherPiece.type)
        
        let thisEdge = piece.id == pieceAId ? edgeA : edgeB
        let otherEdge = piece.id == pieceAId ? edgeB : edgeA
        
        guard thisEdge < edgesThis.count, otherEdge < edgesOther.count else {
            return [ValidationViolation(
                type: .connectionBroken(type: "edge-to-edge"),
                message: "Invalid edge index"
            )]
        }
        
        let thisEdgeDef = edgesThis[thisEdge]
        let otherEdgeDef = edgesOther[otherEdge]
        
        let thisStart = verticesThis[thisEdgeDef.startVertex]
        let thisEnd = verticesThis[thisEdgeDef.endVertex]
        let otherStart = verticesOther[otherEdgeDef.startVertex]
        let otherEnd = verticesOther[otherEdgeDef.endVertex]
        
        if !areEdgesParallelAndTouching(
            edge1Start: thisStart,
            edge1End: thisEnd,
            edge2Start: otherStart,
            edge2End: otherEnd,
            tolerance: ToleranceType.edgeToEdge.value
        ) {
            return [ValidationViolation(
                type: .connectionBroken(type: "edge-to-edge"),
                message: "Edges are not parallel and touching"
            )]
        }
        
        return []
    }
    
    // MARK: - Overlap Validation
    
    private func validateNoOverlap(
        piece: TangramPiece,
        otherPieces: [TangramPiece],
        excludeConnectedPiece: Connection?
    ) -> [ValidationViolation] {
        
        var violations: [ValidationViolation] = []
        
        // Determine which piece to exclude from overlap check
        var excludePieceId: String? = nil
        if let connection = excludeConnectedPiece {
            switch connection.type {
            case .vertexToVertex(let pieceAId, _, let pieceBId, _),
                 .vertexToEdge(let pieceAId, _, let pieceBId, _),
                 .edgeToEdge(let pieceAId, _, let pieceBId, _):
                excludePieceId = piece.id == pieceAId ? pieceBId : pieceAId
            }
        }
        
        for other in otherPieces where other.id != piece.id {
            // Skip overlap check for directly connected piece
            if let excludeId = excludePieceId, other.id == excludeId {
                continue
            }
            
            if hasAreaOverlap(piece, other) {
                violations.append(ValidationViolation(
                    type: .overlap(with: other.id),
                    message: "Piece overlaps with \(other.type.rawValue)"
                ))
                break // One overlap is enough
            }
        }
        
        return violations
    }
    
    // MARK: - Bounds Validation
    
    private func validateCanvasBounds(
        piece: TangramPiece,
        canvasSize: CGSize
    ) -> [ValidationViolation] {
        
        let vertices = TangramEditorCoordinateSystem.getWorldVertices(for: piece)
        let margin: CGFloat = 50 // Allow some margin outside canvas
        
        let inBounds = vertices.allSatisfy { vertex in
            vertex.x >= -margin && vertex.x <= canvasSize.width + margin &&
            vertex.y >= -margin && vertex.y <= canvasSize.height + margin
        }
        
        if !inBounds {
            return [ValidationViolation(
                type: .outOfBounds,
                message: "Piece is partially out of canvas bounds"
            )]
        }
        
        return []
    }
    
    // MARK: - SAT Overlap Detection
    
    private func hasAreaOverlap(_ pieceA: TangramPiece, _ pieceB: TangramPiece) -> Bool {
        let verticesA = TangramEditorCoordinateSystem.getWorldVertices(for: pieceA)
        let verticesB = TangramEditorCoordinateSystem.getWorldVertices(for: pieceB)
        
        let axes = getAxes(vertices: verticesA) + getAxes(vertices: verticesB)
        let tolerance = ToleranceType.overlap.value
        
        for axis in axes {
            let projectionA = projectVertices(verticesA, onto: axis)
            let projectionB = projectVertices(verticesB, onto: axis)
            
            let gap = max(projectionA.min - projectionB.max, projectionB.min - projectionA.max)
            
            if gap > -tolerance {
                return false // Found separating axis
            }
        }
        
        return true // No separating axis found - pieces overlap
    }
    
    private func getAxes(vertices: [CGPoint]) -> [CGVector] {
        var axes: [CGVector] = []
        
        for i in 0..<vertices.count {
            let vertex1 = vertices[i]
            let vertex2 = vertices[(i + 1) % vertices.count]
            
            let edge = CGVector(dx: vertex2.x - vertex1.x, dy: vertex2.y - vertex1.y)
            let normal = CGVector(dx: -edge.dy, dy: edge.dx)
            
            let length = sqrt(normal.dx * normal.dx + normal.dy * normal.dy)
            if length > 0.001 {
                axes.append(CGVector(dx: normal.dx / length, dy: normal.dy / length))
            }
        }
        
        return axes
    }
    
    private func projectVertices(_ vertices: [CGPoint], onto axis: CGVector) -> (min: CGFloat, max: CGFloat) {
        var min = CGFloat.greatestFiniteMagnitude
        var max = -CGFloat.greatestFiniteMagnitude
        
        for vertex in vertices {
            let projection = vertex.x * axis.dx + vertex.y * axis.dy
            min = Swift.min(min, projection)
            max = Swift.max(max, projection)
        }
        
        return (min, max)
    }
    
    // MARK: - Geometry Helpers
    
    private func isPointOnLineSegment(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        let projected = projectPointOntoLineSegment(
            point: point,
            lineStart: lineStart,
            lineEnd: lineEnd
        )
        
        let distance = hypot(point.x - projected.x, point.y - projected.y)
        return distance <= tolerance
    }
    
    private func projectPointOntoLineSegment(
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
    
    private func areEdgesParallelAndTouching(
        edge1Start: CGPoint,
        edge1End: CGPoint,
        edge2Start: CGPoint,
        edge2End: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        let v1 = CGVector(dx: edge1End.x - edge1Start.x, dy: edge1End.y - edge1Start.y)
        let v2 = CGVector(dx: edge2End.x - edge2Start.x, dy: edge2End.y - edge2Start.y)
        
        let len1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let len2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        guard len1 > 0.001 && len2 > 0.001 else { return false }
        
        let n1 = CGVector(dx: v1.dx / len1, dy: v1.dy / len1)
        let n2 = CGVector(dx: v2.dx / len2, dy: v2.dy / len2)
        
        let dotProduct = n1.dx * n2.dx + n1.dy * n2.dy
        let isParallel = abs(abs(dotProduct) - 1.0) < 0.01
        
        if !isParallel { return false }
        
        // Check if edges overlap/touch
        let s1ToE2 = isPointOnLineSegment(point: edge1Start, lineStart: edge2Start, lineEnd: edge2End, tolerance: tolerance)
        let e1ToE2 = isPointOnLineSegment(point: edge1End, lineStart: edge2Start, lineEnd: edge2End, tolerance: tolerance)
        let s2ToE1 = isPointOnLineSegment(point: edge2Start, lineStart: edge1Start, lineEnd: edge1End, tolerance: tolerance)
        let e2ToE1 = isPointOnLineSegment(point: edge2End, lineStart: edge1Start, lineEnd: edge1End, tolerance: tolerance)
        
        return s1ToE2 || e1ToE2 || s2ToE1 || e2ToE1
    }
    
    private func isValidTransform(_ transform: CGAffineTransform) -> Bool {
        // Check for degenerate transform (determinant near zero)
        let determinant = transform.a * transform.d - transform.b * transform.c
        if abs(determinant) < 0.0001 {
            return false
        }
        
        // Check for NaN or infinite values
        let values = [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty]
        for value in values {
            if value.isNaN || value.isInfinite {
                return false
            }
        }
        
        return true
    }
}