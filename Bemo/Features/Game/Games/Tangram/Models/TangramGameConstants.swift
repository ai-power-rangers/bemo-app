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
    
    // MARK: - Geometry
    
    /// Scale factor to convert from normalized space (0-2) to visual space (pixels)
    static let visualScale: CGFloat = 50.0
    
    // MARK: - Validation
    
    enum Validation {
        /// Distance tolerance for piece center position matching (in pixels)
        static let positionTolerance: CGFloat = 35.0  // Increased for better touch interaction with triangles
        
        /// Rotation tolerance for piece angle matching (in degrees)
        static let rotationTolerance: CGFloat = 4.0  // Very tight tolerance for precise placement
        
        /// Legacy vertex matching tolerance (in pixels) - used for vertex-by-vertex comparison
        static let vertexTolerance: CGFloat = 20.0  // Tightened from 30
    }
    
    
    
    // MARK: - Animation
    
    /// Duration for snap animations
    static let snapAnimationDuration: TimeInterval = 0.2
    
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
    
    /// Alpha value for snap preview
    static let snapPreviewAlpha: CGFloat = 0.5
}

