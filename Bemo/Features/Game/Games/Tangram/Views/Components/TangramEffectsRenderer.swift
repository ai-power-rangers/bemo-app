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
    
    /// Shows puzzle completion celebration with confetti and animations
    func showPuzzleCompletionCelebration(availablePieces: [String: SKNode]) {
        guard let scene = scene, let effectsLayer = effectsLayer else { return }
        
        // Haptic feedback for completion
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        // Create confetti effect
        createConfettiEffect(in: effectsLayer)
        
        // Create celebration text with better animation
        let congratsLabel = SKLabelNode(text: "✨ Perfect! ✨")
        congratsLabel.fontSize = 56
        congratsLabel.fontColor = .systemYellow
        congratsLabel.fontName = "System-Bold"
        congratsLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.7)
        congratsLabel.zPosition = 1000
        congratsLabel.alpha = 0
        congratsLabel.setScale(0.5)
        
        effectsLayer.addChild(congratsLabel)
        
        // Animate celebration text
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.2),
            SKAction.scale(to: 1.2, duration: 0.2)
        ])
        let repeatPulse = SKAction.repeat(pulse, count: 3)
        let wait = SKAction.wait(forDuration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        
        congratsLabel.run(SKAction.sequence([
            SKAction.group([fadeIn, scaleUp]),
            repeatPulse,
            wait,
            fadeOut,
            remove
        ]))
        
        // Animate puzzle pieces with staggered celebration
        var delay: TimeInterval = 0
        for piece in availablePieces.values {
            // Stagger the animations
            let waitAction = SKAction.wait(forDuration: delay)
            
            // Create celebration animation for each piece
            let scaleUp = SKAction.scale(to: 1.1, duration: 0.15)
            let rotate = SKAction.rotate(byAngle: .pi / 12, duration: 0.15)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
            let rotateBack = SKAction.rotate(byAngle: -.pi / 12, duration: 0.15)
            
            let celebration = SKAction.sequence([
                waitAction,
                SKAction.group([scaleUp, rotate]),
                SKAction.group([scaleDown, rotateBack])
            ])
            
            piece.run(SKAction.repeat(celebration, count: 2))
            delay += 0.05  // Stagger by 50ms
        }
        
        // Create sparkle effects around the puzzle
        createSparkleEffect(in: effectsLayer)
    }
    
    /// Creates confetti falling effect
    private func createConfettiEffect(in layer: SKNode) {
        guard let scene = scene else { return }
        
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple, .systemOrange, .systemPink]
        
        // Create 50 confetti pieces
        for _ in 0..<50 {
            let confetti = SKShapeNode(rectOf: CGSize(width: 8, height: 12))
            confetti.fillColor = colors.randomElement()!
            confetti.strokeColor = .clear
            
            // Start from top of screen with random X position
            confetti.position = CGPoint(
                x: CGFloat.random(in: 0...scene.size.width),
                y: scene.size.height + 20
            )
            confetti.zPosition = 900
            confetti.zRotation = CGFloat.random(in: 0...(2 * .pi))
            
            layer.addChild(confetti)
            
            // Animate falling with rotation
            let fallDuration = TimeInterval.random(in: 2.0...4.0)
            let fall = SKAction.moveBy(x: CGFloat.random(in: -50...50), 
                                      y: -(scene.size.height + 40), 
                                      duration: fallDuration)
            let rotate = SKAction.rotate(byAngle: CGFloat.random(in: 2...6) * .pi, duration: fallDuration)
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()
            
            confetti.run(SKAction.sequence([
                SKAction.group([fall, rotate]),
                fadeOut,
                remove
            ]))
        }
    }
    
    /// Creates sparkle effects around the completed puzzle
    private func createSparkleEffect(in layer: SKNode) {
        guard let scene = scene else { return }
        
        // Create sparkles at random positions
        for _ in 0..<20 {
            let sparkle = SKShapeNode(circleOfRadius: 3)
            sparkle.fillColor = .white
            sparkle.strokeColor = .clear
            sparkle.glowWidth = 5
            sparkle.alpha = 0
            
            // Random position around center area
            sparkle.position = CGPoint(
                x: scene.size.width / 2 + CGFloat.random(in: -150...150),
                y: scene.size.height / 2 + CGFloat.random(in: -100...100)
            )
            sparkle.zPosition = 950
            
            layer.addChild(sparkle)
            
            // Animate sparkle
            let wait = SKAction.wait(forDuration: TimeInterval.random(in: 0...1.0))
            let fadeIn = SKAction.fadeIn(withDuration: 0.2)
            let scale = SKAction.scale(to: 1.5, duration: 0.2)
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()
            
            sparkle.run(SKAction.sequence([
                wait,
                SKAction.group([fadeIn, scale]),
                fadeOut,
                remove
            ]))
        }
    }
    
    /// Updates available pieces reference
    func updateAvailablePieces(_ pieces: [String: SKNode]) {
        // This method exists for compatibility but doesn't need to store the pieces
        // as they're passed directly to methods that need them
    }
}