//
//  TangramProgressService.swift
//  Bemo
//
//  Service for managing and persisting Tangram progress across child profiles
//

// WHAT: Observable service for tracking and persisting child progress through Tangram difficulties
// ARCHITECTURE: Service in MVVM-S, manages progress state and persistence
// USAGE: Injected into ViewModels to handle progress tracking, unlock logic, and synchronization

import Foundation
import Observation

/// Service for managing Tangram progress across child profiles
@Observable
class TangramProgressService {
    
    // MARK: - Observable Properties
    
    /// Progress data by child profile ID
    private var progressByChild: [String: TangramProgress] = [:]
    
    /// Whether the service is currently syncing with remote
    var isSyncing: Bool = false
    
    // MARK: - Dependencies
    
    private let userDefaults: UserDefaults
    private let supabaseService: SupabaseService?
    
    // MARK: - Constants
    
    private struct Keys {
        static let progressData = "com.bemo.tangram.progress"
        static let dataVersion = "com.bemo.tangram.progress.version"
    }
    
    private let currentDataVersion = 1
    
    // MARK: - Initialization
    
    /// Initialize the progress service
    /// - Parameters:
    ///   - userDefaults: UserDefaults instance for local persistence
    ///   - supabaseService: Optional Supabase service for remote sync
    init(userDefaults: UserDefaults = .standard, supabaseService: SupabaseService? = nil) {
        self.userDefaults = userDefaults
        self.supabaseService = supabaseService
        
        loadProgressFromLocal()
    }
    
    // MARK: - Access Methods
    
    /// Get the number of children with progress data
    /// - Returns: Count of children with progress
    var childCount: Int {
        progressByChild.count
    }
    
    /// Get all child IDs that have progress data
    /// - Returns: Array of child profile IDs
    var childIds: [String] {
        Array(progressByChild.keys)
    }
    
    /// Check if progress exists for a specific child
    /// - Parameter childId: Child profile ID to check
    /// - Returns: True if progress exists for the child
    func hasProgress(for childId: String) -> Bool {
        progressByChild[childId] != nil
    }
    
    /// Get progress for a specific child without creating new one
    /// - Parameter childId: Child profile ID
    /// - Returns: TangramProgress if it exists, nil otherwise
    func getExistingProgress(for childId: String) -> TangramProgress? {
        progressByChild[childId]
    }
    
    /// Get all progress data for debugging/admin purposes
    /// - Returns: Dictionary of child ID to progress data
    func getAllProgressData() -> [String: TangramProgress] {
        progressByChild
    }
    
    // MARK: - Core Progress Methods
    
    /// Get progress for a specific child (creates new if doesn't exist)
    /// - Parameter childId: Unique identifier of the child profile
    /// - Returns: TangramProgress for the child
    func getProgress(for childId: String) -> TangramProgress {
        if let existingProgress = progressByChild[childId] {
            return existingProgress
        }
        
        // Create new progress for child
        let newProgress = TangramProgress(childProfileId: childId)
        progressByChild[childId] = newProgress
        saveProgressToLocal()
        
        return newProgress
    }
    
    /// Update progress for a child
    /// - Parameter progress: Updated progress data
    func updateProgress(_ progress: TangramProgress) {
        progressByChild[progress.childProfileId] = progress
        saveProgressToLocal()
        
        // Trigger background sync if available
        Task {
            await syncProgressToSupabase(progress)
        }
    }
    
    /// Mark a puzzle as completed for a child
    /// - Parameters:
    ///   - childId: Child profile identifier
    ///   - puzzleId: Puzzle identifier to mark complete
    ///   - difficulty: Difficulty level the puzzle belongs to
    func markPuzzleCompleted(childId: String, puzzleId: String, difficulty: UserPreferences.DifficultySetting) {
        var progress = getProgress(for: childId)
        progress.markPuzzleCompleted(puzzleId: puzzleId, difficulty: difficulty)
        updateProgress(progress)
    }
    
