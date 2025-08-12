//
//  TransitionAnimations.swift
//  Bemo
//
//  Scene-wide and container animations: square takeover, assemble, explosion, dust
//

// WHAT: Generic SKAction builders and helpers for transition effects
// ARCHITECTURE: Independent of game; used by AnimationLab and integratable into Tangram scene
// USAGE: Call static functions to create/run effects

import SpriteKit

enum TransitionAnimations {
    
    // MARK: - Complete Tangram Square Helper  
    private static func createCompleteTangramSquare(size: CGFloat, at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        
        // Create tangram square using the classic 7-piece arrangement
        // Based on the actual square puzzle formation
        let scale = size / 100.0  // Normalize to 100 unit square
        
        // All pieces for the classic tangram square
        let pieces: [(type: TangramPieceType, vertices: [CGPoint])] = [
            // Medium Triangle - top left 
            (.mediumTriangle, [
                CGPoint(x: -50, y: 50),
                CGPoint(x: -50, y: 0),
                CGPoint(x: 0, y: 50)
            ]),
            // Small Triangle 1 - top right
            (.smallTriangle1, [
                CGPoint(x: 50, y: 50),
                CGPoint(x: 25, y: 25),
                CGPoint(x: 50, y: 0)
            ]),
            // Square - top center (as diamond)
            (.square, [
                CGPoint(x: 0, y: 50),
                CGPoint(x: 25, y: 25),
                CGPoint(x: 0, y: 0),
                CGPoint(x: -25, y: 25)
            ]),
            // Small Triangle 2 - center
            (.smallTriangle2, [
                CGPoint(x: 0, y: 0),
                CGPoint(x: -25, y: -25),
                CGPoint(x: 0, y: -50)
            ]),
            // Parallelogram - bottom center
            (.parallelogram, [
                CGPoint(x: -25, y: -25),
                CGPoint(x: 25, y: -25),
                CGPoint(x: 0, y: -50),
                CGPoint(x: -50, y: -50)
            ]),
            // Large Triangle 1 - bottom left
            (.largeTriangle1, [
                CGPoint(x: -50, y: 0),
                CGPoint(x: -50, y: -50),
                CGPoint(x: 0, y: -50)
            ]),
            // Large Triangle 2 - bottom right
            (.largeTriangle2, [
                CGPoint(x: 50, y: 0),
                CGPoint(x: 0, y: -50),
                CGPoint(x: 50, y: -50)
            ])
        ]
        
        // Create each piece
        for (pieceType, vertices) in pieces {
            let path = CGMutablePath()
            let scaledVertices = vertices.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
            
            if let first = scaledVertices.first {
                path.move(to: first)
                for vertex in scaledVertices.dropFirst() {
                    path.addLine(to: vertex)
                }
                path.closeSubpath()
            }
            
            let shape = SKShapeNode(path: path)
            shape.fillColor = TangramColors.Sprite.uiColor(for: pieceType)
            shape.strokeColor = shape.fillColor.darker(by: 20)
            shape.lineWidth = 0.5
            container.addChild(shape)
        }
        
        return container
    }
    
