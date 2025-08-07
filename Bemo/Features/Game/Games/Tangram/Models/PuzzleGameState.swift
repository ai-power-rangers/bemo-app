//
//  PuzzleGameState.swift
//  Bemo
//
//  Game state management for Tangram puzzle gameplay
//

// WHAT: Manages the state of an active tangram puzzle game including placed pieces and progress
// ARCHITECTURE: Model in MVVM-S pattern, tracks game state for validation and rendering
// USAGE: Used by TangramGameViewModel to track puzzle solving progress

import Foundation
import CoreGraphics

struct PuzzleGameState: Codable {
    
    // MARK: - Properties
    
    /// The puzzle being solved (simplified for gameplay)
    let targetPuzzle: GamePuzzleData
    
    /// Pieces currently placed by the player (from CV)
    var placedPieces: [PlacedPiece] = []
    
    /// The current anchor piece ID (first piece or dynamically selected)
    var anchorPieceId: String?
    
    /// Correctly placed pieces (validated)
    var correctPieceIds: Set<String> = []
    
    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard !targetPuzzle.targetPieces.isEmpty else { return 0.0 }
        return Double(correctPieceIds.count) / Double(targetPuzzle.targetPieces.count)
    }
    
    /// Whether the puzzle is complete
    var isComplete: Bool {
        correctPieceIds.count == targetPuzzle.targetPieces.count && !targetPuzzle.targetPieces.isEmpty
    }
    
    /// Time spent on current puzzle
    var elapsedTime: TimeInterval = 0
    
    /// Number of hints used
    var hintsUsed: Int = 0
    
    /// Number of placement attempts
    var placementAttempts: Int = 0
    
    /// Last progress timestamp (for frustration detection)
    var lastProgressTime: Date = Date()
    
    // MARK: - Initialization
    
    init(targetPuzzle: GamePuzzleData) {
        self.targetPuzzle = targetPuzzle
    }
    
    // MARK: - State Management
    
    mutating func reset() {
        placedPieces.removeAll()
        anchorPieceId = nil
        correctPieceIds.removeAll()
        elapsedTime = 0
        hintsUsed = 0
        placementAttempts = 0
        lastProgressTime = Date()
    }
    
    mutating func addPlacedPiece(_ piece: PlacedPiece) {
        // Remove existing piece of same type if present
        let pieceType = piece.pieceType
        placedPieces.removeAll { $0.pieceType == pieceType }
        placedPieces.append(piece)
        placementAttempts += 1
        
        // Set as anchor if first piece
        if anchorPieceId == nil {
            anchorPieceId = piece.id
        }
    }
    
    mutating func updatePlacedPieces(_ pieces: [PlacedPiece]) {
        placedPieces = pieces
        placementAttempts += 1
        
        // Update anchor if needed
        if let currentAnchor = anchorPieceId,
           !pieces.contains(where: { $0.id == currentAnchor }) {
            selectNewAnchor()
        } else if anchorPieceId == nil && !pieces.isEmpty {
            selectNewAnchor()
        }
    }
    
    mutating func removePlacedPiece(id: String) {
        placedPieces.removeAll { $0.id == id }
        correctPieceIds.remove(id)
        
        // Update anchor if removed
        if anchorPieceId == id {
            selectNewAnchor()
        }
    }
    
    mutating func markPieceCorrect(_ pieceId: String) {
        correctPieceIds.insert(pieceId)
        lastProgressTime = Date()
    }
    
    mutating func markPieceIncorrect(_ pieceId: String) {
        correctPieceIds.remove(pieceId)
    }
    
    mutating func incrementHintCount() {
        hintsUsed += 1
    }
    
    // MARK: - Anchor Management
    
    private mutating func selectNewAnchor() {
        // Priority: largest correct piece > largest piece > first piece
        
        // Try to select from correct pieces first
        if let newAnchor = placedPieces
            .filter({ correctPieceIds.contains($0.id) })
            .max(by: { $0.area < $1.area }) {
            anchorPieceId = newAnchor.id
            return
        }
        
        // Otherwise select largest piece
        if let newAnchor = placedPieces
            .max(by: { $0.area < $1.area }) {
            anchorPieceId = newAnchor.id
            return
        }
        
        // No pieces left
        anchorPieceId = nil
    }
    
    // MARK: - Helpers
    
    func targetForPieceType(_ type: PieceType) -> GamePuzzleData.TargetPiece? {
        targetPuzzle.targetPieces.first { $0.pieceType == type.rawValue }
    }
    
    func remainingPieceTypes() -> [String] {
        let placedTypes = Set(placedPieces.compactMap { $0.pieceType.rawValue })
        return targetPuzzle.targetPieces
            .map { $0.pieceType }
            .filter { !placedTypes.contains($0) }
    }
    
    func timeSinceLastProgress() -> TimeInterval {
        Date().timeIntervalSince(lastProgressTime)
    }
}

