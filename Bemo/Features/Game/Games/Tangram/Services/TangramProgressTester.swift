//
//  TangramProgressTester.swift
//  Bemo
//
//  Simple console-based tester for TangramProgress functionality
//

// WHAT: Console-based testing utility for TangramProgress and TangramProgressService
// ARCHITECTURE: Utility class for testing/debugging progress functionality
// USAGE: Call TangramProgressTester.runTests() from anywhere to validate functionality

import Foundation

struct TangramProgressTester {
    
    /// Run comprehensive tests and print results to console
    static func runTests() {
        print("🧪 TangramProgress Testing Suite")
        print("================================\n")
        
        testTangramProgressModel()
        testTangramProgressService()
        testDifficultyMapping()
        testSequentialUnlock()
        
        print("\n✅ All tests completed! Check console output above.")
    }
    
    // MARK: - Test Functions
    
    static func testTangramProgressModel() {
        print("📋 Testing TangramProgress Model...")
        
        let childId = "test-child-123"
        var progress = TangramProgress(childProfileId: childId)
        
        // Test initial state
        assert(progress.childProfileId == childId)
        assert(progress.lastSelectedDifficulty == nil)
        assert(progress.completedPuzzlesByDifficulty.isEmpty)
        print("   ✅ Initial state correct")
        
        // Test puzzle completion
        progress.markPuzzleCompleted(puzzleId: "easy1", difficulty: .easy)
        assert(progress.isPuzzleCompleted(puzzleId: "easy1", difficulty: .easy))
        assert(progress.getCompletedCount(for: .easy) == 1)
        print("   ✅ Puzzle completion tracking works")
        
        // Test difficulty setting
        progress.setLastSelectedDifficulty(.normal)
        assert(progress.lastSelectedDifficulty == .normal)
        print("   ✅ Difficulty setting works")
        
        print("   🎉 TangramProgress Model: ALL PASSED\n")
    }
    
    static func testTangramProgressService() {
        print("🔧 Testing TangramProgressService...")
        
        let service = TangramProgressService()
        let childId = "test-child-service"
        
        // Test progress creation
        let progress = service.getProgress(for: childId)
        assert(progress.childProfileId == childId)
        assert(service.childCount == 1)
        print("   ✅ Progress creation works")
        
        // Test puzzle completion through service
        service.markPuzzleCompleted(childId: childId, puzzleId: "easy1", difficulty: .easy)
        let updatedProgress = service.getProgress(for: childId)
        assert(updatedProgress.isPuzzleCompleted(puzzleId: "easy1", difficulty: .easy))
        print("   ✅ Service puzzle completion works")
        
        // Test difficulty setting
        service.setLastSelectedDifficulty(childId: childId, difficulty: .hard)
        let finalProgress = service.getProgress(for: childId)
        assert(finalProgress.lastSelectedDifficulty == .hard)
        print("   ✅ Service difficulty setting works")
        
        print("   🎉 TangramProgressService: ALL PASSED\n")
    }
    
    static func testDifficultyMapping() {
        print("🎯 Testing Difficulty Mapping...")
        
        // Test level mapping
        assert(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(1))
        assert(UserPreferences.DifficultySetting.easy.containsPuzzleLevel(2))
        assert(!UserPreferences.DifficultySetting.easy.containsPuzzleLevel(3))
        print("   ✅ Easy difficulty mapping correct")
        
        assert(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(3))
        assert(UserPreferences.DifficultySetting.normal.containsPuzzleLevel(4))
        assert(!UserPreferences.DifficultySetting.normal.containsPuzzleLevel(5))
        print("   ✅ Normal difficulty mapping correct")
        
        assert(UserPreferences.DifficultySetting.hard.containsPuzzleLevel(5))
        assert(!UserPreferences.DifficultySetting.hard.containsPuzzleLevel(4))
        print("   ✅ Hard difficulty mapping correct")
        
        // Test forPuzzleLevel static method
        assert(UserPreferences.DifficultySetting.forPuzzleLevel(1) == .easy)
        assert(UserPreferences.DifficultySetting.forPuzzleLevel(3) == .normal)
        assert(UserPreferences.DifficultySetting.forPuzzleLevel(5) == .hard)
        print("   ✅ forPuzzleLevel static method works")
        
        print("   🎉 Difficulty Mapping: ALL PASSED\n")
    }
    
