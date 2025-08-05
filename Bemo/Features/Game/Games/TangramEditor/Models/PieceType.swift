//
//  PieceType.swift
//  Bemo
//
//  Pure data model for tangram piece types
//

import Foundation

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
}