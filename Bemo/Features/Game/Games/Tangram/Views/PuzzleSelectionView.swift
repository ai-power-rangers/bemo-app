//
//  PuzzleSelectionView.swift
//  Bemo
//
//  View for browsing and selecting Tangram puzzles
//

// WHAT: Displays available tangram puzzles in a filterable grid/list for selection
// ARCHITECTURE: View in MVVM-S pattern, observes PuzzleSelectionViewModel
// USAGE: Displayed in TangramGameView during puzzle selection phase

import SwiftUI

struct PuzzleSelectionView: View {
    @State private var viewModel: PuzzleSelectionViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    init(viewModel: PuzzleSelectionViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and filters
            headerView
                .padding()
                .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Main content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasNoPuzzles {
                emptyStateView
            } else {
                puzzleGridView
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Select a Puzzle")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: viewModel.toggleViewMode) {
                    Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.title2)
                }
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search puzzles...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Category filter
                    Menu {
                        Button("All Categories") {
                            viewModel.selectedCategory = nil
                        }
                        Divider()
                        ForEach(viewModel.availableCategories, id: \.self) { category in
                            Button(action: { viewModel.selectedCategory = category }) {
                                Label(category.rawValue, systemImage: viewModel.categoryIcon(category))
                            }
                        }
                    } label: {
                        filterChip(
                            title: viewModel.selectedCategory?.rawValue ?? "Category",
                            isSelected: viewModel.selectedCategory != nil
                        )
                    }
                    
                    // Difficulty filter
                    Menu {
                        Button("All Difficulties") {
                            viewModel.selectedDifficulty = nil
                        }
                        Divider()
                        ForEach(viewModel.availableDifficulties, id: \.self) { difficulty in
                            Button(action: { viewModel.selectedDifficulty = difficulty }) {
                                Label(difficulty.displayName, systemImage: viewModel.difficultyIcon(difficulty))
                            }
                        }
                    } label: {
                        filterChip(
                            title: viewModel.selectedDifficulty?.displayName ?? "Difficulty",
                            isSelected: viewModel.selectedDifficulty != nil
                        )
                    }
                    
                    if viewModel.selectedCategory != nil || viewModel.selectedDifficulty != nil {
                        Button(action: viewModel.clearFilters) {
                            Label("Clear", systemImage: "xmark")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    private func filterChip(title: String, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(15)
    }
    
    // MARK: - Content Views
    
    private var puzzleGridView: some View {
        ScrollView {
            if viewModel.isGridView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredPuzzles) { puzzle in
                        TangramPuzzleCard(
                            puzzle: puzzle,
                            thumbnail: viewModel.thumbnailImage(for: puzzle),
                            color: viewModel.thumbnailColor(for: puzzle),
                            difficultyColor: viewModel.difficultyColor(puzzle.difficulty),
                            onTap: { viewModel.selectPuzzle(puzzle) }
                        )
                    }
                }
                .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.filteredPuzzles) { puzzle in
                        PuzzleRowView(
                            puzzle: puzzle,
                            thumbnail: viewModel.thumbnailImage(for: puzzle),
                            color: viewModel.thumbnailColor(for: puzzle),
                            difficultyColor: viewModel.difficultyColor(puzzle.difficulty),
                            categoryIcon: viewModel.categoryIcon(puzzle.category),
                            onTap: { viewModel.selectPuzzle(puzzle) }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading puzzles...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "puzzlepiece.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No puzzles found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your filters or search terms")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Clear Filters") {
                viewModel.clearFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Puzzle Card View

struct TangramPuzzleCard: View {
    let puzzle: TangramPuzzle
    let thumbnail: Image?
    let color: Color
    let difficultyColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.2))
                        .frame(height: 120)
                    
                    if let thumbnail = thumbnail {
                        thumbnail
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 100)
                    } else {
                        Image(systemName: "puzzlepiece.fill")
                            .font(.system(size: 40))
                            .foregroundColor(color)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(puzzle.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label(puzzle.difficulty.displayName, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(difficultyColor)
                        
                        Spacer()
                        
                        Text(puzzle.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Puzzle Row View

struct PuzzleRowView: View {
    let puzzle: TangramPuzzle
    let thumbnail: Image?
    let color: Color
    let difficultyColor: Color
    let categoryIcon: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    if let thumbnail = thumbnail {
                        thumbnail
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                    } else {
                        Image(systemName: "puzzlepiece.fill")
                            .font(.title2)
                            .foregroundColor(color)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(puzzle.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label(puzzle.category.rawValue, systemImage: categoryIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Label(puzzle.difficulty.displayName, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(difficultyColor)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}