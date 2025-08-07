//
//  PieceTransformEngine.swift
//  Bemo
//
//  Unified transformation system for Tangram pieces - single source of truth
//

// WHAT: Calculates, validates, and applies ALL piece transformations (placement, rotation, sliding)
// ARCHITECTURE: Core service that replaces fragmented transformation logic across multiple services
// USAGE: Used by ViewModel for both preview AND actual placement - guarantees consistency
//
// CRITICAL DESIGN DECISIONS:
// 1. ROTATION: The piece being manipulated rotates; the connected piece stays stationary
//    - Maintains connection point at pivot throughout rotation
//    - Only shows valid 45° snap angles that don't cause overlaps
//    - Vertex-to-edge: vertex piece can rotate, edge piece cannot
//
// 2. SLIDING: Piece slides along stationary piece's edge
//    - Maintains edge-to-edge alignment (parallel and touching)
//    - Snaps to 0%, 25%, 50%, 75%, 100% of edge length
//    - Edge bounds: slides from one vertex to the other
//
// 3. VALIDATION: All transforms validated for:
//    - Overlap detection using Separating Axis Theorem
//    - Connection integrity maintenance
//    - Canvas bounds checking
//
// 4. PREVIEW CONSISTENCY: Same engine used for:
//    - Ghost preview during manipulation
//    - Final placement confirmation
//    - Ensures preview exactly matches placement

import Foundation
import CoreGraphics

@MainActor
class PieceTransformEngine {
    
    // MARK: - Types
    
    enum Operation {
        case place(center: CGPoint, rotation: Double)
        case rotate(angle: Double, pivot: CGPoint)
        case slide(distance: Double, edge: Edge)
        case drag(to: CGPoint)
    }
    
    struct Edge {
        let start: CGPoint
        let end: CGPoint
        let vector: CGVector
        
        var length: CGFloat {
            sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        }
        
        func pointAt(percent: Double) -> CGPoint {
            CGPoint(
                x: start.x + vector.dx * CGFloat(percent),
                y: start.y + vector.dy * CGFloat(percent)
            )
        }
    }
    
    struct TransformResult {
        let transform: CGAffineTransform
        let isValid: Bool
        let violations: [ValidationViolation]
        let snapInfo: SnapInfo?
    }
    
    struct ValidationViolation {
        enum ViolationType {
            case overlap(with: String) // piece ID
            case connectionBroken(Connection)
            case outOfBounds
        }
        let type: ViolationType
        let message: String
    }
    
    struct SnapInfo {
        let snappedValue: Double  // Angle in radians or distance
        let snapType: SnapType
        let snapPoints: [CGPoint]
    }
    
    enum SnapType {
        case rotation(angles: [Double])
        case slide(percentages: [Double])
    }
    
    // MARK: - Properties
    
    private let visualScale = TangramConstants.visualScale
    
    // MARK: - Public Interface
    
    /// Calculate and validate any piece transformation
    /// This is THE ONLY method for calculating transforms - used for both preview and placement
    func calculateTransform(
        for piece: TangramPiece,
        operation: Operation,
        connection: Connection? = nil,
        otherPieces: [TangramPiece] = [],
        canvasSize: CGSize = CGSize(width: 800, height: 600)
    ) -> TransformResult {
        
        // Step 1: Calculate base transform for the operation
        let (baseTransform, snapInfo) = calculateOperationTransform(
            piece: piece,
            operation: operation,
            connection: connection,
            otherPieces: otherPieces
        )
        
        // Step 2: Validate the transform
        let violations = validateTransform(
            baseTransform,
            for: piece,
            connection: connection,
            otherPieces: otherPieces,
            canvasSize: canvasSize
        )
        
        return TransformResult(
            transform: baseTransform,
            isValid: violations.isEmpty,
            violations: violations,
            snapInfo: snapInfo
        )
    }
    
    // MARK: - Transform Calculation
    
