//
//  TangramPuzzleScene.swift
//  Bemo
//
//  SpriteKit scene for Tangram puzzle gameplay with accurate geometry rendering
//

// WHAT: SpriteKit scene that renders tangram pieces using proper vertex-based geometry
// ARCHITECTURE: SKScene integrated into SwiftUI, uses transform-based positioning
// USAGE: Handles puzzle rendering with accurate piece shapes and transforms

// COORDINATE SPACE ARCHITECTURE:
// This scene uses multiple coordinate spaces that must be carefully managed:
//
// 1. SCENE SPACE (root coordinate system, Y-up)
//    - Used for: Effects, rotation dial, validation comparisons
//    - Children: backgroundLayer, puzzleLayer, piecesLayer, effectsLayer, uiLayer
//
// 2. PUZZLE LAYER SPACE (child of scene)
//    - Used for: Target pieces (grey silhouettes)
//    - Position: Centered at desired screen location
//    - Children: Target shape nodes
//
// 3. PIECES LAYER SPACE (child of scene)
//    - Used for: Movable pieces
//    - Position: Origin at scene origin
//    - Children: PuzzlePieceNode instances
//
// CRITICAL CONVERSION RULES:
// - Validation: Both piece and target positions must be in SAME space (scene)
// - Snapping: Target position must be converted to piece's parent space (piecesLayer)
// - Effects: All positions must be in scene space (effectsLayer is scene child)
// - Distance calculations: Both positions must be in same space
//
// COMMON CONVERSIONS:
// - Piece to scene: piecesLayer.convert(piece.position, to: self)
// - Target to scene: puzzleLayer.convert(target.position, to: self)
// - Scene to piecesLayer: self.convert(scenePos, to: piecesLayer)
// - Scene to puzzleLayer: self.convert(scenePos, to: puzzleLayer)

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
    private let validator = TangramPieceValidator()
    private let positioningService = TangramPiecePositioningService()
    
    // Node layers
    private var backgroundLayer = SKNode()
    private var puzzleLayer = SKNode()
    private var piecesLayer = SKNode()
    private var effectsLayer = SKNode()
    private var uiLayer = SKNode()  // Layer for UI elements
    
    // Instance-based target tracking
    private var targetNodesById: [String: SKShapeNode] = [:]  // Target ID -> shape node
    private var targetMetaById: [String: (pieceType: TangramPieceType, targetFeatureAngle: CGFloat, centerScene: CGPoint)] = [:]  // Target ID -> metadata with feature angle
    private var completedTargetIds: Set<String> = []  // Track completed target instances
    
    // Piece tracking
    private var availablePieces: [PuzzlePieceNode] = []  // List of available pieces
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
        targetNodesById.removeAll()
        targetMetaById.removeAll()
        completedTargetIds.removeAll()
        availablePieces.removeAll()
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
        
        // Create movable pieces at the bottom
        createAvailablePieces(from: puzzle.targetPieces)
    }
    
    private func createTargetPiece(_ target: GamePuzzleData.TargetPiece, boundsCenterSK: CGPoint) {
        // Extract TRUE expected SK rotation (no baseline adjustment)
        let rawAngle = TangramPoseMapper.rawAngle(from: target.transform)
        let expectedZRotationSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
        
        // BAKED-VERTICES APPROACH: Apply transform directly to vertices
        
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
        
        // 9. Compute target feature angle using canonical values
        // Get the canonical feature angle for this piece type
        let canonicalFeatureSK = TangramGameConstants.CanonicalFeatures.canonicalFeatureAngle(for: target.pieceType)
        
        // Add the rotation from the transform to get the target feature angle
        // expectedZRotationSK = -rawAngle (Y-flip for SpriteKit)
        let targetFeatureAngleSK = TangramRotationValidator.normalizeAngle(canonicalFeatureSK + expectedZRotationSK)
        
        // 10. Store metadata for validation
        shape.userData = [
            "targetId": target.id,
            "pieceType": target.pieceType.rawValue,
            "targetFeatureAngleSK": targetFeatureAngleSK,
            "expectedZRotationSK": expectedZRotationSK  // Keep for debugging only
        ]
        
        // Store in instance-based tracking
        targetNodesById[target.id] = shape
        targetMetaById[target.id] = (
            pieceType: target.pieceType,
            targetFeatureAngle: targetFeatureAngleSK,  // Store feature angle for validation
            centerScene: CGPoint(x: centroidSK.x, y: centroidSK.y)
        )
        
        puzzleLayer.addChild(shape)
    }
    
    private func createAvailablePieces(from targets: [GamePuzzleData.TargetPiece]) {
        // Define safe bounds for piece placement
        let pieceSize: CGFloat = 80  // Max size of largest piece (with rotation)
        let margin: CGFloat = 40  // Extra margin from edges
        let minX = pieceSize + margin
        let maxX = size.width - pieceSize - margin
        let minY = pieceSize + margin  // Bottom safe area
        let maxY = size.height * 0.35  // Keep pieces in bottom 35% of screen
        
        // Create 1:1 mapping - each piece is bound to a specific target ID
        for (index, target) in targets.enumerated() {
            let piece = PuzzlePieceNode(pieceType: target.pieceType)
            
            // CRITICAL: Bind this piece to its specific target ID
            piece.userData = piece.userData ?? [:]
            piece.userData!["assignedTargetId"] = target.id
            
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
            
            // Random initial rotation
            piece.zRotation = CGFloat.random(in: 0...(2 * .pi))
            piece.name = "piece_\(target.id)"  // Use target ID in name
            piece.zPosition = CGFloat(index)
            
            availablePieces.append(piece)
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
            // Calculate angle from dial center to touch point (CW convention)
            let dialPos = dial.position
            let angleCW = -atan2(location.y - dialPos.y, location.x - dialPos.x)
            dial.updateRotation(to: angleCW)
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
        
        // Get the assigned target ID for this piece (1:1 mapping)
        guard let assignedTargetId = selected.userData?["assignedTargetId"] as? String else { return }
        
        // Check if this target is already completed
        if completedTargetIds.contains(assignedTargetId) {
            return  // This piece's target is already filled
        }
        
        // Get target metadata
        guard let targetNode = targetNodesById[assignedTargetId],
              let targetMeta = targetMetaById[assignedTargetId],
              let targetData = puzzle?.targetPieces.first(where: { $0.id == assignedTargetId }) else { return }
        
        // Get positions in scene space for validation
        let piecePosScene = piecesLayer.convert(selected.position, to: self)
        let targetPosScene = puzzleLayer.convert(targetNode.position, to: self)
        
        // Get feature angles for validation
        let localFeatureAngle = (selected.userData?["localFeatureAngleSK"] as? CGFloat) ?? 0
        let pieceFeatureAngle = TangramRotationValidator.normalizeAngle(selected.zRotation + localFeatureAngle)
        let targetFeatureAngle = targetMeta.targetFeatureAngle  // Use the correct feature angle
        let pieceType = targetMeta.pieceType
        
        // Calculate distance for validation
        let distance = hypot(piecePosScene.x - targetPosScene.x, piecePosScene.y - targetPosScene.y)
        
        // Validate using feature angles
        let positionValid = distance < snapDistance
        let rotationValid = TangramRotationValidator.isRotationValid(
            currentRotation: pieceFeatureAngle,
            targetRotation: targetFeatureAngle,
            pieceType: pieceType,
            isFlipped: selected.isFlipped,
            toleranceDegrees: rotationSnapTolerance
        )
        
        // Check flip validity (for parallelogram)
        let flipValid: Bool
        if pieceType == .parallelogram {
            let targetDeterminant = targetData.transform.a * targetData.transform.d - targetData.transform.b * targetData.transform.c
            let targetIsFlipped = targetDeterminant < 0
            flipValid = (selected.isFlipped == targetIsFlipped)
        } else {
            flipValid = true
        }
        
        let validation = (positionValid: positionValid, rotationValid: rotationValid, flipValid: flipValid)
        
        #if DEBUG
        // Clean logging showing feature angles
        print("🧩 [\(pieceType.rawValue)] targetId=\(assignedTargetId)")
        print("   pieceZ=\(Int(selected.zRotation * 180 / .pi))°, localFeature=\(Int(localFeatureAngle * 180 / .pi))°, pieceFeature=\(Int(pieceFeatureAngle * 180 / .pi))°")
        print("   targetFeature=\(Int(targetFeatureAngle * 180 / .pi))°, dist=\(Int(distance))px")
        print("   posOK=\(validation.positionValid), rotOK=\(validation.rotationValid), flipOK=\(validation.flipValid)")
        #endif
            
            if validation.positionValid {
                if validation.rotationValid && validation.flipValid {
                    
                    // Convert target position to piece's parent space before snapping
                    let targetPosInPiecesLayer = self.convert(targetPosScene, to: piecesLayer)
                    snapToPosition(piece: selected, targetPosition: targetPosInPiecesLayer)
                    
                    // Convert target feature angle back to node zRotation for snapping
                    let desiredNodeZ = TangramRotationValidator.normalizeAngle(targetFeatureAngle - localFeatureAngle)
                    selected.zRotation = desiredNodeZ
                    
                    // Mark this specific target as completed
                    completedTargetIds.insert(assignedTargetId)
                    markPieceComplete(selected)
                    effectsRenderer.showSuccessNudge(at: targetPosScene)
                } else {
                    // Auto-rotate if close but wrong rotation
                    if !validation.rotationValid && validation.flipValid {
                        // Find nearest valid rotation in feature space
                        let nearestFeatureAngle = TangramRotationValidator.nearestValidRotation(
                            currentRotation: pieceFeatureAngle,
                            targetRotation: targetFeatureAngle,
                            pieceType: pieceType,
                            isFlipped: selected.isFlipped
                        )
                        
                        // Convert back to node zRotation
                        let nearestNodeZ = TangramRotationValidator.normalizeAngle(nearestFeatureAngle - localFeatureAngle)
                        let rotationDiff = abs(TangramRotationValidator.normalizeAngle(selected.zRotation - nearestNodeZ))
                        
                        // Auto-snap if within 60 degrees (more forgiving for triangles)
                        let autoSnapThreshold = pieceType.rawValue.contains("Triangle") ? (60.0 * .pi / 180) : (45.0 * .pi / 180)
                        if rotationDiff < autoSnapThreshold {
                            selected.zRotation = nearestNodeZ
                            
                            // Re-validate with corrected rotation
                            let newPieceFeature = TangramRotationValidator.normalizeAngle(selected.zRotation + localFeatureAngle)
                            let revalidation = TangramRotationValidator.isRotationValid(
                                currentRotation: newPieceFeature,
                                targetRotation: targetFeatureAngle,
                                pieceType: pieceType,
                                isFlipped: selected.isFlipped,
                                toleranceDegrees: rotationSnapTolerance
                            )
                            
                            if revalidation && validation.flipValid {
                                // Snap to position
                                let targetPosInPiecesLayer = self.convert(targetPosScene, to: piecesLayer)
                                snapToPosition(piece: selected, targetPosition: targetPosInPiecesLayer)
                                selected.zRotation = nearestNodeZ
                                completedTargetIds.insert(assignedTargetId)
                                markPieceComplete(selected)
                                effectsRenderer.showSuccessNudge(at: targetPosScene)
                                return
                            }
                        }
                    }
                    
                    // Update available pieces for hint system
                    var availablePiecesDict: [String: PuzzlePieceNode] = [:]
                    for piece in availablePieces {
                        if let type = piece.pieceType {
                            availablePiecesDict[type.rawValue] = piece
                        }
                    }
                    effectsRenderer.updateAvailablePieces(availablePiecesDict)
                    effectsRenderer.showOrientationNudge(for: selected, flipNeeded: !validation.flipValid, rotationNeeded: !validation.rotationValid)
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
        guard let assignedTargetId = piece.userData?["assignedTargetId"] as? String else { return }
        
        // Only check the assigned target (1:1 mapping)
        guard !completedTargetIds.contains(assignedTargetId),
              let targetNode = targetNodesById[assignedTargetId],
              let targetMeta = targetMetaById[assignedTargetId] else { return }
        
        let piecePosScene = piecesLayer.convert(piece.position, to: self)
        let targetPosScene = puzzleLayer.convert(targetNode.position, to: self)
        let distance = hypot(piecePosScene.x - targetPosScene.x, piecePosScene.y - targetPosScene.y)
        
        // Show preview effect when close
        if distance < snapDistance * 2 {
            targetNode.alpha = 0.5
            targetNode.strokeColor = SKColor.systemBlue
        } else {
            targetNode.alpha = targetAlpha
            targetNode.strokeColor = SKColor.darkGray
        }
    }
    
    private func snapToPosition(piece: PuzzlePieceNode, targetPosition: CGPoint) {
        let snapAction = SKAction.move(to: targetPosition, duration: 0.15)
        snapAction.timingMode = .easeInEaseOut
        piece.run(snapAction)
    }
    
    private func markPieceComplete(_ piece: PuzzlePieceNode) {
        guard let pieceType = piece.pieceType else { return }
        
        piece.isUserInteractionEnabled = false  // Disable interaction for completed pieces
        
        // Lower z-position so new pieces are on top
        piece.zPosition = 1
        
        // Trigger completion callback with piece type and flip state
        onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
        
        // Convert piece position to scene space for effects
        let piecePosScene = piecesLayer.convert(piece.position, to: self)
        
        // Show completion effects at scene position
        effectsRenderer.showCorrectPlacementFeedback(for: piece)
        
        if piece.pieceType == .parallelogram {
            effectsRenderer.showCompletionEffect(at: piecePosScene)
        }
        
        // Check if puzzle is complete (all targets filled)
        if completedTargetIds.count == targetNodesById.count {
            onPuzzleCompleted?()
            
            // Convert availablePieces to dictionary for compatibility
            var availablePiecesDict: [String: PuzzlePieceNode] = [:]
            for piece in availablePieces {
                if let type = piece.pieceType {
                    availablePiecesDict[type.rawValue] = piece
                }
            }
            
            // Trigger celebration effect
            effectsRenderer.updateAvailablePieces(availablePiecesDict)
            
            // Convert to SKNode dictionary for effect
            var piecesAsNodes: [String: SKNode] = [:]
            for (key, value) in availablePiecesDict {
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
        
        // CRITICAL: Convert piece position from piecesLayer to scene space for dial
        // The dial is added to the scene, not piecesLayer
        let piecePosScene = piecesLayer.convert(piece.position, to: self)
        dial.position = piecePosScene
        dial.zPosition = 2000  // Above everything
        
        addChild(dial)
        
        self.rotationDial = dial
        self.isShowingRotationDial = true
        self.selectedPiece = piece  // Keep piece selected while rotating
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Structured Hint System
    
    func showStructuredHint(_ hint: TangramHintEngine.HintData) {
        // Show hint based on type
        // CRITICAL: Convert target position from raw to SK space for scene rendering
        let rawPosition = TangramPoseMapper.rawPosition(from: hint.targetTransform)
        let targetPosition = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPosition)
        
        // CRITICAL: Convert rotation from raw to SK space to match validation
        let rawAngle = TangramPoseMapper.rawAngle(from: hint.targetTransform)
        let targetRotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
        
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
        // UI is now handled by SwiftUI
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