    /// Get unlocked puzzles for a child in a specific difficulty
    /// - Parameters:
    ///   - childId: Child profile identifier
    ///   - difficulty: Difficulty level to check
    ///   - allPuzzles: All available puzzles to filter from
    /// - Returns: Array of unlocked puzzles in sequential order
    func getUnlockedPuzzles(for childId: String, difficulty: UserPreferences.DifficultySetting, from allPuzzles: [GamePuzzleData]) -> [GamePuzzleData] {
        let progress = getProgress(for: childId)
        let completed = progress.getCompletedPuzzles(for: difficulty)
        
        // Filter puzzles for this difficulty and sort by ID
        let difficultyPuzzles = allPuzzles
            .filter { difficulty.containsPuzzleLevel($0.difficulty) }
            .sorted { $0.id < $1.id }
        
        // Sequential unlock: first puzzle + all puzzles after completed ones
        var unlockedPuzzles: [GamePuzzleData] = []
        
        for (index, puzzle) in difficultyPuzzles.enumerated() {
            if index == 0 {
                // First puzzle is always unlocked
                unlockedPuzzles.append(puzzle)
            } else {
                // Check if all previous puzzles are completed
                let previousPuzzle = difficultyPuzzles[index - 1]
                if completed.contains(previousPuzzle.id) {
                    unlockedPuzzles.append(puzzle)
                } else {
                    // Sequential unlock: stop here
                    break
                }
            }
        }
        
        return unlockedPuzzles
    }
    
    /// Get the next puzzle to play for a child in a difficulty
    /// - Parameters:
    ///   - childId: Child profile identifier
    ///   - difficulty: Difficulty level to check
    ///   - allPuzzles: All available puzzles to choose from
    /// - Returns: Next unlocked puzzle, or nil if all completed
    func getNextPuzzle(for childId: String, difficulty: UserPreferences.DifficultySetting, from allPuzzles: [GamePuzzleData]) -> GamePuzzleData? {
        let progress = getProgress(for: childId)
        return progress.getNextUnlockedPuzzle(for: difficulty, from: allPuzzles)
    }
    
    /// Check if a child should be promoted to the next difficulty
    /// - Parameters:
    ///   - childId: Child profile identifier
    ///   - currentDifficulty: Current difficulty level
    ///   - allPuzzles: All available puzzles to check completion against
    /// - Returns: True if all puzzles in current difficulty are completed
    func shouldPromoteToNextDifficulty(childId: String, currentDifficulty: UserPreferences.DifficultySetting, from allPuzzles: [GamePuzzleData]) -> Bool {
        let progress = getProgress(for: childId)
        let totalPuzzlesInDifficulty = allPuzzles
            .filter { currentDifficulty.containsPuzzleLevel($0.difficulty) }
            .count
        
        return progress.isDifficultyCompleted(difficulty: currentDifficulty, totalPuzzles: totalPuzzlesInDifficulty)
    }
    
    /// Set the last selected difficulty for a child
    /// - Parameters:
    ///   - childId: Child profile identifier
    ///   - difficulty: Difficulty level to set as last selected
    func setLastSelectedDifficulty(childId: String, difficulty: UserPreferences.DifficultySetting) {
        var progress = getProgress(for: childId)
        progress.setLastSelectedDifficulty(difficulty)
        updateProgress(progress)
    }
    
    /// Check if a specific puzzle is unlocked for a child
    /// - Parameters:
    ///   - childId: Child profile identifier
    ///   - puzzleId: Puzzle identifier to check
    ///   - difficulty: Difficulty level the puzzle belongs to
    ///   - allPuzzles: All available puzzles for sequential logic
    /// - Returns: True if the puzzle is unlocked
    func isPuzzleUnlocked(childId: String, puzzleId: String, difficulty: UserPreferences.DifficultySetting, from allPuzzles: [GamePuzzleData]) -> Bool {
        let unlockedPuzzles = getUnlockedPuzzles(for: childId, difficulty: difficulty, from: allPuzzles)
        return unlockedPuzzles.contains { $0.id == puzzleId }
    }
    
    /// Get completion statistics for a child in a difficulty
    /// - Parameters:
    ///   - childId: Child profile identifier
    ///   - difficulty: Difficulty level to analyze
    ///   - allPuzzles: All available puzzles to count from
    /// - Returns: Tuple with completed count, total count, and percentage
    func getCompletionStats(for childId: String, difficulty: UserPreferences.DifficultySetting, from allPuzzles: [GamePuzzleData]) -> (completed: Int, total: Int, percentage: Double) {
        let progress = getProgress(for: childId)
        let completed = progress.getCompletedCount(for: difficulty)
        let total = allPuzzles
            .filter { difficulty.containsPuzzleLevel($0.difficulty) }
            .count
        
        let percentage = total > 0 ? Double(completed) / Double(total) : 0.0
        
        return (completed: completed, total: total, percentage: percentage)
    }
    
