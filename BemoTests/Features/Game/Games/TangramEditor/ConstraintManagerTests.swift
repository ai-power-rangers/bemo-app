//
//  ConstraintManagerTests.swift
//  BemoTests
//
//  Comprehensive unit tests for ConstraintManager
//

import XCTest
@testable import Bemo

class ConstraintManagerTests: XCTestCase {
    
    var constraintManager: ConstraintManager!
    
    override func setUp() {
        super.setUp()
        constraintManager = ConstraintManager()
    }
    
    // MARK: - Rotation Constraint Tests
    
    func testApplyRotationConstraint() {
        let initialTransform = CGAffineTransform.identity
        let rotationPoint = CGPoint(x: 1, y: 1)
        let rotationRange: ClosedRange<Double> = -Double.pi/4...Double.pi/4
        
        let constrained = constraintManager.applyRotationConstraint(
            transform: initialTransform,
            around: rotationPoint,
            range: rotationRange
        )
        
        let angle = atan2(constrained.b, constrained.a)
        XCTAssertLessThanOrEqual(angle, rotationRange.upperBound)
        XCTAssertGreaterThanOrEqual(angle, rotationRange.lowerBound)
    }
    
    func testRotationConstraintClamping() {
        // Test clamping to upper bound
        let overRotated = CGAffineTransform(rotationAngle: Double.pi)
        let range: ClosedRange<Double> = 0...Double.pi/2
        let vertex = CGPoint.zero
        
        let clamped = constraintManager.applyRotationConstraint(
            transform: overRotated,
            around: vertex,
            range: range
        )
        
        let angle = atan2(clamped.b, clamped.a)
        XCTAssertEqual(angle, range.upperBound, accuracy: 0.01,
                      "Should clamp to upper bound")
        
        // Test clamping to lower bound
        let underRotated = CGAffineTransform(rotationAngle: -Double.pi/2)
        let clamped2 = constraintManager.applyRotationConstraint(
            transform: underRotated,
            around: vertex,
            range: range
        )
        
        let angle2 = atan2(clamped2.b, clamped2.a)
        XCTAssertEqual(angle2, range.lowerBound, accuracy: 0.01,
                      "Should clamp to lower bound")
    }
    
    func testRotateAroundPoint() {
        let transform = CGAffineTransform.identity
        let point = CGPoint(x: 5, y: 5)
        let angle = Double.pi / 2
        
        let rotated = constraintManager.rotateAroundPoint(transform, angle: angle, point: point)
        
        // Test that a point at (6,5) rotates to (5,6) around (5,5)
        let testPoint = CGPoint(x: 6, y: 5)
        let rotatedPoint = testPoint.applying(rotated)
        
        XCTAssertEqual(rotatedPoint.x, 5, accuracy: 0.01)
        XCTAssertEqual(rotatedPoint.y, 6, accuracy: 0.01)
    }
    
    // MARK: - Translation Constraint Tests
    
    func testApplyTranslationConstraint() {
        let initialTransform = CGAffineTransform(translationX: 0.5, y: 0)
        let vector = CGVector(dx: 1, dy: 0)
        let range: ClosedRange<Double> = 0...2
        
        let constrained = constraintManager.applyTranslationConstraint(
            transform: initialTransform,
            along: vector,
            range: range
        )
        
        XCTAssertEqual(constrained.tx, 0.5, accuracy: 0.01)
        XCTAssertEqual(constrained.ty, 0, accuracy: 0.01)
    }
    
    func testTranslationConstraintClamping() {
        // Test clamping to maximum distance
        let farTransform = CGAffineTransform(translationX: 10, y: 0)
        let vector = CGVector(dx: 1, dy: 0)
        let range: ClosedRange<Double> = 0...5
        
        let clamped = constraintManager.applyTranslationConstraint(
            transform: farTransform,
            along: vector,
            range: range
        )
        
        XCTAssertEqual(clamped.tx, 5, accuracy: 0.01,
                      "Should clamp to maximum distance")
        
        // Test clamping to minimum distance
        let negativeTransform = CGAffineTransform(translationX: -5, y: 0)
        let clamped2 = constraintManager.applyTranslationConstraint(
            transform: negativeTransform,
            along: vector,
            range: range
        )
        
        XCTAssertEqual(clamped2.tx, 0, accuracy: 0.01,
                      "Should clamp to minimum distance")
    }
    
