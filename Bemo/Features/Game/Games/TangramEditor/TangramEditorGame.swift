//
//  TangramEditorGame.swift
//  Bemo
//
//  Game integration for the Tangram Editor - parent-only puzzle creation tool
//

import SwiftUI
import Foundation

class TangramEditorGame: Game {
    
    // MARK: - Properties
    
    let id = "tangram-editor"
    let title = "Tangram Editor"
    let description = "Create custom tangram puzzles for children to solve"
    let recommendedAge = 18...99 // Parent-only tool
    let thumbnailImageName = "tangram_editor_thumb"
    
    private var viewModel: TangramEditorViewModel?
    private weak var delegate: GameDelegate?
    
    // State management
    private var cachedPuzzleData: Data?
    private var pendingStateToLoad: Data?
    
    // Use editor configuration with custom bars
    var gameUIConfig: GameUIConfig {
        // Create custom bars if viewModel exists
        let topBar = viewModel != nil ? AnyView(TangramEditorTopBar(viewModel: viewModel!, delegate: delegate)) : nil
        let bottomBar = viewModel != nil ? AnyView(TangramEditorBottomBar(viewModel: viewModel!)) : nil
        
        return GameUIConfig(
            respectsSafeAreas: true,
            showHintButton: false,
            showProgressBar: false,
            showQuitButton: false,  // We provide quit in our custom top bar
            customTopBar: topBar,
            customBottomBar: bottomBar
        )
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Game Protocol
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        self.delegate = delegate
        
        // Since this method is called from the main thread by SwiftUI,
        // we can safely assume we're on the MainActor context
        return AnyView(
            MainActor.assumeIsolated {
                // Create the view model if needed
                if viewModel == nil {
                    viewModel = TangramEditorViewModel(puzzle: nil)
                    viewModel?.delegate = delegate
                    
                    // Set up state change notification
                    viewModel?.onPuzzleChanged = { [weak self] puzzle in
                        self?.updateStateCache(puzzle)
                    }
                    
                    // Load pending state if any
                    if let pendingData = pendingStateToLoad {
                        if let puzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: pendingData) {
                            viewModel?.loadPuzzle(from: puzzle)
                        }
                        pendingStateToLoad = nil
                    }
                }
                
                // Return just the canvas view - bars are handled via GameUIConfig
                return TangramEditorCanvasView(viewModel: viewModel!)
            }
        )
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Tangram Editor doesn't use CV input - it's a digital creation tool
        // Return neutral outcome since this is not applicable
        return .noAction
    }
    
    func reset() {
        Task { @MainActor in
            viewModel?.reset()
        }
    }
    
    func saveState() -> Data? {
        // Return cached state if available
        // This is the primary mechanism - always use cache
        return cachedPuzzleData
    }
    
    func loadState(from data: Data) {
        // Store the data for when viewModel is created
        pendingStateToLoad = data
        cachedPuzzleData = data
        
        // If viewModel already exists, load immediately
        if let puzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: data) {
            Task { @MainActor in
                viewModel?.loadPuzzle(from: puzzle)
            }
        }
    }
    
    // MARK: - State Management Helpers
    
    private func updateStateCache(_ puzzle: TangramPuzzle) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        cachedPuzzleData = try? encoder.encode(puzzle)
    }
}

// MARK: - Parent Access Control

extension TangramEditorGame {
    
    /// Check if the current user has permission to access the editor
    var isAccessible: Bool {
        // This should check if the current user is a parent
        // Implementation depends on your auth/user system
        return true // TODO: Implement proper parent check
    }
    
    /// Message to show when access is denied
    var accessDeniedMessage: String {
        "The Tangram Editor is only available to parents and educators."
    }
}