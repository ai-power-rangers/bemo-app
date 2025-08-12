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
        
        // Create target pieces exactly like the square puzzle from square.json
        // These transforms are from the actual square puzzle data
        let targetPieces: [GamePuzzleData.TargetPiece] = [
            GamePuzzleData.TargetPiece(id: "1", pieceType: .mediumTriangle, 
                       transform: CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 125.789, ty: 213.456)),
            GamePuzzleData.TargetPiece(id: "2", pieceType: .smallTriangle1,
                       transform: CGAffineTransform(a: -0.7071, b: -0.7071, c: 0.7071, d: -0.7071, tx: 231.855, ty: 248.811)),
            GamePuzzleData.TargetPiece(id: "3", pieceType: .square,
                       transform: CGAffineTransform(a: 0.7071, b: 0.7071, c: -0.7071, d: 0.7071, tx: 196.5, ty: 213.456)),
            GamePuzzleData.TargetPiece(id: "4", pieceType: .smallTriangle2,
                       transform: CGAffineTransform(a: -0.7071, b: 0.7071, c: -0.7071, d: -0.7071, tx: 196.5, ty: 284.167)),
            GamePuzzleData.TargetPiece(id: "5", pieceType: .parallelogram,
                       transform: CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: 161.145, ty: 319.522)),
            GamePuzzleData.TargetPiece(id: "6", pieceType: .largeTriangle1,
                       transform: CGAffineTransform(a: 0.7071, b: 0.7071, c: -0.7071, d: 0.7071, tx: 196.5, ty: 284.167)),
            GamePuzzleData.TargetPiece(id: "7", pieceType: .largeTriangle2,
                       transform: CGAffineTransform(a: 0.7071, b: -0.7071, c: 0.7071, d: 0.7071, tx: 196.5, ty: 284.167))
        ]
        
        // Build exactly like buildAssembledNode does
        let bounds = TangramBounds.calculatePuzzleBoundsSK(targets: targetPieces)
        let boundsCenterSK = CGPoint(x: bounds.midX, y: bounds.midY)
        
        // Calculate scale to fit desired size
        let boundsSize = max(bounds.width, bounds.height)
        let scale = size / boundsSize
        
        for target in targetPieces {
            let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
            let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
            let transformedVerticesRaw = TangramGameGeometry.transformVertices(scaledVertices, with: target.transform)
            let transformedVerticesSK = transformedVerticesRaw.map { TangramPoseMapper.spriteKitPosition(fromRawPosition: $0) }
            
            // Simplify the centering calculation
            var centered: [CGPoint] = []
            for vertex in transformedVerticesSK {
                let x = (vertex.x - boundsCenterSK.x) * scale
                let y = (vertex.y - boundsCenterSK.y) * scale
                centered.append(CGPoint(x: x, y: y))
            }
            
            let path = CGMutablePath()
            if let first = centered.first {
                path.move(to: first)
                for v in centered.dropFirst() { 
                    path.addLine(to: v) 
                }
                path.closeSubpath()
            }
            
            let shape = SKShapeNode(path: path)
            shape.fillColor = TangramColors.Sprite.uiColor(for: target.pieceType)
            shape.strokeColor = shape.fillColor.darker(by: 20)
            shape.lineWidth = 1
            container.addChild(shape)
        }
        
        return container
    }
    
    // MARK: - Row Slide Animation
    static func squareTakeover(in scene: SKScene, layer: SKNode, duration: TimeInterval) -> SKAction {
        // Cover entire screen with tangram squares in brick pattern
        let squareSize: CGFloat = 200  // 2x bigger
        let spacing: CGFloat = 0  // No gaps - seamless pattern
        let totalSize = squareSize + spacing
        
        // Calculate how many rows and columns we need to fill the screen
        let cols = Int(scene.size.width / totalSize) + 3  // Extra for sliding and offset
        let rows = Int(scene.size.height / totalSize) + 2  // Extra to cover full height
        
        // Rotation options (0°, 90°, 180°, 270°) 
        let rotations: [CGFloat] = [0, .pi/2, .pi, .pi * 3/2]
        
        // Create all rows to cover the screen
        for row in 0..<rows {
            let rowContainer = SKNode()
            layer.addChild(rowContainer)
            
            // Brick pattern offset - every other row is offset by half a square
            let xOffset = (row % 2 == 0) ? 0 : totalSize / 2
            
            // Create all squares for this row
            for col in 0..<cols {
                // Final position for this square
                let finalX = CGFloat(col) * totalSize + xOffset - totalSize
                let finalY = CGFloat(row) * totalSize
                
                // Each square gets its own random rotation
                let finalRotation = rotations[Int.random(in: 0..<rotations.count)]
                
                // Create the complete tangram square at final position
                let tangramSquare = createCompleteTangramSquare(size: squareSize, at: CGPoint.zero)
                tangramSquare.position = CGPoint(x: finalX, y: finalY)
                tangramSquare.zRotation = finalRotation
                rowContainer.addChild(tangramSquare)
                
                // PHASE 1: Disassemble and scatter the individual pieces
                for (index, piece) in tangramSquare.children.enumerated() {
                    // Store final position
                    let finalPiecePos = piece.position
                    let finalPieceRot = piece.zRotation
                    
                    // Scatter pieces randomly
                    let scatterX = CGFloat.random(in: -scene.size.width...scene.size.width * 2)
                    let scatterY = CGFloat.random(in: -scene.size.height...scene.size.height * 2)
                    piece.position = CGPoint(x: scatterX, y: scatterY)
                    piece.zRotation = CGFloat.random(in: 0...CGFloat.pi * 2)
                    piece.alpha = 0
                    piece.setScale(0.3)
                    
                    // Animate pieces coming together
                    let pieceDelay = Double(index) * 0.05 + Double.random(in: 0...0.1)
                    let assemble = SKAction.sequence([
                        SKAction.wait(forDuration: pieceDelay),
                        SKAction.group([
                            SKAction.move(to: finalPiecePos, duration: 0.4),
                            SKAction.rotate(toAngle: finalPieceRot, duration: 0.4),
                            SKAction.fadeIn(withDuration: 0.3),
                            SKAction.scale(to: 1.0, duration: 0.4)
                        ])
                    ])
                    assemble.timingMode = .easeOut
                    
                    piece.run(assemble)
                }
            }
            
            // PHASE 2: Sliding animation starts IMMEDIATELY
            // Alternate rows slide in opposite directions
            let slideDirection: CGFloat = (row % 2 == 0) ? 1 : -1
            
            // Start faster and accelerate more
            var slideDuration = 0.8  // Much faster start
            let acceleration = 0.85  // Speed up factor
            
            // Create accelerating slide sequence - NO WAIT, start sliding immediately
            var slideActions: [SKAction] = []
            
            for _ in 0..<10 {  // 10 cycles of back and forth, getting faster
                let slideDistance = totalSize  // Slide by 1 square width
                slideActions.append(SKAction.moveBy(x: slideDistance * slideDirection, y: 0, duration: slideDuration))
                slideActions.append(SKAction.moveBy(x: -slideDistance * slideDirection, y: 0, duration: slideDuration))
                slideDuration *= acceleration  // Get faster each cycle
            }
            
            // After acceleration, maintain fast speed
            slideActions.append(SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.moveBy(x: totalSize * 2 * slideDirection, y: 0, duration: slideDuration),
                    SKAction.moveBy(x: -totalSize * 2 * slideDirection, y: 0, duration: slideDuration)
                ])
            ))
            
            let slideSequence = SKAction.sequence(slideActions)
            slideSequence.timingMode = .easeInEaseOut
            
            rowContainer.run(slideSequence)
        }
        
        return SKAction.sequence([SKAction.wait(forDuration: duration + 1.0)])
    }
    
    
    // MARK: - Column Slide Animation
    static func squareWavePattern(in scene: SKScene, layer: SKNode, duration: TimeInterval) {
        // Cover entire screen with tangram squares in vertical brick pattern
        let squareSize: CGFloat = 200  // Same size as row animation
        let spacing: CGFloat = 0  // No gaps - seamless pattern
        let totalSize = squareSize + spacing
        
        // Calculate how many columns and rows we need to fill the screen
        let cols = Int(scene.size.width / totalSize) + 2  // Extra to cover full width
        let rows = Int(scene.size.height / totalSize) + 3  // Extra for sliding and offset
        
        // Rotation options (0°, 90°, 180°, 270°)
        let rotations: [CGFloat] = [0, .pi/2, .pi, .pi * 3/2]
        
        // Create all columns to cover the screen
        for col in 0..<cols {
            let colContainer = SKNode()
            layer.addChild(colContainer)
            
            // Vertical brick pattern offset - every other column is offset by half a square
            let yOffset = (col % 2 == 0) ? 0 : totalSize / 2
            
            // Create all squares for this column
            for row in 0..<rows {
                // Final position for this square
                let finalX = CGFloat(col) * totalSize
                let finalY = CGFloat(row) * totalSize + yOffset - totalSize
                
                // Each square gets its own random rotation
                let finalRotation = rotations[Int.random(in: 0..<rotations.count)]
                
                // Create the complete tangram square at final position
                let tangramSquare = createCompleteTangramSquare(size: squareSize, at: CGPoint.zero)
                tangramSquare.position = CGPoint(x: finalX, y: finalY)
                tangramSquare.zRotation = finalRotation
                colContainer.addChild(tangramSquare)
                
                // PHASE 1: Disassemble and scatter the individual pieces
                for (index, piece) in tangramSquare.children.enumerated() {
                    // Store final position
                    let finalPiecePos = piece.position
                    let finalPieceRot = piece.zRotation
                    
                    // Scatter pieces randomly
                    let scatterX = CGFloat.random(in: -scene.size.width...scene.size.width * 2)
                    let scatterY = CGFloat.random(in: -scene.size.height...scene.size.height * 2)
                    piece.position = CGPoint(x: scatterX, y: scatterY)
                    piece.zRotation = CGFloat.random(in: 0...CGFloat.pi * 2)
                    piece.alpha = 0
                    piece.setScale(0.3)
                    
                    // Animate pieces coming together
                    let pieceDelay = Double(index) * 0.05 + Double.random(in: 0...0.1)
                    let assemble = SKAction.sequence([
                        SKAction.wait(forDuration: pieceDelay),
                        SKAction.group([
                            SKAction.move(to: finalPiecePos, duration: 0.4),
                            SKAction.rotate(toAngle: finalPieceRot, duration: 0.4),
                            SKAction.fadeIn(withDuration: 0.3),
                            SKAction.scale(to: 1.0, duration: 0.4)
                        ])
                    ])
                    assemble.timingMode = .easeOut
                    
                    piece.run(assemble)
                }
            }
            
            // PHASE 2: Sliding animation starts IMMEDIATELY
            // Alternate columns slide in opposite directions (up/down)
            let slideDirection: CGFloat = (col % 2 == 0) ? 1 : -1
            
            // Start faster and accelerate more (same as row animation)
            var slideDuration = 0.8  // Much faster start - matches row animation
            let acceleration = 0.85  // Same acceleration as rows
            
            // Create accelerating slide sequence - NO WAIT
            var slideActions: [SKAction] = []
            
            for _ in 0..<10 {  // 10 cycles of up and down, getting faster
                let slideDistance = totalSize  // Slide by 1 square height
                slideActions.append(SKAction.moveBy(x: 0, y: slideDistance * slideDirection, duration: slideDuration))
                slideActions.append(SKAction.moveBy(x: 0, y: -slideDistance * slideDirection, duration: slideDuration))
                slideDuration *= acceleration  // Get faster each cycle
            }
            
            // After acceleration, maintain fast speed
            slideActions.append(SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.moveBy(x: 0, y: totalSize * slideDirection, duration: slideDuration),
                    SKAction.moveBy(x: 0, y: -totalSize * slideDirection, duration: slideDuration)
                ])
            ))
            
            let slideSequence = SKAction.sequence(slideActions)
            slideSequence.timingMode = .easeInEaseOut
            
            colContainer.run(slideSequence)
        }
    }
    
    // MARK: - Shatter Animation
    static func squareSpiralPattern(in scene: SKScene, layer: SKNode, duration: TimeInterval) {
        // Create brick pattern like row animation, then shatter like glass
        let squareSize: CGFloat = 200
        let spacing: CGFloat = 0
        let totalSize = squareSize + spacing
        
        // Calculate grid dimensions
        let cols = Int(scene.size.width / totalSize) + 2
        let rows = Int(scene.size.height / totalSize) + 2
        
        // Rotation options
        let rotations: [CGFloat] = [0, .pi/2, .pi, .pi * 3/2]
        
        // Store all pieces for shatter effect
        var allPieces: [(piece: SKNode, position: CGPoint, square: SKNode)] = []
        
        // Create full grid with brick pattern
        for row in 0..<rows {
            // Brick pattern offset
            let xOffset = (row % 2 == 0) ? 0 : totalSize / 2
            
            for col in 0..<cols {
                let x = CGFloat(col) * totalSize + xOffset
                let y = CGFloat(row) * totalSize
                let rotation = rotations[Int.random(in: 0..<rotations.count)]
                
                let tangramSquare = createCompleteTangramSquare(size: squareSize, at: CGPoint.zero)
                tangramSquare.position = CGPoint(x: x, y: y)
                tangramSquare.zRotation = rotation
                layer.addChild(tangramSquare)
                
                // Store each piece with its world position and parent square
                for piece in tangramSquare.children {
                    let worldPos = tangramSquare.convert(piece.position, to: layer)
                    allPieces.append((piece: piece, position: worldPos, square: tangramSquare))
                }
            }
        }
        
        // Random impact point in upper portion of screen (like something was thrown)
        let impactPoint = CGPoint(
            x: scene.size.width * CGFloat.random(in: 0.3...0.7),
            y: scene.size.height * CGFloat.random(in: 0.6...0.8)
        )
        
        // Create impact visual (optional - a small flash or crack effect)
        let impactNode = SKShapeNode(circleOfRadius: 10)
        impactNode.position = impactPoint
        impactNode.fillColor = .white
        impactNode.alpha = 0
        impactNode.zPosition = 1000
        layer.addChild(impactNode)
        
        // Show impact
        impactNode.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.scale(to: 3, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        
        // PHASE 1: Impact and initial cracks (a few pieces fall immediately)
        layer.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),  // Impact happens
            SKAction.run {
                // Sort pieces by distance from impact
                let sortedPieces = allPieces.sorted { piece1, piece2 in
                    let dist1 = hypot(piece1.position.x - impactPoint.x, piece1.position.y - impactPoint.y)
                    let dist2 = hypot(piece2.position.x - impactPoint.x, piece2.position.y - impactPoint.y)
                    return dist1 < dist2
                }
                
                // PHASE 1: First few pieces at impact point fall immediately
                let impactRadius: CGFloat = 150
                var crackedPieces = 0
                
                for (piece, worldPos, _) in sortedPieces {
                    let distance = hypot(worldPos.x - impactPoint.x, worldPos.y - impactPoint.y)
                    
                    if distance < impactRadius && crackedPieces < 10 {
                        // These pieces fall immediately from impact
                        crackedPieces += 1
                        
                        // Small jiggle first (crack forming)
                        let jiggle = SKAction.sequence([
                            SKAction.moveBy(x: CGFloat.random(in: -2...2), y: CGFloat.random(in: -2...2), duration: 0.05),
                            SKAction.moveBy(x: CGFloat.random(in: -2...2), y: CGFloat.random(in: -2...2), duration: 0.05)
                        ])
                        
                        // Then fall STRAIGHT DOWN with gravity
                        let fallX = CGFloat.random(in: -10...10)  // Very minimal sideways drift
                        let fallY = -scene.size.height - 500  // Fall all the way down
                        let rotation = CGFloat.random(in: -CGFloat.pi/4...CGFloat.pi/4)  // Slight rotation
                        
                        let fall = SKAction.sequence([
                            jiggle,
                            SKAction.wait(forDuration: Double.random(in: 0...0.1)),  // Tiny variance
                            SKAction.group([
                                SKAction.moveBy(x: fallX, y: fallY, duration: 1.2),
                                SKAction.rotate(byAngle: rotation, duration: 1.2),
                                SKAction.fadeOut(withDuration: 1.2)
                            ])
                        ])
                        fall.timingMode = .easeIn  // Accelerate as it falls
                        
                        piece.run(fall)
                    }
                }
                
                // PHASE 2: Crack spreads and rest of glass falls
                var delay: TimeInterval = 0.8  // Wait for initial pieces to fall
                let crackSpeed: TimeInterval = 0.003  // How fast crack spreads
                
                // Remaining pieces fall in waves based on distance
                for (piece, worldPos, _) in sortedPieces {
                    let distance = hypot(worldPos.x - impactPoint.x, worldPos.y - impactPoint.y)
                    
                    if distance >= impactRadius {  // Skip already fallen pieces
                        // Calculate delay based on distance (crack spreading)
                        let waveDelay = delay + (distance / scene.size.width) * 0.5
                        
                        // Pieces fall mostly straight down with slight variation
                        let fallX = CGFloat.random(in: -50...50)
                        let fallY = -scene.size.height - 300
                        let rotation = CGFloat.random(in: -CGFloat.pi * 2...CGFloat.pi * 2)
                        
                        let shatter = SKAction.sequence([
                            SKAction.wait(forDuration: waveDelay),
                            // Small shake as crack reaches this piece
                            SKAction.repeat(
                                SKAction.sequence([
                                    SKAction.moveBy(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -1...1), duration: 0.02),
                                    SKAction.moveBy(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -1...1), duration: 0.02)
                                ]), count: 2
                            ),
                            // Then fall
                            SKAction.group([
                                SKAction.moveBy(x: fallX, y: fallY, duration: 1.8),
                                SKAction.rotate(byAngle: rotation, duration: 1.8),
                                SKAction.sequence([
                                    SKAction.wait(forDuration: 0.3),
                                    SKAction.fadeOut(withDuration: 1.5)
                                ])
                            ])
                        ])
                        shatter.timingMode = .easeIn
                        
                        piece.run(shatter)
                        
                        // Accelerate the cascade effect
                        delay += crackSpeed
                        if delay > 2.0 { delay = 2.0 }  // Cap maximum delay
                    }
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


