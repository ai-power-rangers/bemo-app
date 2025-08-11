//
//  PipelineTransformAdapter.swift
//  Bemo
//
//  TEMPORARY: Adapter to fix pipeline puzzle transforms
//  TO REMOVE: Delete after pipeline is fixed
//

import Foundation
import CoreGraphics

struct PipelineTransformAdapter {
    
    /// Convert pipeline puzzle to work with existing rendering
    /// The issue: Pipeline transforms expect to operate on UNSCALED vertices
    /// but our renderer applies transforms to PRE-SCALED vertices
    static func adaptPipelinePuzzle(_ puzzle: GamePuzzleData) -> GamePuzzleData {
        // Only adapt puzzles from the "generated" category (pipeline puzzles)
        guard puzzle.category == "generated" else {
            return puzzle // Don't touch database puzzles!
        }
        
        // The pipeline transforms have the scale baked into the a,b,c,d components
        // We need to extract the scale and adjust the transform
        let visualScale: CGFloat = 50.0
        
        let adaptedPieces = puzzle.targetPieces.map { piece -> GamePuzzleData.TargetPiece in
            // Extract the rotation and scale from the transform
            let originalTransform = piece.transform
            
            // The pipeline transform expects to operate on normalized (0-2) vertices
            // but our renderer scales first then transforms
            // So we need to adjust the transform matrix
            
            // Scale the rotation components by visualScale
            let adjustedTransform = CGAffineTransform(
                a: originalTransform.a * visualScale,
                b: originalTransform.b * visualScale,
                c: originalTransform.c * visualScale,
                d: originalTransform.d * visualScale,
                tx: originalTransform.tx,  // tx/ty are already in visual scale
                ty: originalTransform.ty
            )
            
            return GamePuzzleData.TargetPiece(
                id: piece.id,
                pieceType: piece.pieceType,
                transform: adjustedTransform
            )
        }
        
        return GamePuzzleData(
            id: puzzle.id,
            name: puzzle.name,
            category: puzzle.category,
            difficulty: puzzle.difficulty,
            targetPieces: adaptedPieces
        )
    }
}

// Update the test data to use the adapter
extension AutomatedPipelineTestData {
    
    static func getCatPuzzleAdapted() -> GamePuzzleData {
        let original = getCatPuzzle()
        return PipelineTransformAdapter.adaptPipelinePuzzle(original)
    }
    
    static func getHousePuzzleAdapted() -> GamePuzzleData {
        let original = getHousePuzzle()
        return PipelineTransformAdapter.adaptPipelinePuzzle(original)
    }
}