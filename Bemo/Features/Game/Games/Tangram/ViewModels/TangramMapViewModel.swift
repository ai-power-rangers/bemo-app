//
//  TangramMapViewModel.swift
//  Bemo
//
//  ViewModel for the tangram puzzle map - manages puzzle progression and unlocks
//

// WHAT: Manages map view state, puzzle unlocking, and user progression within a difficulty level
// ARCHITECTURE: ViewModel in MVVM-S pattern with Observable support
// USAGE: Inject with puzzle library and progress services, handles map navigation logic

import Foundation
import Observation

@Observable
class TangramMapViewModel {
    
    // MARK: - Dependencies
    
    private let puzzleLibraryService: PuzzleLibraryService
    private let progressService: TangramProgressService
    private let onPuzzleSelected: (GamePuzzleData) -> Void
    private let onBackToDifficulty: () -> Void
    
    // MARK: - Observable Properties
    
    /// Current difficulty being displayed
    private(set) var difficulty: UserPreferences.DifficultySetting
    
    /// All puzzles for this difficulty, sorted by ID
    private(set) var puzzles: [GamePuzzleData] = []
    
    /// Set of puzzle IDs that are unlocked for play
    private(set) var unlockedPuzzleIds: Set<String> = []
    
    /// Current puzzle index (0-based) - represents progression within this difficulty
    private(set) var currentPuzzleIndex: Int = 0
    
    /// Loading state
    private(set) var isLoading: Bool = false
    
    /// Error message if puzzle loading fails
    private(set) var errorMessage: String?
    
    /// Child profile ID for progress tracking
    private let childProfileId: String
    
    // MARK: - Computed Properties
    
    /// The next puzzle that should be unlocked/played
    var nextPuzzle: GamePuzzleData? {
        guard currentPuzzleIndex < puzzles.count else { return nil }
        return puzzles[currentPuzzleIndex]
    }
    
    /// Current completion percentage for this difficulty (0.0 to 1.0)
    var completionPercentage: Double {
        guard !puzzles.isEmpty else { return 0.0 }
        let completedCount = puzzles.filter { unlockedPuzzleIds.contains($0.id) && isCompleted($0.id) }.count
        return Double(completedCount) / Double(puzzles.count)
    }
    
    /// Number of completed puzzles in this difficulty
    var completedCount: Int {
        puzzles.filter { unlockedPuzzleIds.contains($0.id) && isCompleted($0.id) }.count
    }
    
    /// Total number of puzzles in this difficulty
    var totalCount: Int {
        puzzles.count
    }
    
    /// Whether all puzzles in this difficulty are completed
    var isAllCompleted: Bool {
        !puzzles.isEmpty && completedCount == totalCount
    }
    
    // MARK: - Initialization
    
    init(
        difficulty: UserPreferences.DifficultySetting,
        childProfileId: String,
        puzzleLibraryService: PuzzleLibraryService,
        progressService: TangramProgressService,
        onPuzzleSelected: @escaping (GamePuzzleData) -> Void,
        onBackToDifficulty: @escaping () -> Void
    ) {
        self.difficulty = difficulty
        self.childProfileId = childProfileId
        self.puzzleLibraryService = puzzleLibraryService
        self.progressService = progressService
        self.onPuzzleSelected = onPuzzleSelected
        self.onBackToDifficulty = onBackToDifficulty
        
        // Load puzzles on initialization
        loadPuzzlesForDifficulty()
    }
    
    // MARK: - Public Methods
    
    /// Load puzzles for the current difficulty
    func loadPuzzlesForDifficulty() {
        isLoading = true
        errorMessage = nil
        
        // Get puzzles filtered by difficulty and sorted by ID
        let filteredPuzzles = puzzleLibraryService.puzzlesForDifficulty(difficulty)
        
        if filteredPuzzles.isEmpty {
            errorMessage = "No puzzles found for \(difficulty.displayName) difficulty"
            isLoading = false
            return
        }
        
        puzzles = filteredPuzzles
        updateUnlockedPuzzles()
        updateCurrentPuzzleIndex()
        
        isLoading = false
        
        print("[TangramMapViewModel] Loaded \(puzzles.count) puzzles for \(difficulty.displayName)")
    }
    
