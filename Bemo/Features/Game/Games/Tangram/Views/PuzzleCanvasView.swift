//
//  PuzzleCanvasView.swift
//  Bemo
//
//  Canvas view for displaying tangram puzzle silhouettes and piece overlays
//

// WHAT: Renders the target tangram puzzle as dark silhouettes for players to match
// ARCHITECTURE: View in MVVM-S pattern, displays puzzle state from view model
// USAGE: Embedded in TangramGameView during gameplay phase

import SwiftUI

struct PuzzleCanvasView: View {
    let puzzle: TangramPuzzle
    let gameState: PuzzleGameState
    let showHints: Bool
    let canvasSize: CGSize
    
    // Colors for rendering
    private let silhouetteColor = Color.black.opacity(0.3)
    private let correctPieceColor = Color.green.opacity(0.7)
    private let incorrectPieceColor = Color.red.opacity(0.5)
    private let hintColor = Color.yellow.opacity(0.5)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                // Puzzle silhouettes
                puzzleSilhouetteLayer(size: geometry.size)
                
                // Placed pieces overlay (Phase 2)
                if !gameState.placedPieces.isEmpty {
                    placedPiecesLayer(size: geometry.size)
                }
                
                // Hint overlay (Phase 4)
                if showHints {
                    hintOverlay(size: geometry.size)
                }
                
                // Debug info (development only)
                #if DEBUG
                debugInfoOverlay
                #endif
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: canvasSize.width, maxHeight: canvasSize.height)
    }
    
    // MARK: - Puzzle Silhouettes
    
    private func puzzleSilhouetteLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(puzzle.pieces) { piece in
                PuzzlePieceShape(
                    piece: piece,
                    canvasSize: size
                )
                .fill(silhouetteColor)
                .overlay(
                    PuzzlePieceShape(
                        piece: piece,
                        canvasSize: size
                    )
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Placed Pieces (Phase 2)
    
    private func placedPiecesLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(gameState.placedPieces) { placed in
                if let targetPiece = gameState.pieceInTargetPuzzle(type: placed.type) {
                    PuzzlePieceShape(
                        piece: TangramPiece(
                            type: placed.type,
                            transform: placed.transform
                        ),
                        canvasSize: size
                    )
                    .fill(pieceColor(for: placed))
                    .overlay(
                        PuzzlePieceShape(
                            piece: TangramPiece(
                                type: placed.type,
                                transform: placed.transform
                            ),
                            canvasSize: size
                        )
                        .stroke(Color.white, lineWidth: 2)
                    )
                    .opacity(placed.confidence)
                    
                    // Anchor indicator
                    if placed.id == gameState.anchorPieceId {
                        anchorIndicator(for: placed, size: size)
                    }
                }
            }
        }
    }
    
    private func pieceColor(for placed: PlacedPiece) -> Color {
        if gameState.correctPieceIds.contains(placed.id) {
            return correctPieceColor
        } else {
            return placed.type.color.opacity(0.8)
        }
    }
    
    private func anchorIndicator(for piece: PlacedPiece, size: CGSize) -> some View {
        Circle()
            .stroke(Color.blue, lineWidth: 3)
            .frame(width: 30, height: 30)
            .position(piece.position)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: piece.id)
    }
    
    // MARK: - Hint Overlay (Phase 4)
    
    private func hintOverlay(size: CGSize) -> some View {
        // Placeholder for hint system
        EmptyView()
    }
    
    // MARK: - Debug Info
    
    #if DEBUG
    private var debugInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pieces: \(puzzle.pieces.count)")
            Text("Placed: \(gameState.placedPieces.count)")
            Text("Correct: \(gameState.correctPieceIds.count)")
            Text("Progress: \(Int(gameState.progress * 100))%")
            if let anchorId = gameState.anchorPieceId {
                Text("Anchor: \(String(anchorId.prefix(8)))")
            }
        }
        .font(.caption2)
        .padding(8)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
    #endif
}

// MARK: - Puzzle Piece Shape

struct PuzzlePieceShape: Shape {
    let piece: TangramPiece
    let canvasSize: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Get vertices for the piece type
        let vertices = TangramGeometry.vertices(for: piece.type)
        
        // Apply transform and scale to canvas
        let transformedVertices = vertices.map { vertex in
            let transformed = vertex.applying(piece.transform)
            return CGPoint(
                x: transformed.x * rect.width / canvasSize.width,
                y: transformed.y * rect.height / canvasSize.height
            )
        }
        
        // Create path
        if let first = transformedVertices.first {
            path.move(to: first)
            for vertex in transformedVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
}

// MARK: - Preview

#Preview("Puzzle Canvas") {
    let testPuzzle = TangramPuzzle(
        name: "Test Square",
        category: .geometric,
        difficulty: .easy,
        source: .bundled
    )
    
    let gameState = PuzzleGameState(targetPuzzle: testPuzzle)
    
    PuzzleCanvasView(
        puzzle: testPuzzle,
        gameState: gameState,
        showHints: false,
        canvasSize: CGSize(width: 600, height: 600)
    )
    .frame(width: 400, height: 400)
    .padding()
}