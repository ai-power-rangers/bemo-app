//
//  TangramCVGameView.swift
//  Bemo
//
//  Main SwiftUI view for CV-ready Tangram game
//

// WHAT: SwiftUI view that hosts the three-zone SpriteKit scene and manages UI
// ARCHITECTURE: View in MVVM-S, observes TangramCVGameViewModel for state changes
// USAGE: Created by TangramCVGame, displays puzzle selection and three-zone gameplay

import SwiftUI
import SpriteKit

struct TangramCVGameView: View {
    @Bindable var viewModel: TangramCVGameViewModel
    @State private var showingPuzzleSelection = true
    @State private var sceneSize: CGSize = .zero
    @State private var timerStarted = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var showHints = false
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentPhase {
                case .selectingPuzzle:
                    puzzleSelectionView
                    
                case .playingPuzzle:
                    gameplayView
                    
                case .puzzleComplete:
                    completionView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("GameBackground", bundle: nil))
        }
        .onAppear {
            setupNavigationAppearance()
        }
    }
    
    private func setupNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - Puzzle Selection
    
    private var puzzleSelectionView: some View {
        VStack(spacing: 0) {
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
                        ForEach(viewModel.availablePuzzles, id: \.id) { puzzle in
                            PuzzleCard(puzzle: puzzle) {
                                viewModel.selectPuzzle(puzzle)
                                showingPuzzleSelection = false
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationTitle("Choose a Puzzle (CV)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.quitToLobby()
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
    
    // MARK: - Gameplay View
    
    private var gameplayView: some View {
        Group {
            if viewModel.selectedPuzzle != nil {
                GeometryReader { geometry in
                    SpriteView(
                        scene: scene,
                        options: [.allowsTransparency]
                    )
                    .ignoresSafeArea()
                    .onAppear {
                        configureScene(size: geometry.size)
                    }
                    .onChange(of: viewModel.selectedPuzzle) { _, newValue in
                        if let puzzle = newValue {
                            scene.loadPuzzle(puzzle)
                        }
                    }
                }
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
                    viewModel.currentPhase = .selectingPuzzle
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
                    if timerStarted {
                        Text(formattedTime)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                    } else {
                        Button("Start") {
                            startTimer()
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                // Hints button
                Button(action: {
                    showHints.toggle()
                }) {
                    Image(systemName: showHints ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 18))
                        .foregroundColor(showHints ? .yellow : .primary)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            // CV output indicator
            if !viewModel.cvOutputStream.isEmpty {
                cvOutputIndicator
                    .padding(.top, 60)
                    .padding(.trailing)
            }
        }
    }
    
    private func startTimer() {
        timerStarted = true
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    elapsedTime += 1
                }
            }
        }
    }
    
    private var cvOutputIndicator: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("CV Stream")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let anchorId = viewModel.cvOutputStream["anchor_id"] as? String,
               anchorId != "none" {
                Text("Anchor: Active")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            
            if let objects = viewModel.cvOutputStream["objects"] as? [[String: Any]] {
                Text("\(objects.count) pieces")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 30) {
            // Celebration emoji and title
            Text("🎉")
                .font(.system(size: 80))
                .rotationEffect(.degrees(-15))
            
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
                ForEach(0..<3) { _ in
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                        .scaleEffect(1.2)
                }
            }
            .padding()
            
            // Navigation buttons
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.quitToLobby()
                }) {
                    Label("Back to Lobby", systemImage: "house.fill")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    viewModel.selectNextPuzzle()
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.currentPhase = .selectingPuzzle
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
    
    // MARK: - Scene Creation
    
    @State private var scene: TangramThreeZoneScene = {
        let scene = TangramThreeZoneScene()
        scene.size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        scene.scaleMode = .resizeFill
        return scene
    }()
    
    private func configureScene(size: CGSize) {
        scene.size = size
        scene.scaleMode = .resizeFill
        scene.puzzle = viewModel.selectedPuzzle
        scene.isCVMode = viewModel.isCVMode
        
        // Set up callbacks
        scene.onPiecePlaced = { [weak viewModel] piece, inAssemblyZone in
            viewModel?.handlePiecePlacement(piece, inAssemblyZone: inAssemblyZone)
        }
        
        scene.onAnchorChanged = { [weak viewModel] anchor in
            if let anchor = anchor {
                viewModel?.setAnchorPiece(anchor)
            }
        }
        
        scene.onCVDataGenerated = { [weak viewModel] cvData in
            viewModel?.cvOutputStream = cvData
        }
        
        scene.onPuzzleCompleted = { [weak viewModel] in
            viewModel?.validateAssembly()
        }
    }
}

// MARK: - Puzzle Card Component

struct PuzzleCard: View {
    let puzzle: GamePuzzleData
    let onTap: () -> Void
    
    var difficultyColor: Color {
        switch puzzle.difficulty {
        case 0: return .green
        case 1: return .blue
        case 2: return .orange
        case 3: return .red
        case 4: return .purple
        default: return .gray
        }
    }
    
    var categoryIcon: String {
        switch puzzle.category.lowercased() {
        case "animals": return "🐾"
        case "objects": return "📦"
        case "people": return "👤"
        case "geometric": return "🔷"
        default: return "✨"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Thumbnail with category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(difficultyColor.opacity(0.15))
                        .frame(height: 100)
                    
                    VStack {
                        Text(categoryIcon)
                            .font(.largeTitle)
                        Text(puzzle.category.capitalized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Puzzle name
                Text(puzzle.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                // Difficulty stars
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < puzzle.difficulty ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(index < puzzle.difficulty ? difficultyColor : .gray.opacity(0.3))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}