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
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedDifficulty: Int? = nil
    
    #if DEBUG
    // Debug-only properties for CV mocking
    @State private var mockPieces: [RecognizedPiece] = []
    @State private var showCVMock = false
    #endif
    
    init(viewModel: TangramGameViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentPhase {
                case .selectingPuzzle:
                    puzzleSelectionView
                    
                case .playingPuzzle:
                    gamePlayView
                    
                case .puzzleComplete:
                    completionView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("GameBackground", bundle: nil))
        }
        .onAppear {
            // Remove navigation bar shadow
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    // MARK: - Puzzle Selection View
    
    private var puzzleSelectionView: some View {
        VStack(spacing: 0) {
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Category filters
                    FilterChip(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )
                    
                    ForEach(availableCategories, id: \.self) { category in
                        FilterChip(
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
                    ForEach(0..<5) { difficulty in
                        FilterChip(
                            title: difficultyEmoji(for: difficulty),
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
            .padding(.vertical, 8)
            
            // Puzzle grid
            if viewModel.availablePuzzles.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading puzzles...")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredPuzzles, id: \.id) { puzzle in
                            PuzzleThumbnailView(
                                puzzle: puzzle,
                                allPuzzles: filteredPuzzles,  // Pass all puzzles for badge calculation
                                action: {
                                    viewModel.selectPuzzle(puzzle)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationTitle("Choose a Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.requestQuit()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                }
            }
        }
    }
    
    private var availableCategories: [String] {
        Array(Set(viewModel.availablePuzzles.map { $0.category })).sorted()
    }
    
    private var filteredPuzzles: [GamePuzzleData] {
        viewModel.availablePuzzles.filter { puzzle in
            let matchesCategory = selectedCategory == nil || puzzle.category == selectedCategory
            let matchesDifficulty = selectedDifficulty == nil || puzzle.difficulty == selectedDifficulty
            let matchesSearch = searchText.isEmpty || 
                                puzzle.name.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesDifficulty && matchesSearch
        }
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
    
    private func difficultyEmoji(for difficulty: Int) -> String {
        switch difficulty {
        case 0: return "⭐"
        case 1: return "⭐⭐"
        case 2: return "⭐⭐⭐"
        case 3: return "⭐⭐⭐⭐"
        case 4: return "⭐⭐⭐⭐⭐"
        default: return "⭐"
        }
    }
    
    private func difficultyColor(for difficulty: Int) -> Color {
        switch difficulty {
        case 0: return .green
        case 1: return .blue
        case 2: return .orange
        case 3: return .red
        case 4: return .purple
        default: return .gray
        }
    }
    
    // MARK: - Game Views
    
    private var gamePlayView: some View {
        Group {
            if let puzzle = viewModel.selectedPuzzle {
                TangramSpriteView(
                    puzzle: puzzle,
                    placedPieces: $viewModel.placedPieces,
                    timerStarted: viewModel.timerStarted,
                    formattedTime: viewModel.formattedTime,
                    progress: viewModel.progress,
                    isPuzzleComplete: viewModel.currentPhase == .puzzleComplete,
                    showHints: viewModel.showHints,
                    currentHint: viewModel.currentHint,
                    onPieceCompleted: { pieceType, isFlipped in
                        viewModel.handlePieceCompletion(pieceType: pieceType, isFlipped: isFlipped)
                    },
                    onPuzzleCompleted: {
                        viewModel.handlePuzzleCompletion()
                    },
                    onBackPressed: {
                        viewModel.exitToSelection()
                    },
                    onNextPressed: {
                        viewModel.loadNextPuzzle()
                    },
                    onStartTimer: {
                        viewModel.startTimer()
                    },
                    onToggleHints: {
                        viewModel.toggleHints()
                    }
                )
                .ignoresSafeArea(edges: .bottom) // Only ignore bottom
            } else {
                Text("No puzzle selected")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.exitToSelection()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                }
            }
            
            ToolbarItem(placement: .principal) {
                // Timer centered in toolbar
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 16))
                    if viewModel.timerStarted {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                    } else {
                        Button("Start") {
                            viewModel.startTimer()
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                // Hints button
                Button(action: {
                    viewModel.toggleHints()
                }) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // Removed unused gameHeader - timer is now in the navigation toolbar
    
    
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

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Text(icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? color.opacity(0.2) : Color(UIColor.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PuzzleThumbnailView: View {
    let puzzle: GamePuzzleData
    let allPuzzles: [GamePuzzleData]  // For badge calculation
    let action: () -> Void
    
    // Calculate badge for this puzzle
    private func getBadge() -> TangramBadgeType? {
        // Find newest puzzle (would be based on created_at in production)
        // For now, use last puzzle in list as "newest"
        let isNewest = allPuzzles.last?.id == puzzle.id
        
        // Mark first puzzle as "Top Pick" for demo
        // In production, this would use play count from analytics
        let isTopPick = allPuzzles.first?.id == puzzle.id
        
        return puzzle.getBadge(isNewest: isNewest, isTopPick: isTopPick)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Thumbnail preview - full square
                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                        
                        // Render puzzle silhouette properly scaled
                        PuzzleSilhouetteView(puzzle: puzzle)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .overlay(
                        // Dynamic badge overlay - top left corner
                        Group {
                            if let badge = getBadge() {
                                VStack {
                                    HStack {
                                        Label(badge.rawValue, systemImage: badge.icon)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(badge.color)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                            .padding(6)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                            }
                        }
                    )
                }
                .aspectRatio(1, contentMode: .fit)
                
                // Difficulty indicator - use actual database difficulty (1-5 scale)
                if puzzle.difficulty > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(puzzle.difficulty, 5), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                        ForEach(puzzle.difficulty..<5, id: \.self) { _ in
                            Image(systemName: "star")
                                .font(.system(size: 8))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct PuzzleSilhouetteView: View {
    let puzzle: GamePuzzleData
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate bounds of all pieces to scale appropriately
            let bounds = calculatePuzzleBounds()
            let scale = calculateScale(for: bounds, in: geometry.size)
            let offset = calculateOffset(for: bounds, scale: scale, in: geometry.size)
            
            ForEach(puzzle.targetPieces.indices, id: \.self) { index in
                let piece = puzzle.targetPieces[index]
                PuzzlePieceShape(
                    pieceType: piece.pieceType,
                    transform: piece.transform,
                    scale: scale,
                    offset: offset
                )
                .fill(Color.gray.opacity(0.7))
            }
        }
        .padding(8)
    }
    
    private func calculatePuzzleBounds() -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in puzzle.targetPieces {
            let vertices = TangramGameGeometry.normalizedVertices(for: piece.pieceType)
            let scaled = TangramGameGeometry.scaleVertices(vertices, by: TangramGameConstants.visualScale)
            let transformed = TangramGameGeometry.transformVertices(scaled, with: piece.transform)
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func calculateScale(for bounds: CGRect, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 16
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        
        let scaleX = availableWidth / bounds.width
        let scaleY = availableHeight / bounds.height
        
        return min(scaleX, scaleY, 1.0) // Don't scale up beyond original size
    }
    
    private func calculateOffset(for bounds: CGRect, scale: CGFloat, in size: CGSize) -> CGPoint {
        _ = bounds.width * scale
        _ = bounds.height * scale
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        let offsetX = centerX - (bounds.midX * scale)
        let offsetY = centerY - (bounds.midY * scale)
        
        return CGPoint(x: offsetX, y: offsetY)
    }
}

struct PuzzlePieceShape: Shape {
    let pieceType: TangramPieceType
    let transform: CGAffineTransform
    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        let transformedVertices = TangramGameGeometry.transformVertices(scaledVertices, with: transform)
        
        // Apply thumbnail scaling and offset
        let finalVertices = transformedVertices.map { vertex in
            CGPoint(
                x: vertex.x * scale + offset.x,
                y: vertex.y * scale + offset.y
            )
        }
        
        if let firstVertex = finalVertices.first {
            path.move(to: firstVertex)
            for vertex in finalVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
}