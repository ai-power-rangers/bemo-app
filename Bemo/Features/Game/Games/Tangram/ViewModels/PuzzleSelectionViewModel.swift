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

enum ChildDifficultyMode {
    case `default`
    case easy
    case medium
    case hard
}

@Observable
class PuzzleSelectionViewModel {
    
    // MARK: - Observable State
    
    var selectedCategory: String?
    var selectedDifficulty: Int?
    var searchText: String = ""
    var isGridView: Bool = true
    var childDifficultyMode: ChildDifficultyMode = .default
    
    // MARK: - Dependencies
    
    private let libraryService: PuzzleLibraryService
    private let onPuzzleSelected: (GamePuzzleData) -> Void
    private let onBackToLobby: (() -> Void)?
    
    // MARK: - Computed Properties
    
    var filteredPuzzles: [GamePuzzleData] {
        libraryService.puzzles(
            category: selectedCategory,
            difficulty: selectedDifficulty,
            searchText: searchText
        )
    }
    
    var availableCategories: [String] {
        libraryService.categories
    }
    
    var availableDifficulties: [Int] {
        libraryService.difficulties
    }
    
    var isLoading: Bool {
        libraryService.isLoading
    }
    
    var hasNoPuzzles: Bool {
        !isLoading && filteredPuzzles.isEmpty
    }
    
    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedDifficulty != nil
    }
    
    var activeFilterCount: Int {
        var count = 0
        if selectedCategory != nil { count += 1 }
        if selectedDifficulty != nil { count += 1 }
        return count
    }
    
    // MARK: - Initialization
    
    init(
        libraryService: PuzzleLibraryService,
        onPuzzleSelected: @escaping (GamePuzzleData) -> Void,
        onBackToLobby: (() -> Void)? = nil
    ) {
        self.libraryService = libraryService
        self.onPuzzleSelected = onPuzzleSelected
        self.onBackToLobby = onBackToLobby
    }
    
    // MARK: - Actions
    
    func selectPuzzle(_ puzzle: GamePuzzleData) {
        print("DEBUG: PuzzleSelectionViewModel.selectPuzzle called")
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
        print("DEBUG: PuzzleSelectionViewModel.backToLobby called")
        onBackToLobby?()
    }
    
    func thumbnailImage(for puzzle: GamePuzzleData) -> Image? {
        return libraryService.thumbnailImage(for: puzzle)
    }
    
    func thumbnailColor(for puzzle: GamePuzzleData) -> Color {
        // UI logic belongs in ViewModel, not in service
        switch puzzle.category {
        case "animals":
            return .green
        case "geometric":
            return .blue
        case "objects":
            return .orange
        case "people":
            return .purple
        case "letters":
            return .red
        case "numbers":
            return .cyan
        case "abstract":
            return .pink
        default:
            return .gray
        }
    }
    
    // MARK: - Display Helpers
    
    func difficultyColor(_ difficulty: Int) -> Color {
        switch difficulty {
        case 1:
            return .teal
        case 2:
            return .green
        case 3:
            return .orange
        case 4:
            return .red
        case 5:
            return .purple
        default:
            return .gray
        }
    }
    
    func difficultyIcon(_ difficulty: Int) -> String {
        switch difficulty {
        case 1:
            return "star.circle.fill"
        case 2:
            return "1.circle.fill"
        case 3:
            return "2.circle.fill"
        case 4:
            return "3.circle.fill"
        case 5:
            return "4.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    func categoryIcon(_ category: String) -> String {
        switch category {
        case "animals":
            return "pawprint.fill"
        case "geometric":
            return "square.on.square"
        case "objects":
            return "cube.fill"
        case "people":
            return "person.fill"
        case "letters":
            return "textformat"
        case "numbers":
            return "number"
        case "abstract":
            return "sparkles"
        default:
            return "star.fill"
        }
    }
}