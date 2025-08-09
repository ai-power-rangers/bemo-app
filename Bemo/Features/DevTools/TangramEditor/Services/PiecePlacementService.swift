//
//  PiecePlacementService.swift
//  Bemo
//
//  Service for managing tangram piece placement logic
//

// WHAT: Coordinates piece placement by delegating transform calculations to PieceTransformEngine
// ARCHITECTURE: Service layer in MVVM-S, ensures consistency between preview and placement
// USAGE: Used by ViewModels and Coordinator for piece placement operations

import Foundation
import CoreGraphics

@MainActor
class PiecePlacementService {
    
    private let transformEngine: PieceTransformEngine
    private let connectionService: ConnectionService
    
    init(transformEngine: PieceTransformEngine,
         connectionService: ConnectionService) {
        self.transformEngine = transformEngine
        self.connectionService = connectionService
    }
    
    // MARK: - Piece Placement
    
    /// Place first piece at center of canvas using transform engine
    func placeFirstPiece(type: PieceType, rotation: Double, canvasSize: CGSize) -> TangramPiece {
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        
        // Create temporary piece for transform calculation
        let tempPiece = TangramPiece(type: type, transform: .identity)
        
        // Use transform engine for consistent calculation
        let result = transformEngine.calculateTransform(
            for: tempPiece,
            operation: .place(center: canvasCenter, rotation: rotation * .pi / 180),
            connection: nil,
            otherPieces: [],
            canvasSize: canvasSize
        )
        
        // Create piece with calculated transform
        return TangramPiece(type: type, transform: result.transform)
    }
    
