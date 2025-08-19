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
    @State private var difficultyOverride: UserPreferences.DifficultySetting? = nil
    
    #if DEBUG
    // Debug-only properties for CV mocking
    @State private var mockPieces: [RecognizedPiece] = []
    @State private var showCVMock = false
    #endif
    
    init(viewModel: TangramGameViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    // MARK: - Computed Properties
    
    private var isSelectionPhase: Bool {
        switch viewModel.currentPhase {
        case .selectingDifficulty, .map, .promotion, .finalCompletion:
            return true
        case .playingPuzzle, .puzzleComplete:
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentPhase {
                case .selectingDifficulty:
                    difficultySelectionView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .map(let difficulty):
                    mapView(for: difficulty)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .promotion(let from, let to, let completedCount):
                    PromotionInterstitialView(
                        viewModel: PromotionInterstitialViewModel(
                            fromDifficulty: from,
                            toDifficulty: to,
                            completedPuzzleCount: completedCount,
                            totalTimeSpent: viewModel.getTotalPlayTime(),
                            onContinue: { [weak viewModel] in
                                viewModel?.proceedToNextDifficulty(from: from, to: to)
                            },
                            onSkip: { [weak viewModel] in
                                viewModel?.skipPromotionToMap(difficulty: from)
                            }
                        )
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                
                case .finalCompletion(let totalCompleted, let totalTime):
                    FinalCompletionView(
                        viewModel: FinalCompletionViewModel(
                            totalPuzzlesCompleted: totalCompleted,
                            totalTimeSpent: totalTime,
                            onReturnToLobby: { [weak viewModel] in
                                viewModel?.returnToGameLobby()
                            },
                            onReplayDifficulty: { [weak viewModel] difficulty in
                                viewModel?.selectedDifficulty = difficulty
                                viewModel?.currentPhase = .map(difficulty)
                            }
                        )
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                    
                case .playingPuzzle:
                    gamePlayView
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    
                case .puzzleComplete:
                    completionView
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelectionPhase ? TangramTheme.Backgrounds.editor : TangramTheme.Backgrounds.gameScene)
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentPhase)
        }
        .onAppear {
            updateNavigationBarAppearance()
        }
        .onChange(of: viewModel.currentPhase) { _, _ in
            updateNavigationBarAppearance()
        }
    }
    
    // MARK: - Navigation Bar Configuration
    
    private func updateNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Set background color based on current phase
        let backgroundColor = switch viewModel.currentPhase {
        case .selectingDifficulty, .map, .promotion, .finalCompletion:
            UIColor(TangramTheme.Backgrounds.editor)  // Beige for library
        case .playingPuzzle, .puzzleComplete:
            UIColor(TangramTheme.Backgrounds.gameScene)  // White for game
        }
        
        appearance.backgroundColor = backgroundColor
        appearance.titleTextAttributes = [.foregroundColor: UIColor(TangramTheme.Text.primary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(TangramTheme.Text.primary)]
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        // Configure button appearance
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(TangramTheme.Text.primary)]
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        
        // Force update current navigation controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController?.presentedViewController as? UINavigationController {
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
        } else {
            // Fallback to global appearance
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
        UINavigationBar.appearance().tintColor = UIColor(TangramTheme.Text.primary)
    }
    
    // MARK: - Map View
    
    private func mapView(for difficulty: UserPreferences.DifficultySetting) -> some View {
        Group {
            if let childId = viewModel.childProfileId {
                let mapViewModel = viewModel.container.makeTangramMapViewModel(
                    difficulty: difficulty,
                    childProfileId: childId,
                    onPuzzleSelected: { puzzle in
                        viewModel.selectPuzzleFromMap(puzzle)
                    },
                    onBackToDifficulty: {
                        viewModel.returnToDifficultySelection()
                    },
                    onPromotionTriggered: { [weak viewModel] in
                        viewModel?.checkForPromotionAndTransition()
                    }
                )
                
                TangramMapView(viewModel: mapViewModel)
            } else {
                // Fallback if no child profile is set
                VStack(spacing: BemoTheme.Spacing.large) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("No Profile Selected")
                        .font(BemoTheme.font(for: .heading3))
                        .foregroundColor(BemoTheme.Colors.gray1)
                    
                    Text("Please select a child profile to continue")
                        .font(BemoTheme.font(for: .body))
                        .foregroundColor(BemoTheme.Colors.gray2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BemoTheme.Spacing.large)
                    
                    Button("Back to Difficulty Selection") {
                        viewModel.returnToDifficultySelection()
                    }
                    .primaryButtonStyle()
                }
                .padding(BemoTheme.Spacing.xlarge)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(TangramTheme.Backgrounds.editor, for: .navigationBar)
    }
    
    // MARK: - Difficulty Selection View
    
    private var difficultySelectionView: some View {
        Group {
            if let difficultyViewModel = viewModel.makeDifficultySelectionViewModel() {
                DifficultySelectionView(viewModel: difficultyViewModel)
            } else {
                // Fallback if no child profile is set
                VStack(spacing: BemoTheme.Spacing.large) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("No Profile Selected")
                        .font(BemoTheme.font(for: .heading3))
                        .foregroundColor(BemoTheme.Colors.gray1)
                    
                    Text("Please select a child profile to continue")
                        .font(BemoTheme.font(for: .body))
                        .foregroundColor(BemoTheme.Colors.gray2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BemoTheme.Spacing.large)
                    
                    Button("Back to Lobby") {
                        viewModel.requestQuit()
                    }
                    .primaryButtonStyle()
                }
                .padding(BemoTheme.Spacing.xlarge)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(TangramTheme.Backgrounds.editor, for: .navigationBar)
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
                    .foregroundColor(TangramTheme.UI.primaryButton)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Choose Difficulty")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(TangramTheme.Text.primary)
            }
        }
    }
    
    // MARK: - Puzzle Selection View
    
    private var puzzleSelectionView: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar - matching Editor UI
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(TangramTheme.Text.secondary)
                    TextField("Search puzzles...", text: $searchText)
                }
                .padding(8)
                .background(Color.white.opacity(0.95))
                .cornerRadius(8)

                // Student difficulty (Default/Easy/Medium/Hard) as icon-only menu
                Menu {
                    Button("Default", action: { difficultyOverride = nil; viewModel.applyDifficultyOverride(nil) })
                    Divider()
                    Button("Easy", action: { difficultyOverride = .easy; viewModel.applyDifficultyOverride(.easy) })
                    Button("Medium", action: { difficultyOverride = .normal; viewModel.applyDifficultyOverride(.normal) })
                    Button("Hard", action: { difficultyOverride = .hard; viewModel.applyDifficultyOverride(.hard) })
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(TangramTheme.UI.primaryButton)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(8)
                }

                // Combined filter (icon-only): top section difficulty (stars), next section categories
                Menu {
                    // Difficulty by stars
                    Menu("Difficulty (stars)") {
                        Button("All", action: { selectedDifficulty = nil })
                        Divider()
                        Button(action: { selectedDifficulty = 1 }) { Label("", systemImage: "star.fill").labelStyle(.iconOnly); Text("1 Star") }
                        Button(action: { selectedDifficulty = 2 }) { HStack(spacing: 2) { Image(systemName: "star.fill"); Image(systemName: "star.fill") }; Text("2 Stars") }
                        Button(action: { selectedDifficulty = 3 }) { HStack(spacing: 2) { Image(systemName: "star.fill"); Image(systemName: "star.fill"); Image(systemName: "star.fill") }; Text("3 Stars") }
                        Button(action: { selectedDifficulty = 4 }) { HStack(spacing: 2) { Image(systemName: "star.fill"); Image(systemName: "star.fill"); Image(systemName: "star.fill"); Image(systemName: "star.fill") }; Text("4 Stars") }
                        Button(action: { selectedDifficulty = 5 }) { HStack(spacing: 2) { Image(systemName: "star.fill"); Image(systemName: "star.fill"); Image(systemName: "star.fill"); Image(systemName: "star.fill"); Image(systemName: "star.fill") }; Text("5 Stars") }
                    }
                    Divider()
                    // Categories
                    Menu("Category") {
                        Button("All Categories", action: { selectedCategory = nil })
                        Divider()
                        ForEach(availableCategories, id: \.self) { category in
                            Button(category.capitalized) { selectedCategory = category }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(TangramTheme.UI.primaryButton)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(TangramTheme.Backgrounds.editor)
            
            Divider()
            
            // Puzzle grid - matching Editor layout
            if viewModel.availablePuzzles.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading puzzles...")
                        .foregroundColor(TangramTheme.Text.primary.opacity(0.6))
                }
                Spacer()
            } else if filteredPuzzles.isEmpty {
                // Empty state when no puzzles match filters
                VStack(spacing: 24) {
                    Image(systemName: "square.grid.3x3.square")
                        .font(.system(size: 80))
                        .foregroundColor(TangramTheme.Text.primary.opacity(0.4))
                    
                    VStack(spacing: 8) {
                        Text("No Puzzles Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(TangramTheme.Text.primary)
                        
                        Text("Try adjusting your search or filters")
                            .foregroundColor(TangramTheme.Text.primary.opacity(0.6))
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
                            TangramPuzzleCard(
                                puzzle: puzzle,
                                allPuzzles: filteredPuzzles,
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
        .background(TangramTheme.Backgrounds.editor)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(TangramTheme.Backgrounds.editor, for: .navigationBar)
        .toolbar {
            // Difficulty override control (per-game)
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
                    .foregroundColor(TangramTheme.UI.primaryButton)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Tangram")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(TangramTheme.Text.primary)
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
                    difficultySetting: viewModel.effectiveDifficulty,
                    placedPieces: $viewModel.placedPieces,
                    timerStarted: viewModel.timerStarted,
                    formattedTime: viewModel.formattedTime,
                    progress: viewModel.progress,
                    isPuzzleComplete: viewModel.currentPhase == .puzzleComplete,
                    showHints: viewModel.showHints,
                    currentHint: viewModel.currentHint,
                    cvOverlayImage: viewModel.cvOverlayImage,
                    cvFPS: viewModel.cvFPS,
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
                    onToggleHints: { viewModel.toggleHints() },
                    onValidatedTargetsChanged: { ids in
                        viewModel.syncValidatedTargetIds(ids)
                    }
                )
                .ignoresSafeArea(edges: .bottom) // Only ignore bottom
            } else {
                Text("No puzzle selected")
                    .foregroundColor(TangramTheme.Text.primary.opacity(0.6))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(TangramTheme.Backgrounds.gameScene, for: .navigationBar)
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
                    .foregroundColor(TangramTheme.UI.primaryButton)
                }
            }
            
            ToolbarItem(placement: .principal) {
                // Timer centered in toolbar (auto-started)
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 16))
                    Text(viewModel.formattedTime)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                }
                .foregroundColor(TangramTheme.Text.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                // Hints button - shows active state when hint is showing
                Button(action: {
                    viewModel.toggleHints()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.currentHint != nil ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 18))
                        if viewModel.currentHint != nil {
                            // Show a small indicator when hint is active
                            Image(systemName: "sparkle")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                    }
                    .foregroundColor(viewModel.currentHint != nil ? .yellow : TangramTheme.Text.primary)
                    .scaleEffect(viewModel.currentHint != nil ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentHint != nil)
                }
                .disabled(viewModel.currentHint != nil)  // Disable while hint is active
                .opacity(viewModel.currentHint != nil ? 0.8 : 1.0)
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
    
    private var starRating: Int {
        // Calculate star rating based on time and hints
        let baseTime: TimeInterval = 120  // 2 minutes for 3 stars
        let currentTime = viewModel.elapsedTime
        let hintsUsed = viewModel.hintHistory.count
        
        if currentTime <= baseTime && hintsUsed == 0 {
            return 3  // Perfect: Fast and no hints
        } else if currentTime <= baseTime * 1.5 || hintsUsed <= 1 {
            return 2  // Good: Reasonably fast or minimal hints
        } else {
            return 1  // Complete: Took time or used multiple hints
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
        VStack(spacing: 25) {
            // Celebration emoji and title
            Text("🎉")
                .font(.system(size: 80))
                .rotationEffect(.degrees(-15))
                .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatCount(3, autoreverses: true), value: viewModel.currentPhase)
            
            Text("Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(TangramTheme.Text.primary)
            
            Text("Amazing work! You solved \"\(viewModel.selectedPuzzle?.name ?? "the puzzle")\"!")
                .font(.title3)
                .foregroundColor(TangramTheme.Text.primary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Stats display
            VStack(spacing: 15) {
                // Time completed
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Time:")
                        .foregroundColor(TangramTheme.Text.primary.opacity(0.7))
                    Spacer()
                    Text(viewModel.formattedTime)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(TangramTheme.Text.primary)
                }
                .padding(.horizontal, 30)
                
                // Hints used
                if viewModel.hintHistory.count > 0 {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Hints Used:")
                            .foregroundColor(TangramTheme.Text.primary.opacity(0.7))
                        Spacer()
                        Text("\(viewModel.hintHistory.count)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(TangramTheme.Text.primary)
                    }
                    .padding(.horizontal, 30)
                }
                
                // Difficulty
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(difficultyColor)
                    Text("Difficulty:")
                        .foregroundColor(TangramTheme.Text.primary.opacity(0.7))
                    Spacer()
                    Text(difficultyName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(difficultyColor)
                }
                .padding(.horizontal, 30)
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(TangramTheme.Backgrounds.panel.opacity(0.95))
            )
            .padding(.horizontal, 20)
            
            // Star rating display
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < starRating ? "star.fill" : "star")
                        .font(.title)
                        .foregroundColor(index < starRating ? .yellow : .gray.opacity(0.3))
                        .scaleEffect(1.2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(index) * 0.1), value: viewModel.currentPhase)
                }
            }
            .padding(.top, 5)
            
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
                .fill(TangramTheme.Backgrounds.panel)
                .shadow(radius: 10)
        )
        .padding()
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(TangramTheme.Backgrounds.gameScene, for: .navigationBar)
    }
}

extension TangramGameView {
    private var difficultyOverrideLabel: String {
        guard let d = difficultyOverride else { return "Child Default" }
        switch d {
        case .easy: return "Easy"
        case .normal: return "Medium"
        case .hard: return "Hard"
        }
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
                    .foregroundColor(TangramTheme.Text.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? color.opacity(0.2) : TangramTheme.Backgrounds.panel.opacity(0.3))
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
                            .fill(Color.white)
                        
                        // Render puzzle thumbnail using shared service
                        PuzzleThumbnailService.shared.tangramThumbnailView(for: puzzle, colorful: true)
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
                    .background(TangramTheme.Backgrounds.editor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(TangramTheme.Text.primary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// Removed duplicate PuzzleSilhouetteView and PuzzlePieceShape - now using shared PuzzleThumbnailService