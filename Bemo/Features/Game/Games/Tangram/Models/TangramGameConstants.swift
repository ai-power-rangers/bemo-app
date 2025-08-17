//
//  TangramGameConstants.swift
//  Bemo
//
//  Self-contained constants for Tangram game
//

// WHAT: Centralized configuration for colors, scales, and tolerances
// ARCHITECTURE: Model in MVVM-S, provides consistent values across game
// USAGE: Reference for piece colors, visual scaling, and validation tolerances

import Foundation
import SwiftUI
import CoreGraphics

enum TangramGameConstants {
    
    // MARK: - Canonical Feature Angles
    
    struct CanonicalFeatures {
        /// Canonical feature angle for triangles in SpriteKit space
        /// This aligns with the editor's reference frame where triangles
        /// are considered "unrotated" when their hypotenuse points at 45°
        static let triangleFeatureSK: CGFloat = .pi / 4  // 45° in radians
        
        /// Canonical feature angle for square in SpriteKit space
        static let squareFeatureSK: CGFloat = 0
        
        /// Canonical feature angle for parallelogram in SpriteKit space
        static let parallelogramFeatureSK: CGFloat = 0
        
        /// Get canonical feature angle for any piece type
        static func canonicalFeatureAngle(for pieceType: TangramPieceType) -> CGFloat {
            switch pieceType {
            case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2:
                return triangleFeatureSK
            case .square:
                return squareFeatureSK
            case .parallelogram:
                return parallelogramFeatureSK
            }
        }
    }
    
    // MARK: - Geometry
    
    /// Scale factor to convert from normalized space (0-2) to visual space (pixels)
    static let visualScale: CGFloat = 50.0
    
    // MARK: - Validation
    
    enum Validation {
        /// Distance tolerance for piece center position matching (in pixels)
        static let positionTolerance: CGFloat = 35.0
        
        /// Rotation tolerance for piece angle matching (in degrees)
        static let rotationTolerance: CGFloat = 18.0

        /// Minimum center-to-center distance for two pieces to be considered "connected"
        /// This gates early validation to ensure the first relations are built physically next to each other
        static let connectionDistance: CGFloat = 100.0

        /// Per-difficulty tolerance presets
        static func tolerances(for difficulty: UserPreferences.DifficultySetting) -> (position: CGFloat, rotationDeg: CGFloat, connection: CGFloat, edgeContact: CGFloat) {
            // For testing: use the same tolerances across all difficulties
            // This can be restored to difficulty-specific values later
            return (position: 50, rotationDeg: 25, connection: 130, edgeContact: 20)
        }
    }
    
    // MARK: - Animation
    
    // Snap animation duration removed (snapping disabled)
    
    /// Duration for rotation animations
    static let rotationAnimationDuration: TimeInterval = 0.2
    
    /// Duration for celebration effects
    static let celebrationDuration: TimeInterval = 3.0
    
    // MARK: - UI Layout
    
    /// Height ratio for puzzle area (top section)
    static let puzzleAreaHeightRatio: CGFloat = 0.6
    
    /// Height ratio for pieces area (bottom section)
    static let piecesAreaHeightRatio: CGFloat = 0.4
    
    /// Alpha value for target piece silhouettes
    static let targetPieceAlpha: CGFloat = 0.3
    
    // Snap preview alpha removed (snapping disabled)

    enum VisualDifficultyStyle {
        case easyColoredOutlines
        case mediumStandard
        case hardAllBlack
        
        static func style(for difficulty: UserPreferences.DifficultySetting) -> VisualDifficultyStyle {
            switch difficulty {
            case .easy: return .easyColoredOutlines
            case .normal: return .mediumStandard
            case .hard: return .hardAllBlack
            }
        }
    }
    
    // MARK: - Difficulty Progression
    
    enum DifficultyProgression {
        /// Minimum number of Easy puzzles that must be completed to unlock Medium
        static let easyPuzzlesRequiredForMedium: Int = 1
        
        /// Minimum completion percentage of Medium puzzles required to unlock Hard (0.0 to 1.0)
        static let mediumCompletionRequiredForHard: Double = 0.5
        
        /// Percentage multiplier for display (converts 0.0-1.0 to 0-100)
        static let percentageMultiplier: Double = 100.0
        
        /// Star rating ranges for each difficulty level
        enum StarRating {
            static let easyStars: [Int] = [1, 2]      // 1-2 star puzzles
            static let mediumStars: [Int] = [3, 4]    // 3-4 star puzzles  
            static let hardStars: [Int] = [5]         // 5 star puzzles
        }
        
        /// Check if a difficulty should be unlocked based on progress
        static func isDifficultyUnlocked(
            _ difficulty: UserPreferences.DifficultySetting,
            easyCompleted: Int,
            mediumCompleted: Int,
            mediumTotal: Int
        ) -> Bool {
            switch difficulty {
            case .easy:
                return true // Always unlocked
                
            case .normal:
                return easyCompleted >= easyPuzzlesRequiredForMedium
                
            case .hard:
                guard mediumTotal > 0 else { return false }
                let completionRatio = Double(mediumCompleted) / Double(mediumTotal)
                return completionRatio >= mediumCompletionRequiredForHard
            }
        }
    }
}
