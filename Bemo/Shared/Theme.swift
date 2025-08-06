//
//  Theme.swift
//  Bemo
//
//  Centralized design system for colors, typography, and styling
//

// WHAT: Defines the app's design tokens including colors, fonts, spacing, and common modifiers
// ARCHITECTURE: Shared component used across all views for consistent styling
// USAGE: Import and use BemoTheme.Colors.primary, BemoTheme.font(for: .heading1), etc.

import SwiftUI

/// Centralized access to the Bemo app's design system for colors, fonts, and styling
enum BemoTheme {
    
    // MARK: - Color Palette
    
    enum Colors {
        // Brand Colors
        static let primary = Color(hex: "#5049AD")      // Deep purple
        static let secondary = Color(hex: "#15E6CD")    // Bright cyan
        static let tertiary = Color(hex: "#6B9AC4")     // Soft blue
        
        // Semantic Colors
        static let info = Color(hex: "#2F80ED")         // Information blue
        
        // Neutral Colors
        static let gray1 = Color(hex: "#333333")        // Dark gray
        static let gray2 = Color(hex: "#4F4F4F")        // Medium gray
        static let background = Color(hex: "#F8F9FA")   // Light background
        
        // Game Card Colors (using hex initializer)
        static let card1Background = Color(hex: "#E3F2FD")  // Light blue
        static let card1Foreground = Color(hex: "#1E88E5")  // Blue
        
        static let card2Background = Color(hex: "#E8F5E9")  // Light green
        static let card2Foreground = Color(hex: "#43A047")  // Green
        
        static let card3Background = Color(hex: "#FFF3E0")  // Light orange
        static let card3Foreground = Color(hex: "#FB8C00")  // Orange
        
        static let card4Background = Color(hex: "#FCE4EC")  // Light pink
        static let card4Foreground = Color(hex: "#E91E63")  // Pink
    }
    
    // MARK: - Typography
    
    enum FontStyle {
        case heading1
        case heading2
        case heading3
        case body
        case caption
        
        var size: CGFloat {
            switch self {
            case .heading1: return 56
            case .heading2: return 48
            case .heading3: return 40
            case .body: return 16
            case .caption: return 12
            }
        }
        
        var weight: Font.Weight {
            switch self {
            case .heading1, .heading2, .heading3: return .bold
            case .body: return .regular
            case .caption: return .light
            }
        }
    }
    
    static func font(for style: FontStyle) -> Font {
        // Check if custom SINK font is available
        // For now, using system font with appropriate weights
        // TODO: Replace with .custom("SINK", size: style.size) when font file is added
        return .system(size: style.size, weight: style.weight, design: .rounded)
    }
    
    // MARK: - Spacing & Layout
    
    enum Spacing {
        static let xxsmall: CGFloat = 4
        static let xsmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
        static let xxlarge: CGFloat = 48
    }
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
        static let circle: CGFloat = 9999  // For circular shapes
    }
    
    enum Shadow {
        static let small = (radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let large = (radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    }
    
    enum Animation {
        static let quick: Double = 0.2
        static let standard: Double = 0.3
        static let slow: Double = 0.5
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
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

// MARK: - View Extension for Common Modifiers

extension View {
    /// Applies standard card styling with background, corner radius, and shadow
    func cardStyle(backgroundColor: Color = BemoTheme.Colors.background) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(BemoTheme.CornerRadius.large)
            .shadow(
                radius: BemoTheme.Shadow.medium.radius,
                x: BemoTheme.Shadow.medium.x,
                y: BemoTheme.Shadow.medium.y
            )
    }
    
    /// Applies primary button styling
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .font(BemoTheme.font(for: .body))
            .padding(.horizontal, BemoTheme.Spacing.large)
            .padding(.vertical, BemoTheme.Spacing.small)
            .background(BemoTheme.Colors.primary)
            .cornerRadius(BemoTheme.CornerRadius.medium)
    }
    
    /// Applies secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(BemoTheme.Colors.primary)
            .font(BemoTheme.font(for: .body))
            .padding(.horizontal, BemoTheme.Spacing.large)
            .padding(.vertical, BemoTheme.Spacing.small)
            .overlay(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                    .stroke(BemoTheme.Colors.primary, lineWidth: 2)
            )
    }
    
    /// Applies themed shadow
    func themedShadow(_ size: (radius: CGFloat, x: CGFloat, y: CGFloat) = BemoTheme.Shadow.medium) -> some View {
        self.shadow(radius: size.radius, x: size.x, y: size.y)
    }
}