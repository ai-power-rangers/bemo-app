//
//  TangramCVColors.swift
//  Bemo
//
//  Color definitions for TangramCV pieces
//

// WHAT: Defines colors for each tangram piece type
// ARCHITECTURE: Constants layer for visual styling
// USAGE: Use static methods to get UIColor or SKColor for pieces

import UIKit
import SpriteKit

enum TangramCVColors {
    
    // MARK: - Piece Colors
    
    /// Color definitions for each piece type
    private static let pieceColors: [TangramPieceType: UIColor] = [
        .smallTriangle1: UIColor(red: 196/255.0, green: 69/255.0, blue: 164/255.0, alpha: 1.0),  // Purple-pink
        .smallTriangle2: UIColor(red: 2/255.0, green: 183/255.0, blue: 205/255.0, alpha: 1.0),    // Cyan
        .mediumTriangle: UIColor(red: 43/255.0, green: 186/255.0, blue: 53/255.0, alpha: 1.0),    // Green
        .largeTriangle1: UIColor(red: 56/255.0, green: 150/255.0, blue: 255/255.0, alpha: 1.0),   // Blue
        .largeTriangle2: UIColor(red: 255/255.0, green: 58/255.0, blue: 65/255.0, alpha: 1.0),    // Red
        .square: UIColor(red: 255/255.0, green: 217/255.0, blue: 53/255.0, alpha: 1.0),           // Yellow
        .parallelogram: UIColor(red: 255/255.0, green: 134/255.0, blue: 37/255.0, alpha: 1.0)     // Orange
    ]
    
    // MARK: - UIColor Access
    
    /// Get UIColor for a piece type
    static func uiColor(for pieceType: TangramPieceType) -> UIColor {
        return pieceColors[pieceType] ?? .systemGray
    }
    
    /// Get SKColor for a piece type (alias for UIColor on iOS)
    static func skColor(for pieceType: TangramPieceType) -> SKColor {
        return uiColor(for: pieceType)
    }
    
    // MARK: - Darker Color Helper
    
    /// Create a darker version of a color
    static func darkerColor(_ color: UIColor, by percentage: CGFloat = 20.0) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            let factor = 1.0 - (percentage / 100.0)
            return UIColor(hue: hue,
                          saturation: saturation,
                          brightness: brightness * factor,
                          alpha: alpha)
        }
        
        return color
    }
    
    // MARK: - Target Display Colors
    
    /// Color for target silhouettes in reference zone
    static var targetSilhouetteColor: UIColor {
        return .systemGray
    }
    
    /// Stroke color for target silhouettes
    static var targetStrokeColor: UIColor {
        return .systemGray2
    }
}