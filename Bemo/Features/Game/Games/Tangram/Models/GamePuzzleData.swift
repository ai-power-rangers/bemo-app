//
//  GamePuzzleData.swift
//  Bemo
//
//  Simplified puzzle data model for Tangram gameplay
//

// WHAT: Self-contained puzzle representation with full transform data for accurate rendering
// ARCHITECTURE: Model in MVVM-S, stores complete piece transforms for SpriteKit rendering
// USAGE: Stores puzzle solution with CGAffineTransform for each piece

import Foundation
import CoreGraphics

/// Self-contained puzzle data for gameplay - no editor dependencies
struct GamePuzzleData: Codable, Equatable {
    let id: String
    let name: String
    let category: String
    let difficulty: Int
    let targetPieces: [TargetPiece]
    
    /// A target piece with full transform data for accurate rendering
    struct TargetPiece: Equatable {
        let pieceType: TangramPieceType
        let transform: CGAffineTransform  // Full transform matrix for exact positioning
        
        /// Computed position from transform (translation components)
        var position: CGPoint {
            CGPoint(x: transform.tx, y: transform.ty)
        }
        
        /// Computed rotation in degrees from transform
        var rotation: Double {
            atan2(Double(transform.b), Double(transform.a)) * 180.0 / .pi
        }
        
        /// Check if a placed piece matches this target within tolerances
        func matches(_ placed: PlacedPiece) -> Bool {
            guard placed.pieceType == pieceType else { return false }
            
            // Get transformed vertices for both pieces
            let targetVertices = getTransformedVertices()
            let placedVertices = getPlacedPieceVertices(placed)
            
            // Check if vertices match within tolerance
            return verticesMatch(targetVertices, placedVertices, tolerance: TangramGameConstants.positionTolerance)
        }
        
        /// Get vertices transformed to world position
        private func getTransformedVertices() -> [CGPoint] {
            let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
            let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
            return TangramGameGeometry.transformVertices(scaledVertices, with: transform)
        }
        
        /// Get vertices for a placed piece
        private func getPlacedPieceVertices(_ placed: PlacedPiece) -> [CGPoint] {
            let normalizedVertices = TangramGameGeometry.normalizedVertices(for: placed.pieceType)
            let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
            
            // Create transform from placed piece position and rotation
            var pieceTransform = CGAffineTransform.identity
            pieceTransform = pieceTransform.rotated(by: placed.rotation * .pi / 180)
            pieceTransform = pieceTransform.translatedBy(x: placed.position.x, y: placed.position.y)
            
            return TangramGameGeometry.transformVertices(scaledVertices, with: pieceTransform)
        }
        
        /// Check if two sets of vertices match within tolerance
        private func verticesMatch(_ vertices1: [CGPoint], _ vertices2: [CGPoint], tolerance: CGFloat) -> Bool {
            guard vertices1.count == vertices2.count else { return false }
            
            for i in 0..<vertices1.count {
                let distance = hypot(vertices1[i].x - vertices2[i].x, vertices1[i].y - vertices2[i].y)
                if distance > tolerance { return false }
            }
            return true
        }
    }
    
    /// Create from raw puzzle data (from database or JSON)
    /// NOTE: This preserves the full transform matrix for accurate rendering
    init(fromDatabaseData data: Any) {
        // For now, create a test puzzle until we implement proper database loading
        // This will be replaced with actual database parsing
        let testPuzzle = Self.createTestPuzzle()
        self.id = testPuzzle.id
        self.name = testPuzzle.name
        self.category = testPuzzle.category
        self.difficulty = testPuzzle.difficulty
        self.targetPieces = testPuzzle.targetPieces
    }
    
    /// Create from simplified data (for testing or bundled puzzles)
    init(id: String, name: String, category: String, difficulty: Int, targetPieces: [TargetPiece]) {
        self.id = id
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.targetPieces = targetPieces
    }
    
    /// Create a test puzzle with a simple shape
    static func createTestPuzzle() -> GamePuzzleData {
        // Create a simple test puzzle with 3 pieces forming a triangle
        let pieces = [
            TargetPiece(
                pieceType: .largeTriangle1,
                transform: CGAffineTransform(translationX: 100, y: 100)
            ),
            TargetPiece(
                pieceType: .largeTriangle2,
                transform: CGAffineTransform(translationX: 200, y: 100)
                    .rotated(by: .pi / 2)
            ),
            TargetPiece(
                pieceType: .square,
                transform: CGAffineTransform(translationX: 150, y: 150)
            )
        ]
        
        return GamePuzzleData(
            id: "test-puzzle",
            name: "Test Triangle",
            category: "Test",
            difficulty: 1,
            targetPieces: pieces
        )
    }
}

// MARK: - Codable Support for CGAffineTransform

extension GamePuzzleData.TargetPiece: Codable {
    enum CodingKeys: String, CodingKey {
        case pieceType
        case transform
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pieceType = try container.decode(TangramPieceType.self, forKey: .pieceType)
        
        // Decode CGAffineTransform components
        let transformData = try container.decode(TransformData.self, forKey: .transform)
        transform = CGAffineTransform(
            a: transformData.a,
            b: transformData.b,
            c: transformData.c,
            d: transformData.d,
            tx: transformData.tx,
            ty: transformData.ty
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pieceType, forKey: .pieceType)
        
        // Encode CGAffineTransform components
        let transformData = TransformData(
            a: transform.a,
            b: transform.b,
            c: transform.c,
            d: transform.d,
            tx: transform.tx,
            ty: transform.ty
        )
        try container.encode(transformData, forKey: .transform)
    }
    
    // Helper struct to make CGAffineTransform codable
    private struct TransformData: Codable {
        let a: CGFloat
        let b: CGFloat
        let c: CGFloat
        let d: CGFloat
        let tx: CGFloat
        let ty: CGFloat
    }
}

/// Progress tracking for a puzzle being solved
struct GameProgress {
    let puzzleId: String
    var correctPieces: Set<String> // PieceType rawValues that are correctly placed
    var totalPieces: Int
    var hintsUsed: Int = 0
    var startTime: Date
    var lastProgressTime: Date
    
    var progressPercentage: Double {
        guard totalPieces > 0 else { return 0 }
        return Double(correctPieces.count) / Double(totalPieces)
    }
    
    var isComplete: Bool {
        correctPieces.count == totalPieces
    }
    
    var timeSinceLastProgress: TimeInterval {
        Date().timeIntervalSince(lastProgressTime)
    }
    
    mutating func markPieceCorrect(_ pieceType: TangramPieceType) {
        correctPieces.insert(pieceType.rawValue)
        lastProgressTime = Date()
    }
    
    mutating func markPieceIncorrect(_ pieceType: TangramPieceType) {
        correctPieces.remove(pieceType.rawValue)
    }
}