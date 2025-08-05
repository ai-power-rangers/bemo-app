//
//  ThumbnailGenerator.swift
//  Bemo
//
//  Generates visual thumbnails of tangram puzzles
//

import SwiftUI
import UIKit

@MainActor
class ThumbnailGenerator {
    private let defaultSize = CGSize(width: 200, height: 200)
    
    // MARK: - Public Methods
    
    /// Generate thumbnail for a puzzle using SwiftUI rendering (iOS 16+)
    @available(iOS 16.0, *)
    func generateThumbnail(for puzzle: TangramPuzzle, size: CGSize? = nil) async -> Data? {
        let targetSize = size ?? defaultSize
        
        // Create SwiftUI view of the puzzle
        let puzzleView = ThumbnailPuzzleView(puzzle: puzzle)
            .frame(width: targetSize.width, height: targetSize.height)
            .background(Color.white)
        
        // Render to image using ImageRenderer
        let renderer = ImageRenderer(content: puzzleView)
        renderer.scale = 2.0 // Retina quality
        
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.pngData()
    }
    
    /// Legacy method for iOS 15 and below using UIKit
    func generateThumbnailLegacy(for puzzle: TangramPuzzle, size: CGSize? = nil) -> Data? {
        let targetSize = size ?? defaultSize
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 2.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // White background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: targetSize))
        
        // Calculate bounds and scale
        let bounds = calculatePuzzleBounds(puzzle)
        guard bounds.width > 0 && bounds.height > 0 else { return nil }
        
        let scale = min(
            targetSize.width / bounds.width * 0.8,
            targetSize.height / bounds.height * 0.8
        )
        
        // Center offset
        let offsetX = (targetSize.width - bounds.width * scale) / 2 - bounds.minX * scale
        let offsetY = (targetSize.height - bounds.height * scale) / 2 - bounds.minY * scale
        
        // Draw each piece
        for piece in puzzle.pieces {
            drawPiece(piece, in: context, scale: scale, offset: CGPoint(x: offsetX, y: offsetY))
        }
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        return image.pngData()
    }
    
    /// Generate thumbnail with automatic iOS version detection
    func generateThumbnailAuto(for puzzle: TangramPuzzle, size: CGSize? = nil) async -> Data? {
        if #available(iOS 16.0, *) {
            return await generateThumbnail(for: puzzle, size: size)
        } else {
            return generateThumbnailLegacy(for: puzzle, size: size)
        }
    }
    
    // MARK: - Private Methods
    
    private func calculatePuzzleBounds(_ puzzle: TangramPuzzle) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in puzzle.pieces {
            let vertices = TangramGeometry.vertices(for: piece.type)
            let transformed = GeometryEngine.transformVertices(vertices, with: piece.transform)
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                minY = min(minY, vertex.y)
                maxX = max(maxX, vertex.x)
                maxY = max(maxY, vertex.y)
            }
        }
        
        // Return zero rect if no pieces
        guard minX < CGFloat.greatestFiniteMagnitude else {
            return .zero
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func drawPiece(_ piece: TangramPiece, in context: CGContext, scale: CGFloat, offset: CGPoint) {
        let vertices = TangramGeometry.vertices(for: piece.type)
        let transformed = GeometryEngine.transformVertices(vertices, with: piece.transform)
        
        guard let first = transformed.first else { return }
        
        // Create path
        context.beginPath()
        context.move(to: CGPoint(
            x: first.x * scale + offset.x,
            y: first.y * scale + offset.y
        ))
        
        for vertex in transformed.dropFirst() {
            context.addLine(to: CGPoint(
                x: vertex.x * scale + offset.x,
                y: vertex.y * scale + offset.y
            ))
        }
        
        context.closePath()
        
        // Fill with piece color
        context.setFillColor(colorForPiece(piece.type).cgColor)
        context.fillPath()
        
        // Draw again for stroke
        context.beginPath()
        context.move(to: CGPoint(
            x: first.x * scale + offset.x,
            y: first.y * scale + offset.y
        ))
        
        for vertex in transformed.dropFirst() {
            context.addLine(to: CGPoint(
                x: vertex.x * scale + offset.x,
                y: vertex.y * scale + offset.y
            ))
        }
        
        context.closePath()
        
        // Stroke border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()
    }
    
    private func colorForPiece(_ type: PieceType) -> UIColor {
        switch type {
        case .smallTriangle1, .smallTriangle2: 
            return .systemBlue.withAlphaComponent(0.8)
        case .mediumTriangle: 
            return .systemGreen.withAlphaComponent(0.8)
        case .largeTriangle1, .largeTriangle2: 
            return .systemRed.withAlphaComponent(0.8)
        case .square: 
            return .systemYellow.withAlphaComponent(0.8)
        case .parallelogram: 
            return .systemPurple.withAlphaComponent(0.8)
        }
    }
}

