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
        VStack(spacing: 20) {
            // Header with puzzle info
            gameHeader
            
            // Main puzzle canvas - Using SpriteKit
            if let puzzle = viewModel.selectedPuzzle {
                VStack(spacing: 0) {
                    // Toggle between SwiftUI and SpriteKit canvas
                    if viewModel.useSpriteKit {
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
                        .padding()
                    } else {
                        // Original SwiftUI canvas
                        GamePuzzleCanvasView(
                            puzzle: puzzle,
                            placedPieces: viewModel.placedPieces,
                            anchorPieceId: viewModel.anchorPiece?.id,
                            showHints: viewModel.showHints,
                            canvasSize: viewModel.canvasSize,
                            onPieceTouch: { pieceType in
                                viewModel.handlePieceTouch(pieceType: pieceType)
                            }
                        )
                        .padding()
                    }
                }
                .overlay(alignment: .top) {
                    // Show placement feedback
                    if viewModel.showPlacementCelebration {
                        Text("✨ Perfect! ✨")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(), value: viewModel.showPlacementCelebration)
                    }
                }
            }
            
            // Control buttons
            gameControls
            
            // Commented out CV Mock Controls for simplified testing
            /*
            #if DEBUG
            // CV Mock Controls Toggle
            HStack {
                Spacer()
                Button(action: { showCVMock.toggle() }) {
                    Image(systemName: showCVMock ? "hammer.fill" : "hammer")
                        .foregroundColor(.orange)
                }
                .padding()
            }
            #endif
            */
        }
        .padding()
        /*
        .overlay(alignment: .bottomTrailing) {
            #if DEBUG
            if showCVMock {
                CVMockControlView(
                    mockPieces: $mockPieces,
                    onPiecesChanged: { pieces in
                        // Process mock CV input through the game
                        let outcome = viewModel.processMockCVInput(pieces)
                        print("CV Mock outcome: \(outcome)")
                    }
                )
                .padding()
            }
            #endif
        }
        */
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
            
            // Toggle between SwiftUI and SpriteKit
            Button(action: { viewModel.useSpriteKit.toggle() }) {
                Label(
                    viewModel.useSpriteKit ? "SpriteKit" : "SwiftUI",
                    systemImage: viewModel.useSpriteKit ? "sparkles" : "square.grid.2x2"
                )
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            
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