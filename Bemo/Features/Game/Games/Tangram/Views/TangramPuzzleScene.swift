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
    private var lastEmittedPositions: [String: CGPoint] = [:]  // Track last emitted position per piece
    private var lastEmittedRotations: [String: CGFloat] = [:]  // Track last emitted rotation per piece
    
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
        
        // Account for safe area and navigation bar
        let navBarHeight: CGFloat = 100  // Increased to ensure clearance
        let topPadding: CGFloat = safeAreaTop + navBarHeight
        let availableHeight = size.height - topPadding - 20  // Bottom padding
        let sectionHeight = availableHeight / 2
        
        // Calculate section centers (Y=0 is at bottom in SpriteKit)
        // Top sections should be in the upper half of available space
        let topSectionY = size.height - topPadding - (sectionHeight / 2)  // Center of top half
        let bottomSectionY = sectionHeight / 2  // Center of bottom half
        
        // TOP LEFT - Target Puzzle Section
        targetSection = SKNode()
        targetSection.position = CGPoint(x: halfWidth/2, y: topSectionY)
        targetSection.zPosition = 1
        addChild(targetSection)
        
        targetBounds = CGRect(x: 0, y: topSectionY - sectionHeight/2, width: halfWidth, height: sectionHeight)
        
        // TOP RIGHT - CV Render Section
        cvRenderSection = SKNode()
        cvRenderSection.position = CGPoint(x: size.width * 0.75, y: topSectionY)
        cvRenderSection.zPosition = 1
        addChild(cvRenderSection)
        
        cvRenderBounds = CGRect(x: halfWidth, y: topSectionY - sectionHeight/2, width: halfWidth, height: sectionHeight)
        
        // BOTTOM - Physical World Section
        physicalWorldSection = SKNode()
        physicalWorldSection.position = CGPoint(x: halfWidth, y: bottomSectionY)
        physicalWorldSection.zPosition = 2
        addChild(physicalWorldSection)
        
        physicalBounds = CGRect(x: 0, y: 0, width: size.width, height: sectionHeight)
    }
    
    private func setupSectionBackgrounds() {
        // Match the section setup dimensions
        let navBarHeight: CGFloat = 100
        let topPadding: CGFloat = safeAreaTop + navBarHeight
        let availableHeight = size.height - topPadding - 20
        let sectionHeight = (availableHeight / 2) - 10  // Small gap between sections
        let sectionWidth = (size.width / 2) - 10  // Small gap between left/right
        
        // Target section background (top left)
        let targetBg = SKShapeNode(rectOf: CGSize(width: sectionWidth, height: sectionHeight))
        targetBg.fillColor = SKColor.systemGray6.withAlphaComponent(0.3)
        targetBg.strokeColor = SKColor.systemGray3
        targetBg.lineWidth = 2
        targetBg.position = .zero
        targetBg.zPosition = -1
        targetSection.addChild(targetBg)
        
        // CV render section background (top right)
        let cvBg = SKShapeNode(rectOf: CGSize(width: sectionWidth, height: sectionHeight))
        cvBg.fillColor = SKColor.systemBlue.withAlphaComponent(0.05)
        cvBg.strokeColor = SKColor.systemBlue.withAlphaComponent(0.3)
        cvBg.lineWidth = 2
        cvBg.position = .zero
        cvBg.zPosition = -1
        cvRenderSection.addChild(cvBg)
        
        // Physical world section - assembly area (bottom)
        let assemblyArea = SKShapeNode(rectOf: CGSize(width: size.width - 30, height: sectionHeight))
        assemblyArea.strokeColor = SKColor.systemGreen.withAlphaComponent(0.3)
        assemblyArea.lineWidth = 3
        assemblyArea.fillColor = SKColor.systemGreen.withAlphaComponent(0.02)
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
        
        // Clear old pieces that aren't in the frame
        let frameIds = Set(frame.objects.map { pieceIdFromCVName($0.name) })
        for (pieceId, node) in cvPieces {
            if !frameIds.contains(pieceId) {
                node.removeFromParent()
                cvPieces.removeValue(forKey: pieceId)
            }
        }
        
        // Update or create pieces from frame
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
        
        // Find the corresponding physical piece to get its position
        guard let physicalPiece = availablePieces.first(where: { $0.name == pieceId }) else { return }
        
        // Map position from physical world coordinate space to CV render section space
        // Physical world is centered at (halfWidth, bottomSectionY)
        // CV render is centered at (3/4 width, topSectionY)
        // Both sections should show pieces at the same relative scale
        
        // Simply map the position directly - pieces are already scaled consistently
        let scale: CGFloat = 0.8  // Slight scale to keep pieces within bounds
        
        let cvPos = CGPoint(
            x: physicalPiece.position.x * scale,
            y: physicalPiece.position.y * scale
        )
        
        // Smooth position update - no jitter
        cvNode.position = cvPos
        cvNode.zRotation = physicalPiece.zRotation  // Use actual rotation from physical piece
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
        cvPiece.setScale(0.4)  // Match consistent scale across all sections
        cvPiece.alpha = 0.9
        cvPiece.isUserInteractionEnabled = false  // No interaction in CV section
        
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
        
        // Emit initial CV frame
        emitCVFrameUpdate()
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
        
        // Scale for fitting in the target section (matches physical pieces)
        let displayScale: CGFloat = 0.4  // Consistent scale across all sections
        
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
        
        // Scale pieces consistently across all sections
        let pieceScale: CGFloat = 0.4
        
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
            
            // Only emit rotation event if rotation changed significantly
            if let pieceId = piece.name {
                let lastRot = lastEmittedRotations[pieceId] ?? 0
                let rotDiff = abs(newRotation - lastRot)
                
                // Emit only if rotated more than threshold (reduces jitter)
                if rotDiff > 0.05 {  // About 3 degrees
                    eventBus.emit(.pieceMoved(
                        id: pieceId,
                        position: piece.position,
                        rotation: newRotation
                    ))
                    lastEmittedRotations[pieceId] = newRotation
                    
                    // Also emit CV frame event
                    emitCVFrameUpdate()
                }
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
        
        // Only emit move event if position changed significantly
        if let pieceId = selected.name {
            let lastPos = lastEmittedPositions[pieceId] ?? CGPoint.zero
            let distance = hypot(selected.position.x - lastPos.x, selected.position.y - lastPos.y)
            
            // Emit only if moved more than threshold (reduces jitter)
            if distance > 2.0 {
                eventBus.emit(.pieceMoved(
                    id: pieceId,
                    position: selected.position,
                    rotation: selected.zRotation
                ))
                lastEmittedPositions[pieceId] = selected.position
                
                // Also emit CV frame event for top-right display
                emitCVFrameUpdate()
            }
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
        
        // Emit place event and final CV frame
        if let pieceId = selected.name {
            eventBus.emit(.piecePlaced(id: pieceId))
            
            // Emit final position in CV frame
            lastEmittedPositions[pieceId] = selected.position
            lastEmittedRotations[pieceId] = selected.zRotation
            emitCVFrameUpdate()
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
            
            // Calculate feature angles for validation
            // Get local feature angle from piece's userData (computed during initialization)
            let localFeatureAngle = piece.userData?["localFeatureAngleSK"] as? CGFloat ?? 0
            let pieceFeatureAngle = piece.zRotation + localFeatureAngle
            
            // Calculate target feature angle from transform
            let targetRotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
            let targetLocalFeature = pieceType.isTriangle ? (3 * CGFloat.pi / 4) : 0
            let targetFeatureAngle = targetRotation + targetLocalFeature
            
            let result = validator.validateForSpriteKitWithFeatures(
                piecePosition: pieceScenePos,
                pieceFeatureAngle: pieceFeatureAngle,
                targetFeatureAngle: targetFeatureAngle,
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
    
    // MARK: - CV Frame Updates
    
    private func emitCVFrameUpdate() {
        // Build CV frame from current physical world pieces
        var cvObjects: [CVPieceEvent] = []
        
        for piece in availablePieces {
            guard let pieceType = piece.pieceType,
                  let _ = piece.name else { continue }
            
            // Map piece type to CV names
            let cvName = cvNameFromPieceType(pieceType)
            let classId = classIdFromPieceType(pieceType)
            
            // Convert SpriteKit position to CV coordinates
            let cvTranslation = [
                Double(piece.position.x),
                Double(piece.position.y)
            ]
            
            // Convert rotation to degrees
            let rotationDegrees = Double(piece.zRotation * 180 / .pi)
            
            // Calculate vertices (simplified for now)
            let vertices = calculateVertices(for: pieceType, at: piece.position, rotation: piece.zRotation)
            
            let cvPiece = CVPieceEvent(
                name: cvName,
                classId: classId,
                pose: CVPieceEvent.Pose(
                    rotationDegrees: rotationDegrees,
                    translation: cvTranslation
                ),
                vertices: vertices
            )
            
            cvObjects.append(cvPiece)
        }
        
        // Emit frame event
        let frame = CVFrameEvent(objects: cvObjects)
        eventBus.emitFrame(frame)
    }
    
    private func cvNameFromPieceType(_ type: TangramPieceType) -> String {
        switch type {
        case .smallTriangle1: return "tangram_triangle_sml"
        case .smallTriangle2: return "tangram_triangle_sml2"
        case .mediumTriangle: return "tangram_triangle_med"
        case .largeTriangle1: return "tangram_triangle_lrg"
        case .largeTriangle2: return "tangram_triangle_lrg2"
        case .square: return "tangram_square"
        case .parallelogram: return "tangram_parallelogram"
        }
    }
    
    private func classIdFromPieceType(_ type: TangramPieceType) -> Int {
        switch type {
        case .parallelogram: return 0
        case .square: return 1
        case .largeTriangle1: return 2
        case .largeTriangle2: return 3
        case .mediumTriangle: return 4
        case .smallTriangle1: return 5
        case .smallTriangle2: return 6
        }
    }
    
    private func calculateVertices(for pieceType: TangramPieceType, at position: CGPoint, rotation: CGFloat) -> [[Double]] {
        // Get base vertices
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale * 0.5)
        
        // Apply rotation and translation
        let transform = CGAffineTransform(rotationAngle: rotation)
            .translatedBy(x: position.x, y: position.y)
        
        // Transform vertices and convert to double arrays
        return scaledVertices.map { vertex in
            let transformed = vertex.applying(transform)
            return [Double(transformed.x), Double(transformed.y)]
        }
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