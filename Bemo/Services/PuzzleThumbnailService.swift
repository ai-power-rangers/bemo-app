//
//  PuzzleThumbnailService.swift
//  Bemo
//
//  Shared service for rendering puzzle thumbnails across all games
//

// WHAT: Centralized service for generating consistent puzzle thumbnails
// ARCHITECTURE: Service layer in MVVM-S, provides thumbnail rendering for all puzzle games
// USAGE: Used by Tangram Editor, Tangram Game, TangramCV, and future puzzle games

import SwiftUI
import UIKit

/// Service for rendering puzzle thumbnails consistently across all games
class PuzzleThumbnailService {
    
    // MARK: - Singleton (Optional - can be injected via DependencyContainer instead)
    static let shared = PuzzleThumbnailService()
    
    // MARK: - Public Methods
    
    /// Render a tangram puzzle thumbnail view
    /// - Parameters:
    ///   - puzzle: The puzzle data to render
    ///   - colorful: Whether to use piece colors or gray silhouettes
    ///   - size: Target size for the thumbnail
    /// - Returns: A SwiftUI view of the puzzle thumbnail
    func tangramThumbnailView(for puzzle: GamePuzzleData, colorful: Bool = true) -> some View {
        TangramThumbnailView(puzzle: puzzle, colorful: colorful)
    }
    
    /// Generate a UIImage thumbnail for a tangram puzzle
    /// - Parameters:
    ///   - puzzle: The puzzle data to render
    ///   - size: Target size for the thumbnail image
    ///   - colorful: Whether to use piece colors or gray silhouettes
    /// - Returns: A UIImage of the puzzle thumbnail
    @MainActor
    func generateTangramThumbnailImage(for puzzle: GamePuzzleData, size: CGSize, colorful: Bool = true) async -> UIImage? {
        let renderer = ImageRenderer(content: TangramThumbnailView(puzzle: puzzle, colorful: colorful)
            .frame(width: size.width, height: size.height))
        
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

// MARK: - Internal Tangram Thumbnail View

struct TangramThumbnailView: View {
    let puzzle: GamePuzzleData
    let colorful: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let bounds = calculatePuzzleBounds()
            let scale = calculateScale(for: bounds, in: geometry.size)
            let offset = calculateOffset(for: bounds, scale: scale, in: geometry.size)
            
            ForEach(puzzle.targetPieces.indices, id: \.self) { index in
                let piece = puzzle.targetPieces[index]
                TangramPuzzlePieceShape(
                    pieceType: piece.pieceType,
                    transform: piece.transform,
                    scale: scale,
                    offset: offset
                )
                .fill(pieceColor(for: piece.pieceType))
                .overlay(
                    TangramPuzzlePieceShape(
                        pieceType: piece.pieceType,
                        transform: piece.transform,
                        scale: scale,
                        offset: offset
                    )
                    .stroke(strokeColor(for: piece.pieceType), lineWidth: 0.5)
                )
            }
        }
    }
    
    private func pieceColor(for type: TangramPieceType) -> Color {
        if colorful {
            // Use actual piece colors
            return Color(uiColor(for: type))
        } else {
            // Use gray silhouette
            return Color.gray.opacity(0.7)
        }
    }
    
    private func strokeColor(for type: TangramPieceType) -> Color {
        if colorful {
            return Color(darkerColor(uiColor(for: type), by: 20))
        } else {
            return Color.gray
        }
    }
    
    private func uiColor(for pieceType: TangramPieceType) -> UIColor {
        // Define colors inline to avoid dependencies
        switch pieceType {
        case .smallTriangle1: return UIColor(red: 196/255.0, green: 69/255.0, blue: 164/255.0, alpha: 1.0)  // Purple-pink
        case .smallTriangle2: return UIColor(red: 2/255.0, green: 183/255.0, blue: 205/255.0, alpha: 1.0)    // Cyan
        case .mediumTriangle: return UIColor(red: 43/255.0, green: 186/255.0, blue: 53/255.0, alpha: 1.0)    // Green
        case .largeTriangle1: return UIColor(red: 56/255.0, green: 150/255.0, blue: 255/255.0, alpha: 1.0)   // Blue
        case .largeTriangle2: return UIColor(red: 255/255.0, green: 58/255.0, blue: 65/255.0, alpha: 1.0)    // Red
        case .square: return UIColor(red: 255/255.0, green: 217/255.0, blue: 53/255.0, alpha: 1.0)           // Yellow
        case .parallelogram: return UIColor(red: 255/255.0, green: 134/255.0, blue: 37/255.0, alpha: 1.0)     // Orange
        }
    }
    
