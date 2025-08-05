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
        
        // Create the view model if needed
        if viewModel == nil {
            viewModel = TangramEditorViewModel()
        }
        
        // Create and return the editor view
        let editorView = TangramEditorView(viewModel: viewModel!)
        return AnyView(editorView)
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Tangram Editor doesn't use CV input - it's a digital creation tool
        // Return neutral outcome since this is not applicable
        return PlayerActionOutcome(
            isCorrect: false,
            feedback: "The Tangram Editor is a digital creation tool and doesn't use physical pieces.",
            xpEarned: 0,
            achievementUnlocked: nil
        )
    }
    
    func reset() {
        viewModel?.reset()
    }
    
    func saveState() -> Data? {
        guard let viewModel = viewModel else { return nil }
        
        // Save the current puzzle being edited
        let puzzleData = viewModel.currentPuzzleData()
        return try? JSONEncoder().encode(puzzleData)
    }
    
    func loadState(from data: Data) {
        guard let viewModel = viewModel else { return }
        
        // Load a previously saved puzzle
        if let puzzleData = try? JSONDecoder().decode(TangramPuzzle.self, from: data) {
            viewModel.loadPuzzle(from: puzzleData)
        }
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