    static func testSequentialUnlock() {
        print("🔒 Testing Sequential Unlock Logic...")
        
        let service = TangramProgressService()
        let childId = "test-unlock-child"
        let puzzles = createTestPuzzles()
        
        // Initially only first puzzle should be unlocked
        let initialUnlocked = service.getUnlockedPuzzles(for: childId, difficulty: .easy, from: puzzles)
        assert(initialUnlocked.count == 1)
        assert(initialUnlocked.first?.id == "easy-01")
        print("   ✅ Initial unlock state correct (only first puzzle)")
        
        // Complete first puzzle
        service.markPuzzleCompleted(childId: childId, puzzleId: "easy-01", difficulty: .easy)
        let afterFirst = service.getUnlockedPuzzles(for: childId, difficulty: .easy, from: puzzles)
        assert(afterFirst.count == 2)
        assert(afterFirst.last?.id == "easy-02")
        print("   ✅ Sequential unlock after completion works")
        
        // Test next puzzle logic
        let nextPuzzle = service.getNextPuzzle(for: childId, difficulty: .easy, from: puzzles)
        assert(nextPuzzle?.id == "easy-02")
        print("   ✅ Next puzzle logic works")
        
        // Complete all easy puzzles and test promotion
        service.markPuzzleCompleted(childId: childId, puzzleId: "easy-02", difficulty: .easy)
        service.markPuzzleCompleted(childId: childId, puzzleId: "easy-03", difficulty: .easy)
        
        let shouldPromote = service.shouldPromoteToNextDifficulty(childId: childId, currentDifficulty: .easy, from: puzzles)
        assert(shouldPromote == true)
        print("   ✅ Promotion detection works")
        
        print("   🎉 Sequential Unlock Logic: ALL PASSED\n")
    }
    
    // MARK: - Helper Functions
    
    static func createTestPuzzles() -> [GamePuzzleData] {
        return [
            // Easy puzzles (sorted by ID for sequential testing)
            GamePuzzleData(id: "easy-01", name: "Easy Cat", category: "animals", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy-02", name: "Easy Dog", category: "animals", difficulty: 2, targetPieces: []),
            GamePuzzleData(id: "easy-03", name: "Easy House", category: "objects", difficulty: 1, targetPieces: []),
            
            // Normal puzzles
            GamePuzzleData(id: "normal-01", name: "Medium Bird", category: "animals", difficulty: 3, targetPieces: []),
            GamePuzzleData(id: "normal-02", name: "Medium Tree", category: "nature", difficulty: 4, targetPieces: []),
            
            // Hard puzzles
            GamePuzzleData(id: "hard-01", name: "Hard Dragon", category: "fantasy", difficulty: 5, targetPieces: []),
            GamePuzzleData(id: "hard-02", name: "Hard Castle", category: "buildings", difficulty: 5, targetPieces: [])
        ]
    }
}

// MARK: - Convenience Extension

extension TangramProgressService {
    /// Add some test data for debugging
    func addQuickTestData() {
        let testChild = "quick-test-child"
        markPuzzleCompleted(childId: testChild, puzzleId: "easy1", difficulty: .easy)
        markPuzzleCompleted(childId: testChild, puzzleId: "normal1", difficulty: .normal)
        setLastSelectedDifficulty(childId: testChild, difficulty: .normal)
        
        print("🧪 Quick test data added for child: \(testChild)")
        debugPrintProgress()
    }
}
