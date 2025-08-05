//
//  GameHostViewModel.swift
//  Bemo
//
//  ViewModel that manages the game session and connects services to the game
//

// GameHostViewModel.swift
// This is the brain of the active game session. It's a concrete class that does the actual work of connecting the different parts of your app.
// Its Job: To manage the entire lifecycle of a single game being played.

// What it Does:

// It holds the active Game module (e.g., the TangramGame instance).

// It subscribes to the CVService and passes the recognized pieces to the game.

// It implements the GameDelegate protocol, meaning it's the one listening for events like "level complete" or "quit."

// It tells the AppCoordinator when it's time to navigate away from the game.



import SwiftUI
import Combine

class GameHostViewModel: ObservableObject {
    @Published var gameView: AnyView = AnyView(EmptyView())
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var progress: Float = 0.0
    @Published var showProgress = false
    
    private let game: Game
    private let cvService: CVService
    private let gamificationService: GamificationService
    private let profileService: ProfileService
    private let onQuit: () -> Void
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        game: Game,
        cvService: CVService,
        gamificationService: GamificationService,
        profileService: ProfileService,
        onQuit: @escaping () -> Void
    ) {
        self.game = game
        self.cvService = cvService
        self.gamificationService = gamificationService
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
            if let profile = profileService.activeProfile {
                gamificationService.awardPoints(points, to: profile.id)
            }
            
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
        if let profile = profileService.activeProfile {
            gamificationService.awardXP(xpAwarded, to: profile.id)
        }
        
        // Show celebration or transition to next level
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
        // Handle frustration detection
        if level > 0.7 {
            // Offer help or easier mode
            print("High frustration detected: \(level)")
        }
    }
}
