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
import UIKit

class TangramPuzzleScene: SKScene {
    
    // MARK: - Properties
    
    var puzzle: GamePuzzleData?
    var onPieceCompleted: ((String) -> Void)?
    var onPuzzleCompleted: (() -> Void)?
    var onBackPressed: (() -> Void)?
    var onNextPressed: (() -> Void)?
    var onStartTimer: (() -> Void)?
    var onToggleHints: (() -> Void)?
    var safeAreaTop: CGFloat = 0
    
    // Node layers
    private var backgroundLayer = SKNode()
    private var puzzleLayer = SKNode()
    private var piecesLayer = SKNode()
    private var effectsLayer = SKNode()
    private var uiLayer = SKNode()  // Layer for UI elements
    
    // Piece tracking
    private var targetPieces: [String: SKShapeNode] = [:]
    private var availablePieces: [String: PuzzlePieceNode] = [:]
    private var completedPieces: Set<String> = []
    private var selectedPiece: PuzzlePieceNode?
    
    // Layout properties
    private var puzzleAreaHeight: CGFloat = 0
    private var piecesAreaHeight: CGFloat = 0
    private var puzzleCenter: CGPoint = .zero
    private var puzzleScale: CGFloat = 1.0
    private var puzzleBounds: CGRect = .zero
    
    // Visual settings
    private let targetAlpha: CGFloat = 0.3
    private let snapDistance: CGFloat = 50.0  // Position tolerance in points
    private let rotationSnapTolerance: CGFloat = 15.0 // degrees - stricter for accuracy
    
    // Touch tracking for rotation
    private var initialTouchAngle: CGFloat = 0
    private var initialPieceRotation: CGFloat = 0
    private var isRotating: Bool = false
    
    // UI Elements
    private var backButton: SKNode?
    private var nextButton: SKNode?
    private var timerLabel: SKLabelNode?
    private var startTimerButton: SKNode?
    private var progressBar: SKShapeNode?
    private var progressFill: SKShapeNode?
    private var hintsButton: SKNode?
    private var showingHints: Bool = false
    
    // Rotation dial
    private var rotationDial: RotationDialNode?
    private var isShowingRotationDial: Bool = false
    private var pendingRotationPiece: PuzzlePieceNode?
    private var tapStartTime: TimeInterval = 0
    private var tapStartLocation: CGPoint = .zero
    
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
        addChild(uiLayer)  // UI on top
        
        // Setup layout areas - adjusted for full screen
        puzzleAreaHeight = size.height * 0.4  // Top 40% for target
        piecesAreaHeight = size.height * 0.3  // Bottom 30% for pieces
        puzzleCenter = CGPoint(x: size.width / 2, y: size.height * 0.75)  // Higher up for target
        
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
        
        // Calculate the original bounds of the puzzle
        puzzleBounds = calculatePuzzleBounds(for: puzzle.targetPieces)
        
        // Use the same scale as the movable pieces (no additional scaling)
        // The pieces already use TangramGameConstants.visualScale
        puzzleScale = 1.0
        
        // Create target silhouettes with proper scaling and positioning
        for target in puzzle.targetPieces {
            createTargetPiece(target, puzzleBounds: puzzleBounds, scale: puzzleScale)
        }
        
        // Position the puzzle layer to center the target at the top of screen
        // Offset to center the puzzle bounds and account for safe area
        let centerX = size.width / 2 - puzzleBounds.midX
        let centerY = (size.height - safeAreaTop) * 0.75 + puzzleBounds.midY  // Top area below safe area
        puzzleLayer.position = CGPoint(x: centerX, y: centerY)
        
