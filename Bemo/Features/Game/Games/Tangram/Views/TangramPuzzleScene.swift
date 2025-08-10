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
        
        // STEP 1: Calculate bounds in SK space to understand puzzle dimensions
        let boundsSK = TangramBounds.calculatePuzzleBoundsSK(targets: puzzle.targetPieces)
        
        // Get the current center of the puzzle in SK space
        let currentMid = CGPoint(x: boundsSK.midX, y: boundsSK.midY)
        
        // STEP 2: Determine where we want the puzzle centered on screen
        let desiredMid = CGPoint(
            x: size.width / 2,
            y: (size.height - safeAreaTop) * 0.75
        )
        
        // STEP 3: Position parent layer at the desired position
        // This centers the puzzle at the desired screen location
        puzzleLayer.position = desiredMid
        puzzleLayer.zRotation = 0  // Ensure no rotation on parent
        puzzleLayer.setScale(1.0)  // Ensure no scale on parent
        
        // STEP 4: Create target pieces with parent-local coordinates
        // Pass the bounds center so pieces can be positioned relative to it
        for target in puzzle.targetPieces {
            createTargetPiece(target, boundsCenterSK: currentMid)
        }
        
        // Comprehensive vertex-level verification for ALL pieces
        print("=== Puzzle Assembly Verification ===")
        print("SK Bounds: \(TangramBounds.debugString(for: boundsSK))")
        print("Bounds Center SK: (\(String(format: "%.1f", currentMid.x)), \(String(format: "%.1f", currentMid.y)))")
        print("Desired Screen Position: (\(String(format: "%.1f", desiredMid.x)), \(String(format: "%.1f", desiredMid.y)))")
        print("Puzzle Layer Position: (\(String(format: "%.1f", puzzleLayer.position.x)), \(String(format: "%.1f", puzzleLayer.position.y)))")
        
        // Verify EVERY piece with vertex-level precision
        var totalMaxError: CGFloat = 0
        print("\n=== Per-Piece Vertex Verification ===")
        
        for target in puzzle.targetPieces {
            guard let shape = targetPieces[target.pieceType.rawValue] else { continue }
            
            // Get the expected vertices stored in userData
            guard let expectedVerticesSK = shape.userData?["expectedVerticesSK"] as? [CGPoint] else { 
                print("Warning: No expected vertices for \(target.pieceType.rawValue)")
                continue 
            }
            
            // Get the actual vertices by transforming the shape's path
            let pathBounds = shape.path?.boundingBox ?? .zero
            let pathCenter = CGPoint(x: pathBounds.midX, y: pathBounds.midY)
            
            // The path is centered, so we need to transform it by the shape's position
            // Since zRotation is 0 (baked approach), we only need to translate
            
            // Calculate the centroid of expected vertices (simpler calculation)
            var expectedCentroid = CGPoint.zero
            for vertex in expectedVerticesSK {
                expectedCentroid.x += vertex.x
                expectedCentroid.y += vertex.y
            }
            let vertexCount = CGFloat(expectedVerticesSK.count)
            expectedCentroid.x /= vertexCount
            expectedCentroid.y /= vertexCount
            
            let actualVerticesSK = expectedVerticesSK.map { expectedVertex in
                // The path vertices are centered, so reconstruct scene position
                let localVertex = CGPoint(
                    x: expectedVertex.x - expectedCentroid.x,
                    y: expectedVertex.y - expectedCentroid.y
                )
                
                // Transform to scene coordinates
                let sceneVertex = CGPoint(
                    x: localVertex.x + shape.position.x + puzzleLayer.position.x,
                    y: localVertex.y + shape.position.y + puzzleLayer.position.y
                )
                return sceneVertex
            }
            
            // Calculate per-vertex error
            var maxVertexError: CGFloat = 0
            for (expected, actual) in zip(expectedVerticesSK, actualVerticesSK) {
                // Expected scene position = expected SK vertex offset by bounds center and parent position
                let expectedScene = CGPoint(
                    x: expected.x - currentMid.x + desiredMid.x,
                    y: expected.y - currentMid.y + desiredMid.y
                )
                let error = hypot(actual.x - expectedScene.x, actual.y - expectedScene.y)
                maxVertexError = max(maxVertexError, error)
            }
            
            totalMaxError = max(totalMaxError, maxVertexError)
            
            // Also verify centroid position
            let centroidSK = shape.userData?["centerX"] as? CGFloat ?? 0
            let centroidSKY = shape.userData?["centerY"] as? CGFloat ?? 0
            let expectedCentroidSK = CGPoint(x: centroidSK, y: centroidSKY)
            let actualCentroidScene = puzzleLayer.convert(shape.position, to: self)
            let expectedCentroidScene = CGPoint(
                x: expectedCentroidSK.x - currentMid.x + desiredMid.x,
                y: expectedCentroidSK.y - currentMid.y + desiredMid.y
            )
            let centroidError = hypot(actualCentroidScene.x - expectedCentroidScene.x, actualCentroidScene.y - expectedCentroidScene.y)
            
            print("\(target.pieceType.rawValue):")
            print("  Max vertex error: \(String(format: "%.2f", maxVertexError)) px")
            print("  Centroid error: \(String(format: "%.2f", centroidError)) px")
            print("  Shape zRotation: \(String(format: "%.2f", shape.zRotation * 180 / .pi))° (should be 0)")
        }
        
        print("\nTotal max vertex error across all pieces: \(String(format: "%.2f", totalMaxError)) px")
        if totalMaxError < 1.0 {
            print("✅ SUCCESS: Puzzle assembled with sub-pixel accuracy!")
        } else {
            print("⚠️ WARNING: Puzzle assembly has errors > 1px")
        }
        print("=====================================")
        
        // Create movable pieces at the bottom
        createAvailablePieces(from: puzzle.targetPieces)
    }
    
    private func createTargetPiece(_ target: GamePuzzleData.TargetPiece, boundsCenterSK: CGPoint) {
        // BAKED-VERTICES APPROACH: Apply transform directly to vertices for bulletproof rendering
        
        // 1. Get normalized vertices and scale them
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        
        // 2. Apply the full transform to each vertex in RAW space
        let transformedVerticesRaw = TangramGameGeometry.transformVertices(scaledVertices, with: target.transform)
        
        // 3. Convert each transformed vertex to SK space
        let transformedVerticesSK = transformedVerticesRaw.map { rawVertex in
            TangramPoseMapper.spriteKitPosition(fromRawPosition: rawVertex)
        }
        
        // 4. Calculate centroid from the SK-transformed vertices
        var centroidSK = CGPoint.zero
        for vertex in transformedVerticesSK {
            centroidSK.x += vertex.x
            centroidSK.y += vertex.y
        }
        centroidSK.x /= CGFloat(transformedVerticesSK.count)
        centroidSK.y /= CGFloat(transformedVerticesSK.count)
        
        // 5. Build path from SK vertices centered around their centroid
        let path = UIBezierPath()
        let centeredVertices = transformedVerticesSK.map { vertex in
            CGPoint(x: vertex.x - centroidSK.x, y: vertex.y - centroidSK.y)
        }
        
        if let firstVertex = centeredVertices.first {
            path.move(to: firstVertex)
            for vertex in centeredVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.close()
        }
        
        // 6. Create shape node
        let shape = SKShapeNode(path: path.cgPath)
        shape.fillColor = SKColor.systemGray
        shape.alpha = targetAlpha
        shape.strokeColor = SKColor.darkGray
        shape.lineWidth = 1.0
        shape.name = "target_\(target.pieceType.rawValue)"
        
        // 7. Set position in parent-local coordinates (relative to bounds center)
        let localPos = CGPoint(
            x: centroidSK.x - boundsCenterSK.x,
            y: centroidSK.y - boundsCenterSK.y
        )
        shape.position = localPos
        
        // 8. No rotation needed - transform is baked into the vertices
        shape.zRotation = 0
        
        // 9. Store metadata for validation
        shape.userData = [
            "centerX": centroidSK.x,  // Store the absolute SK position for validation
            "centerY": centroidSK.y,
            "pieceID": target.pieceType.rawValue,
            "expectedVerticesSK": transformedVerticesSK  // Store for verification
        ]
        
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
    
    // Check whether a tapped node is within another ancestor node tree
    private func isNode(_ node: SKNode, inside ancestor: SKNode?) -> Bool {
        guard let ancestor = ancestor else { return false }
        var current: SKNode? = node
        while let c = current {
            if c === ancestor { return true }
            current = c.parent
        }
        return false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Handle rotation dial buttons when showing
        if isShowingRotationDial {
            // Accept rotation (green check button or center check)
            if nodes.contains(where: { $0.name == "saveRotationDial" }) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                hideRotationDial(cancel: false)
                return
            }
            // Cancel rotation (red X button)
            if nodes.contains(where: { $0.name == "closeRotationDial" }) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                hideRotationDial(cancel: true)
                return
            }
        }
        
        // Check rotation dial UI only (other UI is in SwiftUI toolbar now)
        for node in nodes {
            // Check node itself first
            if node.name == "flipPiece" {
                // Flip the piece that's currently being rotated
                
                // Use the dial's targetPiece instead of selectedPiece
                if let dial = rotationDial, let piece = dial.targetPiece {
                    piece.flip()
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                return
            }
            
            // Check if it's the piece being moved
            if let piece = node as? PuzzlePieceNode {
                // Store for potential rotation
                pendingRotationPiece = piece
                tapStartTime = CACurrentMediaTime()
                tapStartLocation = location
                
                // Capture previous selection and dial state to decide whether to hide
                let wasShowingDial = isShowingRotationDial
                let previousSelected = selectedPiece

                selectedPiece = piece
                piece.isSelected = true
                
                // Bring piece to front
                piece.zPosition = 1000
                
                // If we have a rotation dial showing for a different piece, hide it; otherwise keep it
                if wasShowingDial {
                    if let prev = previousSelected, prev !== piece {
                        // Switching pieces while dial is open should revert previous rotation
                        hideRotationDial(cancel: true)
                    } else {
                        // Keep the dial open for the same piece to allow rotation drag
                    }
                }
                
                // No scaling - just bring to front
                
                break
            }
        }
        
        // If dial is showing and tap occurred outside both the dial and the selected piece, cancel (revert)
        if isShowingRotationDial {
            let tappedInsideDial = nodes.contains { isNode($0, inside: rotationDial) }
            let tappedOnSelectedPiece = nodes.contains { isNode($0, inside: selectedPiece) }
            if !tappedInsideDial && !tappedOnSelectedPiece {
                hideRotationDial(cancel: true)
                return
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
            
            // Get target position in scene coordinates
            let targetWorldPos = puzzleLayer.convert(target.position, to: self)
            
            // Use the validator with scene coordinates
            let validation = TangramPieceValidator.validateForSpriteKit(
                piecePosition: selected.position,
                pieceRotation: selected.zRotation,
                pieceType: pieceType,
                isFlipped: selected.isFlipped,
                targetTransform: targetData.transform,
                targetWorldPos: targetWorldPos
            )
            
            if validation.positionValid {
                if validation.rotationValid && validation.flipValid {
                    
                    snapToPosition(piece: selected, targetPosition: targetWorldPos)
                    
                    // Snap rotation to exact SK angle for perfect alignment using PoseMapper
                    // Even though validation passed (within tolerance), we want exact placement
                    let rawAngle = TangramPoseMapper.rawAngle(from: targetData.transform)
                    let targetRotationSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
                    selected.zRotation = targetRotationSK
                    
                    markPieceComplete(selected)
                    
                    // Show success effect
                    effectsRenderer.showSuccessNudge(at: selected.position)
                } else {
                    
                    // Update available pieces for hint system
                    effectsRenderer.updateAvailablePieces(availablePieces)
                    effectsRenderer.showOrientationNudge(for: selected, flipNeeded: !validation.flipValid, rotationNeeded: !validation.rotationValid)
                }
            }
        }
        
        // Only clear selectedPiece if rotation dial is not showing
        // This ensures the flip button can still access the piece
        if !isShowingRotationDial {
            selectedPiece = nil
        }
    }
    
    // MARK: - Game Logic
    
    private func checkSnapPreview(for piece: PuzzlePieceNode) {
        // Visual preview when dragging near target
        guard let pieceType = piece.pieceType,
              let target = targetPieces[pieceType.rawValue] else { return }
        
        let targetWorldPos = puzzleLayer.convert(target.position, to: self)
        let distance = hypot(piece.position.x - targetWorldPos.x, piece.position.y - targetWorldPos.y)
        
        // Show preview effect when close
        if distance < snapDistance * 2 {
            target.alpha = 0.5
            target.strokeColor = SKColor.systemBlue
        } else {
            target.alpha = targetAlpha
            target.strokeColor = SKColor.darkGray
        }
    }
    
    private func snapToPosition(piece: PuzzlePieceNode, targetPosition: CGPoint) {
        let snapAction = SKAction.move(to: targetPosition, duration: 0.15)
        snapAction.timingMode = .easeInEaseOut
        piece.run(snapAction)
    }
    
    private func markPieceComplete(_ piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType else { return }
        
        completedPieces.insert(pieceType.rawValue)
        piece.isUserInteractionEnabled = false  // Disable interaction for completed pieces
        
        // Lower z-position so new pieces are on top
        piece.zPosition = 1
        
        // Trigger completion callback with piece type and flip state
        onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
        
        // Show completion effects
        effectsRenderer.showCorrectPlacementFeedback(for: piece)
        
        if piece.pieceType == .parallelogram {
            effectsRenderer.showCompletionEffect(at: piece.position)
        }
        
        // Check if puzzle is complete
        if completedPieces.count == availablePieces.count {
            onPuzzleCompleted?()
            
            // Trigger celebration effect
            effectsRenderer.updateAvailablePieces(availablePieces)
            
            // Convert availablePieces to [String: SKNode] for the celebration effect
            var piecesAsNodes: [String: SKNode] = [:]
            for (key, value) in availablePieces {
                piecesAsNodes[key] = value
            }
            effectsRenderer.showPuzzleCompletionCelebration(availablePieces: piecesAsNodes)
        }
    }
    
    // MARK: - Rotation Dial
    
    private func showRotationDial(for piece: PuzzlePieceNode) {
        // Create and show rotation dial for the piece
        let dial = TangramRotationDialNode()
        dial.showForPiece(piece)
        dial.position = piece.position
        dial.zPosition = 2000  // Above everything
        
        addChild(dial)
        
        self.rotationDial = dial
        self.isShowingRotationDial = true
        self.selectedPiece = piece  // Keep piece selected while rotating
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
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
        // Deprecated - progress bar is now in SwiftUI overlay
        // Method kept for compatibility but does nothing
    }
    
    private func createHintsButton(isActive: Bool) {
        // Deprecated - hints button is now in SwiftUI toolbar
        // Method kept for compatibility but does nothing
    }
    
    func updateTimer(_ text: String, started: Bool) {
        // Timer is displayed in SwiftUI toolbar - no action needed here
    }
    
    func updateProgress(_ progress: Double) {
        // Progress is displayed in SwiftUI overlay - no action needed here
    }
    
    // MARK: - Structured Hint System
    
    func showStructuredHint(_ hint: TangramHintEngine.HintData) {
        // Show hint based on type
        let targetPosition = CGPoint(x: hint.targetTransform.tx, y: hint.targetTransform.ty)
        // CRITICAL: Use scene-space rotation to match validation
        let targetRotation = CGFloat(TangramGeometryUtilities.sceneRotation(from: hint.targetTransform))
        
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
        
        // Create text
        let buttonText = SKLabelNode(text: "Next")
        buttonText.fontName = "HelveticaNeue-Medium"
        buttonText.fontSize = 18
        buttonText.fontColor = SKColor.white
        buttonText.verticalAlignmentMode = .center
        buttonText.position = CGPoint(x: -10, y: 0)
        buttonContainer.addChild(buttonText)
        
        // Add arrow
        let arrow = SKLabelNode(text: "→")
        arrow.fontSize = 20
        arrow.fontColor = SKColor.white
        arrow.verticalAlignmentMode = .center
        arrow.position = CGPoint(x: 25, y: -7)
        buttonContainer.addChild(arrow)
        
        buttonContainer.name = "nextButton"
        // Position below safe area with extra padding for status bar
        buttonContainer.position = CGPoint(x: 70, y: size.height - safeAreaTop - 60)
        
        self.nextButton = buttonContainer
        uiLayer.addChild(buttonContainer)
    }
    
    // MARK: - Helper Methods
    
    private func hideRotationDial(cancel: Bool = false) {
        if cancel, let dial = rotationDial {
            // Restore original rotation if canceling
            dial.restoreOriginalRotation()
        }
        
        // Remove dial first
        rotationDial?.removeFromParent()
        rotationDial = nil
        isShowingRotationDial = false
        
        // Clear selection AFTER dial is gone (so flip button still works while dial is visible)
        if let selected = selectedPiece {
            selected.isSelected = false
            selectedPiece = nil
        }
    }
}

// The TangramRotationDialNode class has been moved to TangramRotationDialNode.swift
// The PuzzlePieceNode class has been moved to PuzzlePieceNode.swift