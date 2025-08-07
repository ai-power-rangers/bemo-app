//
//  GamePuzzleData.swift
//  Bemo
//
//  Simplified puzzle data model for Tangram gameplay
//

// WHAT: Lightweight puzzle representation for gameplay, containing only validation-relevant data
// ARCHITECTURE: Model in MVVM-S, used by TangramGame for puzzle validation without editor dependencies
// USAGE: Created from TangramPuzzle data, stores target positions for piece validation

import Foundation
import CoreGraphics

/// Simplified puzzle data for gameplay - no editor dependencies
struct GamePuzzleData: Codable, Equatable {
    let id: String
    let name: String
    let category: String
    let difficulty: Int
    let targetPieces: [TargetPiece]
    
    /// A target position for a piece in the puzzle solution
    struct TargetPiece: Codable, Equatable {
        let pieceType: String  // PieceType rawValue
        let position: CGPoint
        let rotation: Double   // In degrees
        
        /// Check if a placed piece matches this target within tolerances
        func matches(_ placed: PlacedPiece, positionTolerance: Double = 10.0, rotationTolerance: Double = 5.0) -> Bool {
            guard placed.pieceType.rawValue == pieceType else { return false }
            
            // Check position tolerance
            let dx = abs(placed.position.x - position.x)
            let dy = abs(placed.position.y - position.y)
            let distance = sqrt(dx * dx + dy * dy)
            guard distance <= positionTolerance else { return false }
            
            // Check rotation tolerance
            var rotationDiff = abs(placed.rotation - rotation)
            // Normalize rotation difference to 0-180 range
            while rotationDiff > 180 { rotationDiff -= 360 }
            if rotationDiff > 180 { rotationDiff = 360 - rotationDiff }
            
            return rotationDiff <= rotationTolerance
        }
    }
    
    /// Convert from editor's TangramPuzzle (when loading from persistence)
    init(from editorPuzzle: TangramPuzzle) {
        self.id = editorPuzzle.id
        self.name = editorPuzzle.name
        self.category = editorPuzzle.category.rawValue
        self.difficulty = editorPuzzle.difficulty.rawValue
        
        // Extract target positions from editor pieces
        self.targetPieces = editorPuzzle.pieces.map { piece in
            // Extract position and rotation from CGAffineTransform
            let transform = piece.transform
            
            // Position is the translation components
            let position = CGPoint(x: transform.tx, y: transform.ty)
            
            // Rotation in radians from the transform matrix
            // atan2 gives us the angle from the rotation components
            let rotationRadians = atan2(transform.b, transform.a)
            let rotationDegrees = rotationRadians * 180.0 / .pi
            
            return TargetPiece(
                pieceType: piece.type.rawValue,
                position: position,
                rotation: rotationDegrees
            )
        }
    }
    
    /// Create from simplified data (for testing or bundled puzzles)
    init(id: String, name: String, category: String, difficulty: Int, targetPieces: [TargetPiece]) {
        self.id = id
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.targetPieces = targetPieces
    }
}

/// Progress tracking for a puzzle being solved
struct GameProgress {
    let puzzleId: String
    var correctPieces: Set<String> // PieceType rawValues that are correctly placed
    var totalPieces: Int
    var hintsUsed: Int = 0
    var startTime: Date
    var lastProgressTime: Date
    
    var progressPercentage: Double {
        guard totalPieces > 0 else { return 0 }
        return Double(correctPieces.count) / Double(totalPieces)
    }
    
    var isComplete: Bool {
        correctPieces.count == totalPieces
    }
    
    var timeSinceLastProgress: TimeInterval {
        Date().timeIntervalSince(lastProgressTime)
    }
    
    mutating func markPieceCorrect(_ pieceType: String) {
        correctPieces.insert(pieceType)
        lastProgressTime = Date()
    }
    
    mutating func markPieceIncorrect(_ pieceType: String) {
        correctPieces.remove(pieceType)
    }
}