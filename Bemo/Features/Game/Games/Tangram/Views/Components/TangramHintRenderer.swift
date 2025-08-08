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
        arrow.lineWidth = 3
        arrow.alpha = 0
        arrow.zPosition = 100
        
        // Add arrowhead
        let arrowhead = createArrowhead(from: from, to: to)
        arrowhead.position = to
        arrow.addChild(arrowhead)
        
        effectsLayer.addChild(arrow)
        currentHintNodes.append(arrow)
        
        // Animate arrow
        let fadeIn = SKAction.fadeAlpha(to: 0.7, duration: 0.3)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        
        arrow.run(SKAction.sequence([fadeIn, wait, fadeOut]))
    }
    
    /// Shows rotation hint
    func showRotationHint(at position: CGPoint, targetRotation: CGFloat) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create rotation indicator
        let radius: CGFloat = 40
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.position = position
        circle.strokeColor = .systemYellow
        circle.fillColor = .clear
        circle.lineWidth = 2
        circle.alpha = 0
        
        // Add rotation arrow
        let arrowPath = CGMutablePath()
        arrowPath.addArc(center: .zero, radius: radius, 
                        startAngle: 0, endAngle: targetRotation,
                        clockwise: false)
        
        let rotationArrow = SKShapeNode(path: arrowPath)
        rotationArrow.strokeColor = .systemYellow
        rotationArrow.lineWidth = 3
        circle.addChild(rotationArrow)
        
        effectsLayer.addChild(circle)
        currentHintNodes.append(circle)
        
        // Animate
        let fadeIn = SKAction.fadeAlpha(to: 0.7, duration: 0.3)
        let rotate = SKAction.rotate(byAngle: targetRotation, duration: 1.0)
        let group = SKAction.group([fadeIn, rotate])
        
        circle.run(group)
    }
    
    /// Shows flip hint
    func showFlipHint(at position: CGPoint) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create flip indicator
        let label = SKLabelNode(text: "↔ Flip")
        label.position = CGPoint(x: position.x, y: position.y + 60)
        label.fontSize = 24
        label.fontColor = .systemYellow
        label.alpha = 0
        
        effectsLayer.addChild(label)
        currentHintNodes.append(label)
        
        // Animate
        let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 0.3)
        let scaleX = SKAction.sequence([
            SKAction.scaleX(to: -1, duration: 0.5),
            SKAction.scaleX(to: 1, duration: 0.5)
        ])
        let repeat_ = SKAction.repeatForever(scaleX)
        
        label.run(SKAction.sequence([fadeIn, repeat_]))
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
        // Get piece vertices
        let vertices = TangramGameGeometry.getVertices(for: pieceType)
        
        // Create path
        let path = CGMutablePath()
        if let first = vertices.first {
            path.move(to: first)
            for vertex in vertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        // Create shape node
        let shape = SKShapeNode(path: path)
        shape.strokeColor = .systemYellow
        shape.fillColor = .systemYellow.withAlphaComponent(0.2)
        shape.lineWidth = 2
        shape.glowWidth = 4
        
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