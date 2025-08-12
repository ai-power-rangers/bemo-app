//
//  TangramDependencyContainer.swift
//  Bemo
//
//  Dependency injection container for Tangram game
//

// WHAT: Centralized dependency container for all Tangram services
// ARCHITECTURE: DI container in MVVM-S, provides all services to ViewModels
// USAGE: Created once and passed to TangramGameViewModel for service access

import Foundation

/// Dependency injection container for Tangram game
class TangramDependencyContainer {
    
    // MARK: - Services
    
    // Removed gameplayService and positioningService (snapping/preview/grid not used)
    
    /// Piece validation service
    let pieceValidator: TangramPieceValidator
    
    /// Hint engine for intelligent hint generation
    let hintEngine: TangramHintEngine
    
    /// Database loader for puzzle data
    let databaseLoader: TangramDatabaseLoader
    
    /// Library service for puzzle management
    let puzzleLibraryService: PuzzleLibraryService
    
    /// Data converter for puzzle format transformations
    let dataConverter: PuzzleDataConverter.Type
    
    // MARK: - Utilities
    
    /// Geometry utilities for calculations
    let geometryUtilities: TangramGeometryUtilities.Type
    
    // MARK: - External Dependencies
    
    let supabaseService: SupabaseService?
    let puzzleManagementService: PuzzleManagementService?

    /// Relative mapping service for anchor-based validation shared by Scene and ViewModel
    let mappingService: TangramRelativeMappingService
    
    // MARK: - Initialization
    
    init(
        supabaseService: SupabaseService? = nil,
        puzzleManagementService: PuzzleManagementService? = nil
    ) {
        self.supabaseService = supabaseService
        self.puzzleManagementService = puzzleManagementService
        
        // Initialize utilities
        self.geometryUtilities = TangramGeometryUtilities.self
        self.dataConverter = PuzzleDataConverter.self
        
        // Initialize core services
        self.pieceValidator = TangramPieceValidator()
        // gameplayService and positioningService removed
        self.hintEngine = TangramHintEngine()
        self.mappingService = TangramRelativeMappingService()
        
        // Initialize data services
        self.databaseLoader = TangramDatabaseLoader(supabaseService: supabaseService)
        self.puzzleLibraryService = PuzzleLibraryService(supabaseService: supabaseService)
    }
    
    // MARK: - Factory Methods
    
    /// Creates a configured TangramGameViewModel
    func makeGameViewModel(delegate: GameDelegate) -> TangramGameViewModel {
        return TangramGameViewModel(
            delegate: delegate,
            container: self
        )
    }
    
    /// Creates a configured PuzzleSelectionViewModel
    func makePuzzleSelectionViewModel(
        onPuzzleSelected: @escaping (Any) -> Void,
        onBackToLobby: (() -> Void)? = nil
    ) -> PuzzleSelectionViewModel {
        return PuzzleSelectionViewModel(
            libraryService: puzzleLibraryService,
            onPuzzleSelected: { puzzle in
                // The library service already returns GamePuzzleData, so just pass it through
                // If we ever need to handle TangramPuzzle conversion, we can add that later
                onPuzzleSelected(puzzle)
            },
            onBackToLobby: onBackToLobby
        )
    }
}