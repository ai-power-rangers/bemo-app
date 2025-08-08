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
        
        guard let finalTransform = transform else {
            return nil
        }
        
        // Create piece with final transform for validation
        let piece = TangramPiece(type: type, transform: finalTransform)
        
        // Use transform engine to validate placement
        let validationResult = transformEngine.calculateTransform(
            for: piece,
            operation: .place(center: CGPoint.zero, rotation: 0),
            connection: nil,
            otherPieces: existingPieces,
            canvasSize: CGSize(width: 1000, height: 1000) // Use large canvas for validation
        )
        
        if !validationResult.isValid {
            return nil
        }
        
        return piece
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