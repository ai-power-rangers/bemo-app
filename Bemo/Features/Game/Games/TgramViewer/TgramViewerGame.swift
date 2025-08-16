//
//  TgramViewerGame.swift
//  Bemo
//
//  Game implementation for viewing CV-detected tangram pieces
//

// WHAT: Implements the Game protocol for TgramViewer, a tool to visualize CV output coordinates
// ARCHITECTURE: Game protocol implementation in MVVM-S pattern
// USAGE: Instantiated by GameLobbyViewModel, creates game view via makeGameView

import SwiftUI

class TgramViewerGame: Game {
    
    // MARK: - Game Protocol Properties
    
    let id = "tgram_viewer"
    let title = "Tangram Viewer"
    let description = "View tangram pieces from CV output coordinates"
    let recommendedAge = 5...99  // Tool for all ages
    let thumbnailImageName = "eye.circle.fill"
    
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
        let vm = TgramViewerViewModel(delegate: delegate, cvService: cvService)
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
