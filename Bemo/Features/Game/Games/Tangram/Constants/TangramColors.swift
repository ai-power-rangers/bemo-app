//
//  TangramColors.swift
//  Bemo
//
//  Centralized color constants for Tangram game pieces
//

// WHAT: Defines the official colors for all tangram pieces
// ARCHITECTURE: Constants in MVVM-S, used throughout Tangram game for consistent colors
// USAGE: Reference TangramColors.pieceColor(for:) to get the color for any piece type

import SwiftUI

enum TangramColors {
    // Official piece colors from the editor
    private static let colors: [TangramPieceType: String] = [
        .smallTriangle1: "#C445A4",  // Purple-pink
        .smallTriangle2: "#02B7CD",  // Cyan
        .mediumTriangle: "#2BBA35",  // Green
        .largeTriangle1: "#3896FF",  // Blue
        .largeTriangle2: "#FF3A41",  // Red
        .square: "#FFD935",          // Yellow
        .parallelogram: "#FF8625"    // Orange
    ]
    
    /// Get the color for a specific piece type
    static func pieceColor(for type: TangramPieceType) -> Color {
        guard let hexColor = colors[type] else {
            return .gray // Fallback color
        }
        return Color(hex: hexColor)
    }
    
    // Additional game-specific colors
    enum Game {
        static let silhouette = Color.black.opacity(0.3)
        static let correctPiece = Color.green.opacity(0.7)
        static let incorrectPiece = Color.red.opacity(0.5)
        static let movingPiece = Color.blue.opacity(0.5)
        static let hint = Color.yellow.opacity(0.5)
        static let anchor = Color.blue
    }
    
    // SpriteKit colors (using UIColor for SKColor compatibility)
    enum Sprite {
        static func uiColor(for type: TangramPieceType) -> UIColor {
            guard let hexColor = colors[type] else {
                return .gray
            }
            return UIColor(hex: hexColor)
        }
    }
}

// Color extension is already defined in Theme.swift

// MARK: - UIColor Extension for Hex Support (for SpriteKit)

extension UIColor {
    convenience init(hex: String) {
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
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
    
    func darker(by percentage: CGFloat = 30.0) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: max(r - percentage/100, 0.0),
                         green: max(g - percentage/100, 0.0),
                         blue: max(b - percentage/100, 0.0),
                         alpha: a)
        }
        return self
    }
}