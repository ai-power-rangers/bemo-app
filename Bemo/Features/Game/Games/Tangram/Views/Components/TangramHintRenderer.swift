//
//  TangramHintRenderer.swift
//  Bemo
//
//  Visual hint renderer for Tangram puzzle scene
//

// WHAT: Renders visual hints in the Tangram puzzle scene
// ARCHITECTURE: View component for SpriteKit scene, handles only visual rendering of hints
// USAGE: Created by TangramPuzzleScene to display hint visualizations

import SpriteKit

/// Handles hint visualization for the Tangram puzzle scene
class TangramHintRenderer {
    
    // MARK: - Properties
    
    private weak var effectsLayer: SKNode?
    private weak var puzzleLayer: SKNode?
    private weak var scene: SKScene?
    private var currentHintNodes: [SKNode] = []
    
    // MARK: - Initialization
    
    init(effectsLayer: SKNode, puzzleLayer: SKNode, scene: SKScene) {
        self.effectsLayer = effectsLayer
        self.puzzleLayer = puzzleLayer
        self.scene = scene
    }
    
    // MARK: - Hint Rendering
    
    /// Shows a visual hint for piece placement
    func showHint(for pieceType: TangramPieceType, at targetPosition: CGPoint, rotation: CGFloat) {
        clearCurrentHint()
        
        guard let effectsLayer = effectsLayer else { return }
        
        // Create hint outline
        let hintNode = createHintNode(for: pieceType)
        hintNode.position = targetPosition
        // Rotation should already be in scene-space from hint engine
        hintNode.zRotation = rotation
        hintNode.alpha = 0
        
        effectsLayer.addChild(hintNode)
        currentHintNodes.append(hintNode)
        
        // Animate hint appearance
        let fadeIn = SKAction.fadeAlpha(to: 0.6, duration: 0.3)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.5),
            SKAction.fadeAlpha(to: 0.4, duration: 0.5)
        ])
        let repeatPulse = SKAction.repeatForever(pulse)
        
        hintNode.run(SKAction.sequence([fadeIn, repeatPulse]))
    }
    
    /// Shows a movement hint arrow
    func showMovementHint(from: CGPoint, to: CGPoint) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create arrow path
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        
        let arrow = SKShapeNode(path: path)
        arrow.strokeColor = .systemYellow
        arrow.lineWidth = 4  // Increased for visibility
        arrow.alpha = 0
        arrow.zPosition = 500  // High z-position for visibility
        arrow.glowWidth = 4  // Add glow for user-requested hints
        
        // Add arrowhead
        let arrowhead = createArrowhead(from: from, to: to)
        arrowhead.position = to
        arrow.addChild(arrowhead)
        
        effectsLayer.addChild(arrow)
        currentHintNodes.append(arrow)
        
        // Animate arrow with pulsing effect
        let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 0.3)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.5),
            SKAction.fadeAlpha(to: 0.6, duration: 0.5)
        ])
        let repeatPulse = SKAction.repeatForever(pulse)
        
        arrow.run(SKAction.sequence([fadeIn, repeatPulse]))
    }
    
    /// Shows rotation hint
    func showRotationHint(at position: CGPoint, targetRotation: CGFloat) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create rotation indicator with enhanced visibility
        let radius: CGFloat = 45  // Slightly larger
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.position = position
        circle.strokeColor = .systemYellow
        circle.fillColor = .clear
        circle.lineWidth = 3  // Thicker line
        circle.glowWidth = 4  // Add glow
        circle.alpha = 0
        circle.zPosition = 500
        
        // Add rotation arrow - rotation should already be in scene-space from hint engine
        let arrowPath = CGMutablePath()
        arrowPath.addArc(center: .zero, radius: radius, 
                        startAngle: 0, endAngle: targetRotation,
                        clockwise: false)
        
        let rotationArrow = SKShapeNode(path: arrowPath)
        rotationArrow.strokeColor = .systemYellow
        rotationArrow.lineWidth = 4
        rotationArrow.glowWidth = 2
        circle.addChild(rotationArrow)
        
        effectsLayer.addChild(circle)
        currentHintNodes.append(circle)
        
        // Animate with pulsing
        let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 0.3)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.5),
            SKAction.fadeAlpha(to: 0.6, duration: 0.5)
        ])
        let repeatPulse = SKAction.repeatForever(pulse)
        let rotate = SKAction.rotate(byAngle: targetRotation, duration: 1.5)
        
        circle.run(SKAction.sequence([fadeIn, SKAction.group([rotate, repeatPulse])]))
    }
    
    /// Shows flip hint
    func showFlipHint(at position: CGPoint) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create flip indicator with enhanced visibility
        let label = SKLabelNode(text: "↔ Flip")
        label.position = CGPoint(x: position.x, y: position.y + 60)
        label.fontSize = 28  // Larger for visibility
        label.fontColor = .systemYellow
        label.fontName = "System-Bold"  // Bold for user hints
        label.alpha = 0
        label.zPosition = 500
        
        // Add background for better visibility
        let background = SKShapeNode(rectOf: CGSize(width: 80, height: 35), cornerRadius: 8)
        background.fillColor = .black.withAlphaComponent(0.5)
        background.strokeColor = .systemYellow
        background.lineWidth = 2
        background.position = .zero
        background.zPosition = -1
        label.addChild(background)
        
        effectsLayer.addChild(label)
        currentHintNodes.append(label)
        
        // Animate with enhanced effect
        let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: 0.3)
        let scaleX = SKAction.sequence([
            SKAction.scaleX(to: -1, duration: 0.5),
            SKAction.scaleX(to: 1, duration: 0.5)
        ])
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.fadeAlpha(to: 0.7, duration: 0.3)
        ])
        let repeatEffects = SKAction.repeatForever(SKAction.group([scaleX, pulse]))
        
        label.run(SKAction.sequence([fadeIn, repeatEffects]))
    }
    
    /// Clears all current hint nodes
    func clearCurrentHint() {
        for node in currentHintNodes {
            node.removeAllActions()
            node.removeFromParent()
        }
        currentHintNodes.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func createHintNode(for pieceType: TangramPieceType) -> SKShapeNode {
        // Get normalized vertices
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        
        // CRITICAL: Scale vertices to visual size (same as actual pieces)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        
        // Calculate centroid for centering
        let centroid = TangramGameGeometry.centerOfVertices(scaledVertices)
        
        // Create path with vertices centered around origin
        let path = CGMutablePath()
        if let first = scaledVertices.first {
            // Center around origin so the hint's position represents its centroid
            path.move(to: CGPoint(x: first.x - centroid.x, y: first.y - centroid.y))
            for vertex in scaledVertices.dropFirst() {
                path.addLine(to: CGPoint(x: vertex.x - centroid.x, y: vertex.y - centroid.y))
            }
            path.closeSubpath()
        }
        
        // Create shape node with enhanced visibility
        let shape = SKShapeNode(path: path)
        shape.strokeColor = .systemYellow
        shape.fillColor = .systemYellow.withAlphaComponent(0.2)
        shape.lineWidth = 3  // Increased for better visibility
        shape.glowWidth = 8  // Increased glow for user-requested hints
        shape.zPosition = 500  // Ensure it's visible above pieces
        
        return shape
    }
    
    private func createArrowhead(from: CGPoint, to: CGPoint) -> SKShapeNode {
        let angle = atan2(to.y - from.y, to.x - from.x)
        
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(
            x: -arrowLength * cos(angle - arrowAngle),
            y: -arrowLength * sin(angle - arrowAngle)
        ))
        path.move(to: .zero)
        path.addLine(to: CGPoint(
            x: -arrowLength * cos(angle + arrowAngle),
            y: -arrowLength * sin(angle + arrowAngle)
        ))
        
        let arrowhead = SKShapeNode(path: path)
        arrowhead.strokeColor = .systemYellow
        arrowhead.lineWidth = 3
        
        return arrowhead
    }
}