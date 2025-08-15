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
            // Search and Filter Bar
            HStack(spacing: 12) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(TangramTheme.Text.secondary)
                        TextField("Search puzzles...", text: $searchText)
                    }
                    .padding(8)
                    .background(TangramTheme.Backgrounds.secondaryPanel)
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
                                .foregroundColor(TangramTheme.UI.primaryButton)
                            Text(selectedCategory?.rawValue ?? "All")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(TangramTheme.Backgrounds.secondaryPanel)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TangramTheme.Backgrounds.editor)
            
            Divider()
            
            // Puzzle Grid
            if filteredPuzzles.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredPuzzles) { puzzle in
                            PuzzleCardView(
                                puzzle: puzzle,
                                allPuzzles: filteredPuzzles,  // Pass all puzzles for badge calculation
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
                    .padding()
                }
            }
        }
        .background(TangramTheme.Backgrounds.editor)
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
                .foregroundColor(TangramTheme.Text.secondary)
            
            VStack(spacing: 8) {
                Text("No Puzzles Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first tangram puzzle to get started")
                    .foregroundColor(TangramTheme.Text.secondary)
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
    let allPuzzles: [TangramPuzzle]  // Needed for badge calculation
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
                    .fill(TangramTheme.Backgrounds.secondaryPanel)
                    .aspectRatio(1, contentMode: .fit)
                
                if let thumbnailData = puzzle.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else if !puzzle.pieces.isEmpty {
                    // Use direct rendering for editor puzzles
                    EditorPuzzleThumbnailView(puzzle: puzzle)
                        .padding(8)
                } else {
                    // Placeholder when no pieces
                    Image(systemName: "square.grid.3x3")
                        .font(.largeTitle)
                        .foregroundColor(TangramTheme.Text.secondary)
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TangramTheme.UI.separator, lineWidth: 1)
            )
            .overlay(
                // Dynamic badge based on puzzle properties - top left corner
                Group {
                    if let badge = puzzle.getBadge(allPuzzles: allPuzzles) {
                        VStack {
                            HStack {
                                Label(badge.rawValue, systemImage: badge.icon)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(badge.color)
                                    .foregroundColor(TangramTheme.Text.onColor)
                                    .cornerRadius(4)
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
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
                        .background(TangramTheme.Backgrounds.secondaryPanel.opacity(0.8))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Difficulty stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= puzzle.difficulty.rawValue ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(TangramTheme.UI.warning)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(TangramTheme.Backgrounds.panel)
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

// MARK: - Editor Puzzle Thumbnail View

/// Simple thumbnail view for TangramPuzzle in the editor
struct EditorPuzzleThumbnailView: View {
    let puzzle: TangramPuzzle
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(puzzle.pieces) { piece in
                    Path { path in
                        let vertices = TangramGeometry.vertices(for: piece.type)
                        let scaledVertices = vertices.map { 
                            CGPoint(x: $0.x * TangramConstants.visualScale, 
                                    y: $0.y * TangramConstants.visualScale)
                        }
                        let transformed = scaledVertices.map { $0.applying(piece.transform) }
                        
                        if let first = transformed.first {
                            path.move(to: normalizePoint(first, in: geometry.size))
                            for vertex in transformed.dropFirst() {
                                path.addLine(to: normalizePoint(vertex, in: geometry.size))
                            }
                            path.closeSubpath()
                        }
                    }
                    .fill(piece.type.color.opacity(0.8))
                    .overlay(
                        Path { path in
                            let vertices = TangramGeometry.vertices(for: piece.type)
                            let scaledVertices = vertices.map { 
                                CGPoint(x: $0.x * TangramConstants.visualScale, 
                                        y: $0.y * TangramConstants.visualScale)
                            }
                            let transformed = scaledVertices.map { $0.applying(piece.transform) }
                            
                            if let first = transformed.first {
                                path.move(to: normalizePoint(first, in: geometry.size))
                                for vertex in transformed.dropFirst() {
                                    path.addLine(to: normalizePoint(vertex, in: geometry.size))
                                }
                                path.closeSubpath()
                            }
                        }
                        .stroke(Color.black, lineWidth: 0.5)
                    )
                }
            }
        }
    }
    
    private func normalizePoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let bounds = calculateBounds()
        guard bounds.width > 0 && bounds.height > 0 else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        let scale = min(size.width / bounds.width * 0.8, size.height / bounds.height * 0.8)
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        return CGPoint(
            x: centerX + (point.x - bounds.midX) * scale,
            y: centerY + (point.y - bounds.midY) * scale
        )
    }
    
    private func calculateBounds() -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in puzzle.pieces {
            let vertices = TangramGeometry.vertices(for: piece.type)
            let scaledVertices = vertices.map { 
                CGPoint(x: $0.x * TangramConstants.visualScale, 
                        y: $0.y * TangramConstants.visualScale)
            }
            let transformed = scaledVertices.map { $0.applying(piece.transform) }
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                minY = min(minY, vertex.y)
                maxX = max(maxX, vertex.x)
                maxY = max(maxY, vertex.y)
            }
        }
        
        guard minX < CGFloat.greatestFiniteMagnitude else {
            return .zero
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

#Preview {
    PuzzleLibraryView(viewModel: .preview())
}