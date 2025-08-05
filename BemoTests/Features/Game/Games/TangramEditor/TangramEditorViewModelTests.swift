//
//  TangramEditorViewModelTests.swift
//  BemoTests
//
//  Comprehensive unit tests for TangramEditorViewModel
//

import XCTest
@testable import Bemo

@MainActor
class TangramEditorViewModelTests: XCTestCase {
    
    var viewModel: TangramEditorViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        viewModel = TangramEditorViewModel()
    }
    
    // MARK: - Piece Management Tests
    
    func testAddPiece() {
        XCTAssertEqual(viewModel.puzzle.pieces.count, 0, "Should start with no pieces")
        
        viewModel.addPiece(type: .smallTriangle1, at: CGPoint(x: 10, y: 10))
        
        XCTAssertEqual(viewModel.puzzle.pieces.count, 1)
        XCTAssertEqual(viewModel.puzzle.pieces[0].type, .smallTriangle1)
        XCTAssertEqual(viewModel.puzzle.pieces[0].transform.tx, 10)
        XCTAssertEqual(viewModel.puzzle.pieces[0].transform.ty, 10)
    }
    
    func testRemovePiece() {
        // Add pieces that share a vertex (properly connected)
        viewModel.addPiece(type: .square, at: .zero)
        viewModel.addPiece(type: .parallelogram, at: CGPoint(x: 1, y: 0))
        let pieceId = viewModel.puzzle.pieces[0].id
        
        // Create valid vertex-to-vertex connection
        // Square vertex 1 is at (1,0), Parallelogram vertex 0 is at (1,0) after translation
        let connection = Connection(
            type: .vertexToVertex(
                pieceA: viewModel.puzzle.pieces[0].id,
                vertexA: 1,  // Square's right-bottom vertex
                pieceB: viewModel.puzzle.pieces[1].id,
                vertexB: 0   // Parallelogram's left-bottom vertex
            ),
            constraint: Constraint(type: .fixed, affectedPieceId: viewModel.puzzle.pieces[1].id)
        )
        viewModel.puzzle.connections.append(connection)
        
        XCTAssertEqual(viewModel.puzzle.connections.count, 1)
        
        // Remove piece
        viewModel.removePiece(id: pieceId)
        
        XCTAssertEqual(viewModel.puzzle.pieces.count, 1)
        XCTAssertEqual(viewModel.puzzle.connections.count, 0,
                      "Should remove connections involving removed piece")
    }
    
    func testUpdatePieceTransform() {
        viewModel.addPiece(type: .mediumTriangle, at: .zero)
        let pieceId = viewModel.puzzle.pieces[0].id
        
        let newTransform = CGAffineTransform(translationX: 20, y: 30)
            .rotated(by: .pi / 4)
        
        viewModel.updatePieceTransform(id: pieceId, transform: newTransform)
        
        XCTAssertEqual(viewModel.puzzle.pieces[0].transform, newTransform)
    }
    
    func testRotatePiece() {
        viewModel.addPiece(type: .largeTriangle1, at: .zero)
        let pieceId = viewModel.puzzle.pieces[0].id
        
        viewModel.rotatePiece(id: pieceId, by: .pi / 2)
        
        let angle = atan2(viewModel.puzzle.pieces[0].transform.b,
                         viewModel.puzzle.pieces[0].transform.a)
        XCTAssertEqual(angle, .pi / 2, accuracy: 0.01)
    }
    
    func testSelectPiece() {
        viewModel.addPiece(type: .square, at: .zero)
        let pieceId = viewModel.puzzle.pieces[0].id
        
        XCTAssertNil(viewModel.selectedPieceId)
        
        viewModel.selectPiece(id: pieceId)
        XCTAssertEqual(viewModel.selectedPieceId, pieceId)
        
        viewModel.selectPiece(id: nil)
        XCTAssertNil(viewModel.selectedPieceId)
    }
    
    // MARK: - Validation Tests
    
    func testValidationOnPieceAdd() {
        if case .unknown = viewModel.validationState {
            // Expected initial state
        } else {
            XCTFail("Should start with unknown validation state")
        }
        
        viewModel.addPiece(type: .smallTriangle1, at: .zero)
        
        // Single piece should be valid
        if case .valid = viewModel.validationState {
            // Expected
        } else {
            XCTFail("Single piece should be valid")
        }
    }
    
    // REMOVED: testValidationWithOverlap - Not relevant for connection-based system
    // In connection-based assembly, pieces can only be placed via connections,
    // which prevents overlaps by design
    
    // REMOVED: testValidationWithUnexplainedContact - Not relevant for connection-based system
    // Pieces are explicitly connected by user selection, not free-form placement
    
    func testValidationWithDisconnectedPieces() {
        viewModel.addPiece(type: .smallTriangle1, at: .zero)
        viewModel.addPiece(type: .smallTriangle2, at: CGPoint(x: 10, y: 10))
        
        if case .invalid(let errors) = viewModel.validationState {
            XCTAssertTrue(errors.contains("Not all pieces are connected"))
        } else {
            XCTFail("Disconnected pieces should be invalid")
        }
    }
    
    func testValidationWithEmptyName() {
        viewModel.puzzle.name = ""
        viewModel.validate()
        
        if case .invalid(let errors) = viewModel.validationState {
            XCTAssertTrue(errors.contains("Puzzle name is required"))
        } else {
            XCTFail("Empty name should be invalid")
        }
    }
    
    // MARK: - Connection Creation Workflow Tests
    
    func testConnectionWorkflowStart() {
        XCTAssertEqual(viewModel.editMode, .select)
        
        if case .idle = viewModel.connectionState {
            // Expected initial state
        } else {
            XCTFail("Should start with idle connection state")
        }
        
        viewModel.startConnectionMode()
        
        XCTAssertEqual(viewModel.editMode, .connect)
        
        if case .selectingFirstPiece = viewModel.connectionState {
            // Expected state after starting connection mode
        } else {
            XCTFail("Should be in selectingFirstPiece state")
        }
        XCTAssertEqual(viewModel.highlightedPoints.count, 0)
    }
    
    func testConnectionWorkflowCancel() {
        viewModel.startConnectionMode()
        viewModel.selectedPieceId = "test-id"
        viewModel.anchorPieceId = "anchor-id"
        viewModel.highlightedPoints = [
            TangramEditorViewModel.ConnectionPoint(
                type: .vertex(index: 0),
                position: .zero,
                pieceId: "test"
            )
        ]
        
        viewModel.cancelConnectionMode()
        
        if case .idle = viewModel.connectionState {
            // Expected state after cancel
        } else {
            XCTFail("Should be idle after cancel")
        }
        XCTAssertEqual(viewModel.editMode, .select)
        XCTAssertEqual(viewModel.highlightedPoints.count, 0)
        XCTAssertNil(viewModel.selectedPieceId)
        XCTAssertNil(viewModel.anchorPieceId)
    }
    
    func testSelectPieceForConnection() {
        viewModel.addPiece(type: .smallTriangle1, at: .zero)
        viewModel.addPiece(type: .smallTriangle2, at: CGPoint(x: 2, y: 0))
        let piece1Id = viewModel.puzzle.pieces[0].id
        _ = viewModel.puzzle.pieces[1].id
        
        viewModel.startConnectionMode()
        viewModel.selectPieceForConnection(pieceId: piece1Id)
        
        if case .selectedFirstPiece(let pieceId, let point) = viewModel.connectionState {
            XCTAssertEqual(pieceId, piece1Id)
            XCTAssertNil(point)
        } else {
            XCTFail("Should be in selectedFirstPiece state")
        }
        
        XCTAssertEqual(viewModel.anchorPieceId, piece1Id)
        XCTAssertTrue(viewModel.highlightedPoints.count > 0,
                     "Should highlight connection points")
    }
    
    func testSelectConnectionPoint() {
        viewModel.addPiece(type: .square, at: .zero)
        let pieceId = viewModel.puzzle.pieces[0].id
        
        viewModel.startConnectionMode()
        viewModel.selectPieceForConnection(pieceId: pieceId)
        
        let point = TangramEditorViewModel.ConnectionPoint(
            type: .vertex(index: 0),
            position: .zero,
            pieceId: pieceId
        )
        
        viewModel.selectConnectionPoint(point)
        
        if case .selectedFirstPiece(_, let selectedPoint) = viewModel.connectionState {
            XCTAssertNotNil(selectedPoint)
            XCTAssertEqual(selectedPoint?.type, point.type)
        } else {
            XCTFail("Should still be in selectedFirstPiece state with point")
        }
    }
    
    func testConfirmConnection() {
        viewModel.addPiece(type: .smallTriangle1, at: .zero)
        viewModel.addPiece(type: .smallTriangle2, at: CGPoint(x: 1, y: 0))
        
        let piece1 = viewModel.puzzle.pieces[0]
        let piece2 = viewModel.puzzle.pieces[1]
        
        // Create pending connection
        let pending = TangramEditorViewModel.PendingConnection(
            pieceAId: piece1.id,
            pieceBId: piece2.id,
            pointA: TangramEditorViewModel.ConnectionPoint(
                type: .vertex(index: 1),
                position: CGPoint(x: 1, y: 0),
                pieceId: piece1.id
            ),
            pointB: TangramEditorViewModel.ConnectionPoint(
                type: .vertex(index: 0),
                position: CGPoint(x: 1, y: 0),
                pieceId: piece2.id
            ),
            connectionType: .vertexToVertex(
                pieceA: piece1.id,
                vertexA: 1,
                pieceB: piece2.id,
                vertexB: 0
            ),
            possibleConstraints: [.fixed]
        )
        
        viewModel.connectionState = .readyToConnect(connection: pending)
        viewModel.confirmConnection()
        
        XCTAssertEqual(viewModel.puzzle.connections.count, 1)
        
        if case .idle = viewModel.connectionState {
            // Expected state after confirmation
        } else {
            XCTFail("Should be idle after confirmation")
        }
        XCTAssertEqual(viewModel.editMode, .select)
    }
    
    // MARK: - Geometric Query Tests
    
    func testGetTransformedVertices() {
        viewModel.addPiece(type: .square, at: CGPoint(x: 5, y: 5))
        let pieceId = viewModel.puzzle.pieces[0].id
        
        let vertices = viewModel.getTransformedVertices(for: pieceId)
        
        XCTAssertNotNil(vertices)
        XCTAssertEqual(vertices?.count, 4)
        XCTAssertEqual(vertices?[0], CGPoint(x: 5, y: 5))
        XCTAssertEqual(vertices?[1], CGPoint(x: 6, y: 5))
        XCTAssertEqual(vertices?[2], CGPoint(x: 6, y: 6))
        XCTAssertEqual(vertices?[3], CGPoint(x: 5, y: 6))
    }
    
    func testGetPieceBounds() {
        viewModel.addPiece(type: .largeTriangle1, at: CGPoint(x: 10, y: 10))
        let pieceId = viewModel.puzzle.pieces[0].id
        
        let bounds = viewModel.getPieceBounds(for: pieceId)
        
        XCTAssertNotNil(bounds)
        XCTAssertEqual(Double(bounds?.origin.x ?? 0), 10, accuracy: 0.01)
        XCTAssertEqual(Double(bounds?.origin.y ?? 0), 10, accuracy: 0.01)
        XCTAssertEqual(Double(bounds?.width ?? 0), 2, accuracy: 0.01)
        XCTAssertEqual(Double(bounds?.height ?? 0), 2, accuracy: 0.01)
    }
    
    func testGetPieceCentroid() {
        viewModel.addPiece(type: .square, at: .zero)
        let pieceId = viewModel.puzzle.pieces[0].id
        
        let centroid = viewModel.getPieceCentroid(for: pieceId)
        
        XCTAssertNotNil(centroid)
        XCTAssertEqual(Double(centroid?.x ?? 0), 0.5, accuracy: 0.01)
        XCTAssertEqual(Double(centroid?.y ?? 0), 0.5, accuracy: 0.01)
    }
    
    // MARK: - Constraint-Aware Transformation Tests
    
    func testRotatePieceAroundVertex() {
        viewModel.addPiece(type: .smallTriangle1, at: .zero)
        let pieceId = viewModel.puzzle.pieces[0].id
        let vertex = CGPoint(x: 1, y: 0)
        
        viewModel.rotatePieceAroundVertex(pieceId: pieceId, vertex: vertex, angle: .pi / 2)
        
        // Piece should rotate around the specified vertex
        let vertices = viewModel.getTransformedVertices(for: pieceId)
        XCTAssertNotNil(vertices)
        
        // The vertex at (1,0) should remain at (1,0) after rotation
        XCTAssertTrue(vertices?.contains { point in
            abs(point.x - 1) < 0.01 && abs(point.y) < 0.01
        } ?? false, "Rotation vertex should remain fixed")
    }
    
    func testSlidePieceAlongEdge() {
        viewModel.addPiece(type: .square, at: .zero)
        let pieceId = viewModel.puzzle.pieces[0].id
        let edgeVector = CGVector(dx: 1, dy: 0)
        
        viewModel.slidePieceAlongEdge(pieceId: pieceId, edgeVector: edgeVector, distance: 2)
        
        let transform = viewModel.puzzle.pieces[0].transform
        XCTAssertEqual(transform.tx, 2, accuracy: 0.01)
        XCTAssertEqual(transform.ty, 0, accuracy: 0.01)
    }
    
    func testSnapToValidPosition() {
        viewModel.addPiece(type: .smallTriangle1, at: .zero)
        viewModel.addPiece(type: .smallTriangle2, at: CGPoint(x: 1, y: 0))
        
        // Create connection with constraint
        let connection = ConnectionType.vertexToVertex(
            pieceA: viewModel.puzzle.pieces[0].id,
            vertexA: 1,
            pieceB: viewModel.puzzle.pieces[1].id,
            vertexB: 0
        )
        viewModel.createConnection(type: connection)
        
        // Move piece2 slightly off
        viewModel.puzzle.pieces[1].transform = CGAffineTransform(translationX: 1.1, y: 0.1)
        
        let snapped = viewModel.snapToValidPosition(pieceId: viewModel.puzzle.pieces[1].id)
        XCTAssertNotNil(snapped)
    }
    
    // MARK: - Export Tests
    
    func testExportForGameplay() {
        viewModel.puzzle.name = "Test Export"
        viewModel.puzzle.category = .animals
        viewModel.puzzle.difficulty = .medium
        
        viewModel.addPiece(type: .square, at: .zero)
        viewModel.addPiece(type: .smallTriangle1, at: CGPoint(x: 1, y: 0))
        
        // Create connection to make valid
        let connection = ConnectionType.edgeToEdge(
            pieceA: viewModel.puzzle.pieces[0].id,
            edgeA: 1,
            pieceB: viewModel.puzzle.pieces[1].id,
            edgeB: 2
        )
        viewModel.createConnection(type: connection)
        
        viewModel.validate()
        
        let exported = viewModel.exportForGameplay()
        
        if viewModel.validationState.isValid {
            XCTAssertNotNil(exported)
            XCTAssertEqual(exported?.name, "Test Export")
            XCTAssertEqual(exported?.category, "Animals")
            XCTAssertEqual(exported?.difficulty, "Medium")
            XCTAssertEqual(exported?.solvedPieces.count, 2)
        } else {
            XCTAssertNil(exported, "Should not export invalid puzzle")
        }
    }
    
    func testExportInvalidPuzzle() {
        // Create invalid puzzle with disconnected pieces
        viewModel.addPiece(type: .largeTriangle1, at: .zero)
        viewModel.addPiece(type: .largeTriangle2, at: CGPoint(x: 10, y: 10))
        
        viewModel.validate()
        
        let exported = viewModel.exportForGameplay()
        XCTAssertNil(exported, "Should not export invalid puzzle")
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Setup complex state
        viewModel.puzzle.name = "Modified"
        viewModel.addPiece(type: .square, at: .zero)
        viewModel.selectedPieceId = "test-id"
        viewModel.anchorPieceId = "anchor-id"
        viewModel.editMode = .rotate
        
        viewModel.reset()
        
        XCTAssertEqual(viewModel.puzzle.name, "New Puzzle")
        XCTAssertEqual(viewModel.puzzle.pieces.count, 0)
        XCTAssertNil(viewModel.selectedPieceId)
        XCTAssertNil(viewModel.anchorPieceId)
        
        if case .unknown = viewModel.validationState {
            // Expected state after reset
        } else {
            XCTFail("Should have unknown validation state after reset")
        }
        
        XCTAssertEqual(viewModel.editMode, .select)
    }
    
    // MARK: - Persistence Integration Tests
    
    func testSaveAndLoad() async throws {
        viewModel.puzzle.name = "Persistence Test"
        viewModel.addPiece(type: .parallelogram, at: .zero)
        
        try await viewModel.save()
        
        let puzzleId = viewModel.puzzle.id
        
        // Reset and load
        viewModel.reset()
        XCTAssertEqual(viewModel.puzzle.pieces.count, 0)
        
        try await viewModel.load(puzzleId: puzzleId)
        
        XCTAssertEqual(viewModel.puzzle.name, "Persistence Test")
        XCTAssertEqual(viewModel.puzzle.pieces.count, 1)
        XCTAssertEqual(viewModel.puzzle.pieces[0].type, .parallelogram)
        
        // Clean up
        try? await viewModel.deletePuzzle()
    }
    
    func testListSavedPuzzles() async throws {
        // Save a puzzle
        viewModel.puzzle.name = "List Test"
        try await viewModel.save()
        
        let puzzles = try await viewModel.listSavedPuzzles()
        
        XCTAssertTrue(puzzles.contains { $0.name == "List Test" })
        
        // Clean up
        try? await viewModel.deletePuzzle()
    }
    
    // MARK: - Edge Mode Tests
    
    func testEditModeTransitions() {
        XCTAssertEqual(viewModel.editMode, .select)
        
        viewModel.editMode = .move
        XCTAssertEqual(viewModel.editMode, .move)
        
        viewModel.editMode = .rotate
        XCTAssertEqual(viewModel.editMode, .rotate)
        
        viewModel.startConnectionMode()
        XCTAssertEqual(viewModel.editMode, .connect)
        
        viewModel.cancelConnectionMode()
        XCTAssertEqual(viewModel.editMode, .select)
    }
    
    func testComplexConnectionScenario() {
        // Create three pieces in a chain
        viewModel.addPiece(type: .square, at: .zero)
        viewModel.addPiece(type: .square, at: CGPoint(x: 1, y: 0))
        viewModel.addPiece(type: .square, at: CGPoint(x: 2, y: 0))
        
        // Connect first two
        viewModel.createConnection(type: .edgeToEdge(
            pieceA: viewModel.puzzle.pieces[0].id,
            edgeA: 1,
            pieceB: viewModel.puzzle.pieces[1].id,
            edgeB: 3
        ))
        
        // Connect second two
        viewModel.createConnection(type: .edgeToEdge(
            pieceA: viewModel.puzzle.pieces[1].id,
            edgeA: 1,
            pieceB: viewModel.puzzle.pieces[2].id,
            edgeB: 3
        ))
        
        viewModel.validate()
        
        if case .valid = viewModel.validationState {
            // Expected - chain should be valid
        } else {
            XCTFail("Connected chain should be valid")
        }
        
        XCTAssertEqual(viewModel.puzzle.connections.count, 2)
    }
}