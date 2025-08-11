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
    private let errorTrackingService: ErrorTrackingService?
    private var currentSessionId: String?
    private let currentChildProfileId: String
    private let onQuit: () -> Void
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        game: Game,
        cvService: CVService,
        profileService: ProfileService,
        supabaseService: SupabaseService,
        errorTrackingService: ErrorTrackingService? = nil,
        currentChildProfileId: String,
        onQuit: @escaping () -> Void
    ) {
        self.game = game
        self.cvService = cvService
        self.profileService = profileService
        self.supabaseService = supabaseService
        self.errorTrackingService = errorTrackingService
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
        
        // Reset game state
        game.reset()
        
        // Start game session in Supabase
        Task {
            do {
                currentSessionId = try await supabaseService.startGameSession(
                    childProfileId: currentChildProfileId,
                    gameId: game.id,
                    sessionData: [
                        "game_title": game.title,
                        "device_type": "iOS",
                        "cv_enabled": true
                    ]
                )
            } catch {
                print("Failed to start game session: \(error)")
                errorTrackingService?.trackError(error, context: ErrorContext(
                    feature: "GameHost",
                    action: "startGameSession",
                    metadata: [
                        "gameId": game.id,
                        "profileId": currentChildProfileId
                    ]
                ))
            }
        }
    }
    
    func endSession() {
        // Stop CV service
        cvService.stopSession()
        
        // Save game state
        if let _ = game.saveState() {
            // TODO: Persist game state
        }
        
        // End game session in Supabase
        if let sessionId = currentSessionId {
            Task {
                do {
                    try await supabaseService.endGameSession(
                        sessionId: sessionId,
                        finalXPEarned: totalSessionXP,
                        finalLevelsCompleted: levelsCompleted,
                        finalSessionData: [
                            "completion_reason": "user_quit",
                            "final_progress": progress
                        ]
                    )
                } catch {
                    print("Failed to end game session: \(error)")
                    errorTrackingService?.trackError(error, context: ErrorContext(
                        feature: "GameHost",
                        action: "endGameSession",
                        metadata: [
                            "sessionId": sessionId,
                            "totalSessionXP": totalSessionXP,
                            "levelsCompleted": levelsCompleted
                        ]
                    ))
                }
            }
        }
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
        Task {
            do {
                try await supabaseService.trackLearningEvent(
                    childProfileId: currentChildProfileId,
                    eventType: "level_completed",
                    gameId: game.id,
                    xpAwarded: xpAwarded,
                    eventData: [
                        "levels_completed_total": levelsCompleted
                    ],
                    sessionId: currentSessionId
                )
                
                // Update local profile XP
                profileService.updateXP(xpAwarded, for: currentChildProfileId)
                
            } catch {
                print("Failed to track level completion: \(error)")
                errorTrackingService?.trackError(error, context: ErrorContext(
                    feature: "GameHost",
                    action: "trackLevelCompletion",
                    metadata: [
                        "gameId": game.id,
                        "xpAwarded": xpAwarded,
                        "levelsCompleted": levelsCompleted
                    ]
                ))
            }
        }
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
}
