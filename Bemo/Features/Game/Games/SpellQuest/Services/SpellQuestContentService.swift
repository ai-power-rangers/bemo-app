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
typealias SpellQuestDifficulty = SpellQuestAlbum.DifficultyLevel

@Observable
class SpellQuestContentService {
    private(set) var albums: [SpellQuestAlbum] = []
    private var shuffleSeed: Int = Int.random(in: 0...1000)
    private let supabaseService: SupabaseService?
    private let cacheURL: URL
    
    init(supabaseService: SupabaseService? = nil) {
        self.supabaseService = supabaseService
        
        // Setup cache directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spellQuestDir = appSupport.appendingPathComponent("SpellQuest", isDirectory: true)
        try? FileManager.default.createDirectory(at: spellQuestDir, withIntermediateDirectories: true)
        self.cacheURL = spellQuestDir.appendingPathComponent("albums.json")
        
        // Try loading from cache first, then fall back to local
        if !loadCachedContent() {
            loadLocalContent()
        }
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
    
    // MARK: - Remote Content
    
    func refreshFromRemote(selectedAlbumSlugs: Set<String>? = nil) async {
        guard let supabase = supabaseService else {
            print("[SpellQuestContent] No Supabase service available, using local content")
            return
        }
        
        print("[SpellQuestContent] Starting remote content fetch...")
        
        do {
            // Fetch albums
            let albumDTOs = try await supabase.fetchSpellQuestAlbums()
            print("[SpellQuestContent] Fetched \(albumDTOs.count) albums from Supabase")
            
            // Filter by selected slugs if provided
            let filteredAlbums = selectedAlbumSlugs != nil
                ? albumDTOs.filter { selectedAlbumSlugs!.contains($0.album_id) }
                : albumDTOs
            
            print("[SpellQuestContent] After filtering: \(filteredAlbums.count) albums")
            
            // Get album UUIDs for puzzle fetch
            let albumUUIDs = filteredAlbums.map { $0.id }
            
            // Fetch puzzles for these albums
            let puzzleDTOs = try await supabase.fetchSpellQuestPuzzles(albumUUIDs: albumUUIDs)
            print("[SpellQuestContent] Fetched \(puzzleDTOs.count) puzzles from Supabase")
            
            // Group puzzles by album
            let puzzlesByAlbum = Dictionary(grouping: puzzleDTOs) { $0.album_id }
            
            // Map to domain models
            let remoteAlbums = filteredAlbums.compactMap { albumDTO -> SpellQuestAlbum? in
                let puzzles = puzzlesByAlbum[albumDTO.id] ?? []
                let mappedPuzzles = puzzles.compactMap { puzzleDTO -> SpellQuestPuzzle? in
                    // Try to get remote image URL
                    let imageURLOrAsset: String
                    if let url = try? supabase.getSpellQuestImagePublicURL(path: puzzleDTO.image_path) {
                        imageURLOrAsset = url
                    } else {
                        // Fall back to asset name
                        imageURLOrAsset = puzzleDTO.image_path
                    }
                    
                    return SpellQuestPuzzle(
                        id: puzzleDTO.puzzle_id,
                        imageName: imageURLOrAsset,
                        word: puzzleDTO.word,
                        displayTitle: puzzleDTO.display_title ?? puzzleDTO.word.capitalized
                    )
                }
                
                // Skip albums with no puzzles
                guard !mappedPuzzles.isEmpty else { return nil }
                
                return SpellQuestAlbum(
                    id: albumDTO.album_id,
                    title: albumDTO.title,
                    puzzles: mappedPuzzles,
                    isInstalled: true,
                    difficulty: mapSpellQuestDifficulty(albumDTO.difficulty)
                )
            }
            
            // Update albums on main thread
            await MainActor.run {
                if !remoteAlbums.isEmpty {
                    print("[SpellQuestContent] Updating albums with \(remoteAlbums.count) remote albums")
                    self.albums = remoteAlbums
                    self.saveToCache()
                } else {
                    print("[SpellQuestContent] No remote albums found, keeping local content")
                }
            }
            
        } catch {
            print("[SpellQuestContent] Failed to fetch remote content: \(error)")
            print("[SpellQuestContent] Error details: \(error.localizedDescription)")
            // Keep existing content on error
        }
    }
    
    private func mapSpellQuestDifficulty(_ value: Int) -> SpellQuestDifficulty {
        switch value {
        case 1: return .easy
        case 2: return .normal
        case 3: return .hard
        default: return .easy
        }
    }
    
    // MARK: - Caching
    
    private func loadCachedContent() -> Bool {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let cached = try JSONDecoder().decode(CachedAlbums.self, from: data)
            self.albums = cached.albums.map { $0.toSpellQuestAlbum() }
            return !albums.isEmpty
        } catch {
            print("[SpellQuestContent] Failed to load cache: \(error)")
            return false
        }
    }
    
    private func saveToCache() {
        let cached = CachedAlbums(
            albums: albums.map { CachedAlbum(from: $0) },
            timestamp: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(cached)
            try data.write(to: cacheURL)
        } catch {
            print("[SpellQuestContent] Failed to save cache: \(error)")
        }
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

// MARK: - Cache Models

private struct CachedAlbums: Codable {
    let albums: [CachedAlbum]
    let timestamp: Date
}

private struct CachedAlbum: Codable {
    let id: String
    let title: String
    let puzzles: [CachedPuzzle]
    let difficulty: String  // Store as string for the enum
    
    init(from album: SpellQuestAlbum) {
        self.id = album.id
        self.title = album.title
        self.puzzles = album.puzzles.map { CachedPuzzle(from: $0) }
        self.difficulty = album.difficulty.rawValue  // This is already a string
    }
    
    func toSpellQuestAlbum() -> SpellQuestAlbum {
        SpellQuestAlbum(
            id: id,
            title: title,
            puzzles: puzzles.map { $0.toSpellQuestPuzzle() },
            isInstalled: true,
            difficulty: SpellQuestAlbum.DifficultyLevel(rawValue: difficulty) ?? .easy
        )
    }
}

private struct CachedPuzzle: Codable {
    let id: String
    let imageName: String
    let word: String
    let displayTitle: String
    
    init(from puzzle: SpellQuestPuzzle) {
        self.id = puzzle.id
        self.imageName = puzzle.imageName
        self.word = puzzle.word
        self.displayTitle = puzzle.displayTitle ?? puzzle.word.capitalized
    }
    
    func toSpellQuestPuzzle() -> SpellQuestPuzzle {
        SpellQuestPuzzle(
            id: id,
            imageName: imageName,
            word: word,
            displayTitle: displayTitle
        )
    }
}
