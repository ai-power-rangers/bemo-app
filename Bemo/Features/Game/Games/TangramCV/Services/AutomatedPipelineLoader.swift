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
        print("🔍 Attempting to load file: \(path)")
        
        // Check if file exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            print("❌ File does not exist at path: \(path)")
            // Try relative to bundle
            if let bundlePath = Bundle.main.path(forResource: "cat_fixed_separation", ofType: "json") {
                print("Found in bundle: \(bundlePath)")
            }
            return nil
        }
        
        do {
            let url = URL(fileURLWithPath: path)
            print("📁 File URL: \(url)")
            let data = try Data(contentsOf: url)
            print("✅ File loaded, size: \(data.count) bytes")
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let json = json else {
                print("❌ Failed to parse JSON from file: \(path)")
                return nil
            }
            
            print("📄 JSON parsed successfully")
            let puzzle = convertPipelineFormat(json)
            if puzzle != nil {
                print("✅ Puzzle converted successfully")
            } else {
                print("❌ Failed to convert puzzle format")
            }
            return puzzle
        } catch {
            print("❌ Error loading pipeline file: \(error)")
            print("   Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Convert automated pipeline format to GamePuzzleData
    static func convertPipelineFormat(_ json: [String: Any]) -> GamePuzzleData? {
        print("🔄 Converting pipeline format...")
        print("  Keys in JSON: \(json.keys.sorted())")
        
        guard let id = json["id"] as? String else {
            print("❌ Missing or invalid 'id' field")
            return nil
        }
        guard let name = json["name"] as? String else {
            print("❌ Missing or invalid 'name' field")
            return nil
        }
        guard let category = json["category"] as? String else {
            print("❌ Missing or invalid 'category' field")
            return nil
        }
        guard let difficulty = json["difficulty"] as? String else {
            print("❌ Missing or invalid 'difficulty' field")
            return nil
        }
        guard let pieces = json["pieces"] as? [[String: Any]] else {
            print("❌ Missing or invalid 'pieces' field")
            print("  pieces type: \(type(of: json["pieces"]))")
            return nil
        }
        
        print("  Found puzzle: \(name), category: \(category), difficulty: \(difficulty)")
        print("  Pieces count: \(pieces.count)")
        
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
        print("  Converting \(pieces.count) pieces...")
        let targetPieces = pieces.compactMap { pieceData -> GamePuzzleData.TargetPiece? in
            guard let type = pieceData["type"] as? String else {
                print("    ❌ Piece missing 'type' field")
                return nil
            }
            guard let pieceType = TangramPieceType(rawValue: type) else {
                print("    ❌ Unknown piece type: \(type)")
                print("    Valid types: \(TangramPieceType.allCases.map { $0.rawValue })")
                return nil
            }
            guard let transform = pieceData["transform"] as? [String: Any] else {
                print("    ❌ Piece missing 'transform' field")
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
            
            print("    ✅ Converted piece: \(pieceType.rawValue)")
            return GamePuzzleData.TargetPiece(
                pieceType: pieceType,
                transform: affineTransform
            )
        }
        
        print("  Total pieces converted: \(targetPieces.count) out of \(pieces.count)")
        
        guard targetPieces.count == 7 else {
            print("Invalid number of pieces: \(targetPieces.count), expected 7")
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
        print("📦 Loading embedded pipeline test puzzles...")
        
        // Use embedded test data since iOS apps can't access files outside their sandbox
        // Apply adapter to fix transform issues
        let puzzles = [
            PipelineTransformAdapter.adaptPipelinePuzzle(AutomatedPipelineTestData.getCatPuzzle()),
            PipelineTransformAdapter.adaptPipelinePuzzle(AutomatedPipelineTestData.getHousePuzzle())
        ]
        
        for puzzle in puzzles {
            print("✅ Loaded automated puzzle: \(puzzle.name)")
        }
        
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
        print("🚀 Starting automated pipeline puzzle loading...")
        
        let testPuzzles = AutomatedPipelineLoader.loadTestPuzzles()
        
        if !testPuzzles.isEmpty {
            // Store test puzzles in our temporary array
            self.pipelineTestPuzzles = testPuzzles
            
            print("============================================================")
            print("🎮 AUTOMATED PIPELINE TEST PUZZLES LOADED")
            print("============================================================")
            for puzzle in testPuzzles {
                print("  ✅ \(puzzle.name) (Category: \(puzzle.category))")
            }
            print("============================================================")
            print("These puzzles are now visible in the puzzle library")
            print("Look for puzzles with category 'generated'")
            print("============================================================")
        } else {
            print("⚠️ No pipeline test puzzles were loaded")
        }
    }
}