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
    let difficultySetting: UserPreferences.DifficultySetting
    @Binding var placedPieces: [PlacedPiece]
    let timerStarted: Bool
    let formattedTime: String
    let progress: Double
    let isPuzzleComplete: Bool
    let showHints: Bool
    let currentHint: TangramHintEngine.HintData?
    let cvOverlayImage: UIImage?
    let cvFPS: Double
    // Tangram model polygons and colors from CV pipeline
    let modelPlanePolygons: [NSNumber: [NSNumber]]
    let modelColorsRGB: [NSNumber: [NSNumber]]
    // Notify CVService about view size to mirror sample app behavior
    let onViewSizeChange: (CGSize) -> Void
    let onPieceCompleted: (String, Bool) -> Void  // pieceType and isFlipped
    let onPuzzleCompleted: () -> Void
    let onBackPressed: () -> Void
    let onNextPressed: () -> Void
    let onStartTimer: () -> Void
    let onToggleHints: () -> Void
    let onValidatedTargetsChanged: (Set<String>) -> Void
    
    // Scene is created once and reused
    @State private var scene: SKScene = {
        let scene = TangramPuzzleScene(size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        scene.scaleMode = .resizeFill
        return scene
    }()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main SpriteKit scene showing puzzle outline and CV-recognized pieces
                SpriteView(
                    scene: scene
                )
                .ignoresSafeArea()
                .onAppear {
                    configureScene(size: geometry.size, safeAreaTop: geometry.safeAreaInsets.top)
                    if let tangramScene = scene as? TangramPuzzleScene, !modelPlanePolygons.isEmpty {
                        tangramScene.updateModelPolygons(
                            planeModelPolygons: modelPlanePolygons,
                            modelColorsRGB: modelColorsRGB
                        )
                    }
                    onViewSizeChange(geometry.size)
                }
                .onChange(of: geometry.size) { _, newSize in
                    onViewSizeChange(newSize)
                }
                
                // CV overlay anchored to the top-right corner (static mini panel)
                if cvOverlayImage != nil {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ZStack {
                                // Background panel
                                Rectangle()
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                                    )
                                // Overlay image
                                if let overlay = cvOverlayImage {
                                    Image(uiImage: overlay)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding(8)
                                }
                                // FPS badge
                                VStack {
                                    HStack {
                                        Spacer()
                                        if cvFPS > 0 {
                                            Text(String(format: "%.1f FPS", cvFPS))
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(8)
                                                .background(Color.black.opacity(0.5))
                                                .cornerRadius(4)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(8)
                            }
                            .frame(width: (geometry.size.width * 0.3),
                                   height: (geometry.size.width * 0.3))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                }
            }
        }
        .onChange(of: puzzle) { oldValue, newValue in
            if let tangramScene = scene as? TangramPuzzleScene {
                tangramScene.loadPuzzle(newValue)
            }
        }
        .onChange(of: difficultySetting) { _, newValue in
            if let tangramScene = scene as? TangramPuzzleScene {
                tangramScene.difficultySetting = newValue
            }
        }
        // Propagate difficulty changes via puzzle reloads or view updates if needed later
        .onChange(of: isPuzzleComplete) { oldValue, newValue in
            if let tangramScene = scene as? TangramPuzzleScene {
                // Convert bool to set of completed pieces (empty if not complete)
                let completedSet = newValue ? Set(puzzle.targetPieces.map { $0.id }) : Set<String>()
                tangramScene.updateCompletionState(completedSet)
            }
        }
        .onChange(of: currentHint) { oldValue, newValue in
            print("DEBUG: onChange triggered - old: \(oldValue != nil), new: \(newValue != nil)")
            if let hint = newValue {
                print("DEBUG: New hint details - type: \(hint.hintType), piece: \(hint.targetPiece.rawValue)")
            }
            
            if let tangramScene = scene as? TangramPuzzleScene {
                if let hint = newValue {
                    tangramScene.showStructuredHint(hint)
                } else {
                    // Clear any existing hints when hint becomes nil
                    tangramScene.hideHint()
                }
            }
        }
        .onChange(of: placedPieces) { _, newPieces in
            // Update scene with CV-detected pieces
            if let tangramScene = scene as? TangramPuzzleScene {
                tangramScene.updateFromCVPieces(newPieces)
                if !modelPlanePolygons.isEmpty {
                    tangramScene.updateModelPolygons(
                        planeModelPolygons: modelPlanePolygons,
                        modelColorsRGB: modelColorsRGB
                    )
                }
            }
        }
        .onChange(of: modelPlanePolygons) { _, newPolys in
            if let tangramScene = scene as? TangramPuzzleScene, !newPolys.isEmpty {
                tangramScene.updateModelPolygons(
                    planeModelPolygons: newPolys,
                    modelColorsRGB: modelColorsRGB
                )
            }
        }
    }
    
    private func configureScene(size: CGSize, safeAreaTop: CGFloat) {
        // Configure scene properties
        guard let tangramScene = scene as? TangramPuzzleScene else { return }
        
        tangramScene.size = size
        tangramScene.scaleMode = .resizeFill
        tangramScene.safeAreaTop = safeAreaTop  // Pass safe area to scene
        tangramScene.canvasSize = CGSize(width: 1080, height: 1920) // Match CVService viewSize
        tangramScene.puzzle = puzzle
        tangramScene.difficultySetting = difficultySetting
        tangramScene.onPieceCompleted = onPieceCompleted
        tangramScene.onPuzzleCompleted = onPuzzleCompleted
        tangramScene.onBackPressed = onBackPressed
        tangramScene.onNextPressed = onNextPressed
        tangramScene.onStartTimer = onStartTimer
        tangramScene.onToggleHints = onToggleHints
        tangramScene.onValidatedTargetsChanged = onValidatedTargetsChanged
        
        // Load the puzzle (no UI elements needed - handled by SwiftUI)
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
