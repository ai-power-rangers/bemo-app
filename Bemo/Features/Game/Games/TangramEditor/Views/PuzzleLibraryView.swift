//
//  PuzzleLibraryView.swift
//  Bemo
//
//  Library view for browsing and managing saved tangram puzzles
//

import SwiftUI

struct PuzzleLibraryView: View {
    @Bindable var viewModel: TangramEditorViewModel
    
    @State private var selectedCategory: PuzzleCategory? = nil
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var puzzleToDelete: TangramPuzzle?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    private var filteredPuzzles: [TangramPuzzle] {
        var puzzles = viewModel.savedPuzzles
        
        if let category = selectedCategory {
            puzzles = puzzles.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            puzzles = puzzles.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return puzzles.sorted { $0.modifiedDate > $1.modifiedDate }
    }
    
    // All puzzles are official - no need to separate them
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    // Back to Lobby button
                    Button(action: { 
                        viewModel.delegate?.gameDidRequestQuit() 
                    }) {
                        Label("Back to Lobby", systemImage: "chevron.left")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Text("Tangram Puzzles")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Create New Button
                    Button(action: { viewModel.createNewPuzzle() }) {
                        Label("Create New", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Search and Filter Bar
                HStack(spacing: 12) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search puzzles...", text: $searchText)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Category filter
                    Menu {
                        Button("All Categories", action: { selectedCategory = nil })
                        Divider()
                        ForEach(PuzzleCategory.allCases, id: \.self) { category in
                            Button(category.rawValue) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(selectedCategory?.rawValue ?? "All")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Puzzle Grid
            if filteredPuzzles.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // All Puzzles (all are official)
                        if !filteredPuzzles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("All Puzzles", systemImage: "checkmark.seal.fill")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text("\(filteredPuzzles.count)")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(filteredPuzzles) { puzzle in
                                        PuzzleCardView(
                                            puzzle: puzzle,
                                            onTap: { viewModel.loadPuzzle(from: puzzle) },
                                            onDelete: {
                                                puzzleToDelete = puzzle
                                                showingDeleteAlert = true
                                            },
                                            onDuplicate: {
                                                Task {
                                                    await viewModel.duplicatePuzzle(puzzle)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(Color(.systemGray6))
        .alert("Delete Puzzle", isPresented: $showingDeleteAlert, presenting: puzzleToDelete) { puzzle in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deletePuzzle(puzzle)
                }
            }
        } message: { puzzle in
            Text("Are you sure you want to delete \"\(puzzle.name)\"? This action cannot be undone.")
        }
        .task {
            await viewModel.loadSavedPuzzles()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Puzzles Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first tangram puzzle to get started")
                    .foregroundColor(.secondary)
            }
            
            Button(action: { viewModel.createNewPuzzle() }) {
                Label("Create Your First Puzzle", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Puzzle Card Component

struct PuzzleCardView: View {
    let puzzle: TangramPuzzle
    let onTap: () -> Void
    let onDelete: (() -> Void)?  // Optional for official puzzles
    let onDuplicate: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail - maintain square frame but preserve aspect ratio
            ZStack {
                // Background for consistent card size
                Rectangle()
                    .fill(Color(.systemGray6))
                    .aspectRatio(1, contentMode: .fit)
                
                if let thumbnailData = puzzle.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()  // Preserve aspect ratio
                        .padding(8)  // Add padding so puzzle doesn't touch edges
                } else {
                    // Placeholder
                    Image(systemName: "square.grid.3x3")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .overlay(
                // Official badge for bundled puzzles
                Group {
                    // All puzzles are official
                    VStack {
                        HStack {
                            Spacer()
                            Label("Official", systemImage: "checkmark.seal.fill")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(puzzle.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    // Category badge
                    Text(puzzle.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Difficulty stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= puzzle.difficulty.rawValue ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Text(puzzle.modifiedDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if let onDelete = onDelete {
                onDelete()
            }
        }
        .contextMenu {
            Button(action: onTap) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            if let onDelete = onDelete {
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    PuzzleLibraryView(viewModel: .preview())
}