//
//  TangramSpriteView.swift
//  Bemo
//
//  SwiftUI wrapper for SpriteKit Tangram scene
//

// WHAT: SwiftUI view that embeds the SpriteKit scene using SpriteView
// ARCHITECTURE: Bridge between SwiftUI UI layer and SpriteKit game layer
// USAGE: Replaces GamePuzzleCanvasView with physics-enabled SpriteKit canvas

import SwiftUI
import SpriteKit

struct TangramSpriteView: View {
    let puzzle: GamePuzzleData
    @Binding var placedPieces: [PlacedPiece]
    let showHints: Bool
    let onPieceCompleted: (String) -> Void
    let onPuzzleCompleted: () -> Void
    
    // Scene is created once and reused
    @State private var scene: SKScene = {
        let scene = TangramPuzzleScene()
        scene.size = CGSize(width: 600, height: 600)
        scene.scaleMode = .aspectFit
        return scene
    }()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // SpriteKit Scene
                SpriteView(
                    scene: scene,
                    options: [.allowsTransparency]
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .onAppear {
                    configureScene(size: geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    scene.size = newSize
                }
                .onChange(of: puzzle) { newPuzzle in
                    if let tangramScene = scene as? TangramPuzzleScene {
                        tangramScene.loadPuzzle(newPuzzle)
                    }
                }
                
                // Hint overlay in SwiftUI
                if showHints {
                    hintsOverlay
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showHints)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func configureScene(size: CGSize) {
        // Configure scene properties
        guard let tangramScene = scene as? TangramPuzzleScene else { return }
        
        tangramScene.size = size
        tangramScene.scaleMode = .aspectFit
        tangramScene.puzzle = puzzle
        tangramScene.onPieceCompleted = onPieceCompleted
        tangramScene.onPuzzleCompleted = onPuzzleCompleted
        
        // Load the puzzle
        tangramScene.loadPuzzle(puzzle)
    }
    
    @ViewBuilder
    private var hintsOverlay: some View {
        ZStack {
            ForEach(0..<puzzle.targetPieces.count, id: \.self) { index in
                let target = puzzle.targetPieces[index]
                let isPlaced = placedPieces.contains { $0.pieceType == target.pieceType }
                
                if !isPlaced {
                    HintOutlineShape(
                        pieceType: target.pieceType,
                        transform: target.transform
                    )
                    .stroke(
                        pieceTypeColor(target.pieceType),
                        lineWidth: 3
                    )
                    .opacity(0.6)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: showHints
                    )
                }
            }
        }
    }
    
    private func pieceTypeColor(_ pieceType: TangramPieceType) -> Color {
        // Map piece types to colors
        switch pieceType {
        case .largeTriangle1, .largeTriangle2:
            return .blue
        case .mediumTriangle:
            return .green
        case .smallTriangle1, .smallTriangle2:
            return .orange
        case .square:
            return .yellow
        case .parallelogram:
            return .purple
        }
    }
}

// Simple shape for hint outlines
struct HintOutlineShape: Shape {
    let pieceType: TangramPieceType
    let transform: CGAffineTransform
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Get the actual vertices for this piece type
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        let transformedVertices = TangramGameGeometry.transformVertices(scaledVertices, with: transform)
        
        // Draw the shape using transformed vertices
        if let firstVertex = transformedVertices.first {
            path.move(to: firstVertex)
            for vertex in transformedVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
}