//
//  TangramCVGame.swift
//  Bemo
//
//  CV-ready implementation of Tangram with three-zone layout and relative validation
//

// WHAT: Game entry point for CV-ready Tangram implementation with physical world simulation
// ARCHITECTURE: Conforms to Game protocol, creates CV-enabled view model and view
// USAGE: Register in game catalog as TangramCVGame for parallel testing with original

import SwiftUI

class TangramCVGame: Game {
    
    // MARK: - Game Protocol Properties
    
    let id = "tangram_cv"
    let title = "Tangram CV"
    let description = "Build colorful shapes with tangram pieces - CV Ready Version"
    let recommendedAge = 5...10
    let thumbnailImageName = "tangram_thumbnail"
    
    // MARK: - Game UI Configuration
    
    var gameUIConfig: GameUIConfig {
        return GameUIConfig(
            respectsSafeAreas: false,  // Games want full screen
            showHintButton: false,     // We use our own hint button
            showProgressBar: false,    // We use our own progress bar
            showQuitButton: false      // We handle quit in our own UI
        )
    }
    
    // MARK: - Services
    
    private let supabaseService: SupabaseService?
    private let puzzleManagementService: PuzzleManagementService?
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService? = nil, puzzleManagementService: PuzzleManagementService? = nil) {
        self.supabaseService = supabaseService
        self.puzzleManagementService = puzzleManagementService
    }
    
    // MARK: - Game Protocol Methods
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        // Create puzzle library service wrapper with both services
        let puzzleLibraryService = PuzzleLibraryService(
            puzzleManagementService: puzzleManagementService,
            supabaseService: supabaseService
        )
        
        // Create the CV-enabled view model with services
        let viewModel = TangramCVGameViewModel(
            delegate: delegate,
            puzzleLibraryService: puzzleLibraryService,
            supabaseService: supabaseService
        )
        
        // Return the CV-enabled game view
        return AnyView(
            TangramCVGameView(viewModel: viewModel)
        )
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // This will process actual CV input when hardware is ready
        // For now, we'll generate CV format from touch input internally
        
        if pieces.isEmpty {
            return .noAction
        }
        
        // Process CV pieces through our relative validation system
        // This will be implemented as we build the validator
        let correctCount = pieces.filter { $0.confidence > 0.8 }.count
        
        // Check if puzzle is complete (all 7 pieces correct)
        if correctCount == 7 {
            return .levelComplete(xpAwarded: 100)
        }
        
        // Check if we have any correct placements
        if correctCount > 0 {
            return .correctPlacement(points: correctCount * 10)
        }
        
        // Check if pieces are being moved
        let movingPieces = pieces.filter { $0.isMoving }
        if !movingPieces.isEmpty {
            return .stateUpdated
        }
        
        // Default to no action
        return .noAction
    }
    
    func reset() {
        // Reset will be handled by the view model
        print("TangramCV: Game reset requested")
    }
    
    func saveState() -> Data? {
        // State saving will be implemented with the view model
        return nil
    }
    
    func loadState(from data: Data) {
        // State loading will be implemented with the view model
        print("TangramCV: Load state requested")
    }
}