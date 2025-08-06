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
    
    private let game: Game
    private let cvService: CVService
    private let profileService: ProfileService
    private let supabaseService: SupabaseService
    private var currentSessionId: String?
    private let currentChildProfileId: String
    private let onQuit: () -> Void
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        game: Game,
        cvService: CVService,
        profileService: ProfileService,
        supabaseService: SupabaseService,
        currentChildProfileId: String,
        onQuit: @escaping () -> Void
    ) {
        self.game = game
        self.cvService = cvService
        self.profileService = profileService
        self.supabaseService = supabaseService
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
                print("Game session started: \(currentSessionId ?? "unknown")")
            } catch {
                print("Failed to start game session: \(error)")
            }
        }
    }
    
    func endSession() {
        // Stop CV service
        cvService.stopSession()
        
        // Save game state
        if let gameState = game.saveState() {
            // TODO: Persist game state
            print("Game state saved")
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
                }
            }
        }
    }
    
    private func handleRecognizedPieces(_ pieces: [RecognizedPiece]) {
        // Process pieces through the game
        let outcome = game.processRecognizedPieces(pieces)
        
        // Track the outcome in Supabase
        Task {
            await trackOutcome(outcome)
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
            
        case .levelComplete(let xpAwarded):
            // Level completed - delegate will be called by game
            break
            
        case .noAction:
            // No action needed
            break
        case .specialAchievement(name: let name, bonusXP: let bonusXP):
            break
        case .hintUsed:
            break
        case .stateUpdated:
            break
        }
    }
    
    private func trackOutcome(_ outcome: PlayerActionOutcome) async {
        do {
            let eventType: String
            let xpAwarded: Int
            var eventData: [String: Any] = [:]
            
            switch outcome {
            case .correctPlacement(let points):
                eventType = "correct_placement"
                xpAwarded = points
                eventData["points"] = points
                
            case .incorrectPlacement:
                eventType = "incorrect_placement"
                xpAwarded = 0
                
            case .levelComplete(let xp):
                eventType = "level_completed"
                xpAwarded = xp
                eventData["level"] = currentLevel
                
            case .specialAchievement(let name, let bonusXP):
                eventType = "achievement_unlocked"
                xpAwarded = bonusXP
                eventData["achievement_name"] = name
                
            case .hintUsed:
                eventType = "hint_used"
                xpAwarded = 0
                
            case .noAction, .stateUpdated:
                return // Don't track these
            }
            
            try await supabaseService.trackLearningEvent(
                childProfileId: currentChildProfileId,
                eventType: eventType,
                gameId: game.id,
                xpAwarded: xpAwarded,
                eventData: eventData,
                sessionId: currentSessionId
            )
        } catch {
            print("Failed to track learning event: \(error)")
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
                        "level": currentLevel,
                        "time_to_complete": levelTimer
                    ],
                    sessionId: currentSessionId
                )
                
                // Update local profile XP
                profileService.awardXP(xpAwarded, to: currentChildProfileId)
                
            } catch {
                print("Failed to track level completion: \(error)")
            }
        }
        
        print("Level completed! XP awarded: \(xpAwarded)")
    }
    
    func gameDidRequestQuit() {
        handleQuitRequest()
    }
    
    func gameDidRequestHint() {
        // Log hint usage for analytics
        print("Hint requested")
    }
    
    func gameDidEncounterError(_ error: Error) {
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
                            "current_level": currentLevel
                        ],
                        sessionId: currentSessionId
                    )
                } catch {
                    print("Failed to track frustration: \(error)")
                }
            }
        }
    }
}
