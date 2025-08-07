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
import SpriteKit

struct TangramGameView: View {
    @State private var viewModel: TangramGameViewModel
    @State private var mockPieces: [RecognizedPiece] = []
    @State private var showCVMock = false
    
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
        VStack(spacing: 0) {
            // Clean header with timer and progress
            gameHeader
                .padding()
            
            // Main puzzle canvas - Always use SpriteKit
            if let puzzle = viewModel.selectedPuzzle {
                TangramSpriteView(
                    puzzle: puzzle,
                    placedPieces: $viewModel.placedPieces,
                    showHints: viewModel.showHints,
                    onPieceCompleted: { pieceType in
                        viewModel.handlePieceCompletion(pieceType: pieceType)
                    },
                    onPuzzleCompleted: {
                        viewModel.handlePuzzleCompletion()
                    }
                )
            }
            
        }
    }
    
    private var gameHeader: some View {
        HStack(spacing: 16) {
            // Back button or Next button when complete
            if viewModel.currentPhase == .puzzleComplete {
                Button(action: viewModel.loadNextPuzzle) {
                    Label("Next", systemImage: "arrow.right")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button(action: viewModel.exitToSelection) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
            }
            
            // Timer with start button
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if viewModel.timerStarted {
                    Text(viewModel.formattedTime)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Button("Start") {
                        viewModel.startTimer()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Spacer()
            
            // Hint button (only during play)
            if viewModel.currentPhase == .playingPuzzle {
                Button(action: viewModel.toggleHints) {
                    Image(systemName: viewModel.showHints ? "lightbulb.fill" : "lightbulb")
                        .font(.body)
                        .foregroundColor(viewModel.showHints ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Progress bar
            ProgressView(value: viewModel.progress)
                .frame(width: 150)
                .tint(viewModel.currentPhase == .puzzleComplete ? .green : .blue)
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
            // Celebration emoji and title
            Text("🎉")
                .font(.system(size: 80))
                .rotationEffect(.degrees(-15))
                .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatCount(3, autoreverses: true), value: viewModel.currentPhase)
            
            Text("Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text("Amazing work! You solved \"\(viewModel.selectedPuzzle?.name ?? "the puzzle")\"!")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Star rating display
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                        .scaleEffect(1.2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(index) * 0.1), value: viewModel.currentPhase)
                }
            }
            .padding()
            
            // Navigation buttons
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.requestQuit()
                }) {
                    Label("Back to Lobby", systemImage: "house.fill")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    viewModel.loadNextPuzzle()
                }) {
                    Label("Next Puzzle", systemImage: "arrow.right.circle.fill")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 10)
        )
        .padding()
    }
}