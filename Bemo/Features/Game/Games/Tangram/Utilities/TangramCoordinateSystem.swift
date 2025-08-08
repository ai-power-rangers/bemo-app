//
//  TangramCoordinateSystem.swift
//  Bemo
//
//  Standardized coordinate system transformations for Tangram game
//

// WHAT: Centralized coordinate system conversion utilities for consistent transformations
// ARCHITECTURE: Utility struct with static methods for coordinate conversions
// USAGE: Used throughout Tangram for converting between different coordinate systems

import Foundation
import CoreGraphics
import SpriteKit

/// Handles coordinate system conversions for Tangram game
struct TangramCoordinateSystem {
    
    // MARK: - SpriteKit Conversions
    
    /// Converts a point from standard coordinates to SpriteKit coordinates
    /// SpriteKit has origin at bottom-left, Y increases upward
    static func convertToSpriteKit(_ point: CGPoint, canvasHeight: CGFloat) -> CGPoint {
        // SpriteKit already uses bottom-left origin, so typically no conversion needed
        // But if converting from UIKit coordinates (top-left origin):
        return CGPoint(x: point.x, y: canvasHeight - point.y)
    }
    
    /// Converts a point from SpriteKit coordinates to standard coordinates
    static func convertFromSpriteKit(_ point: CGPoint, canvasHeight: CGFloat) -> CGPoint {
        // Inverse of convertToSpriteKit
        return CGPoint(x: point.x, y: canvasHeight - point.y)
    }
    
    /// Converts a transform for SpriteKit usage
    static func convertTransformToSpriteKit(_ transform: CGAffineTransform, canvasHeight: CGFloat) -> CGAffineTransform {
        // SpriteKit uses the same transform structure but may need Y-axis adjustment
        var adjusted = transform
        // Flip Y translation if needed
        adjusted.ty = canvasHeight - transform.ty
        return adjusted
    }
    
    // MARK: - UIKit/SwiftUI Conversions
    
    /// Converts from UIKit coordinates (top-left origin) to standard coordinates
    static func convertFromUIKit(_ point: CGPoint, viewHeight: CGFloat) -> CGPoint {
        return CGPoint(x: point.x, y: viewHeight - point.y)
    }
    
    /// Converts to UIKit coordinates (top-left origin) from standard coordinates
    static func convertToUIKit(_ point: CGPoint, viewHeight: CGFloat) -> CGPoint {
        return CGPoint(x: point.x, y: viewHeight - point.y)
    }
    
    // MARK: - Transform Normalization
    
    /// Normalizes a transform to ensure consistent representation
    static func normalizeTransform(_ transform: CGAffineTransform) -> CGAffineTransform {
        // Extract components
        let components = TangramGeometryUtilities.decomposeTransform(transform)
        
        // Rebuild with normalized values
        return TangramGeometryUtilities.createTransform(
            position: components.position,
            rotation: TangramGeometryUtilities.normalizeAngle(components.rotation),
            scale: max(components.scale.width, 0.1) // Ensure minimum scale
        )
    }
    
    /// Applies coordinate system correction to a transform
    static func correctTransformForCoordinateSystem(
        _ transform: CGAffineTransform,
        from: CoordinateSystem,
        to: CoordinateSystem,
        canvasSize: CGSize
    ) -> CGAffineTransform {
        guard from != to else { return transform }
        
        var corrected = transform
        
        // Handle Y-axis flipping between coordinate systems
        if from.hasTopLeftOrigin != to.hasTopLeftOrigin {
            corrected.ty = canvasSize.height - transform.ty
            // May also need to flip rotation depending on the transformation
            if from == .uiKit && to == .spriteKit {
                // UIKit to SpriteKit may need rotation adjustment
                corrected.b = -transform.b // Flip the rotation component
                corrected.c = -transform.c
            }
        }
        
        return corrected
    }
    
    /// Supported coordinate systems
    enum CoordinateSystem {
        case spriteKit  // Bottom-left origin, Y up
        case uiKit      // Top-left origin, Y down
        case standard   // Mathematical standard (bottom-left, Y up)
        
        var hasTopLeftOrigin: Bool {
            switch self {
            case .uiKit: return true
            case .spriteKit, .standard: return false
            }
        }
    }
    
    // MARK: - Piece Position Helpers
    
    /// Converts piece position based on anchor point
    static func adjustPositionForAnchor(
        position: CGPoint,
        size: CGSize,
        anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> CGPoint {
        // Adjust position based on anchor point
        let offsetX = size.width * (0.5 - anchor.x)
        let offsetY = size.height * (0.5 - anchor.y)
        
        return CGPoint(
            x: position.x + offsetX,
            y: position.y + offsetY
        )
    }
    
    /// Calculates world position for a node in a scene
    static func worldPosition(for node: SKNode, in scene: SKScene) -> CGPoint {
        return node.convert(CGPoint.zero, to: scene)
    }
    
    /// Calculates local position relative to a parent node
    static func localPosition(worldPos: CGPoint, relativeTo parent: SKNode, in scene: SKScene) -> CGPoint {
        return parent.convert(worldPos, from: scene)
    }
    
    // MARK: - Bounds Calculations
    
    /// Converts bounds between coordinate systems
    static func convertBounds(
        _ bounds: CGRect,
        from: CoordinateSystem,
        to: CoordinateSystem,
        canvasSize: CGSize
    ) -> CGRect {
        guard from != to else { return bounds }
        
        let topLeft = CGPoint(x: bounds.minX, y: bounds.minY)
        let bottomRight = CGPoint(x: bounds.maxX, y: bounds.maxY)
        
        let convertedTopLeft = convertPoint(topLeft, from: from, to: to, canvasSize: canvasSize)
        let convertedBottomRight = convertPoint(bottomRight, from: from, to: to, canvasSize: canvasSize)
        
        let minX = min(convertedTopLeft.x, convertedBottomRight.x)
        let maxX = max(convertedTopLeft.x, convertedBottomRight.x)
        let minY = min(convertedTopLeft.y, convertedBottomRight.y)
        let maxY = max(convertedTopLeft.y, convertedBottomRight.y)
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// Generic point conversion between coordinate systems
    private static func convertPoint(
        _ point: CGPoint,
        from: CoordinateSystem,
        to: CoordinateSystem,
        canvasSize: CGSize
    ) -> CGPoint {
        guard from != to else { return point }
        
        // Convert to standard first
        var standardPoint = point
        switch from {
        case .uiKit:
            standardPoint = convertFromUIKit(point, viewHeight: canvasSize.height)
        case .spriteKit, .standard:
            standardPoint = point
        }
        
        // Then convert to target
        switch to {
        case .uiKit:
            return convertToUIKit(standardPoint, viewHeight: canvasSize.height)
        case .spriteKit, .standard:
            return standardPoint
        }
    }
}