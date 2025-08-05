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
        let vertices = TangramGeometry.vertices(for: .smallTriangle1)
        
        XCTAssertEqual(vertices.count, 3)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1], CGPoint(x: 1, y: 0))
        XCTAssertEqual(vertices[2], CGPoint(x: 0, y: 1))
        
        let area = TangramGeometry.area(for: .smallTriangle1)
        XCTAssertEqual(area, 0.5, accuracy: 0.0001)
        
        let edges = TangramGeometry.edges(for: .smallTriangle1)
        XCTAssertEqual(edges.count, 3)
        
        let edgeLengths = TangramGeometry.edgeLengths(for: .smallTriangle1)
        XCTAssertEqual(edgeLengths[0], 1.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], 1.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], sqrt(2.0), accuracy: 0.0001)
        
        let angles = TangramGeometry.angles(for: .smallTriangle1)
        XCTAssertEqual(angles, [90.0, 45.0, 45.0])
    }
    
    func testSquareGeometry() {
        let vertices = TangramGeometry.vertices(for: .square)
        
        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1], CGPoint(x: 1, y: 0))
        XCTAssertEqual(vertices[2], CGPoint(x: 1, y: 1))
        XCTAssertEqual(vertices[3], CGPoint(x: 0, y: 1))
        
        let area = TangramGeometry.area(for: .square)
        XCTAssertEqual(area, 1.0, accuracy: 0.0001)
        
        let edgeLengths = TangramGeometry.edgeLengths(for: .square)
        XCTAssertEqual(edgeLengths, [1.0, 1.0, 1.0, 1.0])
        
        let angles = TangramGeometry.angles(for: .square)
        XCTAssertEqual(angles, [90.0, 90.0, 90.0, 90.0])
    }
    
    func testMediumTriangleGeometry() {
        let vertices = TangramGeometry.vertices(for: .mediumTriangle)
        let sqrt2 = sqrt(2.0)
        
        XCTAssertEqual(vertices.count, 3)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1].x, sqrt2, accuracy: 0.0001)
        XCTAssertEqual(vertices[1].y, 0, accuracy: 0.0001)
        XCTAssertEqual(vertices[2].x, 0, accuracy: 0.0001)
        XCTAssertEqual(vertices[2].y, sqrt2, accuracy: 0.0001)
        
        let area = TangramGeometry.area(for: .mediumTriangle)
        XCTAssertEqual(area, 1.0, accuracy: 0.0001)
        
        let edgeLengths = TangramGeometry.edgeLengths(for: .mediumTriangle)
        XCTAssertEqual(edgeLengths[0], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], 2.0, accuracy: 0.0001)
    }
    
    func testLargeTriangleGeometry() {
        let vertices = TangramGeometry.vertices(for: .largeTriangle1)
        
        XCTAssertEqual(vertices.count, 3)
        XCTAssertEqual(vertices[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(vertices[1], CGPoint(x: 2, y: 0))
        XCTAssertEqual(vertices[2], CGPoint(x: 0, y: 2))
        
        let area = TangramGeometry.area(for: .largeTriangle1)
        XCTAssertEqual(area, 2.0, accuracy: 0.0001)
        
        let edgeLengths = TangramGeometry.edgeLengths(for: .largeTriangle1)
        XCTAssertEqual(edgeLengths[0], 2.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], 2.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], 2.0 * sqrt(2.0), accuracy: 0.0001)
    }
    
    func testParallelogramGeometry() {
        let vertices = TangramGeometry.vertices(for: .parallelogram)
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
        
        let area = TangramGeometry.area(for: .parallelogram)
        XCTAssertEqual(area, 1.0, accuracy: 0.0001)
        
        let edgeLengths = TangramGeometry.edgeLengths(for: .parallelogram)
        XCTAssertEqual(edgeLengths[0], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[1], 1.0, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[2], sqrt2, accuracy: 0.0001)
        XCTAssertEqual(edgeLengths[3], 1.0, accuracy: 0.0001)
        
        let angles = TangramGeometry.angles(for: .parallelogram)
        XCTAssertEqual(angles, [45.0, 135.0, 45.0, 135.0])
    }
    
    func testTotalAreaVerification() {
        XCTAssertTrue(TangramGeometry.verifyTotalArea())
    }
    
    func testAllPieceTypes() {
        let allCases = PieceType.allCases
        XCTAssertEqual(allCases.count, 7)
        
        for pieceType in allCases {
            let vertices = TangramGeometry.vertices(for: pieceType)
            let edges = TangramGeometry.edges(for: pieceType)
            let area = TangramGeometry.area(for: pieceType)
            
            XCTAssertTrue(vertices.count >= 3)
            XCTAssertEqual(edges.count, vertices.count)
            XCTAssertTrue(area > 0)
            
            let centroid = TangramGeometry.centroid(for: pieceType)
            XCTAssertNotEqual(centroid, CGPoint.zero)
            
            let boundingBox = TangramGeometry.boundingBox(for: pieceType)
            XCTAssertTrue(boundingBox.width > 0)
            XCTAssertTrue(boundingBox.height > 0)
        }
    }
    
    func testEdgeStructure() {
        for pieceType in PieceType.allCases {
            let edges = TangramGeometry.edges(for: pieceType)
            let vertices = TangramGeometry.vertices(for: pieceType)
            
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