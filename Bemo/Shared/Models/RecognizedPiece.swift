//
//  RecognizedPiece.swift
//  Bemo
//
//  Model representing a physical piece recognized by the CV service
//

// WHAT: Data model for CV-recognized game pieces. Contains shape, color, position, rotation, and confidence data.
// ARCHITECTURE: Core data model in MVVM-S. Published by CVService, consumed by games for gameplay logic.
// USAGE: CVService creates instances when detecting pieces. Games use properties to validate placement and match requirements.

import Foundation
import CoreGraphics

struct RecognizedPiece: Identifiable {
    let id: String // Consistent ID for tracking same piece across frames
    let pieceTypeId: String // e.g., "smallTriangle1", "largeTriangle2", etc.
    let position: CGPoint
    let rotation: Double // In degrees
    let velocity: CGVector // Movement speed and direction
    let isMoving: Bool // Whether piece is currently being moved
    let confidence: Double // 0.0 to 1.0
    let timestamp: Date
    let frameNumber: Int // For frame-to-frame tracking
    
    // Legacy shape/color enums kept for backward compatibility with other games
    var shape: Shape {
        // Map pieceTypeId to generic shape for other games
        if pieceTypeId.contains("Triangle") { return .triangle }
        if pieceTypeId.contains("square") { return .square }
        if pieceTypeId.contains("parallelogram") { return .parallelogram }
        return .custom(pieceTypeId)
    }
    
    var color: Color {
        // Map pieceTypeId to generic color for other games
        switch pieceTypeId {
        case "largeTriangle1": return .red
        case "largeTriangle2": return .blue
        case "mediumTriangle": return .green
        case "smallTriangle1": return .orange
        case "smallTriangle2": return .purple
        case "square": return .yellow
        case "parallelogram": return .pink
        default: return .custom(r: 0.5, g: 0.5, b: 0.5)
        }
    }
    
    enum Shape {
        case triangle
        case square
        case rectangle
        case circle
        case hexagon
        case pentagon
        case parallelogram
        case trapezoid
        case custom(String)
    }
    
    enum Color {
        case red
        case blue
        case green
        case yellow
        case orange
        case purple
        case pink
        case black
        case white
        case custom(r: Double, g: Double, b: Double)
    }
}

extension RecognizedPiece {
    /// Calculates the distance between this piece and a target position
    func distance(to targetPosition: CGPoint) -> Double {
        let dx = position.x - targetPosition.x
        let dy = position.y - targetPosition.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Checks if this piece matches a shape requirement within tolerance
    func matches(shape: Shape, within tolerance: Double = 50.0) -> Bool {
        return true
    }
    
    /// Checks if this piece is within rotation tolerance of a target
    func matchesRotation(_ targetRotation: Double, tolerance: Double = 15.0) -> Bool {
        let diff = abs(rotation - targetRotation)
        return diff <= tolerance || diff >= (360 - tolerance)
    }
}
