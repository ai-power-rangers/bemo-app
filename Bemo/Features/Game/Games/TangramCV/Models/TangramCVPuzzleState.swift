//
//  TangramCVPuzzleState.swift
//  Bemo
//
//  Single source of truth for TangramCV game state
//

// WHAT: Encapsulates all mutable state for the TangramCV game
// ARCHITECTURE: State object in MVVM-S pattern, owned by Scene
// USAGE: Scene updates state, ViewModel observes via delegate

import Foundation
import SpriteKit

/// Encapsulates all game state for TangramCV
class TangramCVPuzzleState {
    
    // MARK: - Puzzle Data
    
    var currentPuzzle: GamePuzzleData?
    var pendingPuzzle: GamePuzzleData?  // Puzzle to load when scene is ready
    
    // MARK: - Piece Collections
    
    /// All pieces available in storage zone (not yet placed)
    var availablePieces: [String: CVPuzzlePieceNode] = [:]
    
    /// Pieces that have been placed in assembly zone
    var assembledPieces: [CVPuzzlePieceNode] = []
    
    /// Current anchor piece for CV coordinate system
    var anchorPiece: CVPuzzlePieceNode?
    
    /// Currently selected piece being dragged
    var selectedPiece: CVPuzzlePieceNode?
    
    // MARK: - Tracking State
    
    /// Last known zone for selected piece (for transition detection)
    var lastZoneForSelectedPiece: Zone = .storage
    
    /// Tracks piece stability over frames for anchor promotion
    var pieceStabilityFrames: [String: Int] = [:]
    
    /// Completed piece types
    var completedPieces: Set<String> = []
    
    /// Validation results per piece type
    var validationResults: [TangramPieceType: Bool] = [:]
    
    // MARK: - CV Output
    
    /// Latest CV stream data
    var cvOutputStream: [String: Any] = [:]
    
    /// Last time CV data was emitted
    var lastCVEmissionTime: TimeInterval = 0
    
    // MARK: - Methods
    
    /// Complete reset of all state
    func reset() {
        currentPuzzle = nil
        pendingPuzzle = nil
        
        // Remove all sprite nodes from their parents before clearing dictionary
        for (_, piece) in availablePieces {
            piece.removeFromParent()
        }
        availablePieces.removeAll()
        
        // Remove assembled pieces from parents
        for piece in assembledPieces {
            piece.removeFromParent()
        }
        assembledPieces.removeAll()
        
        // Clear anchor and selected references
        anchorPiece?.removeFromParent()
        anchorPiece = nil
        selectedPiece = nil
        
        lastZoneForSelectedPiece = .storage
        pieceStabilityFrames.removeAll()
        completedPieces.removeAll()
        validationResults.removeAll()
        cvOutputStream.removeAll()
        lastCVEmissionTime = 0
    }
    
    /// Load a new puzzle (resets existing state)
    func loadPuzzle(_ puzzle: GamePuzzleData) {
        reset()
        currentPuzzle = puzzle
    }
    
    /// Add a piece to the assembled collection
    func addAssembledPiece(_ piece: CVPuzzlePieceNode) {
        if !assembledPieces.contains(where: { $0.id == piece.id }) {
            assembledPieces.append(piece)
        }
    }
    
    /// Remove a piece from the assembled collection
    func removeAssembledPiece(_ piece: CVPuzzlePieceNode) {
        assembledPieces.removeAll { $0.id == piece.id }
    }
    
    /// Clear all assembled pieces (for fresh CV update)
    func clearAssembledPieces() {
        assembledPieces.removeAll()
    }
    
    /// Set a new anchor piece (clears previous anchor)
    func setAnchor(_ piece: CVPuzzlePieceNode?) {
        anchorPiece?.isAnchor = false
        anchorPiece = piece
        piece?.isAnchor = true
    }
    
    /// Track piece stability
    func updatePieceStability(_ piece: CVPuzzlePieceNode, stable: Bool) {
        guard let id = piece.id else { return }
        
        if stable {
            pieceStabilityFrames[id, default: 0] += 1
        } else {
            pieceStabilityFrames[id] = 0
        }
    }
    
    /// Check if a piece has been stable for required frames
    func isPieceStable(_ piece: CVPuzzlePieceNode, requiredFrames: Int) -> Bool {
        guard let id = piece.id else { return false }
        return pieceStabilityFrames[id, default: 0] >= requiredFrames
    }
}

// MARK: - Zone Enum

enum Zone {
    case reference
    case assembly
    case storage
    case unknown
}