//
//  TangramProgressTests.swift
//  BemoTests
//
//  Unit tests for TangramProgress model and UserPreferences.DifficultySetting extensions
//

import XCTest
@testable import Bemo

final class TangramProgressTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let testChildId = "test-child-123"
    private var testProgress: TangramProgress!
    private var samplePuzzles: [GamePuzzleData]!
    
    override func setUp() {
        super.setUp()
        testProgress = TangramProgress(childProfileId: testChildId)
        samplePuzzles = createSamplePuzzles()
    }
    
    override func tearDown() {
        testProgress = nil
        samplePuzzles = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createSamplePuzzles() -> [GamePuzzleData] {
        return [
            // Easy puzzles (1-2 stars)
            GamePuzzleData(id: "easy1", name: "Easy Puzzle 1", category: "animals", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy2", name: "Easy Puzzle 2", category: "animals", difficulty: 2, targetPieces: []),
            GamePuzzleData(id: "easy3", name: "Easy Puzzle 3", category: "animals", difficulty: 1, targetPieces: []),
            
            // Normal puzzles (3-4 stars)
            GamePuzzleData(id: "normal1", name: "Normal Puzzle 1", category: "shapes", difficulty: 3, targetPieces: []),
            GamePuzzleData(id: "normal2", name: "Normal Puzzle 2", category: "shapes", difficulty: 4, targetPieces: []),
            
            // Hard puzzles (5 stars)
            GamePuzzleData(id: "hard1", name: "Hard Puzzle 1", category: "complex", difficulty: 5, targetPieces: []),
            GamePuzzleData(id: "hard2", name: "Hard Puzzle 2", category: "complex", difficulty: 5, targetPieces: [])
        ]
    }
    
    // MARK: - TangramProgress Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(testProgress.childProfileId, testChildId)
        XCTAssertNil(testProgress.lastSelectedDifficulty)
        XCTAssertTrue(testProgress.completedPuzzlesByDifficulty.isEmpty)
        XCTAssertTrue(testProgress.currentLevelByDifficulty.isEmpty)
        XCTAssertNotNil(testProgress.lastPlayedDate)
    }
    
    // MARK: - Puzzle Completion Tests
    
    func testMarkPuzzleCompleted() {
        let puzzleId = "test-puzzle-1"
        let difficulty = UserPreferences.DifficultySetting.easy
        
        // Mark puzzle as completed
        testProgress.markPuzzleCompleted(puzzleId: puzzleId, difficulty: difficulty)
        
        // Verify completion
        XCTAssertTrue(testProgress.isPuzzleCompleted(puzzleId: puzzleId, difficulty: difficulty))
        XCTAssertEqual(testProgress.getCompletedCount(for: difficulty), 1)
        XCTAssertTrue(testProgress.getCompletedPuzzles(for: difficulty).contains(puzzleId))
    }
    
    func testMarkMultiplePuzzlesCompleted() {
        let easyPuzzles = ["easy1", "easy2"]
        let normalPuzzles = ["normal1"]
        
        // Mark multiple puzzles as completed
        for puzzleId in easyPuzzles {
            testProgress.markPuzzleCompleted(puzzleId: puzzleId, difficulty: .easy)
        }
        
        for puzzleId in normalPuzzles {
            testProgress.markPuzzleCompleted(puzzleId: puzzleId, difficulty: .normal)
        }
        
        // Verify counts per difficulty
        XCTAssertEqual(testProgress.getCompletedCount(for: .easy), 2)
        XCTAssertEqual(testProgress.getCompletedCount(for: .normal), 1)
        XCTAssertEqual(testProgress.getCompletedCount(for: .hard), 0)
        
        // Verify specific completions
        for puzzleId in easyPuzzles {
            XCTAssertTrue(testProgress.isPuzzleCompleted(puzzleId: puzzleId, difficulty: .easy))
        }
        
        for puzzleId in normalPuzzles {
            XCTAssertTrue(testProgress.isPuzzleCompleted(puzzleId: puzzleId, difficulty: .normal))
        }
    }
    
    func testGetCompletedPuzzlesForEmptyDifficulty() {
        let completed = testProgress.getCompletedPuzzles(for: .hard)
        XCTAssertTrue(completed.isEmpty)
        XCTAssertEqual(testProgress.getCompletedCount(for: .hard), 0)
    }
    
    // MARK: - Next Puzzle Logic Tests
    
    func testGetNextUnlockedPuzzleForEmptyProgress() {
        let nextPuzzle = testProgress.getNextUnlockedPuzzle(for: .easy, from: samplePuzzles)
        
        // Should return first easy puzzle (sorted by ID)
        XCTAssertNotNil(nextPuzzle)
        XCTAssertEqual(nextPuzzle?.id, "easy1") // First in alphabetical order
        XCTAssertEqual(nextPuzzle?.difficulty, 1)
    }
    
    func testGetNextUnlockedPuzzleAfterCompletion() {
        // Complete first easy puzzle
        testProgress.markPuzzleCompleted(puzzleId: "easy1", difficulty: .easy)
        
        let nextPuzzle = testProgress.getNextUnlockedPuzzle(for: .easy, from: samplePuzzles)
        
        // Should return next easy puzzle
        XCTAssertNotNil(nextPuzzle)
        XCTAssertEqual(nextPuzzle?.id, "easy2")
    }
    
    func testGetNextUnlockedPuzzleAllCompleted() {
        // Complete all easy puzzles
        let easyPuzzleIds = samplePuzzles
            .filter { UserPreferences.DifficultySetting.easy.containsPuzzleLevel($0.difficulty) }
            .map { $0.id }
        
        for puzzleId in easyPuzzleIds {
            testProgress.markPuzzleCompleted(puzzleId: puzzleId, difficulty: .easy)
        }
        
        let nextPuzzle = testProgress.getNextUnlockedPuzzle(for: .easy, from: samplePuzzles)
        
        // Should return nil when all are completed
        XCTAssertNil(nextPuzzle)
    }
    
    // MARK: - Difficulty Completion Tests
    
    func testIsDifficultyCompleted() {
        let easyPuzzleCount = samplePuzzles
            .filter { UserPreferences.DifficultySetting.easy.containsPuzzleLevel($0.difficulty) }
            .count
        
        // Initially not completed
        XCTAssertFalse(testProgress.isDifficultyCompleted(difficulty: .easy, totalPuzzles: easyPuzzleCount))
        
        // Complete all easy puzzles
        let easyPuzzleIds = samplePuzzles
            .filter { UserPreferences.DifficultySetting.easy.containsPuzzleLevel($0.difficulty) }
            .map { $0.id }
        
        for puzzleId in easyPuzzleIds {
            testProgress.markPuzzleCompleted(puzzleId: puzzleId, difficulty: .easy)
        }
        
        // Now should be completed
        XCTAssertTrue(testProgress.isDifficultyCompleted(difficulty: .easy, totalPuzzles: easyPuzzleCount))
    }
    
    func testIsDifficultyCompletedWithZeroPuzzles() {
        // Edge case: zero puzzles should not be considered completed
        XCTAssertFalse(testProgress.isDifficultyCompleted(difficulty: .hard, totalPuzzles: 0))
    }
    
    // MARK: - Difficulty Progression Tests
    
    func testGetNextDifficulty() {
        // Test progression: easy -> normal -> hard -> nil
        testProgress.setLastSelectedDifficulty(.easy)
        XCTAssertEqual(testProgress.getNextDifficulty(), .normal)
        
        testProgress.setLastSelectedDifficulty(.normal)
        XCTAssertEqual(testProgress.getNextDifficulty(), .hard)
        
        testProgress.setLastSelectedDifficulty(.hard)
        XCTAssertNil(testProgress.getNextDifficulty())
    }
    
    func testGetNextDifficultyFromNil() {
        // When no difficulty is set, should default to easy
        XCTAssertEqual(testProgress.getNextDifficulty(), .easy)
    }
    
    func testSetLastSelectedDifficulty() {
        let initialDate = testProgress.lastPlayedDate
        
        // Wait a brief moment to ensure timestamp changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            self.testProgress.setLastSelectedDifficulty(.normal)
            
            XCTAssertEqual(self.testProgress.lastSelectedDifficulty, .normal)
            XCTAssertGreaterThan(self.testProgress.lastPlayedDate, initialDate)
        }
    }
    
    // MARK: - Total Progress Tests
    
    func testGetTotalProgressEmpty() {
        let progress = testProgress.getTotalProgress(from: samplePuzzles)
        XCTAssertEqual(progress, 0.0, accuracy: 0.001)
    }
    
    func testGetTotalProgressPartial() {
        // Complete some puzzles from different difficulties
        testProgress.markPuzzleCompleted(puzzleId: "easy1", difficulty: .easy)
        testProgress.markPuzzleCompleted(puzzleId: "normal1", difficulty: .normal)
        
        let progress = testProgress.getTotalProgress(from: samplePuzzles)
        let expectedProgress = 2.0 / Double(samplePuzzles.count)
        
        XCTAssertEqual(progress, expectedProgress, accuracy: 0.001)
    }
    
    func testGetTotalProgressComplete() {
        // Complete all puzzles
        for puzzle in samplePuzzles {
            let difficulty = UserPreferences.DifficultySetting.forPuzzleLevel(puzzle.difficulty)
            testProgress.markPuzzleCompleted(puzzleId: puzzle.id, difficulty: difficulty)
        }
        
        let progress = testProgress.getTotalProgress(from: samplePuzzles)
        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }
    
    func testGetTotalProgressWithEmptyPuzzleList() {
        let progress = testProgress.getTotalProgress(from: [])
        XCTAssertEqual(progress, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Codable Tests
    
    func testCodableEncoding() throws {
        // Set up test data
        testProgress.markPuzzleCompleted(puzzleId: "test1", difficulty: .easy)
        testProgress.markPuzzleCompleted(puzzleId: "test2", difficulty: .normal)
        testProgress.setLastSelectedDifficulty(.normal)
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(testProgress)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedProgress = try decoder.decode(TangramProgress.self, from: data)
        
        // Verify
        XCTAssertEqual(decodedProgress, testProgress)
        XCTAssertEqual(decodedProgress.childProfileId, testChildId)
        XCTAssertEqual(decodedProgress.lastSelectedDifficulty, .normal)
        XCTAssertTrue(decodedProgress.isPuzzleCompleted(puzzleId: "test1", difficulty: .easy))
        XCTAssertTrue(decodedProgress.isPuzzleCompleted(puzzleId: "test2", difficulty: .normal))
    }
    
    // MARK: - Equatable Tests
    
    func testEquatable() {
        let progress1 = TangramProgress(childProfileId: "child1")
        let progress2 = TangramProgress(childProfileId: "child1")
        let progress3 = TangramProgress(childProfileId: "child2")
        
        // Same child ID should be equal initially
        XCTAssertEqual(progress1, progress2)
        
        // Different child ID should not be equal
        XCTAssertNotEqual(progress1, progress3)
        
        // Test after modification
        var modifiedProgress = progress1
        modifiedProgress.markPuzzleCompleted(puzzleId: "test", difficulty: .easy)
        
        XCTAssertNotEqual(progress1, modifiedProgress)
    }
}

// MARK: - UserPreferences.DifficultySetting Extension Tests

final class DifficuiltySettingExtensionTests: XCTestCase {
    
    func testAllCases() {
        let allCases = UserPreferences.DifficultySetting.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.easy))
        XCTAssertTrue(allCases.contains(.normal))
        XCTAssertTrue(allCases.contains(.hard))
    }
    
    func testPuzzleLevels() {
        XCTAssertEqual(UserPreferences.DifficultySetting.easy.puzzleLevels, [1, 2])
        XCTAssertEqual(UserPreferences.DifficultySetting.normal.puzzleLevels, [3, 4])
        XCTAssertEqual(UserPreferences.DifficultySetting.hard.puzzleLevels, [5])
    }
    
    func testContainsPuzzleLevel() {
        // Test easy difficulty
        XCTAssertTrue(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(1))
        XCTAssertTrue(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(2))
        XCTAssertFalse(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(3))
        XCTAssertFalse(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(5))
        
        // Test normal difficulty
        XCTAssertFalse(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(1))
        XCTAssertFalse(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(2))
        XCTAssertTrue(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(3))
        XCTAssertTrue(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(4))
        XCTAssertFalse(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(5))
        
        // Test hard difficulty
        XCTAssertFalse(UserPreferences.DifficultySetting.hard.containsPuzzleLevel(1))
        XCTAssertFalse(UserPreferences.DifficultySetting.hard.containsPuzzleLevel(4))
        XCTAssertTrue(UserPreferences.DifficultySetting.hard.containsPuzzleLevel(5))
    }
    
    func testDisplayName() {
        XCTAssertEqual(UserPreferences.DifficultySetting.easy.displayName, "Easy")
        XCTAssertEqual(UserPreferences.DifficultySetting.normal.displayName, "Medium")
        XCTAssertEqual(UserPreferences.DifficultySetting.hard.displayName, "Hard")
    }
    
    func testColor() {
        XCTAssertEqual(UserPreferences.DifficultySetting.easy.color, "green")
        XCTAssertEqual(UserPreferences.DifficultySetting.normal.color, "blue")
        XCTAssertEqual(UserPreferences.DifficultySetting.hard.color, "red")
    }
    
    func testIcon() {
        XCTAssertEqual(UserPreferences.DifficultySetting.easy.icon, "star.fill")
        XCTAssertEqual(UserPreferences.DifficultySetting.normal.icon, "star.leadinghalf.filled")
        XCTAssertEqual(UserPreferences.DifficultySetting.hard.icon, "star.circle.fill")
    }
    
    func testForPuzzleLevel() {
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(1), .easy)
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(2), .easy)
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(3), .normal)
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(4), .normal)
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(5), .hard)
        
        // Test edge cases
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(0), .easy) // Default to easy
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(6), .easy) // Default to easy
        XCTAssertEqual(UserPreferences.DifficultySetting.forPuzzleLevel(-1), .easy) // Default to easy
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCases() {
        // Test with extreme values
        XCTAssertFalse(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(Int.max))
        XCTAssertFalse(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(Int.min))
        
        // Test boundary values
        XCTAssertTrue(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(1))
        XCTAssertTrue(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(2))
        XCTAssertFalse(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(3))
        
        XCTAssertFalse(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(2))
        XCTAssertTrue(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(3))
        XCTAssertTrue(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(4))
        XCTAssertFalse(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(5))
        
        XCTAssertFalse(UserPreferences.DifficultySetting.hard.containsPuzzleLevel(4))
        XCTAssertTrue(UserPreferences.DifficultySetting.hard.containsPuzzleLevel(5))
        XCTAssertFalse(UserPreferences.DifficultySetting.hard.containsPuzzleLevel(6))
    }
}
