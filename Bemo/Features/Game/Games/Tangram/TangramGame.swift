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
        return GameUIConfig(
            respectsSafeAreas: false,
            showHintButton: false,  // We use our own hint button
            showProgressBar: false, // We use our own progress bar
            showQuitButton: false   // We handle quit in our own UI
        )
    }
    
    // MARK: - Services
    
    private var viewModel: TangramGameViewModel?
    private let supabaseService: SupabaseService?
    private let learningService: LearningService?
    private let puzzleManagementService: PuzzleManagementService?
    private var childProfileId: String?
    private var overrideDifficulty: UserPreferences.DifficultySetting? = nil
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService? = nil, puzzleManagementService: PuzzleManagementService? = nil, learningService: LearningService? = nil) {
        self.supabaseService = supabaseService
        self.puzzleManagementService = puzzleManagementService
        self.learningService = learningService
    }
    
    // MARK: - Game Protocol Methods
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        let vm = TangramGameViewModel(
            delegate: delegate,
            supabaseService: supabaseService,
            puzzleManagementService: puzzleManagementService,
            learningService: learningService
        )
        
        // Set child profile ID if available
        if let childId = childProfileId {
            vm.setChildProfileId(childId)
        }

        // Provide effective difficulty (parent default with optional override)
        let base = delegate.getChildDifficultySetting()
        vm.setEffectiveDifficulty(overrideDifficulty ?? base)
        
        self.viewModel = vm
        return AnyView(
            TangramGameView(viewModel: vm)
        )
    }
    
    // MARK: - Configuration
    
    func setChildProfileId(_ childId: String) {
        self.childProfileId = childId
        // Also update view model if it exists
        viewModel?.setChildProfileId(childId)
    }

    /// Optional per-game override from the puzzle library
    func setDifficultyOverride(_ difficulty: UserPreferences.DifficultySetting?) {
        self.overrideDifficulty = difficulty
        if let vm = viewModel, let difficulty = difficulty {
            vm.setEffectiveDifficulty(difficulty)
        }
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Convert CV pieces directly to PlacedPieces (no color mapping needed)
        let placedPieces = pieces.map { PlacedPiece(from: $0) }
        
        // Pass to view model for processing
        viewModel?.processCVInput(placedPieces)
        
        // Determine outcome based on piece state
        if placedPieces.isEmpty {
            return .noAction
        }
        
        // Only validate pieces that are placed and stationary
        let stationaryPieces = placedPieces.filter { $0.isPlacedLongEnough() }
        
        // Check if any pieces are correctly placed
        let correctPieces = stationaryPieces.filter { $0.validationState == .correct }
        if !correctPieces.isEmpty {
            return .correctPlacement(points: correctPieces.count * 10)
        }
        
        // Check if pieces are being moved
        let movingPieces = placedPieces.filter { $0.isMoving }
        if !movingPieces.isEmpty {
            return .stateUpdated // User is actively working
        }
        
        // Check if pieces are placed but incorrect
        let incorrectPieces = stationaryPieces.filter { $0.validationState == .incorrect }
        if !incorrectPieces.isEmpty {
            return .incorrectPlacement
        }
        
        return .noAction
    }
    
    func reset() {
        viewModel?.resetGame()
    }
    
    func saveState() -> Data? {
        // Save current game state for persistence
        guard let gameState = viewModel?.gameState else { return nil }
        return try? JSONEncoder().encode(gameState)
    }
    
    func loadState(from data: Data) {
        // Restore game state from saved data
        guard let gameState = try? JSONDecoder().decode(PuzzleGameState.self, from: data) else { return }
        viewModel?.restoreGameState(gameState)
    }
}