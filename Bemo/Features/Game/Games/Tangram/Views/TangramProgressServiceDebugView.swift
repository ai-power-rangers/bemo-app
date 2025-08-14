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