// MARK: - SwiftUI View for Thumbnail

struct ThumbnailPuzzleView: View {
    let puzzle: TangramPuzzle
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(puzzle.pieces) { piece in
                    ThumbnailPieceShape(piece: piece, puzzleBounds: calculatePuzzleBounds())
                        .fill(colorForPiece(piece.type))
                        .overlay(
                            ThumbnailPieceShape(piece: piece, puzzleBounds: calculatePuzzleBounds())
                                .stroke(Color.black, lineWidth: 0.5)
                        )
                }
            }
            .scaleEffect(calculateScale(for: geometry.size))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    func colorForPiece(_ type: PieceType) -> Color {
        switch type {
        case .smallTriangle1, .smallTriangle2: 
            return .blue.opacity(0.8)
        case .mediumTriangle: 
            return .green.opacity(0.8)
        case .largeTriangle1, .largeTriangle2: 
            return .red.opacity(0.8)
        case .square: 
            return .yellow.opacity(0.8)
        case .parallelogram: 
            return .purple.opacity(0.8)
        }
    }
    
    func calculatePuzzleBounds() -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in puzzle.pieces {
            let vertices = TangramGeometry.vertices(for: piece.type)
            let transformed = vertices.map { $0.applying(piece.transform) }
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                minY = min(minY, vertex.y)
                maxX = max(maxX, vertex.x)
                maxY = max(maxY, vertex.y)
            }
        }
        
        guard minX < CGFloat.greatestFiniteMagnitude else {
            return .zero
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func calculateScale(for size: CGSize) -> CGFloat {
        let bounds = calculatePuzzleBounds()
        guard bounds.width > 0 && bounds.height > 0 else { return 1.0 }
        
        return min(
            size.width / bounds.width * 0.8,
            size.height / bounds.height * 0.8
        )
    }
}

struct ThumbnailPieceShape: Shape {
    let piece: TangramPiece
    let puzzleBounds: CGRect
    
    func path(in rect: CGRect) -> Path {
        let vertices = TangramGeometry.vertices(for: piece.type)
        let transformed = vertices.map { $0.applying(piece.transform) }
        
        var path = Path()
        
        if let first = transformed.first {
            // Normalize to thumbnail space
            let normalizedFirst = normalizePoint(first, in: rect)
            path.move(to: normalizedFirst)
            
            for vertex in transformed.dropFirst() {
                let normalizedVertex = normalizePoint(vertex, in: rect)
                path.addLine(to: normalizedVertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
    
    func normalizePoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        guard puzzleBounds.width > 0 && puzzleBounds.height > 0 else {
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        
        let normalizedX = (point.x - puzzleBounds.minX) / puzzleBounds.width
        let normalizedY = (point.y - puzzleBounds.minY) / puzzleBounds.height
        
        return CGPoint(
            x: normalizedX * rect.width,
            y: normalizedY * rect.height
        )
    }
}