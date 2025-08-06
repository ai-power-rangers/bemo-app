//
//  TangramGameView.swift
//  Bemo
//
//  Main game view for Tangram puzzle gameplay
//

// WHAT: Primary view for Tangram game, manages puzzle selection and gameplay phases
// ARCHITECTURE: View in MVVM-S pattern, observes TangramGameViewModel
// USAGE: Created by TangramGame.makeGameView, displays appropriate phase UI

import SwiftUI

struct TangramGameView: View {
    @State private var viewModel: TangramGameViewModel
    
    init(viewModel: TangramGameViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        Group {
            switch viewModel.currentPhase {
            case .selectingPuzzle:
                PuzzleSelectionView(viewModel: viewModel.puzzleSelectionViewModel)
                
            case .playingPuzzle:
                gamePlayView
                
            case .puzzleComplete:
                completionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("GameBackground", bundle: nil))
    }
    
    // MARK: - Game Views
    
    private var gamePlayView: some View {
        VStack(spacing: 20) {
            // Header with puzzle info
            gameHeader
            
            // Main puzzle canvas
            if let puzzle = viewModel.selectedPuzzle {
                GamePuzzleCanvasView(
                    puzzle: puzzle,
                    placedPieces: viewModel.placedPieces,
                    anchorPieceId: viewModel.anchorPiece?.id,
                    showHints: viewModel.showHints,
                    canvasSize: viewModel.canvasSize
                )
                .padding()
            }
            
            // Control buttons
            gameControls
        }
        .padding()
    }
    
    private var gameHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedPuzzle?.name ?? "Puzzle")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    Label(
                        difficultyName,
                        systemImage: "star.fill"
                    )
                    .font(.caption)
                    .foregroundColor(difficultyColor)
                    
                    Label(
                        viewModel.selectedPuzzle?.category ?? "",
                        systemImage: categoryIcon
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Progress indicator
            VStack(alignment: .trailing, spacing: 4) {
                Text("Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: viewModel.progress)
                    .frame(width: 100)
                    .tint(.green)
            }
        }
    }
    
    private var gameControls: some View {
        HStack(spacing: 20) {
            Button(action: viewModel.exitToSelection) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(action: viewModel.toggleHints) {
                Label(
                    viewModel.showHints ? "Hide Hints" : "Show Hints",
                    systemImage: viewModel.showHints ? "lightbulb.fill" : "lightbulb"
                )
            }
            .buttonStyle(.bordered)
            .tint(viewModel.showHints ? .yellow : .blue)
            
            Button(action: viewModel.requestQuit) {
                Label("Quit", systemImage: "xmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
    
    // MARK: - Helper Properties
    
    private var difficultyName: String {
        guard let difficulty = viewModel.selectedPuzzle?.difficulty else { return "" }
        switch difficulty {
        case 0: return "Beginner"
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        case 4: return "Expert"
        default: return "Unknown"
        }
    }
    
    private var difficultyColor: Color {
        guard let difficulty = viewModel.selectedPuzzle?.difficulty else { return .gray }
        switch difficulty {
        case 0: return .teal      // Beginner
        case 1: return .green     // Easy
        case 2: return .orange    // Medium
        case 3: return .red       // Hard
        case 4: return .purple    // Expert
        default: return .gray
        }
    }
    
    private var categoryIcon: String {
        guard let category = viewModel.selectedPuzzle?.category else { return "questionmark" }
        switch category.lowercased() {
        case "animals":
            return "pawprint.fill"
        case "geometric":
            return "square.on.square"
        case "objects":
            return "cube.fill"
        case "people":
            return "person.fill"
        case "letters":
            return "textformat"
        case "numbers":
            return "number"
        case "abstract":
            return "sparkles"
        case "custom":
            return "star.fill"
        default:
            return "questionmark"
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 30) {
            Text("🎉 Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Great job solving the puzzle!")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Button("Next Puzzle") {
                viewModel.exitToSelection()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}