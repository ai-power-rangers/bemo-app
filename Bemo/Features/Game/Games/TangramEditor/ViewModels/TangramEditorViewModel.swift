//
//  TangramEditorViewModel.swift
//  Bemo
//
//  ViewModel for Tangram Editor - Coordinates UI state and business logic
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class TangramEditorViewModel {
    
    // MARK: - Type Aliases
    typealias ConnectionPoint = PiecePlacementService.ConnectionPoint
    
    // MARK: - Core State
    
    var puzzle: TangramPuzzle
    var savedPuzzles: [TangramPuzzle] = []
    var validationState: ValidationState = .unknown
    var availableConnectionPoints: [ConnectionPoint] = []
    var pieceManipulationModes: [String: ManipulationMode] = [:]  // PieceId -> Mode
    
    // MARK: - UI State
    
    var uiState = TangramEditorUIState()
    
    // State is managed by stateManager - make it observable directly
    var editorState: EditorState = .idle {
        didSet {
            print("[STATE CHANGE] editorState changed from \(oldValue) to \(editorState)")
        }
    }
    var currentStateDescription: String { stateManager.stateDescription }
    
    // Error handling
    var currentError: TangramEditorError? = nil
    var showLibraryNavigationAlert: Bool = false
    
    // Delegate
    weak var delegate: GameDelegate?
    var onPuzzleChanged: ((TangramPuzzle) -> Void)?
    
    // MARK: - Services (Dependency Injection)
    
    let coordinator: TangramEditorCoordinator
    let placementService: PiecePlacementService
    let persistenceService: PuzzlePersistenceService
    let undoManager: UndoRedoManager
    let validationService: ValidationService
    let manipulationService: PieceManipulationService
    let stateManager: TangramEditorStateMachine
    let toastService: ToastService
    
    // MARK: - Initialization
    
    init(puzzle: TangramPuzzle? = nil,
         coordinator: TangramEditorCoordinator,
         placementService: PiecePlacementService,
         persistenceService: PuzzlePersistenceService,
         undoManager: UndoRedoManager,
         validationService: ValidationService,
         manipulationService: PieceManipulationService,
         stateManager: TangramEditorStateMachine,
         toastService: ToastService) {
        
        // Initialize services
        self.coordinator = coordinator
        self.placementService = placementService
        self.persistenceService = persistenceService
        self.undoManager = undoManager
        self.validationService = validationService
        self.manipulationService = manipulationService
        self.stateManager = stateManager
        self.toastService = toastService
        
        // Initialize puzzle
        self.puzzle = puzzle ?? TangramPuzzle(name: "New Puzzle")
        
        // Set initial state based on puzzle content
        stateManager.setInitialState(for: self.puzzle)
        self.editorState = stateManager.currentState
        
        // Load saved puzzles on init
        Task { [weak self] in
            await self?.loadSavedPuzzles()
        }
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: TangramEditorError) {
        currentError = error
        toastService.show(error: error)
        
        // Log error for debugging
        print("[TangramEditor] Error: \(error.errorDescription ?? "Unknown error")")
    }
    
    func dismissError() {
        toastService.dismiss()
        currentError = nil
    }
}

// All functionality is organized in extension files:
// - TangramEditorViewModel+PieceOperations.swift - Piece manipulation
// - TangramEditorViewModel+Persistence.swift - Save/load functionality  
// - TangramEditorViewModel+StateAndUI.swift - UI state and connections