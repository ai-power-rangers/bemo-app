//
//  GeometryEngineTests.swift
//  BemoTests
//
//  Unit tests for geometry calculations and transformations
//

import XCTest
@testable import Bemo

class GeometryEngineTests: XCTestCase {
    
    func testTransformVertices() {
        let vertices = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ]
        
        let translation = CGAffineTransform(translationX: 5, y: 5)
        let transformed = GeometryEngine.transformVertices(vertices, with: translation)
        
        XCTAssertEqual(transformed[0], CGPoint(x: 5, y: 5))
        XCTAssertEqual(transformed[1], CGPoint(x: 6, y: 5))
        XCTAssertEqual(transformed[2], CGPoint(x: 5, y: 6))
    }
    
    func testDistance() {
        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: 3, y: 4)
        
        let distance = GeometryEngine.distance(from: p1, to: p2)
        XCTAssertEqual(distance, 5.0, accuracy: 0.0001)
    }
    
    func testAngleCalculation() {
        let vertex = CGPoint(x: 0, y: 0)
        let p1 = CGPoint(x: 1, y: 0)
        let p2 = CGPoint(x: 0, y: 1)
        
        let angle = GeometryEngine.angle(from: p1, vertex: vertex, to: p2)
        XCTAssertEqual(angle, 90.0, accuracy: 0.1)
    }
    
    func testNormalizeAngle() {
        XCTAssertEqual(GeometryEngine.normalizeAngle(0), 0)
        XCTAssertEqual(GeometryEngine.normalizeAngle(360), 0)
        XCTAssertEqual(GeometryEngine.normalizeAngle(-90), 270)
        XCTAssertEqual(GeometryEngine.normalizeAngle(450), 90)
    }
    
    func testPointsEqual() {
        let p1 = CGPoint(x: 1.0, y: 1.0)
        let p2 = CGPoint(x: 1.00001, y: 0.99999)
        let p3 = CGPoint(x: 2.0, y: 2.0)
        
        XCTAssertTrue(GeometryEngine.pointsEqual(p1, p2))
        XCTAssertFalse(GeometryEngine.pointsEqual(p1, p3))
    }
    
    func testLineSegmentIntersection() {
        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: 10, y: 10)
        let p3 = CGPoint(x: 0, y: 10)
        let p4 = CGPoint(x: 10, y: 0)
        
        let intersection = GeometryEngine.lineSegmentIntersection(p1, p2, p3, p4)
        XCTAssertNotNil(intersection)
        XCTAssertEqual(intersection!.x, 5.0, accuracy: 0.0001)
        XCTAssertEqual(intersection!.y, 5.0, accuracy: 0.0001)
        
        let p5 = CGPoint(x: 0, y: 0)
        let p6 = CGPoint(x: 5, y: 0)
        let p7 = CGPoint(x: 0, y: 5)
        let p8 = CGPoint(x: 5, y: 5)
        
        let noIntersection = GeometryEngine.lineSegmentIntersection(p5, p6, p7, p8)
        XCTAssertNil(noIntersection)
    }
    
    func testPolygonContainsPoint() {
        let square = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]
        
        XCTAssertTrue(GeometryEngine.polygonContainsPoint(CGPoint(x: 0.5, y: 0.5), vertices: square))
        XCTAssertFalse(GeometryEngine.polygonContainsPoint(CGPoint(x: 2, y: 2), vertices: square))
        XCTAssertTrue(GeometryEngine.polygonContainsPoint(CGPoint(x: 0.1, y: 0.1), vertices: square))
    }
    
    func testPolygonArea() {
        let square = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]
        
        let area = GeometryEngine.polygonArea(square)
        XCTAssertEqual(area, 1.0, accuracy: 0.0001)
        
        let triangle = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: 2)
        ]
        
        let triangleArea = GeometryEngine.polygonArea(triangle)
        XCTAssertEqual(triangleArea, 2.0, accuracy: 0.0001)
    }
    
    func testPolygonsOverlap() {
        let square1 = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]
        
        let square2 = [
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 1.5, y: 0.5),
            CGPoint(x: 1.5, y: 1.5),
            CGPoint(x: 0.5, y: 1.5)
        ]
        
        let square3 = [
            CGPoint(x: 2, y: 2),
            CGPoint(x: 3, y: 2),
            CGPoint(x: 3, y: 3),
            CGPoint(x: 2, y: 3)
        ]
        
        XCTAssertTrue(GeometryEngine.polygonsOverlap(square1, square2))
        XCTAssertFalse(GeometryEngine.polygonsOverlap(square1, square3))
    }
    
    func testRotationMatrix() {
        let rotation = GeometryEngine.rotationMatrix(angle: 90)
        let point = CGPoint(x: 1, y: 0)
        let rotated = point.applying(rotation)
        
        XCTAssertEqual(rotated.x, 0, accuracy: 0.0001)
        XCTAssertEqual(rotated.y, 1, accuracy: 0.0001)
    }
    
    func testExtractRotation() {
        let angle = 45.0
        let rotation = GeometryEngine.rotationMatrix(angle: angle)
        let extracted = GeometryEngine.extractRotation(from: rotation)
        
        XCTAssertEqual(extracted, angle, accuracy: 0.0001)
    }
    
    func testProjectPointOntoLine() {
        let lineStart = CGPoint(x: 0, y: 0)
        let lineEnd = CGPoint(x: 10, y: 0)
        let point = CGPoint(x: 5, y: 5)
        
        let projection = GeometryEngine.projectPointOntoLine(point, lineStart: lineStart, lineEnd: lineEnd)
        XCTAssertEqual(projection, CGPoint(x: 5, y: 0))
        
        let point2 = CGPoint(x: -5, y: 5)
        let projection2 = GeometryEngine.projectPointOntoLine(point2, lineStart: lineStart, lineEnd: lineEnd)
        XCTAssertEqual(projection2, CGPoint(x: 0, y: 0))
    }
    
    func testDistanceFromPointToLine() {
        let lineStart = CGPoint(x: 0, y: 0)
        let lineEnd = CGPoint(x: 10, y: 0)
        let point = CGPoint(x: 5, y: 5)
        
        let distance = GeometryEngine.distanceFromPointToLine(point, lineStart: lineStart, lineEnd: lineEnd)
        XCTAssertEqual(distance, 5.0, accuracy: 0.0001)
    }
    
    func testEdgeAlignTransform() {
        let pieceVertices = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ]
        
        let targetStart = CGPoint(x: 5, y: 5)
        let targetEnd = CGPoint(x: 6, y: 5)
        
        let transform = GeometryEngine.edgeAlignTransform(
            pieceVertices: pieceVertices,
            edgeStartIndex: 0,
            targetEdgeStart: targetStart,
            targetEdgeEnd: targetEnd
        )
        
        let transformed = pieceVertices[0].applying(transform)
        XCTAssertEqual(transformed.x, targetStart.x, accuracy: 0.0001)
        XCTAssertEqual(transformed.y, targetStart.y, accuracy: 0.0001)
    }
}