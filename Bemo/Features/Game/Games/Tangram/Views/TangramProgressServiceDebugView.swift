//
//  TangramProgressServiceDebugView.swift
//  Bemo
//
//  Enhanced debug view to test TangramProgressService functionality
//

// WHAT: Debug UI to test TangramProgressService with persistence and multiple children
// ARCHITECTURE: SwiftUI View for debugging/testing service layer
// USAGE: Add to DevTools to test full progress service functionality

import SwiftUI

struct TangramProgressServiceDebugView: View {
    @State private var progressService = TangramProgressService()
    @State private var selectedChildId = "test-child-1"
    @State private var selectedDifficulty: UserPreferences.DifficultySetting = .easy
    @State private var showingChildSelector = false
    @State private var testResults: String = ""
    @State private var testStatus: TestStatus = .notRun
    
    enum TestStatus {
        case notRun, running, passed, failed
        
        var color: Color {
            switch self {
            case .notRun: return .gray
            case .running: return .orange
            case .passed: return .green
            case .failed: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .notRun: return "circle"
            case .running: return "hourglass"
            case .passed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
        
        var text: String {
            switch self {
            case .notRun: return "Ready to test"
            case .running: return "Running tests..."
            case .passed: return "All tests passed!"
            case .failed: return "Some tests failed"
            }
        }
    }
    
    // Sample puzzle data for testing
    private let samplePuzzles: [GamePuzzleData] = [
        GamePuzzleData(id: "easy-01", name: "Easy Cat", category: "animals", difficulty: 1, targetPieces: []),
        GamePuzzleData(id: "easy-02", name: "Easy Dog", category: "animals", difficulty: 2, targetPieces: []),
        GamePuzzleData(id: "easy-03", name: "Easy House", category: "objects", difficulty: 1, targetPieces: []),
        GamePuzzleData(id: "normal-01", name: "Medium Bird", category: "animals", difficulty: 3, targetPieces: []),
        GamePuzzleData(id: "normal-02", name: "Medium Tree", category: "nature", difficulty: 4, targetPieces: []),
        GamePuzzleData(id: "hard-01", name: "Hard Dragon", category: "fantasy", difficulty: 5, targetPieces: []),
        GamePuzzleData(id: "hard-02", name: "Hard Castle", category: "buildings", difficulty: 5, targetPieces: [])
    ]
    
    private let availableChildren = ["test-child-1", "test-child-2", "test-child-3"]
    
    var currentProgress: TangramProgress {
        progressService.getProgress(for: selectedChildId)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    Text("TangramProgressService Debug")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Service Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Service Status:")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(progressService.isSyncing ? Color.orange : Color.green)
                                .frame(width: 8, height: 8)
                            Text(progressService.isSyncing ? "Syncing..." : "Ready")
                                .font(.caption)
                        }
                        
                        Text("Total Children: \(progressService.progressByChild.count)")
                            .font(.caption)
                        Text("Active Child: \(selectedChildId)")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Child Selector
                    VStack(alignment: .leading) {
                        Text("Select Child Profile:")
                            .font(.headline)
                        
                        HStack {
                            Picker("Child", selection: $selectedChildId) {
                                ForEach(availableChildren, id: \.self) { childId in
                                    Text(childId).tag(childId)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Button("Add Test Child") {
                                let newChildId = "child-\(Date().timeIntervalSince1970)"
                                selectedChildId = newChildId
                                _ = progressService.getProgress(for: newChildId)
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    
                    // Difficulty Selector
                    VStack(alignment: .leading) {
                        Text("Select Difficulty:")
                            .font(.headline)
                        
                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(UserPreferences.DifficultySetting.allCases, id: \.self) { difficulty in
                                HStack {
                                    Image(systemName: difficulty.icon)
                                    Text(difficulty.displayName)
                                }
                                .tag(difficulty)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedDifficulty) { _, newDifficulty in
                            progressService.setLastSelectedDifficulty(childId: selectedChildId, difficulty: newDifficulty)
                        }
                    }
                    
                    // Progress Statistics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress Statistics:")
                            .font(.headline)
                        
                        let stats = progressService.getCompletionStats(for: selectedChildId, difficulty: selectedDifficulty, from: samplePuzzles)
                        
                        Text("Difficulty: \(selectedDifficulty.displayName)")
                        Text("Completed: \(stats.completed)/\(stats.total)")
                        Text("Progress: \(String(format: "%.1f%%", stats.percentage * 100))")
                        Text("Overall: \(String(format: "%.1f%%", currentProgress.getTotalProgress(from: samplePuzzles) * 100))")
                        
                        if let nextPuzzle = progressService.getNextPuzzle(for: selectedChildId, difficulty: selectedDifficulty, from: samplePuzzles) {
                            Text("Next Puzzle: \(nextPuzzle.name)")
                                .foregroundColor(.blue)
                        } else {
                            Text("All puzzles completed! 🎉")
                                .foregroundColor(.green)
                        }
                        
                        if progressService.shouldPromoteToNextDifficulty(childId: selectedChildId, currentDifficulty: selectedDifficulty, from: samplePuzzles) {
                            if let nextDifficulty = currentProgress.getNextDifficulty() {
                                Text("🎊 Ready for promotion to \(nextDifficulty.displayName)!")
                                    .foregroundColor(.orange)
                                    .fontWeight(.bold)
                            } else {
                                Text("🏆 All difficulties completed!")
                                    .foregroundColor(.purple)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Puzzle List with Service Integration
                    VStack(alignment: .leading) {
                        Text("Puzzles for \(selectedDifficulty.displayName):")
                            .font(.headline)
                        
                        let unlockedPuzzles = progressService.getUnlockedPuzzles(for: selectedChildId, difficulty: selectedDifficulty, from: samplePuzzles)
                        let difficultyPuzzles = samplePuzzles
                            .filter { selectedDifficulty.containsPuzzleLevel($0.difficulty) }
                            .sorted { $0.id < $1.id }
                        
                        ForEach(difficultyPuzzles, id: \.id) { puzzle in
                            ServicePuzzleRowView(
                                puzzle: puzzle,
                                isCompleted: currentProgress.isPuzzleCompleted(puzzleId: puzzle.id, difficulty: selectedDifficulty),
                                isUnlocked: progressService.isPuzzleUnlocked(childId: selectedChildId, puzzleId: puzzle.id, difficulty: selectedDifficulty, from: samplePuzzles),
                                onToggleCompletion: {
                                    if currentProgress.isPuzzleCompleted(puzzleId: puzzle.id, difficulty: selectedDifficulty) {
                                        // For testing: reset a puzzle (not typical behavior)
                                        var progress = currentProgress
                                        var completed = progress.getCompletedPuzzles(for: selectedDifficulty)
                                        completed.remove(puzzle.id)
                                        progress.completedPuzzlesByDifficulty[selectedDifficulty.rawValue] = completed
                                        progressService.updateProgress(progress)
                                    } else {
                                        // Mark as completed through service
                                        progressService.markPuzzleCompleted(childId: selectedChildId, puzzleId: puzzle.id, difficulty: selectedDifficulty)
                                    }
                                }
                            )
                        }
                    }
                    
                    // Service Action Buttons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Actions:")
                            .font(.headline)
                        
                        HStack {
                            Button("Add Test Data") {
                                progressService.addTestData()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Reset Current Child") {
                                let emptyProgress = TangramProgress(childProfileId: selectedChildId)
                                progressService.updateProgress(emptyProgress)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Complete Next") {
                                if let nextPuzzle = progressService.getNextPuzzle(for: selectedChildId, difficulty: selectedDifficulty, from: samplePuzzles) {
                                    progressService.markPuzzleCompleted(childId: selectedChildId, puzzleId: nextPuzzle.id, difficulty: selectedDifficulty)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        HStack {
                            Button("Reset All Progress") {
                                progressService.resetAllProgress()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button("Debug Print") {
                                progressService.debugPrintProgress()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        // Test Suite Button
                        HStack {
                            Button("🧪 Run Test Suite") {
                                runVisualTests()
                            }
                            .buttonStyle(.borderedProminent)
                            .background(testStatus.color)
                            .disabled(testStatus == .running)
                            
                            HStack {
                                Image(systemName: testStatus.icon)
                                    .foregroundColor(testStatus.color)
                                Text(testStatus.text)
                                    .font(.caption)
                                    .foregroundColor(testStatus.color)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Multi-Child Comparison
                    if progressService.progressByChild.count > 1 {
                        VStack(alignment: .leading) {
                            Text("All Children Progress:")
                                .font(.headline)
                            
                            ForEach(Array(progressService.progressByChild.keys).sorted(), id: \.self) { childId in
                                let childProgress = progressService.progressByChild[childId]!
                                HStack {
                                    Text(childId)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("Easy: \(childProgress.getCompletedCount(for: .easy))")
                                        .font(.caption2)
                                    Text("Med: \(childProgress.getCompletedCount(for: .normal))")
                                        .font(.caption2)
                                    Text("Hard: \(childProgress.getCompletedCount(for: .hard))")
                                        .font(.caption2)
                                    
                                    Button("Select") {
                                        selectedChildId = childId
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption2)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Test Results
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: testStatus.icon)
                                    .foregroundColor(testStatus.color)
                                Text("Test Results:")
                                    .font(.headline)
                                    .foregroundColor(testStatus.color)
                            }
                            
                            ScrollView {
                                Text(testResults)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 150)
                        }
                        .padding()
                        .background(testStatus.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Persistence Testing
                    VStack(alignment: .leading) {
                        Text("Persistence Testing:")
                            .font(.headline)
                        
                        Text("Complete a puzzle, then restart the app. Progress should persist!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Try switching children - each has independent progress.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("🧪 Use 'Run Test Suite' to validate all core functionality!")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .onAppear {
            // Set initial difficulty if child has none
            if currentProgress.lastSelectedDifficulty == nil {
                progressService.setLastSelectedDifficulty(childId: selectedChildId, difficulty: selectedDifficulty)
            } else if let lastDifficulty = currentProgress.lastSelectedDifficulty {
                selectedDifficulty = lastDifficulty
            }
        }
    }
    
    // MARK: - Test Methods
    
    private func runVisualTests() {
        testStatus = .running
        testResults = ""
        
        Task {
            // Simulate async testing
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                captureTestResults()
            }
        }
    }
    
    private func captureTestResults() {
        var results = ""
        var allPassed = true
        
        results += "🧪 Tangram Progress Test Suite\n"
        results += "================================\n\n"
        
        // Test 1: TangramProgress Model
        results += "📋 Testing TangramProgress Model...\n"
        do {
            let testChild = "test-validation-child"
            var progress = TangramProgress(childProfileId: testChild)
            
            // Test initial state
            guard progress.childProfileId == testChild,
                  progress.lastSelectedDifficulty == nil,
                  progress.completedPuzzlesByDifficulty.isEmpty else {
                results += "   ❌ Initial state incorrect\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Initial state correct\n"
            
            // Test puzzle completion
            progress.markPuzzleCompleted(puzzleId: "test1", difficulty: .easy)
            guard progress.isPuzzleCompleted(puzzleId: "test1", difficulty: .easy),
                  progress.getCompletedCount(for: .easy) == 1 else {
                results += "   ❌ Puzzle completion tracking failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Puzzle completion tracking works\n"
            
            // Test difficulty setting
            progress.setLastSelectedDifficulty(.normal)
            guard progress.lastSelectedDifficulty == .normal else {
                results += "   ❌ Difficulty setting failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Difficulty setting works\n"
            
            results += "   🎉 TangramProgress Model: ALL PASSED\n\n"
            
        } catch {
            results += "   ❌ TangramProgress Model: FAILED\n\n"
            allPassed = false
        }
        
        // Test 2: TangramProgressService
        results += "🔧 Testing TangramProgressService...\n"
        do {
            let testService = TangramProgressService()
            let testChild = "test-service-child"
            
            // Test progress creation
            let progress = testService.getProgress(for: testChild)
            guard progress.childProfileId == testChild,
                  testService.progressByChild.count >= 1 else {
                results += "   ❌ Progress creation failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Progress creation works\n"
            
            // Test puzzle completion through service
            testService.markPuzzleCompleted(childId: testChild, puzzleId: "test1", difficulty: .easy)
            let updatedProgress = testService.getProgress(for: testChild)
            guard updatedProgress.isPuzzleCompleted(puzzleId: "test1", difficulty: .easy) else {
                results += "   ❌ Service puzzle completion failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Service puzzle completion works\n"
            
            // Test difficulty setting
            testService.setLastSelectedDifficulty(childId: testChild, difficulty: .hard)
            let finalProgress = testService.getProgress(for: testChild)
            guard finalProgress.lastSelectedDifficulty == .hard else {
                results += "   ❌ Service difficulty setting failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Service difficulty setting works\n"
            
            results += "   🎉 TangramProgressService: ALL PASSED\n\n"
            
        } catch {
            results += "   ❌ TangramProgressService: FAILED\n\n"
            allPassed = false
        }
        
        // Test 3: Difficulty Mapping
        results += "🎯 Testing Difficulty Mapping...\n"
        do {
            // Test level mapping
            guard UserPreferences.DifficultySetting.easy.containsPuzzleLevel(1),
                  UserPreferences.DifficultySetting.easy.containsPuzzleLevel(2),
                  !UserPreferences.DifficultySetting.easy.containsPuzzleLevel(3) else {
                results += "   ❌ Easy difficulty mapping incorrect\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Easy difficulty mapping correct\n"
            
            guard UserPreferences.DifficultySetting.normal.containsPuzzleLevel(3),
                  UserPreferences.DifficultySetting.normal.containsPuzzleLevel(4),
                  !UserPreferences.DifficultySetting.normal.containsPuzzleLevel(5) else {
                results += "   ❌ Normal difficulty mapping incorrect\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Normal difficulty mapping correct\n"
            
            guard UserPreferences.DifficultySetting.hard.containsPuzzleLevel(5),
                  !UserPreferences.DifficultySetting.hard.containsPuzzleLevel(4) else {
                results += "   ❌ Hard difficulty mapping incorrect\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Hard difficulty mapping correct\n"
            
            // Test forPuzzleLevel static method
            guard UserPreferences.DifficultySetting.forPuzzleLevel(1) == .easy,
                  UserPreferences.DifficultySetting.forPuzzleLevel(3) == .normal,
                  UserPreferences.DifficultySetting.forPuzzleLevel(5) == .hard else {
                results += "   ❌ forPuzzleLevel method failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ forPuzzleLevel static method works\n"
            
            results += "   🎉 Difficulty Mapping: ALL PASSED\n\n"
            
        } catch {
            results += "   ❌ Difficulty Mapping: FAILED\n\n"
            allPassed = false
        }
        
        // Test 4: Sequential Unlock Logic
        results += "🔒 Testing Sequential Unlock Logic...\n"
        do {
            let testService = TangramProgressService()
            let testChild = "test-unlock-child"
            
            // Initially only first puzzle should be unlocked
            let initialUnlocked = testService.getUnlockedPuzzles(for: testChild, difficulty: .easy, from: samplePuzzles)
            guard initialUnlocked.count == 1,
                  initialUnlocked.first?.id == "easy-01" else {
                results += "   ❌ Initial unlock state incorrect\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Initial unlock state correct (only first puzzle)\n"
            
            // Complete first puzzle
            testService.markPuzzleCompleted(childId: testChild, puzzleId: "easy-01", difficulty: .easy)
            let afterFirst = testService.getUnlockedPuzzles(for: testChild, difficulty: .easy, from: samplePuzzles)
            guard afterFirst.count == 2,
                  afterFirst.last?.id == "easy-02" else {
                results += "   ❌ Sequential unlock after completion failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Sequential unlock after completion works\n"
            
            // Test next puzzle logic
            let nextPuzzle = testService.getNextPuzzle(for: testChild, difficulty: .easy, from: samplePuzzles)
            guard nextPuzzle?.id == "easy-02" else {
                results += "   ❌ Next puzzle logic failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Next puzzle logic works\n"
            
            results += "   🎉 Sequential Unlock Logic: ALL PASSED\n\n"
            
        } catch {
            results += "   ❌ Sequential Unlock Logic: FAILED\n\n"
            allPassed = false
        }
        
        // Final results
        if allPassed {
            results += "✅ ALL TESTS PASSED! Phase 1 implementation is working correctly.\n"
            testStatus = .passed
        } else {
            results += "❌ SOME TESTS FAILED. Check implementation.\n"
            testStatus = .failed
        }
        
        testResults = results
        
        // Also print to console for developers
        print(results)
    }
    
    private enum TestError: Error {
        case failed
    }
}

struct ServicePuzzleRowView: View {
    let puzzle: GamePuzzleData
    let isCompleted: Bool
    let isUnlocked: Bool
    let onToggleCompletion: () -> Void
    
    var body: some View {
        HStack {
            // Status Icon
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 20)
            
            // Puzzle Info
            VStack(alignment: .leading) {
                Text(puzzle.name)
                    .fontWeight(.medium)
                Text("\(puzzle.difficulty)⭐ • \(puzzle.category)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status Text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Action Button
            Button(action: onToggleCompletion) {
                Text(isCompleted ? "Reset" : "Complete")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCompleted ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .disabled(!isUnlocked && !isCompleted)
        }
        .padding(.vertical, 4)
        .opacity(isUnlocked || isCompleted ? 1.0 : 0.5)
    }
    
    private var statusIcon: String {
        if isCompleted {
            return "checkmark.circle.fill"
        } else if isUnlocked {
            return "circle"
        } else {
            return "lock.fill"
        }
    }
    
    private var statusColor: Color {
        if isCompleted {
            return .green
        } else if isUnlocked {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if isCompleted {
            return "Done"
        } else if isUnlocked {
            return "Available"
        } else {
            return "Locked"
        }
    }
}

#Preview {
    TangramProgressServiceDebugView()
}
