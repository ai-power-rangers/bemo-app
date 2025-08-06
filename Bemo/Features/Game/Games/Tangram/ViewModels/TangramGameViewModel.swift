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
    var selectedPuzzle: GamePuzzleData?
    var gameState: PuzzleGameState?
    var score: Int = 0
    var progress: Double = 0.0
    var showHints: Bool = false
    var canvasSize: CGSize = CGSize(width: 600, height: 600)
    
    // CV Tracking
    var placedPieces: [PlacedPiece] = []
    var anchorPiece: PlacedPiece?
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private let puzzleLibraryService: PuzzleLibraryService
    private(set) var puzzleSelectionViewModel: PuzzleSelectionViewModel!
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate, supabaseService: SupabaseService? = nil) {
        self.delegate = delegate
        self.puzzleLibraryService = PuzzleLibraryService(supabaseService: supabaseService)
        self.puzzleSelectionViewModel = PuzzleSelectionViewModel(
            libraryService: puzzleLibraryService,
            onPuzzleSelected: { [weak self] puzzle in
                self?.selectPuzzle(puzzle)
            }
        )
    }
    
    // MARK: - Game Actions
    
    func selectPuzzle(_ puzzle: TangramPuzzle) {
        // Convert editor puzzle to game puzzle data
        selectedPuzzle = GamePuzzleData(from: puzzle)
        gameState = PuzzleGameState(targetPuzzle: selectedPuzzle!)
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
    
    // MARK: - CV Processing
    
    func processCVInput(_ pieces: [PlacedPiece]) {
        guard currentPhase == .playingPuzzle else { return }
        
        // Update placed pieces
        placedPieces = pieces
        
        // Select or update anchor piece
        updateAnchorPiece()
        
        // Calculate relative positions for all pieces
        if let anchor = anchorPiece {
            placedPieces = placedPieces.map { piece in
                if piece.id == anchor.id {
                    return piece
                } else {
                    return piece.updateRelativeToAnchor(anchor)
                }
            }
        }
        
        // Validate piece placements (will implement in Phase 3)
        // For now, just update game state
        gameState?.updatePlacedPieces(placedPieces)
        
        // Calculate progress (will refine in Phase 3)
        let piecesWithTypes = placedPieces.filter { $0.pieceType != nil }
        let newProgress = Double(piecesWithTypes.count) / 7.0
        updateProgress(newProgress)
    }
    
    private func updateAnchorPiece() {
        // If no anchor or anchor is not in current pieces, select new one
        if anchorPiece == nil || !placedPieces.contains(where: { $0.id == anchorPiece?.id }) {
            selectNewAnchor()
        }
    }
    
    private func selectNewAnchor() {
        // Priority: largest piece > most central > first placed
        anchorPiece = placedPieces
            .sorted { p1, p2 in
                // First sort by area (larger pieces first)
                if p1.area != p2.area {
                    return p1.area > p2.area
                }
                // Then by distance from center (closer to center first)
                return p1.distanceFromCenter < p2.distanceFromCenter
            }
            .first
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
    
    // MARK: - Game State Management
    
    func resetGame() {
        currentPhase = .selectingPuzzle
        selectedPuzzle = nil
        gameState = nil
        placedPieces = []
        anchorPiece = nil
        score = 0
        progress = 0.0
        showHints = false
    }
    
    func restoreGameState(_ state: PuzzleGameState) {
        gameState = state
        selectedPuzzle = state.targetPuzzle
        currentPhase = .playingPuzzle
        // Restore placed pieces (not optional - array is always present)
        placedPieces = state.placedPieces
        updateAnchorPiece()
    }
}