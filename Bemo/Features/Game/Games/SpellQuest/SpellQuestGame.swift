//
//  SpellQuestGame.swift
//  Bemo
//
//  Main game implementation for SpellQuest word-spelling game
//

// WHAT: Game protocol implementation for SpellQuest, a drag-and-drop word spelling game
// ARCHITECTURE: Game implementation in MVVM-S, bridges to game engine
// USAGE: Instantiated by GameLobby, creates game view with proper delegate

import SwiftUI

class SpellQuestGame: Game {
    // MARK: - Game Protocol Properties
    let id = "spellquest"
    let title = "Spell Quest"
    let description = "Drag letters to spell the word from the picture"
    let recommendedAge = 4...12
    let thumbnailImageName = "textformat.abc"
    
    var gameUIConfig: GameUIConfig {
        GameUIConfig(
            respectsSafeAreas: false,
            showHintButton: true,
            showProgressBar: true,
            showQuitButton: true
        )
    }
    
    // MARK: - Private State
    private var currentState: SpellQuestGameState?
    private let supabaseService: SupabaseService?
    
    // MARK: - Initialization
    init(supabaseService: SupabaseService? = nil) {
        self.supabaseService = supabaseService
    }
    
    // MARK: - Game Protocol Methods
    func makeGameView(delegate: GameDelegate) -> AnyView {
        let dependencyContainer = SpellQuestDependencyContainer(supabaseService: supabaseService)
        let viewModel = SpellQuestGameViewModel(
            contentService: dependencyContainer.contentService,
            hintService: dependencyContainer.hintService,
            scoringService: dependencyContainer.scoringService,
            audioHapticsService: dependencyContainer.audioHapticsService,
            delegate: delegate
        )
        
        // Get difficulty from delegate
        let difficulty = delegate.getChildDifficultySetting()
        viewModel.setDifficulty(difficulty)
        
        return AnyView(SpellQuestGameView(viewModel: viewModel))
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Touch-only game, no CV input processing
        return .noAction
    }
    
    func reset() {
        currentState = nil
    }
    
    func saveState() -> Data? {
        guard let state = currentState else { return nil }
        return try? JSONEncoder().encode(state)
    }
    
    func loadState(from data: Data) {
        currentState = try? JSONDecoder().decode(SpellQuestGameState.self, from: data)
    }
}

// MARK: - Game State for Persistence
private struct SpellQuestGameState: Codable {
    let mode: String
    let selectedAlbumIds: [String]
    let currentPuzzleIndex: Int
    let playerStates: [PlayerStateSnapshot]
}

private struct PlayerStateSnapshot: Codable {
    let puzzleId: String
    let filledSlots: [Int: Character]
    let hintsUsed: Int
    let errors: Int

    private enum CodingKeys: String, CodingKey {
        case puzzleId
        case filledSlots
        case hintsUsed
        case errors
    }

    private struct SlotPair: Codable {
        let index: Int
        let char: String
    }

    init(puzzleId: String, filledSlots: [Int: Character], hintsUsed: Int, errors: Int) {
        self.puzzleId = puzzleId
        self.filledSlots = filledSlots
        self.hintsUsed = hintsUsed
        self.errors = errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.puzzleId = try container.decode(String.self, forKey: .puzzleId)
        let pairs = try container.decode([SlotPair].self, forKey: .filledSlots)
        var dict: [Int: Character] = [:]
        for pair in pairs {
            if let firstChar = pair.char.first {
                dict[pair.index] = firstChar
            }
        }
        self.filledSlots = dict
        self.hintsUsed = try container.decode(Int.self, forKey: .hintsUsed)
        self.errors = try container.decode(Int.self, forKey: .errors)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(puzzleId, forKey: .puzzleId)
        let pairs = filledSlots.map { SlotPair(index: $0.key, char: String($0.value)) }
        try container.encode(pairs, forKey: .filledSlots)
        try container.encode(hintsUsed, forKey: .hintsUsed)
        try container.encode(errors, forKey: .errors)
    }
}