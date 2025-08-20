//
//  TangramMapView.swift
//  Bemo
//
//  Map view displaying puzzle progression within a difficulty level
//

// WHAT: Main map interface showing sequential puzzle progression with nodes and connection lines
// ARCHITECTURE: SwiftUI View in MVVM-S pattern using TangramMapViewModel and MapNodeView components  
// USAGE: Displays puzzle map for a difficulty level, handles navigation back to difficulty selection

import SwiftUI

struct TangramMapView: View {
    
    // MARK: - Dependencies
    
    @State private var viewModel: TangramMapViewModel
    
    // MARK: - Initialization
    
    init(viewModel: TangramMapViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                TangramTheme.Backgrounds.editor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with navigation and progress
                    headerView
                        .padding(.horizontal, BemoTheme.Spacing.large)
                        .padding(.top, BemoTheme.Spacing.medium)
                    
                    // Main map content
                    if viewModel.isLoading {
                        loadingView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(errorMessage)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.puzzles.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        mapContentView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadPuzzlesForDifficulty()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: BemoTheme.Spacing.medium) {
            // Navigation and Title Row
            HStack {
                // Back Button
                Button(action: {
                    viewModel.goBackToDifficulty()
                }) {
                    HStack(spacing: BemoTheme.Spacing.xsmall) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(TangramTheme.UI.primaryButton)
                }
                .padding(.vertical, BemoTheme.Spacing.small)
                
                Spacer()
                
                // Title
                Text("\(viewModel.difficulty.displayName) Puzzles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(TangramTheme.Text.primary)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 70, height: 20)
            }
            
            // Progress Section
            progressSectionView
            

        }
        .tangramPanel()
        .padding(.bottom, BemoTheme.Spacing.large)
    }
    
    // MARK: - Progress Section
    
    private var progressSectionView: some View {
        VStack(spacing: BemoTheme.Spacing.small) {
            // Progress Bar
            HStack {
                Text("Progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TangramTheme.Text.secondary)
                
                Spacer()
                
                Text("\(viewModel.completedCount) / \(viewModel.totalCount)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(TangramTheme.Text.primary)
            }
            
            // Progress Bar Visual
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TangramTheme.UI.separator.opacity(0.3))
                        .frame(height: 8)
                    
                    // Progress Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [TangramTheme.UI.success, TangramTheme.UI.success.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.completionPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.completionPercentage)
                }
            }
            .frame(height: 8)
            
            // Completion Status
            if viewModel.isDifficultyCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(TangramTheme.UI.success)
                    Text("All puzzles completed! Great work!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TangramTheme.UI.success)
                }
                .padding(.top, BemoTheme.Spacing.xsmall)
            } else if let nextPuzzle = viewModel.nextPuzzle {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(TangramTheme.UI.primaryButton)
                    Text("Next: \(nextPuzzle.name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TangramTheme.Text.secondary)
                }
                .padding(.top, BemoTheme.Spacing.xsmall)
            }
        }
        .padding(.horizontal, BemoTheme.Spacing.large)
        .padding(.vertical, BemoTheme.Spacing.medium)
    }
    
    // MARK: - Map Content
    
    private var mapContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.puzzles.enumerated()), id: \.element.id) { index, puzzle in
                    VStack(spacing: 0) {
                        // Map Node
                        MapNodeView(
                            puzzle: puzzle,
                            nodeState: viewModel.getNodeState(for: puzzle),
                            onTap: {
                                viewModel.selectPuzzle(puzzle)
                            }
                        )
                        .padding(.horizontal, BemoTheme.Spacing.large)
                        
                        // Connection Line (except for last item)
                        if index < viewModel.puzzles.count - 1 {
                            MapConnectionLine(
                                isCompleted: viewModel.isCompleted(puzzle.id)
                            )
                            .padding(.vertical, BemoTheme.Spacing.medium)
                        }
                    }
                    .padding(.vertical, BemoTheme.Spacing.small)
                }
            }
            .padding(.top, BemoTheme.Spacing.medium)
            .padding(.bottom, BemoTheme.Spacing.xxlarge) // Extra bottom padding for safe scrolling
        }
    }
    

    
    // MARK: - State Views
    
    private var loadingView: some View {
        VStack(spacing: BemoTheme.Spacing.large) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: TangramTheme.UI.primaryButton))
            
            Text("Loading puzzles...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(TangramTheme.Text.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: BemoTheme.Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(TangramTheme.UI.warning)
            
            VStack(spacing: BemoTheme.Spacing.small) {
                Text("Oops!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(TangramTheme.Text.primary)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(TangramTheme.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BemoTheme.Spacing.large)
            }
            
            Button(action: {
                viewModel.loadPuzzlesForDifficulty()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .primaryButtonStyle()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: BemoTheme.Spacing.large) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 48))
                .foregroundColor(TangramTheme.Text.tertiary)
            
            VStack(spacing: BemoTheme.Spacing.small) {
                Text("No Puzzles Found")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(TangramTheme.Text.primary)
                
                Text("No puzzles are available for \(viewModel.difficulty.displayName) difficulty.")
                    .font(.system(size: 16))
                    .foregroundColor(TangramTheme.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BemoTheme.Spacing.large)
            }
            
            Button(action: {
                viewModel.goBackToDifficulty()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back to Difficulty Selection")
                }
                .primaryButtonStyle()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Preview with mock data
    let mockPuzzleService = PuzzleLibraryService()
    let mockProgressService = TangramProgressService()
    
    // Create mock puzzles for preview
    let mockPuzzles = [
        // Easy puzzles (1-2 star)
        GamePuzzleData(id: "easy-001", name: "Simple Cat", category: "Animals", difficulty: 1, targetPieces: []),
        GamePuzzleData(id: "easy-002", name: "Basic House", category: "Buildings", difficulty: 1, targetPieces: []),
        GamePuzzleData(id: "easy-003", name: "Small Tree", category: "Nature", difficulty: 2, targetPieces: []),
        GamePuzzleData(id: "easy-004", name: "Fish Shape", category: "Animals", difficulty: 2, targetPieces: []),
        GamePuzzleData(id: "easy-005", name: "Butterfly", category: "Animals", difficulty: 2, targetPieces: [])
    ]
    
    // Load mock data for preview
    mockPuzzleService.loadMockData(mockPuzzles)
    
    let viewModel = TangramMapViewModel(
        difficulty: .easy,
        childProfileId: "preview-child",
        puzzleLibraryService: mockPuzzleService,
        progressService: mockProgressService,
        onPuzzleSelected: { puzzle in
            print("Preview: Selected puzzle \(puzzle.name)")
        },
        onBackToDifficulty: {
            print("Preview: Back to difficulty selection")
        }
    )
    
    return TangramMapView(viewModel: viewModel)
        .preferredColorScheme(.light)
}
