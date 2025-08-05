//
//  ValidationServiceTests.swift
//  BemoTests
//
//  Unit tests for ValidationService - focused on connection-based validation
//

import XCTest
@testable import Bemo

class ValidationServiceTests: XCTestCase {
    
    var validationService: ValidationService!
    
    override func setUp() {
        super.setUp()
        validationService = ValidationService()
    }
    
    // MARK: - Graph Connectivity Tests (KEEP - This is important for connection-based validation)
    
    func testGraphConnectivity() {
        let pieces = [
            TangramPiece(type: .smallTriangle1, transform: .identity),
            TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0)),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 2, y: 0))
        ]
        
        // No connections - not connected
        XCTAssertFalse(validationService.isConnected(pieces: pieces, connections: []),
                      "Pieces without connections should not be connected")
        
        // Chain connections - all connected
        let connections = [
            Connection(
                type: .vertexToVertex(pieceA: pieces[0].id, vertexA: 1, pieceB: pieces[1].id, vertexB: 0),
                constraint: Constraint(type: .fixed, affectedPieceId: pieces[1].id)
            ),
            Connection(
                type: .vertexToVertex(pieceA: pieces[1].id, vertexA: 1, pieceB: pieces[2].id, vertexB: 0),
                constraint: Constraint(type: .fixed, affectedPieceId: pieces[2].id)
            )
        ]
        
        XCTAssertTrue(validationService.isConnected(pieces: pieces, connections: connections),
                     "Chain-connected pieces should form connected graph")
        
        // Disconnected island
        let partialConnections = [connections[0]] // Only first two pieces connected
        XCTAssertFalse(validationService.isConnected(pieces: pieces, connections: partialConnections),
                      "Disconnected piece should break connectivity")
    }
    
    func testEmptyPuzzleValidation() {
        XCTAssertTrue(validationService.isConnected(pieces: [], connections: []),
                     "Empty puzzle should be considered connected")
    }
}