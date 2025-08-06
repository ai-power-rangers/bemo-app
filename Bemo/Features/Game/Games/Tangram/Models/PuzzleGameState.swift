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
    
    /// The puzzle being solved
    let targetPuzzle: TangramPuzzle
    
    /// Pieces currently placed by the player (from CV)
    var placedPieces: [PlacedPiece] = []
    
    /// The current anchor piece ID (first piece or dynamically selected)
    var anchorPieceId: String?
    
    /// Correctly placed pieces (validated)
    var correctPieceIds: Set<String> = []
    
    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard !targetPuzzle.pieces.isEmpty else { return 0.0 }
        return Double(correctPieceIds.count) / Double(targetPuzzle.pieces.count)
    }
    
    /// Whether the puzzle is complete
    var isComplete: Bool {
        correctPieceIds.count == targetPuzzle.pieces.count && !targetPuzzle.pieces.isEmpty
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
    
    init(targetPuzzle: TangramPuzzle) {
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
        placedPieces.removeAll { $0.type == piece.type }
        placedPieces.append(piece)
        placementAttempts += 1
        
        // Set as anchor if first piece
        if anchorPieceId == nil {
            anchorPieceId = piece.id
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
            .max(by: { $0.type.area < $1.type.area }) {
            anchorPieceId = newAnchor.id
            return
        }
        
        // Otherwise select largest piece
        if let newAnchor = placedPieces
            .max(by: { $0.type.area < $1.type.area }) {
            anchorPieceId = newAnchor.id
            return
        }
        
        // No pieces left
        anchorPieceId = nil
    }
    
    // MARK: - Helpers
    
    func pieceInTargetPuzzle(type: PieceType) -> TangramPiece? {
        targetPuzzle.pieces.first { $0.type == type }
    }
    
    func remainingPieceTypes() -> [PieceType] {
        let placedTypes = Set(placedPieces.map { $0.type })
        return targetPuzzle.pieces
            .map { $0.type }
            .filter { !placedTypes.contains($0) }
    }
    
    func timeSinceLastProgress() -> TimeInterval {
        Date().timeIntervalSince(lastProgressTime)
    }
}

// MARK: - PlacedPiece Model (moved here from separate file for Phase 2)

struct PlacedPiece: Identifiable, Codable {
    let id: String
    let type: PieceType
    var position: CGPoint
    var rotation: Double
    let timestamp: Date
    var confidence: Double
    
    init(
        id: String = UUID().uuidString,
        type: PieceType,
        position: CGPoint,
        rotation: Double,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.rotation = rotation
        self.timestamp = Date()
        self.confidence = confidence
    }
    
    // Convert from RecognizedPiece (for Phase 2)
    init(from recognized: RecognizedPiece) {
        self.id = recognized.id
        self.type = PieceType.from(recognized.color) ?? .largeTriangle1
        self.position = recognized.position
        self.rotation = recognized.rotation
        self.timestamp = recognized.timestamp
        self.confidence = recognized.confidence
    }
    
    // Create transform for rendering
    var transform: CGAffineTransform {
        CGAffineTransform.identity
            .translatedBy(x: position.x, y: position.y)
            .rotated(by: rotation)
    }
}

// MARK: - PieceType Extension for CV Mapping

extension PieceType {
    static func from(_ color: RecognizedPiece.Color) -> PieceType? {
        // Map CV colors to piece types
        // This will be refined based on actual CV color detection
        switch color {
        case .red:
            return .largeTriangle1
        case .blue:
            return .largeTriangle2
        case .yellow:
            return .mediumTriangle
        case .green:
            return .smallTriangle1
        case .orange:
            return .smallTriangle2
        case .purple:
            return .square
        case .pink:
            return .parallelogram
        default:
            return nil
        }
    }
    
    var area: Double {
        // Relative area for anchor selection priority
        switch self {
        case .largeTriangle1, .largeTriangle2:
            return 2.0
        case .mediumTriangle:
            return 1.0
        case .smallTriangle1, .smallTriangle2:
            return 0.5
        case .square:
            return 1.0
        case .parallelogram:
            return 1.0
        }
    }
}