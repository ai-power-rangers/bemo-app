//
//  SpellQuestGameViewModel.swift
//  Bemo
//
//  Main ViewModel orchestrating SpellQuest game modes and flow
//

// WHAT: Central ViewModel managing game state, mode transitions, and player coordination
// ARCHITECTURE: ViewModel in MVVM-S, coordinates services and child ViewModels
// USAGE: Created by SpellQuestGame, manages entire game session lifecycle

import Foundation
import SwiftUI
import Observation

// Type alias for difficulty settings
typealias GameDifficulty = UserPreferences.DifficultySetting

@Observable
class SpellQuestGameViewModel {
    // MARK: - Navigation State
    enum NavigationState {
        case modeSelect
        case librarySelect
        case playing
    }
    
    // MARK: - Observable State
    private(set) var navigationState: NavigationState = .modeSelect
    private(set) var selectedMode: SpellQuestGameMode?
    private(set) var selectedAlbumIds: Set<String> = []
    private(set) var currentPuzzles: [SpellQuestPuzzle] = []
    private(set) var currentPuzzleIndex: Int = 0
    
    // Player ViewModel (only one needed now)
    private(set) var playerViewModel: PlayerBoardViewModel?
    
    // Session tracking
    private(set) var sessionXP: Int = 0
    private(set) var wordsCompleted: Int = 0
    private(set) var showingCelebration: Bool = false

    // MARK: - Derived Data
    var installedAlbums: [SpellQuestAlbum] {
        contentService.getInstalledAlbums()
    }
    
    // MARK: - Dependencies
    private let contentService: SpellQuestContentService
    private let hintService: SpellQuestHintService
    private let scoringService: SpellQuestScoringService
    private let audioHapticsService: SpellQuestAudioHapticsService
    private weak var delegate: GameDelegate?
    
    private var difficulty: GameDifficulty = .normal
    private var lastActivityTime = Date()
    private var idleTimer: Timer?
    
    // MARK: - Initialization
    init(
        contentService: SpellQuestContentService,
        hintService: SpellQuestHintService,
        scoringService: SpellQuestScoringService,
        audioHapticsService: SpellQuestAudioHapticsService,
        delegate: GameDelegate
    ) {
        self.contentService = contentService
        self.hintService = hintService
        self.scoringService = scoringService
        self.audioHapticsService = audioHapticsService
        self.delegate = delegate
        
        setupPlayerViewModel()
        startIdleTimer()
    }
    
    // MARK: - Setup
    private func setupPlayerViewModel() {
        playerViewModel = PlayerBoardViewModel(
            audioHapticsService: audioHapticsService,
            onLetterPlaced: { [weak self] xp in
                self?.sessionXP += xp
            },
            onWordCompleted: { [weak self] boardState in
                self?.handleWordCompletion(boardState: boardState)
            }
        )
    }
    
    func setDifficulty(_ difficulty: GameDifficulty) {
        self.difficulty = difficulty
    }
    
    // MARK: - Navigation Actions
    func selectMode(_ mode: SpellQuestGameMode) {
        selectedMode = mode
        navigationState = .librarySelect
        
        // Fetch remote albums when entering library selection
        Task {
            await contentService.refreshFromRemote()
        }
    }
    
    func selectAlbums(_ albumIds: Set<String>) {
        selectedAlbumIds = albumIds
        startNewSession()
    }
    
    func backToModeSelect() {
        navigationState = .modeSelect
        selectedMode = nil
        resetSession()
    }
    
    func backToLibrary() {
        navigationState = .librarySelect
    }
    
    // MARK: - Game Session Management
    private func startNewSession() {
        guard let mode = selectedMode else { return }
        
        // Reset session
        sessionXP = 0
        wordsCompleted = 0
        currentPuzzleIndex = 0
        
        // Get puzzles for selected albums (already fetched when entering library)
        currentPuzzles = contentService.getPuzzlesForMode(
            mode,
            albumIds: selectedAlbumIds,
            difficulty: difficulty
        )
        
        guard !currentPuzzles.isEmpty else { return }
        
        // Start playing
        navigationState = .playing
        startNextPuzzle()
    }
    
    private func startNextPuzzle() {
        guard currentPuzzleIndex < currentPuzzles.count else {
            endSession()
            return
        }
        
        let puzzle = currentPuzzles[currentPuzzleIndex]
        showingCelebration = false
        
        // Setup player board
        playerViewModel?.beginRound(puzzle: puzzle)
        
        // Reset idle timer
        resetIdleTimer()
        
        // Report progress
        updateProgress()
    }
    
    // MARK: - Gameplay Actions
    func onHintRequested() {
        guard let mode = selectedMode,
              let playerBoard = playerViewModel?.boardState else { return }
        
        // Get hint for player
        if let hint = hintService.getNextHint(for: playerBoard, mode: mode) {
            playerViewModel?.revealHint(hint)
        }
        
        delegate?.gameDidRequestHint()
        resetIdleTimer()
    }
    
    func onQuitRequested() {
        delegate?.gameDidRequestQuit()
    }
    
    // MARK: - Completion Handling
    private func handleWordCompletion(boardState: PlayerBoardState) {
        wordsCompleted += 1
        
        // Calculate XP for this word
        let wordXP = scoringService.calculateWordCompletionXP(
            boardState: boardState,
            mode: selectedMode ?? .zen
        )
        sessionXP += wordXP
        
        // Report to delegate
        delegate?.gameDidCompleteLevel(xpAwarded: wordXP)
        
        // Show celebration and wait for user to tap "Next"
        showCelebration {
            // In Zen modes, wait for user action instead of auto-advancing
            // User can tap "Next" button
        }
    }
    
    func advanceToNextPuzzle() {
        currentPuzzleIndex += 1
        startNextPuzzle()
    }
    
    private func showCelebration(completion: @escaping () -> Void) {
        showingCelebration = true
        DispatchQueue.main.asyncAfter(
            deadline: .now() + SpellQuestConstants.Gameplay.celebrationDuration
        ) {
            completion()
        }
    }
    
    // MARK: - Session Management
    private func endSession() {
        // Could show session summary here
        delegate?.gameDidRequestQuit()
    }
    
    private func resetSession() {
        currentPuzzles = []
        currentPuzzleIndex = 0
        sessionXP = 0
        wordsCompleted = 0
    }
    
    // MARK: - Progress Tracking
    private func updateProgress() {
        let progress = playerViewModel?.boardState.progress ?? 0
        delegate?.gameDidUpdateProgress(progress)
    }
    
    // MARK: - Idle Timer for Zen Junior
    private func startIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkIdleTime()
        }
    }
    
    private func resetIdleTimer() {
        lastActivityTime = Date()
    }
    
    private func checkIdleTime() {
        guard selectedMode == .zenJunior else { return }
        
        let idleTime = Date().timeIntervalSince(lastActivityTime)
        if hintService.shouldAutoHint(for: .zenJunior, idleTime: idleTime) {
            onHintRequested()
            resetIdleTimer()
        }
    }
    
    deinit {
        idleTimer?.invalidate()
    }
}