    // MARK: - Local Persistence
    
    /// Load progress data from UserDefaults
    private func loadProgressFromLocal() {
        // Check data version for migration handling
        let savedVersion = userDefaults.integer(forKey: Keys.dataVersion)
        
        guard let data = userDefaults.data(forKey: Keys.progressData) else {
            // No saved data, start fresh
            progressByChild = [:]
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let loadedProgress = try decoder.decode([String: TangramProgress].self, from: data)
            
            // Handle data migration if needed
            if savedVersion < currentDataVersion {
                progressByChild = migrateProgressData(loadedProgress, fromVersion: savedVersion)
                saveProgressToLocal() // Save migrated data
            } else {
                progressByChild = loadedProgress
            }
            
        } catch {
            print("⚠️ TangramProgressService: Failed to load progress data: \(error)")
            // Fall back to empty progress on corruption
            progressByChild = [:]
            
            // Clear corrupted data
            userDefaults.removeObject(forKey: Keys.progressData)
            userDefaults.removeObject(forKey: Keys.dataVersion)
        }
    }
    
    /// Save progress data to UserDefaults
    private func saveProgressToLocal() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(progressByChild)
            
            userDefaults.set(data, forKey: Keys.progressData)
            userDefaults.set(currentDataVersion, forKey: Keys.dataVersion)
            
        } catch {
            print("⚠️ TangramProgressService: Failed to save progress data: \(error)")
        }
    }
    
    /// Migrate progress data between versions
    /// - Parameters:
    ///   - data: Original progress data
    ///   - fromVersion: Version number to migrate from
    /// - Returns: Migrated progress data
    private func migrateProgressData(_ data: [String: TangramProgress], fromVersion: Int) -> [String: TangramProgress] {
        // Future: Add migration logic when data format changes
        print("📈 TangramProgressService: Migrating progress data from version \(fromVersion) to \(currentDataVersion)")
        return data
    }
    
    // MARK: - Remote Sync (Placeholders for Phase 5)
    
    /// Sync progress to Supabase (placeholder)
    /// - Parameter progress: Progress data to sync
    private func syncProgressToSupabase(_ progress: TangramProgress) async {
        guard let supabaseService = supabaseService else { return }
        
        // TODO: Implement in Phase 5
        // - Upload progress to remote database
        // - Handle conflicts and merge strategies
        // - Update sync status
        
        print("🔄 TangramProgressService: Remote sync placeholder - would sync progress for child \(progress.childProfileId)")
    }
    
    /// Sync progress from Supabase (placeholder)
    private func syncFromSupabase() async {
        guard let supabaseService = supabaseService else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // TODO: Implement in Phase 5
        // - Fetch remote progress for all child profiles
        // - Merge with local progress
        // - Save merged results locally
        
        print("🔄 TangramProgressService: Remote fetch placeholder - would fetch all progress data")
    }
    
    // MARK: - Development Helpers
    
    #if DEBUG
    /// Reset all progress data (DEBUG only)
    func resetAllProgress() {
        progressByChild = [:]
        saveProgressToLocal()
        print("🗑️ TangramProgressService: All progress data reset")
    }
    
    /// Print current progress state for debugging (DEBUG only)
    func debugPrintProgress() {
        print("📊 TangramProgressService Debug:")
        print("  Total children: \(childCount)")
        
        for (childId, progress) in progressByChild {
            print("  Child \(childId):")
            print("    Last difficulty: \(progress.lastSelectedDifficulty?.displayName ?? "None")")
            
            for difficulty in UserPreferences.DifficultySetting.allCases {
                let completed = progress.getCompletedCount(for: difficulty)
                print("    \(difficulty.displayName): \(completed) puzzles completed")
            }
        }
    }
    
    /// Add test progress data for debugging (DEBUG only)
    func addTestData() {
        let testChildId = "debug-test-child"
        var testProgress = TangramProgress(childProfileId: testChildId)
        
        // Add some completed puzzles
        testProgress.markPuzzleCompleted(puzzleId: "easy1", difficulty: .easy)
        testProgress.markPuzzleCompleted(puzzleId: "easy2", difficulty: .easy)
        testProgress.markPuzzleCompleted(puzzleId: "normal1", difficulty: .normal)
        testProgress.setLastSelectedDifficulty(.normal)
        
        updateProgress(testProgress)
        print("🧪 TangramProgressService: Test data added for child \(testChildId)")
    }
    #endif
}
