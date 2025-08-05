//
//  Game.swift
//  Bemo
//
//  Protocol defining the contract that all games must follow
//

import SwiftUI

protocol Game {
    var id: String { get }
    var title: String { get }
    var description: String { get }
    var recommendedAge: ClosedRange<Int> { get }
    var thumbnailImageName: String { get }
    
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