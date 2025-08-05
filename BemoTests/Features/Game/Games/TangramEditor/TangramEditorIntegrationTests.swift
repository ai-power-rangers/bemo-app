//
//  TangramEditorIntegrationTests.swift
//  BemoTests
//
//  Integration tests for TangramEditor with Bemo architecture
//

import XCTest
@testable import Bemo

class TangramEditorIntegrationTests: XCTestCase {
    
    func testPuzzleCreationAndExport() {
        var puzzle = TangramPuzzle(name: "Test Puzzle", category: "Test", difficulty: .medium)
        
        let piece1 = TangramPiece(type: .smallTriangle1)
        let piece2 = TangramPiece(
            type: .square,
            transform: CGAffineTransform(translationX: 2, y: 0)
        )
        
        puzzle.addPiece(piece1)
        puzzle.addPiece(piece2)
        
        XCTAssertEqual(puzzle.pieces.count, 2)
        XCTAssertNotEqual(puzzle.solutionChecksum, "")
        
        let validation = puzzle.validate()
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errors.contains("All pieces must be connected"))
        
        let exported = puzzle.exportAsSolved()
        XCTAssertEqual(exported.id, puzzle.id)
        XCTAssertEqual(exported.name, puzzle.name)
        XCTAssertEqual(exported.difficulty, puzzle.difficulty.rawValue)
        XCTAssertEqual(exported.solvedPieces.count, 2)
    }
    
    func testConnectionSystemIntegration() {
        let connectionSystem = ConnectionSystem()
        
        let piece1Id = "piece1"
        let piece2Id = "piece2"
        
        connectionSystem.addPiece(
            id: piece1Id,
            type: .smallTriangle1,
            transform: .identity
        )
        
        connectionSystem.addPiece(
            id: piece2Id,
            type: .smallTriangle2,
            transform: CGAffineTransform(translationX: 1, y: 0)
        )
        
        // Verify pieces touch at vertex before connection
        XCTAssertTrue(connectionSystem.hasVertexContact(piece1Id, piece2Id), "Pieces should touch at vertex")
        XCTAssertFalse(connectionSystem.hasAreaOverlap(piece1Id, piece2Id), "Pieces should not have area overlap")
        
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: piece1Id,
            vertexA: 1,
            pieceB: piece2Id,
            vertexB: 0
        )
        
        let connection = connectionSystem.createConnection(type: connectionType)
        XCTAssertNotNil(connection)
        
        // New clear validation API
        XCTAssertTrue(connectionSystem.isConnected(), "All pieces should be connected")
        XCTAssertTrue(connectionSystem.areConnected(piece1Id, piece2Id), "Pieces should have connection")
        XCTAssertFalse(connectionSystem.hasInvalidAreaOverlaps(), "Should have no area overlaps")
        XCTAssertFalse(connectionSystem.hasUnexplainedContacts(), "All contacts should be explained")
        XCTAssertTrue(connectionSystem.isValidAssembly(), "Assembly should be valid")
    }
    
    func testDataModelCodability() throws {
        var puzzle = TangramPuzzle(name: "Codable Test", difficulty: .easy)
        
        let piece = TangramPiece(
            type: .largeTriangle1,
            transform: CGAffineTransform(rotationAngle: .pi / 4)
        )
        puzzle.addPiece(piece)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(puzzle)
        
        let decoder = JSONDecoder()
        let decodedPuzzle = try decoder.decode(TangramPuzzle.self, from: data)
        
        XCTAssertEqual(decodedPuzzle.id, puzzle.id)
        XCTAssertEqual(decodedPuzzle.name, puzzle.name)
        XCTAssertEqual(decodedPuzzle.pieces.count, puzzle.pieces.count)
        XCTAssertEqual(decodedPuzzle.pieces.first?.type, puzzle.pieces.first?.type)
    }
    
    func testPieceTransformations() {
        var piece = TangramPiece(type: .parallelogram)
        let originalVertices = piece.vertices
        
        piece.translate(by: CGVector(dx: 5, dy: 5))
        let translatedVertices = piece.vertices
        
        for (original, translated) in zip(originalVertices, translatedVertices) {
            XCTAssertEqual(translated.x, original.x + 5, accuracy: 0.0001)
            XCTAssertEqual(translated.y, original.y + 5, accuracy: 0.0001)
        }
        
        piece.rotate(by: 90, around: piece.centroid)
        let rotatedCentroid = piece.centroid
        
        XCTAssertEqual(
            GeometryEngine.distance(from: translatedVertices[0], to: rotatedCentroid),
            GeometryEngine.distance(from: piece.vertices[0], to: rotatedCentroid),
            accuracy: 0.0001
        )
    }
    
    func testPuzzleValidation() {
        var puzzle = TangramPuzzle(name: "", difficulty: .beginner)
        
        var validation = puzzle.validate()
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errors.contains("Puzzle name is required"))
        XCTAssertTrue(validation.errors.contains("Puzzle must contain at least one piece"))
        
        puzzle.name = "Valid Puzzle"
        
        for _ in 0..<8 {
            puzzle.addPiece(TangramPiece(type: .smallTriangle1))
        }
        
        validation = puzzle.validate()
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errors.contains("Puzzle cannot contain more than 7 pieces"))
    }
    
    func testSolvedPuzzleExport() {
        var puzzle = TangramPuzzle(name: "Export Test", difficulty: .hard)
        
        let transform1 = CGAffineTransform(translationX: 1, y: 1)
            .rotated(by: .pi / 4)
        let piece1 = TangramPiece(type: .largeTriangle1, transform: transform1)
        
        let transform2 = CGAffineTransform(translationX: 3, y: 2)
        let piece2 = TangramPiece(type: .square, transform: transform2)
        
        puzzle.addPiece(piece1)
        puzzle.addPiece(piece2)
        
        let solved = puzzle.exportAsSolved()
        
        XCTAssertEqual(solved.solvedPieces.count, 2)
        XCTAssertEqual(solved.solvedPieces[0].pieceType, .largeTriangle1)
        XCTAssertEqual(solved.solvedPieces[0].transform, transform1)
        XCTAssertEqual(solved.solvedPieces[1].pieceType, .square)
        XCTAssertEqual(solved.solvedPieces[1].transform, transform2)
    }
    
    // MARK: - Semantic Validation Tests
    
    func testValidVertexConnection() throws {
        let connectionSystem = ConnectionSystem()
        
        // Add two triangles that will connect at a vertex
        connectionSystem.addPiece(
            id: "triangle1",
            type: .smallTriangle1,
            transform: .identity
        )
        
        connectionSystem.addPiece(
            id: "triangle2", 
            type: .smallTriangle2,
            transform: CGAffineTransform(translationX: 1, y: 0) // Share vertex at (1,0)
        )
        
        // Verify geometric relationship before connection
        let relationship = connectionSystem.getGeometricRelationship("triangle1", "triangle2")
        XCTAssertEqual(relationship, .vertexContact, "Pieces should have vertex contact")
        XCTAssertFalse(connectionSystem.hasAreaOverlap("triangle1", "triangle2"), "No area overlap")
        XCTAssertTrue(connectionSystem.hasVertexContact("triangle1", "triangle2"), "Should touch at vertex")
        
        // Before connection: touching without connection is invalid
        XCTAssertTrue(connectionSystem.hasUnexplainedContacts(), "Should have unexplained contact")
        XCTAssertFalse(connectionSystem.isValidAssembly(), "Assembly invalid without connection")
        
        // Create vertex-to-vertex connection
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: "triangle1",
            vertexA: 1, // vertex (1,0)
            pieceB: "triangle2", 
            vertexB: 0  // vertex (1,0) after translation
        )
        
        let connection = connectionSystem.createConnection(type: connectionType)
        XCTAssertNotNil(connection)
        
        // After connection: vertex contact is now valid
        XCTAssertTrue(connectionSystem.areConnected("triangle1", "triangle2"), "Should be connected")
        XCTAssertFalse(connectionSystem.hasUnexplainedContacts(), "Contact now explained")
        XCTAssertFalse(connectionSystem.hasInvalidAreaOverlaps(), "No area overlaps")
        XCTAssertTrue(connectionSystem.isValidAssembly(), "Should be valid assembly")
    }
    
    func testValidEdgeConnection() throws {
        let connectionSystem = ConnectionSystem()
        
        // Add square and triangle that will share an edge
        connectionSystem.addPiece(
            id: "square1",
            type: .square,
            transform: .identity
        )
        
        connectionSystem.addPiece(
            id: "triangle1",
            type: .smallTriangle1,
            transform: CGAffineTransform(translationX: 0, y: 1) // Place above square
        )
        
        // Verify geometric relationship before connection
        let relationship = connectionSystem.getGeometricRelationship("square1", "triangle1")
        XCTAssertEqual(relationship, .edgeContact, "Pieces should have edge contact")
        XCTAssertFalse(connectionSystem.hasAreaOverlap("square1", "triangle1"), "No area overlap")
        XCTAssertTrue(connectionSystem.hasEdgeContact("square1", "triangle1"), "Should share edge")
        
        // Before connection: edge contact without connection is invalid
        XCTAssertTrue(connectionSystem.hasUnexplainedContacts(), "Should have unexplained contact")
        XCTAssertFalse(connectionSystem.isValidAssembly(), "Assembly invalid without connection")
        
        // Create edge-to-edge connection
        let connectionType = ConnectionType.edgeToEdge(
            pieceA: "square1",
            edgeA: 2, // top edge of square (vertices 2→3)
            pieceB: "triangle1",
            edgeB: 0  // bottom edge of triangle (vertices 0→1)
        )
        
        let connection = connectionSystem.createConnection(type: connectionType)
        XCTAssertNotNil(connection)
        
        // After connection: edge contact is now valid
        XCTAssertTrue(connectionSystem.areConnected("square1", "triangle1"), "Should be connected")
        XCTAssertFalse(connectionSystem.hasUnexplainedContacts(), "Contact now explained")
        XCTAssertFalse(connectionSystem.hasInvalidAreaOverlaps(), "No area overlaps")
        XCTAssertTrue(connectionSystem.isValidAssembly(), "Should be valid assembly")
    }
    
    func testInvalidOverlapDetection() throws {
        let connectionSystem = ConnectionSystem()
        
        // Add two overlapping pieces without declaring a connection
        connectionSystem.addPiece(
            id: "triangle1",
            type: .largeTriangle1,
            transform: .identity
        )
        
        connectionSystem.addPiece(
            id: "triangle2",
            type: .largeTriangle2,
            transform: CGAffineTransform(translationX: 0.5, y: 0.5) // Partially overlapping
        )
        
        // Verify geometric relationship
        let relationship = connectionSystem.getGeometricRelationship("triangle1", "triangle2")
        XCTAssertEqual(relationship, .areaOverlap, "Pieces should have area overlap")
        XCTAssertTrue(connectionSystem.hasAreaOverlap("triangle1", "triangle2"), "Should have area overlap")
        
        // Area overlap is always invalid, even with connection
        XCTAssertTrue(connectionSystem.hasInvalidAreaOverlaps(), "Should have invalid area overlaps")
        XCTAssertFalse(connectionSystem.isValidAssembly(), "Should not be valid assembly")
        XCTAssertFalse(connectionSystem.areConnected("triangle1", "triangle2"), "No connection declared")
        
        // Even if we tried to add a connection, area overlap would still be invalid
        // (This is a fundamental rule - pieces cannot overlap in interior)
    }
    
    func testSemanticVsGeometricValidation() throws {
        let connectionSystem = ConnectionSystem()
        
        // Create a scenario where geometric and semantic validation differ
        connectionSystem.addPiece(
            id: "piece1",
            type: .smallTriangle1,
            transform: .identity
        )
        
        connectionSystem.addPiece(
            id: "piece2",
            type: .smallTriangle2,
            transform: CGAffineTransform(translationX: 1, y: 0)
        )
        
        // Before connection: pieces touch at vertex
        let relationship = connectionSystem.getGeometricRelationship("piece1", "piece2")
        XCTAssertEqual(relationship, .vertexContact, "Pieces should touch at vertex")
        XCTAssertTrue(connectionSystem.hasVertexContact("piece1", "piece2"), "Should have vertex contact")
        XCTAssertFalse(connectionSystem.hasAreaOverlap("piece1", "piece2"), "Should have no area overlap")
        
        // Semantic validation: touching without connection is invalid
        XCTAssertTrue(connectionSystem.hasUnexplainedContacts(), "Should have unexplained contact")
        XCTAssertFalse(connectionSystem.isValidAssembly(), "Assembly invalid without connection")
        
        // Create connection to explain the vertex contact
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: "piece1",
            vertexA: 1,
            pieceB: "piece2",
            vertexB: 0
        )
        
        let connection = connectionSystem.createConnection(type: connectionType)
        XCTAssertNotNil(connection)
        
        // After connection: same geometric truth, different semantic validation
        XCTAssertTrue(connectionSystem.hasVertexContact("piece1", "piece2"), "Still has vertex contact")
        XCTAssertFalse(connectionSystem.hasAreaOverlap("piece1", "piece2"), "Still no area overlap")
        XCTAssertTrue(connectionSystem.areConnected("piece1", "piece2"), "Now connected")
        
        // Semantic validation: contact is now explained by connection
        XCTAssertFalse(connectionSystem.hasUnexplainedContacts(), "No unexplained contacts")
        XCTAssertTrue(connectionSystem.isValidAssembly(), "Assembly now valid")
    }
    
    func testMultiPieceAssembly() throws {
        let connectionSystem = ConnectionSystem()
        
        // Create a simple assembly with three pieces
        connectionSystem.addPiece(id: "center", type: .square, transform: .identity)
        connectionSystem.addPiece(id: "top", type: .smallTriangle1, transform: CGAffineTransform(translationX: 0, y: 1))
        connectionSystem.addPiece(id: "right", type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        
        // Verify geometric relationships before connections
        XCTAssertTrue(connectionSystem.hasEdgeContact("center", "top"), "Center and top should share edge")
        XCTAssertTrue(connectionSystem.hasEdgeContact("center", "right"), "Center and right should share edge")
        XCTAssertTrue(connectionSystem.hasVertexContact("top", "right"), "Top and right should share vertex at (1,1)")
        
        // Before connections: contacts are unexplained
        XCTAssertTrue(connectionSystem.hasUnexplainedContacts(), "Should have unexplained contacts")
        XCTAssertFalse(connectionSystem.isValidAssembly(), "Assembly invalid without connections")
        
        // Connect pieces to the center square
        let topConnection = ConnectionType.edgeToEdge(pieceA: "center", edgeA: 2, pieceB: "top", edgeB: 0)
        let rightConnection = ConnectionType.edgeToEdge(pieceA: "center", edgeA: 1, pieceB: "right", edgeB: 2)
        
        XCTAssertNotNil(connectionSystem.createConnection(type: topConnection))
        XCTAssertNotNil(connectionSystem.createConnection(type: rightConnection))
        
        // The top and right triangles also touch at vertex (1,1), so we need a connection there too
        let topRightConnection = ConnectionType.vertexToVertex(pieceA: "top", vertexA: 1, pieceB: "right", vertexB: 2)
        XCTAssertNotNil(connectionSystem.createConnection(type: topRightConnection))
        
        // Verify all connections are established
        XCTAssertTrue(connectionSystem.areConnected("center", "top"), "Center-top connected")
        XCTAssertTrue(connectionSystem.areConnected("center", "right"), "Center-right connected")
        XCTAssertTrue(connectionSystem.areConnected("top", "right"), "Top-right connected")
        
        // All pieces should form a connected graph
        XCTAssertTrue(connectionSystem.isConnected(), "All pieces should be connected")
        
        // Should be a valid assembly with all contacts explained
        XCTAssertFalse(connectionSystem.hasInvalidAreaOverlaps(), "No area overlaps")
        XCTAssertFalse(connectionSystem.hasUnexplainedContacts(), "All contacts explained")
        XCTAssertTrue(connectionSystem.isValidAssembly(), "Should be valid multi-piece assembly")
        
        // Verify each connection is properly satisfied
        XCTAssertTrue(connectionSystem.isOverlapExplainedByConnection("center", "top"))
        XCTAssertTrue(connectionSystem.isOverlapExplainedByConnection("center", "right"))
        XCTAssertTrue(connectionSystem.isOverlapExplainedByConnection("top", "right"))
    }
}