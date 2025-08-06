//
//  PuzzleLibraryService.swift
//  Bemo
//
//  Service for loading and managing Tangram puzzles for gameplay
//

// WHAT: Loads bundled tangram puzzles and provides them for gameplay selection
// ARCHITECTURE: Service in MVVM-S pattern, reuses TangramEditor's persistence infrastructure
// USAGE: Injected into PuzzleSelectionViewModel to provide available puzzles

import SwiftUI
import Observation

@Observable
class PuzzleLibraryService {
    
    // MARK: - Observable State
    
    private(set) var availablePuzzles: [TangramPuzzle] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    
    // MARK: - Dependencies
    
    private let persistenceService: PuzzlePersistenceService
    
    // MARK: - Computed Properties
    
    var categories: [PuzzleCategory] {
        Array(Set(availablePuzzles.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }
    
    var difficulties: [PuzzleDifficulty] {
        Array(Set(availablePuzzles.map { $0.difficulty })).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService? = nil) {
        self.persistenceService = PuzzlePersistenceService(supabaseService: supabaseService)
        loadPuzzles()
    }
    
    // MARK: - Puzzle Loading
    
    func loadPuzzles() {
        isLoading = true
        loadError = nil
        
        Task {
            do {
                // Load all puzzles (bundled and user)
                let allPuzzles = try await persistenceService.loadAllPuzzles()
                
                await MainActor.run {
                    // Use all loaded puzzles
                    self.availablePuzzles = allPuzzles
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.loadError = "Failed to load puzzles: \(error.localizedDescription)"
                    self.isLoading = false
                    
                    // Load some default puzzles as fallback
                    self.availablePuzzles = createFallbackPuzzles()
                }
            }
        }
    }
    
    // MARK: - Puzzle Filtering
    
    func puzzles(
        category: PuzzleCategory? = nil,
        difficulty: PuzzleDifficulty? = nil,
        searchText: String = ""
    ) -> [TangramPuzzle] {
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
    
    // MARK: - Thumbnail Management
    
    func thumbnailImage(for puzzle: TangramPuzzle) -> Image? {
        if let thumbnailData = persistenceService.loadThumbnail(for: puzzle.id),
           let uiImage = UIImage(data: thumbnailData) {
            return Image(uiImage: uiImage)
        }
        return nil
    }
    
    func thumbnailColor(for puzzle: TangramPuzzle) -> Color {
        // Return a color based on category
        switch puzzle.category {
        case .animals:
            return .green
        case .geometric:
            return .blue
        case .objects:
            return .orange
        case .people:
            return .purple
        case .letters:
            return .red
        case .numbers:
            return .cyan
        case .abstract:
            return .pink
        case .custom:
            return .gray
        }
    }
    
    // MARK: - Fallback Data
    
    private func createFallbackPuzzles() -> [TangramPuzzle] {
        // Create a few basic puzzles as fallback if loading fails
        [
            TangramPuzzle(
                name: "Basic Square",
                category: .geometric,
                difficulty: .easy,
                source: .bundled
            ),
            TangramPuzzle(
                name: "Simple House",
                category: .objects,
                difficulty: .easy,
                source: .bundled
            ),
            TangramPuzzle(
                name: "Cat",
                category: .animals,
                difficulty: .medium,
                source: .bundled
            )
        ]
    }
}