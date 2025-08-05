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
    private let onQuit: () -> Void
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        game: Game,
        cvService: CVService,
        profileService: ProfileService,
        onQuit: @escaping () -> Void
    ) {
        self.game = game
        self.cvService = cvService
        self.profileService = profileService
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
        
        // Log session start
        print("Game session started: \(game.title)")
    }
    
    func endSession() {
        // Stop CV service
        cvService.stopSession()
        
        // Save game state
        if let gameState = game.saveState() {
            // TODO: Persist game state
            print("Game state saved")
        }
    }
    
    private func handleRecognizedPieces(_ pieces: [RecognizedPiece]) {
        // Process pieces through the game
        let outcome = game.processRecognizedPieces(pieces)
        
        // Handle the outcome
        switch outcome {
        case .correctPlacement(let points):
            // Award points through gamification service
            break
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
        // Award XP through gamification service
        
        // Show celebration or transition to next level
        print("Level completed! XP award not implemented: \(xpAwarded)")
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
        // Handle frustration detection
        if level > 0.7 {
            // Offer help or easier mode
            print("High frustration detected: \(level)")
        }
    }
}
