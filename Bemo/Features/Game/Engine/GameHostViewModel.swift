//
//  GameHostViewModel.swift
//  Bemo
//
//  ViewModel that manages the game session and connects services to the game
//

// WHAT: Manages active game lifecycle. Connects CVService to game, implements GameDelegate, manages scoring and session state.
// ARCHITECTURE: Central game coordinator in MVVM-S. Bridges services (CV, Gamification) with game logic. Implements GameDelegate for callbacks.
// USAGE: Created with a Game instance and required services. Subscribe to CVService, forward pieces to game, handle delegate callbacks.

import SwiftUI
import Combine
import Observation

@Observable
class GameHostViewModel {
    var gameView: AnyView = AnyView(EmptyView())
    var showError = false
    var errorMessage = ""
    var progress: Float = 0.0
    var showProgress = false
    
    // Session-wide tracking properties
    private var totalSessionXP: Int = 0
    private var levelsCompleted: Int = 0
    
    let game: Game  // Made non-private so GameHostView can access game.gameUIConfig
    private let cvService: CVService
    private let profileService: ProfileService
    private let supabaseService: SupabaseService
    private let learningService: LearningService
    private let errorTrackingService: ErrorTrackingService?
    private let audioService: AudioService?
    private let characterAnimationService: CharacterAnimationService?
    private var currentSessionId: String?
    private let currentChildProfileId: String
    private let onQuit: () -> Void
    
    private var cancellables = Set<AnyCancellable>()
    private var tangramCVAdapter: TangramCVEventsAdapter?
    
    init(
        game: Game,
        cvService: CVService,
        profileService: ProfileService,
        supabaseService: SupabaseService,
        learningService: LearningService,
        errorTrackingService: ErrorTrackingService? = nil,
        audioService: AudioService? = nil,
        characterAnimationService: CharacterAnimationService? = nil,
        currentChildProfileId: String,
        onQuit: @escaping () -> Void
    ) {
        self.game = game
        self.cvService = cvService
        self.profileService = profileService
        self.supabaseService = supabaseService
        self.errorTrackingService = errorTrackingService
        self.learningService = learningService
        self.audioService = audioService
        self.characterAnimationService = characterAnimationService
        self.currentChildProfileId = currentChildProfileId
        self.onQuit = onQuit
        
        // Defer game view creation until after initialization
        defer {
            self.gameView = game.makeGameView(delegate: self)
        }
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to CV service recognition events
        cvService.recognizedPiecesPublisher
            .sink { [weak self] recognizedPieces in
                self?.handleRecognizedPieces(recognizedPieces)
            }
            .store(in: &cancellables)
    }
    
    func startSession() {
        // Start CV service
        cvService.startSession()
        
        // Start game-scoped CV frame adapter when needed
        if game is TangramGame {
            // Ensure adapter starts on the main actor because it binds to Combine streams used on main runloop
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let adapter = TangramCVEventsAdapter(cvService: self.cvService)
                adapter.start()
                self.tangramCVAdapter = adapter
            }
        }
        
        // Reset game state
        game.reset()
        
        // Start game session via LearningService
        learningService.startSession(
            gameId: game.id,
            context: [
                "game_title": game.title,
                "device_type": "iOS",
                "cv_enabled": true
            ]
        )
    }
    
    func endSession() {
        // Stop CV service
        cvService.stopSession()
        
        // Stop adapter if running
        DispatchQueue.main.async { [weak self] in
            self?.tangramCVAdapter?.stop()
            self?.tangramCVAdapter = nil
        }
        
        // Save game state
        if let _ = game.saveState() {
            // TODO: Persist game state
        }
        
        // End game session via LearningService
        learningService.endSession(
            gameId: game.id,
            finalXP: totalSessionXP,
            levelsCompleted: levelsCompleted,
            context: [
                "completion_reason": "user_quit",
                "final_progress": progress
            ]
        )
    }
    
    private func handleRecognizedPieces(_ pieces: [RecognizedPiece]) {
        // Process pieces through the game
        let outcome = game.processRecognizedPieces(pieces)
        
        // Track the outcome in Supabase
        //not implemented until we figure out what we want to track
        Task {
            //            await trackOutcome(outcome)
        }
        
        // Handle the outcome locally
        switch outcome {
        case .correctPlacement(let points):
            totalSessionXP += points
        case .levelComplete(let xpAwarded):
            levelsCompleted += 1
            totalSessionXP += xpAwarded
        case .incorrectPlacement:
            // Provide feedback (handled by game's view)
            break
        case .noAction:
            // No action needed
            break
        case .specialAchievement(name: _, bonusXP: let bonusXP):
            totalSessionXP += bonusXP
            break
        case .hintUsed:
            break
        case .stateUpdated:
            break
        }
    }
        
    func handleQuitRequest() {
        endSession()
        // Switch back to lobby music
        audioService?.switchToLobbyMusic()
        onQuit()
    }
    
    func requestHint() {
        // This will be called by the UI and forwarded to the game
        gameDidRequestHint()
    }
}

// MARK: - GameDelegate
extension GameHostViewModel: GameDelegate {
    func gameDidCompleteLevel(xpAwarded: Int) {
        // Wrap as generic event via LearningService
        learningService.recordEvent(
            gameId: game.id,
            eventType: "level_completed",
            xpAwarded: xpAwarded,
            eventData: [
                "levels_completed_total": levelsCompleted
            ]
        )
        
        // Update local profile XP
        profileService.updateXP(xpAwarded, for: currentChildProfileId)
    }
    
    func gameDidRequestQuit() {
        handleQuitRequest()
    }
    
    func gameDidRequestHint() {
        // Log hint usage for analytics
    }
    
    func gameDidEncounterError(_ error: Error) {
        errorTrackingService?.trackError(error, context: ErrorContext(
            feature: "Game",
            action: "gameplay",
            metadata: [
                "gameId": game.id,
                "levelsCompleted": levelsCompleted,
                "sessionId": currentSessionId ?? "none"
            ]
        ))
        
        errorMessage = error.localizedDescription
        showError = true
    }
    
    func gameDidUpdateProgress(_ progress: Float) {
        self.progress = progress
        showProgress = progress > 0
    }
    
    func gameDidDetectFrustration(level: Float) {
        if level > 0.7 {
            Task {
                do {
                    try await supabaseService.trackLearningEvent(
                        childProfileId: currentChildProfileId,
                        eventType: "frustration_detected",
                        gameId: game.id,
                        xpAwarded: 0,
                        eventData: [
                            "frustration_level": level,
                            "levels_completed": levelsCompleted
                        ],
                        sessionId: currentSessionId
                    )
                } catch {
                    print("Failed to track frustration: \(error)")
                    errorTrackingService?.trackError(error, context: ErrorContext(
                        feature: "GameHost",
                        action: "trackFrustration",
                        metadata: [
                            "frustrationLevel": level,
                            "gameId": game.id
                        ]
                    ))
                }
            }
        }
    }

    func getChildDifficultySetting() -> UserPreferences.DifficultySetting {
        // Fallback to .normal if no active profile
        return profileService.currentProfile?.preferences.difficultySetting ?? .normal
    }
    
    func showCelebrationAnimation(at position: CharacterAnimationService.AnimationPosition) {
        characterAnimationService?.showCelebration(at: position)
    }
    
    func showCharacterAnimation(
        _ character: CharacterAnimationService.CharacterType,
        at position: CharacterAnimationService.AnimationPosition,
        duration: TimeInterval
    ) {
        characterAnimationService?.showCharacter(character, at: position, duration: duration)
    }
}