    private func calculateOperationTransform(
        piece: TangramPiece,
        operation: Operation,
        connection: Connection?,
        otherPieces: [TangramPiece]
    ) -> (CGAffineTransform, SnapInfo?) {
        
        switch operation {
        case .place(let center, let rotation):
            return calculatePlacementTransform(
                pieceType: piece.type,
                center: center,
                rotation: rotation
            )
            
        case .rotate(let angle, let pivot):
            return calculateRotationTransform(
                piece: piece,
                angle: angle,
                pivot: pivot,
                connection: connection,
                otherPieces: otherPieces
            )
            
        case .slide(let distance, let edge):
            return calculateSlideTransform(
                piece: piece,
                distance: distance,
                edge: edge,
                connection: connection,
                otherPieces: otherPieces
            )
            
        case .drag(let position):
            return calculateDragTransform(
                piece: piece,
                to: position
            )
        }
    }
    
    // MARK: - Placement Transform
    
    private func calculatePlacementTransform(
        pieceType: PieceType,
        center: CGPoint,
        rotation: Double
    ) -> (CGAffineTransform, SnapInfo?) {
        // Get the piece geometry
        let vertices = TangramGeometry.vertices(for: pieceType)
        
        // Calculate the centroid of the piece in local space
        var centroidX: CGFloat = 0
        var centroidY: CGFloat = 0
        for vertex in vertices {
            centroidX += vertex.x
            centroidY += vertex.y
        }
        centroidX /= CGFloat(vertices.count)
        centroidY /= CGFloat(vertices.count)
        
        // Scale to visual space
        let visualCentroid = CGPoint(
            x: centroidX * CGFloat(visualScale),
            y: centroidY * CGFloat(visualScale)
        )
        
        // Create transform: rotate first, then translate to center
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: rotation)
        transform.tx = center.x - visualCentroid.x * transform.a - visualCentroid.y * transform.c
        transform.ty = center.y - visualCentroid.x * transform.b - visualCentroid.y * transform.d
        
