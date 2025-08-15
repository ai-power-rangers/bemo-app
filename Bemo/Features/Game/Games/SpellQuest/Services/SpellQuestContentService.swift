//
//  SpellQuestContentService.swift
//  Bemo
//
//  Manages albums and puzzles for SpellQuest
//

// WHAT: Provides and manages puzzle content (albums, words, images)
// ARCHITECTURE: Service layer in MVVM-S
// USAGE: Used by ViewModels to fetch puzzles based on mode and difficulty

import Foundation
import Observation

// Type alias for difficulty settings
typealias LettersGameDifficulty = UserPreferences.DifficultySetting

@Observable
class SpellQuestContentService {
    private(set) var albums: [SpellQuestAlbum] = []
    private var shuffleSeed: Int = Int.random(in: 0...1000)
    
    init() {
        loadLocalContent()
    }
    
    private func loadLocalContent() {
        // Stage 1: Three local puzzles in one album
        let starterPuzzles = [
            SpellQuestPuzzle(
                id: "apple",
                imageName: "spellquest_apple",
                word: "APPLE",
                displayTitle: "Apple"
            ),
            SpellQuestPuzzle(
                id: "cat",
                imageName: "spellquest_cat",
                word: "CAT",
                displayTitle: "Cat"
            ),
            SpellQuestPuzzle(
                id: "bus",
                imageName: "spellquest_bus",
                word: "BUS",
                displayTitle: "Bus"
            )
        ]
        
        albums = [
            SpellQuestAlbum(
                id: "starter_pack",
                title: "Starter Pack",
                puzzles: starterPuzzles,
                isInstalled: true,
                difficulty: .easy
            )
        ]
    }
    
    func getInstalledAlbums() -> [SpellQuestAlbum] {
        albums.filter { $0.isInstalled }
    }
    
    func getPuzzlesForMode(_ mode: SpellQuestGameMode, albumIds: Set<String>, difficulty: LettersGameDifficulty) -> [SpellQuestPuzzle] {
        let selectedAlbums = albums.filter { albumIds.contains($0.id) }
        var allPuzzles = selectedAlbums.flatMap { $0.puzzles }
        
        // Filter by difficulty for Zen Junior
        if mode == .zenJunior {
            allPuzzles = allPuzzles.filter { $0.letterCount <= 5 }
        }
        
        // Deterministic shuffle for session
        allPuzzles = deterministicShuffle(allPuzzles, seed: shuffleSeed)
        
        return allPuzzles
    }
    
    func resetShuffleSeed() {
        shuffleSeed = Int.random(in: 0...1000)
    }
    
    private func deterministicShuffle<T>(_ array: [T], seed: Int) -> [T] {
        var rng = SeededRandomNumberGenerator(seed: seed)
        return array.shuffled(using: &rng)
    }
}

// Simple seeded RNG for deterministic shuffling
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(seed)
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
