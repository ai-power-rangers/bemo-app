//
//  TangramCVService.swift
//  Bemo
//
//  Business logic service for TangramCV game
//

// WHAT: Handles CV generation, anchor management, and validation logic
// ARCHITECTURE: Service layer in MVVM-S pattern
// USAGE: Called by ViewModel to process game logic

import Foundation
import CoreGraphics

class TangramCVService {
    
    // MARK: - Properties
    
    private let cvFrequency: Double = TangramCVConstants.cvStreamFrequency
    private let stabilityThreshold = 5
    
    // MARK: - Anchor Management
    
    /// Determine the best anchor piece from assembled pieces
    func selectBestAnchor(from pieces: [CVPuzzlePieceNode], 
                          stableFrames: [String: Int],
                          isCVMode: Bool) -> CVPuzzlePieceNode? {
        guard !pieces.isEmpty else { return nil }
        
        if isCVMode {
            // CV mode: Prefer stable, large pieces
            return pieces
                .filter { piece in
                    guard let id = piece.id else { return false }
                    return stableFrames[id, default: 0] >= stabilityThreshold
                }
                .max { p1, p2 in
                    getPieceArea(p1.pieceType) < getPieceArea(p2.pieceType)
                }
                ?? pieces.first
        } else {
            // Touch mode: Use first (oldest) piece
            return pieces.first
        }
    }
    
    /// Check if anchor should be promoted
    func shouldPromoteAnchor(currentAnchor: CVPuzzlePieceNode?, 
                            assembledPieces: [CVPuzzlePieceNode]) -> Bool {
        // Promote if no anchor and pieces are assembled
        if currentAnchor == nil && !assembledPieces.isEmpty {
            return true
        }
        
        // Promote if current anchor is no longer assembled
        if let anchor = currentAnchor,
           !assembledPieces.contains(where: { $0.id == anchor.id }) {
            return true
        }
        
        return false
    }
    
    // MARK: - CV Generation
    
    /// Generate CV output stream data
    func generateCVOutput(state: TangramCVPuzzleState) -> [String: Any] {
        let timestamp = Date().timeIntervalSince1970
        
        // Build objects array
        let objects = state.assembledPieces.map { piece in
            generateCVObject(for: piece, relativeTo: state.anchorPiece)
        }
        
        return [
            "timestamp": timestamp,
            "anchor_id": state.anchorPiece?.id ?? "none",
            "objects": objects
        ]
    }
    
    private func generateCVObject(for piece: CVPuzzlePieceNode, 
                                  relativeTo anchor: CVPuzzlePieceNode?) -> [String: Any] {
        var object: [String: Any] = [
            "id": piece.id ?? UUID().uuidString,
            "type": piece.pieceType?.rawValue ?? "unknown",
            "confidence": 0.95
        ]
        
        if let anchor = anchor {
            // Calculate relative position to anchor
            let relativeX = piece.position.x - anchor.position.x
            let relativeY = piece.position.y - anchor.position.y
            let relativeRotation = piece.zRotation - anchor.zRotation
            
            object["relative_position"] = [
                "x": relativeX / TangramCVConstants.visualScale,
                "y": relativeY / TangramCVConstants.visualScale,
                "rotation": relativeRotation
            ]
        } else {
            // Absolute position
            object["absolute_position"] = [
                "x": piece.position.x / TangramCVConstants.visualScale,
                "y": piece.position.y / TangramCVConstants.visualScale,
                "rotation": piece.zRotation
            ]
        }
        
        return object
    }
    
    // MARK: - Validation
    
    /// Validate piece placement against target
    func validatePiecePlacement(_ piece: CVPuzzlePieceNode,
                               at position: CGPoint,
                               puzzle: GamePuzzleData?) -> Bool {
        guard let puzzle = puzzle,
              let pieceType = piece.pieceType else { return false }
        
        // Find target for this piece type
        guard let target = puzzle.targetPieces.first(where: { 
            $0.pieceType == pieceType 
        }) else { return false }
        
        // For CV mode, we don't snap - just track if it's close
        let tolerance = TangramCVConstants.visualScale * 0.3 // 30% tolerance
        
        // Get target position (would need proper transformation)
        // This is simplified - real implementation would transform target coordinates
        let targetX = target.transform.tx * TangramCVConstants.visualScale
        let targetY = target.transform.ty * TangramCVConstants.visualScale
        
        let distance = hypot(position.x - targetX, position.y - targetY)
        return distance < tolerance
    }
    
    /// Check if puzzle is complete
    func isPuzzleComplete(state: TangramCVPuzzleState) -> Bool {
        guard let puzzle = state.currentPuzzle else { return false }
        
        // All target pieces must be validated
        return puzzle.targetPieces.allSatisfy { target in
            state.validationResults[target.pieceType] == true
        }
    }
    
    // MARK: - Helpers
    
    private func getPieceArea(_ type: TangramPieceType?) -> CGFloat {
        guard let type = type else { return 0 }
        
        // Approximate relative areas
        switch type {
        case .largeTriangle1, .largeTriangle2:
            return 4.0
        case .mediumTriangle:
            return 2.0
        case .smallTriangle1, .smallTriangle2:
            return 1.0
        case .square:
            return 2.0
        case .parallelogram:
            return 2.0
        }
    }
}