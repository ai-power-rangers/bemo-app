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
    
    // MARK: - Manipulation
    
    /// Step size for rotation in degrees
    static let rotationStepDegrees: Double = 45.0
    
    /// Step size for sliding along edges
    static let slideStepSize: Double = 2.0
    
    /// Rotation limits calculation step in degrees
    static let rotationLimitStepDegrees: Double = 5.0
    
    // MARK: - Connection Tolerances
    
    /// Tolerance for angle snapping during placement
    static let angleSnapTolerance: Double = 1.0
    
    /// Tolerance for distance snapping during placement
    static let distanceSnapTolerance: Double = 2.0
    
    /// Tolerance for connection point matching
    static let connectionPointTolerance: Double = 5.0
    
    /// Tolerance for overlap detection
    static let overlapTolerance: Double = 10.0
    
    /// Tolerance for vertex-to-vertex connections
    static let vertexToVertexTolerance: CGFloat = 1.5
    
    /// Tolerance for edge-to-edge connections
    static let edgeToEdgeTolerance: CGFloat = 5.0
    
    /// Tolerance for mixed vertex and edge connections
    static let mixedConnectionTolerance: CGFloat = 3.0
    
    /// Default connection tolerance
    static let defaultConnectionTolerance: CGFloat = 2.0
    
    // MARK: - Canvas
    
    /// Default canvas size
    static let defaultCanvasSize = CGSize(width: 800, height: 800)
    
    // MARK: - Undo/Redo
    
    /// Maximum memory for undo stack (10 MB)
    static let maxUndoMemory: Int = 10_000_000
}