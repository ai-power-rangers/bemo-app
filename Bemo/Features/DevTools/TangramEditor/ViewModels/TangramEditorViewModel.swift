//
//  TangramEditorViewModel.swift
//  Bemo
//
//  ViewModel for Tangram Editor - Coordinates UI state and business logic
//

import Foundation
import SwiftUI
import Observation
import OSLog

@Observable
@MainActor
class TangramEditorViewModel {
    
    // MARK: - Type Aliases
    typealias ConnectionPoint = PiecePlacementService.ConnectionPoint
    
    // MARK: - Core State
    
    var puzzle: TangramPuzzle
    var originalPuzzleData: Data? = nil  // To track if changes were made
    var savedPuzzles: [TangramPuzzle] = []
    var validationState: ValidationState = .unknown
    var availableConnectionPoints: [ConnectionPoint] = []
    var pieceManipulationModes: [String: ManipulationMode] = [:]  // PieceId -> Mode
    
    var hasUnsavedChanges: Bool {
        // Compare current puzzle with original to detect changes
        guard let originalData = originalPuzzleData else {
            // If no original data, check if puzzle has any pieces
            return !puzzle.pieces.isEmpty
        }
        
        // Encode current puzzle and compare
        if let currentData = try? JSONEncoder().encode(puzzle) {
            return currentData != originalData
        }
        
        return true // Assume changes if we can't encode
    }
    
    // MARK: - UI State
    
    var uiState = TangramEditorUIState()
    
    // State is managed by stateManager - make it observable directly
    var editorState: EditorState = .idle {
        didSet {
            Logger.tangramEditorState.debug("State changed from \(oldValue.description) to \(self.editorState.description)")
        }
    }
    var currentStateDescription: String { stateManager.stateDescription }
    
    // Error handling
    var currentError: TangramEditorError? = nil
    
    // Delegate
    weak var delegate: DevToolDelegate?
    var onPuzzleChanged: ((TangramPuzzle) -> Void)?
    
    // MARK: - Services (Dependency Injection)
    
    let transformEngine: PieceTransformEngine
    let coordinator: TangramEditorCoordinator
    let placementService: PiecePlacementService
    let persistenceService: PuzzlePersistenceService
    let undoManager: UndoRedoManager
    let manipulationService: PieceManipulationService
    let stateManager: TangramEditorStateMachine
    let toastService: ToastService
    let puzzleManagementService: PuzzleManagementService?
    
    // MARK: - Dynamic Manipulation Constraints
    var manipulationConstraints: [String: ManipulationConstraints] = [:]
    var initialManipulationTransforms: [String: CGAffineTransform] = [:]  // Store initial transform when starting manipulation
    
    struct ManipulationConstraints {
        var rotationLimits: (min: Double, max: Double)?
        var slideLimits: ClosedRange<Double>?
    }
    
    // MARK: - Initialization
    
    init(puzzle: TangramPuzzle? = nil,
         transformEngine: PieceTransformEngine,
         coordinator: TangramEditorCoordinator,
         placementService: PiecePlacementService,
         persistenceService: PuzzlePersistenceService,
         undoManager: UndoRedoManager,
         manipulationService: PieceManipulationService,
         stateManager: TangramEditorStateMachine,
         toastService: ToastService,
         puzzleManagementService: PuzzleManagementService? = nil) {
        
        // Initialize services
        self.transformEngine = transformEngine
        self.coordinator = coordinator
        self.placementService = placementService
        self.persistenceService = persistenceService
        self.undoManager = undoManager
        self.manipulationService = manipulationService
        self.stateManager = stateManager
        self.toastService = toastService
        self.puzzleManagementService = puzzleManagementService
        
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
        Logger.tangramEditor.error("Error occurred: \(error.localizedDescription)")
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