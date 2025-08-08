//
//  TangramCVConstants.swift
//  Bemo
//
//  Constants for TangramCV game - self-contained version
//

// WHAT: Game constants for CV-ready tangram implementation
// ARCHITECTURE: Constants layer for TangramCV game
// USAGE: Import and use static properties for consistent values

import Foundation
import CoreGraphics

enum TangramCVConstants {
    
    // MARK: - Visual Scaling
    
    /// Scale factor to convert normalized coordinates (0-2) to visual pixels
    static let visualScale: CGFloat = 50.0
    
    /// Scale factor for reference display (60% of normal size)
    static let referenceScale: CGFloat = 0.6
    
    // MARK: - Validation Tolerances (Normalized Units)
    
    /// Position tolerance in normalized units (square = 1.0)
    enum ValidationTolerance {
        case easy
        case standard
        case precise
        case expert
        
        var position: Double {
            switch self {
            case .easy: return 0.40      // 40% of square side
            case .standard: return 0.25   // 25% of square side
            case .precise: return 0.15    // 15% of square side
            case .expert: return 0.08     // 8% of square side
            }
        }
        
        var rotation: Double {
            switch self {
            case .easy: return 15.0       // degrees
            case .standard: return 10.0   // degrees
            case .precise: return 5.0     // degrees
            case .expert: return 3.0      // degrees
            }
        }
    }
    
    // MARK: - CV Stream Configuration
    
    /// Maximum CV output frequency (Hz)
    static let cvStreamFrequency: Double = 20.0
    
    /// Minimum time between CV emissions (seconds)
    static let cvEmissionInterval: TimeInterval = 1.0 / cvStreamFrequency
    
    /// Time to wait after piece drop before validation (milliseconds)
    static let pieceSettleTime: TimeInterval = 0.2
    
    /// Number of stable frames required for anchor promotion in CV mode
    static let anchorStabilityFrames: Int = 5
    
    // MARK: - Visual Properties
    
    /// Alpha for target piece silhouettes in reference zone
    static let targetPieceAlpha: CGFloat = 0.3
    
    /// Stroke width for pieces
    static let pieceStrokeWidth: CGFloat = 2.0
    
    /// Stroke width for reference pieces
    static let referencePieceStrokeWidth: CGFloat = 1.0
    
    // MARK: - Zone Layout
    
    /// Number of zones in the layout
    static let zoneCount: Int = 3
    
    /// Margin for piece scattering in storage zone
    static let storageZoneMargin: CGFloat = 30.0
    
    /// Grid columns for storage zone
    static let storageGridColumns: Int = 3
    
    /// Grid rows for storage zone
    static let storageGridRows: Int = 3
    
    /// Random offset range for scattered pieces
    static let scatterRandomOffset: CGFloat = 20.0
    
    // MARK: - Piece Type Mapping
    
    /// Maps CV model names to game piece types
    static func mapCVNameToType(_ name: String) -> TangramPieceType? {
        switch name {
        case "tangram_square":         return .square
        case "tangram_triangle_sml":   return .smallTriangle1  // Red small triangle
        case "tangram_triangle_sml2":  return .smallTriangle2  // Blue small triangle
        case "tangram_triangle_med":   return .mediumTriangle
        case "tangram_triangle_lrg":   return .largeTriangle1  // Green large triangle
        case "tangram_triangle_lrg2":  return .largeTriangle2  // Yellow large triangle
        case "tangram_parallelogram":  return .parallelogram
        default: return nil
        }
    }
    
    /// Maps game piece types to CV model names
    static func mapTypeToCV(_ type: TangramPieceType?) -> String {
        switch type {
        case .square: return "tangram_square"
        case .smallTriangle1: return "tangram_triangle_sml"
        case .smallTriangle2: return "tangram_triangle_sml2"
        case .mediumTriangle: return "tangram_triangle_med"
        case .largeTriangle1: return "tangram_triangle_lrg"
        case .largeTriangle2: return "tangram_triangle_lrg2"
        case .parallelogram: return "tangram_parallelogram"
        default: return "unknown"
        }
    }
    
    /// CV class IDs for piece types
    static func cvClassId(for type: TangramPieceType?) -> Int {
        switch type {
        case .parallelogram: return 0
        case .square: return 1
        case .largeTriangle1: return 2
        case .largeTriangle2: return 3
        case .mediumTriangle: return 4
        case .smallTriangle1: return 5
        case .smallTriangle2: return 6
        default: return -1
        }
    }
    
    // MARK: - Rotational Symmetry
    
    /// Returns the rotational symmetry angle for a piece type (in degrees)
    static func getRotationalSymmetry(for type: TangramPieceType) -> Double {
        switch type {
        case .square: return 90.0          // 4-fold symmetry
        case .smallTriangle1, .smallTriangle2,
             .mediumTriangle, .largeTriangle1,
             .largeTriangle2: return 180.0  // 2-fold symmetry
        case .parallelogram: return 360.0   // No rotational symmetry
        }
    }
}