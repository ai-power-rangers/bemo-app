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
    var onPieceCompleted: ((String, Bool) -> Void)?  // pieceType and isFlipped
    var onPuzzleCompleted: (() -> Void)?
    var onBackPressed: (() -> Void)?
    var onNextPressed: (() -> Void)?
    var onStartTimer: (() -> Void)?
    var onToggleHints: (() -> Void)?
    var safeAreaTop: CGFloat = 0
    
    // MARK: - Services
    
    private let gameplayService = TangramGameplayService()
    private let positioningService = TangramPiecePositioningService()
    
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
    // Use centralized validation constants
    private var snapDistance: CGFloat { TangramGameConstants.Validation.positionTolerance }
    private var rotationSnapTolerance: CGFloat { TangramGameConstants.Validation.rotationTolerance }
    
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
    
    // Rotation dial
    private var rotationDial: TangramRotationDialNode?
    private var isShowingRotationDial: Bool = false
    private var pendingRotationPiece: PuzzlePieceNode?
    private var tapStartTime: TimeInterval = 0
    private var tapStartLocation: CGPoint = .zero
    
    // Renderer components
    private lazy var hintRenderer = TangramHintRenderer(effectsLayer: effectsLayer, puzzleLayer: puzzleLayer, scene: self)
    private lazy var effectsRenderer = TangramEffectsRenderer(effectsLayer: effectsLayer, scene: self)
    
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
        
        // Add layers in order with explicit z-positions
        backgroundLayer.zPosition = 0
        addChild(backgroundLayer)
        
        puzzleLayer.zPosition = 1
        addChild(puzzleLayer)
        
        piecesLayer.zPosition = 2
        addChild(piecesLayer)
        
        effectsLayer.zPosition = 10  // High z-position for hints and effects
        addChild(effectsLayer)
        
        uiLayer.zPosition = 100  // UI on top
        addChild(uiLayer)
        
        // Use gameplay service for layout calculations
        let layout = gameplayService.calculatePuzzleLayout(
            sceneSize: size,
            safeAreaTop: safeAreaTop
        )
        puzzleAreaHeight = layout.puzzleAreaHeight
        piecesAreaHeight = layout.piecesAreaHeight
        puzzleCenter = layout.puzzleCenter
        
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
        
        // Create shape with vertices CENTERED around origin
        // The shape should be at origin, then positioned at the actual location
        let path = UIBezierPath()
        if let firstVertex = transformedVertices.first {
            // Center the vertices around (0,0) by subtracting the center
            let adjustedFirst = CGPoint(
                x: firstVertex.x - centerX,
                y: -(firstVertex.y - centerY)  // Flip Y for SpriteKit after centering
            )
            path.move(to: adjustedFirst)
            
            for vertex in transformedVertices.dropFirst() {
                let adjustedVertex = CGPoint(
                    x: vertex.x - centerX,
                    y: -(vertex.y - centerY)  // Flip Y for SpriteKit after centering
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
        
        // Now position the shape at the actual center location
        // The center is already flipped for SpriteKit
        shape.position = CGPoint(x: centerX, y: -centerY)
        shape.name = "target_\(target.pieceType.rawValue)"
        
        // Store the actual center position for validation (in puzzleLayer coordinates)
        shape.userData = ["centerX": centerX, "centerY": -centerY]
        
        #if DEBUG
        print("DEBUG: Target piece \(target.pieceType.rawValue)")
        print("  Transform: tx=\(target.transform.tx), ty=\(target.transform.ty)")
        print("  Calculated center: (\(centerX), \(-centerY))")
        print("  Shape position in puzzleLayer: \(shape.position)")
        print("  PuzzleLayer position: \(puzzleLayer.position)")
        #endif
        
        targetPieces[target.pieceType.rawValue] = shape
        puzzleLayer.addChild(shape)
    }
    
    private func createAvailablePieces(from targets: [GamePuzzleData.TargetPiece]) {
        let pieceTypes = targets.map { $0.pieceType }
        
        // Define safe bounds for piece placement
        let pieceSize: CGFloat = 80  // Max size of largest piece (with rotation)
        let margin: CGFloat = 40  // Extra margin from edges
        let minX = pieceSize + margin
        let maxX = size.width - pieceSize - margin
        let minY = pieceSize + margin  // Bottom safe area
        let maxY = size.height * 0.35  // Keep pieces in bottom 35% of screen
        
        // Create a scattered layout that keeps pieces on screen
        for (index, pieceType) in pieceTypes.enumerated() {
            let piece = PuzzlePieceNode(pieceType: pieceType)
            
            // Distribute pieces in a grid-like pattern with randomization
            let cols = 3  // 3 columns for better distribution
            let rows = 3  // Up to 3 rows
            let col = index % cols
            let row = index / cols
            
            // Calculate base position within safe bounds
            let xRange = maxX - minX
            let yRange = maxY - minY
            
            let baseX = minX + (xRange / CGFloat(cols)) * (CGFloat(col) + 0.5)
            let baseY = minY + (yRange / CGFloat(rows)) * (CGFloat(row) + 0.5)
            
            // Add random offset but keep within bounds
            let randomOffsetX = CGFloat.random(in: -30...30)
            let randomOffsetY = CGFloat.random(in: -30...30)
            
            piece.position = CGPoint(
                x: min(maxX, max(minX, baseX + randomOffsetX)),
                y: min(maxY, max(minY, baseY + randomOffsetY))
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
            // Check node itself first
            if node.name == "flipPiece" {
                // Flip the piece that's currently being rotated
                print("DEBUG: Flip button tapped (direct node)!")
                print("DEBUG: rotationDial exists: \(rotationDial != nil)")
                print("DEBUG: selectedPiece exists: \(selectedPiece != nil)")
                if let piece = selectedPiece {
                    print("DEBUG: selectedPiece type: \(piece.pieceType?.rawValue ?? "nil")")
                }
                
                if rotationDial != nil, let piece = selectedPiece {
                    print("DEBUG: Flipping piece - current isFlipped: \(piece.isFlipped)")
                    print("DEBUG: Piece type: \(piece.pieceType?.rawValue ?? "unknown")")
                    piece.flip()
                    print("DEBUG: After flip - isFlipped: \(piece.isFlipped)")
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                } else {
                    print("DEBUG: Cannot flip - no rotation dial or selected piece!")
                    // Try to find the piece being rotated another way
                    if rotationDial != nil {
                        print("DEBUG: Rotation dial exists but no selected piece")
                    }
                }
                return
            }
            
            // Then check parent relationships
            if let parent = node.parent {
                if parent.name == "closeRotationDial" || node.name == "closeRotationDial" {
                    hideRotationDial(cancel: true)
                    return
                } else if parent.name == "saveRotationDial" || node.name == "saveRotationDial" {
                    hideRotationDial(cancel: false)
                    return
                } else if parent.name == "flipPiece" {
                    // Flip the piece that's currently being rotated
                    print("DEBUG: Flip button tapped (parent)!")
                    print("DEBUG: rotationDial exists: \(rotationDial != nil)")
                    print("DEBUG: selectedPiece exists: \(selectedPiece != nil)")
                    if let piece = selectedPiece {
                        print("DEBUG: selectedPiece type: \(piece.pieceType?.rawValue ?? "nil")")
                    }
                    
                    if rotationDial != nil, let piece = selectedPiece {
                        print("DEBUG: Flipping piece - current isFlipped: \(piece.isFlipped)")
                        print("DEBUG: Piece type: \(piece.pieceType?.rawValue ?? "unknown")")
                        piece.flip()
                        print("DEBUG: After flip - isFlipped: \(piece.isFlipped)")
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } else {
                        print("DEBUG: Cannot flip - no rotation dial or selected piece!")
                        // Try to find the piece being rotated another way
                        if rotationDial != nil {
                            print("DEBUG: Rotation dial exists but no selected piece")
                        }
                    }
                    return
                }
            }
        }
        
        // Check if we tapped a movable piece (not already completed)
        // BUT don't select a new piece if rotation dial is showing
        if !isShowingRotationDial {
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
        print("DEBUG: touchesEnded - checking validation")
        if let pieceType = selected.pieceType,
           let target = targetPieces[pieceType.rawValue],
           let targetData = puzzle?.targetPieces.first(where: { $0.pieceType == pieceType }) {
            print("DEBUG: Found target for piece \(pieceType.rawValue)")
            
            // Get the actual world position of the target
            // The shape is positioned at its center within puzzleLayer
            // We need to convert this to world coordinates
            let targetWorldPos = target.convert(CGPoint.zero, to: self)
            
            // Use gameplay service for validation
            let validation = gameplayService.validatePiecePlacement(
                piecePosition: selected.position,
                pieceRotation: selected.zRotation,
                pieceType: pieceType,
                isFlipped: selected.isFlipped,
                targetTransform: targetData.transform,
                targetWorldPos: targetWorldPos
            )
            
            #if DEBUG
            let dist = hypot(selected.position.x - targetWorldPos.x, selected.position.y - targetWorldPos.y)
            print("\n🔍 Piece \(pieceType.rawValue): Final Validation Check")
            print("  ✅ Position valid: \(validation.positionValid) (distance: \(dist)/\(TangramGameConstants.Validation.positionTolerance))")
            print("  ✅ Rotation valid: \(validation.rotationValid)")
            print("  ✅ Flip valid: \(validation.flipValid)")
            print("  📍 Piece position: \(selected.position)")
            print("  🎯 Target world pos: \(targetWorldPos)")
            print("  📏 Distance: \(dist)")
            
            // Extra debug for triangles
            if pieceType.rawValue.contains("Triangle") {
                print("  🔺 Triangle Debug for \(pieceType.rawValue):")
                print("    Target position in puzzleLayer: \(target.position)")
                print("    Puzzle layer pos: \(puzzleLayer.position)")
                print("    Calculated world pos: \(targetWorldPos)")
                print("    Target frame in scene: \(target.frame)")
                print("    Piece frame: \(selected.frame)")
                
                // Check if frames overlap even if centers don't match
                let targetFrame = target.frame
                let pieceFrame = selected.frame
                let frameIntersection = targetFrame.intersection(pieceFrame)
                let overlapRatio = frameIntersection.width * frameIntersection.height / (pieceFrame.width * pieceFrame.height)
                print("    Frame overlap ratio: \(overlapRatio)")
            }
            #endif
            
            // Check if piece should be locked
            if gameplayService.shouldLockPiece(validation: validation) {
                // Lock piece in place (don't move it)
                lockPieceInPlace(piece: selected)
                // Show success nudge
                effectsRenderer.showSuccessNudge(at: selected.position)
            } else {
                // Return original z-position
                selected.zPosition = CGFloat(availablePieces.count)
                
                // Show nudge about what's wrong
                if validation.positionValid && (!validation.rotationValid || !validation.flipValid) {
                    // Position is good but orientation is wrong - show nudge
                    effectsRenderer.updateAvailablePieces(availablePieces)
                    effectsRenderer.showOrientationNudge(for: selected, flipNeeded: !validation.flipValid, rotationNeeded: !validation.rotationValid)
                }
            }
        }
        
        // Only clear selectedPiece if we're not showing the rotation dial
        // The rotation dial needs selectedPiece to remain set for flip functionality
        if !isShowingRotationDial {
            selectedPiece = nil
        }
        isRotating = false
    }
    
    // MARK: - Snap and Completion
    
    private func checkSnapPreview(for piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType,
              let target = targetPieces[pieceType.rawValue],
              let targetData = puzzle?.targetPieces.first(where: { $0.pieceType == pieceType }) else { 
            print("DEBUG: checkSnapPreview guard failed")
            return 
        }
        
        // Get the actual world position of the target
        // The shape is positioned at its center within puzzleLayer
        // We need to convert this to world coordinates
        let targetWorldPos = target.convert(CGPoint.zero, to: self)
        
        // Use gameplay service for validation
        print("DEBUG: Calling validatePiecePlacement in checkSnapPreview")
        let validation = gameplayService.validatePiecePlacement(
            piecePosition: piece.position,
            pieceRotation: piece.zRotation,
            pieceType: pieceType,
            isFlipped: piece.isFlipped,
            targetTransform: targetData.transform,
            targetWorldPos: targetWorldPos
        )
        print("DEBUG: Validation result: pos=\(validation.positionValid), rot=\(validation.rotationValid), flip=\(validation.flipValid)")
        
        // Use positioning service for snap preview
        let snapStrength = positioningService.calculateSnapStrength(
            piecePosition: piece.position,
            targetPosition: targetWorldPos
        )
        
        let orientationCorrect = validation.rotationValid && validation.flipValid
        
        switch snapStrength {
        case .strong:
            target.alpha = snapStrength.alpha
            target.strokeColor = orientationCorrect ? snapStrength.color : SKColor.systemOrange
            target.lineWidth = snapStrength.lineWidth
        case .medium, .weak:
            target.alpha = snapStrength.alpha
            target.strokeColor = orientationCorrect ? snapStrength.color.withAlphaComponent(0.6) : SKColor.systemOrange.withAlphaComponent(0.6)
            target.lineWidth = snapStrength.lineWidth
        case .none:
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
        effectsRenderer.showCorrectPlacementFeedback(for: piece)
        
        // Celebration effect at current position
        effectsRenderer.showCompletionEffect(at: piece.position)
        
        // Update progress immediately
        let progress = Double(completedPieces.count) / Double(puzzle?.targetPieces.count ?? 1)
        updateProgress(progress)
        
        // Notify delegate with flip state
        onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
        
        // Check if puzzle is complete
        checkPuzzleCompletion()
    }
    
    private func checkPuzzleCompletion() {
        guard let puzzle = puzzle else { return }
        
        if completedPieces.count == puzzle.targetPieces.count {
            effectsRenderer.updateAvailablePieces(availablePieces)
            effectsRenderer.showPuzzleCompletionCelebration(availablePieces: availablePieces)
            onPuzzleCompleted?()
        }
    }
    
    // MARK: - Visual Effects
    
    // Methods below moved to TangramEffectsRenderer
    private func REMOVED_showOrientationNudge(for piece: PuzzlePieceNode, flipNeeded: Bool, rotationNeeded: Bool) {
        // Moved to TangramEffectsRenderer
    }
    
    private func REMOVED_showSuccessNudge(at position: CGPoint) {
        // Moved to TangramEffectsRenderer
    }
    
    private func REMOVED_createNudgeBubble(text: String) -> SKNode {
        // Moved to TangramEffectsRenderer
        return SKNode()
    }
    
    private func REMOVED_showCorrectPlacementFeedback(for piece: PuzzlePieceNode) {
        // Moved to TangramEffectsRenderer
    }
    
    private func REMOVED_showCompletionEffect(at position: CGPoint) {
        // Moved to TangramEffectsRenderer
    }
    
    private func REMOVED_showPuzzleCompletionCelebration() {
        // Moved to TangramEffectsRenderer
    }
    
    // MARK: - UI Elements (Deprecated - UI now in SwiftUI toolbar)
    
    func setupUIElements(timerText: String, timerStarted: Bool, progress: Double, showHints: Bool) {
        // UI elements are now handled by SwiftUI toolbar
        // This method is kept for compatibility but does nothing
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
    
    // MARK: - Structured Hint System
    
    func showStructuredHint(_ hint: TangramHintEngine.HintData) {
        // Show hint based on type
        let targetPosition = CGPoint(x: hint.targetTransform.tx, y: hint.targetTransform.ty)
        let targetRotation = atan2(hint.targetTransform.b, hint.targetTransform.a)
        
        switch hint.hintType {
        case .nudge:
            hintRenderer.showHint(for: hint.targetPiece, at: targetPosition, rotation: targetRotation)
        case .rotation:
            hintRenderer.showRotationHint(at: targetPosition, targetRotation: targetRotation)
        case .flip:
            hintRenderer.showFlipHint(at: targetPosition)
        case .position(let from, let to):
            hintRenderer.showMovementHint(from: from, to: to)
        case .fullSolution:
            hintRenderer.showHint(for: hint.targetPiece, at: targetPosition, rotation: targetRotation)
        }
    }
    
    private func clearStructuredHint() {
        hintRenderer.clearCurrentHint()
    }
    
    // Implementation has been moved to TangramHintRenderer
    
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
        shape.fillColor = TangramColors.Sprite.uiColor(for: type)
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
        rotationDial = TangramRotationDialNode()
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
    
    /// Extracts rotation angle from CGAffineTransform with robust floating-point handling
    /// Handles cases where sin/cos values have floating-point precision errors (e.g., 180° rotations)
}

// The TangramRotationDialNode class has been moved to TangramRotationDialNode.swift
// The PuzzlePieceNode class has been moved to PuzzlePieceNode.swift

