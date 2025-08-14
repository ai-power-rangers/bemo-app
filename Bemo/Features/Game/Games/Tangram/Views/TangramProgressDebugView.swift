//
//  TangramProgressDebugView.swift
//  Bemo
//
//  Debug view to test TangramProgress model functionality
//

// WHAT: Debug UI to test and demonstrate TangramProgress functionality
// ARCHITECTURE: SwiftUI View for debugging/testing purposes
// USAGE: Add to DevTools or as temporary overlay to test progress tracking

import SwiftUI

struct TangramProgressDebugView: View {
    @State private var progress = TangramProgress(childProfileId: "debug-child")
    @State private var selectedDifficulty: UserPreferences.DifficultySetting = .easy
    @State private var completedPuzzleIds: Set<String> = []
    
    // Sample puzzle data for testing
    private let samplePuzzles: [GamePuzzleData] = [
        GamePuzzleData(id: "easy1", name: "Easy Cat", category: "animals", difficulty: 1, targetPieces: []),
        GamePuzzleData(id: "easy2", name: "Easy House", category: "objects", difficulty: 2, targetPieces: []),
        GamePuzzleData(id: "easy3", name: "Easy Tree", category: "nature", difficulty: 1, targetPieces: []),
        GamePuzzleData(id: "normal1", name: "Medium Bird", category: "animals", difficulty: 3, targetPieces: []),
        GamePuzzleData(id: "normal2", name: "Medium Bridge", category: "objects", difficulty: 4, targetPieces: []),
        GamePuzzleData(id: "hard1", name: "Hard Dragon", category: "fantasy", difficulty: 5, targetPieces: []),
        GamePuzzleData(id: "hard2", name: "Hard Castle", category: "buildings", difficulty: 5, targetPieces: [])
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    Text("TangramProgress Debug")
                        .font(.title)
                        .fontWeight(.bold)
                    
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
                            progress.setLastSelectedDifficulty(newDifficulty)
                        }
                    }
                    
                    // Current Progress Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress Statistics:")
                            .font(.headline)
                        
                        let difficultyPuzzles = samplePuzzles.filter { selectedDifficulty.containsPuzzleLevel($0.difficulty) }
                        let completedCount = progress.getCompletedCount(for: selectedDifficulty)
                        let totalCount = difficultyPuzzles.count
                        
                        Text("Difficulty: \(selectedDifficulty.displayName)")
                        Text("Completed: \(completedCount)/\(totalCount)")
                        Text("Overall Progress: \(String(format: "%.1f%%", progress.getTotalProgress(from: samplePuzzles) * 100))")
                        
                        if let nextPuzzle = progress.getNextUnlockedPuzzle(for: selectedDifficulty, from: samplePuzzles) {
                            Text("Next Puzzle: \(nextPuzzle.name)")
                                .foregroundColor(.blue)
                        } else {
                            Text("All puzzles completed! 🎉")
                                .foregroundColor(.green)
                        }
                        
                        if let nextDifficulty = progress.getNextDifficulty() {
                            Text("Next Difficulty: \(nextDifficulty.displayName)")
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Puzzle List
                    VStack(alignment: .leading) {
                        Text("Puzzles for \(selectedDifficulty.displayName):")
                            .font(.headline)
                        
                        let difficultyPuzzles = samplePuzzles
                            .filter { selectedDifficulty.containsPuzzleLevel($0.difficulty) }
                            .sorted { $0.id < $1.id }
                        
                        ForEach(difficultyPuzzles, id: \.id) { puzzle in
                            DebugPuzzleRowView(
                                puzzle: puzzle,
                                isCompleted: progress.isPuzzleCompleted(puzzleId: puzzle.id, difficulty: selectedDifficulty),
                                isUnlocked: isUnlocked(puzzle: puzzle),
                                onToggleCompletion: {
                                    togglePuzzleCompletion(puzzle)
                                }
                            )
                        }
                    }
                    
                    // Action Buttons
                    HStack {
                        Button("Reset Progress") {
                            progress = TangramProgress(childProfileId: "debug-child")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Complete Current") {
                            if let nextPuzzle = progress.getNextUnlockedPuzzle(for: selectedDifficulty, from: samplePuzzles) {
                                progress.markPuzzleCompleted(puzzleId: nextPuzzle.id, difficulty: selectedDifficulty)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    // Raw Data (for debugging)
                    DisclosureGroup("Raw Progress Data") {
                        Text("Child ID: \(progress.childProfileId)")
                        Text("Last Difficulty: \(progress.lastSelectedDifficulty?.displayName ?? "None")")
                        Text("Completed by Difficulty:")
                        ForEach(UserPreferences.DifficultySetting.allCases, id: \.self) { difficulty in
                            let completed = progress.getCompletedPuzzles(for: difficulty)
                            Text("  \(difficulty.displayName): \(completed.count) puzzles")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .onAppear {
            progress.setLastSelectedDifficulty(selectedDifficulty)
        }
    }
    
    private func isUnlocked(puzzle: GamePuzzleData) -> Bool {
        let difficultyPuzzles = samplePuzzles
            .filter { selectedDifficulty.containsPuzzleLevel($0.difficulty) }
            .sorted { $0.id < $1.id }
        
        guard let puzzleIndex = difficultyPuzzles.firstIndex(where: { $0.id == puzzle.id }) else {
            return false
        }
        
        // First puzzle is always unlocked
        if puzzleIndex == 0 { return true }
        
        // Check if all previous puzzles are completed
        for i in 0..<puzzleIndex {
            let previousPuzzle = difficultyPuzzles[i]
            if !progress.isPuzzleCompleted(puzzleId: previousPuzzle.id, difficulty: selectedDifficulty) {
                return false
            }
        }
        
        return true
    }
    
    private func togglePuzzleCompletion(_ puzzle: GamePuzzleData) {
        if progress.isPuzzleCompleted(puzzleId: puzzle.id, difficulty: selectedDifficulty) {
            // Remove completion (for testing purposes)
            var completed = progress.getCompletedPuzzles(for: selectedDifficulty)
            completed.remove(puzzle.id)
            progress.completedPuzzlesByDifficulty[selectedDifficulty.rawValue] = completed
        } else {
            // Only mark complete if unlocked
            if isUnlocked(puzzle: puzzle) {
                progress.markPuzzleCompleted(puzzleId: puzzle.id, difficulty: selectedDifficulty)
            }
        }
    }
}

struct DebugPuzzleRowView: View {
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
            
            // Action Button
            Button(action: onToggleCompletion) {
                Text(isCompleted ? "Completed" : "Mark Complete")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCompleted ? Color.green : Color.blue)
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
}

#Preview {
    TangramProgressDebugView()
}
