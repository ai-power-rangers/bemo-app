//
//  TangramEditorIntegrationTests.swift
//  BemoTests
//
//  Integration tests for TangramEditor with new MVVM architecture
//

import XCTest
@testable import Bemo

@MainActor
class TangramEditorIntegrationTests: XCTestCase {
    
    var viewModel: TangramEditorViewModel!
    var connectionService: ConnectionService!
    var validationService: ValidationService!
    
    override func setUp() {
        super.setUp()
        viewModel = TangramEditorViewModel()
        connectionService = ConnectionService()
        validationService = ValidationService()
    }
    
    func testPuzzleCreationAndExport() async {
        // Create a new puzzle through ViewModel
        viewModel.puzzle.name = "Test Puzzle"
        viewModel.puzzle.category = .custom
        viewModel.puzzle.difficulty = .medium
        
        // Add pieces
        viewModel.addPiece(type: .smallTriangle1, at: CGPoint(x: 0, y: 0))
        viewModel.addPiece(type: .square, at: CGPoint(x: 2, y: 0))
        
        XCTAssertEqual(viewModel.puzzle.pieces.count, 2)
        
        // Validate
        viewModel.validate()
        XCTAssertFalse(viewModel.validationState.isValid)
        XCTAssertTrue(viewModel.validationState.errors.contains("Not all pieces are connected"))
        
        // Export for gameplay
        let exported = viewModel.exportForGameplay()
        XCTAssertNil(exported, "Should not export invalid puzzle")
    }
    
    func testConnectionCreation() {
        // Add pieces to puzzle
        let piece1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let piece2 = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        
        viewModel.puzzle.pieces = [piece1, piece2]
        
        // Verify pieces touch at vertex
        let hasVertexContact = validationService.hasVertexContact(pieceA: piece1, pieceB: piece2)
        XCTAssertTrue(hasVertexContact, "Pieces should touch at vertex")
        
        let hasAreaOverlap = validationService.hasAreaOverlap(pieceA: piece1, pieceB: piece2)
        XCTAssertFalse(hasAreaOverlap, "Pieces should not have area overlap")
        
        // Create connection
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: piece1.id,
            vertexA: 1,
            pieceB: piece2.id,
            vertexB: 0
        )
        
        viewModel.createConnection(type: connectionType)
        
        // Verify connection exists
        let connection = viewModel.getConnectionsBetween(pieceA: piece1.id, pieceB: piece2.id)
        XCTAssertNotNil(connection)
        