    private func darkerColor(_ color: UIColor, by percentage: CGFloat = 20.0) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            let factor = 1.0 - (percentage / 100.0)
            return UIColor(hue: hue,
                          saturation: saturation,
                          brightness: brightness * factor,
                          alpha: alpha)
        }
        
        return color
    }
    
    private func calculatePuzzleBounds() -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in puzzle.targetPieces {
            let vertices = normalizedVertices(for: piece.pieceType)
            let scaled = vertices.map { CGPoint(x: $0.x * 50, y: $0.y * 50) }
            let transformed = scaled.map { $0.applying(piece.transform) }
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func calculateScale(for bounds: CGRect, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 16
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        
        let scaleX = availableWidth / bounds.width
        let scaleY = availableHeight / bounds.height
        
        return min(scaleX, scaleY, 1.0) // Don't scale up beyond original size
    }
    
    private func calculateOffset(for bounds: CGRect, scale: CGFloat, in size: CGSize) -> CGPoint {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        let offsetX = centerX - (bounds.midX * scale)
        let offsetY = centerY - (bounds.midY * scale)
        
        return CGPoint(x: offsetX, y: offsetY)
    }
    
    private func normalizedVertices(for type: TangramPieceType) -> [CGPoint] {
        switch type {
        case .smallTriangle1, .smallTriangle2:
            return [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1)]
            
        case .mediumTriangle:
            let sqrt2 = CGFloat(sqrt(2.0))
            return [CGPoint(x: 0, y: 0), CGPoint(x: sqrt2, y: 0), CGPoint(x: 0, y: sqrt2)]
            
        case .largeTriangle1, .largeTriangle2:
            return [CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 0, y: 2)]
            
        case .square:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: 1)
            ]
            
        case .parallelogram:
            let sqrt2 = CGFloat(sqrt(2.0))
            let halfSqrt2 = sqrt2 / 2.0
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: sqrt2, y: 0),
                CGPoint(x: halfSqrt2, y: halfSqrt2),
                CGPoint(x: -halfSqrt2, y: halfSqrt2)
            ]
        }
    }
}

// MARK: - Reusable Shape

struct TangramPuzzlePieceShape: Shape {
    let pieceType: TangramPieceType
    let transform: CGAffineTransform
    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let normalizedVertices = vertices(for: pieceType)
        let scaledVertices = normalizedVertices.map { CGPoint(x: $0.x * 50, y: $0.y * 50) }
        let transformedVertices = scaledVertices.map { $0.applying(transform) }
        
        // Apply thumbnail scaling and offset
        let finalVertices = transformedVertices.map { vertex in
            CGPoint(
                x: vertex.x * scale + offset.x,
                y: vertex.y * scale + offset.y
            )
        }
        
        if let firstVertex = finalVertices.first {
            path.move(to: firstVertex)
            for vertex in finalVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
    
    private func vertices(for type: TangramPieceType) -> [CGPoint] {
        switch type {
        case .smallTriangle1, .smallTriangle2:
            return [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1)]
            
        case .mediumTriangle:
            let sqrt2 = CGFloat(sqrt(2.0))
            return [CGPoint(x: 0, y: 0), CGPoint(x: sqrt2, y: 0), CGPoint(x: 0, y: sqrt2)]
            
        case .largeTriangle1, .largeTriangle2:
            return [CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 0, y: 2)]
            
        case .square:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: 1)
            ]
            
        case .parallelogram:
            let sqrt2 = CGFloat(sqrt(2.0))
            let halfSqrt2 = sqrt2 / 2.0
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: sqrt2, y: 0),
                CGPoint(x: halfSqrt2, y: halfSqrt2),
                CGPoint(x: -halfSqrt2, y: halfSqrt2)
            ]
        }
    }
}