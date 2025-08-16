//
//  DifficultySelectionViewModel.swift
//  Bemo
//
//  ViewModel for difficulty selection screen with progress tracking and recommendations
//

// WHAT: Manages difficulty selection UI state and user interactions
// ARCHITECTURE: ViewModel in MVVM-S pattern - handles presentation logic for difficulty selection
// USAGE: Inject with progress and puzzle services, handles difficulty selection and routing

import Foundation
import Observation

@Observable
class DifficultySelectionViewModel {
    
    // MARK: - Dependencies
    private let progressService: TangramProgressService
    private let puzzleLibraryService: PuzzleLibraryProviding
    private let onDifficultySelected: (UserPreferences.DifficultySetting) -> Void
    
    // MARK: - Observable Properties
    var isLoading: Bool = true
    var errorMessage: String?
    var childProfileId: String
    
    // MARK: - Difficulty State
    var availableDifficulties: [UserPreferences.DifficultySetting] = UserPreferences.DifficultySetting.allCases
    var difficultyStats: [UserPreferences.DifficultySetting: DifficultyStats] = [:]
    var recommendedDifficulty: UserPreferences.DifficultySetting?
    var lastSelectedDifficulty: UserPreferences.DifficultySetting?
    
    // MARK: - Helper Types
    struct DifficultyStats {
        let totalPuzzles: Int
        let completedPuzzles: Int
        let isUnlocked: Bool
        let completionPercentage: Double
        
        init(totalPuzzles: Int, completedPuzzles: Int, isUnlocked: Bool = true) {
            self.totalPuzzles = totalPuzzles
            self.completedPuzzles = completedPuzzles
            self.isUnlocked = isUnlocked
            self.completionPercentage = totalPuzzles > 0 ? 
                Double(completedPuzzles) / Double(totalPuzzles) * TangramGameConstants.DifficultyProgression.percentageMultiplier : 0.0
        }
    }
    
    // MARK: - Initialization
    init(
        childProfileId: String,
        progressService: TangramProgressService,
        puzzleLibraryService: PuzzleLibraryProviding,
        onDifficultySelected: @escaping (UserPreferences.DifficultySetting) -> Void
    ) {
        self.childProfileId = childProfileId
        self.progressService = progressService
        self.puzzleLibraryService = puzzleLibraryService
        self.onDifficultySelected = onDifficultySelected
        
        // Load data asynchronously
        Task {
            await loadDifficultyData()
        }
    }
    
    // MARK: - Core Methods
    
    /// Load difficulty data and compute stats for the current child
    @MainActor
    func loadDifficultyData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current progress for child
            let progress = progressService.getProgress(for: childProfileId)
            lastSelectedDifficulty = progress.lastSelectedDifficulty
            
            // Load all puzzles
            let allPuzzles = try await puzzleLibraryService.loadPuzzles()
            
            // Calculate stats for each difficulty
            await calculateDifficultyStats(from: allPuzzles, progress: progress)
            
            // Determine recommended difficulty
            recommendedDifficulty = determineRecommendedDifficulty(progress: progress)
            
