//
//  PiecePlacementService.swift
//  Bemo
//
//  Service for managing tangram piece placement logic
//

import Foundation
import CoreGraphics

class PiecePlacementService {
    
    private let geometryService: GeometryService
    private let connectionService: ConnectionService
    private let validationService: ValidationService
    private let constraintManager: ConstraintManager
    
    init(geometryService: GeometryService = GeometryService(),
         connectionService: ConnectionService = ConnectionService(),
         validationService: ValidationService = ValidationService(),
         constraintManager: ConstraintManager = ConstraintManager()) {
        self.geometryService = geometryService
        self.connectionService = connectionService
        self.validationService = validationService
        self.constraintManager = constraintManager
    }
    
    // MARK: - Piece Placement
    
    /// Place first piece at center of canvas
    func placeFirstPiece(type: PieceType, rotation: Double, canvasSize: CGSize) -> TangramPiece {
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        
        // Get the piece's bounding box to find its center
        let vertices = TangramGeometry.vertices(for: type)
        let scaledVertices = vertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale)
        }
        
        // Find the center of the piece geometry
        let minX = scaledVertices.map { $0.x }.min() ?? 0
        let maxX = scaledVertices.map { $0.x }.max() ?? 0
        let minY = scaledVertices.map { $0.y }.min() ?? 0
        let maxY = scaledVertices.map { $0.y }.max() ?? 0
        let pieceCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        
        // Create transform that:
        // 1. Translates piece center to origin
        // 2. Rotates around origin
        // 3. Translates to canvas center
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: centerX, y: centerY)
        transform = transform.rotated(by: rotation)
        transform = transform.translatedBy(x: -pieceCenter.x, y: -pieceCenter.y)
        
        let piece = TangramPiece(type: type, transform: transform)
        print("DEBUG PPS: Piece center: \(pieceCenter)")
        print("DEBUG PPS: Canvas center: (\(centerX), \(centerY))")
        print("DEBUG PPS: Final piece transform: \(transform)")
        print("DEBUG PPS: Final piece bounds check:")
        let transformedVertices = scaledVertices.map { $0.applying(transform) }
        print("DEBUG PPS: Transformed vertices: \(transformedVertices)")
        
        return piece
    }
    
    /// Place subsequent piece with connections
    func placeConnectedPiece(
        type: PieceType,
        rotation: Double,
        connections: [(canvasPoint: ConnectionPoint, piecePoint: ConnectionPoint)],
        existingPieces: [TangramPiece]
    ) -> TangramPiece? {
        guard !connections.isEmpty else { return nil }
        
        // The piece connection points have positions but they're in screen space with identity transform
        // We need to use the actual local positions based on the piece geometry
        print("DEBUG PPS: Incoming piece point positions: \(connections.map { $0.piecePoint.position })")
        
        // Recalculate local positions from the piece geometry
        let vertices = TangramGeometry.vertices(for: type)
        let edges = TangramGeometry.edges(for: type)
        
        var localPiecePositions: [CGPoint] = []
        for conn in connections {
            let localPos: CGPoint
            switch conn.piecePoint.type {
            case .vertex(let index):
                // Use scaled vertex position
                localPos = CGPoint(x: vertices[index].x * TangramConstants.visualScale,
                                 y: vertices[index].y * TangramConstants.visualScale)
            case .edge(let index):
                // Calculate edge midpoint and scale
                let edge = edges[index]
                let start = vertices[edge.startVertex]
                let end = vertices[edge.endVertex]
                let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                localPos = CGPoint(x: midpoint.x * TangramConstants.visualScale,
                                 y: midpoint.y * TangramConstants.visualScale)
            }
            localPiecePositions.append(localPos)
            print("DEBUG PPS: Calculated local position for \(conn.piecePoint.type): \(localPos)")
        }
        
        // Start with base rotation
        var transform = CGAffineTransform.identity.rotated(by: rotation)
        
        // Calculate alignment based on connection points
        if connections.count == 1 {
            // Single point connection
            let canvasPos = connections[0].canvasPoint.position
            let localPiecePos = localPiecePositions[0]
            
            print("DEBUG PPS: Single point connection - canvas: \(canvasPos), local: \(localPiecePos)")
            
            // Apply rotation to local position
            let rotatedPiecePos = localPiecePos.applying(transform)
            print("DEBUG PPS: Rotated piece position: \(rotatedPiecePos)")
            
            // Calculate translation to align points
            let dx = canvasPos.x - rotatedPiecePos.x
            let dy = canvasPos.y - rotatedPiecePos.y
            print("DEBUG PPS: Translation needed: dx=\(dx), dy=\(dy)")
            
            // CRITICAL: Set translation directly in world space, don't use translatedBy
            transform.tx = dx  
            transform.ty = dy
            print("DEBUG PPS: Final transform: \(transform)")
            
        } else if connections.count >= 2 {
            // Multi-point connection - prioritize vertex connections for alignment
            // Sort connections to put vertex-to-vertex connections first
            let sortedConnections = connections.sorted { (a, b) in
                // Prioritize vertex connections over edge connections
                switch (a.piecePoint.type, b.piecePoint.type) {
                case (.vertex, .edge): return true
                case (.edge, .vertex): return false
                default: return false  // Keep original order for same types
                }
            }
            
            let sortedLocalPositions = sortedConnections.map { conn in
                connections.firstIndex(where: { $0.piecePoint.id == conn.piecePoint.id })
            }.compactMap { index in
                index.map { localPiecePositions[$0] }
            }
            
            // Use only the first point for placement (like the old implementation)
            // This ensures at least one connection is perfect
            let canvasPos = sortedConnections[0].canvasPoint.position
            let localPiecePos = sortedLocalPositions[0]
            
            print("DEBUG PPS: Multi-point connection - using first point for alignment")
            print("DEBUG PPS: Canvas position: \(canvasPos)")
            print("DEBUG PPS: Local piece position: \(localPiecePos)")
            
            // Apply rotation
            transform = CGAffineTransform.identity.rotated(by: rotation)
            let rotatedPiecePos = localPiecePos.applying(transform)
            
            print("DEBUG PPS: Rotated piece position: \(rotatedPiecePos)")
            
            // Calculate translation to align the first point perfectly
            let dx = canvasPos.x - rotatedPiecePos.x
            let dy = canvasPos.y - rotatedPiecePos.y
            
            print("DEBUG PPS: Translation needed: dx=\(dx), dy=\(dy)")
            
            // Set translation directly in world space
            transform.tx = dx
            transform.ty = dy
            
            // Log how well other points align
            for i in 1..<min(sortedConnections.count, sortedLocalPositions.count) {
                let otherCanvasPos = sortedConnections[i].canvasPoint.position
                let otherLocalPos = sortedLocalPositions[i]
                let rotatedOtherPos = otherLocalPos.applying(transform)
                let error = CGPoint(x: otherCanvasPos.x - rotatedOtherPos.x, 
                                   y: otherCanvasPos.y - rotatedOtherPos.y)
                print("DEBUG PPS: Point \(i) alignment - canvas=\(otherCanvasPos), piece=\(rotatedOtherPos), error=\(error)")
            }
            
            print("DEBUG PPS: Final transform: \(transform)")
        }
        
        // Check for NaN or infinite values in the final transform
        if !transform.a.isFinite || !transform.b.isFinite || !transform.c.isFinite || 
           !transform.d.isFinite || !transform.tx.isFinite || !transform.ty.isFinite {
            print("DEBUG PPS: ERROR - Transform contains non-finite values: \(transform)")
            return nil
        }
        
        print("DEBUG PPS: Creating piece with final transform: \(transform)")
        return TangramPiece(type: type, transform: transform)
    }
    
    // MARK: - Connection Point Calculation
    
    struct ConnectionPoint: Equatable, Hashable {
        enum PointType: Equatable, Hashable {
            case vertex(index: Int)
            case edge(index: Int)
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
    
    func getConnectionPoints(for piece: TangramPiece, scale: CGFloat = 1) -> [ConnectionPoint] {
        var points: [ConnectionPoint] = []
        let vertices = TangramGeometry.vertices(for: piece.type)
        
        // Scale vertices by visualScale BEFORE applying transform (matching ConnectionService pattern)
        let scaledVertices = vertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale) 
        }
        let transformedVertices = geometryService.transformVertices(scaledVertices, with: piece.transform)
        
        // Add vertex points (no additional scaling needed - already in screen coordinates)
        for (index, vertex) in transformedVertices.enumerated() {
            points.append(ConnectionPoint(
                type: .vertex(index: index),
                position: vertex,
                pieceId: piece.id
            ))
        }
        
        // Add edge midpoints (no additional scaling needed)
        for i in 0..<transformedVertices.count {
            let start = transformedVertices[i]
            let end = transformedVertices[(i + 1) % transformedVertices.count]
            let midpoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            points.append(ConnectionPoint(
                type: .edge(index: i),
                position: midpoint,
                pieceId: piece.id
            ))
        }
        
        return points
    }
    
    // MARK: - Transform Calculations
    
    func calculateConstrainedTransform(
        for pieceId: String,
        targetTransform: CGAffineTransform,
        constraints: [Constraint],
        pieces: [TangramPiece]
    ) -> CGAffineTransform {
        // If no constraints, return target as-is
        guard !constraints.isEmpty else { return targetTransform }
        
        // PiecePlacementService doesn't actually use constraints in the current architecture
        // Constraints are handled by ConnectionService for existing connections
        // This method appears to be unused - returning targetTransform unchanged
        // TODO: Either remove this method or properly integrate with ConnectionService
        return targetTransform
    }
}