        return (transform, nil)
    }
    
    // MARK: - Rotation Transform
    
    /// Calculates rotation transform for a piece connected to another piece
    /// CRITICAL: The stationary piece (first in connection) never moves
    /// The rotating piece (second in connection) rotates around the connection point
    private func calculateRotationTransform(
        piece: TangramPiece,
        angle: Double,
        pivot: CGPoint,
        connection: Connection?,
        otherPieces: [TangramPiece]
    ) -> (CGAffineTransform, SnapInfo?) {
        
        guard let conn = connection else {
            // No connection - shouldn't happen for rotation
            return (piece.transform, nil)
        }
        
        // CRITICAL: Identify which piece is rotating vs stationary
        // The pivot point is ON the stationary piece
        // The rotating piece is the one we're calculating the transform for
        let (stationaryPieceId, rotatingPieceId, connectionPoint) = identifyRotationRoles(
            for: piece,
            connection: conn,
            otherPieces: otherPieces
        )
        
        guard piece.id == rotatingPieceId,
              let stationaryPiece = otherPieces.first(where: { $0.id == stationaryPieceId }) else {
            // This piece is the stationary one or connection is invalid
            return (piece.transform, nil)
        }
        
        // Get the connection point in the rotating piece's local coordinates
        let rotatingVertexIndex = getRotatingPieceVertexIndex(for: piece, connection: conn)
        let localVertex = TangramGeometry.vertices(for: piece.type)[rotatingVertexIndex]
        let visualVertex = CGPoint(
            x: localVertex.x * CGFloat(visualScale),
            y: localVertex.y * CGFloat(visualScale)
        )
        
        // Calculate valid rotation angles (45° increments that don't cause overlaps)
        let validAngles = calculateValidRotationAngles(
            rotatingPiece: piece,
            rotatingVertex: visualVertex,
            pivot: pivot,
            otherPieces: otherPieces.filter { $0.id != piece.id }
        )
        
        // Snap to nearest valid angle
        let degrees = angle * 180 / .pi
        let snappedDegrees = validAngles.min(by: { abs($0 - degrees) < abs($1 - degrees) }) ?? 0
        let snappedRadians = snappedDegrees * .pi / 180
        
        // Calculate the transform that:
        // 1. Rotates the piece by the snapped angle
        // 2. Keeps the connection point at the pivot
        var finalTransform = CGAffineTransform.identity
        
        // Apply rotation around the piece's connection point
        finalTransform = finalTransform.rotated(by: snappedRadians)
        
        // Position the piece so its connection point is at the pivot
        // After rotation, the local vertex is transformed
        let rotatedVertex = visualVertex.applying(CGAffineTransform(rotationAngle: snappedRadians))
        finalTransform.tx = pivot.x - rotatedVertex.x
        finalTransform.ty = pivot.y - rotatedVertex.y
        
        // Special handling for vertex-to-edge connections
        if case .vertexToEdge(let vertexPieceId, _, let edgePieceId, let edgeIndex) = conn.type,
           piece.id == vertexPieceId {
            // The rotating piece has a vertex that must stay on the stationary edge
            if let edgePiece = otherPieces.first(where: { $0.id == edgePieceId }) {
                let edgeVertices = TangramCoordinateSystem.getWorldVertices(for: edgePiece)
                let edges = TangramGeometry.edges(for: edgePiece.type)
                
                if edgeIndex < edges.count {
                    let edgeDef = edges[edgeIndex]
                    let edgeStart = edgeVertices[edgeDef.startVertex]
                    let edgeEnd = edgeVertices[edgeDef.endVertex]
                    
                    // Ensure the vertex stays on the edge by projecting
                    let currentVertexPos = visualVertex.applying(finalTransform)
                    let projectedPoint = projectPointOntoLineSegment(
                        point: currentVertexPos,
                        lineStart: edgeStart,
                        lineEnd: edgeEnd
                    )
                    
                    // Adjust if needed to keep vertex on edge
                    if hypot(projectedPoint.x - currentVertexPos.x, projectedPoint.y - currentVertexPos.y) > 0.1 {
                        finalTransform.tx += projectedPoint.x - currentVertexPos.x
                        finalTransform.ty += projectedPoint.y - currentVertexPos.y
                    }
                }
            }
        }
        
        let snapInfo = SnapInfo(
            snappedValue: snappedRadians,
            snapType: .rotation(angles: validAngles.map { $0 * .pi / 180 }),
            snapPoints: validAngles.map { angle in
                // Calculate where a reference point would be at each valid angle
                let refRadius: CGFloat = 50
                return CGPoint(
                    x: pivot.x + cos(angle * .pi / 180) * refRadius,
                    y: pivot.y + sin(angle * .pi / 180) * refRadius
                )
            }
        )
        
        return (finalTransform, snapInfo)
    }
    
    /// Identifies which piece is stationary and which is rotating in a connection
    /// CRITICAL: The piece being manipulated is the rotating one, the other is stationary
    private func identifyRotationRoles(
        for piece: TangramPiece,
        connection: Connection,
        otherPieces: [TangramPiece]
    ) -> (stationaryId: String, rotatingId: String, connectionPoint: CGPoint) {
        
        switch connection.type {
        case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
            // The piece being manipulated rotates, the other is stationary
            let rotatingId = piece.id
            let stationaryId = (piece.id == pieceAId) ? pieceBId : pieceAId
            
            // Get the connection point (vertex on stationary piece)
            if let stationaryPiece = otherPieces.first(where: { $0.id == stationaryId }) {
                let vertices = TangramCoordinateSystem.getWorldVertices(for: stationaryPiece)
                let stationaryVertex = (stationaryId == pieceAId) ? vertexA : vertexB
                let connectionPoint = vertices[stationaryVertex]
                return (stationaryId, rotatingId, connectionPoint)
            }
            
        case .vertexToEdge(let vertexPieceId, let vertex, let edgePieceId, let edge):
            // For vertex-to-edge connections:
            // If the vertex piece is being manipulated, it rotates around its vertex on the edge
            // If the edge piece is being manipulated, it cannot rotate (edge must stay under vertex)
            
            if piece.id == vertexPieceId {
                // Vertex piece rotates, edge piece is stationary
                let rotatingId = vertexPieceId
                let stationaryId = edgePieceId
                
                // Get the current position of the vertex (which is the pivot point)
                let vertexPieceVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
                let connectionPoint = vertexPieceVertices[vertex]
                return (stationaryId, rotatingId, connectionPoint)
                
            } else if piece.id == edgePieceId {
                // Edge piece cannot rotate in vertex-to-edge connection
                // The vertex must stay on the edge
                // Return piece as both stationary and rotating to prevent rotation
                return (piece.id, piece.id, CGPoint.zero)
            }
            
        case .edgeToEdge:
            // Edge-to-edge doesn't support rotation
            // Return piece as both stationary and rotating to prevent rotation
            return (piece.id, piece.id, CGPoint.zero)
        }
        
        // Fallback - shouldn't reach here
        return (piece.id, piece.id, CGPoint.zero)
    }
    
    /// Gets the vertex index in the rotating piece that connects to the stationary piece
    private func getRotatingPieceVertexIndex(for piece: TangramPiece, connection: Connection) -> Int {
        switch connection.type {
        case .vertexToVertex(let pieceAId, let vertexA, _, let vertexB):
            return piece.id == pieceAId ? vertexA : vertexB
        case .vertexToEdge(_, let vertex, _, _):
            return vertex
        default:
            return 0
        }
    }
    
    /// Calculates which rotation angles are valid (don't cause overlaps)
    private func calculateValidRotationAngles(
        rotatingPiece: TangramPiece,
        rotatingVertex: CGPoint,
        pivot: CGPoint,
        otherPieces: [TangramPiece]
    ) -> [Double] {
        
        let allAngles = [-180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0]
        var validAngles: [Double] = []
        
        for angle in allAngles {
            let radians = angle * .pi / 180
            
            // Create test transform for this angle
            var testTransform = CGAffineTransform.identity
            testTransform = testTransform.rotated(by: radians)
            
            // Position so connection point is at pivot
            let rotatedVertex = rotatingVertex.applying(CGAffineTransform(rotationAngle: radians))
            testTransform.tx = pivot.x - rotatedVertex.x
            testTransform.ty = pivot.y - rotatedVertex.y
            
            // Test for overlaps
            var testPiece = rotatingPiece
            testPiece.transform = testTransform
            
            var hasOverlap = false
            for other in otherPieces {
                if Self.hasAreaOverlap(testPiece, other) {
                    hasOverlap = true
                    break
                }
            }
            
            if !hasOverlap {
                validAngles.append(angle)
            }
        }
        
        // Always include current angle (0) if no valid angles found
        if validAngles.isEmpty {
            validAngles = [0.0]
        }
        
        return validAngles
    }
    
    // MARK: - Slide Transform
    
    /// Calculates slide transform for a piece sliding along another piece's edge
    /// CRITICAL: The piece with the edge is stationary, the other piece slides
    /// Maintains edge-to-edge alignment throughout the slide
    private func calculateSlideTransform(
        piece: TangramPiece,
        distance: Double,
        edge: Edge,
        connection: Connection?,
        otherPieces: [TangramPiece]
    ) -> (CGAffineTransform, SnapInfo?) {
        
        guard let conn = connection else {
            // No connection - shouldn't happen for sliding
            return (piece.transform, nil)
        }
        
        // The edge parameter represents the stationary piece's edge
        // The sliding piece moves along this edge while maintaining alignment
        
        // Calculate valid slide positions (0%, 25%, 50%, 75%, 100%)
        let snapPercentages = [0.0, 0.25, 0.5, 0.75, 1.0]
        let normalizedDistance = distance / Double(edge.length)
        let snappedPercentage = snapPercentages.min(by: { 
            abs($0 - normalizedDistance) < abs($1 - normalizedDistance) 
        }) ?? 0
        
        // Calculate the target position along the edge
        let targetPoint = edge.pointAt(percent: snappedPercentage)
        
        // For edge-to-edge connections, we need to maintain:
        // 1. The sliding piece's edge remains parallel to the stationary edge
        // 2. The edges remain touching (coincident)
        // 3. The piece can slide from one end to the other
        
        // Get the sliding piece's edge that's connected
        let slidingEdgeInfo = getSlidingPieceEdgeInfo(for: piece, connection: conn)
        
        // Calculate the transform that positions the sliding piece at the target point
        // while maintaining edge alignment
        var finalTransform = piece.transform
        
        // Get current edge midpoint in world space
        let currentVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
        let edges = TangramGeometry.edges(for: piece.type)
        
        if let slidingEdgeIndex = slidingEdgeInfo.edgeIndex,
           slidingEdgeIndex < edges.count {
            
            let edgeDef = edges[slidingEdgeIndex]
            let currentEdgeStart = currentVertices[edgeDef.startVertex]
            let currentEdgeEnd = currentVertices[edgeDef.endVertex]
            let currentEdgeMidpoint = CGPoint(
                x: (currentEdgeStart.x + currentEdgeEnd.x) / 2,
                y: (currentEdgeStart.y + currentEdgeEnd.y) / 2
            )
            
            // Calculate offset to move edge midpoint to target point
            let offsetX = targetPoint.x - currentEdgeMidpoint.x
            let offsetY = targetPoint.y - currentEdgeMidpoint.y
            
            // Apply the offset to maintain the slide
            finalTransform.tx += offsetX
            finalTransform.ty += offsetY
            
        } else {
            // Fallback: simple slide along the edge vector
            let slideDistance = snappedPercentage * Double(edge.length)
            let slideVector = CGVector(
                dx: edge.vector.dx * CGFloat(slideDistance) / edge.length,
                dy: edge.vector.dy * CGFloat(slideDistance) / edge.length
            )
            
            finalTransform.tx = piece.transform.tx + slideVector.dx
            finalTransform.ty = piece.transform.ty + slideVector.dy
        }
        
        let snapInfo = SnapInfo(
            snappedValue: snappedPercentage * Double(edge.length),
            snapType: .slide(percentages: snapPercentages),
            snapPoints: snapPercentages.map { edge.pointAt(percent: $0) }
        )
        
        return (finalTransform, snapInfo)
    }
    
    /// Gets information about which edge of the sliding piece is connected
    private func getSlidingPieceEdgeInfo(for piece: TangramPiece, connection: Connection) -> (edgeIndex: Int?, orientation: CGFloat) {
        switch connection.type {
        case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
            // Identify which edge belongs to this piece
            if piece.id == pieceAId {
                return (edgeIndex: edgeA, orientation: 0)
            } else if piece.id == pieceBId {
                return (edgeIndex: edgeB, orientation: 0)
            }
        default:
            // Not an edge-to-edge connection
            break
        }
        return (edgeIndex: nil, orientation: 0)
    }
    
    // MARK: - Drag Transform
    
    private func calculateDragTransform(
        piece: TangramPiece,
        to position: CGPoint
    ) -> (CGAffineTransform, SnapInfo?) {
        
        // Get current piece center
        let vertices = TangramCoordinateSystem.getWorldVertices(for: piece)
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        for vertex in vertices {
            centerX += vertex.x
            centerY += vertex.y
        }
        centerX /= CGFloat(vertices.count)
        centerY /= CGFloat(vertices.count)
        
        // Calculate offset
        let offsetX = position.x - centerX
        let offsetY = position.y - centerY
        
        // Apply offset to current transform
        var finalTransform = piece.transform
        finalTransform.tx += offsetX
        finalTransform.ty += offsetY
        
        return (finalTransform, nil)
    }
    
    // MARK: - Validation
    
    private func validateTransform(
        _ transform: CGAffineTransform,
        for piece: TangramPiece,
        connection: Connection?,
        otherPieces: [TangramPiece],
        canvasSize: CGSize
    ) -> [ValidationViolation] {
        
        var violations: [ValidationViolation] = []
        
        // Create test piece with new transform
        var testPiece = piece
        testPiece.transform = transform
        
        // Check 1: Overlap with other pieces
        for other in otherPieces where other.id != piece.id {
            if Self.hasAreaOverlap(testPiece, other) {
                violations.append(ValidationViolation(
                    type: .overlap(with: other.id),
                    message: "Piece would overlap with another piece"
                ))
                break // One overlap is enough to invalidate
            }
        }
        
        // Check 2: Connection integrity
        if let conn = connection {
            if !isConnectionMaintained(testPiece, connection: conn, otherPieces: otherPieces) {
                violations.append(ValidationViolation(
                    type: .connectionBroken(conn),
                    message: "Connection would be broken"
                ))
            }
        }
        
        // Check 3: Canvas bounds (warning only, not blocking)
        let vertices = TangramCoordinateSystem.getWorldVertices(for: testPiece)
        let inBounds = vertices.allSatisfy { vertex in
            vertex.x >= -50 && vertex.x <= canvasSize.width + 50 &&
            vertex.y >= -50 && vertex.y <= canvasSize.height + 50
        }
        
        if !inBounds {
            violations.append(ValidationViolation(
                type: .outOfBounds,
                message: "Piece is partially out of bounds"
            ))
        }
        
        return violations
    }
    
    // MARK: - Overlap Detection
    
    static func hasAreaOverlap(_ pieceA: TangramPiece, _ pieceB: TangramPiece) -> Bool {
        let verticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
        let verticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
        
        // Use Separating Axis Theorem (SAT) with tolerance for touching pieces
        let axes = getAxes(vertices: verticesA) + getAxes(vertices: verticesB)
        
        // Small tolerance to allow pieces that are just touching (e.g., vertex-to-vertex)
        let tolerance: CGFloat = 0.1
        
        for axis in axes {
            let projectionA = projectVertices(verticesA, onto: axis)
            let projectionB = projectVertices(verticesB, onto: axis)
            
            // Check if projections are separated with tolerance
            // This allows pieces to touch but not overlap
            if projectionA.max < projectionB.min - tolerance || projectionB.max < projectionA.min - tolerance {
                // Found a separating axis - no overlap
                return false
            }
        }
        
        // No separating axis found - check if pieces are just touching or actually overlapping
        // If we reach here, projections overlap on all axes
        // But we need to distinguish between touching (valid) and overlapping (invalid)
        
        // Check if any vertices are shared (touching is OK)
        let touchTolerance: CGFloat = 1.0
        var touchingVertices = 0
        for vA in verticesA {
            for vB in verticesB {
                let distance = sqrt(pow(vA.x - vB.x, 2) + pow(vA.y - vB.y, 2))
                if distance < touchTolerance {
                    touchingVertices += 1
                }
            }
        }
        
        // If pieces are only touching at vertices (1-2 vertices), they're not overlapping
        // More than 2 shared vertices means actual overlap
        if touchingVertices > 0 && touchingVertices <= 2 {
            return false // Just touching, not overlapping
        }
        
        return true // Actual overlap
    }
    
    private static func getAxes(vertices: [CGPoint]) -> [CGVector] {
        var axes: [CGVector] = []
        
        for i in 0..<vertices.count {
            let vertex1 = vertices[i]
            let vertex2 = vertices[(i + 1) % vertices.count]
            
            // Get edge vector
            let edge = CGVector(dx: vertex2.x - vertex1.x, dy: vertex2.y - vertex1.y)
            
            // Get perpendicular (normal)
            let normal = CGVector(dx: -edge.dy, dy: edge.dx)
            
            // Normalize
            let length = sqrt(normal.dx * normal.dx + normal.dy * normal.dy)
            if length > 0.001 {
                axes.append(CGVector(dx: normal.dx / length, dy: normal.dy / length))
            }
        }
        
        return axes
    }
    
    private static func projectVertices(_ vertices: [CGPoint], onto axis: CGVector) -> (min: CGFloat, max: CGFloat) {
        var min = CGFloat.greatestFiniteMagnitude
        var max = -CGFloat.greatestFiniteMagnitude
        
        for vertex in vertices {
            let projection = vertex.x * axis.dx + vertex.y * axis.dy
            min = Swift.min(min, projection)
            max = Swift.max(max, projection)
        }
        
        return (min, max)
    }
    
    // MARK: - Connection Validation
    
    private func isConnectionMaintained(
        _ piece: TangramPiece,
        connection: Connection,
        otherPieces: [TangramPiece]
    ) -> Bool {
        
        switch connection.type {
        case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
            guard let otherPiece = otherPieces.first(where: { 
                $0.id == (piece.id == pieceAId ? pieceBId : pieceAId) 
            }) else { return false }
            
            let verticesThis = TangramCoordinateSystem.getWorldVertices(for: piece)
            let verticesOther = TangramCoordinateSystem.getWorldVertices(for: otherPiece)
            
            let thisVertex = piece.id == pieceAId ? vertexA : vertexB
            let otherVertex = piece.id == pieceAId ? vertexB : vertexA
            
            guard thisVertex < verticesThis.count, otherVertex < verticesOther.count else {
                return false
            }
            
            let distance = hypot(
                verticesThis[thisVertex].x - verticesOther[otherVertex].x,
                verticesThis[thisVertex].y - verticesOther[otherVertex].y
            )
            
            return distance < 2.0 // tolerance
            
        case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
            let isVertexPiece = piece.id == pieceAId
            
            if isVertexPiece {
                // This piece has the vertex
                guard let edgePiece = otherPieces.first(where: { $0.id == pieceBId }) else {
                    return false
                }
                
                let vertices = TangramCoordinateSystem.getWorldVertices(for: piece)
                guard vertex < vertices.count else { return false }
                let vertexPoint = vertices[vertex]
                
                let edgeVertices = TangramCoordinateSystem.getWorldVertices(for: edgePiece)
                let edges = TangramGeometry.edges(for: edgePiece.type)
                guard edge < edges.count else { return false }
                
                let edgeDef = edges[edge]
                let edgeStart = edgeVertices[edgeDef.startVertex]
                let edgeEnd = edgeVertices[edgeDef.endVertex]
                
                return isPointOnLineSegment(
                    point: vertexPoint,
                    lineStart: edgeStart,
                    lineEnd: edgeEnd,
                    tolerance: 2.0
                )
            } else {
                // This piece has the edge - vertex piece must have its vertex on our edge
                guard let vertexPiece = otherPieces.first(where: { $0.id == pieceAId }) else {
                    return false
                }
                
                let vertexPieceVertices = TangramCoordinateSystem.getWorldVertices(for: vertexPiece)
                guard vertex < vertexPieceVertices.count else { return false }
                let vertexPoint = vertexPieceVertices[vertex]
                
                let edgeVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
                let edges = TangramGeometry.edges(for: piece.type)
                guard edge < edges.count else { return false }
                
                let edgeDef = edges[edge]
                let edgeStart = edgeVertices[edgeDef.startVertex]
                let edgeEnd = edgeVertices[edgeDef.endVertex]
                
                return isPointOnLineSegment(
                    point: vertexPoint,
                    lineStart: edgeStart,
                    lineEnd: edgeEnd,
                    tolerance: 2.0
                )
            }
            
        case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
            guard let otherPiece = otherPieces.first(where: { 
                $0.id == (piece.id == pieceAId ? pieceBId : pieceAId) 
            }) else { return false }
            
            let verticesThis = TangramCoordinateSystem.getWorldVertices(for: piece)
            let verticesOther = TangramCoordinateSystem.getWorldVertices(for: otherPiece)
            
            let edgesThis = TangramGeometry.edges(for: piece.type)
            let edgesOther = TangramGeometry.edges(for: otherPiece.type)
            
            let thisEdge = piece.id == pieceAId ? edgeA : edgeB
            let otherEdge = piece.id == pieceAId ? edgeB : edgeA
            
            guard thisEdge < edgesThis.count, otherEdge < edgesOther.count else {
                return false
            }
            
            let thisEdgeDef = edgesThis[thisEdge]
            let otherEdgeDef = edgesOther[otherEdge]
            
            let thisStart = verticesThis[thisEdgeDef.startVertex]
            let thisEnd = verticesThis[thisEdgeDef.endVertex]
            let otherStart = verticesOther[otherEdgeDef.startVertex]
            let otherEnd = verticesOther[otherEdgeDef.endVertex]
            
            // Check if edges are parallel and touching
            return areEdgesParallelAndTouching(
                edge1Start: thisStart,
                edge1End: thisEnd,
                edge2Start: otherStart,
                edge2End: otherEnd
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getConnectedVertexIndex(for piece: TangramPiece, connection: Connection?) -> Int {
        guard let conn = connection else { return 0 }
        
        switch conn.type {
        case .vertexToVertex(let pieceAId, let vertexA, _, let vertexB):
            return piece.id == pieceAId ? vertexA : vertexB
        case .vertexToEdge(let pieceAId, let vertex, _, _):
            return piece.id == pieceAId ? vertex : 0
        default:
            return 0
        }
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
    
    private func areEdgesParallelAndTouching(
        edge1Start: CGPoint,
        edge1End: CGPoint,
        edge2Start: CGPoint,
        edge2End: CGPoint
    ) -> Bool {
        // Calculate edge vectors
        let v1 = CGVector(dx: edge1End.x - edge1Start.x, dy: edge1End.y - edge1Start.y)
        let v2 = CGVector(dx: edge2End.x - edge2Start.x, dy: edge2End.y - edge2Start.y)
        
        let len1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let len2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        guard len1 > 0.001 && len2 > 0.001 else { return false }
        
        // Normalize vectors
        let n1 = CGVector(dx: v1.dx / len1, dy: v1.dy / len1)
        let n2 = CGVector(dx: v2.dx / len2, dy: v2.dy / len2)
        
        // Check if parallel (dot product should be -1 or 1)
        let dotProduct = n1.dx * n2.dx + n1.dy * n2.dy
        let isParallel = abs(abs(dotProduct) - 1.0) < 0.01
        
        if !isParallel { return false }
        
        // Check if edges overlap/touch
        let tolerance: CGFloat = 2.0
        
        // Check if any endpoint is close to the other edge
        let s1ToE2 = isPointOnLineSegment(point: edge1Start, lineStart: edge2Start, lineEnd: edge2End, tolerance: tolerance)
        let e1ToE2 = isPointOnLineSegment(point: edge1End, lineStart: edge2Start, lineEnd: edge2End, tolerance: tolerance)
        let s2ToE1 = isPointOnLineSegment(point: edge2Start, lineStart: edge1Start, lineEnd: edge1End, tolerance: tolerance)
        let e2ToE1 = isPointOnLineSegment(point: edge2End, lineStart: edge1Start, lineEnd: edge1End, tolerance: tolerance)
        
        return s1ToE2 || e1ToE2 || s2ToE1 || e2ToE1
    }
}