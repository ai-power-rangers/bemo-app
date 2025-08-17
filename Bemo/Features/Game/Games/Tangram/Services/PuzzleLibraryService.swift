//
//  PuzzleLibraryService.swift
//  Bemo
//
//  Service for loading and managing Tangram puzzles for gameplay
//

// WHAT: Loads puzzles for gameplay using PuzzleManagementService
// ARCHITECTURE: Service in MVVM-S pattern, uses shared PuzzleManagementService
// USAGE: Injected into game components to provide available puzzles

import SwiftUI
import Observation

@Observable
class PuzzleLibraryService {
    
    // MARK: - Observable State
    
    private(set) var availablePuzzles: [GamePuzzleData] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    
    // MARK: - Dependencies
    
    private let puzzleManagementService: PuzzleManagementService?
    private let databaseLoader: TangramDatabaseLoader
    
    // MARK: - Computed Properties
    
    var categories: [String] {
        Array(Set(availablePuzzles.map { $0.category })).sorted()
    }
    
    var difficulties: [Int] {
        Array(Set(availablePuzzles.map { $0.difficulty })).sorted()
    }
    
    // MARK: - Initialization
    
    init(puzzleManagementService: PuzzleManagementService? = nil, supabaseService: SupabaseService? = nil) {
        self.puzzleManagementService = puzzleManagementService
        self.databaseLoader = TangramDatabaseLoader(supabaseService: supabaseService)
        loadPuzzles()
    }
    
    // MARK: - Puzzle Loading
    
    func loadPuzzles() {
        isLoading = true
        loadError = nil
        
        Task {
            do {
                // Try to use cached puzzles first
                if let managementService = puzzleManagementService {
                    let puzzles = await managementService.getTangramPuzzles()
                    await MainActor.run {
                        self.availablePuzzles = puzzles
                        self.isLoading = false
                        print("[PuzzleLibraryService] Loaded \(puzzles.count) puzzles from cache")
                    }
                } else {
                    // Fallback to direct database loading
                    let puzzles = try await databaseLoader.loadOfficialPuzzles()
                    await MainActor.run {
                        self.availablePuzzles = puzzles
                        self.isLoading = false
                        print("[PuzzleLibraryService] Loaded \(puzzles.count) puzzles from database")
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = "Failed to load puzzles: \(error.localizedDescription)"
                    self.isLoading = false
                    self.availablePuzzles = []
                    print("[PuzzleLibraryService] Failed to load puzzles: \(error)")
                }
            }
        }
    }
    
    /// Force refresh puzzles from cache (called after editor saves)
    func refreshPuzzles() {
        print("[PuzzleLibraryService] Refreshing puzzles...")
        loadPuzzles()
    }
    
    // MARK: - Puzzle Filtering
    
    func puzzles(
        category: String? = nil,
        difficulty: Int? = nil,
        searchText: String = ""
    ) -> [GamePuzzleData] {
        var filtered = availablePuzzles
        
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let difficulty = difficulty {
            filtered = filtered.filter { $0.difficulty == difficulty }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { puzzle in
                puzzle.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { $0.name < $1.name }
    }
    
    /// Get puzzles for a specific difficulty band, sorted by database ID for map progression
    /// - Parameter difficulty: The difficulty setting (easy/normal/hard)
    /// - Returns: Puzzles filtered by difficulty and sorted by ID for sequential unlock
    func puzzlesForDifficulty(_ difficulty: UserPreferences.DifficultySetting) -> [GamePuzzleData] {
        return availablePuzzles
            .filter { puzzle in 
                difficulty.containsPuzzleLevel(puzzle.difficulty)
            }
            .sorted { $0.id < $1.id } // Sort by Supabase ID for map order
    }
    
    /// Get puzzles sorted by different criteria
    /// - Parameter sortBy: The sorting criteria to use
    /// - Returns: All puzzles sorted by the specified criteria
    func sortedPuzzles(by sortBy: PuzzleSortCriteria) -> [GamePuzzleData] {
        switch sortBy {
        case .id:
            return availablePuzzles.sorted { $0.id < $1.id }
        case .name:
            return availablePuzzles.sorted { $0.name < $1.name }
        case .difficulty:
            return availablePuzzles.sorted { $0.difficulty < $1.difficulty }
        case .category:
            return availablePuzzles.sorted { $0.category < $1.category }
        }
    }
    
    /// Sorting criteria for puzzle lists
    enum PuzzleSortCriteria {
        case id         // Sort by database ID
        case name       // Sort alphabetically by name
        case difficulty // Sort by star difficulty (1-5)
        case category   // Sort alphabetically by category
    }
    
    // MARK: - Thumbnail Management
    
    func thumbnailImage(for puzzle: GamePuzzleData) -> Image? {
        // For now, return nil - thumbnails would need to be stored separately
        // or retrieved from a service
        return nil
    }
    
    
}

// MARK: - Protocol Conformance

extension PuzzleLibraryService: PuzzleLibraryProviding {
    func loadPuzzles() async throws -> [GamePuzzleData] {
        // Use puzzle management service or database loader
        if let managementService = puzzleManagementService {
            return await managementService.getTangramPuzzles()
        } else {
            return try await databaseLoader.loadOfficialPuzzles()
        }
    }
    
    func savePuzzle(_ puzzle: GamePuzzleData) async throws {
        // Game doesn't save puzzles - that's only done in the editor
        throw NSError(domain: "PuzzleLibraryService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Saving puzzles is not supported in the game"])
    }
    
    func deletePuzzle(id: String) async throws {
        // Game doesn't delete puzzles - that's only done in the editor  
        throw NSError(domain: "PuzzleLibraryService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Deleting puzzles is not supported in the game"])
    }
}