        // Create movable pieces at the bottom
        createAvailablePieces(from: puzzle.targetPieces)
    }
    
    private func createTargetPiece(_ target: GamePuzzleData.TargetPiece, puzzleBounds: CGRect, scale: CGFloat) {
        // Get transformed vertices for the target piece
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        let transformedVertices = TangramGameGeometry.transformVertices(scaledVertices, with: target.transform)
        
        // Calculate the center of the transformed piece
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        for vertex in transformedVertices {
            centerX += vertex.x
            centerY += vertex.y
        }
        centerX /= CGFloat(transformedVertices.count)
        centerY /= CGFloat(transformedVertices.count)
        
        // Create shape from transformed vertices
        // Just flip Y for SpriteKit coordinate system
        let path = UIBezierPath()
        if let firstVertex = transformedVertices.first {
            let adjustedFirst = CGPoint(
                x: firstVertex.x,
                y: -firstVertex.y  // Flip Y for SpriteKit
            )
            path.move(to: adjustedFirst)
            
            for vertex in transformedVertices.dropFirst() {
                let adjustedVertex = CGPoint(
                    x: vertex.x,
                    y: -vertex.y  // Flip Y for SpriteKit
                )
                path.addLine(to: adjustedVertex)
            }
            path.close()
        }
        
        let shape = SKShapeNode(path: path.cgPath)
        shape.fillColor = SKColor.systemGray
        shape.alpha = targetAlpha
        shape.strokeColor = SKColor.darkGray
        shape.lineWidth = 1.0
        shape.position = CGPoint.zero
        shape.name = "target_\(target.pieceType.rawValue)"
        
        // Store the actual center position for validation
        shape.userData = ["centerX": centerX, "centerY": -centerY]  // Store with flipped Y
        
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
            
            // Random initial rotation - like pieces dumped on a table
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
        
        // Check rotation dial UI only (other UI is in SwiftUI toolbar now)
        for node in nodes {
            if let parent = node.parent {
                if parent.name == "closeRotationDial" || node.name == "closeRotationDial" {
                    hideRotationDial(cancel: true)
                    return
                } else if parent.name == "saveRotationDial" || node.name == "saveRotationDial" {
                    hideRotationDial(cancel: false)
                    return
                } else if parent.name == "flipPiece" || node.name == "flipPiece" {
                    // Flip the piece that's currently being rotated
                    if rotationDial != nil, let piece = selectedPiece {
                        piece.flip()
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    return
                }
            }
        }
        
        // Check if we tapped a movable piece (not already completed)
        for node in nodes {
            if let piece = node as? PuzzlePieceNode,
               let pieceType = piece.pieceType,
               !completedPieces.contains(pieceType.rawValue),
               !piece.isCompleted {  // Double check it's not completed
                selectedPiece = piece
                piece.isSelected = true
                
                // Bring to front
                piece.zPosition = 1000
                
                // Store tap info to detect tap vs drag
                pendingRotationPiece = piece
                tapStartTime = CACurrentMediaTime()
                tapStartLocation = location
                
                // Setup for potential drag
                initialTouchAngle = atan2(location.y - piece.position.y,
                                        location.x - piece.position.x)
                initialPieceRotation = piece.zRotation
                isRotating = false
                
                // No scaling - just bring to front
                
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Check if we're rotating with the dial
        if isShowingRotationDial, let dial = rotationDial {
            // Calculate angle from dial center to touch point
            let dialPos = dial.position
            let angle = atan2(location.y - dialPos.y, location.x - dialPos.x)
            dial.updateRotation(to: angle)
            return
        }
        
        // Normal piece dragging
        guard let selected = selectedPiece else { return }
        
        // Cancel pending rotation if we're dragging
        if pendingRotationPiece != nil {
            let dragDistance = hypot(location.x - tapStartLocation.x, location.y - tapStartLocation.y)
            if dragDistance > 10 {  // Threshold for drag detection
                pendingRotationPiece = nil  // Cancel rotation dial
            }
        }
        
        // Drag the piece
        let previousLocation = touch.previousLocation(in: self)
        let deltaX = location.x - previousLocation.x
        let deltaY = location.y - previousLocation.y
        selected.position.x += deltaX
        selected.position.y += deltaY
        
        // Check for snap preview
        checkSnapPreview(for: selected)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // If we're showing the rotation dial, don't process normal touch ended
        if isShowingRotationDial {
            return
        }
        
        // Check if this was a tap (not a drag)
        if let pendingPiece = pendingRotationPiece {
            let dragDistance = hypot(location.x - tapStartLocation.x, location.y - tapStartLocation.y)
            let tapDuration = CACurrentMediaTime() - tapStartTime
            
            // If it was a short tap without much movement, show rotation dial
            if dragDistance < 10 && tapDuration < 0.3 && !isShowingRotationDial {
                showRotationDial(for: pendingPiece)
            }
            pendingRotationPiece = nil
        }
        
        guard let selected = selectedPiece else { return }
        
        selected.isSelected = false
        
        // Check if close enough to snap
        if let pieceType = selected.pieceType,
           let target = targetPieces[pieceType.rawValue],
           let targetData = puzzle?.targetPieces.first(where: { $0.pieceType == pieceType }) {
            
            // Get the actual center of the target piece from userData
            let centerX = target.userData?["centerX"] as? CGFloat ?? 0
            let centerY = target.userData?["centerY"] as? CGFloat ?? 0
            
            // Calculate world position
            let targetWorldPos = CGPoint(
                x: centerX + puzzleLayer.position.x,
                y: centerY + puzzleLayer.position.y
            )
            
            let distance = hypot(selected.position.x - targetWorldPos.x,
                               selected.position.y - targetWorldPos.y)
            
            // Check rotation from the transform matrix
            // IMPORTANT: Negate the rotation because we flip Y for SpriteKit coordinate system
            let targetRotation = -atan2(targetData.transform.b, targetData.transform.a)
            var rotationDiff = selected.zRotation - targetRotation
            
            // Normalize rotation difference to [-π, π] range
            while rotationDiff > .pi { rotationDiff -= 2 * .pi }
            while rotationDiff < -.pi { rotationDiff += 2 * .pi }
            
            // Check if rotation matches within tolerance
            var rotationMatches = abs(rotationDiff) < (rotationSnapTolerance * .pi / 180)
            
            // For triangular pieces, also check 180° rotated position (2-fold symmetry)
            // Right triangles look the same when rotated 180°
            if !rotationMatches && (pieceType == .largeTriangle1 || pieceType == .largeTriangle2 || 
                                    pieceType == .smallTriangle1 || pieceType == .smallTriangle2 || 
                                    pieceType == .mediumTriangle) {
                // Check if it matches when rotated 180°
                let alternateRotationDiff = abs(abs(rotationDiff) - .pi)
                rotationMatches = alternateRotationDiff < (rotationSnapTolerance * .pi / 180)
            }
            
            // Check flip state from transform matrix scale
            // If the transform has negative determinant, it's flipped
            let targetDeterminant = targetData.transform.a * targetData.transform.d - targetData.transform.b * targetData.transform.c
            let targetIsFlipped = targetDeterminant < 0
            let flipMatches = selected.isFlipped == targetIsFlipped
            
            print("Piece \(pieceType.rawValue): Validation")
            print("  Distance: \(distance) < \(snapDistance)? \(distance < snapDistance)")
            print("  Rotation diff: \(abs(rotationDiff) * 180 / .pi)° < \(rotationSnapTolerance)°? \(rotationMatches)")
            print("  Flip: piece=\(selected.isFlipped), target=\(targetIsFlipped), matches? \(flipMatches)")
            print("  Target rotation: \(targetRotation * 180 / .pi)°, Piece rotation: \(selected.zRotation * 180 / .pi)°")
            
            // All three must match for validation
            if distance < snapDistance && rotationMatches && flipMatches {
                // Lock piece in place (don't move it)
                lockPieceInPlace(piece: selected)
            } else {
                // Return original z-position
                selected.zPosition = CGFloat(availablePieces.count)
                
                // Show nudge about what's wrong
                if distance < snapDistance {
                    // Position is good but orientation is wrong - show nudge
                    showOrientationNudge(for: selected, flipNeeded: !flipMatches, rotationNeeded: !rotationMatches)
                }
            }
        }
        
        selectedPiece = nil
        isRotating = false
    }
    
    // MARK: - Snap and Completion
    
    private func checkSnapPreview(for piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType,
              let target = targetPieces[pieceType.rawValue],
              let targetData = puzzle?.targetPieces.first(where: { $0.pieceType == pieceType }) else { return }
        
        // Get the actual center of the target piece from userData
        let centerX = target.userData?["centerX"] as? CGFloat ?? 0
        let centerY = target.userData?["centerY"] as? CGFloat ?? 0
        
        // Calculate world position
        let targetWorldPos = CGPoint(
            x: centerX + puzzleLayer.position.x,
            y: centerY + puzzleLayer.position.y
        )
        
        let distance = hypot(piece.position.x - targetWorldPos.x,
                           piece.position.y - targetWorldPos.y)
        
        if distance < snapDistance * 1.5 {
            // Check rotation (same logic as validation)
            let targetRotation = -atan2(targetData.transform.b, targetData.transform.a)
            var rotationDiff = piece.zRotation - targetRotation
            
            // Normalize rotation difference to [-π, π] range
            while rotationDiff > .pi { rotationDiff -= 2 * .pi }
            while rotationDiff < -.pi { rotationDiff += 2 * .pi }
            
            // Check if rotation matches within tolerance
            var rotationCorrect = abs(rotationDiff) < (rotationSnapTolerance * .pi / 180)
            
            // For triangular pieces, also check 180° rotated position
            if !rotationCorrect && (pieceType == .largeTriangle1 || pieceType == .largeTriangle2 || 
                                    pieceType == .smallTriangle1 || pieceType == .smallTriangle2 || 
                                    pieceType == .mediumTriangle) {
                let alternateRotationDiff = abs(abs(rotationDiff) - .pi)
                rotationCorrect = alternateRotationDiff < (rotationSnapTolerance * .pi / 180)
            }
            
            // Check flip state
            let targetDeterminant = targetData.transform.a * targetData.transform.d - targetData.transform.b * targetData.transform.c
            let targetIsFlipped = targetDeterminant < 0
            let flipCorrect = piece.isFlipped == targetIsFlipped
            
            // Show snap preview with color based on both rotation and flip
            let orientationCorrect = rotationCorrect && flipCorrect
            target.alpha = 0.5
            target.strokeColor = orientationCorrect ? SKColor.systemGreen : SKColor.systemOrange
            target.lineWidth = 2.0
        } else {
            // Reset preview
            target.alpha = targetAlpha
            target.strokeColor = SKColor.darkGray
            target.lineWidth = 1.0
        }
    }
    
    private func lockPieceInPlace(piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType else { return }
        
        // DON'T MOVE THE PIECE - just lock it where it is
        // Mark as completed
        completedPieces.insert(pieceType.rawValue)
        piece.isCompleted = true
        piece.zPosition = 10 // Above unplaced pieces but below selected
        
        // Make it non-interactive (can't be dragged anymore)
        piece.isUserInteractionEnabled = false
        
        // Hide the target silhouette with fade animation
        if let target = targetPieces[pieceType.rawValue] {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()
            target.run(SKAction.sequence([fadeOut, remove]))
        }
        
        // Visual feedback for correct placement
        showCorrectPlacementFeedback(for: piece)
        
        // Celebration effect at current position
        showCompletionEffect(at: piece.position)
        
        // Update progress immediately
        let progress = Double(completedPieces.count) / Double(puzzle?.targetPieces.count ?? 1)
        updateProgress(progress)
        
        // Notify delegate
        onPieceCompleted?(pieceType.rawValue)
        
        // Check if puzzle is complete
        checkPuzzleCompletion()
    }
    
    private func checkPuzzleCompletion() {
        guard let puzzle = puzzle else { return }
        
        if completedPieces.count == puzzle.targetPieces.count {
            showPuzzleCompletionCelebration()
            onPuzzleCompleted?()
        }
    }
    
    // MARK: - Visual Effects
    
    private func showOrientationNudge(for piece: PuzzlePieceNode, flipNeeded: Bool, rotationNeeded: Bool) {
        // Create a speech bubble nudge
        let hintNode = SKNode()
        hintNode.position = CGPoint(x: piece.position.x, y: piece.position.y + 50)
        hintNode.zPosition = 400
        hintNode.alpha = 0 // Start invisible for animation
        hintNode.setScale(0.3) // Start small for bubble effect
        
        // Determine hint text
        let hintText: String
        if flipNeeded && rotationNeeded {
            hintText = "↔ Flip & Rotate"
        } else if flipNeeded {
            hintText = "↔ Flip"
        } else if rotationNeeded {
            hintText = "↻ Rotate"
        } else {
            return // No hint needed
        }
        
        // Create bubble background
        let bubble = createNudgeBubble(text: hintText)
        hintNode.addChild(bubble)
        
        effectsLayer.addChild(hintNode)
        
        // Bubble pop-up animation
        let popUp = SKAction.group([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        popUp.timingMode = .easeOut
        
        // Gentle floating animation
        let floatUp = SKAction.moveBy(x: 0, y: 10, duration: 0.8)
        floatUp.timingMode = .easeInEaseOut
        
        // Pop and disappear
        let wait = SKAction.wait(forDuration: 1.2)
        let popAway = SKAction.group([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.scale(to: 1.2, duration: 0.2)
        ])
        let remove = SKAction.removeFromParent()
        
        // Run the complete animation sequence
        hintNode.run(SKAction.sequence([
            popUp,
            SKAction.group([floatUp, wait]),
            popAway,
            remove
        ]))
    }
    
    private func createNudgeBubble(text: String) -> SKNode {
        let container = SKNode()
        
        // Create the label first to measure its size
        let label = SKLabelNode(text: text)
        label.fontSize = 14
        label.fontName = "Helvetica-Bold"
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        
        // Create bubble shape with padding
        let padding: CGFloat = 12
        let bubbleWidth = label.frame.width + padding * 2
        let bubbleHeight: CGFloat = 28
        let cornerRadius: CGFloat = bubbleHeight / 2
        
        // Create rounded rectangle for bubble
        let bubblePath = UIBezierPath(roundedRect: CGRect(x: -bubbleWidth/2, y: -bubbleHeight/2, 
                                                          width: bubbleWidth, height: bubbleHeight),
                                      cornerRadius: cornerRadius)
        
        // Add a small tail to the bubble pointing down
        bubblePath.move(to: CGPoint(x: -5, y: -bubbleHeight/2))
        bubblePath.addLine(to: CGPoint(x: 0, y: -bubbleHeight/2 - 8))
        bubblePath.addLine(to: CGPoint(x: 5, y: -bubbleHeight/2))
        
        let bubble = SKShapeNode(path: bubblePath.cgPath)
        bubble.fillColor = SKColor.systemOrange
        bubble.strokeColor = SKColor.systemOrange.darker(by: 20)
        bubble.lineWidth = 1.5
        
        // Add subtle shadow
        let shadow = SKShapeNode(path: bubblePath.cgPath)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        
        container.addChild(shadow)
        container.addChild(bubble)
        container.addChild(label)
        
        return container
    }
    
    private func showCorrectPlacementFeedback(for piece: PuzzlePieceNode) {
        // Create a green checkmark that appears and fades
        let checkmark = SKLabelNode(text: "✓")
        checkmark.fontSize = 40
        checkmark.fontColor = .systemGreen
        checkmark.position = piece.position
        checkmark.zPosition = 300
        effectsLayer.addChild(checkmark)
        
        // Animate the checkmark
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.2)
        let wait = SKAction.wait(forDuration: 0.3)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        checkmark.run(SKAction.sequence([scaleUp, wait, fadeOut, remove]))
        
        // Also flash the piece in green
        if let shape = piece.children.first as? SKShapeNode {
            let originalColor = shape.fillColor
            let flashGreen = SKAction.run { shape.fillColor = .systemGreen }
            let wait = SKAction.wait(forDuration: 0.2)
            let restoreColor = SKAction.run { shape.fillColor = originalColor }
            shape.run(SKAction.sequence([flashGreen, wait, restoreColor]))
        }
        
        // Haptic feedback for successful placement
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
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
    
    // MARK: - UI Elements (Deprecated - UI now in SwiftUI toolbar)
    
    func setupUIElements(timerText: String, timerStarted: Bool, progress: Double, showHints: Bool) {
        // UI elements are now handled by SwiftUI toolbar
        // This method is kept for compatibility but does nothing
        self.showingHints = showHints
    }
    
    // UI creation methods removed - now handled by SwiftUI
    
    // Timer display removed - now in SwiftUI toolbar
    
    private func createTimerDisplay(text: String, started: Bool) {
        // Deprecated - timer is now in SwiftUI toolbar
        // Method kept for compatibility but does nothing
    }
    
    private func createProgressBar(progress: Double) {
        // Progress bar background
        let barWidth: CGFloat = 150
        let barHeight: CGFloat = 8
        
        let progressBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 4)
        progressBg.fillColor = SKColor.systemGray5
        progressBg.strokeColor = SKColor.clear
        // Position below safe area with extra padding for status bar
        progressBg.position = CGPoint(x: size.width - 100, y: size.height - safeAreaTop - 60)
        
        // Progress fill
        let fillWidth = barWidth * CGFloat(progress)
        if fillWidth > 0 {
            let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: barHeight), cornerRadius: 4)
            fill.fillColor = progress >= 1.0 ? SKColor.systemGreen : SKColor.systemBlue
            fill.strokeColor = SKColor.clear
            fill.position = CGPoint(x: -barWidth/2 + fillWidth/2, y: 0)
            progressBg.addChild(fill)
            self.progressFill = fill
        }
        
        self.progressBar = progressBg
        uiLayer.addChild(progressBg)
    }
    
    private func createHintsButton(isActive: Bool) {
        let buttonContainer = SKNode()
        
        // Button background
        let buttonBg = SKShapeNode(circleOfRadius: 20)
        buttonBg.fillColor = isActive ? SKColor.systemYellow : SKColor.systemGray3
        buttonBg.strokeColor = SKColor.clear
        buttonContainer.addChild(buttonBg)
        
        // Lightbulb icon (simplified)
        let icon = SKLabelNode(text: "💡")
        icon.fontSize = 20
        icon.position = CGPoint(x: 0, y: -7)
        buttonContainer.addChild(icon)
        
        buttonContainer.name = "hintsButton"
        // Position below other UI elements
        buttonContainer.position = CGPoint(x: size.width - 50, y: size.height - safeAreaTop - 120)
        
        self.hintsButton = buttonContainer
        uiLayer.addChild(buttonContainer)
    }
    
    func updateTimer(_ text: String, started: Bool) {
        // Timer is now in SwiftUI toolbar
    }
    
    func updateProgress(_ progress: Double) {
        // Progress bar is now in SwiftUI overlay
    }
    
    func updateHints(_ show: Bool) {
        self.showingHints = show
        
        // Update hints button appearance
        if let hintsButton = hintsButton?.children.first as? SKShapeNode {
            hintsButton.fillColor = show ? SKColor.systemYellow : SKColor.systemGray3
        }
        
        // Legacy hint system - show all targets
        if !show {
            // Hide all hints when turning off
            clearStructuredHint()
            for (pieceType, targetNode) in targetPieces {
                if !completedPieces.contains(pieceType) {
                    targetNode.alpha = targetAlpha
                    targetNode.strokeColor = SKColor.darkGray
                    targetNode.lineWidth = 1.0
                }
            }
        }
    }
    
    // MARK: - Structured Hint System
    
    private var hintGhostNode: SKNode?
    private var hintPathNode: SKShapeNode?
    private var currentHintAnimation: SKAction?
    
    func showStructuredHint(_ hint: TangramHintEngine.HintData) {
        clearStructuredHint()
        
        switch hint.hintType {
        case .nudge:
            showNudgeHint(hint)
        case .rotation(let degrees):
            showRotationHint(hint, degrees: degrees)
        case .flip:
            showFlipHint(hint)
        case .position(let from, let to):
            showPositionHint(hint, from: from, to: to)
        case .fullSolution:
            showFullSolutionHint(hint)
        }
    }
    
    private func clearStructuredHint() {
        hintGhostNode?.removeAllActions()
        hintGhostNode?.removeFromParent()
        hintGhostNode = nil
        
        hintPathNode?.removeAllActions()
        hintPathNode?.removeFromParent()
        hintPathNode = nil
    }
    
    private func createGhostPiece(for pieceType: TangramPieceType) -> SKNode {
        let container = SKNode()
        
        // Create shape from piece geometry
        let shape = createPieceShape(type: pieceType)
        shape.fillColor = SKColor.systemYellow.withAlphaComponent(0.3)
        shape.strokeColor = SKColor.systemYellow
        shape.lineWidth = 3  // Slightly thicker line for visibility instead of glow
        
        container.addChild(shape)
        return container
    }
    
    private func showNudgeHint(_ hint: TangramHintEngine.HintData) {
        // Find the actual piece and make it pulse
        if let piece = availablePieces[hint.targetPiece.rawValue] {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.3)
            ])
            // Create a glow effect using color blend
            let glow = SKAction.sequence([
                SKAction.colorize(with: .systemYellow, colorBlendFactor: 0.5, duration: 0.3),
                SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.3)
            ])
            piece.run(SKAction.repeat(SKAction.group([pulse, glow]), count: 3))
        }
    }
    
    private func showRotationHint(_ hint: TangramHintEngine.HintData, degrees: Double) {
        let ghost = createGhostPiece(for: hint.targetPiece)
        ghost.alpha = 0.3
        ghost.zPosition = 150
        
        // Position at current piece location or default
        if let currentPiece = availablePieces[hint.targetPiece.rawValue] {
            ghost.position = currentPiece.position
            ghost.zRotation = currentPiece.zRotation
        } else {
            ghost.position = CGPoint(x: size.width * 0.5, y: size.height * 0.3)
        }
        
        // Create rotation indicator
        let arc = createRotationArc(from: ghost.zRotation, to: CGFloat(degrees * .pi / 180))
        ghost.addChild(arc)
        
        // Animate rotation
        let fadeIn = SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        let wait = SKAction.wait(forDuration: 0.5)
        let rotate = SKAction.rotate(toAngle: CGFloat(degrees * .pi / 180), duration: 1.5)
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.5),
            SKAction.fadeAlpha(to: 0.3, duration: 0.5)
        ]))
        
        ghost.run(SKAction.sequence([fadeIn, wait, rotate, pulse]))
        effectsLayer.addChild(ghost)
        hintGhostNode = ghost
    }
    
    private func showFlipHint(_ hint: TangramHintEngine.HintData) {
        let ghost = createGhostPiece(for: hint.targetPiece)
        ghost.alpha = 0.3
        ghost.zPosition = 150
        
        // Position at current piece location
        if let currentPiece = availablePieces[hint.targetPiece.rawValue] {
            ghost.position = currentPiece.position
            ghost.zRotation = currentPiece.zRotation
        }
        
        // Show flip animation
        let fadeIn = SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        let flipAnimation = SKAction.scaleX(to: -1.0, duration: 0.8)
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.5),
            SKAction.fadeAlpha(to: 0.3, duration: 0.5)
        ]))
        
        ghost.run(SKAction.sequence([fadeIn, flipAnimation, pulse]))
        effectsLayer.addChild(ghost)
        hintGhostNode = ghost
    }
    
    private func showPositionHint(_ hint: TangramHintEngine.HintData, from: CGPoint, to: CGPoint) {
        // Create ghost at target position
        let targetGhost = createGhostPiece(for: hint.targetPiece)
        targetGhost.position = to
        targetGhost.alpha = 0.4
        targetGhost.zPosition = 100
        
        // Apply target rotation
        let targetRotation = -atan2(hint.targetTransform.b, hint.targetTransform.a)
        targetGhost.zRotation = targetRotation
        
        // Create animated path
        let path = UIBezierPath()
        path.move(to: from)
        
        // Curved path for visual appeal
        let controlPoint = CGPoint(
            x: (from.x + to.x) / 2,
            y: max(from.y, to.y) + 50
        )
        path.addQuadCurve(to: to, controlPoint: controlPoint)
        
        let pathNode = SKShapeNode(path: path.cgPath)
        pathNode.strokeColor = .systemYellow
        pathNode.lineWidth = 2
        pathNode.lineCap = .round
        pathNode.alpha = 0
        pathNode.zPosition = 99
        
        // Animate path drawing
        let fadeInPath = SKAction.fadeIn(withDuration: 0.3)
        pathNode.run(fadeInPath)
        
        // Pulse the target
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        targetGhost.run(pulse)
        
        effectsLayer.addChild(targetGhost)
        effectsLayer.addChild(pathNode)
        
        hintGhostNode = targetGhost
        hintPathNode = pathNode
    }
    
    private func showFullSolutionHint(_ hint: TangramHintEngine.HintData) {
        let ghost = createGhostPiece(for: hint.targetPiece)
        ghost.alpha = 0
        ghost.zPosition = 150
        
        var actions: [SKAction] = []
        
        // Build animation sequence from steps
        for (index, step) in hint.animationSteps.enumerated() {
            if index == 0 {
                actions.append(SKAction.fadeAlpha(to: 0.5, duration: 0.3))
                ghost.position = CGPoint(x: size.width * 0.5, y: size.height * 0.3)
            }
            
            // Create transform actions
            let moveAction = SKAction.move(to: CGPoint(x: step.transform.tx, y: step.transform.ty), duration: step.duration)
            let rotateAction = SKAction.rotate(toAngle: atan2(step.transform.b, step.transform.a), duration: step.duration)
            
            actions.append(SKAction.group([moveAction, rotateAction]))
            
            if index < hint.animationSteps.count - 1 {
                actions.append(SKAction.wait(forDuration: 0.3))
            }
        }
        
        // Final pulse
        actions.append(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.5),
            SKAction.fadeAlpha(to: 0.3, duration: 0.5)
        ])))
        
        ghost.run(SKAction.sequence(actions))
        effectsLayer.addChild(ghost)
        hintGhostNode = ghost
    }
    
    private func createRotationArc(from startAngle: CGFloat, to endAngle: CGFloat) -> SKShapeNode {
        let radius: CGFloat = 60
        let path = UIBezierPath(arcCenter: .zero,
                               radius: radius,
                               startAngle: startAngle,
                               endAngle: endAngle,
                               clockwise: endAngle > startAngle)
        
        let arc = SKShapeNode(path: path.cgPath)
        arc.strokeColor = .systemYellow
        arc.lineWidth = 2
        arc.lineCap = .round
        
        // Add arrow at end
        let arrowSize: CGFloat = 10
        let arrowAngle = endAngle + (endAngle > startAngle ? -0.2 : 0.2)
        let arrowTip = CGPoint(x: cos(endAngle) * radius, y: sin(endAngle) * radius)
        
        let arrowPath = UIBezierPath()
        arrowPath.move(to: arrowTip)
        arrowPath.addLine(to: CGPoint(
            x: arrowTip.x - cos(arrowAngle) * arrowSize,
            y: arrowTip.y - sin(arrowAngle) * arrowSize
        ))
        arrowPath.move(to: arrowTip)
        arrowPath.addLine(to: CGPoint(
            x: arrowTip.x - cos(arrowAngle - 0.5) * arrowSize,
            y: arrowTip.y - sin(arrowAngle - 0.5) * arrowSize
        ))
        
        let arrow = SKShapeNode(path: arrowPath.cgPath)
        arrow.strokeColor = .systemYellow
        arrow.lineWidth = 2
        arc.addChild(arrow)
        
        return arc
    }
    
    func updateCompletionState(_ isComplete: Bool) {
        if isComplete {
            // Replace back button with next button
            backButton?.removeFromParent()
            createNextButton()
        }
    }
    
    private func createNextButton() {
        let buttonContainer = SKNode()
        
        // Create button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 8)
        buttonBg.fillColor = SKColor.systemGreen
        buttonBg.strokeColor = SKColor.clear
        buttonContainer.addChild(buttonBg)
        
        // Add "Next" text
        let label = SKLabelNode(text: "Next")
        label.fontSize = 16
        label.fontName = "System-Medium"
        label.fontColor = SKColor.white
        label.position = CGPoint(x: -5, y: -6)
        buttonContainer.addChild(label)
        
        // Add arrow icon
        let arrow = SKLabelNode(text: "▶")
        arrow.fontSize = 20
        arrow.fontName = "System"
        arrow.fontColor = SKColor.white
        arrow.position = CGPoint(x: 25, y: -7)
        buttonContainer.addChild(arrow)
        
        buttonContainer.name = "nextButton"
        // Position below safe area with extra padding for status bar
        buttonContainer.position = CGPoint(x: 70, y: size.height - safeAreaTop - 60)
        
        self.nextButton = buttonContainer
        uiLayer.addChild(buttonContainer)
    }
    
    // MARK: - Helper Methods
    
    private func calculatePuzzleBounds(for pieces: [GamePuzzleData.TargetPiece]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in pieces {
            let vertices = TangramGameGeometry.normalizedVertices(for: piece.pieceType)
            let scaled = TangramGameGeometry.scaleVertices(vertices, by: TangramGameConstants.visualScale)
            let transformed = TangramGameGeometry.transformVertices(scaled, with: piece.transform)
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
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
    
    // MARK: - Rotation Dial
    
    private func showRotationDial(for piece: PuzzlePieceNode) {
        // Remove any existing dial
        hideRotationDial()
        
        // Keep the piece selected while rotating
        selectedPiece = piece
        piece.isSelected = true
        
        // Create new rotation dial
        rotationDial = RotationDialNode()
        rotationDial?.position = piece.position
        rotationDial?.zPosition = 2000
        rotationDial?.showForPiece(piece)
        
        if let dial = rotationDial {
            uiLayer.addChild(dial)
            isShowingRotationDial = true
        }
    }
    
    private func hideRotationDial(cancel: Bool = false) {
        if cancel, let dial = rotationDial {
            // Restore original rotation if canceling
            dial.restoreOriginalRotation()
        }
        
        // Deselect the piece
        if let selected = selectedPiece {
            selected.isSelected = false
            selectedPiece = nil
        }
        
        rotationDial?.removeFromParent()
        rotationDial = nil
        isShowingRotationDial = false
    }
}

// MARK: - Rotation Dial Node

class RotationDialNode: SKNode {
    private var dial: SKShapeNode!
    private var handle: SKShapeNode!
    private var angleLabel: SKLabelNode!
    private var targetPiece: PuzzlePieceNode?
    private var initialRotation: CGFloat = 0
    private var originalRotation: CGFloat = 0
    private var originalFlipState: Bool = false
    
    func showForPiece(_ piece: PuzzlePieceNode) {
        targetPiece = piece
        initialRotation = piece.zRotation
        originalRotation = piece.zRotation  // Store original for cancel
        originalFlipState = piece.isFlipped  // Store original flip state
        
        // Create dial circle
        dial = SKShapeNode(circleOfRadius: 80)
        dial.strokeColor = .systemBlue
        dial.lineWidth = 3
        dial.fillColor = .clear
        dial.alpha = 0.8
        addChild(dial)
        
        // Add angle markers every 45°
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let marker = SKShapeNode(circleOfRadius: 3)
            marker.fillColor = .white
            marker.strokeColor = .systemBlue
            marker.position = CGPoint(
                x: cos(angle) * 80,
                y: sin(angle) * 80
            )
            dial.addChild(marker)
            
            // Add labels at 0°, 90°, 180°, 270°
            if i % 2 == 0 {
                let label = SKLabelNode(text: "\(i * 45)°")
                label.fontSize = 10
                label.fontColor = .systemBlue
                label.position = CGPoint(
                    x: cos(angle) * 95,
                    y: sin(angle) * 95 - 5
                )
                dial.addChild(label)
            }
        }
        
        // Create rotation handle
        handle = SKShapeNode(circleOfRadius: 12)
        handle.fillColor = .systemBlue
        handle.strokeColor = .white
        handle.lineWidth = 2
        handle.position = CGPoint(
            x: cos(initialRotation) * 80,
            y: sin(initialRotation) * 80
        )
        handle.zPosition = 10
        addChild(handle)
        
        // Add current angle display
        angleLabel = SKLabelNode(text: "\(Int(initialRotation * 180 / .pi))°")
        angleLabel.fontSize = 16
        angleLabel.fontColor = .systemBlue
        angleLabel.fontName = "System-Bold"
        angleLabel.position = CGPoint(x: 0, y: -110)
        addChild(angleLabel)
        
        // Add close button (cancel)
        let closeButton = SKShapeNode(circleOfRadius: 15)
        closeButton.fillColor = .systemRed
        closeButton.strokeColor = .white
        closeButton.lineWidth = 2
        closeButton.position = CGPoint(x: 60, y: 60)
        closeButton.name = "closeRotationDial"
        
        let xLabel = SKLabelNode(text: "✕")
        xLabel.fontSize = 16
        xLabel.fontColor = .white
        xLabel.position = CGPoint(x: 0, y: -5)
        xLabel.name = "closeRotationDial"
        closeButton.addChild(xLabel)
        
        addChild(closeButton)
        
        // Add save button (confirm)
        let saveButton = SKShapeNode(circleOfRadius: 15)
        saveButton.fillColor = .systemGreen
        saveButton.strokeColor = .white
        saveButton.lineWidth = 2
        saveButton.position = CGPoint(x: -60, y: 60)
        saveButton.name = "saveRotationDial"
        
        let checkLabel = SKLabelNode(text: "✓")
        checkLabel.fontSize = 16
        checkLabel.fontColor = .white
        checkLabel.position = CGPoint(x: 0, y: -5)
        checkLabel.name = "saveRotationDial"
        saveButton.addChild(checkLabel)
        
        addChild(saveButton)
        
        // Add center button (also saves)
        let centerButton = SKShapeNode(circleOfRadius: 25)
        centerButton.fillColor = .systemBlue.withAlphaComponent(0.3)
        centerButton.strokeColor = .systemBlue
        centerButton.lineWidth = 2
        centerButton.position = CGPoint.zero
        centerButton.name = "saveRotationDial"
        centerButton.zPosition = 5
        
        let saveIcon = SKLabelNode(text: "✓")
        saveIcon.fontSize = 20
        saveIcon.fontColor = .systemBlue
        saveIcon.position = CGPoint(x: 0, y: -7)
        saveIcon.name = "saveRotationDial"
        centerButton.addChild(saveIcon)
        
        addChild(centerButton)
        
        // Add flip button at the bottom
        let flipButton = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 15)
        flipButton.fillColor = .systemPurple
        flipButton.strokeColor = .white
        flipButton.lineWidth = 2
        flipButton.position = CGPoint(x: 0, y: -120)
        flipButton.name = "flipPiece"
        
        let flipLabel = SKLabelNode(text: "↔ Flip")
        flipLabel.fontSize = 14
        flipLabel.fontColor = .white
        flipLabel.position = CGPoint(x: 0, y: -5)
        flipLabel.name = "flipPiece"
        flipButton.addChild(flipLabel)
        
        addChild(flipButton)
    }
    
    func updateRotation(to angle: CGFloat) {
        guard let piece = targetPiece else { return }
        
        // Update piece rotation
        piece.zRotation = angle
        
        // Update handle position
        handle.position = CGPoint(
            x: cos(angle) * 80,
            y: sin(angle) * 80
        )
        
        // Update angle label
        var degrees = Int(angle * 180 / .pi)
        while degrees < 0 { degrees += 360 }
        while degrees >= 360 { degrees -= 360 }
        angleLabel.text = "\(degrees)°"
    }
    
    func restoreOriginalRotation() {
        // Restore the piece to its original rotation and flip state if canceling
        if let piece = targetPiece {
            piece.zRotation = originalRotation
            // Restore original flip state
            if piece.isFlipped != originalFlipState {
                piece.flip()  // This will toggle it back to original state
            }
        }
    }
}

// MARK: - Puzzle Piece Node

class PuzzlePieceNode: SKNode {
    var pieceType: TangramPieceType?
    var isSelected: Bool = false
    var isCompleted: Bool = false
    var isFlipped: Bool = false  // Track if piece is flipped
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
    
    func flip() {
        // Flip the piece horizontally
        isFlipped = !isFlipped
        
        // Apply horizontal flip using xScale
        if isFlipped {
            xScale = -1.0
        } else {
            xScale = 1.0
        }
        
        // Visual feedback
        let flipAnimation = SKAction.sequence([
            SKAction.scaleX(to: 0.1, duration: 0.15),
            SKAction.scaleX(to: isFlipped ? -1.0 : 1.0, duration: 0.15)
        ])
        run(flipAnimation)
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