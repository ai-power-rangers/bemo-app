//
//  TgramViewerGame.swift
//  Bemo
//
//  Game implementation for frustration detection testing
//

// WHAT: Implements the Game protocol for TgramViewer, a tool to test frustration detection
// ARCHITECTURE: Game protocol implementation in MVVM-S pattern
// USAGE: Instantiated by GameLobbyViewModel, creates game view via makeGameView

import SwiftUI

class TgramViewerGame: Game {
    
    // MARK: - Game Protocol Properties
    
    let id = "tgram_viewer"
    let title = "Frustration Detector"
    let description = "Test facial expression-based frustration detection"
    let recommendedAge = 5...99  // Tool for all ages
    let thumbnailImageName = "face.smiling.inverse"
    
    // MARK: - Game UI Configuration
    
    var gameUIConfig: GameUIConfig {
        return GameUIConfig(
            respectsSafeAreas: true,
            showHintButton: false,
            showProgressBar: false,
            showQuitButton: true
        )
    }
    
    // MARK: - Properties
    
    private var viewModel: TgramViewerViewModel?
    private let cvService: CVService
    
    init(cvService: CVService) {
        self.cvService = cvService
    }
    
    // MARK: - Game Protocol Methods
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        let vm = TgramViewerViewModel(delegate: delegate)
        self.viewModel = vm
        return AnyView(
            TgramViewerView(viewModel: vm)
        )
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // This viewer doesn't process CV input - it just displays static data
        return .noAction
    }
    
    func reset() {
        viewModel?.reset()
    }
    
    func saveState() -> Data? {
        // No state to save for a viewer
        return nil
    }
    
    func loadState(from data: Data) {
        // No state to load for a viewer
    }
}
