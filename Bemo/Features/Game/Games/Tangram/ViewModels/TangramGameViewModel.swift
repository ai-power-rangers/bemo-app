//
//  TangramGameViewModel.swift
//  Bemo
//
//  Main view model for Tangram puzzle gameplay
//

// WHAT: Manages game state, puzzle selection, and CV piece tracking for Tangram game
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses @Observable for state management
// USAGE: Created by TangramGame with GameDelegate, manages all game logic

import SwiftUI
import Observation

@Observable
class TangramGameViewModel {
    
    // MARK: - Game State
    
    enum GamePhase {
        case selectingPuzzle
        case playingPuzzle
        case puzzleComplete
    }
    
    var currentPhase: GamePhase = .selectingPuzzle
    var selectedPuzzle: TangramPuzzle?
    var gameState: PuzzleGameState?
    var score: Int = 0
    var progress: Double = 0.0
    var showHints: Bool = false
    var canvasSize: CGSize = CGSize(width: 600, height: 600)
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private let puzzleLibraryService = PuzzleLibraryService()
    private(set) var puzzleSelectionViewModel: PuzzleSelectionViewModel!
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate) {
        self.delegate = delegate
        self.puzzleSelectionViewModel = PuzzleSelectionViewModel(
            libraryService: puzzleLibraryService,
            onPuzzleSelected: { [weak self] puzzle in
                self?.selectPuzzle(puzzle)
            }
        )
    }
    
    // MARK: - Game Actions
    
    func selectPuzzle(_ puzzle: TangramPuzzle) {
        selectedPuzzle = puzzle
        gameState = PuzzleGameState(targetPuzzle: puzzle)
        currentPhase = .playingPuzzle
        progress = 0.0
        showHints = false
        // Update progress to 0 when starting
        delegate?.gameDidUpdateProgress(Float(0.0))
    }
    
    func exitToSelection() {
        currentPhase = .selectingPuzzle
        selectedPuzzle = nil
        gameState = nil
        progress = 0.0
        showHints = false
    }
    
    func requestQuit() {
        delegate?.gameDidRequestQuit()
    }
    
    func requestHint() {
        showHints = true
        gameState?.incrementHintCount()
        delegate?.gameDidRequestHint()
    }
    
    func toggleHints() {
        showHints.toggle()
        if showHints {
            gameState?.incrementHintCount()
        }
    }
    
    // MARK: - CV Processing (Phase 2)
    
    func processCVInput(_ pieces: [RecognizedPiece]) {
        // Will implement in Phase 2
    }
    
    // MARK: - Progress Management (Phase 3)
    
    func updateProgress(_ newProgress: Double) {
        progress = newProgress
        delegate?.gameDidUpdateProgress(Float(progress))
        
        if progress >= 1.0 {
            completePuzzle()
        }
    }
    
    private func completePuzzle() {
        currentPhase = .puzzleComplete
        let xpAwarded = calculateXP()
        delegate?.gameDidCompleteLevel(xpAwarded: xpAwarded)
    }
    
    private func calculateXP() -> Int {
        // Base XP with modifiers for hints, time, etc.
        return 100
    }
}