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
    var onBackPressed: (() -> Void)?
    var onNextPressed: (() -> Void)?
    var onStartTimer: (() -> Void)?
    var onToggleHints: (() -> Void)?
    
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
    private let snapDistance: CGFloat = 40.0
    private let rotationSnapTolerance: CGFloat = 15.0 // degrees
    
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
        
        // Calculate scale to fit the puzzle in the top area
        let targetAreaSize = CGSize(width: size.width * 0.8, height: size.height * 0.35)
        puzzleScale = min(
            targetAreaSize.width / puzzleBounds.width,
            targetAreaSize.height / puzzleBounds.height,
            0.5  // Don't make it too big
        )
        
        // Create target silhouettes with proper scaling and positioning
        for target in puzzle.targetPieces {
            createTargetPiece(target, puzzleBounds: puzzleBounds, scale: puzzleScale)
        }
        
        // Position the puzzle layer to center the target at the top of screen
        let centerX = size.width / 2
        let centerY = size.height * 0.75  // Top area
        puzzleLayer.position = CGPoint(x: centerX, y: centerY)
        
        // Create movable pieces at the bottom
        createAvailablePieces(from: puzzle.targetPieces)
    }
    
    private func createTargetPiece(_ target: GamePuzzleData.TargetPiece, puzzleBounds: CGRect, scale: CGFloat) {
        // Get transformed vertices for the target piece
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        let transformedVertices = TangramGameGeometry.transformVertices(scaledVertices, with: target.transform)
        
        // Create shape from transformed vertices, adjusted for display
        let path = UIBezierPath()
        if let firstVertex = transformedVertices.first {
            // Center the puzzle and apply display scale
            let adjustedFirst = CGPoint(
                x: (firstVertex.x - puzzleBounds.midX) * scale,
                y: -(firstVertex.y - puzzleBounds.midY) * scale  // Flip Y for SpriteKit
            )
            path.move(to: adjustedFirst)
            
            for vertex in transformedVertices.dropFirst() {
                let adjustedVertex = CGPoint(
                    x: (vertex.x - puzzleBounds.midX) * scale,
                    y: -(vertex.y - puzzleBounds.midY) * scale  // Flip Y for SpriteKit
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
        
        // Check UI elements first
        for node in nodes {
            if let parent = node.parent {
                // Check button presses
                if parent.name == "backButton" || node.name == "backButton" {
                    onBackPressed?()
                    return
                } else if parent.name == "nextButton" || node.name == "nextButton" {
                    onNextPressed?()
                    return
                } else if parent.name == "startTimer" || node.name == "startTimer" {
                    onStartTimer?()
                    return
                } else if parent.name == "hintsButton" || node.name == "hintsButton" {
                    onToggleHints?()
                    return
                } else if parent.name == "closeRotationDial" || node.name == "closeRotationDial" {
                    hideRotationDial()
                    return
                }
            }
        }
        
        // Check if we tapped a movable piece
        for node in nodes {
            if let piece = node as? PuzzlePieceNode,
               let pieceType = piece.pieceType,
               !completedPieces.contains(pieceType.rawValue) {
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
                
                // Visual feedback
                let scaleUp = SKAction.scale(to: 1.1, duration: 0.1)
                piece.run(scaleUp)
                
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
        
        // Return to normal scale
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        selected.run(scaleDown)
        
        // Check if close enough to snap
        if let pieceType = selected.pieceType {
            // Find the matching target piece
            let matchingTarget = puzzle?.targetPieces.first { $0.pieceType == pieceType }
            
            if let target = targetPieces[pieceType.rawValue],
               let targetData = matchingTarget {
                
                // Calculate the expected position for this piece
                let targetWorldPos = CGPoint(
                    x: (targetData.transform.tx - puzzleBounds.midX) * puzzleScale + puzzleLayer.position.x,
                    y: -(targetData.transform.ty - puzzleBounds.midY) * puzzleScale + puzzleLayer.position.y
                )
                
                let distance = hypot(selected.position.x - targetWorldPos.x,
                                   selected.position.y - targetWorldPos.y)
                
                // Get the correct rotation from the target data
                let targetRotation = atan2(-targetData.transform.b, targetData.transform.a)
                var rotationDiff = abs(selected.zRotation - targetRotation)
                
                // Normalize rotation difference
                while rotationDiff > .pi { rotationDiff = 2 * .pi - rotationDiff }
                
                if distance < snapDistance && rotationDiff < rotationSnapTolerance * .pi / 180 {
                    // Snap to position
                    snapToTarget(piece: selected, targetRotation: targetRotation, targetWorldPos: targetWorldPos)
                } else {
                    // Return original z-position
                    selected.zPosition = CGFloat(availablePieces.count)
                }
            }
        }
        
        selectedPiece = nil
        isRotating = false
    }
    
    // MARK: - Snap and Completion
    
    private func checkSnapPreview(for piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType,
              let target = targetPieces[pieceType.rawValue] else { return }
        
        // Find the matching target piece data
        let matchingTarget = puzzle?.targetPieces.first { $0.pieceType == pieceType }
        
        if let targetData = matchingTarget {
            // Calculate the expected position for this piece
            let targetWorldPos = CGPoint(
                x: (targetData.transform.tx - puzzleBounds.midX) * puzzleScale + puzzleLayer.position.x,
                y: -(targetData.transform.ty - puzzleBounds.midY) * puzzleScale + puzzleLayer.position.y
            )
            
            let distance = hypot(piece.position.x - targetWorldPos.x,
                               piece.position.y - targetWorldPos.y)
            
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
    }
    
    private func snapToTarget(piece: PuzzlePieceNode, targetRotation: CGFloat, targetWorldPos: CGPoint) {
        guard let pieceType = piece.pieceType else { return }
        
        // Snap animation to world position
        let snapMove = SKAction.move(to: targetWorldPos, duration: 0.2)
        let snapRotate = SKAction.rotate(toAngle: targetRotation, duration: 0.2, shortestUnitArc: true)
        let snapGroup = SKAction.group([snapMove, snapRotate])
        
        piece.run(snapGroup) {
            // Mark as completed
            self.completedPieces.insert(pieceType.rawValue)
            piece.isCompleted = true
            piece.zPosition = 10 // Above unplaced pieces but below selected
            
            // Hide the target
            if let target = self.targetPieces[pieceType.rawValue] {
                target.alpha = 0
            }
            
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
    
    // MARK: - UI Elements
    
    func setupUIElements(timerText: String, timerStarted: Bool, progress: Double, showHints: Bool) {
        // Clear existing UI
        uiLayer.removeAllChildren()
        
        // Create back button
        createBackButton()
        
        // Create timer display
        createTimerDisplay(text: timerText, started: timerStarted)
        
        // Create progress bar
        createProgressBar(progress: progress)
        
        // Create hints button if not showing completion
        if !completedPieces.isEmpty && completedPieces.count < (puzzle?.targetPieces.count ?? 0) {
            createHintsButton(isActive: showHints)
        }
        
        self.showingHints = showHints
    }
    
    private func createBackButton() {
        let buttonContainer = SKNode()
        
        // Create button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 8)
        buttonBg.fillColor = SKColor.systemBlue
        buttonBg.strokeColor = SKColor.clear
        buttonContainer.addChild(buttonBg)
        
        // Add chevron icon
        let chevron = SKLabelNode(text: "◀")
        chevron.fontSize = 20
        chevron.fontName = "System"
        chevron.fontColor = SKColor.white
        chevron.position = CGPoint(x: -25, y: -7)
        buttonContainer.addChild(chevron)
        
        // Add "Back" text
        let label = SKLabelNode(text: "Back")
        label.fontSize = 16
        label.fontName = "System-Medium"
        label.fontColor = SKColor.white
        label.position = CGPoint(x: 5, y: -6)
        buttonContainer.addChild(label)
        
        buttonContainer.name = "backButton"
        buttonContainer.position = CGPoint(x: 70, y: size.height - 60)
        
        self.backButton = buttonContainer
        uiLayer.addChild(buttonContainer)
    }
    
    private func createTimerDisplay(text: String, started: Bool) {
        // Timer container
        let timerContainer = SKNode()
        
        if started {
            // Show timer text
            let timer = SKLabelNode(text: text)
            timer.fontSize = 18
            timer.fontName = "Courier-Bold"
            timer.fontColor = SKColor.label
            timerContainer.addChild(timer)
            self.timerLabel = timer
        } else {
            // Show start button
            let startBg = SKShapeNode(rectOf: CGSize(width: 80, height: 32), cornerRadius: 6)
            startBg.fillColor = SKColor.systemGreen
            startBg.strokeColor = SKColor.clear
            
            let startLabel = SKLabelNode(text: "Start")
            startLabel.fontSize = 14
            startLabel.fontName = "System-Medium"
            startLabel.fontColor = SKColor.white
            startLabel.position = CGPoint(x: 0, y: -5)
            
            startBg.addChild(startLabel)
            timerContainer.addChild(startBg)
            timerContainer.name = "startTimer"
            self.startTimerButton = timerContainer
        }
        
        timerContainer.position = CGPoint(x: 200, y: size.height - 60)
        uiLayer.addChild(timerContainer)
    }
    
    private func createProgressBar(progress: Double) {
        // Progress bar background
        let barWidth: CGFloat = 150
        let barHeight: CGFloat = 8
        
        let progressBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 4)
        progressBg.fillColor = SKColor.systemGray5
        progressBg.strokeColor = SKColor.clear
        progressBg.position = CGPoint(x: size.width - 100, y: size.height - 60)
        
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
        buttonContainer.position = CGPoint(x: size.width - 50, y: size.height - 120)
        
        self.hintsButton = buttonContainer
        uiLayer.addChild(buttonContainer)
    }
    
    func updateTimer(_ text: String, started: Bool) {
        if let timer = timerLabel {
            timer.text = text
        } else if started {
            // Timer was started, recreate display
            if let startButton = startTimerButton {
                startButton.removeFromParent()
                self.startTimerButton = nil
            }
            createTimerDisplay(text: text, started: true)
        }
    }
    
    func updateProgress(_ progress: Double) {
        guard let progressBar = progressBar else { return }
        
        // Update fill
        progressFill?.removeFromParent()
        
        let barWidth: CGFloat = 150
        let barHeight: CGFloat = 8
        let fillWidth = barWidth * CGFloat(progress)
        
        if fillWidth > 0 {
            let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: barHeight), cornerRadius: 4)
            fill.fillColor = progress >= 1.0 ? SKColor.systemGreen : SKColor.systemBlue
            fill.strokeColor = SKColor.clear
            fill.position = CGPoint(x: -barWidth/2 + fillWidth/2, y: 0)
            progressBar.addChild(fill)
            self.progressFill = fill
        }
    }
    
    func updateHints(_ show: Bool) {
        self.showingHints = show
        
        // Update hints button appearance
        if let hintsButton = hintsButton?.children.first as? SKShapeNode {
            hintsButton.fillColor = show ? SKColor.systemYellow : SKColor.systemGray3
        }
        
        // Update target visibility for hints
        for (pieceType, targetNode) in targetPieces {
            if !completedPieces.contains(pieceType) {
                targetNode.alpha = show ? 0.5 : targetAlpha
                targetNode.strokeColor = show ? SKColor.systemBlue : SKColor.darkGray
                targetNode.lineWidth = show ? 2.0 : 1.0
            }
        }
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
        buttonContainer.position = CGPoint(x: 70, y: size.height - 60)
        
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
    
    private func hideRotationDial() {
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
    
    func showForPiece(_ piece: PuzzlePieceNode) {
        targetPiece = piece
        initialRotation = piece.zRotation
        
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
        
        // Add close button
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
        closeButton.addChild(xLabel)
        
        addChild(closeButton)
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