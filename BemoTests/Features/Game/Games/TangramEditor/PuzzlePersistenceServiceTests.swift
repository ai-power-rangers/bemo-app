//
//  PuzzlePersistenceServiceTests.swift
//  BemoTests
//
//  Comprehensive unit tests for PuzzlePersistenceService
//

import XCTest
@testable import Bemo

@MainActor
class PuzzlePersistenceServiceTests: XCTestCase {
    
    var persistenceService: PuzzlePersistenceService!
    var testPuzzle: TangramPuzzle!
    
    override func setUp() async throws {
        try await super.setUp()
        persistenceService = PuzzlePersistenceService()
        
        // Create a test puzzle
        testPuzzle = TangramPuzzle(
            name: "Test Puzzle",
            category: .geometric,
            difficulty: .medium
        )
        testPuzzle.pieces = [
            TangramPiece(type: .smallTriangle1, transform: .identity),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 2, y: 0))
        ]
        testPuzzle.connections = [
            Connection(
                type: .vertexToVertex(
                    pieceA: testPuzzle.pieces[0].id,
                    vertexA: 1,
                    pieceB: testPuzzle.pieces[1].id,
                    vertexB: 0
                ),
                constraint: Constraint(type: .fixed, affectedPieceId: testPuzzle.pieces[1].id)
            )
        ]
    }
    
    override func tearDown() async throws {
        // Clean up test files
        if let puzzle = testPuzzle {
            try? await persistenceService.deletePuzzle(id: puzzle.id)
        }
        try await super.tearDown()
    }
    
    // MARK: - Save and Load Tests
    
    func testSavePuzzle() async throws {
        try await persistenceService.savePuzzle(testPuzzle)
        
        XCTAssertTrue(persistenceService.puzzleExists(id: testPuzzle.id),
                     "Puzzle should exist after saving")
        
        // Verify saved puzzles list is updated
        XCTAssertTrue(persistenceService.savedPuzzles.contains { $0.id == testPuzzle.id },
                     "Saved puzzles list should contain the puzzle")
    }
    
    func testLoadPuzzle() async throws {
        // First save the puzzle
        try await persistenceService.savePuzzle(testPuzzle)
        
        // Load it back
        let loadedPuzzle = try await persistenceService.loadPuzzle(id: testPuzzle.id)
        
        XCTAssertEqual(loadedPuzzle.id, testPuzzle.id)
        XCTAssertEqual(loadedPuzzle.name, testPuzzle.name)
        XCTAssertEqual(loadedPuzzle.category, testPuzzle.category)
        XCTAssertEqual(loadedPuzzle.difficulty, testPuzzle.difficulty)
        XCTAssertEqual(loadedPuzzle.pieces.count, testPuzzle.pieces.count)
        XCTAssertEqual(loadedPuzzle.connections.count, testPuzzle.connections.count)
    }
    
    func testDeletePuzzle() async throws {
        // Save puzzle first
        try await persistenceService.savePuzzle(testPuzzle)
        XCTAssertTrue(persistenceService.puzzleExists(id: testPuzzle.id))
        
        // Delete it
        try await persistenceService.deletePuzzle(id: testPuzzle.id)
        
        XCTAssertFalse(persistenceService.puzzleExists(id: testPuzzle.id),
                      "Puzzle should not exist after deletion")
        
        XCTAssertFalse(persistenceService.savedPuzzles.contains { $0.id == testPuzzle.id },
                      "Saved puzzles list should not contain deleted puzzle")
    }
    
    func testUpdateExistingPuzzle() async throws {
        // Save initial puzzle
        try await persistenceService.savePuzzle(testPuzzle)
        
        // Modify and save again
        testPuzzle.name = "Updated Test Puzzle"
        testPuzzle.difficulty = .hard
        try await persistenceService.savePuzzle(testPuzzle)
        
        // Load and verify updates
        let loadedPuzzle = try await persistenceService.loadPuzzle(id: testPuzzle.id)
        XCTAssertEqual(loadedPuzzle.name, "Updated Test Puzzle")
        XCTAssertEqual(loadedPuzzle.difficulty, .hard)
        
        // Should not create duplicate in index
        let puzzleCount = persistenceService.savedPuzzles.filter { $0.id == testPuzzle.id }.count
        XCTAssertEqual(puzzleCount, 1, "Should not create duplicate puzzles")
    }
    
    // MARK: - Puzzle Index Tests
    
    func testListPuzzles() async throws {
        // Save multiple puzzles
        let puzzle1 = TangramPuzzle(name: "Puzzle 1", category: .animals, difficulty: .easy)
        let puzzle2 = TangramPuzzle(name: "Puzzle 2", category: .objects, difficulty: .hard)
        
        try await persistenceService.savePuzzle(puzzle1)
        try await persistenceService.savePuzzle(puzzle2)
        
        let puzzleList = try await persistenceService.listPuzzles()
        
        XCTAssertTrue(puzzleList.contains { $0.id == puzzle1.id })
        XCTAssertTrue(puzzleList.contains { $0.id == puzzle2.id })
        
        // Clean up
        try await persistenceService.deletePuzzle(id: puzzle1.id)
        try await persistenceService.deletePuzzle(id: puzzle2.id)
    }
    
    func testPuzzleMetadata() async throws {
        try await persistenceService.savePuzzle(testPuzzle)
        
        let metadata = try await persistenceService.listPuzzles()
        guard let puzzleMeta = metadata.first(where: { $0.id == testPuzzle.id }) else {
            XCTFail("Should find puzzle metadata")
            return
        }
        
        XCTAssertEqual(puzzleMeta.name, testPuzzle.name)
        XCTAssertEqual(puzzleMeta.category, testPuzzle.category)
        XCTAssertEqual(puzzleMeta.difficulty, testPuzzle.difficulty)
        XCTAssertEqual(puzzleMeta.pieceCount, testPuzzle.pieces.count)
    }
    
    // MARK: - Thumbnail Tests
    
    func testThumbnailGeneration() async throws {
        // Save puzzle (should generate thumbnail)
        try await persistenceService.savePuzzle(testPuzzle)
        
        // Load thumbnail
        let thumbnailData = persistenceService.loadThumbnail(for: testPuzzle.id)
        XCTAssertNotNil(thumbnailData, "Should have generated thumbnail")
        
        // Verify it's valid image data
        if let data = thumbnailData {
            let image = UIImage(data: data)
            XCTAssertNotNil(image, "Thumbnail data should be valid image")
        }
    }
    
    func testThumbnailDeletion() async throws {
        try await persistenceService.savePuzzle(testPuzzle)
        
        // Verify thumbnail exists
        XCTAssertNotNil(persistenceService.loadThumbnail(for: testPuzzle.id))
        
        // Delete puzzle
        try await persistenceService.deletePuzzle(id: testPuzzle.id)
        
        // Thumbnail should be deleted too
        XCTAssertNil(persistenceService.loadThumbnail(for: testPuzzle.id),
                    "Thumbnail should be deleted with puzzle")
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadNonExistentPuzzle() async {
        do {
            _ = try await persistenceService.loadPuzzle(id: "non-existent-id")
            XCTFail("Should throw error for non-existent puzzle")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    func testDeleteNonExistentPuzzle() async {
        do {
            try await persistenceService.deletePuzzle(id: "non-existent-id")
            // Might succeed silently or throw - both are acceptable
        } catch {
            // Error is acceptable for non-existent puzzle
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - File System Tests
    
    func testDirectoryCreation() {
        // Directories should be created on init
        let fm = FileManager.default
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let puzzlesURL = documentsURL.appendingPathComponent("TangramPuzzles")
        let thumbnailsURL = puzzlesURL.appendingPathComponent("thumbnails")
        
        XCTAssertTrue(fm.fileExists(atPath: puzzlesURL.path),
                     "Puzzles directory should exist")
        XCTAssertTrue(fm.fileExists(atPath: thumbnailsURL.path),
                     "Thumbnails directory should exist")
    }
    
    func testPuzzleFileFormat() async throws {
        try await persistenceService.savePuzzle(testPuzzle)
        
        // Read raw file
        let fm = FileManager.default
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL
            .appendingPathComponent("TangramPuzzles")
            .appendingPathComponent("puzzle_\(testPuzzle.id).json")
        
        let data = try Data(contentsOf: fileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["id"] as? String, testPuzzle.id)
        XCTAssertEqual(json?["name"] as? String, testPuzzle.name)
        XCTAssertNotNil(json?["pieces"])
        XCTAssertNotNil(json?["connections"])
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSaves() async throws {
        // Create multiple puzzles
        let puzzles = (0..<5).map { i in
            TangramPuzzle(name: "Concurrent \(i)", category: .custom, difficulty: .easy)
        }
        
        // Save them concurrently
        await withTaskGroup(of: Void.self) { group in
            for puzzle in puzzles {
                group.addTask {
                    try? await self.persistenceService.savePuzzle(puzzle)
                }
            }
        }
        
        // Verify all were saved
        for puzzle in puzzles {
            XCTAssertTrue(persistenceService.puzzleExists(id: puzzle.id),
                         "All puzzles should be saved")
        }
        
        // Clean up
        for puzzle in puzzles {
            try? await persistenceService.deletePuzzle(id: puzzle.id)
        }
    }
    
    // MARK: - Data Migration Tests
    
    func testLoadPuzzleWithMissingThumbnail() async throws {
        // Save puzzle
        try await persistenceService.savePuzzle(testPuzzle)
        
        // Manually delete thumbnail
        let fm = FileManager.default
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let thumbURL = documentsURL
            .appendingPathComponent("TangramPuzzles")
            .appendingPathComponent("thumbnails")
            .appendingPathComponent("thumb_\(testPuzzle.id).png")
        try? fm.removeItem(at: thumbURL)
        
        // Should still load puzzle successfully
        let loadedPuzzle = try await persistenceService.loadPuzzle(id: testPuzzle.id)
        XCTAssertNotNil(loadedPuzzle)
        XCTAssertNil(persistenceService.loadThumbnail(for: testPuzzle.id),
                    "Thumbnail should be nil")
    }
    
    func testEmptyPuzzleIndex() async throws {
        // Start with fresh service
        let freshService = PuzzlePersistenceService()
        
        // Should return empty list, not crash
        let puzzles = try await freshService.listPuzzles()
        XCTAssertEqual(puzzles.count, 0, "Should return empty list for fresh service")
    }
    
    // MARK: - Large Data Tests
    
    func testLargePuzzle() async throws {
        // Create puzzle with all 7 pieces
        var largePuzzle = TangramPuzzle(name: "Large Puzzle", category: .custom, difficulty: .hard)
        largePuzzle.pieces = [
            TangramPiece(type: .smallTriangle1, transform: .identity),
            TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0)),
            TangramPiece(type: .mediumTriangle, transform: CGAffineTransform(translationX: 2, y: 0)),
            TangramPiece(type: .largeTriangle1, transform: CGAffineTransform(translationX: 3, y: 0)),
            TangramPiece(type: .largeTriangle2, transform: CGAffineTransform(translationX: 4, y: 0)),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 5, y: 0)),
            TangramPiece(type: .parallelogram, transform: CGAffineTransform(translationX: 6, y: 0))
        ]
        
        // Add multiple connections
        for i in 0..<6 {
            largePuzzle.connections.append(
                Connection(
                    type: .edgeToEdge(
                        pieceA: largePuzzle.pieces[i].id,
                        edgeA: 1,
                        pieceB: largePuzzle.pieces[i+1].id,
                        edgeB: 3
                    ),
                    constraint: Constraint(type: .fixed, affectedPieceId: largePuzzle.pieces[i+1].id)
                )
            )
        }
        
        try await persistenceService.savePuzzle(largePuzzle)
        let loaded = try await persistenceService.loadPuzzle(id: largePuzzle.id)
        
        XCTAssertEqual(loaded.pieces.count, 7)
        XCTAssertEqual(loaded.connections.count, 6)
        
        // Clean up
        try await persistenceService.deletePuzzle(id: largePuzzle.id)
    }
}