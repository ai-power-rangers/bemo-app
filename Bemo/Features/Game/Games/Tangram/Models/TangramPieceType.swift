//
//  TangramPieceType.swift
//  Bemo
//
//  Self-contained piece type enum for Tangram game (no editor dependencies)
//

// WHAT: Defines the 7 tangram piece types with their display names
// ARCHITECTURE: Model in MVVM-S, used throughout Tangram game for piece identification
// USAGE: Reference piece types without depending on TangramEditor

import Foundation
import SwiftUI

enum TangramPieceType: String, CaseIterable, Codable, Identifiable {
    case smallTriangle1 = "smallTriangle1"
    case smallTriangle2 = "smallTriangle2"
    case mediumTriangle = "mediumTriangle"
    case largeTriangle1 = "largeTriangle1"
    case largeTriangle2 = "largeTriangle2"
    case square = "square"
    case parallelogram = "parallelogram"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .smallTriangle1, .smallTriangle2:
            return "Small Triangle"
        case .mediumTriangle:
            return "Medium Triangle"
        case .largeTriangle1, .largeTriangle2:
            return "Large Triangle"
        case .square:
            return "Square"
        case .parallelogram:
            return "Parallelogram"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .largeTriangle1: return 0
        case .largeTriangle2: return 1
        case .mediumTriangle: return 2
        case .smallTriangle1: return 3
        case .smallTriangle2: return 4
        case .square: return 5
        case .parallelogram: return 6
        }
    }
    
    var color: Color {
        TangramColors.pieceColor(for: self)
    }
}