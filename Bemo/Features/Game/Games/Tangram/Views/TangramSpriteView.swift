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
            ForEach(puzzle.targetPieces, id: \.pieceType) { target in
                let isPlaced = placedPieces.contains { $0.pieceType.rawValue == target.pieceType }
                
                if !isPlaced {
                    HintOutlineShape(
                        pieceType: target.pieceType,
                        position: target.position,
                        rotation: target.rotation
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
    
    private func pieceTypeColor(_ pieceType: String) -> Color {
        // Map piece types to colors
        switch pieceType {
        case "largeTriangle1", "largeTriangle2":
            return .blue
        case "mediumTriangle":
            return .green
        case "smallTriangle1", "smallTriangle2":
            return .orange
        case "square":
            return .yellow
        case "parallelogram":
            return .purple
        default:
            return .gray
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
            
        case "mediumTriangle":
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + 45, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + 45))
            path.closeSubpath()
            
        case "largeTriangle1", "largeTriangle2":
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + 60, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + 60))
            path.closeSubpath()
            
        case "square":
            path.addRect(CGRect(x: center.x - 25, y: center.y - 25, width: 50, height: 50))
            
        case "parallelogram":
            path.move(to: CGPoint(x: center.x - 25, y: center.y))
            path.addLine(to: CGPoint(x: center.x + 25, y: center.y))
            path.addLine(to: CGPoint(x: center.x + 10, y: center.y + 30))
            path.addLine(to: CGPoint(x: center.x - 40, y: center.y + 30))
            path.closeSubpath()
            
        default:
            path.addEllipse(in: CGRect(x: center.x - 25, y: center.y - 25, width: 50, height: 50))
        }
        
        return path
    }
}