//
//  TangramPieceGeometryTests.swift
//  BemoTests
//
//  Unit tests for tangram piece mathematical definitions
//

import XCTest
@testable import Bemo

class TangramPieceGeometryTests: XCTestCase {
    
    func testSmallTriangleGeometry() {
        let vertices = TangramPieceGeometry.vertices(for: .smallTriangle1)
        
        XCTAssertEqual(vertices.count, 3)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1], CGPoint(x: 1, y: 0))
        XCTAssertEqual(vertices[2], CGPoint(x: 0, y: 1))
        
        let area = TangramPieceGeometry.area(for: .smallTriangle1)
        XCTAssertEqual(area, 0.5, accuracy: 0.0001)
        
        let edges = TangramPieceGeometry.edges(for: .smallTriangle1)
        XCTAssertEqual(edges.count, 3)
        
        let edgeLengths = TangramPieceGeometry.edgeLengths(for: .smallTriangle1)
        XCTAssertEqual(edgeLengths[0], 1.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], 1.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], sqrt(2.0), accuracy: 0.0001)
        
        let angles = TangramPieceGeometry.angles(for: .smallTriangle1)
        XCTAssertEqual(angles, [90.0, 45.0, 45.0])
    }
    
    func testSquareGeometry() {
        let vertices = TangramPieceGeometry.vertices(for: .square)
        
        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1], CGPoint(x: 1, y: 0))
        XCTAssertEqual(vertices[2], CGPoint(x: 1, y: 1))
        XCTAssertEqual(vertices[3], CGPoint(x: 0, y: 1))
        
        let area = TangramPieceGeometry.area(for: .square)
        XCTAssertEqual(area, 1.0, accuracy: 0.0001)
        
        let edgeLengths = TangramPieceGeometry.edgeLengths(for: .square)
        XCTAssertEqual(edgeLengths, [1.0, 1.0, 1.0, 1.0])
        
        let angles = TangramPieceGeometry.angles(for: .square)
        XCTAssertEqual(angles, [90.0, 90.0, 90.0, 90.0])
    }
    
    func testMediumTriangleGeometry() {
        let vertices = TangramPieceGeometry.vertices(for: .mediumTriangle)
        let sqrt2 = sqrt(2.0)
        
        XCTAssertEqual(vertices.count, 3)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1].x, sqrt2, accuracy: 0.0001)
        XCTAssertEqual(vertices[1].y, 0, accuracy: 0.0001)
        XCTAssertEqual(vertices[2].x, 0, accuracy: 0.0001)
        XCTAssertEqual(vertices[2].y, sqrt2, accuracy: 0.0001)
        
        let area = TangramPieceGeometry.area(for: .mediumTriangle)
        XCTAssertEqual(area, 1.0, accuracy: 0.0001)
        
        let edgeLengths = TangramPieceGeometry.edgeLengths(for: .mediumTriangle)
        XCTAssertEqual(edgeLengths[0], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], 2.0, accuracy: 0.0001)
    }
    
    func testLargeTriangleGeometry() {
        let vertices = TangramPieceGeometry.vertices(for: .largeTriangle1)
        
        XCTAssertEqual(vertices.count, 3)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1], CGPoint(x: 2, y: 0))
        XCTAssertEqual(vertices[2], CGPoint(x: 0, y: 2))
        
        let area = TangramPieceGeometry.area(for: .largeTriangle1)
        XCTAssertEqual(area, 2.0, accuracy: 0.0001)
        
        let edgeLengths = TangramPieceGeometry.edgeLengths(for: .largeTriangle1)
        XCTAssertEqual(edgeLengths[0], 2.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], 2.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], 2.0 * sqrt(2.0), accuracy: 0.0001)
    }
    
    func testParallelogramGeometry() {
        let vertices = TangramPieceGeometry.vertices(for: .parallelogram)
        let sqrt2 = sqrt(2.0)
        let halfSqrt2 = sqrt2 / 2.0
        
        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1].x, sqrt2, accuracy: 0.0001)
        XCTAssertEqual(vertices[1].y, 0, accuracy: 0.0001)
        XCTAssertEqual(vertices[2].x, halfSqrt2, accuracy: 0.0001)
        XCTAssertEqual(vertices[2].y, halfSqrt2, accuracy: 0.0001)
        XCTAssertEqual(vertices[3].x, -halfSqrt2, accuracy: 0.0001)
        XCTAssertEqual(vertices[3].y, halfSqrt2, accuracy: 0.0001)
        
        let area = TangramPieceGeometry.area(for: .parallelogram)
        XCTAssertEqual(area, 1.0, accuracy: 0.0001)
        
        let edgeLengths = TangramPieceGeometry.edgeLengths(for: .parallelogram)
        XCTAssertEqual(edgeLengths[0], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], 1.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[3], 1.0, accuracy: 0.0001)
        
        let angles = TangramPieceGeometry.angles(for: .parallelogram)
        XCTAssertEqual(angles, [45.0, 135.0, 45.0, 135.0])
    }
    
    func testTotalAreaVerification() {
        XCTAssertTrue(TangramPieceGeometry.verifyTotalArea())
    }
    
    func testAllPieceTypes() {
        let allCases = TangramPieceGeometry.PieceType.allCases
        XCTAssertEqual(allCases.count, 7)
        
        for pieceType in allCases {
            let vertices = TangramPieceGeometry.vertices(for: pieceType)
            let edges = TangramPieceGeometry.edges(for: pieceType)
            let area = TangramPieceGeometry.area(for: pieceType)
            
            XCTAssertTrue(vertices.count >= 3)
            XCTAssertEqual(edges.count, vertices.count)
            XCTAssertTrue(area > 0)
            
            let centroid = TangramPieceGeometry.centroid(for: pieceType)
            XCTAssertNotEqual(centroid, CGPoint.zero)
            
            let boundingBox = TangramPieceGeometry.boundingBox(for: pieceType)
            XCTAssertTrue(boundingBox.width > 0)
            XCTAssertTrue(boundingBox.height > 0)
        }
    }
    
    func testEdgeStructure() {
        for pieceType in TangramPieceGeometry.PieceType.allCases {
            let edges = TangramPieceGeometry.edges(for: pieceType)
            let vertices = TangramPieceGeometry.vertices(for: pieceType)
            
            for edge in edges {
                XCTAssertTrue(edge.startVertex >= 0)
                XCTAssertTrue(edge.startVertex < vertices.count)
                XCTAssertTrue(edge.endVertex >= 0)
                XCTAssertTrue(edge.endVertex < vertices.count)
                XCTAssertTrue(edge.length > 0)
            }
        }
    }
}