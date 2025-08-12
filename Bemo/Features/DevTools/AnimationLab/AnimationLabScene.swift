//
//  AnimationLabScene.swift
//  Bemo
//
//  SKScene testbed for transition and character animations
//

// WHAT: Scene hosts an assembled tangram container and provides methods to trigger animations
// ARCHITECTURE: Scene-only logic; reusable animation builders live in separate files
// USAGE: Embedded by AnimationLabView; not used by gameplay

import SpriteKit
import SwiftUI

final class AnimationLabScene: SKScene {
    private let assembledLayer = SKNode()
    private let overlayLayer = SKNode()   // particles, takeover, etc
    private var assembledNode: SKNode?
    private var currentPuzzle: GamePuzzleData?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(named: "GameBackground") ?? .black
        addChild(assembledLayer)
        addChild(overlayLayer)
        assembledLayer.zPosition = 10
        overlayLayer.zPosition = 100
    }

    // MARK: - Presets
    enum Preset: String, CaseIterable { 
        case classicTangram = "Classic"
        case trianglesOnly = "Triangles"
        case squaresParallelogram = "Squares"
        
        var displayName: String { rawValue }
    }
    
    // MARK: - Exit Directions
    enum ExitDirection: String, CaseIterable {
        case up = "Up"
        case down = "Down"
        case left = "Left"
        case right = "Right"
        case upLeft = "Up-Left"
        case upRight = "Up-Right"
        case downLeft = "Down-Left"
        case downRight = "Down-Right"
        
        var displayName: String { rawValue }
    }
    
    private var currentExitDirection: ExitDirection = .up
    
    // Public setter for exit direction
    func setExitDirection(_ direction: ExitDirection) {
        currentExitDirection = direction
    }
    
    // Helper to get exit vector
    private func getExitVector(for direction: ExitDirection) -> CGVector {
        let distance: CGFloat = max(size.width, size.height) + 200
        switch direction {
        case .up:
            return CGVector(dx: 0, dy: distance)
        case .down:
            return CGVector(dx: 0, dy: -distance)
        case .left:
            return CGVector(dx: -distance, dy: 0)
        case .right:
            return CGVector(dx: distance, dy: 0)
        case .upLeft:
            return CGVector(dx: -distance * 0.7, dy: distance * 0.7)
        case .upRight:
            return CGVector(dx: distance * 0.7, dy: distance * 0.7)
        case .downLeft:
            return CGVector(dx: -distance * 0.7, dy: -distance * 0.7)
        case .downRight:
            return CGVector(dx: distance * 0.7, dy: -distance * 0.7)
        }
    }

    func preparePreset(preset: Preset) {
        clearLoops()
        assembledNode?.removeFromParent()

        let center = CGPoint(x: size.width/2, y: size.height/2)
        let node: SKNode
        switch preset {
        case .classicTangram:
            node = TangramCharacterNode.makeFrom(pieceTypes: [.largeTriangle1, .largeTriangle2, .mediumTriangle, .smallTriangle1, .smallTriangle2, .square, .parallelogram])
        case .trianglesOnly:
            node = TangramCharacterNode.makeFrom(pieceTypes: [.largeTriangle1, .largeTriangle2, .mediumTriangle, .smallTriangle1, .smallTriangle2])
        case .squaresParallelogram:
            node = TangramCharacterNode.makeFrom(pieceTypes: [.square, .parallelogram])
        }
        node.position = center
        assembledLayer.addChild(node)
        assembledNode = node
    }

    // MARK: - Transitions
    func runSquareTakeover() {
        overlayLayer.removeAllChildren()
        let animation = TransitionAnimations.squareTakeover(in: self, layer: overlayLayer, duration: 1.5)
        
        // Add additional animation effects after squares are in place
        overlayLayer.run(SKAction.sequence([
            animation,
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                // Create a wave effect across all squares
                self?.animateSquareWave()
            },
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                self?.clearTransient()
            }
        ]))
    }
    
    private func animateSquareWave() {
        // Animate all squares in a wave pattern
        for (index, child) in overlayLayer.children.enumerated() {
            guard let square = child as? SKShapeNode else { continue }
            
            let delay = Double(index) * 0.01  // Create wave delay
            let wave = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.scale(to: 1.3, duration: 0.3),
                    SKAction.rotate(byAngle: .pi/6, duration: 0.3)
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.3),
                    SKAction.rotate(byAngle: -.pi/6, duration: 0.3)
                ])
            ])
            
            square.run(wave)
        }
    }
    
    func runSquareWave() {
        overlayLayer.removeAllChildren()
        // Create squares in wave formation
        TransitionAnimations.squareWavePattern(in: self, layer: overlayLayer, duration: 2.0)
        
        overlayLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.run { [weak self] in
                self?.clearTransient()
            }
        ]))
    }
    
    func runSquareSpiral() {
        overlayLayer.removeAllChildren()
        // Create squares in spiral formation
        TransitionAnimations.squareSpiralPattern(in: self, layer: overlayLayer, duration: 2.5)
        
        overlayLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.run { [weak self] in
                self?.clearTransient()
            }
        ]))
    }

    func runAssemble() {
        guard let assembledNode else { return }
        TransitionAnimations.assemble(node: assembledNode, within: frame, duration: 0.8)
        // Clear any overlay effects after animation
        overlayLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                self?.overlayLayer.removeAllChildren()
            }
        ]))
    }

    func runExplosionWithDust() {
        guard let assembledNode else { return }
        let center = assembledNode.convert(CGPoint.zero, to: self)
        assembledNode.run(SKAction.sequence([
            TransitionAnimations.explosion(node: assembledNode, intensity: 1.0, radius: 220, duration: 0.6),
            SKAction.wait(forDuration: 0.2),
            SKAction.run { [weak self] in
                // Rebuild the assembled node after explosion
                self?.rebuildAssembledNode()
            }
        ]))
        TransitionAnimations.emitDust(at: center, in: overlayLayer, preset: "DustCloud")
        // Clear dust after animation
        overlayLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.overlayLayer.removeAllChildren()
            }
        ]))
    }

    func clearTransient() {
        overlayLayer.removeAllChildren()
    }

    // MARK: - Character Animations
    func startBreathingLoop() { 
        clearLoops()
        assembledNode?.run(CharacterAnimations.breathing().repeatForever(), withKey: "breathing")
        // Auto-stop after 3 seconds
        assembledNode?.run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                self?.stopBreathingLoop()
            }
        ]), withKey: "breathingTimer")
    }
    func stopBreathingLoop() { 
        assembledNode?.removeAction(forKey: "breathing")
        assembledNode?.removeAction(forKey: "breathingTimer")
    }

    func startWobbleLoop() { 
        clearLoops()
        // Wobble and then animate off screen for exit
        let wobble = CharacterAnimations.wobble()
        let wobbleRepeat = SKAction.repeat(wobble, count: 2)  // Reduced from 3 to 2
        
        // Use configurable exit direction
        let exitVector = getExitVector(for: currentExitDirection)
        let moveOff = SKAction.moveBy(x: exitVector.dx, y: exitVector.dy, duration: 0.6)
        moveOff.timingMode = .easeIn
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let scaleDown = SKAction.scale(to: 0.7, duration: 0.6)  // Shrink slightly as it flies away
        
        // Add rotation for diagonal exits
        let rotation: SKAction
        if currentExitDirection.rawValue.contains("-") {  // Diagonal exits
            rotation = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: 0.6)
        } else {
            rotation = SKAction.rotate(byAngle: 0, duration: 0)  // No rotation for cardinal directions
        }
        
        let exitSequence = SKAction.sequence([
            wobbleRepeat,
            SKAction.group([moveOff, fadeOut, scaleDown, rotation]),
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.rebuildAssembledNode()
            }
        ])
        assembledNode?.run(exitSequence, withKey: "wobble")
    }
    func stopWobbleLoop() { 
        assembledNode?.removeAction(forKey: "wobble")
        assembledNode?.removeAction(forKey: "wobbleTimer")
    }

    func startShimmerLoop() { 
        clearLoops()
        CharacterAnimations.applyShimmer(to: assembledNode)
        // Auto-stop after 3 seconds
        assembledNode?.run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                self?.stopShimmerLoop()
            }
        ]), withKey: "shimmerTimer")
    }
    func stopShimmerLoop() { 
        assembledNode?.removeAction(forKey: "shimmerTimer")
        CharacterAnimations.removeShimmer(from: assembledNode) 
    }

    func runHappyJumpOnce() { 
        clearLoops()
        assembledNode?.run(CharacterAnimations.happyJump()) 
    }
    func runPulseOnce() { 
        clearLoops()
        assembledNode?.run(CharacterAnimations.pulse()) 
    }
    
    // MARK: - New Animation Types
    func runCelebration() {
        guard let assembledNode else { return }
        
        // Enhanced celebration: subtle per-piece validation, then happy jump with confetti
        
        // Step 1: Subtle color lightening for each piece (validation effect)
        var delay: TimeInterval = 0
        for (_, child) in assembledNode.children.enumerated() {
            guard let shape = child as? SKShapeNode else { continue }
            
            // Store original color
            let originalColor = shape.fillColor
            
            // Create subtle validation effect - just lighten the color slightly
            let lighten = SKAction.run {
                shape.fillColor = originalColor.lighter(by: 15)  // Much subtler lightening
            }
            let restore = SKAction.run {
                shape.fillColor = originalColor
            }
            
            let validationSequence = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                lighten,
                SKAction.wait(forDuration: 0.15),  // Shorter duration
                restore
            ])
            
            shape.run(validationSequence)
            delay += 0.1  // Faster stagger
        }
        
        // Step 2: After validation completes, do happy jump with enhanced confetti
        let totalValidationTime = delay + 0.15
        
        assembledNode.run(SKAction.sequence([
            SKAction.wait(forDuration: totalValidationTime),
            CharacterAnimations.happyJump()
        ]))
        
        // Step 3: Fast, intense confetti
        overlayLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: totalValidationTime),
            TransitionAnimations.confettiBurst(in: overlayLayer, duration: 2.0, intensity: 2.0),
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                self?.clearTransient()
            }
        ]))
    }
    
    func runEntrance() {
        guard let assembledNode else { return }
        // Pieces fly in from edges and assemble
        TransitionAnimations.assemble(node: assembledNode, within: frame, duration: 1.2)
    }
    
    func runExit() {
        guard let assembledNode else { return }
        // Original explosion exit
        let center = assembledNode.convert(CGPoint.zero, to: self)
        assembledNode.run(SKAction.sequence([
            TransitionAnimations.explosion(node: assembledNode, intensity: 0.8, radius: 300, duration: 1.0),
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.rebuildAssembledNode()
            }
        ]))
        TransitionAnimations.emitDust(at: center, in: overlayLayer, preset: "FadeOut")
        // Clear overlay after animation
        overlayLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.overlayLayer.removeAllChildren()
            }
        ]))
    }
    
    func runDisassembleExit() {
        guard let assembledNode else { return }
        // Disassemble pieces and fly them off screen in the configured direction
        let exitVector = getExitVector(for: currentExitDirection)
        
        for (index, child) in assembledNode.children.enumerated() {
            guard let piece = child as? SKShapeNode else { continue }
            
            // Add some variation to the exit vector for each piece
            let variation = CGFloat.random(in: 0.8...1.2)
            let pieceExitVector = CGVector(
                dx: exitVector.dx * variation + CGFloat.random(in: -50...50),
                dy: exitVector.dy * variation + CGFloat.random(in: -50...50)
            )
            
            // Stagger the timing for each piece
            let delay = Double(index) * 0.1
            
            // Create disassemble animation
            let disassemble = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                // Small random movement to show separation
                SKAction.moveBy(x: CGFloat.random(in: -20...20), 
                              y: CGFloat.random(in: -20...20), 
                              duration: 0.2),
                // Then fly off screen
                SKAction.group([
                    SKAction.moveBy(x: pieceExitVector.dx, y: pieceExitVector.dy, duration: 0.8),
                    SKAction.rotate(byAngle: CGFloat.random(in: -CGFloat.pi * 2...CGFloat.pi * 2), duration: 0.8),
                    SKAction.scale(to: 0.5, duration: 0.8),
                    SKAction.fadeOut(withDuration: 0.8)
                ])
            ])
            disassemble.timingMode = .easeIn
            
            piece.run(disassemble)
        }
        
        // Rebuild after animation completes
        assembledNode.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                self?.rebuildAssembledNode()
            }
        ]))
    }

    private func clearLoops() {
        stopBreathingLoop(); stopWobbleLoop(); stopShimmerLoop()
        assembledNode?.removeAllActions()
    }

    // MARK: - Puzzle Loading
    func loadGamePuzzle(_ puzzle: GamePuzzleData) {
        currentPuzzle = puzzle
        assembledNode?.removeFromParent()
        let node = buildAssembledNode(from: puzzle)
        node.position = CGPoint(x: size.width/2, y: size.height/2)
        assembledLayer.addChild(node)
        assembledNode = node
    }

    private func rebuildAssembledNode() {
        if let puzzle = currentPuzzle {
            loadGamePuzzle(puzzle)
        } else if assembledNode != nil {
            // Rebuild from preset if no puzzle loaded
            let preset: Preset = .classicTangram
            preparePreset(preset: preset)
        }
    }
    
    private func buildAssembledNode(from puzzle: GamePuzzleData) -> SKNode {
        // Build silhouettes exactly like game target, but as a unified container
        let bounds = TangramBounds.calculatePuzzleBoundsSK(targets: puzzle.targetPieces)
        let boundsCenterSK = CGPoint(x: bounds.midX, y: bounds.midY)
        let container = SKNode()
        for target in puzzle.targetPieces {
            let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
            let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
            let transformedVerticesRaw = TangramGameGeometry.transformVertices(scaledVertices, with: target.transform)
            let transformedVerticesSK = transformedVerticesRaw.map { TangramPoseMapper.spriteKitPosition(fromRawPosition: $0) }
            let centered = transformedVerticesSK.map { CGPoint(x: $0.x - boundsCenterSK.x, y: $0.y - boundsCenterSK.y) }
            let path = CGMutablePath()
            if let first = centered.first {
                path.move(to: first)
                for v in centered.dropFirst() { path.addLine(to: v) }
                path.closeSubpath()
            }
            let shape = SKShapeNode(path: path)
            shape.fillColor = TangramColors.Sprite.uiColor(for: target.pieceType)
            shape.strokeColor = shape.fillColor.darker(by: 20)
            shape.lineWidth = 2
            container.addChild(shape)
        }
        return container
    }
}

private extension SKAction {
    func repeatForever() -> SKAction { SKAction.repeatForever(self) }
}


