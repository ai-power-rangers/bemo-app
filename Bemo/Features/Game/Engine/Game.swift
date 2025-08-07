//
//  Game.swift
//  Bemo
//
//  Protocol defining the contract that all games must follow
//

// WHAT: Protocol that all games must implement. Defines required properties and methods for game identification, UI creation, and CV input processing.
// ARCHITECTURE: Core protocol of the plug-and-play game engine. Enables modular game addition without modifying engine code.
// USAGE: Implement this protocol for new games. Must provide makeGameView(), processRecognizedPieces(), and state management methods.

import SwiftUI

protocol Game {
    var id: String { get }
    var title: String { get }
    var description: String { get }
    var recommendedAge: ClosedRange<Int> { get }
    var thumbnailImageName: String { get }
    
    /// UI configuration preferences for this game
    var gameUIConfig: GameUIConfig { get }
    
    /// Creates and returns the SwiftUI view for this game
    /// - Parameter delegate: The delegate to communicate game events back to the host
    /// - Returns: Type-erased SwiftUI view for the game
    func makeGameView(delegate: GameDelegate) -> AnyView
    
    /// Processes recognized pieces from the CV service
    /// - Parameter pieces: Array of recognized physical pieces
    /// - Returns: The outcome of processing the player's action
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome
    
    /// Called when the game should reset to its initial state
    func reset()
    
    /// Returns the current game state for persistence
    func saveState() -> Data?
    
    /// Restores the game from a previously saved state
    func loadState(from data: Data)
}

// MARK: - Default Implementations
extension Game {
    /// Default UI configuration for games (can be overridden)
    var gameUIConfig: GameUIConfig {
        return .defaultGameConfig
    }
}