    // MARK: - Row Slide Animation
    static func squareTakeover(in scene: SKScene, layer: SKNode, duration: TimeInterval) -> SKAction {
        // Rows of tangram squares sliding in alternating directions
        let squareSize: CGFloat = 80
        let spacing: CGFloat = 10
        let totalSize = squareSize + spacing
        
        let cols = Int(scene.size.width / totalSize) + 2
        let rows = Int(scene.size.height / totalSize) + 1
        
        for row in 0..<rows {
            let rowContainer = SKNode()
            layer.addChild(rowContainer)
            
            for col in 0..<cols {
                let tangramSquare = createCompleteTangramSquare(size: squareSize, at: CGPoint.zero)
                let finalX = CGFloat(col) * totalSize + squareSize/2
                let finalY = CGFloat(row) * totalSize + squareSize/2
                tangramSquare.position = CGPoint(x: finalX, y: finalY)
                rowContainer.addChild(tangramSquare)
            }
            
            // Start position based on row (alternating sides)
            let startX = (row % 2 == 0) ? -scene.size.width : scene.size.width * 2
            rowContainer.position = CGPoint(x: startX, y: 0)
            rowContainer.alpha = 0
            
            // Slide in with delay based on row
            let slideIn = SKAction.sequence([
                SKAction.wait(forDuration: Double(row) * 0.2),
                SKAction.group([
                    SKAction.moveTo(x: 0, duration: duration),
                    SKAction.fadeIn(withDuration: duration * 0.5)
                ])
            ])
            slideIn.timingMode = .easeOut
            
            rowContainer.run(slideIn)
        }
        
        return SKAction.sequence([SKAction.wait(forDuration: duration + 1.0)])
    }
    
    
    // MARK: - Column Slide Animation
    static func squareWavePattern(in scene: SKScene, layer: SKNode, duration: TimeInterval) {
        // Columns of tangram squares sliding in alternating directions
        let squareSize: CGFloat = 80
        let spacing: CGFloat = 10
        let totalSize = squareSize + spacing
        let cols = Int(scene.size.width / totalSize) + 1
        let rows = Int(scene.size.height / totalSize) + 2
        
        for col in 0..<cols {
            let colContainer = SKNode()
            layer.addChild(colContainer)
            
            for row in 0..<rows {
                let tangramSquare = createCompleteTangramSquare(size: squareSize, at: CGPoint.zero)
                let finalX = CGFloat(col) * totalSize + squareSize/2
                let finalY = CGFloat(row) * totalSize + squareSize/2
                tangramSquare.position = CGPoint(x: finalX, y: finalY)
                colContainer.addChild(tangramSquare)
            }
            
            // Start position based on column (alternating top/bottom)
            let startY = (col % 2 == 0) ? -scene.size.height : scene.size.height * 2
            colContainer.position = CGPoint(x: 0, y: startY)
            colContainer.alpha = 0
            
            // Slide in with delay based on column
            let slideIn = SKAction.sequence([
                SKAction.wait(forDuration: Double(col) * 0.2),
                SKAction.group([
                    SKAction.moveTo(y: 0, duration: duration),
                    SKAction.fadeIn(withDuration: duration * 0.5)
                ])
            ])
            slideIn.timingMode = .easeOut
            
            colContainer.run(slideIn)
        }
    }
    
    // MARK: - Shatter Animation
    static func squareSpiralPattern(in scene: SKScene, layer: SKNode, duration: TimeInterval) {
        // Full grid that shatters piece by piece
        let squareSize: CGFloat = 80
        let spacing: CGFloat = 10
        let totalSize = squareSize + spacing
        let sceneWidth = scene.size.width
        let sceneHeight = scene.size.height
        let cols = Int(sceneWidth / totalSize) + 1
        let rows = Int(sceneHeight / totalSize) + 1
        
        var allSquares: [SKNode] = []
        
        // Create full grid first
        for row in 0..<rows {
            for col in 0..<cols {
                let tangramSquare = createCompleteTangramSquare(size: squareSize, at: CGPoint.zero)
                let x = CGFloat(col) * totalSize + squareSize/2
                let y = CGFloat(row) * totalSize + squareSize/2
                tangramSquare.position = CGPoint(x: x, y: y)
                layer.addChild(tangramSquare)
                allSquares.append(tangramSquare)
            }
        }
        
        // Capture scene height for use in closure
        let fallHeight = sceneHeight + 200
        
        // Wait a moment then shatter
        layer.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak layer] in
                guard layer != nil else { return }
                
                // Shatter each square's pieces individually
                var pieceDelay: TimeInterval = 0
                let acceleration: TimeInterval = 0.95  // Speed up factor
                
