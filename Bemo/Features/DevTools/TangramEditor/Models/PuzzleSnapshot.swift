//
//  PuzzleSnapshot.swift
//  Bemo
//
//  Model for undo/redo snapshot functionality in Tangram Editor
//

import Foundation

/// Snapshot of puzzle state for undo/redo functionality
struct PuzzleSnapshot: Codable {
    let pieces: [TangramPiece]
    let connections: [Connection]
    let timestamp: Date
    
    init(puzzle: TangramPuzzle) {
        self.pieces = puzzle.pieces
        self.connections = puzzle.connections
        self.timestamp = Date()
    }
    
    /// Apply this snapshot's state to a puzzle
    func apply(to puzzle: inout TangramPuzzle) {
        puzzle.pieces = pieces
        puzzle.connections = connections
        puzzle.modifiedDate = Date()
    }
}