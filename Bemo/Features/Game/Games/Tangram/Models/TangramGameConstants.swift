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
    
    /// Tolerance for position matching during validation (in pixels)
    static let positionTolerance: CGFloat = 15.0
    
    /// Tolerance for rotation matching during validation (in degrees)
    static let rotationTolerance: CGFloat = 10.0
    
    /// Snap distance for piece placement (in pixels)
    static let snapDistance: CGFloat = 40.0
    
    // MARK: - Colors
    
    /// Official Bemo colors for each tangram piece
    enum Colors {
        static let smallTriangle1 = Color(tangramHex: "#C445A4")  // Purple-pink
        static let smallTriangle2 = Color(tangramHex: "#02B7CD")  // Cyan
        static let mediumTriangle = Color(tangramHex: "#2BBA35")  // Green
        static let largeTriangle1 = Color(tangramHex: "#3896FF")  // Blue
        static let largeTriangle2 = Color(tangramHex: "#FF3A41")  // Red
        static let square = Color(tangramHex: "#FFD935")          // Yellow
        static let parallelogram = Color(tangramHex: "#FF8625")   // Orange
        
        /// Get color for a specific piece type
        static func color(for pieceType: TangramPieceType) -> Color {
            switch pieceType {
            case .smallTriangle1: return smallTriangle1
            case .smallTriangle2: return smallTriangle2
            case .mediumTriangle: return mediumTriangle
            case .largeTriangle1: return largeTriangle1
            case .largeTriangle2: return largeTriangle2
            case .square: return square
            case .parallelogram: return parallelogram
            }
        }
        
        /// Get UIColor for SpriteKit usage
        static func uiColor(for pieceType: TangramPieceType) -> UIColor {
            UIColor(color(for: pieceType))
        }
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

// MARK: - Color Extension

private extension Color {
    /// Initialize Color from hex string (renamed to avoid conflicts)
    init(tangramHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}