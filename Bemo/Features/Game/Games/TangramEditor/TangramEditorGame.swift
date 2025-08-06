//
//  TangramEditorGame.swift
//  Bemo
//
//  Game integration for the Tangram Editor - parent-only puzzle creation tool
//

import SwiftUI
import Foundation

class TangramEditorGame: Game {
    
    // MARK: - Properties
    
    let id = "tangram-editor"
    let title = "Tangram Editor"
    let description = "Create custom tangram puzzles for children to solve"
    let recommendedAge = 18...99 // Parent-only tool
    let thumbnailImageName = "tangram_editor_thumb"
    
    private var viewModel: TangramEditorViewModel?
    private weak var delegate: GameDelegate?
    
    // State management
    private var cachedPuzzleData: Data?
    private var pendingStateToLoad: Data?
    
    // Use editor configuration with custom bars
    var gameUIConfig: GameUIConfig {
        // Simple configuration - let the views handle their own visibility
        let topBar = viewModel != nil ? AnyView(TangramEditorTopBar(viewModel: viewModel!, delegate: delegate)) : nil
        let bottomBar = viewModel != nil ? AnyView(TangramEditorBottomBar(viewModel: viewModel!)) : nil
        
        return GameUIConfig(
            respectsSafeAreas: true,
            showHintButton: false,
            showProgressBar: false,
            showQuitButton: false,  // We provide quit in our custom top bar
            customTopBar: topBar,
            customBottomBar: bottomBar
        )
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Game Protocol
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        self.delegate = delegate
        
        // Create a wrapper view that handles MainActor initialization
        return AnyView(
            TangramEditorInitializerView(
                onInitialize: { [weak self] in
                    guard let self = self else { return nil }
                    await self.initializeViewModel(delegate: delegate)
                    return self.viewModel
                }
            )
        )
    }
    
    @MainActor
    private func initializeViewModel(delegate: GameDelegate) async {
        if viewModel == nil {
            viewModel = TangramEditorViewModel(puzzle: nil)
            viewModel?.delegate = delegate
            
            // Set up state change notification
            viewModel?.onPuzzleChanged = { [weak self] puzzle in
                self?.updateStateCache(puzzle)
            }
            
            // Load pending state if any
            if let pendingData = pendingStateToLoad {
                if let puzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: pendingData) {
                    viewModel?.loadPuzzle(from: puzzle)
                }
                pendingStateToLoad = nil
            }
        }
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Tangram Editor doesn't use CV input - it's a digital creation tool
        // Return neutral outcome since this is not applicable
        return .noAction
    }
    
    func reset() {
        Task { @MainActor in
            viewModel?.reset()
        }
    }
    
    func saveState() -> Data? {
        // Return cached state if available
        // This is the primary mechanism - always use cache
        return cachedPuzzleData
    }
    
    func loadState(from data: Data) {
        // Store the data for when viewModel is created
        pendingStateToLoad = data
        cachedPuzzleData = data
        
        // If viewModel already exists, load immediately
        if viewModel != nil {
            if let puzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: data) {
                Task { @MainActor in
                    self.viewModel?.loadPuzzle(from: puzzle)
                }
            }
        }
    }
    
    // MARK: - State Management Helpers
    
    private func updateStateCache(_ puzzle: TangramPuzzle) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        cachedPuzzleData = try? encoder.encode(puzzle)
    }
}

// MARK: - Initializer View

private struct TangramEditorInitializerView: View {
    let onInitialize: () async -> TangramEditorViewModel?
    @State private var viewModel: TangramEditorViewModel?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                TangramEditorContainerView(viewModel: viewModel)
            } else if isLoading {
                ProgressView("Loading Editor...")
                    .task {
                        viewModel = await onInitialize()
                        isLoading = false
                    }
            } else {
                Text("Failed to initialize editor")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Parent Access Control

extension TangramEditorGame {
    
    /// Check if the current user has permission to access the editor
    var isAccessible: Bool {
        // Check if no active child profile is selected (parent mode)
        // In parent mode, activeProfile would be nil
        // This follows the pattern where parents manage the app when no child is selected
        
        // Note: This logic assumes that:
        // 1. When a child profile is active, we're in child mode
        // 2. When no profile is active, we're in parent/admin mode
        // 3. The tangram editor is a parent-only tool
        
        // Future enhancement: Add PIN or biometric authentication for additional security
        return !hasActiveChildProfile()
    }
    
    /// Check if there's an active child profile
    private func hasActiveChildProfile() -> Bool {
        // Check UserDefaults for active profile
        // This matches the ProfileService implementation
        let activeProfileKey = "com.bemo.activeProfile"
        return UserDefaults.standard.data(forKey: activeProfileKey) != nil
    }
    
    /// Message to show when access is denied
    var accessDeniedMessage: String {
        "The Tangram Editor is only available to parents and educators. Please switch to parent mode to access this feature."
    }
    
    /// Check access and provide appropriate view
    func makeAccessControlledView(delegate: GameDelegate) -> AnyView {
        if isAccessible {
            return makeGameView(delegate: delegate)
        } else {
            return AnyView(
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Parent Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(accessDeniedMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("Return to Games") {
                        delegate.gameDidRequestQuit()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            )
        }
    }
}