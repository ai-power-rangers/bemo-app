//
//  TangramPuzzleScene.swift
//  Bemo
//
//  SpriteKit scene for Tangram puzzle gameplay with accurate geometry rendering
//

// WHAT: SpriteKit scene that renders tangram pieces using proper vertex-based geometry
// ARCHITECTURE: SKScene integrated into SwiftUI, uses transform-based positioning
// USAGE: Handles puzzle rendering with accurate piece shapes and transforms

import SpriteKit
import SwiftUI

class TangramPuzzleScene: SKScene {
    
    // MARK: - Properties
    
    var puzzle: GamePuzzleData?
    var onPieceCompleted: ((String) -> Void)?
    var onPuzzleCompleted: (() -> Void)?
    
    // Node layers
    private var backgroundLayer = SKNode()
    private var puzzleLayer = SKNode()
    private var piecesLayer = SKNode()
    private var effectsLayer = SKNode()
    
    // Piece tracking
    private var targetPieces: [String: SKShapeNode] = [:]
    private var availablePieces: [String: PuzzlePieceNode] = [:]
    private var completedPieces: Set<String> = []
    private var selectedPiece: PuzzlePieceNode?
    
    // Layout properties
    private var puzzleAreaHeight: CGFloat = 0
    private var piecesAreaHeight: CGFloat = 0
    private var puzzleCenter: CGPoint = .zero
    
    // Visual settings
    private let targetAlpha: CGFloat = 0.3
    private let snapDistance: CGFloat = 40.0
    private let rotationSnapTolerance: CGFloat = 15.0 // degrees
    
