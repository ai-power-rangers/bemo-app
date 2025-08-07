//
//  TangramPuzzleData.swift
//  Bemo
//
//  Pure data model for tangram puzzles
//

import Foundation
import CoreGraphics

// All puzzles created in the editor are official puzzles for the app

struct TangramPuzzle: Codable, Identifiable {
    let id: String
    var name: String
    var category: PuzzleCategory
    var difficulty: PuzzleDifficulty
    var pieces: [TangramPiece]
    var connections: [Connection]
    var solutionChecksum: String
    let createdDate: Date
    var modifiedDate: Date
    var createdBy: String?
    var thumbnailData: Data?
    var tags: [String]
    // All puzzles are editable in the editor since this is a developer tool
    var isEditable: Bool { true }
    
    init(name: String, 
         category: PuzzleCategory = .custom,
         difficulty: PuzzleDifficulty = .medium) {
        self.id = "puzzle_\(UUID().uuidString)"
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.pieces = []
        self.connections = []
        self.solutionChecksum = ""
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.tags = []
    }
}

enum PuzzleDifficulty: Int, Codable, CaseIterable {
    case beginner = 1
    case easy = 2
    case medium = 3
    case hard = 4
    case expert = 5
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }
}

enum PuzzleCategory: String, Codable, CaseIterable {
    case animals = "Animals"
    case people = "People"
    case objects = "Objects"
    case letters = "Letters"
    case numbers = "Numbers"
    case geometric = "Geometric"
    case abstract = "Abstract"
    case custom = "Custom"
}

// Data structure for solved puzzles (used in gameplay)
struct SolvedTangramPuzzle: Codable {
    let id: String
    let name: String
    let category: String
    let difficulty: String
    let solvedPieces: [SolvedPiece]
    let checksum: String
}

struct SolvedPiece: Codable {
    let pieceType: PieceType
    let transform: CGAffineTransform
}

// Metadata for listing puzzles without loading full data
struct PuzzleMetadata: Codable, Identifiable {
    let id: String
    let name: String
    let category: PuzzleCategory
    let difficulty: PuzzleDifficulty
    let createdDate: Date
    let modifiedDate: Date
    let pieceCount: Int
}