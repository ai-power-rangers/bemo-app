//
//  AutomatedPipelineLoader.swift
//  Bemo
//
//  Loads and converts automated pipeline puzzle outputs for TangramCV game
//

// WHAT: Service to load automated pipeline JSON files and convert them to GamePuzzleData
// ARCHITECTURE: Service in MVVM-S pattern for loading automated puzzle generation outputs
// USAGE: Load JSON files from yiran-tests and visualize them in TangramCV game

import Foundation
import CoreGraphics

class AutomatedPipelineLoader {
    
    /// Load a puzzle from automated pipeline JSON file (synchronous for immediate loading)
    static func loadFromFile(at path: String) -> GamePuzzleData? {
        
        // Check if file exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            // Try relative to bundle
            if Bundle.main.path(forResource: "cat_fixed_separation", ofType: "json") != nil {
                // File exists in bundle but not at the specified path
            }
            return nil
        }
        
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let json = json else {
                return nil
            }
            
            let puzzle = convertPipelineFormat(json)
            if puzzle != nil {
            } else {
            }
            return puzzle
        } catch {
            return nil
        }
    }
    
    /// Convert automated pipeline format to GamePuzzleData
    static func convertPipelineFormat(_ json: [String: Any]) -> GamePuzzleData? {
        
        guard let id = json["id"] as? String else {
            return nil
        }
        guard let name = json["name"] as? String else {
            return nil
        }
        guard let category = json["category"] as? String else {
            return nil
        }
        guard let difficulty = json["difficulty"] as? String else {
            return nil
        }
        guard let pieces = json["pieces"] as? [[String: Any]] else {
            return nil
        }
        
        
        // Convert difficulty string to int
        let difficultyValue: Int = {
            switch difficulty.lowercased() {
            case "easy": return 1
            case "medium": return 2
            case "hard": return 3
            case "expert": return 4
            default: return 2
            }
        }()
        
        // Convert pieces
        let targetPieces = pieces.compactMap { pieceData -> GamePuzzleData.TargetPiece? in
            guard let type = pieceData["type"] as? String else {
                return nil
            }
            guard let pieceType = TangramPieceType(rawValue: type) else {
                return nil
            }
            guard let transform = pieceData["transform"] as? [String: Any] else {
                return nil
            }
            
            // Extract transform components
            let a = (transform["a"] as? NSNumber)?.doubleValue ?? 1.0
            let b = (transform["b"] as? NSNumber)?.doubleValue ?? 0.0
            let c = (transform["c"] as? NSNumber)?.doubleValue ?? 0.0
            let d = (transform["d"] as? NSNumber)?.doubleValue ?? 1.0
            let tx = (transform["tx"] as? NSNumber)?.doubleValue ?? 0.0
            let ty = (transform["ty"] as? NSNumber)?.doubleValue ?? 0.0
            
            let affineTransform = CGAffineTransform(
                a: CGFloat(a),
                b: CGFloat(b),
                c: CGFloat(c),
                d: CGFloat(d),
                tx: CGFloat(tx),
                ty: CGFloat(ty)
            )
            
            return GamePuzzleData.TargetPiece(
                pieceType: pieceType,
                transform: affineTransform
            )
        }
        
        
        guard targetPieces.count == 7 else {
            return nil
        }
        
        return GamePuzzleData(
            id: id,
            name: name,
            category: category,
            difficulty: difficultyValue,
            targetPieces: targetPieces
        )
    }
    
    /// Load the test puzzles - using embedded data due to iOS sandbox restrictions
    /// TEMPORARY: Using embedded data instead of files for iOS compatibility
    static func loadTestPuzzles() -> [GamePuzzleData] {
        
        // Use embedded test data since iOS apps can't access files outside their sandbox
        // Apply adapter to fix transform issues
        let puzzles = [
            PipelineTransformAdapter.adaptPipelinePuzzle(AutomatedPipelineTestData.getCatPuzzle()),
            PipelineTransformAdapter.adaptPipelinePuzzle(AutomatedPipelineTestData.getHousePuzzle())
        ]
        
        // Puzzles are ready to use
        
        return puzzles
    }
    
    /// Create mock CV output from automated pipeline puzzle
    static func generateMockCVOutput(from puzzle: GamePuzzleData) -> [String: Any] {
        let objects = puzzle.targetPieces.map { piece in
            // Map piece type to CV name
            let cvName: String = {
                switch piece.pieceType {
                case .square: return "tangram_square"
                case .smallTriangle1: return "tangram_triangle_sml"
                case .smallTriangle2: return "tangram_triangle_sml2"
                case .mediumTriangle: return "tangram_triangle_med"
                case .largeTriangle1: return "tangram_triangle_lrg"
                case .largeTriangle2: return "tangram_triangle_lrg2"
                case .parallelogram: return "tangram_parallelogram"
                }
            }()
            
            // Extract rotation from transform using scene-space rotation
            // CRITICAL: Use sceneRotation to match the Y-flipped rendering in the scene
            let rotation = TangramCVGeometry.sceneRotation(from: piece.transform) * 180.0 / .pi
            
            return [
                "name": cvName,
                "class_id": piece.pieceType.sortOrder,
                "pose": [
                    "rotation_degrees": rotation,
                    "translation": [piece.transform.tx, -piece.transform.ty] // Flip Y for CV
                ],
                "object_id": UUID().uuidString,
                "confidence": 1.0,
                "stability_ms": 1000.0
            ] as [String : Any]
        }
        
        return [
            "schema_version": 1,
            "homography": [
                [1.0, 0.0, 0.0],
                [0.0, 1.0, 0.0],
                [0.0, 0.0, 1.0]
            ],
            "homography_applied": true,
            "scale": 50.0, // Visual scale
            "objects": objects
        ]
    }
}

// MARK: - Extension to inject test puzzles into TangramCV
// TEMPORARY: This extension is for testing automated pipeline puzzles
// TO REMOVE: Delete this entire extension after validation

extension TangramCVGameViewModel {
    /// Load automated pipeline puzzles for testing
    /// TEMPORARY: Remove this method after pipeline validation
    func loadAutomatedPuzzles() {
        
        let testPuzzles = AutomatedPipelineLoader.loadTestPuzzles()
        
        if !testPuzzles.isEmpty {
            // Store test puzzles in our temporary array
            self.pipelineTestPuzzles = testPuzzles
        }
    }
}