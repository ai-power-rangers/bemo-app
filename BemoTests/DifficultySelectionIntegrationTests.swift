//
//  DifficultySelectionIntegrationTests.swift
//  BemoTests
//
//  Integration tests for difficulty selection flow and user experience scenarios
//

import XCTest
@testable import Bemo

final class DifficultySelectionIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var progressService: TangramProgressService!
    private var puzzleService: MockPuzzleLibraryService!
    private var mockUserDefaults: UserDefaults!
    private var samplePuzzles: [GamePuzzleData]!
    private let child1Id = "child-1"
    private let child2Id = "child-2"
    
    override func setUp() {
        super.setUp()
        
        // Create isolated UserDefaults for testing
        let suiteName = "DifficultySelectionIntegrationTests-\(UUID().uuidString)"
        mockUserDefaults = UserDefaults(suiteName: suiteName)!
        
        // Initialize services
        progressService = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        samplePuzzles = createSamplePuzzles()
        puzzleService = MockPuzzleLibraryService(puzzles: samplePuzzles)
    }
    
    override func tearDown() {
        // Clean up test data
        mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.description)
        
        progressService = nil
        puzzleService = nil
        mockUserDefaults = nil
        samplePuzzles = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createSamplePuzzles() -> [GamePuzzleData] {
        return [
            // Easy puzzles (1-2 stars) - 4 total
            GamePuzzleData(id: "easy-01", name: "Easy Cat", category: "animals", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy-02", name: "Easy Dog", category: "animals", difficulty: 2, targetPieces: []),
            GamePuzzleData(id: "easy-03", name: "Easy House", category: "objects", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy-04", name: "Easy Tree", category: "nature", difficulty: 2, targetPieces: []),
            
            // Normal puzzles (3-4 stars) - 3 total
            GamePuzzleData(id: "normal-01", name: "Medium Bird", category: "animals", difficulty: 3, targetPieces: []),
            GamePuzzleData(id: "normal-02", name: "Medium Flower", category: "nature", difficulty: 4, targetPieces: []),
            GamePuzzleData(id: "normal-03", name: "Medium Car", category: "vehicles", difficulty: 3, targetPieces: []),
            
            // Hard puzzles (5 stars) - 2 total
            GamePuzzleData(id: "hard-01", name: "Hard Dragon", category: "fantasy", difficulty: 5, targetPieces: []),
            GamePuzzleData(id: "hard-02", name: "Hard Castle", category: "buildings", difficulty: 5, targetPieces: [])
        ]
    }
    
    private func createViewModel(for childId: String) -> DifficultySelectionViewModel {
        var selectedDifficulty: UserPreferences.DifficultySetting?
        
        return DifficultySelectionViewModel(
            childProfileId: childId,
            progressService: progressService,
            puzzleLibraryService: puzzleService,
            onDifficultySelected: { difficulty in
                selectedDifficulty = difficulty
            }
        )
    }
    
    private func waitForAsyncData() async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - New User Onboarding Flow Tests
    
    func testNewUserOnboardingFlow() async {
        // Simulate new user experience
        let viewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        // Step 1: New user sees Easy unlocked, others locked
        XCTAssertTrue(viewModel.canSelectDifficulty(.easy))
        XCTAssertFalse(viewModel.canSelectDifficulty(.normal))
        XCTAssertFalse(viewModel.canSelectDifficulty(.hard))
        
        // Step 2: New user is recommended Easy
        XCTAssertEqual(viewModel.recommendedDifficulty, .easy)
        XCTAssertTrue(viewModel.isNewUser)
        
        // Step 3: User selects Easy (simulating UI interaction)
        var callbackTriggered = false
        var selectedDiff: UserPreferences.DifficultySetting?
        
        let userViewModel = DifficultySelectionViewModel(
            childProfileId: child1Id,
            progressService: progressService,
            puzzleLibraryService: puzzleService,
            onDifficultySelected: { difficulty in
                callbackTriggered = true
                selectedDiff = difficulty
            }
        )
        
        await waitForAsyncData()
        userViewModel.selectDifficulty(.easy)
        
        // Step 4: Verify selection was processed
        XCTAssertTrue(callbackTriggered)
        XCTAssertEqual(selectedDiff, .easy)
        
        // Step 5: Verify progress service was updated
        let progress = progressService.getProgress(for: child1Id)
        XCTAssertEqual(progress.lastSelectedDifficulty, .easy)
    }
    
    // MARK: - Returning User Flow Tests
    
    func testReturningUserFlow() async {
        // Setup: User has some progress in Easy difficulty
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-01", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-02", difficulty: .easy)
        progressService.setLastSelectedDifficulty(childId: child1Id, difficulty: .easy)
        
        let viewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        // Step 1: Returning user should not be flagged as new
        XCTAssertFalse(viewModel.isNewUser)
        
        // Step 2: Last selected difficulty should be restored
        XCTAssertEqual(viewModel.lastSelectedDifficulty, .easy)
        
        // Step 3: Should be recommended to continue with Easy (not completed)
        XCTAssertEqual(viewModel.recommendedDifficulty, .easy)
        
        // Step 4: Progress should be accurately reflected
        let easyStats = viewModel.difficultyStats[.easy]
        XCTAssertEqual(easyStats?.completedPuzzles, 2)
        XCTAssertEqual(easyStats?.totalPuzzles, 4)
        XCTAssertEqual(easyStats?.completionPercentage, 50.0, accuracy: 0.001)
        
        // Step 5: Easy should still be unlocked, others locked until progression threshold
        XCTAssertTrue(viewModel.canSelectDifficulty(.easy))
        // Note: Normal unlock depends on DifficultyProgression logic
    }
    
    func testProgressionToNextDifficulty() async {
        // Setup: Complete enough Easy puzzles to unlock Normal
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-01", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-02", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-03", difficulty: .easy)
        progressService.setLastSelectedDifficulty(childId: child1Id, difficulty: .easy)
        
        let viewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        // Step 1: Easy should be mostly completed
        let easyStats = viewModel.difficultyStats[.easy]
        XCTAssertEqual(easyStats?.completedPuzzles, 3)
        XCTAssertEqual(easyStats?.totalPuzzles, 4)
        XCTAssertEqual(easyStats?.completionPercentage, 75.0, accuracy: 0.001)
        
        // Step 2: User completes final easy puzzle
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-04", difficulty: .easy)
        
        // Create new view model to reflect updated progress
        let updatedViewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        // Step 3: Easy should be 100% complete
        let updatedEasyStats = updatedViewModel.difficultyStats[.easy]
        XCTAssertEqual(updatedEasyStats?.completedPuzzles, 4)
        XCTAssertEqual(updatedEasyStats?.completionPercentage, 100.0, accuracy: 0.001)
        
        // Step 4: Should now recommend Normal difficulty
        XCTAssertEqual(updatedViewModel.recommendedDifficulty, .normal)
    }
    
    // MARK: - Multiple Children Profile Switching Tests
    
    func testMultipleChildrenProfileSwitching() async {
        // Setup: Two children with different progress
        
        // Child 1: Beginner with some easy progress
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-01", difficulty: .easy)
        progressService.setLastSelectedDifficulty(childId: child1Id, difficulty: .easy)
        
        // Child 2: Advanced with easy completed, normal in progress
        progressService.markPuzzleCompleted(childId: child2Id, puzzleId: "easy-01", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child2Id, puzzleId: "easy-02", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child2Id, puzzleId: "easy-03", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child2Id, puzzleId: "easy-04", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child2Id, puzzleId: "normal-01", difficulty: .normal)
        progressService.setLastSelectedDifficulty(childId: child2Id, difficulty: .normal)
        
        // Test Child 1 ViewModel
        let child1ViewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        XCTAssertFalse(child1ViewModel.isNewUser)
        XCTAssertEqual(child1ViewModel.lastSelectedDifficulty, .easy)
        XCTAssertEqual(child1ViewModel.recommendedDifficulty, .easy)
        
        let child1EasyStats = child1ViewModel.difficultyStats[.easy]
        XCTAssertEqual(child1EasyStats?.completedPuzzles, 1)
        XCTAssertEqual(child1EasyStats?.completionPercentage, 25.0, accuracy: 0.001)
        
        // Test Child 2 ViewModel
        let child2ViewModel = createViewModel(for: child2Id)
        await waitForAsyncData()
        
        XCTAssertFalse(child2ViewModel.isNewUser)
        XCTAssertEqual(child2ViewModel.lastSelectedDifficulty, .normal)
        XCTAssertEqual(child2ViewModel.recommendedDifficulty, .normal)
        
        let child2EasyStats = child2ViewModel.difficultyStats[.easy]
        let child2NormalStats = child2ViewModel.difficultyStats[.normal]
        
        XCTAssertEqual(child2EasyStats?.completedPuzzles, 4)
        XCTAssertEqual(child2EasyStats?.completionPercentage, 100.0, accuracy: 0.001)
        XCTAssertEqual(child2NormalStats?.completedPuzzles, 1)
        
        // Verify progress isolation
        XCTAssertNotEqual(child1ViewModel.overallProgress, child2ViewModel.overallProgress)
    }
    
    // MARK: - Progress Persistence Tests
    
    func testProgressPersistenceAcrossAppRestart() async {
        // Setup progress
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-01", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "normal-01", difficulty: .normal)
        progressService.setLastSelectedDifficulty(childId: child1Id, difficulty: .normal)
        
        let initialViewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        let initialProgress = initialViewModel.overallProgress
        let initialLastSelected = initialViewModel.lastSelectedDifficulty
        
        // Simulate app restart by creating new service with same UserDefaults
        let restartedProgressService = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        
        let restartedViewModel = DifficultySelectionViewModel(
            childProfileId: child1Id,
            progressService: restartedProgressService,
            puzzleLibraryService: puzzleService,
            onDifficultySelected: { _ in }
        )
        
        await waitForAsyncData()
        
        // Verify persistence
        XCTAssertEqual(restartedViewModel.overallProgress, initialProgress, accuracy: 0.001)
        XCTAssertEqual(restartedViewModel.lastSelectedDifficulty, initialLastSelected)
        
        let easyStats = restartedViewModel.difficultyStats[.easy]
        let normalStats = restartedViewModel.difficultyStats[.normal]
        
        XCTAssertEqual(easyStats?.completedPuzzles, 1)
        XCTAssertEqual(normalStats?.completedPuzzles, 1)
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryFlow() async {
        // Test recovery from corrupted data
        let corruptData = "invalid-json-data".data(using: .utf8)!
        mockUserDefaults.set(corruptData, forKey: "com.bemo.tangram.progress")
        
        // Create service with corrupted data
        let recoveryService = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        
        let viewModel = DifficultySelectionViewModel(
            childProfileId: child1Id,
            progressService: recoveryService,
            puzzleLibraryService: puzzleService,
            onDifficultySelected: { _ in }
        )
        
        await waitForAsyncData()
        
        // Should handle corruption gracefully and create fresh progress
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isNewUser)
        XCTAssertEqual(viewModel.recommendedDifficulty, .easy)
        
        // Should be able to make progress normally after recovery
        viewModel.selectDifficulty(.easy)
        let progress = recoveryService.getProgress(for: child1Id)
        XCTAssertEqual(progress.lastSelectedDifficulty, .easy)
    }
    
    // MARK: - Complete User Journey Tests
    
    func testCompleteUserJourneyFromNewToAdvanced() async {
        var currentViewModel: DifficultySelectionViewModel
        
        // Phase 1: New User
        currentViewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        XCTAssertTrue(currentViewModel.isNewUser)
        XCTAssertEqual(currentViewModel.recommendedDifficulty, .easy)
        XCTAssertTrue(currentViewModel.canSelectDifficulty(.easy))
        XCTAssertFalse(currentViewModel.canSelectDifficulty(.normal))
        
        // Phase 2: Start with Easy
        currentViewModel.selectDifficulty(.easy)
        
        // Simulate playing and completing some easy puzzles
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-01", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-02", difficulty: .easy)
        
        // Phase 3: Returning to difficulty selection with partial easy progress
        currentViewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        XCTAssertFalse(currentViewModel.isNewUser)
        XCTAssertEqual(currentViewModel.lastSelectedDifficulty, .easy)
        XCTAssertEqual(currentViewModel.recommendedDifficulty, .easy) // Continue with Easy
        
        let midEasyStats = currentViewModel.difficultyStats[.easy]
        XCTAssertEqual(midEasyStats?.completedPuzzles, 2)
        XCTAssertEqual(midEasyStats?.completionPercentage, 50.0, accuracy: 0.001)
        
        // Phase 4: Complete Easy difficulty
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-03", difficulty: .easy)
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "easy-04", difficulty: .easy)
        
        // Phase 5: Return after completing Easy
        currentViewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        XCTAssertEqual(currentViewModel.recommendedDifficulty, .normal) // Progress to Normal
        let completedEasyStats = currentViewModel.difficultyStats[.easy]
        XCTAssertEqual(completedEasyStats?.completionPercentage, 100.0, accuracy: 0.001)
        
        // Phase 6: Start Normal difficulty
        currentViewModel.selectDifficulty(.normal)
        progressService.markPuzzleCompleted(childId: child1Id, puzzleId: "normal-01", difficulty: .normal)
        
        // Phase 7: Final state check - experienced user with multi-difficulty progress
        currentViewModel = createViewModel(for: child1Id)
        await waitForAsyncData()
        
        XCTAssertEqual(currentViewModel.lastSelectedDifficulty, .normal)
        XCTAssertGreaterThan(currentViewModel.overallProgress, 50.0) // Significant overall progress
        
        let finalEasyStats = currentViewModel.difficultyStats[.easy]
        let finalNormalStats = currentViewModel.difficultyStats[.normal]
        
        XCTAssertEqual(finalEasyStats?.completionPercentage, 100.0, accuracy: 0.001)
        XCTAssertGreaterThan(finalNormalStats?.completionPercentage ?? 0, 0.0)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() async {
        // Create a large dataset to test performance
        var largePuzzleSet: [GamePuzzleData] = []
        
        // Generate 100 puzzles per difficulty (300 total)
        for i in 1...100 {
            largePuzzleSet.append(GamePuzzleData(id: "easy-\(String(format: "%03d", i))", name: "Easy \(i)", category: "test", difficulty: 1, targetPieces: []))
            largePuzzleSet.append(GamePuzzleData(id: "normal-\(String(format: "%03d", i))", name: "Normal \(i)", category: "test", difficulty: 3, targetPieces: []))
            largePuzzleSet.append(GamePuzzleData(id: "hard-\(String(format: "%03d", i))", name: "Hard \(i)", category: "test", difficulty: 5, targetPieces: []))
        }
        
        let largeDataService = MockPuzzleLibraryService(puzzles: largePuzzleSet)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let viewModel = DifficultySelectionViewModel(
            childProfileId: child1Id,
            progressService: progressService,
            puzzleLibraryService: largeDataService,
            onDifficultySelected: { _ in }
        )
        
        await waitForAsyncData()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Should complete within reasonable time (less than 1 second)
        XCTAssertLessThan(executionTime, 1.0)
        
        // Should handle large dataset correctly
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        
        let easyStats = viewModel.difficultyStats[.easy]
        XCTAssertEqual(easyStats?.totalPuzzles, 100)
    }
}

// MARK: - Helper Mock Classes

private class MockPuzzleLibraryService: PuzzleLibraryProviding {
    private let puzzles: [GamePuzzleData]
    
    init(puzzles: [GamePuzzleData] = []) {
        self.puzzles = puzzles
    }
    
    func loadPuzzles() async throws -> [GamePuzzleData] {
        return puzzles
    }
    
    func savePuzzle(_ puzzle: GamePuzzleData) async throws {
        // Mock implementation - do nothing
    }
    
    func deletePuzzle(id: String) async throws {
        // Mock implementation - do nothing
    }
}
