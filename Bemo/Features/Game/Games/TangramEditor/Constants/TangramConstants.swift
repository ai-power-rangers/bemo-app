//
//  TangramConstants.swift
//  Bemo
//
//  Central configuration and constants for the Tangram Editor
//

import Foundation
import CoreGraphics

enum TangramConstants {
    
    // MARK: - Geometry
    
    /// Scale factor for visual representation of tangram pieces
    static let visualScale: CGFloat = 50
    
    /// Tolerance for geometric calculations and comparisons
    static let geometricTolerance: CGFloat = 0.01
    
    /// Fine tolerance for precise calculations
    static let fineTolerance: CGFloat = 0.0001
    
    /// Ultra-fine tolerance for critical comparisons
    static let ultraFineTolerance: CGFloat = 1e-9
    
    // MARK: - Official Bemo Tangram Colors
    
    enum Colors {
        static let smallTriangle1 = "#C445A4"  // Purple-pink
        static let smallTriangle2 = "#02B7CD"  // Cyan
        static let mediumTriangle = "#2BBA35"  // Green
        static let largeTriangle1 = "#3896FF"  // Blue
        static let largeTriangle2 = "#FF3A41"  // Red
        static let square = "#FFD935"          // Yellow
        static let parallelogram = "#FF8625"   // Orange
    }
    
    // MARK: - UI Configuration
    
    /// Grid size for editor canvas
    static let gridSize: CGFloat = 50
    
    /// Connection point visual size
    static let connectionPointSize: CGFloat = 20
    
    /// Selected connection point scale factor
    static let selectedPointScale: CGFloat = 1.3
    
    // MARK: - Validation
    
    /// Tolerance for vertex matching in validation
    static let vertexMatchTolerance: CGFloat = 0.01
    
    /// Tolerance for edge coincidence checks
    static let edgeCoincidenceTolerance: CGFloat = 1e-6
}