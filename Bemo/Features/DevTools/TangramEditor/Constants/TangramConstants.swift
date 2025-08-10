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
    
    /// Primary tolerance values used by TangramValidationService
    /// All validation should use these consistent values
    
    // MARK: - Manipulation
    
    /// Step size for rotation in degrees
    static let rotationStepDegrees: Double = 45.0
    
    /// Valid rotation snap angles in degrees
    static let rotationSnapAngles: [Double] = [-180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0]
    
    /// Step size for sliding along edges
    static let slideStepSize: Double = 2.0
    
    /// Slide snap positions as percentages (0.0 to 1.0)
    static let slideSnapPercentages: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
    
    /// Rotation limits calculation step in degrees
    static let rotationLimitStepDegrees: Double = 5.0
    
    // MARK: - Connection Tolerances
    
    /// Unified tolerance values - single source of truth
    /// These are used by TangramValidationService.ToleranceType
    
    /// Tolerance for vertex-to-vertex connections (tight)
    static let vertexToVertexTolerance: CGFloat = 1.5
    
    /// Tolerance for edge-to-edge connections (allows sliding)
    static let edgeToEdgeTolerance: CGFloat = 2.0  // Reduced from 5.0 for consistency
    
    /// Tolerance for vertex-to-edge connections
    static let vertexToEdgeTolerance: CGFloat = 2.0
    
    /// Tolerance for mixed connections (vertex+edge)
    static let mixedConnectionTolerance: CGFloat = 2.0  // Aligned with engine tolerance
    
    /// SAT overlap detection tolerance
    static let overlapTolerance: CGFloat = 1.0
    
    /// Angle snapping tolerance for rotations
    static let angleSnapTolerance: Double = 1.0
    
    /// Distance snapping tolerance
    static let distanceSnapTolerance: Double = 2.0
    
    // MARK: - Canvas
    
    /// Default canvas size
    static let defaultCanvasSize = CGSize(width: 800, height: 800)
    
    // MARK: - Undo/Redo
    
    /// Maximum memory for undo stack (10 MB)
    static let maxUndoMemory: Int = 10_000_000
    
    // MARK: - UI Animation
    
    /// Toast message duration in seconds
    static let toastDuration: Double = 2.0
    
    /// Button press scale effect
    static let buttonPressScale: CGFloat = 0.95
    
    /// Long press minimum duration
    static let longPressDuration: Double = 0.5
    
    /// Selection scale effect
    static let selectionScale: CGFloat = 1.2
    
    // MARK: - Math Utilities
    
    /// Convert degrees to radians multiplier
    static let degreesToRadians: Double = .pi / 180.0
    
    /// Convert radians to degrees multiplier
    static let radiansToDegrees: Double = 180.0 / .pi
}