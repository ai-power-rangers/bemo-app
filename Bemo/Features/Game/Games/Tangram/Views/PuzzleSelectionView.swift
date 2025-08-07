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
    @Bindable var viewModel: PuzzleSelectionViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    init(viewModel: PuzzleSelectionViewModel) {
        self.viewModel = viewModel
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
            headerTitleRow
            searchBar
            filterChips
        }
    }
    
    private var headerTitleRow: some View {
        HStack {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Puzzle Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("\(viewModel.filteredPuzzles.count) puzzles available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // View mode toggle
            Picker("View", selection: $viewModel.isGridView) {
                Image(systemName: "square.grid.2x2")
                    .tag(true)
                Image(systemName: "list.bullet")
                    .tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            
            // Back to Lobby button
            Button(action: {
                print("DEBUG: Back to Lobby button tapped")
                viewModel.backToLobby()
            }) {
                Label("Back to Lobby", systemImage: "arrow.left.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
    
    private var searchBar: some View {
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
    }
    
    private var filterChips: some View {
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
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            print("DEBUG: Puzzle card tapped: \(puzzle.name)")
            onTap()
        }) {
            VStack(spacing: 0) {
                // Thumbnail area
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.15), color.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150)
                    
                    if let thumbnail = thumbnail {
                        thumbnail
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "puzzlepiece.fill")
                                .font(.system(size: 50))
                                .foregroundColor(color)
                            Text(puzzle.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                
                // Info section
                VStack(alignment: .leading, spacing: 8) {
                    Text(puzzle.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack {
                        // Difficulty stars
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < puzzle.difficulty.rawValue ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(index < puzzle.difficulty.rawValue ? difficultyColor : .gray.opacity(0.3))
                            }
                        }
                        
                        Spacer()
                        
                        // Category badge
                        Text(puzzle.category.rawValue)
                            .font(.system(size: 10))
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color.opacity(0.2))
                            .foregroundColor(color)
                            .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(Color(UIColor.systemBackground))
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
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