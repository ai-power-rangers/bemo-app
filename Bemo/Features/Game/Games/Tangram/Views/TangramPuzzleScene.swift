//
//  TangramPuzzleScene.swift
//  Bemo
//
//  CV-ready 4-section scene for Tangram puzzle gameplay
//

// WHAT: SpriteKit scene with 4 sections simulating CV hardware setup
// ARCHITECTURE: Physical world (bottom) emits events, digital world (top) displays
// USAGE: Main game scene showing target, CV render, and physical manipulation

import SpriteKit
import SwiftUI

class TangramPuzzleScene: SKScene {
    
    // MARK: - Section Nodes
    
    private var targetSection: SKNode!      // Top left - shows target puzzle
    private var cvRenderSection: SKNode!    // Top right - shows CV interpretation
    private var physicalWorldSection: SKNode! // Bottom - user interaction area
    
    // MARK: - Section Bounds
    
    private var targetBounds: CGRect = .zero
    private var cvRenderBounds: CGRect = .zero
    private var physicalBounds: CGRect = .zero
    
    // MARK: - Game State
    
    var puzzle: GamePuzzleData?
    var onPieceCompleted: ((String, Bool) -> Void)?
    var onPuzzleCompleted: (() -> Void)?
    var onBackPressed: (() -> Void)?
    var onNextPressed: (() -> Void)?
    var onStartTimer: (() -> Void)?
    var onToggleHints: (() -> Void)?
    var safeAreaTop: CGFloat = 0
    
    // MARK: - Pieces & Targets
    
    private var availablePieces: [PuzzlePieceNode] = []
    private var selectedPiece: PuzzlePieceNode?
    private var cvPieces: [String: SKNode] = [:]  // Pieces in CV render section
    private var targetSilhouettes: [String: SKShapeNode] = [:]  // Target section silhouettes
    private var completedPieces: Set<String> = []
    
    // MARK: - Services
    
    private let eventBus = CVEventBus.shared
    private var eventSubscriptionId: UUID?
    private var frameSubscriptionId: UUID?
    private let validator = TangramPieceValidator()
    private let gameplayService = TangramGameplayService()
    
    // MARK: - Touch Tracking
    
    private var initialTouchLocation: CGPoint = .zero
    private var initialPieceRotation: CGFloat = 0
    private var isRotating = false
    
    // MARK: - Rotation Dial
    
    private var rotationDial: TangramRotationDialNode?
    private var isShowingRotationDial: Bool = false
    private var pendingRotationPiece: PuzzlePieceNode?
    private var tapStartTime: TimeInterval = 0
    private var tapStartLocation: CGPoint = .zero
    
    // MARK: - Hints
    
    private var currentHint: (pieceType: TangramPieceType, targetId: String)?
    private var hintNode: SKNode?
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupScene()
        subscribeToEvents()
        
        // Load puzzle if it was set before scene was ready
        if let puzzle = puzzle {
            loadPuzzle(puzzle)
        }
        
