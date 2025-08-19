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
    @State private var selectedDifficulty: UserPreferences.DifficultySetting = UserPreferences.DifficultySetting.easy
    @State private var showingChildSelector = false
    @State private var testResults: String = ""
    @State private var testStatus: TestStatus = .notRun
    
    // Test the new PuzzleLibraryService filtering
    @State private var puzzleLibraryService = PuzzleLibraryService()
    @State private var puzzleFilterTestResults: String = ""
    @State private var usingMockData: Bool = false
    
    // Test TangramMapViewModel
    @State private var mapViewModel: TangramMapViewModel?
    @State private var mapTestResults: String = ""
    @State private var selectedMapDifficulty: UserPreferences.DifficultySetting = .easy
    
    // Test MapNodeView Component
    @State private var showingMapNodeDemo: Bool = false
    
    // Test TangramMapView Interface (NEW)
    @State private var showMapView: Bool = false
    
    // DifficultySelectionViewModel testing
    @State private var difficultySelectionViewModel: DifficultySelectionViewModel?
    @State private var viewModelTestStatus: TestStatus = .notRun
    @State private var selectedDifficultyFromViewModel: UserPreferences.DifficultySetting?
    
    // Phase 4 Auto-Promotion testing
    @State private var phase4TestResults: String = ""
    
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
        NavigationStack {
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
                        
                        Text("Total Children: \(progressService.childCount)")
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
                        
                        let _ = progressService.getUnlockedPuzzles(for: selectedChildId, difficulty: selectedDifficulty, from: samplePuzzles)
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
                        
                        // Puzzle Library Status
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📚 Puzzle Library Status:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Circle()
                                    .fill(puzzleLibraryService.isLoading ? Color.orange : 
                                          puzzleLibraryService.availablePuzzles.isEmpty ? Color.red : Color.green)
                                    .frame(width: 8, height: 8)
                                
                                if puzzleLibraryService.isLoading {
                                    Text("Loading puzzles...")
                                } else if puzzleLibraryService.availablePuzzles.isEmpty {
                                    Text("No puzzles loaded (using mock data)")
                                } else {
                                    Text("\(puzzleLibraryService.availablePuzzles.count) puzzles loaded")
                                }
                            }
                            .font(.caption)
                            
                            if let error = puzzleLibraryService.loadError {
                                Text("⚠️ Error: \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(puzzleLibraryService.availablePuzzles.isEmpty ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Test new puzzle filtering functionality
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🧪 New Filtering Tests:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Button("Test Easy Puzzles") {
                                    testPuzzleFiltering(.easy)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Test Medium Puzzles") {
                                    testPuzzleFiltering(.normal)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Test Hard Puzzles") {
                                    testPuzzleFiltering(.hard)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            HStack {
                                Button("Use Mock Data") {
                                    loadMockPuzzles()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.blue)
                                
                                Button("Retry Database") {
                                    puzzleLibraryService.loadPuzzles()
                                    usingMockData = false
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.green)
                            }
                            
                            if !puzzleFilterTestResults.isEmpty {
                                ScrollView {
                                    Text(puzzleFilterTestResults)
                                        .font(.system(size: 11).monospaced())
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .frame(maxHeight: 120)
                            }
                        }
                        
                        // Test TangramMapViewModel
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🗺️ Map ViewModel Tests:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            // Difficulty selector for map testing
                            HStack {
                                Text("Test Difficulty:")
                                    .font(.caption)
                                
                                Picker("Map Difficulty", selection: $selectedMapDifficulty) {
                                    ForEach([UserPreferences.DifficultySetting.easy, .normal, .hard], id: \.self) { difficulty in
                                        Text(difficulty.displayName).tag(difficulty)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            HStack {
                                Button("Create MapViewModel") {
                                    createMapViewModel()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.blue)
                                
                                Button("Test Map Logic") {
                                    testMapViewModel()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.green)
                                .disabled(mapViewModel == nil)
                                
                                Button("Simulate Completion") {
                                    simulatePuzzleCompletion()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.orange)
                                .disabled(mapViewModel == nil)
                            }
                            
                            HStack {
                                Button("Reset Child Progress") {
                                    resetCurrentChildProgress()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                                
                                Button("Refresh ViewModel") {
                                    mapViewModel?.refresh()
                                    mapTestResults += "\n🔄 ViewModel refreshed manually\n"
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.purple)
                                .disabled(mapViewModel == nil)
                            }
                            
                            // NEW: TangramMapView Test Button  
                            Button("🗺️ Test TangramMapView Interface") {
                                showMapView = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(mapViewModel == nil)
                            .padding(.top, 4)
                            
                            if !mapTestResults.isEmpty {
                                ScrollView {
                                    Text(mapTestResults)
                                        .font(.system(size: 11).monospaced())
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .frame(maxHeight: 150)
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                        
                        // MapNodeView Visual Demo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🎯 MapNodeView Component Test")
                                .font(.headline)
                                .foregroundColor(.indigo)
                            
                            Button(showingMapNodeDemo ? "Hide MapNodeView Demo" : "Show MapNodeView Demo") {
                                showingMapNodeDemo.toggle()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.indigo)
                            
                            if showingMapNodeDemo {
                                VStack(spacing: 16) {
                                    Text("All Node States (Linear Progression):")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 20) {
                                        MapNodeView(
                                            puzzle: GamePuzzleData.mockPuzzle(id: "demo1", name: "Future", difficulty: 2),
                                            nodeState: .locked,
                                            onTap: { print("🔒 Locked node tapped (no action)") }
                                        )
                                        
                                        MapNodeView(
                                            puzzle: GamePuzzleData.mockPuzzle(id: "demo2", name: "Next", difficulty: 3),
                                            nodeState: .current,
                                            onTap: { print("🎯 Current node tapped") }
                                        )
                                        
                                        MapNodeView(
                                            puzzle: GamePuzzleData.mockPuzzle(id: "demo3", name: "Done", difficulty: 4),
                                            nodeState: .completed,
                                            onTap: { print("✅ Completed node tapped") }
                                        )
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("Connection Lines Demo:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        VStack(spacing: 0) {
                                            MapNodeView(
                                                puzzle: GamePuzzleData.mockPuzzle(id: "demo5", name: "Cat", difficulty: 2),
                                                nodeState: .completed,
                                                onTap: { print("🐱 Cat completed") }
                                            )
                                            MapConnectionLine(isCompleted: true)
                                            MapNodeView(
                                                puzzle: GamePuzzleData.mockPuzzle(id: "demo6", name: "Dog", difficulty: 3),
                                                nodeState: .current,
                                                onTap: { print("🐕 Dog current") }
                                            )
                                            MapConnectionLine(isCompleted: false)
                                            MapNodeView(
                                                puzzle: GamePuzzleData.mockPuzzle(id: "demo7", name: "Bird", difficulty: 4),
                                                nodeState: .locked,
                                                onTap: { print("🐦 Bird locked") }
                                            )
                                        }
                                    }
                                    
                                    Text("💡 Linear progression: Complete current → next unlocks!")
                                        .font(.caption2)
                                        .foregroundColor(.indigo)
                                        .italic()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(8)
                        
                        // NEW: TangramMapView Test Section
                        if showMapView, let mapViewModel = mapViewModel {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🗺️ TangramMapView Full Interface Test:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("Live TangramMapView with all features:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Full TangramMapView Integration
                                TangramMapView(viewModel: mapViewModel)
                                    .frame(height: 400)
                                    .background(TangramTheme.Backgrounds.editor)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                    )
                                
                                Text("✅ Test: ScrollView, nodes, progress bar, navigation")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .italic()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
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
                    if progressService.childCount > 1 {
                        VStack(alignment: .leading) {
                            Text("All Children Progress:")
                                .font(.headline)
                            
                            ForEach(Array(progressService.getAllProgressData().keys).sorted(), id: \.self) { childId in
                                if let childProgress = progressService.getAllProgressData()[childId] {
                                    HStack {
                                        Text(childId)
                                            .font(.caption)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Text("Easy: \(childProgress.getCompletedCount(for: UserPreferences.DifficultySetting.easy))")
                                            .font(.caption2)
                                        Text("Med: \(childProgress.getCompletedCount(for: UserPreferences.DifficultySetting.normal))")
                                            .font(.caption2)
                                        Text("Hard: \(childProgress.getCompletedCount(for: UserPreferences.DifficultySetting.hard))")
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
                    
                    // DifficultySelectionViewModel Testing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🎯 DifficultySelectionViewModel Testing:")
                            .font(.headline)
                        
                        HStack {
                            Button("Create ViewModel") {
                                createDifficultySelectionViewModel()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Test ViewModel Logic") {
                                testDifficultySelectionViewModel()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(difficultySelectionViewModel == nil)
                            
                            HStack {
                                Image(systemName: viewModelTestStatus.icon)
                                    .foregroundColor(viewModelTestStatus.color)
                                Text(viewModelTestStatus.text)
                                    .font(.caption)
                                    .foregroundColor(viewModelTestStatus.color)
                            }
                        }
                        
                        if let viewModel = difficultySelectionViewModel {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ViewModel State:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Text("Loading: \(viewModel.isLoading ? "Yes" : "No")")
                                        .font(.caption)
                                    Text("New User: \(viewModel.isNewUser ? "Yes" : "No")")
                                        .font(.caption)
                                    if let recommended = viewModel.recommendedDifficulty {
                                        Text("Recommended: \(recommended.displayName)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text("Difficulty Stats:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                ForEach([UserPreferences.DifficultySetting.easy, UserPreferences.DifficultySetting.normal, UserPreferences.DifficultySetting.hard], id: \.self) { difficulty in
                                    HStack {
                                        Text("\(difficulty.displayName):")
                                            .font(.caption2)
                                            .frame(width: 60, alignment: .leading)
                                        
                                        if let stats = viewModel.difficultyStats[difficulty] {
                                            Text("\(stats.completedPuzzles)/\(stats.totalPuzzles)")
                                                .font(.caption2)
                                            Text("(\(Int(stats.completionPercentage))%)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(stats.isUnlocked ? "🔓" : "🔒")
                                                .font(.caption2)
                                            
                                            if viewModel.isDifficultyRecommended(difficulty) {
                                                Text("⭐ Recommended")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            }
                                        } else {
                                            Text("Loading...")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                
                                HStack {
                                    Text("Test Difficulty Selection:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    ForEach([UserPreferences.DifficultySetting.easy, UserPreferences.DifficultySetting.normal, UserPreferences.DifficultySetting.hard], id: \.self) { difficulty in
                                        Button(difficulty.displayName) {
                                            viewModel.selectDifficulty(difficulty)
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                        .disabled(!viewModel.canSelectDifficulty(difficulty))
                                    }
                                }
                                
                                if let errorMessage = viewModel.errorMessage {
                                    Text("Error: \(errorMessage)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                                
                                if let selectedDiff = selectedDifficultyFromViewModel {
                                    Text("✅ Last Selected: \(selectedDiff.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    
                    // DifficultySelectionView UI Testing (Task 2)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🎨 DifficultySelectionView UI Testing:")
                            .font(.headline)
                        
                        Text("Task 2 Implementation - Full UI with cards, animations, and accessibility")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let viewModel = difficultySelectionViewModel {
                            DifficultySelectionView(viewModel: viewModel)
                                .frame(maxHeight: 600)
                                .border(Color.blue.opacity(0.3), width: 2)
                        } else {
                            VStack {
                                Text("Create ViewModel first to test the UI")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // PHASE 4: Difficulty Completion & Auto-Promotion Testing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🚀 Phase 4: Auto-Promotion Testing")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("Test difficulty completion detection and promotion logic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Completion simulation buttons
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Difficulty Completion Simulation:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 12) {
                                Button("🟢 Simulate Easy Complete") {
                                    simulateDifficultyCompletion(.easy)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("🔵 Simulate Medium Complete") {
                                    simulateDifficultyCompletion(.normal)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("🔴 Simulate Hard Complete") {
                                    simulateDifficultyCompletion(.hard)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            HStack(spacing: 12) {
                                Button("🎉 Test Promotion Interstitial") {
                                    testPromotionInterstitial()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("🏆 Test Final Completion") {
                                    testFinalCompletion()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            
                            // Comprehensive Task 1 test
                            Button("🧪 Run Comprehensive Task 1 Tests") {
                                testPhase4Task1Implementation()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        
                        // Promotion status display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Promotion Status:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            ForEach([UserPreferences.DifficultySetting.easy, .normal, .hard], id: \.self) { difficulty in
                                let isCompleted = progressService.isDifficultyCompleted(
                                    for: selectedChildId, 
                                    difficulty: difficulty, 
                                    from: samplePuzzles
                                )
                                let nextDifficulty = progressService.getNextDifficultyForPromotion(from: difficulty)
                                
                                HStack {
                                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isCompleted ? .green : .gray)
                                    
                                    Text("\(difficulty.displayName)")
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    if isCompleted {
                                        if let next = nextDifficulty {
                                            Text("→ \(next.displayName)")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        } else {
                                            Text("🎉 ALL COMPLETE!")
                                                .font(.caption)
                                                .foregroundColor(.purple)
                                        }
                                    } else {
                                        let stats = progressService.getCompletionStats(
                                            for: selectedChildId, 
                                            difficulty: difficulty, 
                                            from: samplePuzzles
                                        )
                                        Text("\(stats.completed)/\(stats.total)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(isCompleted ? Color.green.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            }
                        }
                        
                        // Phase 4 test results
                        if !phase4TestResults.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phase 4 Test Results:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(phase4TestResults)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
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
    
    private func createDifficultySelectionViewModel() {
        // Create a mock PuzzleLibraryService with our sample puzzles
        let mockPuzzleService = MockTangramPuzzleLibraryService(puzzles: samplePuzzles)
        
        difficultySelectionViewModel = DifficultySelectionViewModel(
            childProfileId: selectedChildId,
            progressService: progressService,
            puzzleLibraryService: mockPuzzleService,
            onDifficultySelected: { [self] difficulty in
                selectedDifficultyFromViewModel = difficulty
                print("🎯 DifficultySelectionViewModel: User selected \(difficulty.displayName)")
            }
        )
        
        viewModelTestStatus = .notRun
        selectedDifficultyFromViewModel = nil
        print("✅ DifficultySelectionViewModel created for child: \(selectedChildId)")
    }
    
    private func testDifficultySelectionViewModel() {
        guard let viewModel = difficultySelectionViewModel else {
            print("❌ No ViewModel to test. Create one first.")
            return
        }
        
        viewModelTestStatus = .running
        
        Task {
            // Test async loading
            await viewModel.loadDifficultyData()
            
            await MainActor.run {
                // Validate the ViewModel state
                let hasStats = !viewModel.difficultyStats.isEmpty
                let hasRecommendation = viewModel.recommendedDifficulty != nil
                let isConsistent = viewModel.isNewUser == (viewModel.difficultyStats.values.allSatisfy { $0.completedPuzzles == 0 })
                
                if hasStats && hasRecommendation && isConsistent {
                    viewModelTestStatus = .passed
                    print("✅ DifficultySelectionViewModel test PASSED")
                    print("   - Difficulty stats loaded: \(viewModel.difficultyStats.count)")
                    print("   - Is new user: \(viewModel.isNewUser)")
                    print("   - Recommended difficulty: \(viewModel.recommendedDifficulty?.displayName ?? "None")")
                } else {
                    viewModelTestStatus = .failed
                    print("❌ DifficultySelectionViewModel test FAILED")
                    print("   - Has stats: \(hasStats)")
                    print("   - Has recommendation: \(hasRecommendation)")
                    print("   - Is consistent: \(isConsistent)")
                }
            }
        }
    }
    
    private func runVisualTests() {
        testStatus = .running
        testResults = ""
        
        Task {
            // Simulate async testing
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await captureTestResults()
        }
    }
    
    private func loadMockPuzzles() {
        puzzleFilterTestResults = "Loading mock puzzle data...\n\n"
        
        // Create mock puzzles for testing
        let mockPuzzles = [
            // Easy puzzles (1-2 star)
            GamePuzzleData(id: "easy-001", name: "Simple Cat", category: "Animals", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy-002", name: "Basic House", category: "Buildings", difficulty: 1, targetPieces: []),
            GamePuzzleData(id: "easy-003", name: "Small Tree", category: "Nature", difficulty: 2, targetPieces: []),
            GamePuzzleData(id: "easy-004", name: "Fish Shape", category: "Animals", difficulty: 2, targetPieces: []),
            
            // Medium puzzles (3-4 star)
            GamePuzzleData(id: "medium-010", name: "Flying Bird", category: "Animals", difficulty: 3, targetPieces: []),
            GamePuzzleData(id: "medium-015", name: "Tall Tower", category: "Buildings", difficulty: 3, targetPieces: []),
            GamePuzzleData(id: "medium-020", name: "Running Person", category: "People", difficulty: 4, targetPieces: []),
            GamePuzzleData(id: "medium-025", name: "Complex Flower", category: "Nature", difficulty: 4, targetPieces: []),
            
            // Hard puzzles (5 star)
            GamePuzzleData(id: "hard-030", name: "Dragon", category: "Fantasy", difficulty: 5, targetPieces: []),
            GamePuzzleData(id: "hard-035", name: "Castle", category: "Buildings", difficulty: 5, targetPieces: []),
            GamePuzzleData(id: "hard-040", name: "Sailing Ship", category: "Transport", difficulty: 5, targetPieces: [])
        ]
        
        // Load mock data into the service
        puzzleLibraryService.loadMockData(mockPuzzles)
        usingMockData = true
        
        puzzleFilterTestResults += "✅ Loaded \(mockPuzzles.count) mock puzzles!\n"
        puzzleFilterTestResults += "📊 Distribution:\n"
        puzzleFilterTestResults += "   • Easy (1-2⭐): \(mockPuzzles.filter { $0.difficulty <= 2 }.count) puzzles\n"
        puzzleFilterTestResults += "   • Medium (3-4⭐): \(mockPuzzles.filter { $0.difficulty >= 3 && $0.difficulty <= 4 }.count) puzzles\n"
        puzzleFilterTestResults += "   • Hard (5⭐): \(mockPuzzles.filter { $0.difficulty == 5 }.count) puzzles\n\n"
        puzzleFilterTestResults += "🎯 Now you can test the filtering methods!\n"
        
        print("🧪 Mock data loaded successfully")
    }
    
    private func testPuzzleFiltering(_ difficulty: UserPreferences.DifficultySetting) {
        // Check if we have any puzzles to test with
        if puzzleLibraryService.availablePuzzles.isEmpty {
            puzzleFilterTestResults = "⚠️  No puzzles available for testing!\n\n"
            puzzleFilterTestResults += "The database connection failed and no mock data is loaded.\n"
            puzzleFilterTestResults += "Please try:\n"
            puzzleFilterTestResults += "1. Click 'Use Mock Data' to load test puzzles\n"
            puzzleFilterTestResults += "2. Or click 'Retry Database' to reconnect\n"
            return
        }
        
        puzzleFilterTestResults = "Testing puzzlesForDifficulty(\(difficulty))...\n"
        if usingMockData {
            puzzleFilterTestResults += "(Using mock data - not real database)\n"
        }
        puzzleFilterTestResults += "\n"
        
        // Test the new filtering method
        let filteredPuzzles = puzzleLibraryService.puzzlesForDifficulty(difficulty)
        
        puzzleFilterTestResults += "✅ Method called successfully!\n"
        puzzleFilterTestResults += "📊 Results:\n"
        puzzleFilterTestResults += "   • Total puzzles found: \(filteredPuzzles.count)\n"
        puzzleFilterTestResults += "   • Difficulty filter: \(difficulty.displayName)\n"
        puzzleFilterTestResults += "   • Expected star levels: \(difficulty.puzzleLevels)\n\n"
        
        if filteredPuzzles.isEmpty {
            puzzleFilterTestResults += "⚠️  No puzzles found for this difficulty\n"
            puzzleFilterTestResults += "   This might mean no puzzles exist for difficulty \(difficulty.displayName)\n\n"
        } else {
            puzzleFilterTestResults += "🔍 Sample puzzles (first 5):\n"
            for (index, puzzle) in filteredPuzzles.prefix(5).enumerated() {
                puzzleFilterTestResults += "   \(index + 1). ID: \(puzzle.id), Difficulty: \(puzzle.difficulty)⭐, Name: \(puzzle.name)\n"
            }
            
            // Verify filtering worked correctly
            let correctlyFiltered = filteredPuzzles.allSatisfy { puzzle in
                difficulty.containsPuzzleLevel(puzzle.difficulty)
            }
            
            let sortedByID = filteredPuzzles.sorted { $0.id < $1.id } == filteredPuzzles
            
            puzzleFilterTestResults += "\n✨ Validation:\n"
            puzzleFilterTestResults += "   • All puzzles match difficulty: \(correctlyFiltered ? "✅" : "❌")\n"
            puzzleFilterTestResults += "   • Sorted by ID: \(sortedByID ? "✅" : "❌")\n"
        }
        
        print("🧪 Puzzle filtering test results:")
        print(puzzleFilterTestResults)
    }
    
    // MARK: - TangramMapViewModel Testing
    
    private func createMapViewModel() {
        mapTestResults = "Creating TangramMapViewModel for \(selectedMapDifficulty.displayName)...\n\n"
        
        // Ensure we have mock data
        if puzzleLibraryService.availablePuzzles.isEmpty {
            loadMockPuzzles()
            mapTestResults += "📚 Loaded mock data first\n\n"
        }
        
        // Create the map view model
        mapViewModel = TangramMapViewModel(
            difficulty: selectedMapDifficulty,
            childProfileId: selectedChildId,
            puzzleLibraryService: puzzleLibraryService,
            progressService: progressService,
            onPuzzleSelected: { puzzle in
                print("🎯 Puzzle selected: \(puzzle.name)")
            },
            onBackToDifficulty: {
                print("🔙 Back to difficulty selection")
            }
        )
        
        mapTestResults += "✅ TangramMapViewModel created successfully!\n"
        mapTestResults += "📊 Initial state:\n"
        mapTestResults += "   • Difficulty: \(selectedMapDifficulty.displayName)\n"
        mapTestResults += "   • Total puzzles: \(mapViewModel?.totalCount ?? 0)\n"
        mapTestResults += "   • Unlocked puzzles: \(mapViewModel?.unlockedPuzzleIds.count ?? 0)\n"
        mapTestResults += "   • Completed puzzles: \(mapViewModel?.completedCount ?? 0)\n"
        mapTestResults += "   • Current puzzle index: \(mapViewModel?.currentPuzzleIndex ?? 0)\n"
        
        if let nextPuzzle = mapViewModel?.nextPuzzle {
            mapTestResults += "   • Next puzzle: \(nextPuzzle.name)\n"
        }
        
        mapTestResults += "\n🎯 Ready for testing!\n"
        print("🧪 TangramMapViewModel created and initialized")
    }
    
    private func testMapViewModel() {
        guard let viewModel = mapViewModel else {
            mapTestResults = "❌ No MapViewModel created. Click 'Create MapViewModel' first.\n"
            return
        }
        
        mapTestResults = "Testing TangramMapViewModel functionality...\n\n"
        
        // Test basic properties
        mapTestResults += "📊 Map State:\n"
        mapTestResults += "   • Difficulty: \(viewModel.difficulty.displayName)\n"
        mapTestResults += "   • Total puzzles: \(viewModel.totalCount)\n"
        mapTestResults += "   • Unlocked puzzles: \(viewModel.unlockedPuzzleIds.count)\n"
        mapTestResults += "   • Completed puzzles: \(viewModel.completedCount)\n"
        mapTestResults += "   • Completion %: \(Int(viewModel.completionPercentage * 100))%\n"
        mapTestResults += "   • All completed: \(viewModel.isAllCompleted ? "Yes" : "No")\n\n"
        
        // Test puzzle node states
        mapTestResults += "🗺️ Puzzle Node States:\n"
        for (index, puzzle) in viewModel.puzzles.prefix(5).enumerated() {
            let state = viewModel.getNodeState(for: puzzle)
            let canSelect = viewModel.canSelectPuzzle(puzzle)
            let isCurrent = viewModel.isCurrentPuzzle(puzzle)
            let isCompleted = viewModel.isCompleted(puzzle.id)
            
            mapTestResults += "   \(index + 1). \(puzzle.name):\n"
            mapTestResults += "      • State: \(state)\n"
            mapTestResults += "      • Can select: \(canSelect ? "✅" : "❌")\n"
            mapTestResults += "      • Is current: \(isCurrent ? "🎯" : "⚪")\n"
            mapTestResults += "      • Is completed: \(isCompleted ? "✅" : "❌")\n"
        }
        
        if viewModel.puzzles.count > 5 {
            mapTestResults += "   ... and \(viewModel.puzzles.count - 5) more puzzles\n"
        }
        
        // Test puzzle selection
        mapTestResults += "\n🎮 Testing Puzzle Selection:\n"
        if let nextPuzzle = viewModel.nextPuzzle {
            if viewModel.canSelectPuzzle(nextPuzzle) {
                mapTestResults += "   ✅ Can select next puzzle: \(nextPuzzle.name)\n"
                mapTestResults += "   🎯 This would trigger: onPuzzleSelected(\(nextPuzzle.name))\n"
            } else {
                mapTestResults += "   ❌ Cannot select next puzzle: \(nextPuzzle.name)\n"
            }
        } else {
            mapTestResults += "   🏁 No next puzzle - all completed or no puzzles available\n"
        }
        
        mapTestResults += "\n✅ TangramMapViewModel test completed successfully!\n"
        print("🧪 TangramMapViewModel test completed")
    }
    
    private func simulatePuzzleCompletion() {
        guard let viewModel = mapViewModel else {
            mapTestResults = "❌ No MapViewModel created. Click 'Create MapViewModel' first.\n"
            return
        }
        
        guard let nextPuzzle = viewModel.nextPuzzle else {
            mapTestResults += "\n🏁 No more puzzles to complete!\n"
            return
        }
        
        mapTestResults += "\n🎮 Simulating completion of: \(nextPuzzle.name) (ID: \(nextPuzzle.id))\n"
        
        // Debug: Show state before completion
        let beforeCompleted = viewModel.completedCount
        let beforeUnlocked = viewModel.unlockedPuzzleIds.count
        mapTestResults += "🔍 BEFORE completion:\n"
        mapTestResults += "   • Completed: \(beforeCompleted), Unlocked: \(beforeUnlocked)\n"
        mapTestResults += "   • Unlocked IDs: \(Array(viewModel.unlockedPuzzleIds).sorted())\n"
        
        // Get progress before marking as completed
        let progressBefore = progressService.getProgress(for: selectedChildId)
        let completedBefore = progressBefore.getCompletedPuzzles(for: selectedMapDifficulty)
        mapTestResults += "   • Progress service completed before: \(completedBefore)\n"
        
        // Mark the puzzle as completed in the progress service
        progressService.markPuzzleCompleted(
            childId: selectedChildId,
            puzzleId: nextPuzzle.id,
            difficulty: selectedMapDifficulty
        )
        
        // Debug: Check progress service after marking
        let progressAfter = progressService.getProgress(for: selectedChildId)
        let completedAfter = progressAfter.getCompletedPuzzles(for: selectedMapDifficulty)
        mapTestResults += "🔍 AFTER marking completed:\n"
        mapTestResults += "   • Progress service completed after: \(completedAfter)\n"
        
        // Refresh the view model to update state
        viewModel.refresh()
        
        // Debug: Show state after refresh
        mapTestResults += "🔍 AFTER viewModel.refresh():\n"
        mapTestResults += "   • Completed: \(viewModel.completedCount), Unlocked: \(viewModel.unlockedPuzzleIds.count)\n"
        mapTestResults += "   • Unlocked IDs: \(Array(viewModel.unlockedPuzzleIds).sorted())\n"
        
        mapTestResults += "✅ Puzzle marked as completed!\n"
        mapTestResults += "📊 Final state:\n"
        mapTestResults += "   • Completed puzzles: \(viewModel.completedCount)\n"
        mapTestResults += "   • Completion %: \(Int(viewModel.completionPercentage * 100))%\n"
        mapTestResults += "   • Current puzzle index: \(viewModel.currentPuzzleIndex)\n"
        
        if let newNextPuzzle = viewModel.nextPuzzle {
            mapTestResults += "   • New next puzzle: \(newNextPuzzle.name)\n"
        } else {
            mapTestResults += "   🏁 All puzzles completed for this difficulty!\n"
        }
        
        print("🧪 Simulated puzzle completion: \(nextPuzzle.name)")
    }
    
    private func resetCurrentChildProgress() {
        // Reset progress for the current child
        let emptyProgress = TangramProgress(childProfileId: selectedChildId)
        progressService.updateProgress(emptyProgress)
        
        // Refresh the map view model if it exists
        mapViewModel?.refresh()
        
        mapTestResults += "\n🔄 Progress reset for child: \(selectedChildId)\n"
        mapTestResults += "   • All puzzles marked as incomplete\n"
        mapTestResults += "   • Only first puzzle should be unlocked now\n"
        
        print("🧪 Reset progress for child: \(selectedChildId)")
    }
    
    private func captureTestResults() async {
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
            progress.markPuzzleCompleted(puzzleId: "test1", difficulty: UserPreferences.DifficultySetting.easy)
            guard progress.isPuzzleCompleted(puzzleId: "test1", difficulty: UserPreferences.DifficultySetting.easy),
                  progress.getCompletedCount(for: UserPreferences.DifficultySetting.easy) == 1 else {
                results += "   ❌ Puzzle completion tracking failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Puzzle completion tracking works\n"
            
            // Test difficulty setting
            progress.setLastSelectedDifficulty(UserPreferences.DifficultySetting.normal)
            guard progress.lastSelectedDifficulty == UserPreferences.DifficultySetting.normal else {
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
                  testService.childCount >= 1 else {
                results += "   ❌ Progress creation failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Progress creation works\n"
            
            // Test puzzle completion through service
            testService.markPuzzleCompleted(childId: testChild, puzzleId: "test1", difficulty: UserPreferences.DifficultySetting.easy)
            let updatedProgress = testService.getProgress(for: testChild)
            guard updatedProgress.isPuzzleCompleted(puzzleId: "test1", difficulty: UserPreferences.DifficultySetting.easy) else {
                results += "   ❌ Service puzzle completion failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Service puzzle completion works\n"
            
            // Test difficulty setting
            testService.setLastSelectedDifficulty(childId: testChild, difficulty: UserPreferences.DifficultySetting.hard)
            let finalProgress = testService.getProgress(for: testChild)
            guard finalProgress.lastSelectedDifficulty == UserPreferences.DifficultySetting.hard else {
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
            guard UserPreferences.DifficultySetting.forPuzzleLevel(1) == UserPreferences.DifficultySetting.easy,
                  UserPreferences.DifficultySetting.forPuzzleLevel(3) == UserPreferences.DifficultySetting.normal,
                  UserPreferences.DifficultySetting.forPuzzleLevel(5) == UserPreferences.DifficultySetting.hard else {
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
            let initialUnlocked = testService.getUnlockedPuzzles(for: testChild, difficulty: UserPreferences.DifficultySetting.easy, from: samplePuzzles)
            guard initialUnlocked.count == 1,
                  initialUnlocked.first?.id == "easy-01" else {
                results += "   ❌ Initial unlock state incorrect\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Initial unlock state correct (only first puzzle)\n"
            
            // Complete first puzzle
            testService.markPuzzleCompleted(childId: testChild, puzzleId: "easy-01", difficulty: UserPreferences.DifficultySetting.easy)
            let afterFirst = testService.getUnlockedPuzzles(for: testChild, difficulty: UserPreferences.DifficultySetting.easy, from: samplePuzzles)
            guard afterFirst.count == 2,
                  afterFirst.last?.id == "easy-02" else {
                results += "   ❌ Sequential unlock after completion failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Sequential unlock after completion works\n"
            
            // Test next puzzle logic
            let nextPuzzle = testService.getNextPuzzle(for: testChild, difficulty: UserPreferences.DifficultySetting.easy, from: samplePuzzles)
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
        
        // Test 5: DifficultySelectionViewModel
        results += "🎯 Testing DifficultySelectionViewModel...\n"
        do {
            // Create a mock service for testing
            let mockService = MockTangramPuzzleLibraryService(puzzles: samplePuzzles)
            let testChild = "test-viewmodel-child"
            
            // Create ViewModel
            var testCompleted = false
            let viewModel = DifficultySelectionViewModel(
                childProfileId: testChild,
                progressService: progressService,
                puzzleLibraryService: mockService,
                onDifficultySelected: { difficulty in
                    testCompleted = true
                    results += "   ✅ Callback triggered with \(difficulty.displayName)\n"
                }
            )
            
            // Test initial state
            guard viewModel.childProfileId == testChild,
                  viewModel.isLoading == true,
                  viewModel.difficultyStats.isEmpty else {
                results += "   ❌ Initial ViewModel state incorrect\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Initial ViewModel state correct\n"
            
            // Test async loading
            await viewModel.loadDifficultyData()
            
            guard !viewModel.isLoading,
                  viewModel.difficultyStats.count == 3,
                  viewModel.recommendedDifficulty != nil else {
                results += "   ❌ ViewModel data loading failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ ViewModel data loading works\n"
            
            // Test difficulty selection
            if viewModel.canSelectDifficulty(UserPreferences.DifficultySetting.easy) {
                viewModel.selectDifficulty(UserPreferences.DifficultySetting.easy)
                
                // Give callback a moment to execute
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                
                guard testCompleted else {
                    results += "   ❌ Difficulty selection callback failed\n"
                    allPassed = false
                    throw TestError.failed
                }
                results += "   ✅ Difficulty selection works\n"
            } else {
                results += "   ⚠️ Easy difficulty locked (might be expected)\n"
            }
            
            // Test helper methods
            let progressText = viewModel.getProgressText(for: UserPreferences.DifficultySetting.easy)
            let percentage = viewModel.getCompletionPercentage(for: UserPreferences.DifficultySetting.easy)
            let description = viewModel.getDifficultyDescription(UserPreferences.DifficultySetting.easy)
            
            guard !progressText.isEmpty,
                  percentage >= 0.0,
                  description.contains("beginner") else {
                results += "   ❌ Helper methods failed\n"
                allPassed = false
                throw TestError.failed
            }
            results += "   ✅ Helper methods work\n"
            
            results += "   🎉 DifficultySelectionViewModel: ALL PASSED\n\n"
            
        } catch {
            results += "   ❌ DifficultySelectionViewModel: FAILED\n\n"
            allPassed = false
        }
        
        // Final results
        if allPassed {
            results += "✅ ALL TESTS PASSED! Phase 1 & Phase 2 Task 1 working correctly.\n"
        } else {
            results += "❌ SOME TESTS FAILED. Check implementation.\n"
        }
        
        await MainActor.run {
            testResults = results
            testStatus = allPassed ? .passed : .failed
            
            // Also print to console for developers
            print(results)
        }
    }
    
    // MARK: - Phase 4 Debug Functions
    
    /// Simulate completion of all puzzles in a difficulty
    private func simulateDifficultyCompletion(_ difficulty: UserPreferences.DifficultySetting) {
        phase4TestResults = "🔄 Simulating \(difficulty.displayName) difficulty completion...\n"
        
        // Get all puzzles for this difficulty from sample data
        let difficultyPuzzles = samplePuzzles.filter { puzzle in
            difficulty.containsPuzzleLevel(puzzle.difficulty)
        }
        
        if difficultyPuzzles.isEmpty {
            phase4TestResults += "⚠️ No puzzles found for \(difficulty.displayName) difficulty\n"
            return
        }
        
        // Mark all puzzles as completed for this difficulty
        for puzzle in difficultyPuzzles {
            progressService.markPuzzleCompleted(
                childId: selectedChildId, 
                puzzleId: puzzle.id, 
                difficulty: difficulty
            )
        }
        
        // Check if promotion should be triggered
        let isCompleted = progressService.isDifficultyCompleted(
            for: selectedChildId, 
            difficulty: difficulty, 
            from: samplePuzzles
        )
        
        let nextDifficulty = progressService.getNextDifficultyForPromotion(from: difficulty)
        
        phase4TestResults += "✅ Completed \(difficultyPuzzles.count) puzzles in \(difficulty.displayName)\n"
        phase4TestResults += "🎯 Difficulty completed: \(isCompleted ? "YES" : "NO")\n"
        
        if let next = nextDifficulty {
            phase4TestResults += "🚀 Ready for promotion to: \(next.displayName)\n"
        } else {
            phase4TestResults += "🏆 ALL DIFFICULTIES COMPLETED!\n"
        }
        
        // Update the last selected difficulty
        progressService.setLastSelectedDifficulty(childId: selectedChildId, difficulty: difficulty)
        
        print("Phase 4 Debug: Simulated \(difficulty.displayName) completion")
    }
    
    /// Test promotion interstitial with mock data
    private func testPromotionInterstitial() {
        phase4TestResults = "🎉 Testing Promotion Interstitial...\n"
        phase4TestResults += "This would show the promotion screen from Easy → Medium\n"
        phase4TestResults += "Features:\n"
        phase4TestResults += "• Congratulations message\n"
        phase4TestResults += "• Puzzle completion stats\n"
        phase4TestResults += "• Auto-advance timer (3 seconds)\n"
        phase4TestResults += "• Continue/Skip buttons\n"
        phase4TestResults += "\n🚧 Implementation in Task 2: Promotion Interstitial View\n"
        
        print("Phase 4 Debug: Tested promotion interstitial")
    }
    
    /// Test final completion celebration with mock data
    private func testFinalCompletion() {
        phase4TestResults = "🏆 Testing Final Completion Celebration...\n"
        phase4TestResults += "This would show the final celebration after completing Hard difficulty\n"
        phase4TestResults += "Features:\n"
        phase4TestResults += "• TANGRAM MASTER achievement\n"
        phase4TestResults += "• Total statistics display\n"
        phase4TestResults += "• Replay difficulty options\n"
        phase4TestResults += "• Return to lobby button\n"
        phase4TestResults += "\n🚧 Implementation in Task 3: Final Completion View\n"
        
        // Simulate completing all difficulties for testing
        simulateDifficultyCompletion(.easy)
        simulateDifficultyCompletion(.normal)
        simulateDifficultyCompletion(.hard)
        
        phase4TestResults += "\n✅ All difficulties marked as completed for testing\n"
        
        print("Phase 4 Debug: Tested final completion celebration")
    }
    
    /// Test Phase 4 Task 1 implementation thoroughly
    private func testPhase4Task1Implementation() {
        phase4TestResults = "🧪 Testing Phase 4 Task 1 Implementation...\n\n"
        var allTestsPassed = true
        
        // Test 1: Test difficulty completion detection
        do {
            phase4TestResults += "Test 1: Difficulty Completion Detection\n"
            
            let testChildId = "phase4-test-child"
            
            // Initially, no difficulty should be completed
            for difficulty in [UserPreferences.DifficultySetting.easy, .normal, .hard] {
                let isCompleted = progressService.isDifficultyCompleted(
                    for: testChildId, 
                    difficulty: difficulty, 
                    from: samplePuzzles
                )
                if isCompleted {
                    phase4TestResults += "❌ \(difficulty.displayName) incorrectly marked as completed initially\n"
                    allTestsPassed = false
                } else {
                    phase4TestResults += "✅ \(difficulty.displayName) correctly not completed initially\n"
                }
            }
            
            // Complete some puzzles in Easy difficulty
            let easyPuzzles = samplePuzzles.filter { UserPreferences.DifficultySetting.easy.containsPuzzleLevel($0.difficulty) }
            for puzzle in easyPuzzles.prefix(easyPuzzles.count - 1) { // Complete all but one
                progressService.markPuzzleCompleted(childId: testChildId, puzzleId: puzzle.id, difficulty: .easy)
            }
            
            // Easy should not be completed yet
            let easyPartiallyCompleted = progressService.isDifficultyCompleted(for: testChildId, difficulty: .easy, from: samplePuzzles)
            if easyPartiallyCompleted {
                phase4TestResults += "❌ Easy incorrectly marked as completed when partially done\n"
                allTestsPassed = false
            } else {
                phase4TestResults += "✅ Easy correctly not completed when partially done\n"
            }
            
            // Complete the last Easy puzzle
            if let lastEasyPuzzle = easyPuzzles.last {
                progressService.markPuzzleCompleted(childId: testChildId, puzzleId: lastEasyPuzzle.id, difficulty: .easy)
            }
            
            // Now Easy should be completed
            let easyFullyCompleted = progressService.isDifficultyCompleted(for: testChildId, difficulty: .easy, from: samplePuzzles)
            if !easyFullyCompleted {
                phase4TestResults += "❌ Easy not marked as completed when all puzzles done\n"
                allTestsPassed = false
            } else {
                phase4TestResults += "✅ Easy correctly marked as completed\n"
            }
            
        } catch {
            phase4TestResults += "❌ Test 1 failed with error: \(error)\n"
            allTestsPassed = false
        }
        
        // Test 2: Test promotion logic
        do {
            phase4TestResults += "\nTest 2: Promotion Logic\n"
            
            // Test promotion from Easy
            let easyPromotion = progressService.getNextDifficultyForPromotion(from: .easy)
            if easyPromotion == .normal {
                phase4TestResults += "✅ Easy → Medium promotion correct\n"
            } else {
                phase4TestResults += "❌ Easy promotion logic incorrect\n"
                allTestsPassed = false
            }
            
            // Test promotion from Medium
            let mediumPromotion = progressService.getNextDifficultyForPromotion(from: .normal)
            if mediumPromotion == .hard {
                phase4TestResults += "✅ Medium → Hard promotion correct\n"
            } else {
                phase4TestResults += "❌ Medium promotion logic incorrect\n"
                allTestsPassed = false
            }
            
            // Test no promotion from Hard
            let hardPromotion = progressService.getNextDifficultyForPromotion(from: .hard)
            if hardPromotion == nil {
                phase4TestResults += "✅ Hard has no further promotion (correct)\n"
            } else {
                phase4TestResults += "❌ Hard promotion should be nil\n"
                allTestsPassed = false
            }
            
        } catch {
            phase4TestResults += "❌ Test 2 failed with error: \(error)\n"
            allTestsPassed = false
        }
        
        // Final result
        phase4TestResults += "\n" + (allTestsPassed ? "🎉 ALL PHASE 4 TASK 1 TESTS PASSED!" : "❌ SOME TESTS FAILED")
        phase4TestResults += "\n\nPhase 4 Task 1 implementation ready for integration testing."
        
        print("Phase 4 Debug: Task 1 testing completed - \(allTestsPassed ? "PASSED" : "FAILED")")
    }
    
    private enum TestError: Error {
        case failed
    }
}

// MARK: - MockPuzzleLibraryService for Testing

class MockTangramPuzzleLibraryService: PuzzleLibraryProviding {
    private let mockPuzzles: [GamePuzzleData]
    
    init(puzzles: [GamePuzzleData]) {
        self.mockPuzzles = puzzles
    }
    
    func loadPuzzles() async throws -> [GamePuzzleData] {
        // Simulate slight delay like real service
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return mockPuzzles
    }
    
    func savePuzzle(_ puzzle: GamePuzzleData) async throws {
        // Mock implementation - not used in our testing
        throw NSError(domain: "MockTangramPuzzleLibraryService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock doesn't support saving"])
    }
    
    func deletePuzzle(id: String) async throws {
        // Mock implementation - not used in our testing
        throw NSError(domain: "MockTangramPuzzleLibraryService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock doesn't support deleting"])
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
