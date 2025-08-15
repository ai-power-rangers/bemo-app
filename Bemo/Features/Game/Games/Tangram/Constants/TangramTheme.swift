//
//  TangramTheme.swift
//  Bemo
//
//  Tangram-specific theme extensions building on BemoTheme
//

// WHAT: Extends BemoTheme with Tangram-specific colors and styles while maintaining consistency
// ARCHITECTURE: Theme layer in MVVM-S, bridges BemoTheme with game-specific needs
// USAGE: Use TangramTheme for all UI colors in Tangram game and dev tools

import SwiftUI
import SpriteKit

/// Tangram-specific theme that extends BemoTheme for game needs
enum TangramTheme {
    
    // MARK: - Background Colors
    
    /// Background colors for different contexts
    enum Backgrounds {
        /// Main background for editor and tools (uses app background)
        static var editor: Color { Color("AppBackground") }
        
        /// Game scene background
        static var gameScene: Color { Color("GameBackground") }
        
        /// Panel backgrounds for tools
        static var panel: Color { BemoTheme.Colors.background }
        
        /// Secondary panel backgrounds
        static var secondaryPanel: Color { BemoTheme.Colors.background.opacity(0.95) }
        
        /// Toolbar backgrounds
        static var toolbar: Color { Color.white.opacity(0.95) }
    }
    
    // MARK: - Text Colors
    
    /// Text colors with semantic meaning
    enum Text {
        /// Primary text color from assets
        static var primary: Color { Color("AppPrimaryTextColor") }
        
        /// Secondary text for less important content
        static var secondary: Color { Color("AppPrimaryTextColor").opacity(0.6) }
        
        /// Tertiary text for hints and subtle labels
        static var tertiary: Color { Color("AppPrimaryTextColor").opacity(0.4) }
        
        /// Text on colored backgrounds
        static var onColor: Color { .white }
    }
    
    // MARK: - UI Element Colors
    
    /// Colors for interactive elements
    enum UI {
        /// Primary action buttons
        static var primaryButton: Color { BemoTheme.Colors.primary }
        
        /// Secondary action buttons
        static var secondaryButton: Color { BemoTheme.Colors.secondary }
        
        /// Destructive actions
        static var destructive: Color { Color(hex: "#FF3A41") }
        
        /// Success states
        static var success: Color { BemoTheme.Colors.card2Foreground }
        
        /// Warning states
        static var warning: Color { BemoTheme.Colors.card3Foreground }
        
        /// Info states
        static var info: Color { BemoTheme.Colors.info }
        
        /// Disabled states
        static var disabled: Color { Color("AppPrimaryTextColor").opacity(0.3) }
        
        /// Selection highlight
        static var selection: Color { BemoTheme.Colors.primary.opacity(0.2) }
        
        /// Separator lines
        static var separator: Color { Color("AppPrimaryTextColor").opacity(0.1) }
    }
    
    // MARK: - Nudge Level Colors
    
    /// Colors for different nudge levels
    enum Nudge {
        static func color(for level: NudgeLevel) -> Color {
            switch level {
            case .none:
                return Color.clear
            case .visual:
                return BemoTheme.Colors.info.opacity(0.8) // Light blue for visual
            case .gentle:
                return BemoTheme.Colors.info // Blue for gentle
            case .specific:
                return BemoTheme.Colors.card3Foreground // Orange for specific
            case .directed:
                return BemoTheme.Colors.card4Foreground // Pink for directed
            case .solution:
                return BemoTheme.Colors.card2Foreground // Green for solution
            }
        }
        
        static func skColor(for level: NudgeLevel) -> SKColor {
            switch level {
            case .none:
                return SKColor.clear
            case .visual:
                return SKColor.systemBlue
            case .gentle:
                return SKColor.systemTeal
            case .specific:
                return SKColor.systemOrange
            case .directed:
                return SKColor.systemYellow
            case .solution:
                return SKColor.systemGreen
            }
        }
    }
    
    // MARK: - Hint Colors
    
    /// Colors for hint system
    enum Hint {
        /// Hint highlight color
        static var highlight: Color { BemoTheme.Colors.secondary }
        
