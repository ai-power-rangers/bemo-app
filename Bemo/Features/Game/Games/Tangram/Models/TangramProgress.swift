//
//  TangramProgress.swift
//  Bemo
//
//  Progress tracking and persistence for Tangram gameplay progression
//

// WHAT: Model for tracking child progress through Tangram difficulty levels and puzzles
// ARCHITECTURE: Model in MVVM-S, used by TangramProgressService for persistence
// USAGE: Stores completed puzzles, current levels, and difficulty progression per child

import Foundation

// MARK: - TangramProgress Model

/// Tracks a child's progress through Tangram puzzles across difficulty levels
struct TangramProgress: Codable, Equatable {
    /// Unique identifier of the child profile this progress belongs to
    let childProfileId: String
    
    /// The last difficulty level the child selected/played
    var lastSelectedDifficulty: UserPreferences.DifficultySetting?
    
    /// Dictionary mapping difficulty level to set of completed puzzle IDs
    /// Key: difficulty.rawValue, Value: Set of puzzle IDs
    var completedPuzzlesByDifficulty: [String: Set<String>]
    
    /// Dictionary mapping difficulty level to current/last played puzzle ID
    /// Key: difficulty.rawValue, Value: current puzzle ID
    var currentLevelByDifficulty: [String: String?]
    
    /// Timestamp of last progress update
    var lastPlayedDate: Date
    
    // MARK: - Initialization
    
    /// Creates a new progress tracker for a child
    /// - Parameter childProfileId: Unique ID of the child profile
    init(childProfileId: String) {
        self.childProfileId = childProfileId
        self.lastSelectedDifficulty = nil
        self.completedPuzzlesByDifficulty = [:]
        self.currentLevelByDifficulty = [:]
        self.lastPlayedDate = Date()
    }
    
    // MARK: - Helper Methods
    
    /// Get completed puzzles for a specific difficulty
    /// - Parameter difficulty: The difficulty level to query
    /// - Returns: Set of completed puzzle IDs for the difficulty
    func getCompletedPuzzles(for difficulty: UserPreferences.DifficultySetting) -> Set<String> {
        return completedPuzzlesByDifficulty[difficulty.rawValue] ?? Set<String>()
    }
    
    /// Mark a puzzle as completed for a specific difficulty
    /// - Parameters:
    ///   - puzzleId: Unique identifier of the completed puzzle
    ///   - difficulty: The difficulty level the puzzle belongs to
    mutating func markPuzzleCompleted(puzzleId: String, difficulty: UserPreferences.DifficultySetting) {
        // Initialize difficulty entry if it doesn't exist
        if completedPuzzlesByDifficulty[difficulty.rawValue] == nil {
            completedPuzzlesByDifficulty[difficulty.rawValue] = Set<String>()
        }
        
        // Add the puzzle to completed set
        completedPuzzlesByDifficulty[difficulty.rawValue]?.insert(puzzleId)
        
        // Update last played date
        lastPlayedDate = Date()
    }
    
    /// Get count of completed puzzles for a difficulty
    /// - Parameter difficulty: The difficulty level to query
    /// - Returns: Number of completed puzzles
    func getCompletedCount(for difficulty: UserPreferences.DifficultySetting) -> Int {
        return getCompletedPuzzles(for: difficulty).count
    }
    
    /// Check if a specific puzzle is completed
    /// - Parameters:
    ///   - puzzleId: The puzzle ID to check
    ///   - difficulty: The difficulty level to check within
    /// - Returns: True if the puzzle is completed
    func isPuzzleCompleted(puzzleId: String, difficulty: UserPreferences.DifficultySetting) -> Bool {
        return getCompletedPuzzles(for: difficulty).contains(puzzleId)
    }
    
    /// Get the next unlocked puzzle for a difficulty (sequential unlock logic)
    /// - Parameters:
    ///   - difficulty: The difficulty level to query
    ///   - puzzles: Array of all available puzzles for the difficulty (sorted by ID)
    /// - Returns: The next unlocked puzzle, or nil if all are completed
    func getNextUnlockedPuzzle(for difficulty: UserPreferences.DifficultySetting, from puzzles: [GamePuzzleData]) -> GamePuzzleData? {
        let completed = getCompletedPuzzles(for: difficulty)
        
        // Filter puzzles for this difficulty and sort by ID
        let difficultyPuzzles = puzzles
            .filter { difficulty.containsPuzzleLevel($0.difficulty) }
            .sorted { $0.id < $1.id }
        
        // Find first uncompleted puzzle
        return difficultyPuzzles.first { !completed.contains($0.id) }
    }
    
