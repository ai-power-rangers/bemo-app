//
//  PieceType.swift
//  Bemo
//
//  Pure data model for tangram piece types
//

import Foundation
import SwiftUI

enum PieceType: String, CaseIterable, Codable, Identifiable {
    case smallTriangle1
    case smallTriangle2
    case square
    case mediumTriangle
    case largeTriangle1
    case largeTriangle2
    case parallelogram
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .smallTriangle1, .smallTriangle2:
            return "Small Triangle"
        case .square:
            return "Square"
        case .mediumTriangle:
            return "Medium Triangle"
        case .largeTriangle1, .largeTriangle2:
            return "Large Triangle"
        case .parallelogram:
            return "Parallelogram"
        }
    }
    
    /// Official Bemo colors for each tangram piece
    var color: Color {
        switch self {
        case .smallTriangle1:
            return Self.colorFromHex(TangramConstants.Colors.smallTriangle1)
        case .smallTriangle2:
            return Self.colorFromHex(TangramConstants.Colors.smallTriangle2)
        case .mediumTriangle:
            return Self.colorFromHex(TangramConstants.Colors.mediumTriangle)
        case .largeTriangle1:
            return Self.colorFromHex(TangramConstants.Colors.largeTriangle1)
        case .largeTriangle2:
            return Self.colorFromHex(TangramConstants.Colors.largeTriangle2)
        case .square:
            return Self.colorFromHex(TangramConstants.Colors.square)
        case .parallelogram:
            return Self.colorFromHex(TangramConstants.Colors.parallelogram)
        }
    }
    
    // MARK: - Private Helper
    
    /// Convert hex string to Color - private helper to avoid polluting Color namespace
    private static func colorFromHex(_ hex: String) -> Color {
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
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}