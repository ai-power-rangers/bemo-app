//
//  ParallelogramValidationTest.swift
//  Bemo
//
//  Test file to verify parallelogram validation fixes
//

import Foundation
import CoreGraphics

/// Test helper to verify parallelogram index remapping
struct ParallelogramValidationTest {
    
    static func runTests() {
        print("=== Parallelogram Validation Tests ===")
        
        // Test vertex remapping
        testVertexRemapping()
        
        // Test edge remapping
        testEdgeRemapping()
        
        // Test validation connection creation
        testValidationConnectionCreation()
        
        print("=== All Tests Complete ===")
    }
    
    private static func testVertexRemapping() {
        print("\n--- Testing Vertex Remapping ---")
        
        // Test each vertex index
        let mappings = [
            (0, 1, "Vertex 0 → 1"),
            (1, 0, "Vertex 1 → 0"),
            (2, 3, "Vertex 2 → 3"),
            (3, 2, "Vertex 3 → 2")
        ]
        
        for (original, expected, description) in mappings {
            let remapped = TangramEditorCoordinateSystem.remapParallelogramVertexIndexForFlip(original)
            let passed = remapped == expected
            print("\(passed ? "✅" : "❌") \(description): \(original) → \(remapped) (expected \(expected))")
        }
    }
    
    private static func testEdgeRemapping() {
        print("\n--- Testing Edge Remapping ---")
        
        // Test each edge index
        let mappings = [
            (0, 0, "Edge 0 → 0"),
            (1, 3, "Edge 1 → 3"),
            (2, 2, "Edge 2 → 2"),
            (3, 1, "Edge 3 → 1")
        ]
        
        for (original, expected, description) in mappings {
            let remapped = TangramEditorCoordinateSystem.remapParallelogramEdgeIndexForFlip(original)
            let passed = remapped == expected
            print("\(passed ? "✅" : "❌") \(description): \(original) → \(remapped) (expected \(expected))")
        }
    }
    
    private static func testValidationConnectionCreation() {
        print("\n--- Testing Validation Connection Creation ---")
        
        // Simulate a flipped parallelogram scenario
        let testCases = [
            (
                name: "Vertex-to-Vertex (0→0)",
                originalPieceIndex: 0,
                isVertex: true,
                expectedRemapped: 1
            ),
            (
                name: "Edge-to-Edge (1→1)",
                originalPieceIndex: 1,
                isVertex: false,
                expectedRemapped: 3
            ),
            (
                name: "Vertex-to-Vertex (3→3)",
                originalPieceIndex: 3,
                isVertex: true,
                expectedRemapped: 2
            ),
            (
                name: "Edge-to-Edge (3→3)",
                originalPieceIndex: 3,
                isVertex: false,
                expectedRemapped: 1
            )
        ]
        
        for testCase in testCases {
            let remapped = testCase.isVertex 
                ? TangramEditorCoordinateSystem.remapParallelogramVertexIndexForFlip(testCase.originalPieceIndex)
                : TangramEditorCoordinateSystem.remapParallelogramEdgeIndexForFlip(testCase.originalPieceIndex)
            
            let passed = remapped == testCase.expectedRemapped
            print("\(passed ? "✅" : "❌") \(testCase.name): original=\(testCase.originalPieceIndex) → remapped=\(remapped) (expected \(testCase.expectedRemapped))")
        }
    }
}

// Note: To run these tests in the app, add this somewhere in your code:
// ParallelogramValidationTest.runTests()