    /// Check if a specific puzzle can be selected (is unlocked)
    /// - Parameter puzzle: The puzzle to check
    /// - Returns: True if the puzzle is unlocked and can be played
    func canSelectPuzzle(_ puzzle: GamePuzzleData) -> Bool {
        return unlockedPuzzleIds.contains(puzzle.id)
    }
    
    /// Select a puzzle for play
    /// - Parameter puzzle: The puzzle to select
    func selectPuzzle(_ puzzle: GamePuzzleData) {
        guard canSelectPuzzle(puzzle) else {
            print("[TangramMapViewModel] Cannot select locked puzzle: \(puzzle.id)")
            return
        }
        
        print("[TangramMapViewModel] Selected puzzle: \(puzzle.id)")
        onPuzzleSelected(puzzle)
    }
    
    /// Navigate back to difficulty selection
    func goBackToDifficulty() {
        print("[TangramMapViewModel] Navigating back to difficulty selection")
        onBackToDifficulty()
    }
    
    /// Refresh the map state (call after completing a puzzle)
    func refresh() {
        updateUnlockedPuzzles()
        updateCurrentPuzzleIndex()
    }
    
    /// Check if a puzzle is completed
    /// - Parameter puzzleId: The ID of the puzzle to check
    /// - Returns: True if the puzzle is completed
    func isCompleted(_ puzzleId: String) -> Bool {
        let progress = progressService.getProgress(for: childProfileId)
        return progress.isPuzzleCompleted(puzzleId: puzzleId, difficulty: difficulty)
    }
    
    /// Check if a puzzle is the current/next puzzle to be played
    /// - Parameter puzzle: The puzzle to check
    /// - Returns: True if this is the current puzzle in progression
    func isCurrentPuzzle(_ puzzle: GamePuzzleData) -> Bool {
        guard let nextPuzzle = nextPuzzle else { return false }
        return puzzle.id == nextPuzzle.id
    }
    
    // MARK: - Private Methods
    
    /// Update which puzzles are unlocked based on progress
    private func updateUnlockedPuzzles() {
        let progress = progressService.getProgress(for: childProfileId)
        unlockedPuzzleIds = Set(progressService.getUnlockedPuzzles(
            for: childProfileId, 
            difficulty: difficulty, 
            from: puzzles
        ).map { $0.id })
        
        print("[TangramMapViewModel] Updated unlocked puzzles: \(unlockedPuzzleIds.count)/\(puzzles.count)")
    }
    
    /// Update the current puzzle index based on progression
    private func updateCurrentPuzzleIndex() {
        // Find the first incomplete puzzle - this is our "current" position
        if let firstIncompleteIndex = puzzles.firstIndex(where: { !isCompleted($0.id) }) {
            currentPuzzleIndex = firstIncompleteIndex
        } else {
            // All puzzles completed - set to end of list
            currentPuzzleIndex = puzzles.count
        }
        
        print("[TangramMapViewModel] Current puzzle index: \(currentPuzzleIndex)/\(puzzles.count)")
    }
}

// MARK: - Map Node State

extension TangramMapViewModel {
    
    /// Get the display state for a puzzle node on the map
    /// - Parameter puzzle: The puzzle to get state for
    /// - Returns: Node state enum for UI rendering
    func getNodeState(for puzzle: GamePuzzleData) -> MapNodeState {
        if isCompleted(puzzle.id) {
            return .completed
        } else if canSelectPuzzle(puzzle) {
            return isCurrentPuzzle(puzzle) ? .current : .unlocked
        } else {
            return .locked
        }
    }
}


