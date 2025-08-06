//
//  TangramGame.swift
//  Bemo
//
//  Game protocol implementation for Tangram puzzle gameplay
//

// WHAT: Implements the Game protocol for Tangram puzzles, enabling players to solve
//       classic tangram challenges using computer vision to track physical pieces
// ARCHITECTURE: Game protocol implementation in MVVM-S pattern
// USAGE: Instantiated by GameLobbyViewModel, creates game view via makeGameView

import SwiftUI

class TangramGame: Game {
    
    // MARK: - Game Protocol Properties
    
    let id = "tangram"
    let title = "Tangram Puzzles"
    let description = "Solve classic tangram puzzles by arranging shapes"
    let recommendedAge = 5...12
    let thumbnailImageName = "tangram_thumb"
    
    // MARK: - Game UI Configuration
    
    var gameUIConfig: GameUIConfig {
        GameUIConfig(
            respectsSafeAreas: false,
            showHintButton: true,
            showProgressBar: true,
            showQuitButton: true
        )
    }
    
    // MARK: - Game Protocol Methods
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        // For now, return a placeholder view until we build the full game view
        AnyView(
            TangramGameView(
                viewModel: TangramGameViewModel(delegate: delegate)
            )
        )
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Phase 2: Will implement CV processing here
        // For now, return no action
        return .noAction
    }
    
    func reset() {
        // Reset game state to beginning
        // Will be implemented when we have game state management
    }
    
    func saveState() -> Data? {
        // Save current game state for persistence
        // Will be implemented with game state model
        return nil
    }
    
    func loadState(from data: Data) {
        // Restore game state from saved data
        // Will be implemented with game state model
    }
}