//
//  ValidationServiceTests.swift
//  BemoTests
//
//  Comprehensive unit tests for ValidationService
//

import XCTest
@testable import Bemo

class ValidationServiceTests: XCTestCase {
    
    var validationService: ValidationService!
    
    override func setUp() {
        super.setUp()
        validationService = ValidationService()
    }
    
    // MARK: - Layer 1: Pure Geometric Detection Tests
    
    func testAreaOverlapDetection() {
        // Test complete overlap
        let piece1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let piece2 = TangramPiece(type: .smallTriangle1, transform: .identity)
        
        XCTAssertTrue(validationService.hasAreaOverlap(pieceA: piece1, pieceB: piece2),
                     "Identical pieces should have area overlap")
        
        // Test partial overlap
        let piece3 = TangramPiece(type: .smallTriangle1, transform: CGAffineTransform(translationX: 0.5, y: 0))
        XCTAssertTrue(validationService.hasAreaOverlap(pieceA: piece1, pieceB: piece3),
                     "Partially overlapping pieces should be detected")
        
        // Test no overlap
        let piece4 = TangramPiece(type: .smallTriangle1, transform: CGAffineTransform(translationX: 10, y: 10))
        XCTAssertFalse(validationService.hasAreaOverlap(pieceA: piece1, pieceB: piece4),
                      "Distant pieces should not overlap")
    }
    
    func testEdgeContactDetection() {
        // Test perfect edge alignment
        let square = TangramPiece(type: .square, transform: .identity)
        let triangle = TangramPiece(type: .smallTriangle1, transform: CGAffineTransform(translationX: 0, y: 1))
        
        XCTAssertTrue(validationService.hasEdgeContact(pieceA: square, pieceB: triangle),
                     "Square top edge should contact triangle bottom edge")
        
        // Test partial edge contact
        let offsetTriangle = TangramPiece(type: .smallTriangle1, transform: CGAffineTransform(translationX: 0.5, y: 1))
        XCTAssertTrue(validationService.hasEdgeContact(pieceA: square, pieceB: offsetTriangle),
                     "Partial edge contact should be detected")
        
        // Test no edge contact
        let distantPiece = TangramPiece(type: .square, transform: CGAffineTransform(translationX: 5, y: 5))
        XCTAssertFalse(validationService.hasEdgeContact(pieceA: square, pieceB: distantPiece),
                      "Distant pieces should not have edge contact")
    }
    
