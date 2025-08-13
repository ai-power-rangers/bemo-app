//
//  SKColorExtensions.swift
//  Bemo
//
//  Color utilities for animation effects
//

import SpriteKit

extension SKColor {
    /// Returns a lighter version of the color
    func lighter(by percentage: CGFloat) -> SKColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return SKColor(hue: h, saturation: max(0, s - percentage/200), brightness: min(1, b + percentage/100), alpha: a)
    }
    
    // Note: darker(by:) is already defined in TangramColors.swift
}