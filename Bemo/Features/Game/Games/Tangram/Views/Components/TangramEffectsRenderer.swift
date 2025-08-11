//
//  TangramEffectsRenderer.swift
//  Bemo
//
//  Visual effects renderer for Tangram puzzle scene
//

// WHAT: Handles visual feedback and effects in the Tangram puzzle scene
// ARCHITECTURE: View component for SpriteKit scene, handles only visual rendering
// USAGE: Created by TangramPuzzleScene to handle celebration effects and visual feedback

import SpriteKit

/// Handles visual effects rendering for the Tangram puzzle scene
class TangramEffectsRenderer {
    
    // MARK: - Properties
    
    private weak var effectsLayer: SKNode?
    private weak var scene: SKScene?
    
    // MARK: - Initialization
    
    init(effectsLayer: SKNode, scene: SKScene) {
        self.effectsLayer = effectsLayer
        self.scene = scene
    }
    
    // MARK: - Visual Effects
    
    /// Shows a success nudge animation at the given position
    func showSuccessNudge(at position: CGPoint) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create a pulse effect
        let pulse = SKShapeNode(circleOfRadius: 30)
        pulse.position = position
        pulse.strokeColor = .systemGreen
        pulse.fillColor = .clear
        pulse.lineWidth = 3
        pulse.alpha = 0.8
        
        effectsLayer.addChild(pulse)
        
        // Animate the pulse
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.3)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        pulse.run(SKAction.sequence([group, remove]))
    }
    
    /// Shows orientation feedback when piece needs rotation or flipping
    func showOrientationNudge(for piece: SKNode, flipNeeded: Bool, rotationNeeded: Bool) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create feedback indicator with distinct visual style (automatic nudge)
        let indicator = SKLabelNode()
        indicator.position = CGPoint(x: piece.position.x, y: piece.position.y + 50)
        indicator.fontSize = 18  // Slightly smaller than hints
        indicator.fontColor = .systemBlue  // Blue for automatic nudges (vs yellow for hints)
        indicator.fontName = "System"  // Regular font (hints use bold)
        
        if flipNeeded && rotationNeeded {
            indicator.text = "↻ Flip & Rotate"
        } else if flipNeeded {
            indicator.text = "↔ Flip needed"
        } else if rotationNeeded {
            indicator.text = "↻ Rotate needed"
        }
        
        effectsLayer.addChild(indicator)
        
        // Animate feedback with shorter duration (automatic feedback)
        let moveUp = SKAction.moveBy(x: 0, y: 20, duration: 1.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        indicator.run(SKAction.sequence([group, remove]))
    }
    
    /// Shows correct placement feedback
    func showCorrectPlacementFeedback(for piece: SKNode) {
        // Create a brief glow effect
        guard let effectsLayer = effectsLayer else { return }
        
        let glow = SKShapeNode(circleOfRadius: 40)
        glow.position = piece.position
        glow.strokeColor = .systemGreen
        glow.fillColor = .systemGreen
        glow.alpha = 0.3
        glow.zPosition = piece.zPosition - 1
        
        effectsLayer.addChild(glow)
        
        // Animate glow
        let fadeIn = SKAction.fadeAlpha(to: 0.5, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        glow.run(SKAction.sequence([fadeIn, fadeOut, remove]))
    }
    
    /// Shows completion effect at position
    func showCompletionEffect(at position: CGPoint) {
        guard let effectsLayer = effectsLayer else { return }
        
        // Create particle effect
        for _ in 0..<10 {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.position = position
            particle.fillColor = [SKColor.systemYellow, SKColor.systemGreen, SKColor.systemBlue].randomElement()!
            particle.strokeColor = .clear
            
            effectsLayer.addChild(particle)
            
            // Random direction
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...100)
            let destination = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            // Animate particle
            let move = SKAction.move(to: destination, duration: 0.5)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let group = SKAction.group([move, fadeOut])
            let remove = SKAction.removeFromParent()
            
            particle.run(SKAction.sequence([group, remove]))
        }
    }
    
    /// Shows puzzle completion celebration
    func showPuzzleCompletionCelebration(availablePieces: [String: SKNode]) {
        guard let scene = scene else { return }
        
        // Create celebration text
        let congratsLabel = SKLabelNode(text: "🎉 Puzzle Complete! 🎉")
        congratsLabel.fontSize = 48
        congratsLabel.fontColor = .systemYellow
        congratsLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        congratsLabel.zPosition = 1000
        congratsLabel.alpha = 0
        
        scene.addChild(congratsLabel)
        
        // Animate celebration
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scale = SKAction.scale(to: 1.2, duration: 0.3)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        congratsLabel.run(SKAction.sequence([
            SKAction.group([fadeIn, scale]),
            wait,
            fadeOut,
            remove
        ]))
        
        // Animate pieces
        for piece in availablePieces.values {
            let jump = SKAction.moveBy(x: 0, y: 20, duration: 0.2)
            let fall = SKAction.moveBy(x: 0, y: -20, duration: 0.2)
            let sequence = SKAction.sequence([jump, fall])
            piece.run(SKAction.repeat(sequence, count: 2))
        }
    }
    
    /// Updates available pieces reference
    func updateAvailablePieces(_ pieces: [String: SKNode]) {
        // This method exists for compatibility but doesn't need to store the pieces
        // as they're passed directly to methods that need them
    }
}