//
//  TangramEditorGame.swift
//  Bemo
//
//  Game integration for the Tangram Editor - parent-only puzzle creation tool
//

import SwiftUI

class TangramEditorGame: Game {
    
    // MARK: - Properties
    
    let id = "tangram-editor"
    let title = "Tangram Editor"
    let description = "Create custom tangram puzzles for children to solve"
    let recommendedAge = 18...99 // Parent-only tool
    let thumbnailImageName = "tangram_editor_thumb"
    
    private var viewModel: TangramEditorViewModel?
    private weak var delegate: GameDelegate?
    
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
                }
                
                // Create and return the editor view
                return TangramEditorView(viewModel: viewModel!)
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
        // We need to get the data synchronously, so we'll return nil for now
        // and handle persistence through the view model's save methods
        return nil
    }
    
    func loadState(from data: Data) {
        // Load state will be handled through the view model's async methods
        // This synchronous method can't directly call MainActor methods
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