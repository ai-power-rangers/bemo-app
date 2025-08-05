//
//  TangramGame.swift
//  Bemo
//
//  Concrete implementation of the Tangram puzzle game
//

// WHAT: Tangram puzzle game implementation. Manages game logic for matching physical pieces to target shapes.
// ARCHITECTURE: Concrete Game protocol implementation. Self-contained game module that processes CV input and manages game state.
// USAGE: Add to GameLobbyViewModel's game list. Handles piece placement validation, level progression, and score tracking.

import SwiftUI

class TangramGame: Game {
    let id = "tangram"
    let title = "Tangram Puzzles"
    let description = "Create shapes using geometric pieces"
    let recommendedAge = 4...8
    let thumbnailImageName = "tangram_thumbnail"
    
    private weak var delegate: GameDelegate?
    private var currentLevel = 1
    private var placedPieces: Set<PlacedPiece> = []
    private var targetShape: TargetShape
    
    struct PlacedPiece: Hashable {
        let shape: ShapeType
        let position: CGPoint
        let rotation: Double
    }
    
    struct TargetShape {
        let name: String
        let requiredPieces: [ShapeRequirement]
    }
    
    struct ShapeRequirement {
        let shape: ShapeType
        let targetPosition: CGPoint
        let targetRotation: Double
        let tolerance: Double = 50.0 // Position tolerance in points
    }
    
    enum ShapeType {
        case triangle
        case square
        case parallelogram
    }
    
    init() {
        // Initialize with first level
        self.targetShape = TargetShape(
            name: "House",
            requiredPieces: [
                ShapeRequirement(shape: .triangle, targetPosition: CGPoint(x: 200, y: 100), targetRotation: 0),
                ShapeRequirement(shape: .square, targetPosition: CGPoint(x: 200, y: 200), targetRotation: 0)
            ]
        )
    }
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        self.delegate = delegate
        let viewModel = TangramGameViewModel(game: self, delegate: delegate)
        return AnyView(TangramGameView(viewModel: viewModel))
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Convert recognized pieces to game pieces
        for piece in pieces {
            if let shapeType = convertToShapeType(piece.shape) {
                let placedPiece = PlacedPiece(
                    shape: shapeType,
                    position: piece.position,
                    rotation: piece.rotation
                )
                
                // Check if this piece fits the target
                if let matchedRequirement = findMatchingRequirement(for: placedPiece) {
                    placedPieces.insert(placedPiece)
                    
                    // Check if level is complete
                    if placedPieces.count == targetShape.requiredPieces.count {
                        delegate?.gameDidCompleteLevel(xpAwarded: 50)
                        return .levelComplete(xpAwarded: 50)
                    }
                    
                    return .correctPlacement(points: 10)
                } else {
                    return .incorrectPlacement
                }
            }
        }
        
        return .noAction
    }
    
    func reset() {
        placedPieces.removeAll()
        currentLevel = 1
        loadLevel(currentLevel)
    }
    
    func saveState() -> Data? {
        // TODO: Implement state serialization
        return nil
    }
    
    func loadState(from data: Data) {
        // TODO: Implement state deserialization
    }
    
    // MARK: - Private Methods
    
    private func convertToShapeType(_ shape: RecognizedPiece.Shape) -> ShapeType? {
        switch shape {
        case .triangle:
            return .triangle
        case .square:
            return .square
        case .rectangle:
            return .parallelogram
        default:
            return nil
        }
    }
    
    private func findMatchingRequirement(for piece: PlacedPiece) -> ShapeRequirement? {
        return targetShape.requiredPieces.first { requirement in
            requirement.shape == piece.shape &&
            distance(from: piece.position, to: requirement.targetPosition) < requirement.tolerance
        }
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> Double {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func loadLevel(_ level: Int) {
        // Load level configuration
        // This would typically load from a level definition file
        switch level {
        case 1:
            targetShape = TargetShape(
                name: "House",
                requiredPieces: [
                    ShapeRequirement(shape: .triangle, targetPosition: CGPoint(x: 200, y: 100), targetRotation: 0),
                    ShapeRequirement(shape: .square, targetPosition: CGPoint(x: 200, y: 200), targetRotation: 0)
                ]
            )
        default:
            break
        }
    }
}