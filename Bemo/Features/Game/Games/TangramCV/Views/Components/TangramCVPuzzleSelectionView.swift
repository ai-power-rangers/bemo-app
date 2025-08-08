//
//  TangramCVPuzzleSelectionView.swift
//  Bemo
//
//  Enhanced puzzle selection view with filters and search for TangramCV
//

// WHAT: Complete puzzle selection UI matching TangramGame with search and filters
// ARCHITECTURE: View component in MVVM-S pattern, observes TangramCVGameViewModel
// USAGE: Replaces simple puzzle grid with rich selection experience

import SwiftUI

struct TangramCVPuzzleSelectionView: View {
    @Bindable var viewModel: TangramCVGameViewModel
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedDifficulty: Int? = nil
    @State private var isGridView = true
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    private let listColumns = [
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and view toggle
            headerView
                .padding()
                .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Search bar
            searchBar
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Filter chips
            filterChips
                .padding(.vertical, 8)
            
            // Main content
            if viewModel.availablePuzzles.isEmpty {
                loadingView
            } else if filteredPuzzles.isEmpty {
                emptyStateView
            } else {
                puzzleGridView
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Title and count
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose a Puzzle")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("\(filteredPuzzles.count) puzzles available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // View mode toggle
            Picker("View", selection: $isGridView) {
                Image(systemName: "square.grid.2x2")
                    .tag(true)
                Image(systemName: "list.bullet")
                    .tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search puzzles...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(UIColor.tertiarySystemFill))
        .cornerRadius(10)
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All filter
                TangramCVFilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil && selectedDifficulty == nil,
                    action: {
                        selectedCategory = nil
                        selectedDifficulty = nil
                    }
                )
                
                // Category filters
                ForEach(availableCategories, id: \.self) { category in
                    TangramCVFilterChip(
                        title: category.capitalized,
                        isSelected: selectedCategory == category,
                        icon: categoryIcon(for: category),
                        action: {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    )
                }
                
                Divider()
                    .frame(height: 20)
                
                // Difficulty filters
                ForEach(1...5, id: \.self) { difficulty in
                    TangramCVFilterChip(
                        title: difficultyName(for: difficulty),
                        isSelected: selectedDifficulty == difficulty,
                        color: difficultyColor(for: difficulty),
                        action: {
                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Puzzle Grid
    
    private var puzzleGridView: some View {
        ScrollView {
            LazyVGrid(columns: isGridView ? columns : listColumns, spacing: 16) {
                ForEach(filteredPuzzles, id: \.id) { puzzle in
                    if isGridView {
                        TangramCVPuzzleCard(
                            puzzle: puzzle,
                            allPuzzles: filteredPuzzles,
                            action: {
                                viewModel.selectPuzzle(puzzle)
                            }
                        )
                    } else {
                        // List view card (horizontal layout)
                        TangramCVPuzzleListCard(
                            puzzle: puzzle,
                            allPuzzles: filteredPuzzles,
                            action: {
                                viewModel.selectPuzzle(puzzle)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading & Empty States
    
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
                clearFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Properties & Functions
    
    private var availableCategories: [String] {
        Array(Set(viewModel.availablePuzzles.map { $0.category })).sorted()
    }
    
    private var filteredPuzzles: [GamePuzzleData] {
        viewModel.availablePuzzles.filter { puzzle in
            let matchesCategory = selectedCategory == nil || puzzle.category == selectedCategory
            let matchesDifficulty = selectedDifficulty == nil || puzzle.difficulty == selectedDifficulty
            let matchesSearch = searchText.isEmpty ||
                                puzzle.name.localizedCaseInsensitiveContains(searchText) ||
                                puzzle.category.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesDifficulty && matchesSearch
        }
    }
    
    private func clearFilters() {
        searchText = ""
        selectedCategory = nil
        selectedDifficulty = nil
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "animals": return "🐾"
        case "objects": return "📦"
        case "people": return "👤"
        case "geometric": return "🔷"
        default: return "✨"
        }
    }
    
    private func difficultyName(for difficulty: Int) -> String {
        switch difficulty {
        case 1: return "Beginner"
        case 2: return "Easy"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Expert"
        default: return "Level \(difficulty)"
        }
    }
    
    private func difficultyColor(for difficulty: Int) -> Color {
        switch difficulty {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
        }
    }
}

// List view card component
struct TangramCVPuzzleListCard: View {
    let puzzle: GamePuzzleData
    let allPuzzles: [GamePuzzleData]
    let action: () -> Void
    
    private func getBadge() -> TangramCVBadgeType? {
        let isNewest = allPuzzles.last?.id == puzzle.id
        let isTopPick = allPuzzles.first?.id == puzzle.id
        return puzzle.getCVBadge(isNewest: isNewest, isTopPick: isTopPick)
    }
    
    var difficultyColor: Color {
        switch puzzle.difficulty {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(difficultyColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(puzzle.category.prefix(2).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(difficultyColor)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(puzzle.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let badge = getBadge() {
                            Label(badge.rawValue, systemImage: badge.icon)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badge.color)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack {
                        // Category
                        Text(puzzle.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        // Difficulty stars
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < puzzle.difficulty ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(index < puzzle.difficulty ? difficultyColor : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}