    /// Place subsequent piece with connections using transform engine
    func placeConnectedPiece(
        type: PieceType,
        rotation: Double,
        isFlipped: Bool = false,
        connections: [(canvasPoint: ConnectionPoint, piecePoint: ConnectionPoint)],
        existingPieces: [TangramPiece]
    ) -> TangramPiece? {
        guard !connections.isEmpty else { return nil }
        
        // Use TangramEditorCoordinateSystem for multi-point alignment
        // Pass flip state to alignment calculation
        let transform = TangramEditorCoordinateSystem.calculateAlignmentTransform(
            pieceType: type,
            baseRotation: rotation * .pi / 180,
            isFlipped: isFlipped,
            connections: connections.map { conn in
                (canvas: conn.canvasPoint, piece: conn.piecePoint)
            },
            existingPieces: existingPieces
        )
        
        guard var finalTransform = transform else {
            return nil
        }
        
        // For single edge-to-edge connections, search for a non-overlapping slide position
        // using the transform engine for consistency
        if connections.count == 1,
           case .edge(let canvasEdgeIndex) = connections[0].canvasPoint.type,
           case .edge(let pieceEdgeIndex) = connections[0].piecePoint.type {
            
            let canvasPieceId = connections[0].canvasPoint.pieceId
            if let canvasPiece = existingPieces.first(where: { $0.id == canvasPieceId }) {
                // Get the canvas edge for sliding
                let canvasVertices = TangramEditorCoordinateSystem.getWorldVertices(for: canvasPiece)
                let canvasEdges = TangramGeometry.edges(for: canvasPiece.type)
                
                if canvasEdgeIndex < canvasEdges.count {
                    let canvasEdgeDef = canvasEdges[canvasEdgeIndex]
                    let canvasEdgeStart = canvasVertices[canvasEdgeDef.startVertex]
                    let canvasEdgeEnd = canvasVertices[canvasEdgeDef.endVertex]
                    
                    // Search along the edge - try different positions from start to end
                    // Two-phase search: coarse then fine for better performance in tight spaces
                    
                    // Phase 1: Coarse search (10% increments)
                    let coarsePercentages: [Double] = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
                    var bestCoarsePercent: Double? = nil
                    var bestCoarseTransform: CGAffineTransform? = nil
                    var foundValidSlide = false
                    
                    for slidePercent in coarsePercentages {
                        // Calculate absolute position along the canvas edge
                        let targetPoint = CGPoint(
                            x: canvasEdgeStart.x + (canvasEdgeEnd.x - canvasEdgeStart.x) * CGFloat(slidePercent),
                            y: canvasEdgeStart.y + (canvasEdgeEnd.y - canvasEdgeStart.y) * CGFloat(slidePercent)
                        )
                        
                        // Calculate transform that places piece edge at this position
                        // maintaining the anti-parallel alignment from initial calculation
                        let testTransform = calculateEdgeAlignedTransform(
                            pieceType: type,
                            pieceEdgeIndex: pieceEdgeIndex,
                            targetEdgePoint: targetPoint,
                            baseTransform: finalTransform,
                            isFlipped: isFlipped
                        )
                        
                        // Test for overlaps with OTHER pieces (not the connected one)
                        let testPiece = TangramPiece(type: type, transform: testTransform)
                        let piecesToCheck = existingPieces.filter { $0.id != canvasPieceId }
                        
                        if !hasOverlapWithAnyPiece(testPiece, existingPieces: piecesToCheck) {
                            bestCoarsePercent = slidePercent
                            bestCoarseTransform = testTransform
                            break // Found a valid position in coarse search
                        }
                    }
                    
                    // Phase 2: Fine search around best coarse position
                    if let coarsePercent = bestCoarsePercent {
                        // Search ±5% around the best coarse position with 0.5% increments
                        let fineStart = max(0.0, coarsePercent - 0.05)
                        let fineEnd = min(1.0, coarsePercent + 0.05)
                        let fineStep = 0.005 // 0.5% increments
                        
                        var currentPercent = fineStart
                        while currentPercent <= fineEnd {
                            let targetPoint = CGPoint(
                                x: canvasEdgeStart.x + (canvasEdgeEnd.x - canvasEdgeStart.x) * CGFloat(currentPercent),
                                y: canvasEdgeStart.y + (canvasEdgeEnd.y - canvasEdgeStart.y) * CGFloat(currentPercent)
                            )
                            
                            let testTransform = calculateEdgeAlignedTransform(
                                pieceType: type,
                                pieceEdgeIndex: pieceEdgeIndex,
                                targetEdgePoint: targetPoint,
                                baseTransform: finalTransform,
                                isFlipped: isFlipped
                            )
                            
                            let testPiece = TangramPiece(type: type, transform: testTransform)
                            let piecesToCheck = existingPieces.filter { $0.id != canvasPieceId }
                            
                            if !hasOverlapWithAnyPiece(testPiece, existingPieces: piecesToCheck) {
                                finalTransform = testTransform
                                foundValidSlide = true
                                break
                            }
                            
                            currentPercent += fineStep
                        }
                    } else if let fallbackTransform = bestCoarseTransform {
                        // Use best coarse result if fine search didn't improve
                        finalTransform = fallbackTransform
                        foundValidSlide = true
                    }
                    
                    // Update foundValidSlide based on whether we found any valid position
                    foundValidSlide = foundValidSlide || (bestCoarsePercent != nil)
                    
                    // If no valid slide found, keep the original midpoint alignment
                    if !foundValidSlide {
                        print("Warning: No valid slide position found for edge-to-edge connection")
                    }
                }
            }
        }
        
        // Create piece with final transform (either original or slid)
        let piece = TangramPiece(type: type, transform: finalTransform)
        
        // Return the piece with the calculated alignment transform
        // Validation is handled by the coordinator and preview paths which
        // properly check overlaps and connection integrity with the correct context
        return piece
    }
    
    // MARK: - Helper Methods
    
    /// Calculate transform that aligns piece edge midpoint to a target point
    /// while maintaining the rotation from the base transform
    private func calculateEdgeAlignedTransform(
        pieceType: PieceType,
        pieceEdgeIndex: Int,
        targetEdgePoint: CGPoint,
        baseTransform: CGAffineTransform,
        isFlipped: Bool
    ) -> CGAffineTransform {
        // Create a temporary piece with base transform to get current edge position
        let tempPiece = TangramPiece(type: pieceType, transform: baseTransform)
        let pieceVertices = TangramEditorCoordinateSystem.getWorldVertices(for: tempPiece)
        let pieceEdges = TangramGeometry.edges(for: pieceType)
        
        guard pieceEdgeIndex < pieceEdges.count else {
            return baseTransform
        }
        
        // Get the piece edge that needs to align
        let edgeDef = pieceEdges[pieceEdgeIndex]
        let edgeStart = pieceVertices[edgeDef.startVertex]
        let edgeEnd = pieceVertices[edgeDef.endVertex]
        let currentEdgeMidpoint = CGPoint(
            x: (edgeStart.x + edgeEnd.x) / 2,
            y: (edgeStart.y + edgeEnd.y) / 2
        )
        
        // Calculate translation to move edge midpoint to target
        let dx = targetEdgePoint.x - currentEdgeMidpoint.x
        let dy = targetEdgePoint.y - currentEdgeMidpoint.y
        
        // Apply translation to base transform (preserves rotation and flip)
        var newTransform = baseTransform
        newTransform.tx += dx
        newTransform.ty += dy
        
        return newTransform
    }
    
