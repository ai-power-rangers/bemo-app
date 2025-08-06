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
    
    // MARK: - Services (Lazy for efficiency)
    
    lazy var coordinator: TangramEditorCoordinator = {
        return TangramEditorCoordinator()
    }()
    
    lazy var placementService: PiecePlacementService = {
        return PiecePlacementService()
    }()
    
    lazy var persistenceService: PuzzlePersistenceService = {
        return PuzzlePersistenceService()
    }()
    
    lazy var undoManager: UndoRedoManager = {
        return UndoRedoManager()
    }()
    
    lazy var validationService: ValidationService = {
        return ValidationService()
    }()
    
    // MARK: - Initialization
    
    init() {
        // Services are lazy-loaded, so nothing to initialize here
        // This ensures services are only created when actually needed
    }
    
    // MARK: - Factory Method
    
    /// Creates a properly configured ViewModel with all dependencies injected
    func makeViewModel(puzzle: TangramPuzzle? = nil) -> TangramEditorViewModel {
        return TangramEditorViewModel(
            puzzle: puzzle,
            coordinator: coordinator,
            placementService: placementService,
            persistenceService: persistenceService,
            undoManager: undoManager,
            validationService: validationService
        )
    }
}