        /// Hint background
        static var background: Color { BemoTheme.Colors.secondary.opacity(0.1) }
        
        /// Hint glow effect
        static var glow: Color { BemoTheme.Colors.secondary.opacity(0.3) }
        
        /// SpriteKit hint color
        static var skColor: SKColor { 
            SKColor(red: 0.08, green: 0.90, blue: 0.80, alpha: 1.0) // Cyan
        }
    }
    
    // MARK: - Validation Colors
    
    /// Colors for validation states
    enum Validation {
        /// Correct placement
        static var correct: Color { BemoTheme.Colors.card2Foreground }
        static var correctSK: SKColor { SKColor(red: 0.3, green: 0.75, blue: 0.31, alpha: 0.7) }
        
        /// Incorrect placement
        static var incorrect: Color { Color(hex: "#FF3A41").opacity(0.5) }
        static var incorrectSK: SKColor { SKColor(red: 1.0, green: 0.23, blue: 0.25, alpha: 0.5) }
        
        /// Partially correct
        static var partial: Color { BemoTheme.Colors.card3Foreground.opacity(0.5) }
        static var partialSK: SKColor { SKColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 0.5) }
        
        /// Moving/active state
        static var active: Color { BemoTheme.Colors.primary.opacity(0.5) }
        static var activeSK: SKColor { SKColor(red: 0.31, green: 0.29, blue: 0.68, alpha: 0.5) }
    }
    
    // MARK: - Shadow Styles
    
    /// Consistent shadow styles
    enum Shadow {
        static var card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(0.08), 10, 0, 4)
        }
        
        static var button: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(0.1), 4, 0, 2)
        }
        
        static var panel: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(0.05), 8, 0, 2)
        }
    }
    
    // MARK: - Dev Tool Specific
    
    /// Colors specific to dev tools
    enum DevTools {
        /// Grid lines in editor
        static var gridLine: Color { Color("AppPrimaryTextColor").opacity(0.1) }
        
        /// Grid major lines
        static var gridMajor: Color { Color("AppPrimaryTextColor").opacity(0.2) }
        
        /// Snap indicators
        static var snapIndicator: Color { BemoTheme.Colors.info }
        
        /// Guides and rulers
        static var guide: Color { BemoTheme.Colors.tertiary }
        
        /// Active tool highlight
        static var toolActive: Color { BemoTheme.Colors.primary }
        
        /// Tool inactive state
        static var toolInactive: Color { Color("AppPrimaryTextColor").opacity(0.5) }
    }
    
    // MARK: - Utility Functions
    
    /// Convert theme color to SKColor for SpriteKit
    static func toSKColor(_ color: Color) -> SKColor {
        // This is a simplified conversion - in production you'd want UIColor
        let uiColor = UIColor(color)
        return SKColor(cgColor: uiColor.cgColor)
    }
}

// MARK: - View Extensions for Tangram

extension View {
    /// Apply standard panel styling for dev tools
    func tangramPanel() -> some View {
        self
            .background(TangramTheme.Backgrounds.panel)
            .cornerRadius(BemoTheme.CornerRadius.large)
            .shadow(
                color: TangramTheme.Shadow.panel.color,
                radius: TangramTheme.Shadow.panel.radius,
                x: TangramTheme.Shadow.panel.x,
                y: TangramTheme.Shadow.panel.y
            )
    }
    
    /// Apply toolbar styling
    func tangramToolbar() -> some View {
        self
            .background(TangramTheme.Backgrounds.toolbar)
            .overlay(
                Rectangle()
                    .fill(TangramTheme.UI.separator)
                    .frame(height: 1),
                alignment: .bottom
            )
    }
    
    /// Apply button styling for dev tools
    func tangramButton(isActive: Bool = false) -> some View {
        self
            .foregroundColor(isActive ? TangramTheme.UI.primaryButton : TangramTheme.Text.primary)
            .padding(.horizontal, BemoTheme.Spacing.medium)
            .padding(.vertical, BemoTheme.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                    .fill(isActive ? TangramTheme.UI.selection : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                    .stroke(
                        isActive ? TangramTheme.UI.primaryButton : TangramTheme.UI.separator,
                        lineWidth: isActive ? 2 : 1
                    )
            )
    }
}