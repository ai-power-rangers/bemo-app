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
    
    /// Progress service for tracking child progress
    let progressService: TangramProgressService
    
    /// Data converter for puzzle format transformations
    let dataConverter: PuzzleDataConverter.Type
    
    // MARK: - Utilities
    
    /// Geometry utilities for calculations
    let geometryUtilities: TangramGeometryUtilities.Type
    
    // MARK: - External Dependencies
    
    let supabaseService: SupabaseService?
    let puzzleManagementService: PuzzleManagementService?
    let learningService: LearningService?

    /// Relative mapping service for anchor-based validation shared by Scene and ViewModel
    let mappingService: TangramRelativeMappingService
    
    /// Unified validation engine - single source of truth for all validation
    let validationEngine: TangramValidationEngine
    
    // MARK: - Initialization
    
    init(
        supabaseService: SupabaseService? = nil,
        puzzleManagementService: PuzzleManagementService? = nil,
        learningService: LearningService? = nil
    ) {
        self.supabaseService = supabaseService
        self.puzzleManagementService = puzzleManagementService
        self.learningService = learningService
        
        // Initialize utilities
        self.geometryUtilities = TangramGeometryUtilities.self
        self.dataConverter = PuzzleDataConverter.self
        
        // Initialize core services with default tolerances; scene/viewmodel can replace if difficulty override applies
        self.pieceValidator = TangramPieceValidator()
        // gameplayService and positioningService removed
        self.hintEngine = TangramHintEngine()
        self.mappingService = TangramRelativeMappingService()
        
        // Initialize unified validation engine with default difficulty (map to .normal)
        self.validationEngine = TangramValidationEngine(difficulty: .normal)
        
        // Initialize data services
        self.databaseLoader = TangramDatabaseLoader(supabaseService: supabaseService)
        self.puzzleLibraryService = PuzzleLibraryService(supabaseService: supabaseService)
        
        // Initialize progress service
        self.progressService = TangramProgressService(userDefaults: .standard, supabaseService: supabaseService)
    }
    
    // MARK: - Factory Methods
    
    /// Creates a configured TangramGameViewModel
    func makeGameViewModel(delegate: GameDelegate) -> TangramGameViewModel {
        return TangramGameViewModel(
            delegate: delegate,
            container: self,
            learningService: learningService
        )
    }
    
    // Removed PuzzleSelectionViewModel factory to reduce duplicate selection paths
}
