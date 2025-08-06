//
//  GamePuzzleCanvasView.swift
//  Bemo
//
//  Simplified canvas view for displaying tangram puzzle during gameplay
//

// WHAT: Renders the target puzzle silhouette and overlays CV-tracked pieces
// ARCHITECTURE: View in MVVM-S pattern, uses game-specific models without editor dependencies
// USAGE: Embedded in TangramGameView during gameplay phase

import SwiftUI

struct GamePuzzleCanvasView: View {
    let puzzle: GamePuzzleData
    let placedPieces: [PlacedPiece]
    let anchorPieceId: String?
    let showHints: Bool
    let canvasSize: CGSize
    
    // Colors for rendering
    private let silhouetteColor = Color.black.opacity(0.3)
    private let correctPieceColor = Color.green.opacity(0.7)
    private let incorrectPieceColor = Color.red.opacity(0.5)
    private let movingPieceColor = Color.blue.opacity(0.5)
    private let hintColor = Color.yellow.opacity(0.5)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                // Target puzzle silhouettes
                targetSilhouetteLayer(size: geometry.size)
                
                // CV-tracked pieces overlay
                if !placedPieces.isEmpty {
                    cvPiecesLayer(size: geometry.size)
                }
                
                // Hint overlay
                if showHints {
                    hintOverlay(size: geometry.size)
                }
                
                // Debug info
                #if DEBUG
                debugInfoOverlay
                #endif
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: canvasSize.width, maxHeight: canvasSize.height)
    }
    
    // MARK: - Target Silhouettes
    
    private func targetSilhouetteLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(puzzle.targetPieces, id: \.pieceType) { target in
                SimplePieceShape(
                    pieceType: target.pieceType,
                    position: target.position,
                    rotation: target.rotation,
                    canvasSize: size
                )
                .fill(silhouetteColor)
                .overlay(
                    SimplePieceShape(
                        pieceType: target.pieceType,
                        position: target.position,
                        rotation: target.rotation,
                        canvasSize: size
                    )
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - CV Tracked Pieces
    
    private func cvPiecesLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(placedPieces) { placed in
                SimplePieceShape(
                    pieceType: placed.pieceType.rawValue,
                    position: placed.position,
                    rotation: placed.rotation,
                    canvasSize: size
                )
                .fill(pieceColor(for: placed))
                .overlay(
                    SimplePieceShape(
                        pieceType: placed.pieceType.rawValue,
                        position: placed.position,
                        rotation: placed.rotation,
                        canvasSize: size
                    )
                    .stroke(Color.white, lineWidth: placed.isMoving ? 1 : 2)
                    .opacity(placed.isMoving ? 0.5 : 1.0)
                )
                .opacity(placed.confidence)
                .scaleEffect(placed.isMoving ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: placed.isMoving)
                
                // Anchor indicator
                if placed.id == anchorPieceId {
                    anchorIndicator(for: placed, size: size)
                }
            }
        }
    }
    
    private func pieceColor(for placed: PlacedPiece) -> Color {
        if placed.isMoving {
            return movingPieceColor
        } else if placed.validationState == .correct {
            return correctPieceColor
        } else if placed.validationState == .incorrect {
            return incorrectPieceColor
        } else {
            return placed.pieceType.color.opacity(0.8)
        }
    }
    
    private func anchorIndicator(for piece: PlacedPiece, size: CGSize) -> some View {
        Circle()
            .stroke(Color.blue, lineWidth: 3)
            .frame(width: 30, height: 30)
            .position(
                x: piece.position.x * size.width / canvasSize.width,
                y: piece.position.y * size.height / canvasSize.height
            )
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: piece.id)
    }
    
    // MARK: - Hint Overlay
    
    private func hintOverlay(size: CGSize) -> some View {
        // Will implement in Phase 4
        EmptyView()
    }
    
    // MARK: - Debug Info
    
    #if DEBUG
    private var debugInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Target: \(puzzle.targetPieces.count) pieces")
            Text("Placed: \(placedPieces.count)")
            Text("Moving: \(placedPieces.filter { $0.isMoving }.count)")
            Text("Correct: \(placedPieces.filter { $0.validationState == .correct }.count)")
            if let anchorId = anchorPieceId {
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

// MARK: - Simplified Piece Shape

struct SimplePieceShape: Shape {
    let pieceType: String
    let position: CGPoint
    let rotation: Double
    let canvasSize: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Get basic shape for piece type (simplified without TangramGeometry)
        let vertices = getVertices(for: pieceType)
        
        // Apply position and rotation
        let center = CGPoint(
            x: position.x * rect.width / canvasSize.width,
            y: position.y * rect.height / canvasSize.height
        )
        
        let rotationRadians = rotation * .pi / 180
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: rotationRadians)
        
        let transformedVertices = vertices.map { vertex in
            vertex.applying(transform)
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
    
    private func getVertices(for pieceType: String) -> [CGPoint] {
        // Simplified vertices based on piece type
        // Using normalized coordinates that will be scaled
        let scale: CGFloat = 50 // Base scale factor
        
        switch pieceType {
        case "smallTriangle1", "smallTriangle2":
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale, y: 0),
                CGPoint(x: 0, y: scale)
            ]
        case "mediumTriangle":
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale * 1.414, y: 0),
                CGPoint(x: 0, y: scale * 1.414)
            ]
        case "largeTriangle1", "largeTriangle2":
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale * 2, y: 0),
                CGPoint(x: 0, y: scale * 2)
            ]
        case "square":
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale, y: 0),
                CGPoint(x: scale, y: scale),
                CGPoint(x: 0, y: scale)
            ]
        case "parallelogram":
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale * 1.414, y: 0),
                CGPoint(x: scale * 0.707, y: scale * 0.707),
                CGPoint(x: -scale * 0.707, y: scale * 0.707)
            ]
        default:
            // Default square shape
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale, y: 0),
                CGPoint(x: scale, y: scale),
                CGPoint(x: 0, y: scale)
            ]
        }
    }
}