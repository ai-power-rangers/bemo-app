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

// MARK: - Piece Validation

protocol PieceValidating {
    /// Validates if a placed piece matches a target position
    func validate(placed: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool
    
    /// Validates placement for SpriteKit scene
    func validateForSpriteKit(
        piecePosition: CGPoint,
        pieceRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> TangramPieceValidator.ValidationResult
}

// MARK: - Gameplay Service

protocol TangramGameplayProviding {
    /// Validates piece placement against target
    func validatePiecePlacement(
        piecePosition: CGPoint,
        pieceRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> TangramPieceValidator.ValidationResult
    
    /// Checks if a piece is close enough to snap to target
    func shouldShowSnapPreview(piecePosition: CGPoint, targetPosition: CGPoint) -> Bool
    
    /// Determines snap preview strength based on distance
    func getSnapPreviewStrength(piecePosition: CGPoint, targetPosition: CGPoint) -> TangramGameplayService.SnapPreviewStrength
}

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
    
    /// Loads community puzzles
    func loadCommunityPuzzles() async throws -> [GamePuzzleData]
    
    /// Loads puzzle by ID
    func loadPuzzle(id: String) async throws -> GamePuzzleData?
}

// MARK: - Piece Positioning

protocol PiecePositioning {
    /// Calculates optimal piece layout for a puzzle
    func calculateLayout(for pieces: [TangramPieceType], in bounds: CGRect) -> [TangramPieceType: CGPoint]
    
    /// Adjusts piece position to grid if enabled
    func snapToGrid(_ position: CGPoint, gridSize: CGFloat) -> CGPoint
}

// MARK: - Data Conversion

protocol PuzzleDataConverting {
    /// Converts from database format to GamePuzzleData
    func convertFromDatabase(_ data: [String: Any]) -> Result<GamePuzzleData, PuzzleDataConverterError>
    
    /// Converts from Codable format
    func convertFromCodable<T: Decodable>(_ data: T) -> GamePuzzleData?
}

// MARK: - Make existing services conform to protocols

extension TangramPieceValidator: PieceValidating {}

extension TangramGameplayService: TangramGameplayProviding {}

extension TangramHintEngine: HintProviding {}

extension PuzzleLibraryService: PuzzleLibraryProviding {}

extension TangramDatabaseLoader: TangramDatabaseLoading {}

extension TangramPiecePositioningService: PiecePositioning {}

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