//
//  TangramGameViewModel.swift
//  Bemo
//
//  ViewModel for the Tangram game view
//

// WHAT: ViewModel for TangramGameView. Manages display state, animations, and visual feedback for the Tangram game.
// ARCHITECTURE: Presentation layer in game's internal MVVM. Transforms game state into view-friendly display models.
// USAGE: Created by TangramGame. Updates view based on game logic. Manages target outlines, placed pieces, and feedback messages.

import SwiftUI
import Combine

class TangramGameViewModel: ObservableObject {
    @Published var targetShapeName: String = ""
    @Published var targetOutlines: [ShapeOutline] = []
    @Published var placedPieces: [PlacedPieceDisplay] = []
    @Published var showFeedback: Bool = false
    @Published var feedbackMessage: String = ""
    @Published var feedbackColor: Color = .green
    
    private let game: TangramGame
    private weak var delegate: GameDelegate?
    private var cancellables = Set<AnyCancellable>()
    
    // Display models
    struct ShapeOutline: Identifiable {
        let id = UUID()
        let shape: AnyShape
        let position: CGPoint
        let rotation: Double
        let size: CGSize
    }
    
    struct PlacedPieceDisplay: Identifiable {
        let id = UUID()
        let shape: AnyShape
        let position: CGPoint
        let rotation: Double
        let size: CGSize
        let color: Color
    }
    
    init(game: TangramGame, delegate: GameDelegate) {
        self.game = game
        self.delegate = delegate
    }
    
    func startGame() {
        // Initialize display based on current game state
        updateDisplay()
    }
    
    private func updateDisplay() {
        // This would be updated based on game state
        targetShapeName = "House"
        
        // Create target outlines
        targetOutlines = [
            ShapeOutline(
                shape: AnyShape(Triangle()),
                position: CGPoint(x: 200, y: 150),
                rotation: 0,
                size: CGSize(width: 100, height: 100)
            ),
            ShapeOutline(
                shape: AnyShape(Rectangle()),
                position: CGPoint(x: 200, y: 250),
                rotation: 0,
                size: CGSize(width: 100, height: 100)
            )
        ]
    }
    
    func showPositiveFeedback(_ message: String) {
        feedbackMessage = message
        feedbackColor = .green
        showFeedback = true
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showFeedback = false
        }
    }
    
    func showNegativeFeedback(_ message: String) {
        feedbackMessage = message
        feedbackColor = .red
        showFeedback = true
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showFeedback = false
        }
    }
}

// MARK: - Shape Helpers

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}