//
//  PuzzleSelectionViewModel.swift
//  Bemo
//
//  ViewModel for puzzle selection screen in Tangram game
//

// WHAT: Manages puzzle selection state, filtering, and user interactions
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses PuzzleLibraryService for data
// USAGE: Created by TangramGameViewModel, handles puzzle browsing and selection

import SwiftUI
import Observation

@Observable
class PuzzleSelectionViewModel {
    
    // MARK: - Observable State
    
    var selectedCategory: PuzzleCategory?
    var selectedDifficulty: PuzzleDifficulty?
    var searchText: String = ""
    var isGridView: Bool = true
    
    // MARK: - Dependencies
    
    private let libraryService: PuzzleLibraryService
    private let onPuzzleSelected: (TangramPuzzle) -> Void
    private let onBackToLobby: (() -> Void)?
    
    // MARK: - Computed Properties
    
    var filteredPuzzles: [TangramPuzzle] {
        libraryService.puzzles(
            category: selectedCategory,
            difficulty: selectedDifficulty,
            searchText: searchText
        )
    }
    
    var availableCategories: [PuzzleCategory] {
        libraryService.categories
    }
    
    var availableDifficulties: [PuzzleDifficulty] {
        libraryService.difficulties
    }
    
    var isLoading: Bool {
        libraryService.isLoading
    }
    
    var hasNoPuzzles: Bool {
        !isLoading && filteredPuzzles.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        libraryService: PuzzleLibraryService,
        onPuzzleSelected: @escaping (TangramPuzzle) -> Void,
        onBackToLobby: (() -> Void)? = nil
    ) {
        self.libraryService = libraryService
        self.onPuzzleSelected = onPuzzleSelected
        self.onBackToLobby = onBackToLobby
    }
    
    // MARK: - Actions
    
    func selectPuzzle(_ puzzle: TangramPuzzle) {
        onPuzzleSelected(puzzle)
    }
    
    func clearFilters() {
        selectedCategory = nil
        selectedDifficulty = nil
        searchText = ""
    }
    
    func toggleViewMode() {
        isGridView.toggle()
    }
    
    func backToLobby() {
        onBackToLobby?()
    }
    
    func thumbnailImage(for puzzle: TangramPuzzle) -> Image? {
        libraryService.thumbnailImage(for: puzzle)
    }
    
    func thumbnailColor(for puzzle: TangramPuzzle) -> Color {
        libraryService.thumbnailColor(for: puzzle)
    }
    
    // MARK: - Display Helpers
    
    func difficultyColor(_ difficulty: PuzzleDifficulty) -> Color {
        switch difficulty {
        case .beginner:
            return .teal
        case .easy:
            return .green
        case .medium:
            return .orange
        case .hard:
            return .red
        case .expert:
            return .purple
        }
    }
    
    func difficultyIcon(_ difficulty: PuzzleDifficulty) -> String {
        switch difficulty {
        case .beginner:
            return "star.circle.fill"
        case .easy:
            return "1.circle.fill"
        case .medium:
            return "2.circle.fill"
        case .hard:
            return "3.circle.fill"
        case .expert:
            return "4.circle.fill"
        }
    }
    
    func categoryIcon(_ category: PuzzleCategory) -> String {
        switch category {
        case .animals:
            return "pawprint.fill"
        case .geometric:
            return "square.on.square"
        case .objects:
            return "cube.fill"
        case .people:
            return "person.fill"
        case .letters:
            return "textformat"
        case .numbers:
            return "number"
        case .abstract:
            return "sparkles"
        case .custom:
            return "star.fill"
        }
    }
}