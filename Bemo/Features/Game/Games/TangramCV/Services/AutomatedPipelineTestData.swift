//
//  AutomatedPipelineTestData.swift
//  Bemo
//
//  TEMPORARY: Embedded test data for pipeline validation
//  TO REMOVE: Delete this entire file after validation
//

import Foundation
import CoreGraphics

// MARK: - TEMPORARY TEST DATA - REMOVE AFTER VALIDATION
struct AutomatedPipelineTestData {
    
    static func getCatPuzzle() -> GamePuzzleData {
        return GamePuzzleData(
            id: "2855def8-2022-47df-bbaf-ad4313deedf4",
            name: "Cat (Pipeline Test)",
            category: "generated",
            difficulty: 2,
            targetPieces: [
                GamePuzzleData.TargetPiece(
                    id: "cat_mediumTriangle",
                    pieceType: .mediumTriangle,
                    transform: CGAffineTransform(a: 0.01863, b: -0.999826, c: 0.999826, d: 0.01863, tx: 277.67, ty: 281.33)
                ),
                GamePuzzleData.TargetPiece(
                    id: "cat_largeTriangle2",
                    pieceType: .largeTriangle2,
                    transform: CGAffineTransform(a: 0.006135, b: -0.999981, c: 0.999981, d: 0.006135, tx: 401.22, ty: 165.75)
                ),
                GamePuzzleData.TargetPiece(
                    id: "cat_square",
                    pieceType: .square,
                    transform: CGAffineTransform(a: 0.718988, b: 0.695022, c: -0.695022, d: 0.718988, tx: 279.34, ty: 398.83)
                ),
                GamePuzzleData.TargetPiece(
                    id: "cat_largeTriangle1",
                    pieceType: .largeTriangle1,
                    transform: CGAffineTransform(a: 0.00862, b: -0.999963, c: 0.999963, d: 0.00862, tx: 346.67, ty: 247.67)
                ),
                GamePuzzleData.TargetPiece(
                    id: "cat_smallTriangle2",
                    pieceType: .smallTriangle2,
                    transform: CGAffineTransform(a: 0.026539, b: -0.999648, c: 0.999648, d: 0.026539, tx: 317.67, ty: 460.33)
                ),
                GamePuzzleData.TargetPiece(
                    id: "cat_smallTriangle1",
                    pieceType: .smallTriangle1,
                    transform: CGAffineTransform(a: 0.027512, b: -0.999621, c: 0.999621, d: 0.027512, tx: 239.33, ty: 460.67)
                ),
                GamePuzzleData.TargetPiece(
                    id: "cat_parallelogram",
                    pieceType: .parallelogram,
                    transform: CGAffineTransform(a: 0.863469, b: 0.504402, c: -0.504402, d: 0.863469, tx: 516.88, ty: 177.2)
                )
            ]
        )
    }
    
    static func getHousePuzzle() -> GamePuzzleData {
        return GamePuzzleData(
            id: "5e18d2b5-ac02-4f20-a511-3287cf7e4c99",
            name: "House (Pipeline Test)",
            category: "generated",
            difficulty: 2,
            targetPieces: [
                GamePuzzleData.TargetPiece(
                    id: "house_largeTriangle1",
                    pieceType: .largeTriangle1,
                    transform: CGAffineTransform(a: 0.999979, b: -0.006515, c: 0.006515, d: 0.999979, tx: 322.67, ty: 259.67)
                ),
                GamePuzzleData.TargetPiece(
                    id: "house_parallelogram",
                    pieceType: .parallelogram,
                    transform: CGAffineTransform(a: -0.703748, b: 0.71045, c: -0.71045, d: -0.703748, tx: 487.33, ty: 261.92)
                ),
                GamePuzzleData.TargetPiece(
                    id: "house_smallTriangle1",
                    pieceType: .smallTriangle1,
                    transform: CGAffineTransform(a: 0.999907, b: -0.013604, c: 0.013604, d: 0.999907, tx: 483.33, ty: 175.67)
                ),
                GamePuzzleData.TargetPiece(
                    id: "house_square",
                    pieceType: .square,
                    transform: CGAffineTransform(a: 0.009174, b: 0.999958, c: -0.999958, d: 0.009174, tx: 432.0, ty: 377.0)
                ),
                GamePuzzleData.TargetPiece(
                    id: "house_smallTriangle2",
                    pieceType: .smallTriangle2,
                    transform: CGAffineTransform(a: 0.013422, b: -0.99991, c: 0.99991, d: 0.013422, tx: 539.33, ty: 121.33)
                ),
                GamePuzzleData.TargetPiece(
                    id: "house_largeTriangle2",
                    pieceType: .largeTriangle2,
                    transform: CGAffineTransform(a: 0.999979, b: -0.006536, c: 0.006536, d: 0.999979, tx: 405.33, ty: 92.67)
                ),
                GamePuzzleData.TargetPiece(
                    id: "house_mediumTriangle",
                    pieceType: .mediumTriangle,
                    transform: CGAffineTransform(a: -0.707107, b: -0.707107, c: 0.707107, d: -0.707107, tx: 298.0, ty: 150.0)
                )
            ]
        )
    }
}