        // Start timer when scene loads
        onStartTimer?()
    }
    
    private func setupScene() {
        backgroundColor = SKColor(named: "GameBackground") ?? SKColor.systemBackground
        setupSections()
        setupSectionBackgrounds()
    }
    
    private func setupSections() {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        
        // Account for safe area
        let effectiveTop = size.height - safeAreaTop
        let topSectionY = effectiveTop * 0.75
        
        // TOP LEFT - Target Puzzle Section
        targetSection = SKNode()
        targetSection.position = CGPoint(x: halfWidth/2, y: topSectionY)
        targetSection.zPosition = 1
        addChild(targetSection)
        
        targetBounds = CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight)
        
        // TOP RIGHT - CV Render Section
        cvRenderSection = SKNode()
        cvRenderSection.position = CGPoint(x: size.width * 0.75, y: topSectionY)
        cvRenderSection.zPosition = 1
        addChild(cvRenderSection)
        
        cvRenderBounds = CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)
        
        // BOTTOM - Physical World Section
        physicalWorldSection = SKNode()
        physicalWorldSection.position = CGPoint(x: halfWidth, y: halfHeight/2)
        physicalWorldSection.zPosition = 2
        addChild(physicalWorldSection)
        
        physicalBounds = CGRect(x: 0, y: 0, width: size.width, height: halfHeight)
    }
    
    private func setupSectionBackgrounds() {
        let availableHeight = size.height - safeAreaTop - 80
        let sectionHeight = availableHeight / 2
        
        // Target section background (no label - cleaner look)
        let targetBg = SKShapeNode(rectOf: CGSize(width: size.width/2 - 10, height: sectionHeight - 10))
        targetBg.fillColor = SKColor.systemGray6.withAlphaComponent(0.2)
        targetBg.strokeColor = SKColor.systemGray4
        targetBg.lineWidth = 1
        targetBg.position = .zero
        targetBg.zPosition = -1
        targetSection.addChild(targetBg)
        
        // CV render section background (no label)
        let cvBg = SKShapeNode(rectOf: CGSize(width: size.width/2 - 10, height: sectionHeight - 10))
        cvBg.fillColor = SKColor.systemGray6.withAlphaComponent(0.2)
        cvBg.strokeColor = SKColor.systemGray4
        cvBg.lineWidth = 1
        cvBg.position = .zero
        cvBg.zPosition = -1
        cvRenderSection.addChild(cvBg)
        
        // Physical world section - assembly area (no label)
        let assemblyArea = SKShapeNode(rectOf: CGSize(width: size.width - 20, height: sectionHeight - 10))
        assemblyArea.strokeColor = .systemGray4
        assemblyArea.lineWidth = 2
        assemblyArea.fillColor = .clear
        assemblyArea.position = .zero
        assemblyArea.zPosition = -1
        physicalWorldSection.addChild(assemblyArea)
    }
    
    // MARK: - Event Subscription
    
    private func subscribeToEvents() {
        // Subscribe to individual events
        eventSubscriptionId = eventBus.subscribe { [weak self] event in
            self?.handleCVEvent(event)
        }
        
        // Subscribe to frame events for CV render
        frameSubscriptionId = eventBus.subscribeToFrames { [weak self] frame in
            self?.updateCVRender(frame)
        }
    }
    
    private func handleCVEvent(_ event: TangramCVEvent) {
        switch event {
        case .validationChanged(let pieceId, let isValid):
            updateTargetValidation(pieceId: pieceId, isValid: isValid)
            
        default:
            break
        }
    }
    
    private func updateCVRender(_ frame: CVFrameEvent) {
        // Update CV render section with frame data
        // This simulates what the iPad would show based on CV input
        
        for object in frame.objects {
            updateCVPiece(object)
        }
    }
    
    private func updateCVPiece(_ cvPiece: CVPieceEvent) {
        // Find or create CV visualization
        let pieceId = pieceIdFromCVName(cvPiece.name)
        
        if cvPieces[pieceId] == nil {
            createCVVisualization(for: pieceId)
        }
        
        guard let cvNode = cvPieces[pieceId] else { return }
        
        // Transform position from physical world to CV render section
        let scale: CGFloat = 0.3  // Scale down for CV view
        let cvPos = CGPoint(
            x: CGFloat(cvPiece.pose.translation[0]) * scale * 0.1,
            y: CGFloat(cvPiece.pose.translation[1]) * scale * 0.1
        )
        
        // Add slight jitter to simulate CV noise
        let jitterX = CGFloat.random(in: -1...1)
        let jitterY = CGFloat.random(in: -1...1)
        
        cvNode.position = CGPoint(x: cvPos.x + jitterX, y: cvPos.y + jitterY)
        cvNode.zRotation = CGFloat(cvPiece.pose.rotationDegrees) * .pi / 180
    }
    
    private func createCVVisualization(for pieceId: String) {
        // Find the original piece to get its type
        guard let originalPiece = availablePieces.first(where: { $0.name == pieceId }),
              let pieceType = originalPiece.pieceType else {
            return
        }
        
        // Create a visual copy for CV section
        let cvPiece = PuzzlePieceNode(pieceType: pieceType)
        cvPiece.name = "cv_\(pieceId)"
        cvPiece.setScale(0.5)  // Match the scale of other sections
        cvPiece.alpha = 0.8
        
        cvRenderSection.addChild(cvPiece)
        cvPieces[pieceId] = cvPiece
    }
    
    private func pieceIdFromCVName(_ cvName: String) -> String {
        // Map CV names back to internal IDs
        switch cvName {
        case "tangram_triangle_sml": return "piece_smallTriangle1"
        case "tangram_triangle_sml2": return "piece_smallTriangle2"
        case "tangram_triangle_med": return "piece_mediumTriangle"
        case "tangram_triangle_lrg": return "piece_largeTriangle1"
        case "tangram_triangle_lrg2": return "piece_largeTriangle2"
        case "tangram_square": return "piece_square"
        case "tangram_parallelogram": return "piece_parallelogram"
        default: return cvName
        }
    }
    
    // MARK: - Puzzle Loading
    
    func loadPuzzle(_ puzzle: GamePuzzleData) {
        self.puzzle = puzzle
        
        // If scene hasn't been added to view yet, just store the puzzle
        guard targetSection != nil else { return }
        
        // Clear existing state
        clearAllSections()
        
        // Setup target section with silhouettes
        setupTargetPuzzle(puzzle)
        
        // Create physical pieces
        createPhysicalPieces(puzzle)
    }
    
    private func clearAllSections() {
        // Only clear if sections have been initialized
        guard targetSection != nil else { return }
        
        // Clear all child nodes except backgrounds
        targetSection.children.forEach { node in
            if !(node is SKShapeNode) && !(node is SKLabelNode) {
                node.removeFromParent()
            }
        }
        
        cvRenderSection.children.forEach { node in
            if !(node is SKShapeNode) && !(node is SKLabelNode) {
                node.removeFromParent()
            }
        }
        
        physicalWorldSection.children.forEach { node in
            if !(node is SKShapeNode) && !(node is SKLabelNode) {
                node.removeFromParent()
            }
        }
        
        availablePieces.removeAll()
        cvPieces.removeAll()
        targetSilhouettes.removeAll()
        completedPieces.removeAll()
    }
    
    private func setupTargetPuzzle(_ puzzle: GamePuzzleData) {
        // Calculate bounds for centering
        let bounds = TangramBounds.calculatePuzzleBoundsSK(targets: puzzle.targetPieces)
        let boundsCenterSK = CGPoint(x: bounds.midX, y: bounds.midY)
        
        // Scale for fitting in the smaller target section
        let displayScale: CGFloat = 0.5  // Half size for display
        
        for target in puzzle.targetPieces {
            // Create properly transformed silhouette
            let silhouette = createTargetSilhouette(target, boundsCenterSK: boundsCenterSK, displayScale: displayScale)
            targetSection.addChild(silhouette)
            targetSilhouettes[target.id] = silhouette
        }
    }
    
    private func createTargetSilhouette(_ target: GamePuzzleData.TargetPiece, boundsCenterSK: CGPoint, displayScale: CGFloat) -> SKShapeNode {
        // BAKED-VERTICES APPROACH: Apply transform directly to vertices
        
        // 1. Get normalized vertices and scale them to match piece size
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
        
        // 5. Build path from SK vertices, scaled and positioned for display
        let path = CGMutablePath()
        let centeredVertices = transformedVerticesSK.map { vertex in
            CGPoint(
                x: (vertex.x - boundsCenterSK.x) * displayScale,
                y: (vertex.y - boundsCenterSK.y) * displayScale
            )
        }
        
        if let firstVertex = centeredVertices.first {
            path.move(to: firstVertex)
            for vertex in centeredVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        let silhouette = SKShapeNode(path: path)
        silhouette.fillColor = .systemGray
        silhouette.strokeColor = .darkGray
        silhouette.alpha = 0.3
        silhouette.name = "target_\(target.id)"
        silhouette.position = .zero  // Already positioned via vertices
        
        return silhouette
    }
    
    private func createPhysicalPieces(_ puzzle: GamePuzzleData) {
        // Scatter pieces on left side of physical world
        let startX = -size.width * 0.35
        let pieceSpacing: CGFloat = 60  // Adjusted spacing for scaled pieces
        
        // Scale pieces to fit nicely in the physical world section
        // but still be interactive and visible
        let pieceScale: CGFloat = 0.5
        
        for (index, target) in puzzle.targetPieces.enumerated() {
            let piece = PuzzlePieceNode(pieceType: target.pieceType)
            piece.name = "piece_\(target.pieceType)"
            
            // CRITICAL: Bind this piece to its specific target ID
            piece.userData = piece.userData ?? [:]
            piece.userData!["assignedTargetId"] = target.id
            piece.userData!["pieceType"] = target.pieceType.rawValue
            
            // Scale piece to match display requirements
            piece.setScale(pieceScale)
            
            // Position on left side
            let row = index / 3
            let col = index % 3
            piece.position = CGPoint(
                x: startX + CGFloat(col) * pieceSpacing,
                y: CGFloat(row) * pieceSpacing - 50
            )
            
            // Random rotation
            piece.zRotation = CGFloat.random(in: 0...(2 * .pi))
            
            availablePieces.append(piece)
            physicalWorldSection.addChild(piece)
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Handle rotation dial if showing
        if isShowingRotationDial {
            handleRotationDialTouch(at: location)
            return
        }
        
        // Check for piece in physical world section
        let physicalLocation = touch.location(in: physicalWorldSection)
        let physicalNodes = physicalWorldSection.nodes(at: physicalLocation)
        
        for node in physicalNodes {
            if let piece = node as? PuzzlePieceNode {
                // Store for potential rotation
                pendingRotationPiece = piece
                tapStartTime = CACurrentMediaTime()
                tapStartLocation = physicalLocation
                
                selectedPiece = piece
                piece.isSelected = true
                piece.zPosition = 1000  // Bring to front
                
                // Emit lift event
                if let pieceId = piece.name {
                    eventBus.emit(.pieceLifted(id: pieceId))
                }
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Check if we're rotating with the dial
        if isShowingRotationDial, let dial = rotationDial, let piece = selectedPiece {
            let location = touch.location(in: self)
            
            // Calculate angle from dial center to touch point
            let dialPos = dial.position
            let currentTouchAngle = atan2(location.y - dialPos.y, location.x - dialPos.x)
            
            // On first move, calculate the offset
            if !isRotating {
                isRotating = true
                initialTouchLocation = location
                initialPieceRotation = piece.zRotation
            }
            
            // Calculate rotation delta
            let angleDelta = currentTouchAngle - atan2(initialTouchLocation.y - dialPos.y, initialTouchLocation.x - dialPos.x)
            
            // Apply rotation
            let newRotation = initialPieceRotation - angleDelta  // Negative because SK is clockwise
            dial.updateRotation(to: newRotation)
            
            // Emit rotation event
            if let pieceId = piece.name {
                eventBus.emit(.pieceMoved(
                    id: pieceId,
                    position: piece.position,
                    rotation: newRotation
                ))
            }
            return
        }
        
        // Normal piece dragging
        guard let selected = selectedPiece else { return }
        
        // Cancel pending rotation if we're dragging
        if pendingRotationPiece != nil {
            let physicalLocation = touch.location(in: physicalWorldSection)
            let dragDistance = hypot(physicalLocation.x - tapStartLocation.x, physicalLocation.y - tapStartLocation.y)
            if dragDistance > 10 {  // Threshold for drag detection
                pendingRotationPiece = nil
            }
        }
        
        // Drag the piece
        let physicalLocation = touch.location(in: physicalWorldSection)
        selected.position = physicalLocation
        
        // Emit move event
        if let pieceId = selected.name {
            eventBus.emit(.pieceMoved(
                id: pieceId,
                position: selected.position,
                rotation: selected.zRotation
            ))
        }
        
        // Check for snap preview
        checkSnapPreview(for: selected)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: physicalWorldSection)
        
        // If rotation dial is showing, handle rotation end
        if isShowingRotationDial {
            if isRotating {
                rotationDial?.finishRotation()
                isRotating = false
            }
            return
        }
        
        // Check if this was a tap (not a drag) to show rotation dial
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
        
        // Check for snap
        checkAndSnap(piece: selected)
        
        // Emit place event
        if let pieceId = selected.name {
            eventBus.emit(.piecePlaced(id: pieceId))
        }
        
        // Validate placement
        validatePiece(selected)
        
        // Clear selection if not showing rotation dial
        if !isShowingRotationDial {
            selectedPiece = nil
        }
    }
    
    // MARK: - Rotation Dial
    
    private func showRotationDial(for piece: PuzzlePieceNode) {
        let dial = TangramRotationDialNode()
        dial.showForPiece(piece)
        
        // Convert piece position to scene space for dial
        let piecePosScene = physicalWorldSection.convert(piece.position, to: self)
        dial.position = piecePosScene
        dial.zPosition = 2000
        
        addChild(dial)
        
        self.rotationDial = dial
        self.isShowingRotationDial = true
        self.selectedPiece = piece
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleRotationDialTouch(at location: CGPoint) {
        let nodes = nodes(at: location)
        
        // Accept rotation
        if nodes.contains(where: { $0.name == "saveRotationDial" }) {
            hideRotationDial(save: true)
            return
        }
        
        // Cancel rotation
        if nodes.contains(where: { $0.name == "closeRotationDial" }) {
            hideRotationDial(save: false)
            return
        }
        
        // Flip piece
        if nodes.contains(where: { $0.name == "flipPiece" }) {
            if let piece = selectedPiece {
                piece.flip()
                if let pieceId = piece.name {
                    eventBus.emit(.pieceFlipped(id: pieceId, isFlipped: piece.isFlipped))
                }
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            return
        }
    }
    
    private func hideRotationDial(save: Bool) {
        if !save, let dial = rotationDial {
            dial.restoreOriginalRotation()
        }
        
        isRotating = false
        rotationDial?.removeFromParent()
        rotationDial = nil
        isShowingRotationDial = false
        
        if let selected = selectedPiece {
            selected.isSelected = false
            selectedPiece = nil
        }
    }
    
    // MARK: - Snap & Validation
    
    private func checkSnapPreview(for piece: PuzzlePieceNode) {
        // Find nearest target
        guard let puzzle = puzzle,
              let pieceType = piece.pieceType else { return }
        
        // Convert piece position to scene space for comparison
        let pieceScenePos = physicalWorldSection.convert(piece.position, to: self)
        
        var closestDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        for target in puzzle.targetPieces where target.pieceType == pieceType {
            // Get target position in scene space
            guard let targetNode = targetSilhouettes[target.id] else { continue }
            let targetScenePos = targetSection.convert(targetNode.position, to: self)
            
            let distance = hypot(targetScenePos.x - pieceScenePos.x, targetScenePos.y - pieceScenePos.y)
            if distance < closestDistance {
                closestDistance = distance
            }
        }
        
        // Show snap preview if close enough
        if closestDistance < 100 {
            piece.alpha = 0.7
        } else {
            piece.alpha = 1.0
        }
    }
    
    private func checkAndSnap(piece: PuzzlePieceNode) {
        // Similar to checkSnapPreview but actually snaps the piece
        guard let puzzle = puzzle,
              let pieceType = piece.pieceType else { return }
        
        let pieceScenePos = physicalWorldSection.convert(piece.position, to: self)
        
        for target in puzzle.targetPieces where target.pieceType == pieceType {
            guard let targetNode = targetSilhouettes[target.id] else { continue }
            let targetScenePos = targetSection.convert(targetNode.position, to: self)
            
            let distance = hypot(targetScenePos.x - pieceScenePos.x, targetScenePos.y - pieceScenePos.y)
            
            if distance < 50 {  // Snap distance
                // Convert target position to physical world space for snapping
                let snapPos = self.convert(targetScenePos, to: physicalWorldSection)
                
                // Animate snap
                let snapAction = SKAction.move(to: snapPos, duration: 0.1)
                piece.run(snapAction)
                
                // Snap rotation too
                let targetRotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
                let rotateAction = SKAction.rotate(toAngle: targetRotation, duration: 0.1)
                piece.run(rotateAction)
                
                break
            }
        }
    }
    
    private func validatePiece(_ piece: PuzzlePieceNode) {
        guard let puzzle = puzzle,
              let pieceType = piece.pieceType,
              let pieceId = piece.name,
              let assignedTargetId = piece.userData?["assignedTargetId"] as? String else { return }
        
        // Check if piece matches its assigned target
        guard let target = puzzle.targetPieces.first(where: { $0.id == assignedTargetId }) else { return }
        
        // Only validate if types match (safety check)
        if target.pieceType == pieceType {
            let pieceScenePos = physicalWorldSection.convert(piece.position, to: self)
            
            guard let targetNode = targetSilhouettes[target.id] else { return }
            let targetScenePos = targetSection.convert(targetNode.position, to: self)
            
            let result = validator.validateForSpriteKit(
                piecePosition: pieceScenePos,
                pieceRotation: piece.zRotation,
                pieceType: pieceType,
                isFlipped: piece.isFlipped,
                targetTransform: target.transform,
                targetWorldPos: targetScenePos
            )
            let isValid = result.positionValid && result.rotationValid && result.flipValid
            
            if isValid {
                // Mark as completed
                completedPieces.insert(target.id)
                eventBus.emit(.validationChanged(pieceId: target.id, isValid: true))
                
                // Update target visual
                targetNode.fillColor = .systemGreen
                targetNode.alpha = 0.7
                
                // Pulse effect
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                targetNode.run(pulse)
                
                // Check if puzzle complete
                if completedPieces.count == puzzle.targetPieces.count {
                    onPuzzleCompleted?()
                }
                
                // Notify piece completion
                onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
                
                return
            }
        }
        
        // Not valid - emit event
        eventBus.emit(.validationChanged(pieceId: pieceId, isValid: false))
    }
    
    private func updateTargetValidation(pieceId: String, isValid: Bool) {
        guard let silhouette = targetSilhouettes[pieceId] else { return }
        
        if isValid {
            silhouette.fillColor = .systemGreen
            silhouette.alpha = 0.7
        } else {
            silhouette.fillColor = .systemGray
            silhouette.alpha = 0.3
        }
    }
    
    // MARK: - Public Methods
    
    func updateCompletionState(_ completedPieces: Set<String>) {
        // Update completed pieces from external source
        self.completedPieces = completedPieces
        
        // Update visual state of targets
        for targetId in completedPieces {
            if let silhouette = targetSilhouettes[targetId] {
                silhouette.fillColor = .systemGreen
                silhouette.alpha = 0.7
            }
        }
    }
    
    func showStructuredHint(_ hint: TangramHintEngine.HintData) {
        // Delegate to showHint
        showHint(for: hint)
    }
    
    // MARK: - Hints
    
    func showHint(for hint: TangramHintEngine.HintData) {
        // Remove existing hint
        hintNode?.removeFromParent()
        
        guard let puzzle = puzzle else { return }
        
        // Find the target for this hint
        let target = puzzle.targetPieces.first { $0.pieceType == hint.targetPiece }
        guard let target = target,
              let targetNode = targetSilhouettes[target.id] else { return }
        
        // Create hint visualization in physical world
        let hintPiece = PuzzlePieceNode(pieceType: hint.targetPiece)
        hintPiece.alpha = 0.5
        hintPiece.isUserInteractionEnabled = false
        
        // Convert target position to physical world space
        let targetScenePos = targetSection.convert(targetNode.position, to: self)
        let hintPos = self.convert(targetScenePos, to: physicalWorldSection)
        
        hintPiece.position = hintPos
        hintPiece.zRotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
        hintPiece.zPosition = 500
        
        // Add pulsing animation
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.5),
            SKAction.fadeAlpha(to: 0.3, duration: 0.5)
        ])
        hintPiece.run(SKAction.repeatForever(pulse))
        
        physicalWorldSection.addChild(hintPiece)
        hintNode = hintPiece
        
        currentHint = (hint.targetPiece, target.id)
    }
    
    func hideHint() {
        hintNode?.removeFromParent()
        hintNode = nil
        currentHint = nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        if let eventId = eventSubscriptionId {
            eventBus.unsubscribe(eventId)
        }
        if let frameId = frameSubscriptionId {
            eventBus.unsubscribe(frameId)
        }
    }
}