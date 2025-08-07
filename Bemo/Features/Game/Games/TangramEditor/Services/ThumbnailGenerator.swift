//
//  ThumbnailGenerator.swift
//  Bemo
//
//  Generates visual thumbnails of tangram puzzles
//

import SwiftUI

class ThumbnailGenerator {
    private let defaultSize = CGSize(width: 200, height: 200)
    
    // MARK: - Public Methods
    
    /// Generate thumbnail for a puzzle using SwiftUI ImageRenderer
    func generateThumbnail(for puzzle: TangramPuzzle, size: CGSize? = nil) async -> Data? {
        let targetSize = size ?? defaultSize
        
        return await MainActor.run {
            // Create SwiftUI view of the puzzle
            let puzzleView = ThumbnailPuzzleView(puzzle: puzzle)
                .frame(width: targetSize.width, height: targetSize.height)
                .background(Color.white)
            
            // Render to image using ImageRenderer (iOS 16+ feature, but we require iOS 17+)
            let renderer = ImageRenderer(content: puzzleView)
            renderer.scale = 2.0 // Retina quality
            
            guard let uiImage = renderer.uiImage else { return nil }
            return uiImage.pngData()
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
                        .fill(piece.type.color.opacity(0.8))
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
    
    func calculatePuzzleBounds() -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in puzzle.pieces {
            let vertices = TangramGeometry.vertices(for: piece.type)
            // CRITICAL: Scale vertices before applying transform (matching rendering)
            let scaledVertices = vertices.map { 
                CGPoint(x: $0.x * TangramConstants.visualScale, 
                        y: $0.y * TangramConstants.visualScale)
            }
            let transformed = scaledVertices.map { $0.applying(piece.transform) }
            
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
        // CRITICAL: Scale vertices before applying transform (matching rendering)
        let scaledVertices = vertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale)
        }
        let transformed = scaledVertices.map { $0.applying(piece.transform) }
        
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