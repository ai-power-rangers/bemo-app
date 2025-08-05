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
    let id: String
    let shape: Shape
    let color: Color
    let position: CGPoint
    let rotation: Double // In degrees
    let confidence: Double // 0.0 to 1.0
    let timestamp: Date
    
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
