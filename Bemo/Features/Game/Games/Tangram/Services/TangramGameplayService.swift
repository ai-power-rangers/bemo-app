//
//  TangramGameplayService.swift
//  Bemo
//
//  Core game logic service for Tangram puzzle gameplay
//

// WHAT: Business logic for Tangram game mechanics, validation, and state management
// ARCHITECTURE: Service in MVVM-S pattern, handles all game logic
// USAGE: Injected into scene and view models for game logic operations

import Foundation
import CoreGraphics
import SpriteKit

/// Service handling all Tangram gameplay business logic
class TangramGameplayService {
    
    // MARK: - Properties
    
    private let pieceValidator: TangramPieceValidator
    
    // MARK: - Initialization
    
    init(pieceValidator: TangramPieceValidator = TangramPieceValidator()) {
        self.pieceValidator = pieceValidator
    }
    
    // MARK: - Validation Logic
    
    /// Validates piece placement against target
    func validatePiecePlacement(
        piecePosition: CGPoint,
        pieceRotation: CGFloat,
        pieceType: TangramPieceType,
        isFlipped: Bool,
        targetTransform: CGAffineTransform,
        targetWorldPos: CGPoint
    ) -> TangramPieceValidator.ValidationResult {
        return pieceValidator.validateForSpriteKit(
            piecePosition: piecePosition,
            pieceRotation: pieceRotation,
            pieceType: pieceType,
            isFlipped: isFlipped,
            targetTransform: targetTransform,
            targetWorldPos: targetWorldPos
        )
    }
    
    /// Checks if a piece is close enough to snap to target
    func shouldShowSnapPreview(piecePosition: CGPoint, targetPosition: CGPoint) -> Bool {
        let distance = hypot(piecePosition.x - targetPosition.x, piecePosition.y - targetPosition.y)
        return distance < TangramGameConstants.Validation.positionTolerance * 2.5
    }
    
    /// Determines snap preview strength based on distance
    func getSnapPreviewStrength(piecePosition: CGPoint, targetPosition: CGPoint) -> SnapPreviewStrength {
        let distance = hypot(piecePosition.x - targetPosition.x, piecePosition.y - targetPosition.y)
        
        if distance < TangramGameConstants.Validation.positionTolerance {
            return .strong
        } else if distance < TangramGameConstants.Validation.positionTolerance * 2.5 {
            return .weak
        } else {
            return .none
        }
    }
    
    enum SnapPreviewStrength {
        case none
        case weak
        case strong
    }
    
    // MARK: - State Management
    
    /// Updates game progress based on completed pieces
    func calculateProgress(completedCount: Int, totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    /// Checks if puzzle is complete
    func isPuzzleComplete(completedCount: Int, totalCount: Int) -> Bool {
        return completedCount == totalCount && totalCount > 0
    }
    
    // MARK: - Touch Handling Logic
    
    /// Determines if a touch is a tap vs drag
    func isTapGesture(dragDistance: CGFloat, tapDuration: TimeInterval) -> Bool {
        return dragDistance < 10 && tapDuration < 0.3
    }
    
    /// Calculates rotation from touch gesture
    func calculateRotation(from touchAngle: CGFloat, initialRotation: CGFloat, initialTouchAngle: CGFloat) -> CGFloat {
        let angleDelta = touchAngle - initialTouchAngle
        return initialRotation + angleDelta
    }
    
    // MARK: - Piece Management
    
    /// Determines z-position for pieces
    func zPositionForPiece(isSelected: Bool, isCompleted: Bool, basePieceCount: Int) -> CGFloat {
        if isSelected {
            return 100
        } else if isCompleted {
            return 10
        } else {
            return CGFloat(basePieceCount)
        }
    }
    
    /// Checks if piece should be locked after placement
    func shouldLockPiece(validation: TangramPieceValidator.ValidationResult) -> Bool {
        return validation.positionValid && validation.rotationValid && validation.flipValid
    }
    
    // MARK: - Layout Calculations
    
    /// Calculates puzzle area dimensions
    func calculatePuzzleLayout(sceneSize: CGSize, safeAreaTop: CGFloat) -> PuzzleLayout {
        let totalHeight = sceneSize.height - safeAreaTop - 120
        let puzzleAreaHeight = totalHeight * 0.55
        let piecesAreaHeight = totalHeight * 0.35
        let puzzleCenter = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - safeAreaTop - 80 - puzzleAreaHeight / 2)
        
        return PuzzleLayout(
            puzzleAreaHeight: puzzleAreaHeight,
            piecesAreaHeight: piecesAreaHeight,
            puzzleCenter: puzzleCenter
        )
    }
    
    struct PuzzleLayout {
        let puzzleAreaHeight: CGFloat
        let piecesAreaHeight: CGFloat
        let puzzleCenter: CGPoint
    }
    
    /// Calculates scale for puzzle to fit in area
    func calculatePuzzleScale(puzzleBounds: CGRect, availableSize: CGSize, padding: CGFloat = 40) -> CGFloat {
        let maxWidth = availableSize.width - padding
        let maxHeight = availableSize.height - padding
        
        let scaleX = maxWidth / puzzleBounds.width
        let scaleY = maxHeight / puzzleBounds.height
        
        return min(scaleX, scaleY, 1.0) // Don't scale up beyond 1.0
    }
    
    // MARK: - Piece Positioning
    
    /// Calculates initial positions for available pieces
    func calculatePiecePositions(pieceTypes: [TangramPieceType], containerWidth: CGFloat, yPosition: CGFloat) -> [TangramPieceType: CGPoint] {
        var positions: [TangramPieceType: CGPoint] = [:]
        let spacing = containerWidth / CGFloat(pieceTypes.count + 1)
        
        for (index, pieceType) in pieceTypes.enumerated() {
            let x = spacing * CGFloat(index + 1)
            positions[pieceType] = CGPoint(x: x, y: yPosition)
        }
        
        return positions
    }
    
    /// Converts world position to target position
    func convertToTargetPosition(worldPos: CGPoint, in node: SKNode) -> CGPoint {
        return node.convert(worldPos, from: node.scene!)
    }
}