    func testTranslationAlongDiagonal() {
        let transform = CGAffineTransform(translationX: 1, y: 1)
        let diagonalVector = CGVector(dx: 1, dy: 1)
        let range: ClosedRange<Double> = 0...sqrt(8)
        
        let constrained = constraintManager.applyTranslationConstraint(
            transform: transform,
            along: diagonalVector,
            range: range
        )
        
        // Point should project onto diagonal
        let distance = sqrt(constrained.tx * constrained.tx + constrained.ty * constrained.ty)
        XCTAssertEqual(distance, sqrt(2), accuracy: 0.01)
        XCTAssertEqual(constrained.tx, constrained.ty, accuracy: 0.01,
                      "Should maintain diagonal alignment")
    }
    
    // MARK: - Multiple Constraints Tests
    
    func testApplyMultipleConstraints() {
        let transform = CGAffineTransform.identity
        let constraints = [
            Constraint(
                type: .rotation(around: CGPoint.zero, range: 0...Double.pi/4),
                affectedPieceId: "test"
            ),
            Constraint(
                type: .translation(along: CGVector(dx: 1, dy: 0), range: 0...2),
                affectedPieceId: "test"
            )
        ]
        
        let result = constraintManager.applyConstraints(transform, constraints: constraints)
        
        XCTAssertNotEqual(result, transform,
                         "Should apply multiple constraints")
    }
    
    func testFixedConstraint() {
        let transform = CGAffineTransform(translationX: 5, y: 5)
        let constraints = [
            Constraint(type: .fixed, affectedPieceId: "test")
        ]
        
        let result = constraintManager.applyConstraints(transform, constraints: constraints)
        
        XCTAssertEqual(result, transform,
                      "Fixed constraint should not change transform")
    }
    
    // MARK: - Validation Tests
    
    func testValidateTransformAgainstConstraints() {
        let validTransform = CGAffineTransform(rotationAngle: Double.pi/8)
        let constraints = [
            Constraint(
                type: .rotation(around: CGPoint.zero, range: 0...Double.pi/4),
                affectedPieceId: "test"
            )
        ]
        
        XCTAssertTrue(constraintManager.validateTransform(validTransform, against: constraints),
                     "Transform within constraints should be valid")
        
        let invalidTransform = CGAffineTransform(rotationAngle: Double.pi/2)
        XCTAssertFalse(constraintManager.validateTransform(invalidTransform, against: constraints),
                      "Transform outside constraints should be invalid")
    }
    
    func testValidateTranslationConstraint() {
        let transform = CGAffineTransform(translationX: 1.5, y: 0)
        let constraints = [
            Constraint(
                type: .translation(along: CGVector(dx: 1, dy: 0), range: 0...2),
                affectedPieceId: "test"
            )
        ]
        
        XCTAssertTrue(constraintManager.validateTransform(transform, against: constraints),
                     "Translation within range should be valid")
        
        let outOfRangeTransform = CGAffineTransform(translationX: 3, y: 0)
        XCTAssertFalse(constraintManager.validateTransform(outOfRangeTransform, against: constraints),
                      "Translation outside range should be invalid")
    }
    
    // MARK: - Edge Vector Tests
    
    func testEdgeVectorCalculation() {
        let start = CGPoint(x: 1, y: 1)
        let end = CGPoint(x: 4, y: 5)
        
        let vector = constraintManager.edgeVector(from: start, to: end)
        
        XCTAssertEqual(vector.dx, 3, accuracy: 0.01)
        XCTAssertEqual(vector.dy, 4, accuracy: 0.01)
    }
    
    func testParallelEdgeDetection() {
        let edge1 = CGVector(dx: 2, dy: 0)
        let edge2 = CGVector(dx: 4, dy: 0)
        
        XCTAssertTrue(constraintManager.areEdgesParallel(edge1, edge2),
                     "Parallel edges should be detected")
        
        let edge3 = CGVector(dx: 0, dy: 2)
        XCTAssertFalse(constraintManager.areEdgesParallel(edge1, edge3),
                      "Perpendicular edges should not be parallel")
        
        // Test anti-parallel
        let edge4 = CGVector(dx: -3, dy: 0)
        XCTAssertTrue(constraintManager.areEdgesParallel(edge1, edge4),
                     "Anti-parallel edges should be detected as parallel")
    }
    
