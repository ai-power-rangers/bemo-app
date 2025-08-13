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
    private let supabaseService: SupabaseService?
    private let puzzleManagementService: PuzzleManagementService?
    private let initialPuzzleId: String

    // MARK: - Initialization
    
    init(
        supabaseService: SupabaseService? = nil,
        puzzleManagementService: PuzzleManagementService? = nil,
        puzzleId: String = "puzzle_26D26F42-0D65-4D85-9405-15E9CFBA3098"
    ) {
        self.supabaseService = supabaseService
        self.puzzleManagementService = puzzleManagementService
        self.initialPuzzleId = puzzleId
    }
    
    // MARK: - Game Protocol Methods
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        let container = TangramDependencyContainer(
            supabaseService: supabaseService,
            puzzleManagementService: puzzleManagementService
        )
        let vm = TgramViewerViewModel(delegate: delegate, container: container, initialPuzzleId: initialPuzzleId)
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
