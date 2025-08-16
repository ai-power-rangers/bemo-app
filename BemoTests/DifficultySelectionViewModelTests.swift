//
//  DifficultySelectionViewModelTests.swift
//  BemoTests
//
//  Unit tests for DifficultySelectionViewModel functionality
//

import XCTest
@testable import Bemo

final class DifficultySelectionViewModelTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var viewModel: DifficultySelectionViewModel!
    private var mockProgressService: TangramProgressService!
    private var mockPuzzleService: MockPuzzleLibraryService!
    private var mockUserDefaults: UserDefaults!
    private var samplePuzzles: [GamePuzzleData]!
    private let testChildId = "test-child-123"
    private var difficultySelectedCallbackInvoked = false
    private var selectedDifficulty: UserPreferences.DifficultySetting?
    
    override func setUp() {
        super.setUp()
        
        // Create isolated UserDefaults for testing
        let suiteName = "DifficultySelectionViewModelTests-\(UUID().uuidString)"
        mockUserDefaults = UserDefaults(suiteName: suiteName)!
        
        // Initialize mock services
        mockProgressService = TangramProgressService(userDefaults: mockUserDefaults, supabaseService: nil)
        samplePuzzles = createSamplePuzzles()
        mockPuzzleService = MockPuzzleLibraryService(puzzles: samplePuzzles)
        
        // Reset callback state
        difficultySelectedCallbackInvoked = false
        selectedDifficulty = nil
    }
    
    override func tearDown() {
        // Clean up test data
        mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.description)
        
        viewModel = nil
        mockProgressService = nil
        mockPuzzleService = nil
        mockUserDefaults = nil
        samplePuzzles = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createSamplePuzzles() -> [GamePuzzleData] {
        return [
            // Easy puzzles (1-2 stars) - 3 total
            GamePuzzleData(id: "easy-01", name: "Easy Cat", category: "animals", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy-02", name: "Easy Dog", category: "animals", difficulty: 2, targetPieces: []),
            GamePuzzleData(id: "easy-03", name: "Easy House", category: "objects", difficulty: 1, targetPieces: []),
            
            // Normal puzzles (3-4 stars) - 2 total
            GamePuzzleData(id: "normal-01", name: "Medium Bird", category: "animals", difficulty: 3, targetPieces: []),
            GamePuzzleData(id: "normal-02", name: "Medium Tree", category: "nature", difficulty: 4, targetPieces: []),
            
            // Hard puzzles (5 stars) - 2 total
            GamePuzzleData(id: "hard-01", name: "Hard Dragon", category: "fantasy", difficulty: 5, targetPieces: []),
            GamePuzzleData(id: "hard-02", name: "Hard Castle", category: "buildings", difficulty: 5, targetPieces: [])
        ]
    }
    
    private func createViewModel() -> DifficultySelectionViewModel {
        return DifficultySelectionViewModel(
            childProfileId: testChildId,
            progressService: mockProgressService,
            puzzleLibraryService: mockPuzzleService,
            onDifficultySelected: { [weak self] difficulty in
                self?.difficultySelectedCallbackInvoked = true
                self?.selectedDifficulty = difficulty
            }
        )
    }
    
    private func waitForAsyncData() async {
        // Give time for async loadDifficultyData to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        viewModel = createViewModel()
        
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.childProfileId, testChildId)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.availableDifficulties.count, 3)
        XCTAssertNil(viewModel.recommendedDifficulty)
        XCTAssertNil(viewModel.lastSelectedDifficulty)
        XCTAssertTrue(viewModel.difficultyStats.isEmpty)
    }
    
    func testAsyncDataLoading() async {
        viewModel = createViewModel()
        
        // Initially loading
        XCTAssertTrue(viewModel.isLoading)
        
        // Wait for async data loading
        await waitForAsyncData()
        
        // Should finish loading
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.difficultyStats.isEmpty)
    }
    
    // MARK: - Difficulty Stats Calculation Tests
    
    func testDifficultyStatsCalculationForNewUser() async {
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // Verify stats for new user
        let easyStats = viewModel.difficultyStats[.easy]
        let normalStats = viewModel.difficultyStats[.normal]
        let hardStats = viewModel.difficultyStats[.hard]
        
        XCTAssertNotNil(easyStats)
        XCTAssertNotNil(normalStats)
        XCTAssertNotNil(hardStats)
        
        // Easy: 3 puzzles, 0 completed, unlocked
        XCTAssertEqual(easyStats?.totalPuzzles, 3)
        XCTAssertEqual(easyStats?.completedPuzzles, 0)
        XCTAssertTrue(easyStats?.isUnlocked ?? false)
        XCTAssertEqual(easyStats?.completionPercentage ?? 0.0, 0.0, accuracy: 0.001)
        
        // Normal: 2 puzzles, 0 completed, locked for new user
        XCTAssertEqual(normalStats?.totalPuzzles, 2)
        XCTAssertEqual(normalStats?.completedPuzzles, 0)
        XCTAssertFalse(normalStats?.isUnlocked ?? true)
        XCTAssertEqual(normalStats?.completionPercentage ?? 0.0, 0.0, accuracy: 0.001)
        
        // Hard: 2 puzzles, 0 completed, locked for new user
        XCTAssertEqual(hardStats?.totalPuzzles, 2)
        XCTAssertEqual(hardStats?.completedPuzzles, 0)
        XCTAssertFalse(hardStats?.isUnlocked ?? true)
        XCTAssertEqual(hardStats?.completionPercentage ?? 0.0, 0.0, accuracy: 0.001)
    }
    
    func testDifficultyStatsCalculationWithProgress() async {
        // Add some progress data
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-02", difficulty: .easy)
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "normal-01", difficulty: .normal)
        
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // Verify updated stats
        let easyStats = viewModel.difficultyStats[.easy]
        let normalStats = viewModel.difficultyStats[.normal]
        
        XCTAssertNotNil(easyStats)
        XCTAssertNotNil(normalStats)
        
        // Easy: 3 puzzles, 2 completed
        XCTAssertEqual(easyStats?.totalPuzzles, 3)
        XCTAssertEqual(easyStats?.completedPuzzles, 2)
        XCTAssertEqual(easyStats?.completionPercentage ?? 0.0, 200.0/3.0, accuracy: 0.1) // 66.7%
        
        // Normal: 2 puzzles, 1 completed  
        XCTAssertEqual(normalStats?.totalPuzzles, 2)
        XCTAssertEqual(normalStats?.completedPuzzles, 1)
        XCTAssertEqual(normalStats?.completionPercentage ?? 0.0, 50.0, accuracy: 0.001)
    }
    
    // MARK: - Recommendation Logic Tests
    
    func testRecommendedDifficultyForNewUser() async {
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // New user should be recommended Easy
        XCTAssertEqual(viewModel.recommendedDifficulty, .easy)
        XCTAssertTrue(viewModel.isDifficultyRecommended(.easy))
        XCTAssertFalse(viewModel.isDifficultyRecommended(.normal))
        XCTAssertFalse(viewModel.isDifficultyRecommended(.hard))
    }
    
    func testRecommendedDifficultyForReturningUser() async {
        // Add progress and set last selected
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        mockProgressService.setLastSelectedDifficulty(childId: testChildId, difficulty: .easy)
        
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // Should recommend continuing with Easy since not completed
        XCTAssertEqual(viewModel.recommendedDifficulty, .easy)
        XCTAssertEqual(viewModel.lastSelectedDifficulty, .easy)
    }
    
    func testRecommendedDifficultyAfterCompletion() async {
        // Complete all easy puzzles
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-02", difficulty: .easy) 
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-03", difficulty: .easy)
        mockProgressService.setLastSelectedDifficulty(childId: testChildId, difficulty: .easy)
        
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // Should recommend Normal since Easy is completed
        XCTAssertEqual(viewModel.recommendedDifficulty, .normal)
    }
    
    // MARK: - User Type Detection Tests
    
    func testIsNewUserDetection() async {
        viewModel = createViewModel()
        await waitForAsyncData()
        
        XCTAssertTrue(viewModel.isNewUser)
    }
    
    func testIsNotNewUserDetection() async {
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        viewModel = createViewModel()
        await waitForAsyncData()
        
        XCTAssertFalse(viewModel.isNewUser)
    }
    
    // MARK: - Difficulty Selection Tests
    
    func testCanSelectUnlockedDifficulty() async {
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // Easy should be unlocked for new user
        XCTAssertTrue(viewModel.canSelectDifficulty(.easy))
        
        // Normal and Hard should be locked for new user
        XCTAssertFalse(viewModel.canSelectDifficulty(.normal))
        XCTAssertFalse(viewModel.canSelectDifficulty(.hard))
    }
    
    func testSelectUnlockedDifficulty() async {
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // Select easy difficulty
        viewModel.selectDifficulty(.easy)
        
        // Verify callback was triggered
        XCTAssertTrue(difficultySelectedCallbackInvoked)
        XCTAssertEqual(selectedDifficulty, .easy)
        
        // Verify progress service was updated
        let progress = mockProgressService.getProgress(for: testChildId)
        XCTAssertEqual(progress.lastSelectedDifficulty, .easy)
    }
    
    func testSelectLockedDifficulty() async {
        viewModel = createViewModel()
        await waitForAsyncData()
        
        // Try to select locked difficulty
        viewModel.selectDifficulty(.normal)
        
        // Callback should not be triggered
        XCTAssertFalse(difficultySelectedCallbackInvoked)
        XCTAssertNil(selectedDifficulty)
        
        // Error message should be set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("not yet unlocked") ?? false)
    }
    
    // MARK: - Progress Text Generation Tests
    
    func testGetProgressTextForLoadedStats() async {
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        viewModel = createViewModel()
        await waitForAsyncData()
        
        let progressText = viewModel.getProgressText(for: .easy)
        XCTAssertEqual(progressText, "1 of 3 completed")
    }
    
    func testGetProgressTextForEmptyStats() {
        viewModel = createViewModel()
        
        // Before data is loaded
        let progressText = viewModel.getProgressText(for: .easy)
        XCTAssertEqual(progressText, "Loading...")
    }
    
    func testGetCompletionPercentage() async {
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        viewModel = createViewModel()
        await waitForAsyncData()
        
        let percentage = viewModel.getCompletionPercentage(for: .easy)
        XCTAssertEqual(percentage, 100.0/3.0, accuracy: 0.1) // 33.3%
    }
    
    // MARK: - Overall Progress Tests
    
    func testOverallProgressCalculation() async {
        // Complete 1 easy puzzle (1/7 total)
        mockProgressService.markPuzzleCompleted(childId: testChildId, puzzleId: "easy-01", difficulty: .easy)
        
        viewModel = createViewModel()
        await waitForAsyncData()
        
        let expectedProgress = 100.0 / 7.0 // 1 completed out of 7 total puzzles
        XCTAssertEqual(viewModel.overallProgress, expectedProgress, accuracy: 0.1)
    }
    
    func testOverallProgressForNewUser() async {
        viewModel = createViewModel()
        await waitForAsyncData()
        
        XCTAssertEqual(viewModel.overallProgress, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Description Text Tests
    
    func testGetDifficultyDescription() {
        viewModel = createViewModel()
        
        XCTAssertEqual(viewModel.getDifficultyDescription(.easy), "Perfect for beginners (1-2 star puzzles)")
        XCTAssertEqual(viewModel.getDifficultyDescription(.normal), "Ready for a challenge? (3-4 star puzzles)")
        XCTAssertEqual(viewModel.getDifficultyDescription(.hard), "Expert level (5 star puzzles)")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingWithFailingPuzzleService() async {
        // Create a failing puzzle service
        let failingService = FailingMockPuzzleLibraryService()
        
        viewModel = DifficultySelectionViewModel(
            childProfileId: testChildId,
            progressService: mockProgressService,
            puzzleLibraryService: failingService,
            onDifficultySelected: { _ in }
        )
        
        await waitForAsyncData()
        
        // Should handle error gracefully
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Failed to load difficulty data") ?? false)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyPuzzleList() async {
        // Create service with empty puzzle list
        let emptyPuzzleService = MockPuzzleLibraryService(puzzles: [])
        
        viewModel = DifficultySelectionViewModel(
            childProfileId: testChildId,
            progressService: mockProgressService,
            puzzleLibraryService: emptyPuzzleService,
            onDifficultySelected: { _ in }
        )
        
        await waitForAsyncData()
        
        // Should handle empty puzzle list gracefully
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        
        // All difficulties should have 0 puzzles
        for difficulty in UserPreferences.DifficultySetting.allCases {
            let stats = viewModel.difficultyStats[difficulty]
            XCTAssertNotNil(stats)
            XCTAssertEqual(stats?.totalPuzzles, 0)
            XCTAssertEqual(stats?.completedPuzzles, 0)
            XCTAssertEqual(stats?.completionPercentage, 0.0)
        }
    }
    
    // MARK: - DifficultyStats Tests
    
    func testDifficultyStatsInitialization() {
        let stats = DifficultySelectionViewModel.DifficultyStats(
            totalPuzzles: 10,
            completedPuzzles: 3,
            isUnlocked: true
        )
        
        XCTAssertEqual(stats.totalPuzzles, 10)
        XCTAssertEqual(stats.completedPuzzles, 3)
        XCTAssertTrue(stats.isUnlocked)
        XCTAssertEqual(stats.completionPercentage, 30.0, accuracy: 0.001)
    }
    
    func testDifficultyStatsWithZeroPuzzles() {
        let stats = DifficultySelectionViewModel.DifficultyStats(
            totalPuzzles: 0,
            completedPuzzles: 0,
            isUnlocked: false
        )
        
        XCTAssertEqual(stats.totalPuzzles, 0)
        XCTAssertEqual(stats.completedPuzzles, 0)
        XCTAssertFalse(stats.isUnlocked)
        XCTAssertEqual(stats.completionPercentage, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Memory Management Tests
    
    func testCallbackDoesNotRetainViewModel() {
        weak var weakViewModel: DifficultySelectionViewModel?
        
        autoreleasepool {
            let strongViewModel = createViewModel()
            weakViewModel = strongViewModel
            XCTAssertNotNil(weakViewModel)
        }
        
        // ViewModel should be deallocated
        XCTAssertNil(weakViewModel)
    }
}

// MARK: - Helper Mock Classes

private class FailingMockPuzzleLibraryService: PuzzleLibraryProviding {
    func loadPuzzles() async throws -> [GamePuzzleData] {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error for testing"])
    }
    
    func savePuzzle(_ puzzle: GamePuzzleData) async throws {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error for testing"])
    }
    
    func deletePuzzle(id: String) async throws {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error for testing"])
    }
}

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