    func testSlidingRangeCalculation() {
        // Same length edges - no sliding
        let range1 = constraintManager.calculateSlidingRange(edge1Length: 2.0, edge2Length: 2.0)
        XCTAssertEqual(range1.lowerBound, 0)
        XCTAssertEqual(range1.upperBound, 0)
        
        // Different length edges - can slide
        let range2 = constraintManager.calculateSlidingRange(edge1Length: 3.0, edge2Length: 1.0)
        XCTAssertEqual(range2.lowerBound, 0)
        XCTAssertEqual(range2.upperBound, 2.0, accuracy: 0.01)
        
        // Order shouldn't matter
        let range3 = constraintManager.calculateSlidingRange(edge1Length: 1.0, edge2Length: 3.0)
        XCTAssertEqual(range3.upperBound, 2.0, accuracy: 0.01)
    }
    
    func testAngleBetweenVectors() {
        let v1 = CGVector(dx: 1, dy: 0)
        let v2 = CGVector(dx: 0, dy: 1)
        
        let angle = constraintManager.angleBetweenVectors(v1, v2)
        XCTAssertEqual(angle, Double.pi/2, accuracy: 0.01,
                      "Should calculate 90 degrees between perpendicular vectors")
        
        let v3 = CGVector(dx: 1, dy: 1)
        let angle2 = constraintManager.angleBetweenVectors(v1, v3)
        XCTAssertEqual(angle2, Double.pi/4, accuracy: 0.01,
                      "Should calculate 45 degrees")
        
        let v4 = CGVector(dx: -1, dy: 0)
        let angle3 = constraintManager.angleBetweenVectors(v1, v4)
        XCTAssertEqual(abs(angle3), Double.pi, accuracy: 0.01,
                      "Should calculate 180 degrees for opposite vectors")
    }
    
    // MARK: - Complex Scenario Tests
    
    func testConstraintChaining() {
        // Test applying constraints that depend on each other
        let initialTransform = CGAffineTransform.identity
        
        // First rotate around a point
        let rotated = constraintManager.rotateAroundPoint(
            initialTransform,
            angle: Double.pi/4,
            point: CGPoint(x: 1, y: 0)
        )
        
        // Then apply translation constraint
        let translationConstraint = Constraint(
            type: .translation(along: CGVector(dx: 1, dy: 1), range: 0...2),
            affectedPieceId: "test"
        )
        
        let final = constraintManager.applyConstraints(
            rotated,
            constraints: [translationConstraint]
        )
        
        XCTAssertNotEqual(final, initialTransform,
                         "Chained constraints should produce different transform")
    }
    
    func testConstraintWithComplexTransform() {
        let complexTransform = CGAffineTransform.identity
            .translatedBy(x: 5, y: 3)
            .rotated(by: Double.pi/6)
            .translatedBy(x: -2, y: 1)
        
        let constraint = Constraint(
            type: .rotation(around: CGPoint(x: 3, y: 3), range: 0...Double.pi/3),
            affectedPieceId: "test"
        )
        
        let result = constraintManager.applyConstraints(
            complexTransform,
            constraints: [constraint]
        )
        
        // Should preserve translation but adjust rotation
        XCTAssertEqual(result.tx, complexTransform.tx, accuracy: 0.01,
                      "Should preserve translation component")
        XCTAssertEqual(result.ty, complexTransform.ty, accuracy: 0.01,
                      "Should preserve translation component")
    }
    
    func testZeroRangeConstraints() {
        // Test constraints with zero range (effectively fixed)
        let transform = CGAffineTransform(translationX: 1, y: 1)
        
        let zeroRotation = Constraint(
            type: .rotation(around: CGPoint.zero, range: 0...0),
            affectedPieceId: "test"
        )
        
        let result = constraintManager.applyConstraints(transform, constraints: [zeroRotation])
        
        let angle = atan2(result.b, result.a)
        XCTAssertEqual(angle, 0, accuracy: 0.01,
                      "Zero range rotation should force angle to 0")
        
        let zeroTranslation = Constraint(
            type: .translation(along: CGVector(dx: 1, dy: 0), range: 0...0),
            affectedPieceId: "test"
        )
        
        let result2 = constraintManager.applyConstraints(transform, constraints: [zeroTranslation])
        XCTAssertEqual(result2.tx, 0, accuracy: 0.01,
                      "Zero range translation should force position to origin")
    }
}