            isLoading = false
            
        } catch {
            errorMessage = "Failed to load difficulty data: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Handle difficulty selection
    func selectDifficulty(_ difficulty: UserPreferences.DifficultySetting) {
        guard canSelectDifficulty(difficulty) else {
            errorMessage = "This difficulty is not yet unlocked"
            return
        }
        
        // Update progress service with selection
        progressService.setLastSelectedDifficulty(childId: childProfileId, difficulty: difficulty)
        
        // Trigger callback to navigate
        onDifficultySelected(difficulty)
    }
    
    /// Check if a difficulty can be selected
    func canSelectDifficulty(_ difficulty: UserPreferences.DifficultySetting) -> Bool {
        return difficultyStats[difficulty]?.isUnlocked ?? false
    }
    
    /// Check if a difficulty is recommended
    func isDifficultyRecommended(_ difficulty: UserPreferences.DifficultySetting) -> Bool {
        return recommendedDifficulty == difficulty
    }
    
    /// Get description text for a difficulty
    func getDifficultyDescription(_ difficulty: UserPreferences.DifficultySetting) -> String {
        switch difficulty {
        case .easy:
            return "Perfect for beginners (1-2 star puzzles)"
        case .normal:
            return "Ready for a challenge? (3-4 star puzzles)"
        case .hard:
            return "Expert level (5 star puzzles)"
        }
    }
    
    /// Get formatted progress text for a difficulty
    func getProgressText(for difficulty: UserPreferences.DifficultySetting) -> String {
        guard let stats = difficultyStats[difficulty] else {
            return "Loading..."
        }
        
        if stats.totalPuzzles == 0 {
            return "No puzzles available"
        }
        
        return "\(stats.completedPuzzles) of \(stats.totalPuzzles) completed"
    }
    
    /// Get completion percentage for progress bars
    func getCompletionPercentage(for difficulty: UserPreferences.DifficultySetting) -> Double {
        return difficultyStats[difficulty]?.completionPercentage ?? 0.0
    }
    
    // MARK: - Private Helper Methods
    
    /// Calculate statistics for each difficulty based on progress and available puzzles
    private func calculateDifficultyStats(from allPuzzles: [GamePuzzleData], progress: TangramProgress) async {
        let newStats: [UserPreferences.DifficultySetting: DifficultyStats] = await withTaskGroup(of: (UserPreferences.DifficultySetting, DifficultyStats).self) { group in
            var stats: [UserPreferences.DifficultySetting: DifficultyStats] = [:]
            
            for difficulty in availableDifficulties {
                group.addTask {
                    let puzzlesForDifficulty = self.getPuzzlesForDifficulty(difficulty, from: allPuzzles)
                    let completedPuzzles = progress.getCompletedCount(for: difficulty)
                    let isUnlocked = self.isDifficultyUnlocked(difficulty, progress: progress, allPuzzles: allPuzzles)
                    
                    let difficultyStats = DifficultyStats(
                        totalPuzzles: puzzlesForDifficulty.count,
                        completedPuzzles: completedPuzzles,
                        isUnlocked: isUnlocked
                    )
                    
                    return (difficulty, difficultyStats)
                }
            }
            
            for await (difficulty, difficultyStats) in group {
                stats[difficulty] = difficultyStats
            }
            
            return stats
        }
        
        await MainActor.run {
            self.difficultyStats = newStats
        }
    }
    
    /// Get puzzles that belong to a specific difficulty level
    private func getPuzzlesForDifficulty(_ difficulty: UserPreferences.DifficultySetting, from puzzles: [GamePuzzleData]) -> [GamePuzzleData] {
        return puzzles.filter { puzzle in
            difficulty.containsPuzzleLevel(puzzle.difficulty)
        }.sorted { $0.id < $1.id } // Sort by ID for consistent ordering
    }
    
    /// Determine if a difficulty should be unlocked for the current user
    private func isDifficultyUnlocked(_ difficulty: UserPreferences.DifficultySetting, progress: TangramProgress, allPuzzles: [GamePuzzleData]) -> Bool {
        let easyCompleted = progress.getCompletedCount(for: UserPreferences.DifficultySetting.easy)
        let mediumCompleted = progress.getCompletedCount(for: UserPreferences.DifficultySetting.normal)
        
        // Calculate mediumTotal directly from puzzle data instead of relying on difficultyStats
        let mediumPuzzles = getPuzzlesForDifficulty(.normal, from: allPuzzles)
        let mediumTotal = mediumPuzzles.count
        
        return TangramGameConstants.DifficultyProgression.isDifficultyUnlocked(
            difficulty,
            easyCompleted: easyCompleted,
            mediumCompleted: mediumCompleted,
            mediumTotal: mediumTotal
        )
    }
    
    /// Determine which difficulty should be recommended to the user
    private func determineRecommendedDifficulty(progress: TangramProgress) -> UserPreferences.DifficultySetting {
        // If user has a last selected difficulty and it's not completed, recommend it
        if let lastSelected = progress.lastSelectedDifficulty,
           let stats = difficultyStats[lastSelected],
           stats.completionPercentage < 100.0 && stats.isUnlocked {
            return lastSelected
        }
        
        // Find the next logical difficulty to work on
        for difficulty in [UserPreferences.DifficultySetting.easy, .normal, .hard] {
            guard let stats = difficultyStats[difficulty], stats.isUnlocked else { continue }
            
            // Recommend if not completed
            if stats.completionPercentage < 100.0 {
                return difficulty
            }
        }
        
        // Default to easy for new users
        return .easy
    }
    
    // MARK: - Public Computed Properties
    
    /// Check if this appears to be a new user (no progress in any difficulty)
    var isNewUser: Bool {
        return difficultyStats.values.allSatisfy { $0.completedPuzzles == 0 }
    }
    
    /// Get total progress across all difficulties
    var overallProgress: Double {
        let totalPuzzles = difficultyStats.values.reduce(0) { $0 + $1.totalPuzzles }
        let completedPuzzles = difficultyStats.values.reduce(0) { $0 + $1.completedPuzzles }
        
        return totalPuzzles > 0 ? 
            Double(completedPuzzles) / Double(totalPuzzles) * TangramGameConstants.DifficultyProgression.percentageMultiplier : 0.0
    }
}


