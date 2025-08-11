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
import Foundation

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
    
    // MARK: - State Tracking
    
    private var pieceStates: [String: PieceState] = [:]  // Track state for each piece
    private var placementTimer: Timer?  // Timer for detecting placement
    private var firstMovedPieceId: String?  // Track the anchor piece
    
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
        
        // Only show pieces that have been moved or placed (not just detected)
        guard let state = pieceStates[pieceId] else {
            // Remove from CV render if it exists but we don't have state
            if let existingNode = cvPieces[pieceId] {
                existingNode.removeFromParent()
                cvPieces.removeValue(forKey: pieceId)
            }
            return
        }
        
        // Check if the state is not unobserved or detected
        switch state.state {
        case .unobserved, .detected:
            // Remove from CV render if it exists but shouldn't be shown
            if let existingNode = cvPieces[pieceId] {
                existingNode.removeFromParent()
                cvPieces.removeValue(forKey: pieceId)
            }
            return
        case .moved, .placed, .validating, .validated, .invalid:
            // Continue to show/update the piece in CV render
            break
        }
        
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
        let scale: CGFloat = 0.6  // Scale down slightly to fit CV render section
        
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
        cvPiece.setScale(0.8)  // Match consistent scale across all sections
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
        let displayScale: CGFloat = 0.8  // Doubled from 0.4 for better visibility
        
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
        // Position pieces in the physical world section, ensuring all are visible
        // Physical world section is centered at (halfWidth, bottomSectionY)
        // and has width = size.width
        
        // Calculate safe bounds for piece placement (with padding from edges)
        let sectionWidth = size.width - 60  // Leave padding on sides
        let sectionHeight = physicalBounds.height - 40  // Leave padding top/bottom
        
        // Piece positioning parameters
        let pieceSpacing: CGFloat = 90  // Space between pieces
        let pieceScale: CGFloat = 0.8  // Scale for visibility
        
        // Calculate grid layout that fits all pieces on screen
        let totalPieces = puzzle.targetPieces.count
        let maxCols = 4  // Maximum columns to keep pieces on screen
        let rows = (totalPieces + maxCols - 1) / maxCols  // Ceiling division
        let cols = min(totalPieces, maxCols)
        
        // Calculate starting position to center the grid
        let gridWidth = CGFloat(cols - 1) * pieceSpacing
        let gridHeight = CGFloat(rows - 1) * pieceSpacing
        let startX = -gridWidth / 2  // Center horizontally
        let startY = gridHeight / 2   // Start from top of available space
        
        // Ensure pieces fit within bounds
        let maxX = (sectionWidth / 2) - 50  // Right boundary with padding
        let minX = -(sectionWidth / 2) + 50  // Left boundary with padding
        let maxY = (sectionHeight / 2) - 20  // Top boundary
        let minY = -(sectionHeight / 2) + 20  // Bottom boundary
        
        for (index, target) in puzzle.targetPieces.enumerated() {
            let piece = PuzzlePieceNode(pieceType: target.pieceType)
            piece.name = "piece_\(target.pieceType)"
            
            // CRITICAL: Bind this piece to its specific target ID
            piece.userData = piece.userData ?? [:]
            piece.userData!["assignedTargetId"] = target.id
            piece.userData!["pieceType"] = target.pieceType.rawValue
            
            // Scale piece to match display requirements
            piece.setScale(pieceScale)
            
            // Position pieces in a grid, ensuring they stay within bounds
            let row = index / maxCols
            let col = index % maxCols
            
            var xPos = startX + CGFloat(col) * pieceSpacing
            var yPos = startY - CGFloat(row) * pieceSpacing
            
            // Clamp positions to ensure pieces are on screen
            xPos = max(minX, min(xPos, maxX))
            yPos = max(minY, min(yPos, maxY))
            
            piece.position = CGPoint(x: xPos, y: yPos)
            
            // Random rotation
            piece.zRotation = CGFloat.random(in: 0...(2 * .pi))
            
            // Initialize piece state as DETECTED
            let pieceId = piece.name ?? "unknown"
            var initialState = PieceState(pieceId: pieceId, pieceType: target.pieceType)
            initialState.state = .detected(baseline: piece.position, rotation: piece.zRotation, detectedAt: Date())
            initialState.currentPosition = piece.position
            initialState.currentRotation = piece.zRotation
            pieceStates[pieceId] = initialState
            piece.pieceState = initialState
            piece.markAsDetected(at: piece.position, rotation: piece.zRotation)
            
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
                
                // Update piece state to MOVED when picked up
                if let pieceId = piece.name {
                    if var state = pieceStates[pieceId] {
                        if case .detected(let baseline, let baseRot, _) = state.state {
                            state.state = .moved(from: baseline, rotation: baseRot)
                            state.interactionCount += 1
                            state.lastMovedTime = Date()
                            
                            // Mark first moved piece as anchor
                            if firstMovedPieceId == nil {
                                firstMovedPieceId = pieceId
                                state.isAnchor = true
                            }
                            
                            pieceStates[pieceId] = state
                            piece.pieceState = state
                            piece.updateStateIndicator()
                        }
                    }
                    
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
        
        // Update piece state position
        if let pieceId = selected.name {
            if var state = pieceStates[pieceId] {
                state.updatePosition(selected.position, rotation: selected.zRotation)
                pieceStates[pieceId] = state
                selected.pieceState = state
                selected.updateStateIndicator()
            }
            
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
        
        // Update state to PLACED and start placement timer
        if let pieceId = selected.name {
            if var state = pieceStates[pieceId] {
                state.markAsPlaced()
                pieceStates[pieceId] = state
                selected.pieceState = state
                selected.updateStateIndicator()
                
                // Start timer to validate after placement delay
                DispatchQueue.main.asyncAfter(deadline: .now() + PieceState.placementDelay) { [weak self] in
                    self?.validatePlacedPiece(selected)
                }
            }
            
            eventBus.emit(.piecePlaced(id: pieceId))
            
            // Emit final position in CV frame
            lastEmittedPositions[pieceId] = selected.position
            lastEmittedRotations[pieceId] = selected.zRotation
            emitCVFrameUpdate()
        }
        
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
    
    private func validatePlacedPiece(_ piece: PuzzlePieceNode) {
        guard let puzzle = puzzle,
              let pieceType = piece.pieceType,
              let pieceId = piece.name,
              let assignedTargetId = piece.userData?["assignedTargetId"] as? String else { return }
        
        // Only validate pieces in PLACED state or later
        guard var state = pieceStates[pieceId],
              state.state.canValidate else {
            return
        }
        
        // Begin validation
        state.beginValidation()
        pieceStates[pieceId] = state
        piece.pieceState = state
        piece.updateStateIndicator()
        
        // Skip validation if this is the anchor piece and no other pieces are validated
        if state.isAnchor && pieceStates.values.filter({ $0.state.canValidate && !$0.isAnchor }).isEmpty {
            // First piece is always "valid" as reference
            var updatedState = state
            updatedState.markAsValidated(connections: [])
            pieceStates[pieceId] = updatedState
            piece.pieceState = updatedState
            piece.updateStateIndicator()
            
            // Mark as completed in target section
            completedPieces.insert(assignedTargetId)
            if let targetNode = targetSilhouettes[assignedTargetId] {
                targetNode.fillColor = .systemGreen
                targetNode.alpha = 0.7
            }
            return
        }
        
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
            
            let distance = hypot(pieceScenePos.x - targetScenePos.x, pieceScenePos.y - targetScenePos.y)
            
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
            } else {
                // Update piece state to invalid with reason
                var updatedState = state
                let reason = determineValidationFailure(result: result, distance: distance)
                updatedState.markAsInvalid(reason: reason)
                pieceStates[pieceId] = updatedState
                piece.pieceState = updatedState
                piece.updateStateIndicator()
                
                // Show nudge for invalid placement
                showNudge(for: piece, reason: reason)
            }
        }
        
        // Not valid - emit event
        eventBus.emit(.validationChanged(pieceId: pieceId, isValid: false))
    }
    
    // MARK: - Nudge System
    
    private func showNudge(for piece: PuzzlePieceNode, reason: ValidationFailure) {
        // Remove any existing nudge
        piece.childNode(withName: "nudge")?.removeFromParent()
        
        // Create nudge node
        let nudgeNode = SKNode()
        nudgeNode.name = "nudge"
        nudgeNode.zPosition = 100
        
        // Add text label
        let label = SKLabelNode(text: reason.nudgeMessage)
        label.fontSize = 14
        label.fontColor = .white
        label.fontName = "System-Bold"
        
        // Add background
        let background = SKShapeNode(rectOf: CGSize(width: label.frame.width + 20, height: 25), cornerRadius: 12)
        background.fillColor = SKColor.systemOrange
        background.strokeColor = .clear
        background.position = CGPoint(x: 0, y: 40)
        
        label.position = CGPoint(x: 0, y: 35)
        
        nudgeNode.addChild(background)
        nudgeNode.addChild(label)
        
        // Add directional arrow if position is wrong
        if case .wrongPosition = reason {
            // Calculate direction to target
            if let targetId = piece.userData?["assignedTargetId"] as? String,
               let targetNode = targetSilhouettes[targetId] {
                let targetPos = targetSection.convert(targetNode.position, to: physicalWorldSection)
                let direction = CGPoint(
                    x: targetPos.x - piece.position.x,
                    y: targetPos.y - piece.position.y
                )
                let angle = atan2(direction.y, direction.x)
                
                // Create arrow
                let arrow = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
                path.addLine(to: CGPoint(x: 15, y: 5))
                path.move(to: CGPoint(x: 20, y: 0))
                path.addLine(to: CGPoint(x: 15, y: -5))
                arrow.path = path
                arrow.strokeColor = .systemOrange
                arrow.lineWidth = 2
                arrow.zRotation = angle
                arrow.position = CGPoint(x: 0, y: 0)
                
                nudgeNode.addChild(arrow)
            }
        }
        
        piece.addChild(nudgeNode)
        
        // Auto-remove after 3 seconds
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 2.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        nudgeNode.run(fadeOut)
    }
    
    // MARK: - Validation Helpers
    
    private func findConnectedValidatedPieces(for piece: PuzzlePieceNode) -> Set<String> {
        var connected = Set<String>()
        
        // Find all validated pieces within connection distance
        for otherPiece in availablePieces {
            guard let otherId = otherPiece.name,
                  otherId != piece.name,
                  let otherState = pieceStates[otherId],
                  case .validated = otherState.state else { continue }
            
            let distance = hypot(piece.position.x - otherPiece.position.x,
                               piece.position.y - otherPiece.position.y)
            
            // Consider pieces within connection threshold as connected
            if distance < 100 {
                connected.insert(otherId)
            }
        }
        
        return connected
    }
    
    private func determineValidationFailure(result: TangramPieceValidator.ValidationResult, distance: CGFloat) -> ValidationFailure {
        if !result.positionValid {
            return .wrongPosition(offset: distance)
        } else if !result.rotationValid {
            // Estimate degrees off (rough calculation)
            return .wrongRotation(degreesOff: 45)
        } else if !result.flipValid {
            return .needsFlip
        } else {
            return .wrongPiece
        }
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
                  let pieceId = piece.name else { continue }
            
            // Include all pieces in CV frame (for testing)
            // In production, we'd only include moved pieces
            // guard let state = pieceStates[pieceId] else { continue }
            // switch state.state {
            // case .unobserved, .detected:
            //     continue
            // default:
            //     break // Include in frame
            // }
            
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