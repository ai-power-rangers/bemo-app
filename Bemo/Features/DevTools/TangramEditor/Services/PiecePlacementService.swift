//
//  PiecePlacementService.swift
//  Bemo
//
//  Service for managing tangram piece placement logic
//

// WHAT: Coordinates piece placement by delegating transform calculations to PieceTransformEngine
// ARCHITECTURE: Service layer in MVVM-S, ensures consistency between preview and placement
// USAGE: Used by ViewModels and Coordinator for piece placement operations
//
// RESPONSIBILITIES:
// - Calculate initial piece placement with connections
// - Find valid snap positions for edge-to-edge connections
// - Delegate all transform calculations to PieceTransformEngine
// - Delegate all overlap detection to PieceTransformEngine
//
// NOT RESPONSIBLE FOR:
// - Transform calculations (use PieceTransformEngine)
// - Overlap detection algorithms (use PieceTransformEngine)
// - Connection validation (use ConnectionService)
// - State management (handled by ViewModel)

import Foundation
import CoreGraphics
import OSLog

@MainActor
class PiecePlacementService {
    
    private let transformEngine: PieceTransformEngine
    private let connectionService: ConnectionService
    private let validationService: TangramValidationService
    
    init(transformEngine: PieceTransformEngine,
         connectionService: ConnectionService,
         validationService: TangramValidationService) {
        self.transformEngine = transformEngine
        self.connectionService = connectionService
        self.validationService = validationService
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
        guard !connections.isEmpty else {
            Logger.tangramPlacement.error("[PlacementService] No connections provided")
            return nil
        }
        
        Logger.tangramPlacement.info("[PlacementService] Starting placement: piece=\(type.rawValue) connections=\(connections.count) rotation=\(String(format: "%.0f", rotation * 180 / .pi))° flipped=\(isFlipped)")
        
        // Log connection details
        for (index, conn) in connections.enumerated() {
            let canvasType = conn.canvasPoint.type
            let pieceType = conn.piecePoint.type
            Logger.tangramPlacement.debug("[PlacementService] Connection \(index): canvas=\(String(describing: canvasType)) -> piece=\(String(describing: pieceType))")
        }
        
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
            Logger.tangramPlacement.error("[PlacementService] Failed to calculate alignment transform")
            return nil
        }
        
        Logger.tangramPlacement.info("[PlacementService] Initial transform calculated")
        
        // For single edge-to-edge connections, find best snap position (0%, 25%, 50%, 75%, 100%)
        // that doesn't cause overlaps
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
                    
                    // Get piece edge length to determine valid slide range
                    let tempPiece = TangramPiece(type: type, transform: finalTransform)
                    let pieceVertices = TangramEditorCoordinateSystem.getWorldVertices(for: tempPiece)
                    let pieceEdges = TangramGeometry.edges(for: type)
                    
                    if pieceEdgeIndex < pieceEdges.count {
                        let pieceEdgeDef = pieceEdges[pieceEdgeIndex]
                        let pieceEdgeStart = pieceVertices[pieceEdgeDef.startVertex]
                        let pieceEdgeEnd = pieceVertices[pieceEdgeDef.endVertex]
                        let pieceEdgeLength = sqrt(pow(pieceEdgeEnd.x - pieceEdgeStart.x, 2) + 
                                                  pow(pieceEdgeEnd.y - pieceEdgeStart.y, 2))
                        
                        let canvasEdgeLength = sqrt(pow(canvasEdgeEnd.x - canvasEdgeStart.x, 2) + 
                                                   pow(canvasEdgeEnd.y - canvasEdgeStart.y, 2))
                        
                        // Calculate valid range: piece can slide from 0 to (canvas_length - piece_length)
                        // This ensures the piece edge stays fully on the canvas edge
                        let maxSlidePercent = max(0, (canvasEdgeLength - pieceEdgeLength) / canvasEdgeLength)
                        
                        // Define snap positions as percentages of the valid slide range
                        var snapPercentages: [Double] = []
                        if maxSlidePercent <= 0 {
                            // Edges are same length - only center position is valid
                            snapPercentages = [0.5]
                        } else {
                            // Use standard snap positions from constants, scaled to valid range
                            snapPercentages = TangramConstants.slideSnapPercentages.map { $0 * maxSlidePercent }
                            
                            // For longer piece edge on shorter canvas edge, adjust to center
                            if pieceEdgeLength > canvasEdgeLength {
                                // Center the longer edge on the shorter edge
                                let centerOffset = (pieceEdgeLength - canvasEdgeLength) / (2 * canvasEdgeLength)
                                snapPercentages = [0.5 - centerOffset]
                            }
                        }
                        
                        // Try each snap position, starting with center (most likely to fit)
                        let orderedSnapPositions = snapPercentages.sorted { abs($0 - 0.5) < abs($1 - 0.5) }
                        
                        for snapPercent in orderedSnapPositions {
                            // Calculate position along the canvas edge
                            let targetPoint = CGPoint(
                                x: canvasEdgeStart.x + (canvasEdgeEnd.x - canvasEdgeStart.x) * CGFloat(snapPercent),
                                y: canvasEdgeStart.y + (canvasEdgeEnd.y - canvasEdgeStart.y) * CGFloat(snapPercent)
                            )
                            
                            // Calculate transform for this snap position
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
                                finalTransform = testTransform
                                break // Use first valid snap position
                            }
                        }
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
        // Use unified validation service for overlap detection
        let context = TangramValidationService.ValidationContext(
            connection: nil, // No connection context for simple overlap check
            otherPieces: existingPieces,
            canvasSize: CGSize(width: 800, height: 600),
            allowOutOfBounds: true
        )
        
        let result = validationService.validatePlacement(piece, context: context)
        
        // Check specifically for overlap violations
        for violation in result.violations {
            if case .overlap = violation.type {
                return true
            }
        }
        return false
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