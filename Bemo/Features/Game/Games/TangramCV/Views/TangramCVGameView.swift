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
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var sceneKey = UUID()  // Key to force scene recreation
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var availableCategories: [String] {
        Array(Set(viewModel.availablePuzzles.map { $0.category })).sorted()
    }
    
    private var filteredPuzzles: [GamePuzzleData] {
        var puzzles = viewModel.availablePuzzles
        
        if let category = selectedCategory {
            puzzles = puzzles.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            puzzles = puzzles.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return puzzles
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
            // Search and Filter Bar - matching Editor UI
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
                
                // Category filter dropdown - matching Editor
                Menu {
                    Button("All Categories", action: { selectedCategory = nil })
                    Divider()
                    ForEach(availableCategories, id: \.self) { category in
                        Button(category.capitalized) {
                            selectedCategory = category
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedCategory?.capitalized ?? "All")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
            
            // Puzzle grid - matching Editor layout
            if viewModel.availablePuzzles.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading puzzles...")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if filteredPuzzles.isEmpty {
                // Empty state when no puzzles match filters
                VStack(spacing: 24) {
                    Image(systemName: "square.grid.3x3.square")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("No Puzzles Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Try adjusting your search or filters")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredPuzzles, id: \.id) { puzzle in
                            TangramCVPuzzleCard(
                                puzzle: puzzle,
                                allPuzzles: filteredPuzzles,
                                action: {
                                    viewModel.selectPuzzle(puzzle)
                                    // Reset timer and force new scene
                                    timerStarted = false
                                    elapsedTime = 0
                                    timerTask?.cancel()
                                    sceneKey = UUID()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGray6))
        .navigationTitle("")
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
            
            ToolbarItem(placement: .principal) {
                Text("Puzzle Library")
                    .font(.system(size: 18, weight: .semibold))
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
                    .id(sceneKey)  // Forces new SpriteView when key changes
                    .ignoresSafeArea()
                    .onAppear {
                        configureScene(size: geometry.size)
                    }
                    .onChange(of: viewModel.selectedPuzzle) { _, newValue in
                        if newValue != nil {
                            // Force scene recreation for clean state
                            sceneKey = UUID()
                            // Scene will be loaded in onAppear after recreation
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
        TangramCVCompletionView(
            puzzle: viewModel.selectedPuzzle,
            timeElapsed: formattedTime,
            onNextPuzzle: {
                viewModel.selectNextPuzzle()
                // Reset timer and force new scene
                timerStarted = false
                elapsedTime = 0
                timerTask?.cancel()
                sceneKey = UUID()
            },
            onBackToLobby: {
                viewModel.quitToLobby()
            }
        )
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
        
        // Connect scene to viewModel via delegate pattern
        viewModel.setScene(scene)
        
        // Load selected puzzle if any
        if let puzzle = viewModel.selectedPuzzle {
            scene.loadPuzzle(puzzle)
        }
    }
}

// Puzzle Card component moved to TangramCVPuzzleCard.swift