                for square in allSquares.shuffled() {
                    // Make each piece in the square fall
                    for (index, piece) in square.children.enumerated() {
                        let fallDelay = pieceDelay + Double(index) * 0.02
                        
                        // Random fall direction and rotation
                        let fallX = CGFloat.random(in: -100...100)
                        let fallY = CGFloat.random(in: -fallHeight...(-fallHeight - 200))
                        let rotation = CGFloat.random(in: -CGFloat.pi * 4...CGFloat.pi * 4)
                        
                        let shatter = SKAction.sequence([
                            SKAction.wait(forDuration: fallDelay),
                            SKAction.group([
                                SKAction.moveBy(x: fallX, y: fallY, duration: 1.5),
                                SKAction.rotate(byAngle: rotation, duration: 1.5),
                                SKAction.fadeOut(withDuration: 1.5)
                            ])
                        ])
                        shatter.timingMode = .easeIn
                        
                        piece.run(shatter)
                    }
                    
                    // Accelerate the delay (pieces fall faster and faster)
                    pieceDelay *= acceleration
                    if pieceDelay < 0.001 { pieceDelay = 0.001 }  // Minimum delay
                }
            }
        ]))
    }

    private static func randomEdgeStart(size: CGSize) -> CGPoint {
        let edge = Int.random(in: 0..<4)
        switch edge {
        case 0: return CGPoint(x: -20, y: CGFloat.random(in: 0...size.height))
        case 1: return CGPoint(x: size.width+20, y: CGFloat.random(in: 0...size.height))
        case 2: return CGPoint(x: CGFloat.random(in: 0...size.width), y: -20)
        default: return CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height+20)
        }
    }

    // MARK: - Assemble
    static func assemble(node: SKNode, within frame: CGRect, duration: TimeInterval) {
        // Scatter children around then animate back to their current pose
        for child in node.children {
            let originalPos = child.position
            let originalRot = child.zRotation
            let off = CGPoint(
                x: CGFloat.random(in: frame.minX...frame.maxX) - node.position.x,
                y: CGFloat.random(in: frame.minY...frame.maxY) - node.position.y
            )
            child.position = off
            child.zRotation = CGFloat.random(in: -CGFloat.pi...CGFloat.pi)
            let move = SKAction.move(to: originalPos, duration: duration)
            move.timingMode = .easeOut
            let rotate = SKAction.rotate(toAngle: originalRot, duration: duration, shortestUnitArc: true)
            rotate.timingMode = .easeOut
            let settle = SKAction.sequence([
                SKAction.scale(to: 1.06, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.12)
            ])
            child.run(SKAction.sequence([SKAction.group([move, rotate]), settle]))
        }
    }

    // MARK: - Explosion
    static func explosion(node: SKNode, intensity: CGFloat = 1.0, radius: CGFloat = 200, duration: TimeInterval = 0.6) -> SKAction {
        let center = CGPoint.zero
        let group = SKAction.group(node.children.map { child in
            let dir = CGVector(dx: child.position.x - center.x, dy: child.position.y - center.y)
            let len = max(1, hypot(dir.dx, dir.dy))
            let unit = CGVector(dx: dir.dx/len, dy: dir.dy/len)
            let travel = CGVector(dx: unit.dx * radius * intensity * CGFloat.random(in: 0.8...1.2),
                                   dy: unit.dy * radius * intensity * CGFloat.random(in: 0.8...1.2))
            let move = SKAction.moveBy(x: travel.dx, y: travel.dy, duration: duration)
            move.timingMode = .easeOut
            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -CGFloat.pi...CGFloat.pi), duration: duration)
            let fade = SKAction.fadeOut(withDuration: duration)
            return SKAction.group([move, spin, fade])
        })
        return SKAction.sequence([group])
    }

    // MARK: - Dust Cloud
    static func emitDust(at position: CGPoint, in layer: SKNode, preset: String) {
        if let emitter = SKEmitterNode(fileNamed: preset + ".sks") ?? SKEmitterNode(fileNamed: preset) {
            emitter.position = position
            emitter.zPosition = 1000
            layer.addChild(emitter)
            emitter.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
        }
    }
    
    // MARK: - Confetti
    static func confetti(in layer: SKNode, duration: TimeInterval) -> SKAction {
        return confettiBurst(in: layer, duration: duration, intensity: 1.0)
    }
    
    static func confettiBurst(in layer: SKNode, duration: TimeInterval, intensity: CGFloat = 1.0) -> SKAction {
        return SKAction.run {
            let colors: [SKColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple, .systemOrange, .systemPink]
            let particleCount = Int(50 * intensity)
            
            for _ in 0..<particleCount {
                let confetti = SKShapeNode(rectOf: CGSize(width: 8, height: 12))
                confetti.fillColor = colors.randomElement()!
                confetti.strokeColor = .clear
                
                // Start from much higher up for longer fall duration
                let screenHeight = layer.scene?.size.height ?? 600
                confetti.position = CGPoint(
                    x: CGFloat.random(in: 0...(layer.scene?.size.width ?? 400)),
                    y: screenHeight + CGFloat.random(in: 100...300)  // Start 100-300 points above screen
                )
                confetti.zRotation = CGFloat.random(in: 0...(2 * .pi))
                confetti.zPosition = 900
                layer.addChild(confetti)
                
                // Longer fall duration for extended effect
                let baseDuration = duration * 1.5 / intensity  // Increased base duration
                let fallDuration = TimeInterval.random(in: baseDuration...baseDuration*2.0)  // More variation
                
                // Fall distance now needs to account for higher starting position
                let fallDistance = screenHeight + confetti.position.y - screenHeight + 350  // Fall well below screen
                
                let fall = SKAction.group([
                    SKAction.moveBy(
                        x: CGFloat.random(in: -50...50) * intensity,
                        y: -fallDistance,
                        duration: fallDuration
                    ),
                    SKAction.rotate(byAngle: CGFloat.random(in: 4...8) * .pi * intensity, duration: fallDuration),
                    SKAction.sequence([
                        SKAction.wait(forDuration: fallDuration * 0.8),  // Stay visible longer
                        SKAction.fadeOut(withDuration: fallDuration * 0.2)
                    ])
                ])
                fall.timingMode = .easeIn
                
                confetti.run(SKAction.sequence([fall, .removeFromParent()]))
            }
        }
    }
}


