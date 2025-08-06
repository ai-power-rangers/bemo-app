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
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        
        // Use centralized coordinate system for transform creation
        let transform = TangramCoordinateSystem.createCenteringTransform(
            type: type,
            targetCenter: canvasCenter,
            rotation: rotation
        )
        
        let piece = TangramPiece(type: type, transform: transform)
        
        print("DEBUG PPS: Canvas center: \(canvasCenter)")
        print("DEBUG PPS: Final piece transform: \(transform)")
        print("DEBUG PPS: Final piece bounds check:")
        let transformedVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
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
        
        // Recalculate local positions from the piece geometry using centralized system
        var localPiecePositions: [CGPoint] = []
        for conn in connections {
            let localPos = TangramCoordinateSystem.getLocalConnectionPoint(
                for: type,
                connectionType: conn.piecePoint.type
            )
            localPiecePositions.append(localPos)
            print("DEBUG PPS: Calculated local position for \(conn.piecePoint.type): \(localPos)")
        }
        
        // Use centralized coordinate system for alignment
        let connectionPairs = connections.enumerated().map { index, conn in
            (canvas: conn.canvasPoint, piece: conn.piecePoint)
        }
        
        // Calculate transform using new multi-point alignment with auto-rotation for edges
        guard let transform = TangramCoordinateSystem.calculateAlignmentTransform(
            pieceType: type,
            baseRotation: rotation,
            connections: connectionPairs,
            existingPieces: existingPieces
        ) else {
            print("DEBUG PPS: Failed to calculate alignment transform")
            return nil
        }
        
        print("DEBUG PPS: Successfully calculated transform for \(connections.count) connection(s)")
        print("DEBUG PPS: Final transform: \(transform)")
        
        // Log connection satisfaction for debugging
        if connections.count >= 2 {
            // Verify that all connection points are satisfied
            for (index, conn) in connections.enumerated() {
                let localPos = localPiecePositions[index]
                let transformedPos = localPos.applying(transform)
                let canvasPos = conn.canvasPoint.position
                let error = sqrt(pow(canvasPos.x - transformedPos.x, 2) + pow(canvasPos.y - transformedPos.y, 2))
                
                let connectionType = switch (conn.canvasPoint.type, conn.piecePoint.type) {
                case (.vertex, .vertex): "vertex-to-vertex"
                case (.edge, .edge): "edge-to-edge"
                case (.vertex, .edge): "vertex-to-edge"
                case (.edge, .vertex): "edge-to-vertex"
                }
                
                print("DEBUG PPS: Connection \(index) (\(connectionType)) - error: \(error)")
            }
        }
        
        // Check for valid transform using centralized system
        if !TangramCoordinateSystem.isValidTransform(transform) {
            print("DEBUG PPS: ERROR - Transform is invalid: \(transform)")
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
    
    func getConnectionPoints(for piece: TangramPiece, scale: CGFloat = 1) -> [ConnectionPoint] {
        // Use centralized coordinate system for connection points
        return TangramCoordinateSystem.getConnectionPoints(for: piece)
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