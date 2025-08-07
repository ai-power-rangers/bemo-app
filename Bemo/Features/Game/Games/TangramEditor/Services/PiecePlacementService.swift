//
//  PiecePlacementService.swift
//  Bemo
//
//  Service for managing tangram piece placement logic
//

// TODO: REFACTOR TO USE PieceTransformEngine
// This service currently has its own placement logic which can diverge from PieceTransformEngine.
// To ensure consistency between preview and actual placement, this should delegate to
// PieceTransformEngine.calculateTransform() for all transform calculations.
// This refactor will eliminate duplicate logic and ensure preview always matches placement.

import Foundation
import CoreGraphics

class PiecePlacementService {
    
    private let connectionService: ConnectionService
    
    init(connectionService: ConnectionService = ConnectionService()) {
        self.connectionService = connectionService
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
        
        // Recalculate local positions from the piece geometry
        var localPiecePositions: [CGPoint] = []
        for conn in connections {
            let localPos = TangramCoordinateSystem.getLocalConnectionPoint(
                for: type,
                connectionType: conn.piecePoint.type
            )
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
            
            // Check for edge-to-edge connection and auto-rotate
            var finalRotation = rotation
            if case .edge(let canvasEdgeIndex) = connections[0].canvasPoint.type,
               case .edge(let pieceEdgeIndex) = connections[0].piecePoint.type {
                
                print("DEBUG PPS: Single edge-to-edge connection, calculating auto-rotation")
                
                // Find the canvas piece that owns this edge
                if let canvasPieceId = connections[0].canvasPoint.pieceId.split(separator: "_").first,
                   let canvasPiece = existingPieces.first(where: { $0.id == String(canvasPieceId) }) {
                    
                    // Get edge directions in world space
                    let canvasVertices = TangramCoordinateSystem.getWorldVertices(for: canvasPiece)
                    let canvasEdges = TangramGeometry.edges(for: canvasPiece.type)
                    
                    if canvasEdgeIndex < canvasEdges.count {
                        let canvasEdge = canvasEdges[canvasEdgeIndex]
                        let canvasStart = canvasVertices[canvasEdge.startVertex]
                        let canvasEnd = canvasVertices[canvasEdge.endVertex]
                        let canvasEdgeAngle = atan2(canvasEnd.y - canvasStart.y, canvasEnd.x - canvasStart.x)
                        
                        // Get piece edge direction in local space
                        let pieceVertices = TangramGeometry.vertices(for: type)
                        let pieceEdges = TangramGeometry.edges(for: type)
                        
                        if pieceEdgeIndex < pieceEdges.count {
                            let pieceEdge = pieceEdges[pieceEdgeIndex]
                            let pieceStart = pieceVertices[pieceEdge.startVertex]
                            let pieceEnd = pieceVertices[pieceEdge.endVertex]
                            let pieceEdgeAngle = atan2(pieceEnd.y - pieceStart.y, pieceEnd.x - pieceStart.x)
                            
                            // Calculate rotation to make edges anti-parallel (facing opposite)
                            finalRotation = canvasEdgeAngle - pieceEdgeAngle + .pi
                            
                            print("DEBUG PPS: Auto-rotation calculated: \(finalRotation * 180 / .pi)°")
                        }
                    }
                }
            }
            
            // Apply rotation (either manual or auto-calculated)
            transform = CGAffineTransform.identity.rotated(by: finalRotation)
            let rotatedPiecePos = localPiecePos.applying(transform)
            print("DEBUG PPS: Rotated piece position: \(rotatedPiecePos)")
            
            // Calculate translation
            let dx = canvasPos.x - rotatedPiecePos.x
            let dy = canvasPos.y - rotatedPiecePos.y
            
            // Set translation directly in world space
            transform.tx = dx
            transform.ty = dy
            print("DEBUG PPS: Final transform: \(transform)")
            
        } else if connections.count >= 2 {
            // Multi-point connection - prioritize vertex-to-vertex connections for alignment
            // A vertex-to-vertex connection is more precise than edge-to-edge
            
            // Create array with indices to maintain correspondence with localPiecePositions
            let indexedConnections = connections.enumerated().map { (index: $0, connection: $1) }
            
            // Sort to prioritize vertex-to-vertex connections
            let sortedIndexedConnections = indexedConnections.sorted { (a, b) in
                // Check if each connection is vertex-to-vertex
                let aIsVertexToVertex: Bool = {
                    if case .vertex = a.connection.canvasPoint.type,
                       case .vertex = a.connection.piecePoint.type {
                        return true
                    }
                    return false
                }()
                
                let bIsVertexToVertex: Bool = {
                    if case .vertex = b.connection.canvasPoint.type,
                       case .vertex = b.connection.piecePoint.type {
                        return true
                    }
                    return false
                }()
                
                // Vertex-to-vertex connections come first
                if aIsVertexToVertex && !bIsVertexToVertex {
                    return true
                } else if !aIsVertexToVertex && bIsVertexToVertex {
                    return false
                } else {
                    // Keep original order for same types
                    return a.index < b.index
                }
            }
            
            // Extract sorted connections and their corresponding local positions
            let sortedConnections = sortedIndexedConnections.map { $0.connection }
            let sortedLocalPositions = sortedIndexedConnections.map { localPiecePositions[$0.index] }
            
            // Use only the first point for placement (like the old implementation)
            // This ensures at least one connection is perfect
            let canvasPos = sortedConnections[0].canvasPoint.position
            let localPiecePos = sortedLocalPositions[0]
            
            // Check if we need auto-rotation for edge-to-edge connection
            var finalRotation = rotation
            if case .edge(let canvasEdgeIndex) = sortedConnections[0].canvasPoint.type,
               case .edge(let pieceEdgeIndex) = sortedConnections[0].piecePoint.type {
                
                // Auto-rotate for edge-to-edge alignment
                print("DEBUG PPS: Detecting edge-to-edge connection, calculating auto-rotation")
                
                // Find the canvas piece that owns this edge
                if let canvasPieceId = sortedConnections[0].canvasPoint.pieceId.split(separator: "_").first,
                   let canvasPiece = existingPieces.first(where: { $0.id == String(canvasPieceId) }) {
                    
                    // Get edge directions in world space
                    let canvasVertices = TangramCoordinateSystem.getWorldVertices(for: canvasPiece)
                    let canvasEdges = TangramGeometry.edges(for: canvasPiece.type)
                    
                    if canvasEdgeIndex < canvasEdges.count {
                        let canvasEdge = canvasEdges[canvasEdgeIndex]
                        let canvasStart = canvasVertices[canvasEdge.startVertex]
                        let canvasEnd = canvasVertices[canvasEdge.endVertex]
                        let canvasEdgeAngle = atan2(canvasEnd.y - canvasStart.y, canvasEnd.x - canvasStart.x)
                        
                        // Get piece edge direction in local space
                        let pieceVertices = TangramGeometry.vertices(for: type)
                        let pieceEdges = TangramGeometry.edges(for: type)
                        
                        if pieceEdgeIndex < pieceEdges.count {
                            let pieceEdge = pieceEdges[pieceEdgeIndex]
                            let pieceStart = pieceVertices[pieceEdge.startVertex]
                            let pieceEnd = pieceVertices[pieceEdge.endVertex]
                            let pieceEdgeAngle = atan2(pieceEnd.y - pieceStart.y, pieceEnd.x - pieceStart.x)
                            
                            // Calculate rotation to make edges anti-parallel (facing opposite)
                            finalRotation = canvasEdgeAngle - pieceEdgeAngle + .pi
                            
                            print("DEBUG PPS: Canvas edge angle: \(canvasEdgeAngle * 180 / .pi)°")
                            print("DEBUG PPS: Piece edge angle: \(pieceEdgeAngle * 180 / .pi)°")
                            print("DEBUG PPS: Auto-rotation: \(finalRotation * 180 / .pi)°")
                        }
                    }
                }
            }
            
            // Log which connection type we're using for primary alignment
            let primaryConnectionType: String = {
                if case .vertex = sortedConnections[0].canvasPoint.type,
                   case .vertex = sortedConnections[0].piecePoint.type {
                    return "vertex-to-vertex"
                } else if case .edge = sortedConnections[0].canvasPoint.type,
                          case .edge = sortedConnections[0].piecePoint.type {
                    return "edge-to-edge (auto-rotated)"
                } else {
                    return "mixed"
                }
            }()
            
            print("DEBUG PPS: Multi-point connection - using \(primaryConnectionType) for alignment")
            print("DEBUG PPS: Canvas position: \(canvasPos)")
            print("DEBUG PPS: Local piece position: \(localPiecePos)")
            
            // Apply rotation (either manual or auto-calculated)
            transform = CGAffineTransform.identity.rotated(by: finalRotation)
            let rotatedPiecePos = localPiecePos.applying(transform)
            
            print("DEBUG PPS: Rotated piece position: \(rotatedPiecePos)")
            
            // Calculate translation to align the first point perfectly
            let dx = canvasPos.x - rotatedPiecePos.x
            let dy = canvasPos.y - rotatedPiecePos.y
            
            // Set translation directly in world space
            transform.tx = dx
            transform.ty = dy
            print("DEBUG PPS: Final transform: \(transform)")
        } else {
            print("DEBUG PPS: ERROR - No connections provided")
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