    /// Check if a difficulty is fully completed
    /// - Parameters:
    ///   - difficulty: The difficulty level to check
    ///   - totalPuzzles: Total number of puzzles available for this difficulty
    /// - Returns: True if all puzzles in the difficulty are completed
    func isDifficultyCompleted(difficulty: UserPreferences.DifficultySetting, totalPuzzles: Int) -> Bool {
        let completedCount = getCompletedCount(for: difficulty)
        return completedCount >= totalPuzzles && totalPuzzles > 0
    }
    
    /// Get the next difficulty level for auto-promotion
    /// - Returns: Next difficulty level, or nil if already at hardest
    func getNextDifficulty() -> UserPreferences.DifficultySetting? {
        guard let current = lastSelectedDifficulty else { return .easy }
        
        switch current {
        case .easy:
            return .normal
        case .normal:
            return .hard
        case .hard:
            return nil // Already at maximum difficulty
        }
    }
    
    /// Set the last selected difficulty
    /// - Parameter difficulty: The difficulty level to set as last selected
    mutating func setLastSelectedDifficulty(_ difficulty: UserPreferences.DifficultySetting) {
        lastSelectedDifficulty = difficulty
        lastPlayedDate = Date()
    }
    
    /// Calculate overall progress percentage across all difficulties
    /// - Parameter allPuzzles: All available puzzles in the game
    /// - Returns: Progress as a percentage (0.0 to 1.0)
    func getTotalProgress(from allPuzzles: [GamePuzzleData]) -> Double {
        let totalPuzzles = allPuzzles.count
        guard totalPuzzles > 0 else { return 0.0 }
        
        let totalCompleted = UserPreferences.DifficultySetting.allCases.reduce(0) { total, difficulty in
            return total + getCompletedCount(for: difficulty)
        }
        
        return Double(totalCompleted) / Double(totalPuzzles)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: TangramProgress, rhs: TangramProgress) -> Bool {
        return lhs.childProfileId == rhs.childProfileId &&
               lhs.lastSelectedDifficulty == rhs.lastSelectedDifficulty &&
               lhs.completedPuzzlesByDifficulty == rhs.completedPuzzlesByDifficulty &&
               lhs.currentLevelByDifficulty == rhs.currentLevelByDifficulty
    }
}

// MARK: - UserPreferences.DifficultySetting Extensions

extension UserPreferences.DifficultySetting {
    /// All available difficulty settings
    static var allCases: [UserPreferences.DifficultySetting] {
        return [.easy, .normal, .hard]
    }
    /// Puzzle levels (star ratings) that belong to this difficulty
    var puzzleLevels: [Int] {
        switch self {
        case .easy:
            return TangramGameConstants.DifficultyProgression.StarRating.easyStars
        case .normal:
            return TangramGameConstants.DifficultyProgression.StarRating.mediumStars
        case .hard:
            return TangramGameConstants.DifficultyProgression.StarRating.hardStars
        }
    }
    
    /// Check if a puzzle level (star rating) belongs to this difficulty
    /// - Parameter level: The puzzle level/star rating to check
    /// - Returns: True if the level belongs to this difficulty
    func containsPuzzleLevel(_ level: Int) -> Bool {
        return puzzleLevels.contains(level)
    }
    
    /// Human-readable display name for the difficulty
    var displayName: String {
        switch self {
        case .easy:
            return "Easy"
        case .normal:
            return "Medium"
        case .hard:
            return "Hard"
        }
    }
    
    /// Color identifier for UI display
    var color: String {
        switch self {
        case .easy:
            return "green"
        case .normal:
            return "blue"
        case .hard:
            return "red"
        }
    }
    
    /// Icon name for UI display
    var icon: String {
        switch self {
        case .easy:
            return "star.fill"
        case .normal:
            return "star.leadinghalf.filled"
        case .hard:
            return "star.circle.fill"
        }
    }
    
    /// Get difficulty setting for a specific puzzle level
    /// - Parameter level: The puzzle level/star rating
    /// - Returns: Appropriate difficulty setting for the level
    static func forPuzzleLevel(_ level: Int) -> UserPreferences.DifficultySetting {
        switch level {
        case 1, 2:
            return .easy
        case 3, 4:
            return .normal
        case 5:
            return .hard
        default:
            return .easy  // Default to easy for unknown levels
        }
    }
}
