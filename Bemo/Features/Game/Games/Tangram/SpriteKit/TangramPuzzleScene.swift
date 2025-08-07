//
//  TangramPuzzleScene.swift
//  Bemo
//
//  SpriteKit scene for Tangram puzzle gameplay with physics and animations
//

// WHAT: SpriteKit scene managing puzzle pieces, physics, and animations
// ARCHITECTURE: SKScene integrated into SwiftUI via SpriteView
// USAGE: Handles all game canvas rendering and interactions

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
    private var placedPieces: [String: PuzzlePieceNode] = [:]
    private var selectedPiece: PuzzlePieceNode?
    
    // Visual settings
    private let targetAlpha: CGFloat = 0.3
    private let snapDistance: CGFloat = 30.0
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupScene()
        setupPhysics()
        if let puzzle = puzzle {
            loadPuzzle(puzzle)
        }
    }
    
    private func setupScene() {
        backgroundColor = SKColor.systemBackground
        
        // Add layers in order
        addChild(backgroundLayer)
        addChild(puzzleLayer)
        addChild(piecesLayer)
        addChild(effectsLayer)
        
        // Center the scene
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }
    
    private func setupPhysics() {
        // Light gravity for nice piece movements
        physicsWorld.gravity = CGVector(dx: 0, dy: -0.5)
        physicsWorld.speed = 0.8
        
        // Add boundaries
        let border = SKPhysicsBody(edgeLoopFrom: frame)
        border.friction = 0.3
        border.restitution = 0.1
        physicsBody = border
    }
    
    // MARK: - Puzzle Loading
    
    func loadPuzzle(_ puzzle: GamePuzzleData) {
        self.puzzle = puzzle
        
        // Clear existing pieces
        targetPieces.removeAll()
        placedPieces.removeAll()
        puzzleLayer.removeAllChildren()
        piecesLayer.removeAllChildren()
        
        // Create target silhouettes
        for target in puzzle.targetPieces {
            createTargetPiece(target)
        }
    }
    
    private func createTargetPiece(_ target: GamePuzzleData.TargetPiece) {
        let shape = createPieceShape(type: target.pieceType)
        shape.fillColor = SKColor.black
        shape.alpha = targetAlpha
        shape.strokeColor = SKColor.darkGray
        shape.lineWidth = 1.0
        shape.position = CGPoint(x: target.position.x - 300, y: target.position.y - 300)
        shape.zRotation = CGFloat(target.rotation * .pi / 180)
        shape.name = "target_\(target.pieceType)"
        
        targetPieces[target.pieceType] = shape
        puzzleLayer.addChild(shape)
    }
    
    // MARK: - Piece Creation
    
    func addPiece(type: String, at position: CGPoint? = nil) {
        // Don't add if already placed
        guard placedPieces[type] == nil else { return }
        
        let piece = PuzzlePieceNode(pieceType: type)
        piece.position = position ?? randomOffScreenPosition()
        piece.name = "piece_\(type)"
        
        // Add physics
        piece.physicsBody = SKPhysicsBody(rectangleOf: piece.size)
        piece.physicsBody?.isDynamic = true
        piece.physicsBody?.allowsRotation = true
        piece.physicsBody?.friction = 0.3
        piece.physicsBody?.restitution = 0.2
        piece.physicsBody?.angularDamping = 0.8
        piece.physicsBody?.linearDamping = 0.5
        
        placedPieces[type] = piece
        piecesLayer.addChild(piece)
        
        // Animate entrance
        piece.alpha = 0
        piece.setScale(0.1)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        piece.run(SKAction.group([fadeIn, scaleUp]))
    }
    
    private func randomOffScreenPosition() -> CGPoint {
        let side = Int.random(in: 0...3)
        switch side {
        case 0: return CGPoint(x: -frame.width/2 - 100, y: CGFloat.random(in: -200...200))
        case 1: return CGPoint(x: frame.width/2 + 100, y: CGFloat.random(in: -200...200))
        case 2: return CGPoint(x: CGFloat.random(in: -200...200), y: frame.height/2 + 100)
        default: return CGPoint(x: CGFloat.random(in: -200...200), y: -frame.height/2 - 100)
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Check if we tapped a piece
        for node in nodes {
            if let piece = node as? PuzzlePieceNode {
                selectedPiece = piece
                piece.isSelected = true
                
                // Bring to front
                piece.zPosition = 100
                
                // Remove physics temporarily
                piece.physicsBody?.isDynamic = false
                
                // Pulse animation
                let scaleUp = SKAction.scale(to: 1.1, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                piece.run(SKAction.sequence([scaleUp, scaleDown]))
                
                break
            } else if let targetName = node.name,
                      targetName.starts(with: "target_") {
                // Tapped a target - simulate perfect placement
                let pieceType = String(targetName.dropFirst(7))
                simulatePerfectPlacement(pieceType: pieceType)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let selected = selectedPiece else { return }
        
        let location = touch.location(in: self)
        selected.position = location
        
        // Check for snap points
        checkSnapPoints(for: selected)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let selected = selectedPiece else { return }
        
        selected.isSelected = false
        selected.zPosition = 1
        
        // Check if close to target
        if let targetPosition = checkIfNearTarget(selected) {
            // Snap to position
            snapToPosition(piece: selected, target: targetPosition)
        } else {
            // Re-enable physics
            selected.physicsBody?.isDynamic = true
            
            // Add a little spin for fun
            selected.physicsBody?.applyAngularImpulse(CGFloat.random(in: -0.01...0.01))
        }
        
        selectedPiece = nil
    }
    
    // MARK: - Placement Logic
    
    private func checkSnapPoints(for piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType,
              let target = targetPieces[pieceType] else { return }
        
        let distance = hypot(piece.position.x - target.position.x,
                           piece.position.y - target.position.y)
        
        if distance < snapDistance {
            // Show snap indicator
            target.alpha = 0.5
            target.run(SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ]))
        } else {
            target.alpha = targetAlpha
        }
    }
    
    private func checkIfNearTarget(_ piece: PuzzlePieceNode) -> CGPoint? {
        guard let pieceType = piece.pieceType,
              let target = targetPieces[pieceType] else { return nil }
        
        let distance = hypot(piece.position.x - target.position.x,
                           piece.position.y - target.position.y)
        
        if distance < snapDistance {
            return target.position
        }
        return nil
    }
    
    private func snapToPosition(piece: PuzzlePieceNode, target: CGPoint) {
        // Disable physics
        piece.physicsBody?.isDynamic = false
        
        // Snap animation
        let snapMove = SKAction.move(to: target, duration: 0.2)
        let snapRotate = SKAction.rotate(toAngle: targetPieces[piece.pieceType ?? ""]?.zRotation ?? 0, duration: 0.2)
        let snapGroup = SKAction.group([snapMove, snapRotate])
        
        piece.run(snapGroup) {
            self.handlePieceCompleted(piece)
        }
    }
    
    func simulatePerfectPlacement(pieceType: String) {
        // Remove if already placed
        if let existing = placedPieces[pieceType] {
            existing.removeFromParent()
            placedPieces.removeValue(forKey: pieceType)
        }
        
        // Get target position
        guard let target = targetPieces[pieceType] else { return }
        
        // Create new piece at target position
        let piece = PuzzlePieceNode(pieceType: pieceType)
        piece.position = CGPoint(x: 0, y: frame.height/2)
        piece.name = "piece_\(pieceType)"
        piece.physicsBody = SKPhysicsBody(rectangleOf: piece.size)
        piece.physicsBody?.isDynamic = false
        
        placedPieces[pieceType] = piece
        piecesLayer.addChild(piece)
        
        // Animate to position
        piece.alpha = 0
        piece.setScale(0.1)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        let moveTo = SKAction.move(to: target.position, duration: 0.5)
        let rotateTo = SKAction.rotate(toAngle: target.zRotation, duration: 0.5)
        
        let entrance = SKAction.group([fadeIn, scaleUp])
        let placement = SKAction.group([moveTo, rotateTo])
        
        piece.run(SKAction.sequence([entrance, placement])) {
            self.handlePieceCompleted(piece)
        }
    }
    
    // MARK: - Completion Handling
    
    private func handlePieceCompleted(_ piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType else { return }
        
        // Mark as completed
        piece.isCompleted = true
        
        // Celebration effect
        showCompletionEffect(at: piece.position)
        
        // Notify delegate
        onPieceCompleted?(pieceType)
        
        // Check if puzzle is complete
        checkPuzzleCompletion()
    }
    
    private func checkPuzzleCompletion() {
        guard let puzzle = puzzle else { return }
        
        let completedCount = placedPieces.values.filter { $0.isCompleted }.count
        if completedCount == puzzle.targetPieces.count {
            showPuzzleCompletionCelebration()
            onPuzzleCompleted?()
        }
    }
    
    // MARK: - Visual Effects
    
    private func showCompletionEffect(at position: CGPoint) {
        // Particle effect
        if let particles = SKEmitterNode(fileNamed: "PieceComplete") {
            particles.position = position
            particles.zPosition = 200
            effectsLayer.addChild(particles)
            
            let remove = SKAction.sequence([
                SKAction.wait(forDuration: 2.0),
                SKAction.removeFromParent()
            ])
            particles.run(remove)
        } else {
            // Fallback: Simple star burst
            createStarBurst(at: position)
        }
    }
    
    private func createStarBurst(at position: CGPoint) {
        for i in 0..<8 {
            let star = SKShapeNode(circleOfRadius: 3)
            star.fillColor = .yellow
            star.position = position
            star.zPosition = 200
            effectsLayer.addChild(star)
            
            let angle = CGFloat(i) * .pi / 4
            let distance: CGFloat = 50
            let endpoint = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            let move = SKAction.move(to: endpoint, duration: 0.5)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            
            star.run(SKAction.sequence([
                SKAction.group([move, fadeOut]),
                remove
            ]))
        }
    }
    
    private func showPuzzleCompletionCelebration() {
        // Create multiple particle effects
        for _ in 0..<5 {
            let x = CGFloat.random(in: -200...200)
            let y = CGFloat.random(in: -200...200)
            createStarBurst(at: CGPoint(x: x, y: y))
        }
        
        // Pulse all pieces
        for piece in placedPieces.values {
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
            let pulse = SKAction.sequence([scaleUp, scaleDown])
            piece.run(SKAction.repeat(pulse, count: 3))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createPieceShape(type: String) -> SKShapeNode {
        // Create shape based on piece type
        let path = UIBezierPath()
        
        switch type {
        case "smallTriangle1", "smallTriangle2":
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 50))
            path.close()
            
        case "mediumTriangle":
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 70, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 70))
            path.close()
            
        case "largeTriangle1", "largeTriangle2":
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 100, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 100))
            path.close()
            
        case "square":
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 0, y: 50))
            path.close()
            
        case "parallelogram":
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 70, y: 0))
            path.addLine(to: CGPoint(x: 35, y: 35))
            path.addLine(to: CGPoint(x: -35, y: 35))
            path.close()
            
        default:
            // Default square
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 0, y: 50))
            path.close()
        }
        
        return SKShapeNode(path: path.cgPath)
    }
}

// MARK: - Puzzle Piece Node

class PuzzlePieceNode: SKSpriteNode {
    var pieceType: String?
    var isSelected: Bool = false
    var isCompleted: Bool = false
    
    init(pieceType: String) {
        // Create texture from piece type - convert SwiftUI Color to UIColor
        let swiftUIColor = PieceType(rawValue: pieceType)?.color ?? .gray
        let uiColor = UIColor(swiftUIColor)
        let texture = SKTexture(image: Self.createPieceImage(type: pieceType, color: uiColor))
        
        super.init(texture: texture, color: .clear, size: CGSize(width: 100, height: 100))
        
        self.pieceType = pieceType
        self.name = "piece_\(pieceType)"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private static func createPieceImage(type: String, color: UIColor) -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { ctx in
            color.setFill()
            
            let path = UIBezierPath()
            switch type {
            case "smallTriangle1", "smallTriangle2":
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 50, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 50))
                
            case "square":
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 50, y: 0))
                path.addLine(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 0, y: 50))
                
            default:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 50, y: 0))
                path.addLine(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 0, y: 50))
            }
            
            path.close()
            path.fill()
        }
    }
}