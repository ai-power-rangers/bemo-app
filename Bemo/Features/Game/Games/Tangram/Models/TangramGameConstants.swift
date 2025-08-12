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
            switch difficulty {
            case .easy:
                return (position: 55, rotationDeg: 24, connection: 170, edgeContact: 16)
            case .normal:
                return (position: 40, rotationDeg: 18, connection: 130, edgeContact: 14)
            case .hard:
                return (position: 28, rotationDeg: 12, connection: 90, edgeContact: 10)
            }
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
}

