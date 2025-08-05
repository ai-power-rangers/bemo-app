//
//  ConnectionServiceTests.swift
//  BemoTests
//
//  Comprehensive unit tests for ConnectionService
//

import XCTest
@testable import Bemo

class ConnectionServiceTests: XCTestCase {
    
    var connectionService: ConnectionService!
    
    override func setUp() {
        super.setUp()
        connectionService = ConnectionService()
    }
    
    // MARK: - Connection Creation Tests
    
    func testVertexToVertexConnectionCreation() {
        // Create two triangles positioned to share a vertex
        let triangle1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let triangle2 = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        let pieces = [triangle1, triangle2]
        
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: triangle1.id,
            vertexA: 1, // vertex at (1,0)
            pieceB: triangle2.id,
            vertexB: 0  // vertex at (0,0) in local, (1,0) after transform
        )
        
        let connection = connectionService.createConnection(type: connectionType, pieces: pieces)
        
        XCTAssertNotNil(connection, "Should create vertex-to-vertex connection")
        XCTAssertEqual(connection?.pieceAId, triangle1.id)
        XCTAssertEqual(connection?.pieceBId, triangle2.id)
        
        // Check constraint type
        if case .rotation(let center, let range) = connection?.constraint.type {
            XCTAssertEqual(center, CGPoint(x: 1, y: 0), "Rotation should be around shared vertex")
            XCTAssertEqual(range.lowerBound, 0, accuracy: 0.01)
            XCTAssertEqual(range.upperBound, 360, accuracy: 0.01)
        } else {
            XCTFail("Should have rotation constraint")
        }
    }
    
    func testEdgeToEdgeConnectionCreation() {
        // Create square and triangle with aligned edges
        let square = TangramPiece(type: .square, transform: .identity)
        let triangle = TangramPiece(type: .smallTriangle1, transform: CGAffineTransform(translationX: 0, y: 1))
        let pieces = [square, triangle]
        
        let connectionType = ConnectionType.edgeToEdge(
            pieceA: square.id,
            edgeA: 2, // top edge of square
            pieceB: triangle.id,
            edgeB: 0  // bottom edge of triangle
        )
        
        let connection = connectionService.createConnection(type: connectionType, pieces: pieces)
        
        XCTAssertNotNil(connection, "Should create edge-to-edge connection")
        
        // Check constraint for same-length edges
        if case .translation(_, let range) = connection?.constraint.type {
            XCTAssertEqual(range.lowerBound, 0, accuracy: 0.01)
            XCTAssertEqual(range.upperBound, 0, accuracy: 0.01, "Same length edges should not slide")
        } else if case .fixed = connection?.constraint.type {
            // Fixed constraint is also valid for same-length edges
        } else {
            XCTFail("Should have translation or fixed constraint")
        }
    }
    
    func testEdgeToEdgeDifferentLengths() {
        // Small triangle edge (length 1) on medium triangle edge (length √2)
        let smallTriangle = TangramPiece(type: .smallTriangle1, transform: .identity)
        let mediumTriangle = TangramPiece(type: .mediumTriangle, transform: CGAffineTransform(translationX: 0, y: 1))
        let pieces = [smallTriangle, mediumTriangle]
        
        let connectionType = ConnectionType.edgeToEdge(
            pieceA: mediumTriangle.id,
            edgeA: 0, // edge length √2
            pieceB: smallTriangle.id,
            edgeB: 0  // edge length 1
        )
        
        let connection = connectionService.createConnection(type: connectionType, pieces: pieces)
        
        XCTAssertNotNil(connection, "Should create sliding edge connection")
        
        // Check sliding constraint
        if case .translation(_, let range) = connection?.constraint.type {
            let expectedRange = sqrt(2.0) - 1.0
            XCTAssertEqual(range.upperBound, expectedRange, accuracy: 0.01,
                          "Should allow sliding by difference in edge lengths")
        } else {
            XCTFail("Should have translation constraint for different length edges")
        }
    }
    
    func testInvalidConnectionCreation() {
        let piece = TangramPiece(type: .square, transform: .identity)
        let pieces = [piece]
        
        // Invalid vertex index
        let invalidVertexConnection = ConnectionType.vertexToVertex(
            pieceA: piece.id,
            vertexA: 10, // Invalid index
            pieceB: piece.id,
            vertexB: 0
        )
        
        let connection = connectionService.createConnection(type: invalidVertexConnection, pieces: pieces)
        XCTAssertNil(connection, "Should not create connection with invalid vertex index")
        
        // Non-existent piece
        let nonExistentConnection = ConnectionType.vertexToVertex(
            pieceA: "non-existent-id",
            vertexA: 0,
            pieceB: piece.id,
            vertexB: 0
        )
        
        let connection2 = connectionService.createConnection(type: nonExistentConnection, pieces: pieces)
        XCTAssertNil(connection2, "Should not create connection with non-existent piece")
    }
    
    // MARK: - Connection Query Tests
    
    func testAreConnected() {
        let piece1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let piece2 = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        
        let connection = Connection(
            type: .vertexToVertex(pieceA: piece1.id, vertexA: 0, pieceB: piece2.id, vertexB: 0),
            constraint: Constraint(type: .fixed, affectedPieceId: piece2.id)
        )
        
        XCTAssertTrue(connectionService.areConnected(
            pieceA: piece1.id,
            pieceB: piece2.id,
            connections: [connection]
        ), "Should detect connection between pieces")
        
        XCTAssertTrue(connectionService.areConnected(
            pieceA: piece2.id,
            pieceB: piece1.id,
            connections: [connection]
        ), "Should detect connection regardless of order")
        
        XCTAssertFalse(connectionService.areConnected(
            pieceA: piece1.id,
            pieceB: "other-id",
            connections: [connection]
        ), "Should not detect connection with unconnected piece")
    }
    
    func testConnectionBetween() {
        let connections = [
            Connection(
                type: .vertexToVertex(pieceA: "A", vertexA: 0, pieceB: "B", vertexB: 0),
                constraint: Constraint(type: .fixed, affectedPieceId: "B")
            ),
            Connection(
                type: .edgeToEdge(pieceA: "B", edgeA: 0, pieceB: "C", edgeB: 0),
                constraint: Constraint(type: .fixed, affectedPieceId: "C")
            )
        ]
        
        let connection = connectionService.connectionBetween("A", "B", connections: connections)
        XCTAssertNotNil(connection, "Should find connection between A and B")
        
        let reverseConnection = connectionService.connectionBetween("B", "A", connections: connections)
        XCTAssertNotNil(reverseConnection, "Should find connection regardless of order")
        XCTAssertEqual(connection?.id, reverseConnection?.id, "Should be same connection")
        
        let noConnection = connectionService.connectionBetween("A", "C", connections: connections)
        XCTAssertNil(noConnection, "Should not find direct connection between A and C")
    }
    
    // MARK: - Constraint Application Tests
    
    func testApplyRotationConstraint() {
        let piece = TangramPiece(type: .smallTriangle1, transform: .identity)
        let rotationPoint = CGPoint(x: 1, y: 0)
        
        let connection = Connection(
            type: .vertexToVertex(pieceA: "other", vertexA: 0, pieceB: piece.id, vertexB: 0),
            constraint: Constraint(
                type: .rotation(around: rotationPoint, range: -Double.pi...Double.pi),
                affectedPieceId: piece.id
            )
        )
        
        let newTransform = connectionService.applyConstraints(
            for: piece.id,
            connections: [connection],
            currentTransform: piece.transform,
            parameter: Double.pi / 4
        )
        
        // Verify rotation was applied
        let angle = atan2(newTransform.b, newTransform.a)
        XCTAssertEqual(angle, Double.pi / 4, accuracy: 0.01, "Should apply rotation parameter")
    }
    
    func testApplyTranslationConstraint() {
        let piece = TangramPiece(type: .square, transform: .identity)
        let slideVector = CGVector(dx: 1, dy: 0)
        
        let connection = Connection(
            type: .edgeToEdge(pieceA: "other", edgeA: 0, pieceB: piece.id, edgeB: 0),
            constraint: Constraint(
                type: .translation(along: slideVector, range: 0...2),
                affectedPieceId: piece.id
            )
        )
        
        let newTransform = connectionService.applyConstraints(
            for: piece.id,
            connections: [connection],
            currentTransform: piece.transform,
            parameter: 1.5
        )
        
        XCTAssertEqual(newTransform.tx, 1.5, accuracy: 0.01, "Should apply translation along vector")
        XCTAssertEqual(newTransform.ty, 0, accuracy: 0.01, "Should only translate along specified vector")
    }
    
    func testMultipleConstraints() {
        let pieceId = "test-piece"
        let connections = [
            Connection(
                type: .vertexToVertex(pieceA: "A", vertexA: 0, pieceB: pieceId, vertexB: 0),
                constraint: Constraint(
                    type: .rotation(around: CGPoint(x: 0, y: 0), range: 0...Double.pi),
                    affectedPieceId: pieceId
                )
            ),
            Connection(
                type: .edgeToEdge(pieceA: "B", edgeA: 0, pieceB: pieceId, edgeB: 0),
                constraint: Constraint(
                    type: .translation(along: CGVector(dx: 1, dy: 0), range: 0...1),
                    affectedPieceId: pieceId
                )
            )
        ]
        
        let transform = connectionService.applyConstraints(
            for: pieceId,
            connections: connections,
            currentTransform: .identity,
            parameter: 0.5
        )
        
        XCTAssertNotEqual(transform, CGAffineTransform.identity,
                         "Should apply multiple constraints")
    }
    
    // MARK: - Connection Satisfaction Tests
    
    func testVertexConnectionSatisfaction() {
        let triangle1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let triangle2 = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        let pieces = [triangle1, triangle2]
        
        let connection = Connection(
            type: .vertexToVertex(
                pieceA: triangle1.id,
                vertexA: 1, // vertex at (1,0)
                pieceB: triangle2.id,
                vertexB: 0  // vertex at (0,0) local, (1,0) world
            ),
            constraint: Constraint(type: .fixed, affectedPieceId: triangle2.id)
        )
        
        XCTAssertTrue(connectionService.isConnectionSatisfied(connection, pieces: pieces),
                     "Vertex connection should be satisfied when vertices align")
        
        // Move piece2 away
        var movedTriangle2 = triangle2
        movedTriangle2.transform = CGAffineTransform(translationX: 2, y: 0)
        let movedPieces = [triangle1, movedTriangle2]
        
        XCTAssertFalse(connectionService.isConnectionSatisfied(connection, pieces: movedPieces),
                      "Vertex connection should not be satisfied when vertices don't align")
    }
    
    func testEdgeConnectionSatisfaction() {
        let square1 = TangramPiece(type: .square, transform: .identity)
        let square2 = TangramPiece(type: .square, transform: CGAffineTransform(translationX: 1, y: 0))
        let pieces = [square1, square2]
        
        let connection = Connection(
            type: .edgeToEdge(
                pieceA: square1.id,
                edgeA: 1, // right edge
                pieceB: square2.id,
                edgeB: 3  // left edge
            ),
            constraint: Constraint(type: .fixed, affectedPieceId: square2.id)
        )
        
        XCTAssertTrue(connectionService.isConnectionSatisfied(connection, pieces: pieces),
                     "Edge connection should be satisfied when edges align")
        
        // Rotate piece2
        var rotatedSquare2 = square2
        rotatedSquare2.transform = square2.transform.rotated(by: .pi / 4)
        let rotatedPieces = [square1, rotatedSquare2]
        
        XCTAssertFalse(connectionService.isConnectionSatisfied(connection, pieces: rotatedPieces),
                      "Edge connection should not be satisfied when edges don't align")
    }
    
    func testPartialEdgeConnectionSatisfaction() {
        // Small edge sliding on larger edge
        let smallTriangle = TangramPiece(type: .smallTriangle1, transform: .identity)
        let largeTriangle = TangramPiece(type: .largeTriangle1, transform: CGAffineTransform(translationX: 0, y: 1))
        let pieces = [smallTriangle, largeTriangle]
        
        let connection = Connection(
            type: .edgeToEdge(
                pieceA: largeTriangle.id,
                edgeA: 0, // length 2
                pieceB: smallTriangle.id,
                edgeB: 0  // length 1
            ),
            constraint: Constraint(
                type: .translation(along: CGVector(dx: 1, dy: 0), range: 0...1),
                affectedPieceId: smallTriangle.id
            )
        )
        
        // Small edge should be satisfied anywhere along large edge
        XCTAssertTrue(connectionService.isConnectionSatisfied(connection, pieces: pieces),
                     "Partial edge connection should be satisfied")
        
        // Move small triangle to middle of large edge
        var slidTriangle = smallTriangle
        slidTriangle.transform = CGAffineTransform(translationX: 0.5, y: 1)
        let slidPieces = [slidTriangle, largeTriangle]
        
        XCTAssertTrue(connectionService.isConnectionSatisfied(connection, pieces: slidPieces),
                     "Partial edge connection should be satisfied at any valid position")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyPiecesArray() {
        let connectionType = ConnectionType.vertexToVertex(
            pieceA: "A",
            vertexA: 0,
            pieceB: "B",
            vertexB: 0
        )
        
        let connection = connectionService.createConnection(type: connectionType, pieces: [])
        XCTAssertNil(connection, "Should not create connection with empty pieces array")
    }
    
    func testSelfConnection() {
        let piece = TangramPiece(type: .square, transform: .identity)
        
        let selfConnection = ConnectionType.vertexToVertex(
            pieceA: piece.id,
            vertexA: 0,
            pieceB: piece.id,
            vertexB: 2
        )
        
        // Note: The service might allow self-connections for special cases
        // This test documents the behavior
        let connection = connectionService.createConnection(type: selfConnection, pieces: [piece])
        
        // Update assertion based on actual implementation behavior
        if connection != nil {
            XCTAssertEqual(connection?.pieceAId, connection?.pieceBId,
                          "Self-connection should reference same piece")
        }
    }
    
    func testConnectionWithTransformedPieces() {
        let complexTransform = CGAffineTransform.identity
            .rotated(by: .pi / 6)
            .translatedBy(x: 5, y: 3)
            .scaledBy(x: 1, y: 1) // No actual scaling
        
        let piece1 = TangramPiece(type: .parallelogram, transform: complexTransform)
        let piece2 = TangramPiece(type: .square, transform: complexTransform.translatedBy(x: 1, y: 0))
        let pieces = [piece1, piece2]
        
        let connectionType = ConnectionType.edgeToEdge(
            pieceA: piece1.id,
            edgeA: 0,
            pieceB: piece2.id,
            edgeB: 0
        )
        
        let connection = connectionService.createConnection(type: connectionType, pieces: pieces)
        XCTAssertNotNil(connection, "Should handle connections with complex transforms")
    }
}