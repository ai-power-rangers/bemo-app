//
//  DifficultySelectionView.swift
//  Bemo
//
//  Difficulty selection UI for choosing challenge level with progress tracking
//

// WHAT: Displays three difficulty cards (Easy, Medium, Hard) with progress info and recommendations
// ARCHITECTURE: View in MVVM-S pattern - presents DifficultySelectionViewModel state and handles interactions
// USAGE: Inject DifficultySelectionViewModel, handles user selection via callbacks

import SwiftUI

struct DifficultySelectionView: View {
    @State private var viewModel: DifficultySelectionViewModel
    @State private var selectedDifficulty: UserPreferences.DifficultySetting?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(viewModel: DifficultySelectionViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color("GameBackground")
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else {
                    mainContentView
                }
            }
        }
        .animation(.easeInOut(duration: BemoTheme.Animation.standard), value: viewModel.isLoading)
        .animation(.easeInOut(duration: BemoTheme.Animation.standard), value: viewModel.errorMessage)
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: BemoTheme.Spacing.large) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(BemoTheme.Colors.primary)
            
            Text("Loading difficulties...")
                .font(BemoTheme.font(for: .body))
                .foregroundColor(BemoTheme.Colors.gray2)
        }
    }
    
    // MARK: - Error State
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: BemoTheme.Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Oops! Something went wrong")
                .font(BemoTheme.font(for: .heading3))
                .foregroundColor(BemoTheme.Colors.gray1)
            
            Text(message)
                .font(BemoTheme.font(for: .body))
                .foregroundColor(BemoTheme.Colors.gray2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BemoTheme.Spacing.large)
            
            Button("Try Again") {
                Task {
                    await viewModel.loadDifficultyData()
                }
            }
            .primaryButtonStyle()
        }
        .padding(BemoTheme.Spacing.xlarge)
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: BemoTheme.Spacing.xlarge) {
                headerView
                difficultyCardsView
            }
            .padding(.horizontal, BemoTheme.Spacing.large)
            .padding(.vertical, BemoTheme.Spacing.xlarge)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: BemoTheme.Spacing.medium) {
            Text("Choose Your Challenge Level")
                .font(BemoTheme.font(for: .heading2))
                .foregroundColor(BemoTheme.Colors.gray1)
                .multilineTextAlignment(.center)
            
            if viewModel.isNewUser {
                Text("Start your tangram journey! Pick a difficulty to begin.")
                    .font(BemoTheme.font(for: .body))
                    .foregroundColor(BemoTheme.Colors.gray2)
                    .multilineTextAlignment(.center)
            } else {
                Text("Welcome back! Continue your progress or try a new challenge.")
                    .font(BemoTheme.font(for: .body))
                    .foregroundColor(BemoTheme.Colors.gray2)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var difficultyCardsView: some View {
        VStack(spacing: BemoTheme.Spacing.large) {
            ForEach(viewModel.availableDifficulties, id: \.self) { difficulty in
                DifficultyCard(
                    difficulty: difficulty,
                    stats: viewModel.difficultyStats[difficulty],
                    isRecommended: viewModel.isDifficultyRecommended(difficulty),
                    isSelected: selectedDifficulty == difficulty,
                    description: viewModel.getDifficultyDescription(difficulty),
                    progressText: viewModel.getProgressText(for: difficulty),
                    completionPercentage: viewModel.getCompletionPercentage(for: difficulty),
                    canSelect: viewModel.canSelectDifficulty(difficulty),
                    onTap: {
                        handleDifficultyTap(difficulty)
                    }
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleDifficultyTap(_ difficulty: UserPreferences.DifficultySetting) {
        // Visual feedback
        selectedDifficulty = difficulty
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Delay for visual feedback, then select
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedDifficulty = nil
            viewModel.selectDifficulty(difficulty)
        }
    }
}

// MARK: - Difficulty Card Component

struct DifficultyCard: View {
    let difficulty: UserPreferences.DifficultySetting
    let stats: DifficultySelectionViewModel.DifficultyStats?
    let isRecommended: Bool
    let isSelected: Bool
    let description: String
    let progressText: String
    let completionPercentage: Double
    let canSelect: Bool
    let onTap: () -> Void
    
    private var cardColors: (background: Color, foreground: Color, accent: Color) {
        switch difficulty {
        case UserPreferences.DifficultySetting.easy:
            return (BemoTheme.Colors.card2Background, BemoTheme.Colors.card2Foreground, .green)
        case UserPreferences.DifficultySetting.normal:
            return (BemoTheme.Colors.card3Background, BemoTheme.Colors.card3Foreground, .orange)
        case UserPreferences.DifficultySetting.hard:
            return (BemoTheme.Colors.card4Background, BemoTheme.Colors.card4Foreground, .red)
        }
    }
    
    private var difficultyTitle: String {
        switch difficulty {
        case UserPreferences.DifficultySetting.easy: return "Easy"
        case UserPreferences.DifficultySetting.normal: return "Medium"
        case UserPreferences.DifficultySetting.hard: return "Hard"
        }
    }
    
    private var difficultyIcon: String {
        switch difficulty {
        case UserPreferences.DifficultySetting.easy: return "star.fill"
        case UserPreferences.DifficultySetting.normal: return "star.leadinghalf.filled"
        case UserPreferences.DifficultySetting.hard: return "flame.fill"
        }
    }
    
    var body: some View {
        Button(action: {
            if canSelect {
                onTap()
            }
        }) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSelect)
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.easeInOut(duration: BemoTheme.Animation.quick), value: isSelected)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
    
    private var cardContent: some View {
        VStack(spacing: BemoTheme.Spacing.medium) {
            // Header with icon and title
            HStack {
                VStack(alignment: .leading, spacing: BemoTheme.Spacing.xxsmall) {
                    HStack {
                        Image(systemName: difficultyIcon)
                            .font(.title2)
                            .foregroundColor(cardColors.foreground)
                        
                        Text(difficultyTitle)
                            .font(BemoTheme.font(for: .heading3))
                            .foregroundColor(BemoTheme.Colors.gray1)
                        
                        Spacer()
                        
                        if isRecommended {
                            recommendedBadge
                        }
                        
                        if !canSelect {
                            lockedIndicator
                        }
                    }
                    
                    Text(description)
                        .font(BemoTheme.font(for: .body))
                        .foregroundColor(BemoTheme.Colors.gray2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            // Progress section
            if canSelect, let stats = stats {
                progressSection(stats: stats)
            } else if !canSelect {
                lockedSection
            }
        }
        .padding(BemoTheme.Spacing.large)
        .cardStyle(backgroundColor: cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .opacity(canSelect ? 1.0 : 0.6)
    }
    
    private var cardBackgroundColor: Color {
        if isRecommended {
            return cardColors.background.opacity(0.3)
        } else {
            return BemoTheme.Colors.background
        }
    }
    
    private var borderColor: Color {
        if isRecommended {
            return cardColors.foreground
        } else if !canSelect {
            return BemoTheme.Colors.gray2.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        isRecommended ? 2 : 0
    }
    
    private var recommendedBadge: some View {
        HStack(spacing: BemoTheme.Spacing.xxsmall) {
            Image(systemName: "star.circle.fill")
                .font(.caption)
            Text("RECOMMENDED")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, BemoTheme.Spacing.small)
        .padding(.vertical, BemoTheme.Spacing.xxsmall)
        .background(cardColors.foreground)
        .cornerRadius(BemoTheme.CornerRadius.small)
        .scaleEffect(isRecommended ? 1.1 : 1.0)
        .animation(
            reduceMotion ? 
                .easeInOut(duration: 0.2) : 
                .easeInOut(duration: 1.0).repeatCount(3, autoreverses: true),
            value: isRecommended
        )
    }
    
    private var lockedIndicator: some View {
        HStack(spacing: BemoTheme.Spacing.xxsmall) {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("LOCKED")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, BemoTheme.Spacing.small)
        .padding(.vertical, BemoTheme.Spacing.xxsmall)
        .background(BemoTheme.Colors.gray2)
        .cornerRadius(BemoTheme.CornerRadius.small)
    }
    
    private func progressSection(stats: DifficultySelectionViewModel.DifficultyStats) -> some View {
        VStack(alignment: .leading, spacing: BemoTheme.Spacing.small) {
            HStack {
                Text(progressText)
                    .font(BemoTheme.font(for: .body))
                    .foregroundColor(BemoTheme.Colors.gray1)
                
                Spacer()
                
                Text("\(Int(completionPercentage))%")
                    .font(BemoTheme.font(for: .body))
                    .fontWeight(.medium)
                    .foregroundColor(cardColors.foreground)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(BemoTheme.Colors.gray2.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(cardColors.foreground)
                        .frame(width: geometry.size.width * (completionPercentage / 100), height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.8), value: completionPercentage)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var lockedSection: some View {
        VStack(spacing: BemoTheme.Spacing.small) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(BemoTheme.Colors.gray2)
                
                Text("Complete earlier difficulties to unlock")
                    .font(BemoTheme.font(for: .body))
                    .foregroundColor(BemoTheme.Colors.gray2)
                
                Spacer()
            }
        }
    }
}

// MARK: - Accessibility

extension DifficultyCard {
    private var accessibilityLabel: String {
        var label = "\(difficultyTitle) difficulty. \(description)"
        
        if isRecommended {
            label += ". Recommended for you"
        }
        
        if canSelect, let stats = stats {
            label += ". Progress: \(stats.completedPuzzles) of \(stats.totalPuzzles) puzzles completed"
        } else if !canSelect {
            label += ". Locked. Complete earlier difficulties to unlock"
        }
        
        return label
    }
    
    private var accessibilityHint: String {
        if canSelect {
            return "Double tap to select this difficulty"
        } else {
            return "This difficulty is locked and cannot be selected"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct DifficultySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loading state
            DifficultySelectionView(viewModel: mockLoadingViewModel())
                .previewDisplayName("Loading State")
            
            // Normal state
            DifficultySelectionView(viewModel: mockNormalViewModel())
                .previewDisplayName("Normal State")
            
            // Error state
            DifficultySelectionView(viewModel: mockErrorViewModel())
                .previewDisplayName("Error State")
        }
    }
    
    static func mockLoadingViewModel() -> DifficultySelectionViewModel {
        let mockProgressService = MockTangramProgressService()
        let mockPuzzleService = MockPuzzleLibraryService()
        
        let viewModel = DifficultySelectionViewModel(
            childProfileId: "test-child",
            progressService: mockProgressService,
            puzzleLibraryService: mockPuzzleService,
            onDifficultySelected: { _ in }
        )
        
        // Simulate loading state
        viewModel.isLoading = true
        
        return viewModel
    }
    
    static func mockNormalViewModel() -> DifficultySelectionViewModel {
        let mockProgressService = MockTangramProgressService()
        let mockPuzzleService = MockPuzzleLibraryService()
        
        let viewModel = DifficultySelectionViewModel(
            childProfileId: "test-child",
            progressService: mockProgressService,
            puzzleLibraryService: mockPuzzleService,
            onDifficultySelected: { _ in }
        )
        
        // Simulate loaded state with mock data
        viewModel.isLoading = false
        viewModel.difficultyStats = [
            UserPreferences.DifficultySetting.easy: DifficultySelectionViewModel.DifficultyStats(totalPuzzles: 15, completedPuzzles: 8, isUnlocked: true),
            UserPreferences.DifficultySetting.normal: DifficultySelectionViewModel.DifficultyStats(totalPuzzles: 20, completedPuzzles: 3, isUnlocked: true),
            UserPreferences.DifficultySetting.hard: DifficultySelectionViewModel.DifficultyStats(totalPuzzles: 25, completedPuzzles: 0, isUnlocked: false)
        ]
        viewModel.recommendedDifficulty = UserPreferences.DifficultySetting.normal
        
        return viewModel
    }
    
    static func mockErrorViewModel() -> DifficultySelectionViewModel {
        let mockProgressService = MockTangramProgressService()
        let mockPuzzleService = MockPuzzleLibraryService()
        
        let viewModel = DifficultySelectionViewModel(
            childProfileId: "test-child",
            progressService: mockProgressService,
            puzzleLibraryService: mockPuzzleService,
            onDifficultySelected: { _ in }
        )
        
        // Simulate error state
        viewModel.isLoading = false
        viewModel.errorMessage = "Failed to load difficulty data. Please check your internet connection."
        
        return viewModel
    }
}

// Mock services for previews
class MockTangramProgressService: TangramProgressService {
    override func getProgress(for childId: String) -> TangramProgress {
        return TangramProgress(childProfileId: childId)
    }
}

class MockPuzzleLibraryService: PuzzleLibraryProviding {
    private let puzzles: [GamePuzzleData]
    
    init(puzzles: [GamePuzzleData] = []) {
        self.puzzles = puzzles
    }
    
    func loadPuzzles() async throws -> [GamePuzzleData] {
        return puzzles
    }
    
    func savePuzzle(_ puzzle: GamePuzzleData) async throws {
        // Mock implementation - do nothing
    }
    
    func deletePuzzle(id: String) async throws {
        // Mock implementation - do nothing
    }
}
#endif