    // Touch tracking for rotation
    private var initialTouchAngle: CGFloat = 0
    private var initialPieceRotation: CGFloat = 0
    private var isRotating: Bool = false
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupScene()
        if let puzzle = puzzle {
            loadPuzzle(puzzle)
        }
    }
    
    private func setupScene() {
        backgroundColor = SKColor(named: "GameBackground") ?? SKColor.systemBackground
        
        // Add layers in order
        addChild(backgroundLayer)
        addChild(puzzleLayer)
        addChild(piecesLayer)
        addChild(effectsLayer)
        
        // Setup layout areas
        puzzleAreaHeight = size.height * 0.5
        piecesAreaHeight = size.height * 0.5
        puzzleCenter = CGPoint(x: size.width / 2, y: size.height * 0.65)
        
        // No physics for this implementation - we want direct control
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    }
    
    // MARK: - Puzzle Loading
    
    func loadPuzzle(_ puzzle: GamePuzzleData) {
        self.puzzle = puzzle
        
        // Clear existing pieces
        targetPieces.removeAll()
        availablePieces.removeAll()
        completedPieces.removeAll()
        puzzleLayer.removeAllChildren()
        piecesLayer.removeAllChildren()
        
        // Create target silhouettes in the top area
        for target in puzzle.targetPieces {
            createTargetPiece(target)
        }
        
        // Create movable pieces at the bottom
        createAvailablePieces(from: puzzle.targetPieces)
    }
    
    private func createTargetPiece(_ target: GamePuzzleData.TargetPiece) {
        // Get transformed vertices for the target piece
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        let transformedVertices = TangramGameGeometry.transformVertices(scaledVertices, with: target.transform)
        
        // Create shape from transformed vertices
        let path = UIBezierPath()
        if let firstVertex = transformedVertices.first {
            path.move(to: firstVertex)
            for vertex in transformedVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.close()
        }
        
        let shape = SKShapeNode(path: path.cgPath)
        shape.fillColor = SKColor.black
        shape.alpha = targetAlpha
        shape.strokeColor = SKColor.darkGray
        shape.lineWidth = 1.0
        
        // Offset to center the puzzle in the view
        shape.position = CGPoint(x: puzzleCenter.x, y: puzzleCenter.y)
        shape.name = "target_\(target.pieceType.rawValue)"
        
        targetPieces[target.pieceType.rawValue] = shape
        puzzleLayer.addChild(shape)
    }
    
    private func createAvailablePieces(from targets: [GamePuzzleData.TargetPiece]) {
        let pieceTypes = targets.map { $0.pieceType }
        let piecesPerRow = 4
        let spacing: CGFloat = 120
        let startY = size.height * 0.2 // Bottom area
        
        for (index, pieceType) in pieceTypes.enumerated() {
            let row = index / piecesPerRow
            let col = index % piecesPerRow
            
            let piece = PuzzlePieceNode(pieceType: pieceType)
            
            // Random position in bottom area with some organization
            let baseX = CGFloat(col - 1) * spacing + size.width / 2
            let baseY = startY - CGFloat(row) * 100
            
            piece.position = CGPoint(
                x: baseX + CGFloat.random(in: -20...20),
                y: baseY + CGFloat.random(in: -20...20)
            )
            
            // Random initial rotation
            piece.zRotation = CGFloat.random(in: 0...(2 * .pi))
            piece.name = "piece_\(pieceType.rawValue)"
            piece.zPosition = CGFloat(index)
            
            availablePieces[pieceType.rawValue] = piece
            piecesLayer.addChild(piece)
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Check if we tapped a movable piece
        for node in nodes {
            if let piece = node as? PuzzlePieceNode,
               let pieceType = piece.pieceType,
               !completedPieces.contains(pieceType.rawValue) {
                selectedPiece = piece
                piece.isSelected = true
                
                // Bring to front
                piece.zPosition = 1000
                
                // Check if this is a double tap for rotation
                if touch.tapCount == 2 {
                    // Rotate by 45 degrees on double tap
                    let rotation = SKAction.rotate(byAngle: .pi / 4, duration: 0.2)
                    piece.run(rotation)
                } else {
                    // Setup for drag or rotation gesture
                    initialTouchAngle = atan2(location.y - piece.position.y,
                                            location.x - piece.position.x)
                    initialPieceRotation = piece.zRotation
                    isRotating = false
                }
                
                // Visual feedback
                let scaleUp = SKAction.scale(to: 1.1, duration: 0.1)
                piece.run(scaleUp)
                
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let selected = selectedPiece else { return }
        
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        
        // Determine if this is a rotation or drag based on touch count
        if touches.count == 2 {
            // Two finger rotation
            isRotating = true
            let currentAngle = atan2(location.y - selected.position.y,
                                    location.x - selected.position.x)
            let angleDelta = currentAngle - initialTouchAngle
            selected.zRotation = initialPieceRotation + angleDelta
        } else if !isRotating {
            // Single finger drag
            let deltaX = location.x - previousLocation.x
            let deltaY = location.y - previousLocation.y
            selected.position.x += deltaX
            selected.position.y += deltaY
            
            // Check for snap preview
            checkSnapPreview(for: selected)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let selected = selectedPiece else { return }
        
        selected.isSelected = false
        
        // Return to normal scale
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        selected.run(scaleDown)
        
        // Check if close enough to snap
        if let pieceType = selected.pieceType,
           let target = targetPieces[pieceType.rawValue] {
            
            let distance = hypot(selected.position.x - target.position.x,
                               selected.position.y - target.position.y)
            
            // Check rotation difference
            var rotationDiff = abs(selected.zRotation - target.zRotation)
            // Normalize to 0-2π range
            while rotationDiff > 2 * .pi { rotationDiff -= 2 * .pi }
            // Check if it's close enough (considering all 4 rotations for squares, etc.)
            let rotationIsClose = rotationDiff < rotationSnapTolerance * .pi / 180 ||
                                abs(rotationDiff - .pi/2) < rotationSnapTolerance * .pi / 180 ||
                                abs(rotationDiff - .pi) < rotationSnapTolerance * .pi / 180 ||
                                abs(rotationDiff - 3 * .pi/2) < rotationSnapTolerance * .pi / 180
            
            if distance < snapDistance && rotationIsClose {
                // Snap to position
                snapToTarget(piece: selected, target: target)
            } else {
                // Return original z-position
                selected.zPosition = CGFloat(availablePieces.count)
            }
        }
        
        selectedPiece = nil
        isRotating = false
    }
    
    // MARK: - Snap and Completion
    
    private func checkSnapPreview(for piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType,
              let target = targetPieces[pieceType.rawValue] else { return }
        
        let distance = hypot(piece.position.x - target.position.x,
                           piece.position.y - target.position.y)
        
        if distance < snapDistance * 1.5 {
            // Show snap preview
            target.alpha = 0.5
            target.strokeColor = SKColor.systemGreen
            target.lineWidth = 2.0
        } else {
            // Reset preview
            target.alpha = targetAlpha
            target.strokeColor = SKColor.darkGray
            target.lineWidth = 1.0
        }
    }
    
    private func snapToTarget(piece: PuzzlePieceNode, target: SKShapeNode) {
        guard let pieceType = piece.pieceType else { return }
        
        // Snap animation
        let snapMove = SKAction.move(to: target.position, duration: 0.2)
        let snapRotate = SKAction.rotate(toAngle: target.zRotation, duration: 0.2, shortestUnitArc: true)
        let snapGroup = SKAction.group([snapMove, snapRotate])
        
        piece.run(snapGroup) {
            // Mark as completed
            self.completedPieces.insert(pieceType.rawValue)
            piece.isCompleted = true
            piece.zPosition = 10 // Above unplaced pieces but below selected
            
            // Hide the target
            target.alpha = 0
            
            // Celebration effect
            self.showCompletionEffect(at: piece.position)
            
            // Notify delegate
            self.onPieceCompleted?(pieceType.rawValue)
            
            // Check if puzzle is complete
            self.checkPuzzleCompletion()
        }
    }
    
    private func checkPuzzleCompletion() {
        guard let puzzle = puzzle else { return }
        
        if completedPieces.count == puzzle.targetPieces.count {
            showPuzzleCompletionCelebration()
            onPuzzleCompleted?()
        }
    }
    
    // MARK: - Visual Effects
    
    private func showCompletionEffect(at position: CGPoint) {
        // Create a star burst effect
        for i in 0..<6 {
            let star = SKShapeNode(circleOfRadius: 3)
            star.fillColor = .systemYellow
            star.position = position
            star.zPosition = 200
            effectsLayer.addChild(star)
            
            let angle = CGFloat(i) * .pi / 3
            let distance: CGFloat = 40
            let endpoint = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            let move = SKAction.move(to: endpoint, duration: 0.4)
            let fadeOut = SKAction.fadeOut(withDuration: 0.4)
            let scale = SKAction.scale(to: 0.1, duration: 0.4)
            let remove = SKAction.removeFromParent()
            
            star.run(SKAction.sequence([
                SKAction.group([move, fadeOut, scale]),
                remove
            ]))
        }
    }
    
    private func showPuzzleCompletionCelebration() {
        // Create confetti effect
        for _ in 0..<20 {
            let confetti = SKShapeNode(rectOf: CGSize(width: 10, height: 10))
            confetti.fillColor = [SKColor.systemRed, SKColor.systemBlue, SKColor.systemGreen,
                                 SKColor.systemYellow, SKColor.systemPurple].randomElement()!
            confetti.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                       y: size.height + 20)
            confetti.zPosition = 300
            effectsLayer.addChild(confetti)
            
            let fall = SKAction.moveTo(y: -20, duration: Double.random(in: 2...4))
            let rotate = SKAction.rotate(byAngle: .pi * 4, duration: Double.random(in: 2...4))
            let remove = SKAction.removeFromParent()
            
            confetti.run(SKAction.sequence([
                SKAction.group([fall, rotate]),
                remove
            ]))
        }
        
        // Pulse all completed pieces
        for piece in availablePieces.values where piece.isCompleted {
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
            let pulse = SKAction.sequence([scaleUp, scaleDown])
            piece.run(SKAction.repeat(pulse, count: 3))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createPieceShape(type: TangramPieceType) -> SKShapeNode {
        // Get normalized vertices from geometry
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: type)
        
        // Scale vertices to visual size
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        
        // Create path from scaled vertices
        let path = UIBezierPath()
        if let firstVertex = scaledVertices.first {
            path.move(to: firstVertex)
            for vertex in scaledVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.close()
        }
        
        let shape = SKShapeNode(path: path.cgPath)
        shape.fillColor = TangramGameConstants.Colors.uiColor(for: type)
        shape.strokeColor = shape.fillColor.darker(by: 20)
        shape.lineWidth = 2
        
        return shape
    }
}

// MARK: - Puzzle Piece Node

class PuzzlePieceNode: SKNode {
    var pieceType: TangramPieceType?
    var isSelected: Bool = false
    var isCompleted: Bool = false
    private var shapeNode: SKShapeNode?
    
    init(pieceType: TangramPieceType) {
        super.init()
        
        self.pieceType = pieceType
        self.name = "piece_\(pieceType.rawValue)"
        
        // Create shape node with proper geometry
        let shapeNode = createShape(for: pieceType)
        self.shapeNode = shapeNode
        addChild(shapeNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createShape(for pieceType: TangramPieceType) -> SKShapeNode {
        // Get normalized vertices from geometry
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        
        // Scale vertices to visual size
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        
        // Create path from scaled vertices
        let path = UIBezierPath()
        if let firstVertex = scaledVertices.first {
            path.move(to: firstVertex)
            for vertex in scaledVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.close()
        }
        
        let shape = SKShapeNode(path: path.cgPath)
        shape.fillColor = TangramGameConstants.Colors.uiColor(for: pieceType)
        shape.strokeColor = shape.fillColor.darker(by: 20)
        shape.lineWidth = 2
        
        return shape
    }
}

// UIColor extension for darker colors
extension UIColor {
    func darker(by percentage: CGFloat = 30.0) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: max(r - percentage/100, 0.0),
                         green: max(g - percentage/100, 0.0),
                         blue: max(b - percentage/100, 0.0),
                         alpha: a)
        }
        return self
    }
}