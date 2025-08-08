//
//  TangramEditorError.swift
//  Bemo
//
//  Error types and user-friendly messages for Tangram Editor
//

// WHAT: Defines all error types that can occur in Tangram Editor with user-friendly messages
// ARCHITECTURE: Error model in MVVM-S pattern, used by services and ViewModel for proper error handling
// USAGE: Throw these errors from services, handle in ViewModel, display userMessage to users

import Foundation

enum TangramEditorError: LocalizedError {
    
    // MARK: - Placement Errors
    case pieceAlreadyPlaced(String)
    case invalidConnectionPoints(String)
    case placementCalculationFailed(String)
    case overlappingPieces(String)
    case invalidPlacement(String)
    case noAvailableConnections
    case insufficientConnectionPoints
    
    // MARK: - Validation Errors
    case validationFailed(String)
    case puzzleIncomplete
    case disconnectedPieces
    case invalidPuzzleConfiguration
    
    // MARK: - Persistence Errors
    case saveFailed(String)
    case loadFailed(String)
    case puzzleNotFound
    case corruptedPuzzleData
    case insufficientStorage
    
    // MARK: - State Errors
    case invalidState(String)
    case operationNotAllowed(String)
    case undoNotAvailable
    case redoNotAvailable
    
    // MARK: - Manipulation Errors
    case manipulationFailed(String)
    case rotationBlocked(String)
    case slideBlocked(String)
    case invalidManipulation
    
    // MARK: - LocalizedError Protocol
    
    var errorDescription: String? {
        switch self {
        case .pieceAlreadyPlaced(let type):
            return "Piece already placed: \(type)"
        case .invalidConnectionPoints(let detail):
            return "Invalid connection points: \(detail)"
        case .placementCalculationFailed(let detail):
            return "Failed to calculate placement: \(detail)"
        case .overlappingPieces(let detail):
            return "Pieces would overlap: \(detail)"
        case .invalidPlacement(let detail):
            return "Invalid placement: \(detail)"
        case .noAvailableConnections:
            return "No available connection points"
        case .insufficientConnectionPoints:
            return "Not enough connection points selected"
            
        case .validationFailed(let detail):
            return "Validation failed: \(detail)"
        case .puzzleIncomplete:
            return "Puzzle is incomplete"
        case .disconnectedPieces:
            return "Some pieces are not connected"
        case .invalidPuzzleConfiguration:
            return "Invalid puzzle configuration"
            
        case .saveFailed(let detail):
            return "Failed to save puzzle: \(detail)"
        case .loadFailed(let detail):
            return "Failed to load puzzle: \(detail)"
        case .puzzleNotFound:
            return "Puzzle not found"
        case .corruptedPuzzleData:
            return "Puzzle data is corrupted"
        case .insufficientStorage:
            return "Not enough storage space"
            
        case .invalidState(let detail):
            return "Invalid editor state: \(detail)"
        case .operationNotAllowed(let detail):
            return "Operation not allowed: \(detail)"
        case .undoNotAvailable:
            return "Nothing to undo"
        case .redoNotAvailable:
            return "Nothing to redo"
            
        case .manipulationFailed(let detail):
            return "Manipulation failed: \(detail)"
        case .rotationBlocked(let detail):
            return "Cannot rotate: \(detail)"
        case .slideBlocked(let detail):
            return "Cannot slide: \(detail)"
        case .invalidManipulation:
            return "Invalid manipulation attempt"
        }
    }
    
    var failureReason: String? {
        userMessage
    }
    
    // MARK: - User-Friendly Messages
    
    var userMessage: String {
        switch self {
        case .pieceAlreadyPlaced:
            return "This piece is already placed in the puzzle."
        case .invalidConnectionPoints:
            return "Please select matching connection types (vertex-to-vertex or edge-to-edge)."
        case .placementCalculationFailed:
            return "Cannot place piece here. Try different connection points."
        case .overlappingPieces:
            return "This position would overlap with existing pieces."
        case .invalidPlacement:
            return "This placement is not valid. Please try again."
        case .noAvailableConnections:
            return "No connection points available. Add your first piece anywhere on the canvas."
        case .insufficientConnectionPoints:
            return "Please select connection points on both the canvas and the piece."
            
        case .validationFailed:
            return "The puzzle doesn't meet validation requirements."
        case .puzzleIncomplete:
            return "Please complete the puzzle before saving."
        case .disconnectedPieces:
            return "All pieces must be connected. Some pieces are isolated."
        case .invalidPuzzleConfiguration:
            return "The puzzle configuration is invalid."
            
        case .saveFailed:
            return "Unable to save the puzzle. Please try again."
        case .loadFailed:
            return "Unable to load the puzzle. It may be corrupted."
        case .puzzleNotFound:
            return "The requested puzzle could not be found."
        case .corruptedPuzzleData:
            return "The puzzle data appears to be damaged."
        case .insufficientStorage:
            return "Not enough storage space to save the puzzle."
            
        case .invalidState:
            return "The editor is in an unexpected state. Please try again."
        case .operationNotAllowed:
            return "This action is not currently available."
        case .undoNotAvailable:
            return "There are no actions to undo."
        case .redoNotAvailable:
            return "There are no actions to redo."
            
        case .manipulationFailed:
            return "Unable to move the piece. It may be locked in place."
        case .rotationBlocked:
            return "This piece cannot rotate further without overlapping."
        case .slideBlocked:
            return "This piece cannot slide further in that direction."
        case .invalidManipulation:
            return "This piece cannot be moved in that way."
        }
    }
    
    // MARK: - Helper Properties
    
    var isRecoverable: Bool {
        switch self {
        case .corruptedPuzzleData, .insufficientStorage:
            return false
        default:
            return true
        }
    }
    
    var suggestedAction: String? {
        switch self {
        case .noAvailableConnections:
            return "Place your first piece anywhere to start building."
        case .insufficientConnectionPoints:
            return "Select a point on the canvas, then a point on the piece."
        case .overlappingPieces:
            return "Try rotating the piece or choosing different connection points."
        case .disconnectedPieces:
            return "Connect all pieces together to form a valid puzzle."
        case .insufficientStorage:
            return "Free up some space and try again."
        case .corruptedPuzzleData:
            return "Try loading a different puzzle or create a new one."
        default:
            return nil
        }
    }
}