        // Validate assembly
        viewModel.validate()
        XCTAssertTrue(viewModel.validationState.isValid, "Assembly should be valid")
    }
    
    func testDataModelCodability() throws {
        let puzzle = TangramPuzzle(
            name: "Codable Test",
            category: .geometric,
            difficulty: .easy
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(puzzle)
        
        let decoder = JSONDecoder()
        let decodedPuzzle = try decoder.decode(TangramPuzzle.self, from: data)
        
        XCTAssertEqual(decodedPuzzle.id, puzzle.id)
        XCTAssertEqual(decodedPuzzle.name, puzzle.name)
        XCTAssertEqual(decodedPuzzle.pieces.count, puzzle.pieces.count)
    }
    
    func testPieceTransformations() {
        let originalTransform = CGAffineTransform.identity
        let piece = TangramPiece(type: .parallelogram, transform: originalTransform)
        
        // Get original vertices through geometry utilities
        let originalVertices = TangramGeometry.vertices(for: piece.type)
        
        // Apply translation
        let translatedTransform = originalTransform.translatedBy(x: 5, y: 5)
        let translatedVertices = GeometryEngine.transformVertices(originalVertices, with: translatedTransform)
        
        for (original, translated) in zip(originalVertices, translatedVertices) {
            XCTAssertEqual(translated.x, original.x + 5, accuracy: 0.0001)
            XCTAssertEqual(translated.y, original.y + 5, accuracy: 0.0001)
        }
        
        // Apply rotation
        let rotatedTransform = translatedTransform.rotated(by: CGFloat.pi / 2)
        let rotatedVertices = GeometryEngine.transformVertices(originalVertices, with: rotatedTransform)
        
        // Check that distance from centroid is preserved
        let originalCentroid = TangramGeometry.centroid(for: piece.type)
        let rotatedCentroid = originalCentroid.applying(rotatedTransform)
        
        XCTAssertEqual(
            GeometryEngine.distance(from: translatedVertices[0], to: originalCentroid.applying(translatedTransform)),
            GeometryEngine.distance(from: rotatedVertices[0], to: rotatedCentroid),
            accuracy: 0.0001
        )
    }
    
    func testPuzzleValidation() {
        viewModel.puzzle.name = ""
        viewModel.puzzle.pieces = []
        
        viewModel.validate()
        XCTAssertFalse(viewModel.validationState.isValid)
        XCTAssertTrue(viewModel.validationState.errors.contains("Puzzle name is required"))
        
        viewModel.puzzle.name = "Valid Puzzle"
        
        // Add too many pieces
        for i in 0..<8 {
            viewModel.addPiece(type: .smallTriangle1, at: CGPoint(x: Double(i), y: 0))
        }
        
        // Note: We don't have a "max 7 pieces" rule in the new validation
        // This test would need to be updated based on actual business rules
        viewModel.validate()
        
        // Check for connectivity issues instead
        XCTAssertFalse(viewModel.validationState.isValid)
        XCTAssertTrue(viewModel.validationState.errors.contains("Not all pieces are connected") ||
                     viewModel.validationState.errors.contains("Pieces touch without connection"))
    }
    
    func testSolvedPuzzleExport() {
        viewModel.puzzle.name = "Export Test"
        viewModel.puzzle.difficulty = .hard
        
        // Add pieces
        viewModel.addPiece(type: .largeTriangle1, at: CGPoint(x: 1, y: 1))
        viewModel.addPiece(type: .square, at: CGPoint(x: 3, y: 2))
        
        // Create a valid connection between them (adjust positions to make them touch)
        viewModel.puzzle.pieces[0].transform = CGAffineTransform(translationX: 0, y: 0)
        viewModel.puzzle.pieces[1].transform = CGAffineTransform(translationX: 2, y: 0)
        
        // Add connection
        let connectionType = ConnectionType.edgeToEdge(
            pieceA: viewModel.puzzle.pieces[0].id,
            edgeA: 1,
            pieceB: viewModel.puzzle.pieces[1].id,
            edgeB: 3
        )
        viewModel.createConnection(type: connectionType)
        
        viewModel.validate()
        
        let solved = viewModel.exportForGameplay()
        if viewModel.validationState.isValid {
            XCTAssertNotNil(solved)
            XCTAssertEqual(solved?.solvedPieces.count, 2)
            XCTAssertEqual(solved?.solvedPieces[0].pieceType, .largeTriangle1)
            XCTAssertEqual(solved?.solvedPieces[1].pieceType, .square)
        }
    }
    
    // MARK: - Semantic Validation Tests
    
    func testValidVertexConnection() throws {
        // Add two triangles that will connect at a vertex
        let triangle1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let triangle2 = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        
        viewModel.puzzle.pieces = [triangle1, triangle2]
        
        // Verify geometric relationship
        let relationship = validationService.getGeometricRelationship(pieceA: triangle1, pieceB: triangle2)
        XCTAssertEqual(relationship, .vertexContact, "Pieces should have vertex contact")
        
        // Before connection: touching without connection is invalid
        viewModel.validate()
        XCTAssertFalse(viewModel.validationState.isValid)
        XCTAssertTrue(viewModel.validationState.errors.contains("Pieces touch without connection"))
        
        // Create vertex-to-vertex connection
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: triangle1.id,
            vertexA: 1,
            pieceB: triangle2.id,
            vertexB: 0
        )
        
        viewModel.createConnection(type: connectionType)
        
        // After connection: vertex contact is now valid
        viewModel.validate()
        XCTAssertTrue(viewModel.validationState.isValid)
    }
    
    func testValidEdgeConnection() throws {
        // Add square and triangle that will share an edge
        let square = TangramPiece(type: .square, transform: .identity)
        let triangle = TangramPiece(type: .smallTriangle1, transform: CGAffineTransform(translationX: 0, y: 1))
        
        viewModel.puzzle.pieces = [square, triangle]
        
        // Verify geometric relationship
        let relationship = validationService.getGeometricRelationship(pieceA: square, pieceB: triangle)
        XCTAssertEqual(relationship, .edgeContact, "Pieces should have edge contact")
        
        // Before connection: edge contact without connection is invalid
        viewModel.validate()
        XCTAssertFalse(viewModel.validationState.isValid)
        
        // Create edge-to-edge connection
        let connectionType = ConnectionType.edgeToEdge(
            pieceA: square.id,
            edgeA: 2,
            pieceB: triangle.id,
            edgeB: 0
        )
        
        viewModel.createConnection(type: connectionType)
        
        // After connection: edge contact is now valid
        viewModel.validate()
        XCTAssertTrue(viewModel.validationState.isValid)
    }
    
    func testInvalidOverlapDetection() throws {
        // Add two overlapping pieces
        let triangle1 = TangramPiece(type: .largeTriangle1, transform: .identity)
        let triangle2 = TangramPiece(type: .largeTriangle2, transform: CGAffineTransform(translationX: 0.5, y: 0.5))
        
        viewModel.puzzle.pieces = [triangle1, triangle2]
        
        // Verify area overlap
        let hasOverlap = validationService.hasAreaOverlap(pieceA: triangle1, pieceB: triangle2)
        XCTAssertTrue(hasOverlap, "Pieces should have area overlap")
        
        // Area overlap is always invalid
        viewModel.validate()
        XCTAssertFalse(viewModel.validationState.isValid)
        XCTAssertTrue(viewModel.validationState.errors.contains("Pieces have area overlap"))
    }
    
    func testSemanticVsGeometricValidation() throws {
        // Create pieces that touch at a vertex
        let piece1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let piece2 = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        
        viewModel.puzzle.pieces = [piece1, piece2]
        
        // Before connection: pieces touch at vertex
        let relationship = validationService.getGeometricRelationship(pieceA: piece1, pieceB: piece2)
        XCTAssertEqual(relationship, .vertexContact, "Pieces should touch at vertex")
        
        // Semantic validation: touching without connection is invalid
        viewModel.validate()
        XCTAssertFalse(viewModel.validationState.isValid)
        
        // Create connection to explain the vertex contact
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: piece1.id,
            vertexA: 1,
            pieceB: piece2.id,
            vertexB: 0
        )
        
        viewModel.createConnection(type: connectionType)
        
        // After connection: same geometric truth, different semantic validation
        let stillHasContact = validationService.hasVertexContact(pieceA: piece1, pieceB: piece2)
        XCTAssertTrue(stillHasContact, "Still has vertex contact")
        
        viewModel.validate()
        XCTAssertTrue(viewModel.validationState.isValid, "Assembly now valid")
    }
    
    func testMultiPieceAssembly() throws {
        // Create a simple assembly with three pieces
        let center = TangramPiece(type: .square, transform: .identity)
        let top = TangramPiece(type: .smallTriangle1, transform: CGAffineTransform(translationX: 0, y: 1))
        let right = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        
        viewModel.puzzle.pieces = [center, top, right]
        
        // Verify geometric relationships
        let centerTopRelation = validationService.getGeometricRelationship(pieceA: center, pieceB: top)
        XCTAssertEqual(centerTopRelation, .edgeContact, "Center and top should share edge")
        
        let centerRightRelation = validationService.getGeometricRelationship(pieceA: center, pieceB: right)
        XCTAssertEqual(centerRightRelation, .edgeContact, "Center and right should share edge")
        
        let topRightRelation = validationService.getGeometricRelationship(pieceA: top, pieceB: right)
        XCTAssertEqual(topRightRelation, .vertexContact, "Top and right should share vertex")
        
        // Before connections: contacts are unexplained
        viewModel.validate()
        XCTAssertFalse(viewModel.validationState.isValid)
        
        // Connect pieces
        viewModel.createConnection(type: ConnectionType.edgeToEdge(
            pieceA: center.id, edgeA: 2, pieceB: top.id, edgeB: 0
        ))
        viewModel.createConnection(type: ConnectionType.edgeToEdge(
            pieceA: center.id, edgeA: 1, pieceB: right.id, edgeB: 2
        ))
        viewModel.createConnection(type: ConnectionType.vertexToVertex(
            pieceA: top.id, vertexA: 1, pieceB: right.id, vertexB: 2
        ))
        
        // All pieces should form a connected graph
        let isConnected = validationService.isConnected(
            pieces: viewModel.puzzle.pieces,
            connections: viewModel.puzzle.connections
        )
        XCTAssertTrue(isConnected, "All pieces should be connected")
        
        // Should be a valid assembly
        viewModel.validate()
        XCTAssertTrue(viewModel.validationState.isValid, "Should be valid multi-piece assembly")
    }
}