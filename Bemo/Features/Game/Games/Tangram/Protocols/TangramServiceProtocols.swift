//
//  TangramServiceProtocols.swift
//  Bemo
//
//  Service protocols for Tangram game dependency injection and testing
//

// WHAT: Defines protocols for all Tangram services to enable testing and loose coupling
// ARCHITECTURE: Protocol definitions in MVVM-S for dependency injection
// USAGE: Implement these protocols in services, inject protocol types for testability

import Foundation
import CoreGraphics

// MARK: - Piece Validation (feature-angle path only)
// Keep protocol surface minimal; rely on TangramPieceValidator directly

// MARK: - Hint Engine

protocol HintProviding {
    /// Generates appropriate hint based on game state
    func generateHint(gameState: PuzzleGameState, lastMovedPiece: TangramPieceType?) -> TangramHintEngine.HintData
    
    /// Calculates frustration level based on game state
    func calculateFrustrationLevel(gameState: PuzzleGameState) -> TangramHintEngine.FrustrationLevel
}

// MARK: - Puzzle Library

protocol PuzzleLibraryProviding {
    /// Loads puzzles from the database
    func loadPuzzles() async throws -> [GamePuzzleData]
    
    /// Saves a custom puzzle
    func savePuzzle(_ puzzle: GamePuzzleData) async throws
    
    /// Deletes a puzzle
    func deletePuzzle(id: String) async throws
}

// MARK: - Database Loading

protocol TangramDatabaseLoading {
    /// Loads official puzzles from database
    func loadOfficialPuzzles() async throws -> [GamePuzzleData]
    
    /// Loads puzzle by ID
    func loadPuzzle(id: String) async throws -> GamePuzzleData?
}

// MARK: - Piece Positioning
// Removed grid/snap interfaces to avoid snapping-related tech debt

// MARK: - Data Conversion

protocol PuzzleDataConverting {
    /// Converts from database format to GamePuzzleData
    func convertFromDatabase(_ data: [String: Any]) -> Result<GamePuzzleData, PuzzleDataConverterError>
    
    /// Converts from Codable format
    func convertFromCodable<T: Decodable>(_ data: T) -> GamePuzzleData?
}

// MARK: - Make existing services conform to protocols
// Use TangramPieceValidator directly (no protocol indirection)

extension TangramHintEngine: HintProviding {}

extension TangramDatabaseLoader: TangramDatabaseLoading {}

// Removed PiecePositioning conformance

// Note: PuzzleDataConverter is an enum with static methods, 
// so we'd need to create a wrapper class to conform to the protocol
class PuzzleDataConvertingService: PuzzleDataConverting {
    func convertFromDatabase(_ data: [String: Any]) -> Result<GamePuzzleData, PuzzleDataConverterError> {
        return PuzzleDataConverter.convertFromDatabase(data)
    }
    
    func convertFromCodable<T: Decodable>(_ data: T) -> GamePuzzleData? {
        return PuzzleDataConverter.convertFromCodable(data)
    }
}