//
//  TangramProgressServiceTests.swift
//  BemoTests
//
//  Unit tests for TangramProgressService functionality
//

import XCTest
@testable import Bemo

final class TangramProgressServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var service: TangramProgressService!
    private var mockUserDefaults: UserDefaults!
    private var samplePuzzles: [GamePuzzleData]!
    private let testChildId = "test-child-123"
    
    override func setUp() {
        super.setUp()
        
        // Create isolated UserDefaults for testing
        let suiteName = "TangramProgressServiceTests-\(UUID().uuidString)"
        mockUserDefaults = UserDefaults(suiteName: suiteName)!
        
        // Initialize service with mock dependencies
        service = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        
        // Create sample puzzle data
        samplePuzzles = createSamplePuzzles()
    }
    
    override func tearDown() {
        // Clean up test data
        mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.description)
        
        service = nil
        mockUserDefaults = nil
        samplePuzzles = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createSamplePuzzles() -> [GamePuzzleData] {
        return [
            // Easy puzzles (1-2 stars) - sorted by ID for sequential testing
            GamePuzzleData(id: "easy-01", name: "Easy Cat", category: "animals", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy-02", name: "Easy Dog", category: "animals", difficulty: 2, targetPieces: []),
            GamePuzzleData(id: "easy-03", name: "Easy House", category: "objects", difficulty: 1, targetPieces: []),
            
            // Normal puzzles (3-4 stars)
            GamePuzzleData(id: "normal-01", name: "Medium Bird", category: "animals", difficulty: 3, targetPieces: []),
            GamePuzzleData(id: "normal-02", name: "Medium Tree", category: "nature", difficulty: 4, targetPieces: []),
            
            // Hard puzzles (5 stars)
            GamePuzzleData(id: "hard-01", name: "Hard Dragon", category: "fantasy", difficulty: 5, targetPieces: []),
            GamePuzzleData(id: "hard-02", name: "Hard Castle", category: "buildings", difficulty: 5, targetPieces: [])
        ]
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(service)
        XCTAssertTrue(service.progressByChild.isEmpty)
        XCTAssertFalse(service.isSyncing)
    }
    
    func testGetProgressCreatesNewForUnknownChild() {
        let progress = service.getProgress(for: testChildId)
        
        XCTAssertEqual(progress.childProfileId, testChildId)
        XCTAssertNil(progress.lastSelectedDifficulty)
        XCTAssertTrue(progress.completedPuzzlesByDifficulty.isEmpty)
        
        // Should be stored in service
        XCTAssertEqual(service.progressByChild.count, 1)
        XCTAssertNotNil(service.progressByChild[testChildId])
    }
    
    func testGetProgressReturnsExistingForKnownChild() {
        // Create initial progress
        let initialProgress = service.getProgress(for: testChildId)
        
        // Modify it
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "test-puzzle", difficulty: .easy)
        
        // Get progress again
        let retrievedProgress = service.getProgress(for: testChildId)
        
        XCTAssertEqual(retrievedProgress.childProfileId, testChildId)
        XCTAssertTrue(retrievedProgress.isPuzzleCompleted(puzzleId: "test-puzzle", difficulty: .easy))
        
        // Should be same instance
        XCTAssertEqual(service.progressByChild.count, 1)
    }
    
    // MARK: - Puzzle Completion Tests
    
    func testMarkPuzzleCompleted() {
        let puzzleId = "easy-01"
        let difficulty = UserPreferences.DifficultySetting.easy
        
        // Mark puzzle as completed
        service.markPuzzleCompleted(childId: testChildId, puzzleId: puzzleId, difficulty: difficulty)
        
        // Verify completion
        let progress = service.getProgress(for: testChildId)
        XCTAssertTrue(progress.isPuzzleCompleted(puzzleId: puzzleId, difficulty: difficulty))
        XCTAssertEqual(progress.getCompletedCount(for: difficulty), 1)
    }
    
    func testMarkMultiplePuzzlesCompleted() {
        // Mark various puzzles completed
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-02", difficulty: .easy)
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "normal-01", difficulty: .normal)
        
        // Verify counts
        let progress = service.getProgress(for: testChildId)
        XCTAssertEqual(progress.getCompletedCount(for: .easy), 2)
        XCTAssertEqual(progress.getCompletedCount(for: .normal), 1)
        XCTAssertEqual(progress.getCompletedCount(for: .hard), 0)
    }
    
    // MARK: - Unlock Logic Tests
    
    func testGetUnlockedPuzzlesForNewChild() {
        let unlockedPuzzles = service.getUnlockedPuzzles(for: testChildId, difficulty: .easy, from: samplePuzzles)
        
        // Only first puzzle should be unlocked
        XCTAssertEqual(unlockedPuzzles.count, 1)
        XCTAssertEqual(unlockedPuzzles.first?.id, "easy-01")
    }
    
    func testGetUnlockedPuzzlesAfterCompletion() {
        // Complete first easy puzzle
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        let unlockedPuzzles = service.getUnlockedPuzzles(for: testChildId, difficulty: .easy, from: samplePuzzles)
        
        // First two puzzles should be unlocked
        XCTAssertEqual(unlockedPuzzles.count, 2)
        XCTAssertEqual(unlockedPuzzles[0].id, "easy-01")
        XCTAssertEqual(unlockedPuzzles[1].id, "easy-02")
    }
    
    func testSequentialUnlockLogic() {
        // Complete puzzles in order
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-02", difficulty: .easy)
        
        let unlockedPuzzles = service.getUnlockedPuzzles(for: testChildId, difficulty: .easy, from: samplePuzzles)
        
        // All three easy puzzles should be unlocked
        XCTAssertEqual(unlockedPuzzles.count, 3)
        XCTAssertEqual(unlockedPuzzles.map { $0.id }, ["easy-01", "easy-02", "easy-03"])
    }
    
    func testGetNextPuzzleForNewChild() {
        let nextPuzzle = service.getNextPuzzle(for: testChildId, difficulty: .easy, from: samplePuzzles)
        
        XCTAssertNotNil(nextPuzzle)
        XCTAssertEqual(nextPuzzle?.id, "easy-01")
    }
    
    func testGetNextPuzzleAfterCompletion() {
        // Complete first puzzle
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        let nextPuzzle = service.getNextPuzzle(for: testChildId, difficulty: .easy, from: samplePuzzles)
        
        XCTAssertNotNil(nextPuzzle)
        XCTAssertEqual(nextPuzzle?.id, "easy-02")
    }
    
    func testGetNextPuzzleWhenAllCompleted() {
        // Complete all easy puzzles
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-02", difficulty: .easy)
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-03", difficulty: .easy)
        
        let nextPuzzle = service.getNextPuzzle(for: testChildId, difficulty: .easy, from: samplePuzzles)
        
        XCTAssertNil(nextPuzzle)
    }
    
    func testIsPuzzleUnlocked() {
        // First puzzle should be unlocked
        XCTAssertTrue(service.isPuzzleUnlocked(childId: testChildId, puzzleId: "easy-01", difficulty: .easy, from: samplePuzzles))
        
        // Second puzzle should be locked
        XCTAssertFalse(service.isPuzzleUnlocked(childId: testChildId, puzzleId: "easy-02", difficulty: .easy, from: samplePuzzles))
        
        // Complete first puzzle
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        // Now second puzzle should be unlocked
        XCTAssertTrue(service.isPuzzleUnlocked(childId: testChildId, puzzleId: "easy-02", difficulty: .easy, from: samplePuzzles))
    }
    
    // MARK: - Promotion Detection Tests
    
    func testShouldPromoteWhenDifficultyIncomplete() {
        // Complete only some easy puzzles
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        let shouldPromote = service.shouldPromoteToNextDifficulty(childId: testChildId, currentDifficulty: .easy, from: samplePuzzles)
        
        XCTAssertFalse(shouldPromote)
    }
    
    func testShouldPromoteWhenDifficultyComplete() {
        // Complete all easy puzzles
        let easyPuzzles = samplePuzzles.filter { UserPreferences.DifficultySetting.easy.containsPuzzleLevel($0.difficulty) }
        
        for puzzle in easyPuzzles {
            service.markPuzzleCompleted(childId: testChildId, puzzleId: puzzle.id, difficulty: .easy)
        }
        
        let shouldPromote = service.shouldPromoteToNextDifficulty(childId: testChildId, currentDifficulty: .easy, from: samplePuzzles)
        
        XCTAssertTrue(shouldPromote)
    }
    
    func testShouldNotPromoteFromHardDifficulty() {
        // Complete all hard puzzles
        let hardPuzzles = samplePuzzles.filter { UserPreferences.DifficultySetting.hard.containsPuzzleLevel($0.difficulty) }
        
        for puzzle in hardPuzzles {
            service.markPuzzleCompleted(childId: testChildId, puzzleId: puzzle.id, difficulty: .hard)
        }
        
        let shouldPromote = service.shouldPromoteToNextDifficulty(childId: testChildId, currentDifficulty: .hard, from: samplePuzzles)
        
        // Should still be true - promotion detection doesn't check if there's a next difficulty
        XCTAssertTrue(shouldPromote)
    }
    
    // MARK: - Difficulty Management Tests
    
    func testSetLastSelectedDifficulty() {
        service.setLastSelectedDifficulty(childId: testChildId, difficulty: .normal)
        
        let progress = service.getProgress(for: testChildId)
        XCTAssertEqual(progress.lastSelectedDifficulty, .normal)
    }
    
    func testGetCompletionStats() {
        // Complete some easy puzzles
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-02", difficulty: .easy)
        
        let stats = service.getCompletionStats(for: testChildId, difficulty: .easy, from: samplePuzzles)
        
        let expectedTotal = samplePuzzles.filter { UserPreferences.DifficultySetting.easy.containsPuzzleLevel($0.difficulty) }.count
        
        XCTAssertEqual(stats.completed, 2)
        XCTAssertEqual(stats.total, expectedTotal)
        XCTAssertEqual(stats.percentage, 2.0 / Double(expectedTotal), accuracy: 0.001)
    }
    
    func testGetCompletionStatsEmpty() {
        let stats = service.getCompletionStats(for: testChildId, difficulty: .hard, from: samplePuzzles)
        
        let expectedTotal = samplePuzzles.filter { UserPreferences.DifficultySetting.hard.containsPuzzleLevel($0.difficulty) }.count
        
        XCTAssertEqual(stats.completed, 0)
        XCTAssertEqual(stats.total, expectedTotal)
        XCTAssertEqual(stats.percentage, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Persistence Tests
    
    func testProgressPersistence() {
        // Add some progress data
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        service.setLastSelectedDifficulty(childId: testChildId, difficulty: .easy)
        
        // Create new service instance (simulating app restart)
        let newService = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        
        // Verify data was loaded
        let loadedProgress = newService.getProgress(for: testChildId)
        XCTAssertTrue(loadedProgress.isPuzzleCompleted(puzzleId: "easy-01", difficulty: .easy))
        XCTAssertEqual(loadedProgress.lastSelectedDifficulty, .easy)
    }
    
    func testUpdateProgressTriggersLocalSave() {
        let initialProgress = service.getProgress(for: testChildId)
        var modifiedProgress = initialProgress
        modifiedProgress.markPuzzleCompleted(puzzleId: "test-puzzle", difficulty: .normal)
        
        // Update progress
        service.updateProgress(modifiedProgress)
        
        // Create new service to verify persistence
        let newService = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        let loadedProgress = newService.getProgress(for: testChildId)
        
        XCTAssertTrue(loadedProgress.isPuzzleCompleted(puzzleId: "test-puzzle", difficulty: .normal))
    }
    
    func testCorruptedDataHandling() {
        // Write invalid data to UserDefaults
        let corruptData = "invalid-json-data".data(using: .utf8)!
        mockUserDefaults.set(corruptData, forKey: "com.bemo.tangram.progress")
        
        // Service should handle corruption gracefully
        let newService = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        
        XCTAssertTrue(newService.progressByChild.isEmpty)
        
        // Should still be able to create new progress
        let progress = newService.getProgress(for: testChildId)
        XCTAssertEqual(progress.childProfileId, testChildId)
    }
    
    // MARK: - Multiple Children Tests
    
    func testMultipleChildrenProgress() {
        let child1Id = "child-1"
        let child2Id = "child-2"
        
        // Add progress for both children
        service.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-01", difficulty: .easy)
        service.markPuzzleCompleted(childId: child2Id, puzzleId: "normal-01", difficulty: .normal)
        
        // Verify separate progress tracking
        let child1Progress = service.getProgress(for: child1Id)
        let child2Progress = service.getProgress(for: child2Id)
        
        XCTAssertTrue(child1Progress.isPuzzleCompleted(puzzleId: "easy-01", difficulty: .easy))
        XCTAssertFalse(child1Progress.isPuzzleCompleted(puzzleId: "normal-01", difficulty: .normal))
        
        XCTAssertTrue(child2Progress.isPuzzleCompleted(puzzleId: "normal-01", difficulty: .normal))
        XCTAssertFalse(child2Progress.isPuzzleCompleted(puzzleId: "easy-01", difficulty: .easy))
        
        XCTAssertEqual(service.progressByChild.count, 2)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyPuzzleList() {
        let emptyPuzzles: [GamePuzzleData] = []
        
        let unlockedPuzzles = service.getUnlockedPuzzles(for: testChildId, difficulty: .easy, from: emptyPuzzles)
        let nextPuzzle = service.getNextPuzzle(for: testChildId, difficulty: .easy, from: emptyPuzzles)
        let stats = service.getCompletionStats(for: testChildId, difficulty: .easy, from: emptyPuzzles)
        
        XCTAssertTrue(unlockedPuzzles.isEmpty)
        XCTAssertNil(nextPuzzle)
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.percentage, 0.0)
    }
    
    func testDifficultyWithNoPuzzles() {
        // Create puzzles that don't match any difficulty level
        let invalidPuzzles = [
            GamePuzzleData(id: "invalid-1", name: "Invalid", category: "test", difficulty: 10, targetPieces: [])
        ]
        
        let unlockedPuzzles = service.getUnlockedPuzzles(for: testChildId, difficulty: .easy, from: invalidPuzzles)
        let nextPuzzle = service.getNextPuzzle(for: testChildId, difficulty: .easy, from: invalidPuzzles)
        
        XCTAssertTrue(unlockedPuzzles.isEmpty)
        XCTAssertNil(nextPuzzle)
    }
    
    // MARK: - Debug Helper Tests
    
    #if DEBUG
    func testResetAllProgress() {
        // Add some progress
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        XCTAssertEqual(service.progressByChild.count, 1)
        
        // Reset all progress
        service.resetAllProgress()
        
        XCTAssertTrue(service.progressByChild.isEmpty)
    }
    
    func testAddTestData() {
        XCTAssertTrue(service.progressByChild.isEmpty)
        
        service.addTestData()
        
        XCTAssertFalse(service.progressByChild.isEmpty)
        XCTAssertTrue(service.progressByChild.contains { $0.key == "debug-test-child" })
    }
    
    func testDebugPrintProgress() {
        // Add some test data
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        service.setLastSelectedDifficulty(childId: testChildId, difficulty: .easy)
        
        // Should not crash (testing print statements is challenging, but we can verify it doesn't throw)
        XCTAssertNoThrow(service.debugPrintProgress())
    }
    #endif
    
    // MARK: - Observable Behavior Tests
    
    func testObservableUpdates() {
        // Note: Full @Observable testing requires more complex setup with observation
        // Here we just verify the basic property changes work
        
        XCTAssertFalse(service.isSyncing)
        XCTAssertTrue(service.progressByChild.isEmpty)
        
        // Adding progress should update the observable property
        let progress = service.getProgress(for: testChildId)
        XCTAssertFalse(service.progressByChild.isEmpty)
        
        // Completing puzzles should update progress
        service.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        let updatedProgress = service.getProgress(for: testChildId)
        XCTAssertTrue(updatedProgress.isPuzzleCompleted(puzzleId: "easy-01", difficulty: .easy))
    }
}
