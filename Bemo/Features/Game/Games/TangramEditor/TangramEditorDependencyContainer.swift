//
//  TangramEditorDependencyContainer.swift
//  Bemo
//
//  Local dependency container for Tangram Editor services
//

// WHAT: Service locator that creates and holds all Tangram Editor-specific services. Ensures single instances and proper dependency injection.
// ARCHITECTURE: Local dependency container pattern following MVVM-S. Created by TangramEditorGame and provides services to TangramEditorViewModel.
// USAGE: Created once per editor session. Services are lazy-loaded to avoid unnecessary initialization. Pass to ViewModel on creation.

import Foundation

@MainActor
class TangramEditorDependencyContainer {
    
    // MARK: - External Dependencies
    
    private let supabaseService: SupabaseService?
    private let puzzleManagementService: PuzzleManagementService?
    
    // MARK: - Services (Lazy for efficiency)
    
    lazy var transformEngine: PieceTransformEngine = {
        return PieceTransformEngine()
    }()
    
    lazy var coordinator: TangramEditorCoordinator = {
        return TangramEditorCoordinator()
    }()
    
    lazy var placementService: PiecePlacementService = {
        return PiecePlacementService()
    }()
    
    lazy var persistenceService: PuzzlePersistenceService = {
        return PuzzlePersistenceService(supabaseService: supabaseService)
    }()
    
    lazy var undoManager: UndoRedoManager = {
        return UndoRedoManager()
    }()
    
    lazy var manipulationService: PieceManipulationService = {
        return PieceManipulationService()
    }()
    
    lazy var toastService: ToastService = {
        return ToastService()
    }()
    
    lazy var stateManager: TangramEditorStateMachine = {
        return TangramEditorStateMachine()
    }()
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService? = nil, puzzleManagementService: PuzzleManagementService? = nil) {
        self.supabaseService = supabaseService
        self.puzzleManagementService = puzzleManagementService
        print("[TangramEditorDependencyContainer] Initialized with SupabaseService: \(supabaseService != nil ? "✅" : "❌ nil")")
        print("[TangramEditorDependencyContainer] Initialized with PuzzleManagementService: \(puzzleManagementService != nil ? "✅" : "❌ nil")")
        // Services are lazy-loaded, so nothing else to initialize here
        // This ensures services are only created when actually needed
    }
    
    // MARK: - Factory Method
    
    /// Creates a properly configured ViewModel with all dependencies injected
    func makeViewModel(puzzle: TangramPuzzle? = nil) -> TangramEditorViewModel {
        return TangramEditorViewModel(
            puzzle: puzzle,
            transformEngine: transformEngine,
            coordinator: coordinator,
            placementService: placementService,
            persistenceService: persistenceService,
            undoManager: undoManager,
            manipulationService: manipulationService,
            stateManager: stateManager,
            toastService: toastService,
            puzzleManagementService: puzzleManagementService
        )
    }
}