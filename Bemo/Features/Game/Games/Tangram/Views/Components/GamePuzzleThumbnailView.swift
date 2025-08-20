//
//  GamePuzzleThumbnailView.swift
//  Bemo
//
//  Renders a thumbnail preview of a GamePuzzleData puzzle
//

// WHAT: Thumbnail renderer for GamePuzzleData using target pieces transforms
// ARCHITECTURE: SwiftUI View component that renders puzzle pieces from game data
// USAGE: Display preview of puzzle solutions in map nodes and other UI elements

import SwiftUI

struct GamePuzzleThumbnailView: View {
    let puzzleData: GamePuzzleData
    let size: CGSize
    
    init(puzzleData: GamePuzzleData, size: CGSize = CGSize(width: 50, height: 50)) {
        self.puzzleData = puzzleData
        self.size = size
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(TangramTheme.Backgrounds.secondaryPanel)
                    .aspectRatio(1, contentMode: .fit)
                
                if !puzzleData.targetPieces.isEmpty {
                    // Render puzzle pieces
                    ForEach(puzzleData.targetPieces, id: \.id) { targetPiece in
                        let pieceView = createPieceView(for: targetPiece, in: geometry.size)
                        pieceView
                    }
                } else {
                    // Placeholder when no pieces
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: min(size.width, size.height) * 0.4))
                        .foregroundColor(TangramTheme.Text.secondary)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    // MARK: - Helper Methods
    
    private func createPieceView(for targetPiece: GamePuzzleData.TargetPiece, in size: CGSize) -> some View {
        ZStack {
            Path { path in
                // Get vertices for the piece type
                let vertices = TangramGameGeometry.normalizedVertices(for: targetPiece.pieceType)
                
                // Apply visual scale
                let scaledVertices = vertices.map { 
                    CGPoint(x: $0.x * TangramConstants.visualScale, 
                            y: $0.y * TangramConstants.visualScale)
                }
                
                // Apply the target piece transform
                let transformed = scaledVertices.map { $0.applying(targetPiece.transform) }
                
                // Draw the path
                if let first = transformed.first {
                    path.move(to: normalizePoint(first, in: size))
                    for vertex in transformed.dropFirst() {
                        path.addLine(to: normalizePoint(vertex, in: size))
                    }
                    path.closeSubpath()
                }
            }
            .fill(targetPiece.pieceType.color.opacity(0.8))
            
            Path { path in
                // Same path for the outline
                let vertices = TangramGameGeometry.normalizedVertices(for: targetPiece.pieceType)
                let scaledVertices = vertices.map { 
                    CGPoint(x: $0.x * TangramConstants.visualScale, 
                            y: $0.y * TangramConstants.visualScale)
                }
                let transformed = scaledVertices.map { $0.applying(targetPiece.transform) }
                
                if let first = transformed.first {
                    path.move(to: normalizePoint(first, in: size))
                    for vertex in transformed.dropFirst() {
                        path.addLine(to: normalizePoint(vertex, in: size))
                    }
                    path.closeSubpath()
                }
            }
            .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
        }
    }
    
    private func normalizePoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let bounds = calculateBounds()
        guard bounds.width > 0 && bounds.height > 0 else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        // Calculate scale to fit within the given size with padding
        let scale = min(size.width / bounds.width * 0.8, size.height / bounds.height * 0.8)
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        return CGPoint(
            x: centerX + (point.x - bounds.midX) * scale,
            y: centerY + (point.y - bounds.midY) * scale
        )
    }
    
    private func calculateBounds() -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for targetPiece in puzzleData.targetPieces {
            let vertices = TangramGameGeometry.normalizedVertices(for: targetPiece.pieceType)
            let scaledVertices = vertices.map { 
                CGPoint(x: $0.x * TangramConstants.visualScale, 
                        y: $0.y * TangramConstants.visualScale)
            }
            let transformed = scaledVertices.map { $0.applying(targetPiece.transform) }
            
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
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Game Puzzle Thumbnails")
            .font(.headline)
        
        HStack(spacing: 20) {
            // Small thumbnail
            GamePuzzleThumbnailView(
                puzzleData: GamePuzzleData.mockPuzzle(id: "1", name: "Cat", difficulty: 3),
                size: CGSize(width: 50, height: 50)
            )
            
            // Medium thumbnail
            GamePuzzleThumbnailView(
                puzzleData: GamePuzzleData.mockPuzzle(id: "2", name: "House", difficulty: 2),
                size: CGSize(width: 80, height: 80)
            )
            
            // Large thumbnail
            GamePuzzleThumbnailView(
                puzzleData: GamePuzzleData.mockPuzzle(id: "3", name: "Bird", difficulty: 4),
                size: CGSize(width: 120, height: 120)
            )
        }
    }
    .padding()
    .background(TangramTheme.Backgrounds.editor)
}