    // MARK: - Overlap Detection Helpers
    
    /// Check if a piece overlaps with any existing pieces
    private func hasOverlapWithAnyPiece(_ piece: TangramPiece, existingPieces: [TangramPiece]) -> Bool {
        let pieceVertices = TangramEditorCoordinateSystem.getWorldVertices(for: piece)
        
        for existingPiece in existingPieces {
            let existingVertices = TangramEditorCoordinateSystem.getWorldVertices(for: existingPiece)
            
            // Use SAT (Separating Axis Theorem) for polygon overlap detection
            if polygonsOverlap(pieceVertices, existingVertices) {
                return true
            }
        }
        
        return false
    }
    
    /// Check if two polygons overlap using SAT
    private func polygonsOverlap(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Bool {
        // Check all edges of polygon 1
        for i in 0..<vertices1.count {
            let edge = CGPoint(
                x: vertices1[(i + 1) % vertices1.count].x - vertices1[i].x,
                y: vertices1[(i + 1) % vertices1.count].y - vertices1[i].y
            )
            let normal = CGPoint(x: -edge.y, y: edge.x)
            
            if !projectionsOverlap(vertices1, vertices2, axis: normal) {
                return false
            }
        }
        
        // Check all edges of polygon 2
        for i in 0..<vertices2.count {
            let edge = CGPoint(
                x: vertices2[(i + 1) % vertices2.count].x - vertices2[i].x,
                y: vertices2[(i + 1) % vertices2.count].y - vertices2[i].y
            )
            let normal = CGPoint(x: -edge.y, y: edge.x)
            
            if !projectionsOverlap(vertices1, vertices2, axis: normal) {
                return false
            }
        }
        
        return true
    }
    
    /// Check if projections of two polygons onto an axis overlap
    private func projectionsOverlap(_ vertices1: [CGPoint], _ vertices2: [CGPoint], axis: CGPoint) -> Bool {
        let (min1, max1) = projectPolygon(vertices1, onto: axis)
        let (min2, max2) = projectPolygon(vertices2, onto: axis)
        
        return !(max1 < min2 || max2 < min1)
    }
    
    /// Project a polygon onto an axis and return min/max values
    private func projectPolygon(_ vertices: [CGPoint], onto axis: CGPoint) -> (min: CGFloat, max: CGFloat) {
        guard !vertices.isEmpty else { return (0, 0) }
        
        let axisLength = sqrt(axis.x * axis.x + axis.y * axis.y)
        guard axisLength > 0 else { return (0, 0) }
        
        let normalizedAxis = CGPoint(x: axis.x / axisLength, y: axis.y / axisLength)
        
        var minProj = CGFloat.greatestFiniteMagnitude
        var maxProj = -CGFloat.greatestFiniteMagnitude
        
        for vertex in vertices {
            let projection = vertex.x * normalizedAxis.x + vertex.y * normalizedAxis.y
            minProj = min(minProj, projection)
            maxProj = max(maxProj, projection)
        }
        
        return (minProj, maxProj)
    }
    
    // MARK: - Connection Point Calculation
    
    struct ConnectionPoint: Equatable, Hashable {
        enum PointType: Equatable, Hashable {
            case vertex(index: Int)
            case edge(index: Int)
            
            var isVertex: Bool {
                if case .vertex = self { return true }
                return false
            }
            
            var isEdge: Bool {
                if case .edge = self { return true }
                return false
            }
        }
        let type: PointType
        let position: CGPoint
        let pieceId: String
        
        var id: String {
            switch type {
            case .vertex(let index):
                return "\(pieceId)_v\(index)"
            case .edge(let index):
                return "\(pieceId)_e\(index)"
            }
        }
    }
    
    /// Get connection points for a piece - delegates to coordinate system
    func getConnectionPoints(for piece: TangramPiece, scale: CGFloat = 1) -> [ConnectionPoint] {
        return TangramEditorCoordinateSystem.getConnectionPoints(for: piece)
    }
}