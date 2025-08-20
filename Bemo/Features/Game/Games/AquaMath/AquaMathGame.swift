//
//  AquaMathGame.swift
//  Bemo
//
//  Game implementation for AquaMath Touch - underwater math learning game
//

// WHAT: Implements the Game protocol for AquaMath, a touch-based educational math game
// ARCHITECTURE: Game protocol implementation in MVVM-S pattern
// USAGE: Instantiated by GameLobbyViewModel, creates game view via makeGameView

import SwiftUI

class AquaMathGame: Game {
    
    // MARK: - Game Protocol Properties
    
    let id = "aquamath"
    let title = "Math Aquarium"
    let description = "Solve math problems to fill your aquarium!"
    let recommendedAge = 5...10
    let thumbnailImageName = "drop.circle.fill"
    
    // MARK: - Game UI Configuration
    
    var gameUIConfig: GameUIConfig {
        return GameUIConfig(
            respectsSafeAreas: false,  // Full screen immersive experience
            showHintButton: false,      // Hide hint button for now
            showProgressBar: false,     // We'll use water level as progress
            showQuitButton: true
        )
    }
    
    // MARK: - Properties
    
    private var viewModel: AquaMathGameViewModel?
    
    // MARK: - Game Protocol Methods
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        let vm = AquaMathGameViewModel(delegate: delegate)
        self.viewModel = vm
        return AnyView(
            AquaMathGameView(viewModel: vm)
        )
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // AquaMath is a touch-only game, no CV input processing
        return .noAction
    }
    
    func reset() {
        viewModel?.reset()
    }
    
    func saveState() -> Data? {
        return viewModel?.saveState()
    }
    
    func loadState(from data: Data) {
        viewModel?.loadState(from: data)
    }
}