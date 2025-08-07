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
    
    @State private var scene: TangramPuzzleScene?
    
    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: createScene(size: geometry.size))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .overlay(
                    // Hint overlay in SwiftUI
                    hintsOverlay
                        .allowsHitTesting(false)
                        .opacity(showHints ? 1 : 0)
                        .animation(.easeInOut, value: showHints)
                )
                .onAppear {
                    setupScene()
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func createScene(size: CGSize) -> SKScene {
        if scene == nil {
            let newScene = TangramPuzzleScene()
            newScene.size = size
            newScene.scaleMode = .aspectFit
            newScene.puzzle = puzzle
            newScene.onPieceCompleted = onPieceCompleted
            newScene.onPuzzleCompleted = onPuzzleCompleted
            scene = newScene
        }
        return scene!
    }
    
    private func setupScene() {
        // Setup any initial state
        scene?.loadPuzzle(puzzle)
    }
    
    @ViewBuilder
    private var hintsOverlay: some View {
        if showHints {
            ZStack {
                ForEach(puzzle.targetPieces, id: \.pieceType) { target in
                    let isPlaced = placedPieces.contains { $0.pieceType.rawValue == target.pieceType }
                    
                    if !isPlaced {
                        HintOutlineShape(
                            pieceType: target.pieceType,
                            position: target.position,
                            rotation: target.rotation
                        )
                        .stroke(
                            PieceType(rawValue: target.pieceType)?.color ?? .gray,
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
    }
}

// Simple shape for hint outlines
struct HintOutlineShape: Shape {
    let pieceType: String
    let position: CGPoint
    let rotation: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Simplified shape outlines
        let center = CGPoint(
            x: rect.width * position.x / 600,
            y: rect.height * position.y / 600
        )
        
        switch pieceType {
        case "smallTriangle1", "smallTriangle2":
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + 30, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + 30))
            path.closeSubpath()
            
        case "square":
            path.addRect(CGRect(x: center.x - 25, y: center.y - 25, width: 50, height: 50))
            
        default:
            path.addEllipse(in: CGRect(x: center.x - 25, y: center.y - 25, width: 50, height: 50))
        }
        
        return path
    }
}