    func testVertexContactDetection() {
        // Test exact vertex-to-vertex contact
        let triangle1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let triangle2 = TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 1, y: 0))
        
        XCTAssertTrue(validationService.hasVertexContact(pieceA: triangle1, pieceB: triangle2),
                     "Triangles should share a vertex")
        
        // Test vertex-to-edge contact
        let square = TangramPiece(type: .square, transform: CGAffineTransform(translationX: 0.5, y: -1))
        XCTAssertTrue(validationService.hasVertexContact(pieceA: triangle1, pieceB: square),
                     "Triangle vertex should touch square edge")
    }
    
    func testGeometricRelationshipPriority() {
        // Area overlap takes priority over edge/vertex contact
        let overlappingPieces = (
            TangramPiece(type: .largeTriangle1, transform: .identity),
            TangramPiece(type: .largeTriangle1, transform: CGAffineTransform(translationX: 0.5, y: 0.5))
        )
        
        let relationship = validationService.getGeometricRelationship(
            pieceA: overlappingPieces.0,
            pieceB: overlappingPieces.1
        )
        XCTAssertEqual(relationship, .areaOverlap,
                      "Area overlap should be detected first")
        
        // Edge contact takes priority over vertex contact
        let edgeTouchingPieces = (
            TangramPiece(type: .square, transform: .identity),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 1, y: 0))
        )
        
        let edgeRelationship = validationService.getGeometricRelationship(
            pieceA: edgeTouchingPieces.0,
            pieceB: edgeTouchingPieces.1
        )
        XCTAssertEqual(edgeRelationship, .edgeContact,
                      "Edge contact should be detected before vertex")
    }
    
    // MARK: - Layer 2: Semantic Validation Tests
    
    func testInvalidAreaOverlapsInCollection() {
        let pieces = [
            TangramPiece(type: .smallTriangle1, transform: .identity),
            TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 2, y: 0)),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 0.5, y: 0.5)) // Overlaps with first
        ]
        
        XCTAssertTrue(validationService.hasInvalidAreaOverlaps(pieces: pieces),
                     "Should detect overlap in collection")
        
        let nonOverlappingPieces = [
            TangramPiece(type: .smallTriangle1, transform: .identity),
            TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 5, y: 0)),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 10, y: 0))
        ]
        
        XCTAssertFalse(validationService.hasInvalidAreaOverlaps(pieces: nonOverlappingPieces),
                      "Should not detect overlaps when pieces are separated")
    }
    
    func testUnexplainedContacts() {
        // Pieces touching without connections
        let touchingPieces = [
            TangramPiece(type: .square, transform: .identity),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 1, y: 0))
        ]
        
        XCTAssertTrue(validationService.hasUnexplainedContacts(pieces: touchingPieces, connections: []),
                     "Edge contact without connection should be unexplained")
        
        // Same pieces with connection
        let connection = Connection(
            type: .edgeToEdge(
                pieceA: touchingPieces[0].id,
                edgeA: 1,
                pieceB: touchingPieces[1].id,
                edgeB: 3
            ),
            constraint: Constraint(type: .fixed, affectedPieceId: touchingPieces[1].id)
        )
        
        XCTAssertFalse(validationService.hasUnexplainedContacts(pieces: touchingPieces, connections: [connection]),
                      "Edge contact with connection should be explained")
    }
    
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
        
        XCTAssertFalse(validationService.hasInvalidAreaOverlaps(pieces: []),
                      "Empty puzzle should have no overlaps")
        
        XCTAssertFalse(validationService.hasUnexplainedContacts(pieces: [], connections: []),
                      "Empty puzzle should have no unexplained contacts")
    }
    
    // MARK: - Main Validation Method Tests
    
    func testValidAssembly() {
        // Create a valid L-shape with three pieces
        let pieces = [
            TangramPiece(type: .square, transform: .identity),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 1, y: 0)),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 1, y: 1))
        ]
        
        let connections = [
            Connection(
                type: .edgeToEdge(pieceA: pieces[0].id, edgeA: 1, pieceB: pieces[1].id, edgeB: 3),
                constraint: Constraint(type: .fixed, affectedPieceId: pieces[1].id)
            ),
            Connection(
                type: .edgeToEdge(pieceA: pieces[1].id, edgeA: 2, pieceB: pieces[2].id, edgeB: 0),
                constraint: Constraint(type: .fixed, affectedPieceId: pieces[2].id)
            )
        ]
        
        XCTAssertTrue(validationService.isValidAssembly(pieces: pieces, connections: connections),
                     "L-shaped assembly should be valid")
    }
    
    func testInvalidAssemblyWithOverlap() {
        let pieces = [
            TangramPiece(type: .largeTriangle1, transform: .identity),
            TangramPiece(type: .largeTriangle2, transform: CGAffineTransform(translationX: 0.5, y: 0.5))
        ]
        
        XCTAssertFalse(validationService.isValidAssembly(pieces: pieces, connections: []),
                      "Overlapping pieces should make assembly invalid")
    }
    
    func testInvalidAssemblyWithUnexplainedContact() {
        let pieces = [
            TangramPiece(type: .square, transform: .identity),
            TangramPiece(type: .square, transform: CGAffineTransform(translationX: 1, y: 0))
        ]
        
        XCTAssertFalse(validationService.isValidAssembly(pieces: pieces, connections: []),
                      "Touching pieces without connection should be invalid")
    }
    
    func testInvalidAssemblyDisconnected() {
        let pieces = [
            TangramPiece(type: .smallTriangle1, transform: .identity),
            TangramPiece(type: .smallTriangle2, transform: CGAffineTransform(translationX: 10, y: 10))
        ]
        
        XCTAssertFalse(validationService.isValidAssembly(pieces: pieces, connections: []),
                      "Disconnected pieces should make assembly invalid")
    }
    
    // MARK: - Edge Cases
    
    func testRotatedPieceValidation() {
        let rotation = CGAffineTransform(rotationAngle: .pi / 4)
        let piece1 = TangramPiece(type: .square, transform: rotation)
        let piece2 = TangramPiece(
            type: .square,
            transform: rotation.translatedBy(x: sqrt(2), y: 0)
        )
        
        // Should still detect edge contact after rotation
        XCTAssertTrue(validationService.hasEdgeContact(pieceA: piece1, pieceB: piece2),
                     "Should detect edge contact in rotated pieces")
    }
    
    func testScaledPieceValidation() {
        // Note: Tangram pieces shouldn't be scaled in real usage,
        // but testing for robustness
        let piece1 = TangramPiece(type: .smallTriangle1, transform: .identity)
        let scaledTransform = CGAffineTransform(scaleX: 2, y: 2)
        let piece2 = TangramPiece(type: .smallTriangle1, transform: scaledTransform)
        
        // Scaled piece at origin will overlap with normal piece
        XCTAssertTrue(validationService.hasAreaOverlap(pieceA: piece1, pieceB: piece2),
                     "Scaled piece should be detected for overlap")
    }
    
    func testComplexTransformChain() {
        let transform = CGAffineTransform.identity
            .translatedBy(x: 5, y: 5)
            .rotated(by: .pi / 6)
            .translatedBy(x: -2, y: -2)
        
        let piece1 = TangramPiece(type: .parallelogram, transform: transform)
        let piece2 = TangramPiece(type: .square, transform: .identity)
        
        // Complex transform should still allow relationship detection
        let relationship = validationService.getGeometricRelationship(pieceA: piece1, pieceB: piece2)
        XCTAssertNotNil(relationship, "Should determine relationship with complex transform")
    }
}