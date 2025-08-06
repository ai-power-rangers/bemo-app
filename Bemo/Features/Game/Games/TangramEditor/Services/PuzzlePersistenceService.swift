//
//  PuzzlePersistenceService.swift
//  Bemo
//
//  Service for saving and loading tangram puzzles to device storage
//

import Foundation

class PuzzlePersistenceService {
    
    private let documentsDirectory: URL
    private let puzzlesDirectory: URL
    private let thumbnailsDirectory: URL
    private let thumbnailGenerator = ThumbnailGenerator()
    
    init() {
        // Get documents directory
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                      in: .userDomainMask)[0]
        puzzlesDirectory = documentsDirectory.appendingPathComponent("TangramPuzzles")
        thumbnailsDirectory = puzzlesDirectory.appendingPathComponent("thumbnails")
        
        // Create directories if needed
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: puzzlesDirectory, 
                                                 withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, 
                                                 withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    func savePuzzle(_ puzzle: TangramPuzzle) async throws -> TangramPuzzle {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        var updatedPuzzle = puzzle
        
        // Generate and save thumbnail
        if let thumbnailData = await thumbnailGenerator.generateThumbnail(for: puzzle) {
            try saveThumbnail(thumbnailData, for: puzzle.id)
            updatedPuzzle.thumbnailData = thumbnailData
        }
        
        // Save puzzle to file
        let data = try encoder.encode(updatedPuzzle)
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(updatedPuzzle.id).json")
        try data.write(to: fileURL)
        
        // Update index
        try await updatePuzzleIndex(updatedPuzzle)
        
        return updatedPuzzle
    }
    
    func loadPuzzle(id: String) async throws -> TangramPuzzle {
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(id).json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(TangramPuzzle.self, from: data)
    }
    
    func deletePuzzle(id: String) async throws {
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(id).json")
        try FileManager.default.removeItem(at: fileURL)
        
        let thumbURL = thumbnailsDirectory.appendingPathComponent("thumb_\(id).png")
        try? FileManager.default.removeItem(at: thumbURL)
        
        try await removeFromIndex(id: id)
    }
    
    func listPuzzles() async throws -> [PuzzleMetadata] {
        let indexURL = puzzlesDirectory.appendingPathComponent("puzzles.index")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode([PuzzleMetadata].self, from: data)
    }
    
    func puzzleExists(id: String) -> Bool {
        let fileURL = puzzlesDirectory.appendingPathComponent("puzzle_\(id).json")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Private Methods
    
    private func updatePuzzleIndex(_ puzzle: TangramPuzzle) async throws {
        var index = (try? await listPuzzles()) ?? []
        
        let metadata = PuzzleMetadata(
            id: puzzle.id,
            name: puzzle.name,
            category: puzzle.category,
            difficulty: puzzle.difficulty,
            createdDate: puzzle.createdDate,
            modifiedDate: puzzle.modifiedDate,
            pieceCount: puzzle.pieces.count
        )
        
        // Update or append
        if let existingIndex = index.firstIndex(where: { $0.id == puzzle.id }) {
            index[existingIndex] = metadata
        } else {
            index.append(metadata)
        }
        
        // Save index
        let indexURL = puzzlesDirectory.appendingPathComponent("puzzles.index")
        let data = try JSONEncoder().encode(index)
        try data.write(to: indexURL)
    }
    
    private func removeFromIndex(id: String) async throws {
        var index = (try? await listPuzzles()) ?? []
        index.removeAll { $0.id == id }
        
        let indexURL = puzzlesDirectory.appendingPathComponent("puzzles.index")
        let data = try JSONEncoder().encode(index)
        try data.write(to: indexURL)
    }
    
    func loadAllPuzzles() async throws -> [TangramPuzzle] {
        let puzzles = try await listPuzzles()
        var loadedPuzzles: [TangramPuzzle] = []
        
        for metadata in puzzles {
            if let puzzle = try? await loadPuzzle(id: metadata.id) {
                loadedPuzzles.append(puzzle)
            }
        }
        
        return loadedPuzzles
    }
    
    // MARK: - Thumbnail Support
    
    func saveThumbnail(_ data: Data, for puzzleId: String) throws {
        let thumbURL = thumbnailsDirectory.appendingPathComponent("thumb_\(puzzleId).png")
        try data.write(to: thumbURL)
    }
    
    func loadThumbnail(for puzzleId: String) -> Data? {
        let thumbURL = thumbnailsDirectory.appendingPathComponent("thumb_\(puzzleId).png")
        return try? Data(contentsOf: thumbURL)
    }
}

// MARK: - Supporting Types

// PuzzleMetadata moved to Models/TangramPuzzleData.swift