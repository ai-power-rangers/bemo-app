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
    
    internal var targetSection: SKNode!      // Top panel - shows target puzzle centered
    private var cvMiniDisplay: SKNode!      // Mini CV display in top-right corner
    internal var physicalWorldSection: SKNode! // Bottom - user interaction area (internal for extensions)
    
    // MARK: - Section Bounds
    
    private var targetBounds: CGRect = .zero
    private var cvMiniBounds: CGRect = .zero
    internal var physicalBounds: CGRect = .zero  // Internal for extensions
    
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
    
    internal var availablePieces: [PuzzlePieceNode] = []  // Internal for extensions
    private var selectedPiece: PuzzlePieceNode?
    private var cvPieces: [String: SKNode] = [:]  // Pieces in CV render section
    internal var targetSilhouettes: [String: SKShapeNode] = [:]  // Target section silhouettes (internal for validation)
    private var completedPieces: Set<String> = []
    
    // MARK: - Services
    
    private let eventBus = CVEventBus.shared
    private var eventSubscriptionId: UUID?
    private var frameSubscriptionId: UUID?
    private let validator = TangramPieceValidator()
    private let gameplayService = TangramGameplayService()
    private let groupManager = ConstructionGroupManager()
    private let nudgeManager = SmartNudgeManager()
    private var constructionGroups: [ConstructionGroup] = []
    // Per-group anchor mapping and associations
    var mappingService: TangramRelativeMappingService = TangramRelativeMappingService()
    private var pieceInvalidStreak: [String: Int] = [:]
    private let invalidStreakThreshold = 5
    private var targetDisplayScale: CGFloat = 0.8
    
    // MARK: - Touch Tracking
    
    private var initialTouchLocation: CGPoint = .zero
    private var initialPieceRotation: CGFloat = 0
    private var isRotating = false
    private var lastEmittedPositions: [String: CGPoint] = [:]  // Track last emitted position per piece
    private var lastEmittedRotations: [String: CGFloat] = [:]  // Track last emitted rotation per piece
    
    // MARK: - Anchor-Based Validation
    
    // Legacy single mapping fields (kept for backward compatibility but unused in new per-group flow)
    private var anchorPieceId: String?
    private var validatedTargets: Set<String> = []
    
    // MARK: - State Tracking
    
    internal var pieceStates: [String: PieceState] = [:]  // Track state for each piece (internal for extensions)
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
        
        // Account for safe area and navigation bar - reduced spacing
        let navBarHeight: CGFloat = 60  // Reduced from 100 to bring content higher
        let topPadding: CGFloat = safeAreaTop + navBarHeight
        let sectionGap: CGFloat = 20  // Gap between sections
        let availableHeight = size.height - topPadding - 10  // Minimal bottom padding
        let sectionHeight = (availableHeight - sectionGap) / 2  // Account for gap between sections
        
        // Calculate section centers (Y=0 is at bottom in SpriteKit)
        // Position top panel right below nav bar
        let topSectionY = size.height - topPadding - (sectionHeight / 2)  // Higher position
        let bottomSectionY = topSectionY - sectionHeight - sectionGap  // Bottom section moved up
        
        // TOP PANEL - Unified target display with mini CV in corner
        targetSection = SKNode()
        targetSection.position = CGPoint(x: halfWidth, y: topSectionY)  // Center of entire top panel
        targetSection.zPosition = 1
        addChild(targetSection)
        
        targetBounds = CGRect(x: 0, y: topSectionY - sectionHeight/2, width: size.width, height: sectionHeight)
        
        // MINI CV DISPLAY - Small display in top-right corner of top panel
        let miniDisplaySize: CGFloat = min(size.width * 0.25, 150)  // 25% of width or 150px max
        cvMiniDisplay = SKNode()
        // Position relative to targetSection (which is centered)
        cvMiniDisplay.position = CGPoint(
            x: (size.width / 2) - miniDisplaySize/2 - 20,  // Right edge minus padding
            y: (sectionHeight / 2) - miniDisplaySize/2 - 20   // Top edge minus padding
        )
        cvMiniDisplay.zPosition = 10  // Above target content
        targetSection.addChild(cvMiniDisplay)  // Add as child of target section
        
        cvMiniBounds = CGRect(
            x: size.width - miniDisplaySize - 20,
            y: topSectionY + sectionHeight/2 - miniDisplaySize - 20,
            width: miniDisplaySize,
            height: miniDisplaySize
        )
        
        // BOTTOM - Physical World Section
        physicalWorldSection = SKNode()
        physicalWorldSection.position = CGPoint(x: halfWidth, y: bottomSectionY)
        physicalWorldSection.zPosition = 2
        addChild(physicalWorldSection)
        
        physicalBounds = CGRect(x: 0, y: 0, width: size.width, height: sectionHeight)
    }
    
    private func setupSectionBackgrounds() {
        // Match the section setup dimensions
        let navBarHeight: CGFloat = 60  // Match reduced nav bar height
        let topPadding: CGFloat = safeAreaTop + navBarHeight
        let sectionGap: CGFloat = 20
        let availableHeight = size.height - topPadding - 10
        let sectionHeight = (availableHeight - sectionGap) / 2
        
        // Top panel background (entire top section)
        let targetBg = SKShapeNode(rectOf: CGSize(width: size.width - 20, height: sectionHeight))
        targetBg.fillColor = SKColor.systemGray6.withAlphaComponent(0.3)
        targetBg.strokeColor = SKColor.systemGray3
        targetBg.lineWidth = 2
        targetBg.position = .zero
        targetBg.zPosition = -1
        targetSection.addChild(targetBg)
        
        // Mini CV display background
        let miniDisplaySize: CGFloat = min(size.width * 0.25, 150)
        let cvMiniBg = SKShapeNode(rectOf: CGSize(width: miniDisplaySize, height: miniDisplaySize))
        cvMiniBg.fillColor = SKColor.systemBlue.withAlphaComponent(0.1)
        cvMiniBg.strokeColor = SKColor.systemBlue.withAlphaComponent(0.5)
        cvMiniBg.lineWidth = 1
        cvMiniBg.position = .zero
        cvMiniBg.zPosition = -1
        cvMiniDisplay.addChild(cvMiniBg)
        
        // Add label for CV mini display
        let cvLabel = SKLabelNode(text: "CV")
        cvLabel.fontSize = 10
        cvLabel.fontColor = SKColor.systemBlue.withAlphaComponent(0.7)
        cvLabel.position = CGPoint(x: 0, y: -miniDisplaySize/2 + 5)
        cvLabel.zPosition = 1
        cvMiniDisplay.addChild(cvLabel)
        
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
        case .validationChanged(let pieceIdOrTargetId, let isValid):
            updateTargetValidation(pieceId: pieceIdOrTargetId, isValid: isValid)
            // For CV mini display, map target ids to piece ids if needed
            let mappedPieceId: String? = {
                // If cvPieces already contains this id, use it directly
                if cvPieces[pieceIdOrTargetId] != nil { return pieceIdOrTargetId }
                // Otherwise find the piece that validated against this target id
                for node in availablePieces {
                    if let vid = node.userData?["validatedTargetId"] as? String, vid == pieceIdOrTargetId {
                        return node.name
                    }
                }
                return nil
            }()
            if let pid = mappedPieceId {
                showCVValidationFeedback(pieceId: pid, isValid: isValid)
            }
            
        case .pieceFlipped(let id, _):
            // Update CV display when piece is flipped
            if let cvNode = cvPieces[id] as? PuzzlePieceNode,
               let physicalPiece = availablePieces.first(where: { $0.name == id }) {
                if cvNode.isFlipped != physicalPiece.isFlipped {
                    cvNode.flip()
                }
            }
            
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
        
        // Map position from physical world to mini CV display
        // Scale down significantly for the mini display
        let miniDisplaySize: CGFloat = min(size.width * 0.25, 150)
        let scale: CGFloat = miniDisplaySize / (size.width * 0.8)  // Scale relative to physical world width
        
        let cvPos = CGPoint(
            x: physicalPiece.position.x * scale,
            y: physicalPiece.position.y * scale
        )
        
        // Smooth position update - no jitter
        cvNode.position = cvPos
        cvNode.zRotation = physicalPiece.zRotation  // Use actual rotation from physical piece
        
        // Update flip state if it's a PuzzlePieceNode
        if let cvPuzzlePiece = cvNode as? PuzzlePieceNode {
            if cvPuzzlePiece.isFlipped != physicalPiece.isFlipped {
                cvPuzzlePiece.flip()  // Sync flip state
            }
            
            // Update visual state based on piece state
            if let state = pieceStates[pieceId] {
                updateCVPieceVisualState(cvPuzzlePiece, state: state)
            }
        }
    }
    
    private func createCVVisualization(for pieceId: String) {
        // Find the original piece to get its type
        guard let originalPiece = availablePieces.first(where: { $0.name == pieceId }),
              let pieceType = originalPiece.pieceType else {
            return
        }
        
        // Create a visual copy for mini CV display
        let cvPiece = PuzzlePieceNode(pieceType: pieceType)
        cvPiece.name = "cv_\(pieceId)"
        
        // Scale down significantly for mini display
        let miniDisplaySize: CGFloat = min(size.width * 0.25, 150)
        let miniScale: CGFloat = miniDisplaySize / (size.width * 0.8) * 0.8  // Extra scaling for piece size
        cvPiece.setScale(miniScale)
        
        cvPiece.alpha = 0.9
        cvPiece.isUserInteractionEnabled = false  // No interaction in CV section
        
        // Sync initial flip state
        if originalPiece.isFlipped {
            cvPiece.flip()
        }
        
        cvMiniDisplay.addChild(cvPiece)
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
        
        // Clear all child nodes except backgrounds and mini CV display
        targetSection.children.forEach { node in
            // Keep backgrounds, labels, and the CV mini display itself
            if node !== cvMiniDisplay && !(node is SKShapeNode) && !(node is SKLabelNode) {
                node.removeFromParent()
            }
        }
        
        // Clear CV mini display contents except its background
        cvMiniDisplay?.children.forEach { node in
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
        
        // Scale for fitting in the target section (keep current size)
        let displayScale: CGFloat = 0.8  // Doubled from 0.4 for better visibility
        self.targetDisplayScale = displayScale
        
        // Create a container to center the puzzle in the main area
        let puzzleContainer = SKNode()
        puzzleContainer.name = "puzzleContainer"
        puzzleContainer.position = CGPoint(x: 0, y: 0)  // Center of target section
        puzzleContainer.zPosition = 1
        targetSection.addChild(puzzleContainer)
        
        for target in puzzle.targetPieces {
            // Create properly transformed silhouette
            let silhouette = createTargetSilhouette(target, boundsCenterSK: boundsCenterSK, displayScale: displayScale)
            puzzleContainer.addChild(silhouette)  // Add to container instead of directly to section
            targetSilhouettes[target.id] = silhouette
        }
    }
    
    private func createTargetSilhouette(_ target: GamePuzzleData.TargetPiece, boundsCenterSK: CGPoint, displayScale: CGFloat) -> SKShapeNode {
        // BAKED-VERTICES APPROACH: Apply transform directly to vertices
        
        // Log silhouette info
        let rotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
        let isFlipped = target.transform.a * target.transform.d - target.transform.b * target.transform.c < 0
        print("[SILHOUETTE] Creating \(target.pieceType.rawValue): rotation=\(Int(rotation * 180 / .pi))°, flipped=\(isFlipped)")
        
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
        // Start with light gray outline, will turn green when completed
        silhouette.fillColor = .clear  // Start with no fill
        silhouette.strokeColor = .systemGray2
        silhouette.lineWidth = 2
        silhouette.alpha = 0.6
        silhouette.name = "target_\(target.id)"
        silhouette.position = .zero  // Already positioned via vertices
        
        // Store the actual centroid position and expected rotation for validation
        silhouette.userData = silhouette.userData ?? [:]
        silhouette.userData!["centroidSK"] = NSValue(cgPoint: CGPoint(
            x: (centroidSK.x - boundsCenterSK.x) * displayScale,
            y: (centroidSK.y - boundsCenterSK.y) * displayScale
        ))
        silhouette.userData!["expectedZRotationSK"] = TangramPoseMapper.spriteKitAngle(
            fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform)
        )
        silhouette.userData!["isFlipped"] = target.transform.a * target.transform.d - target.transform.b * target.transform.c < 0
        
        return silhouette
    }
    
    private func createPhysicalPieces(_ puzzle: GamePuzzleData) {
        // Position pieces in LEFT ORGANIZATION ZONE for natural workflow
        // Physical world section is centered at (halfWidth, bottomSectionY)
        // Left third is the organization zone where pieces start
        
        // Calculate organization zone bounds (left 1/3 of physical world)
        let sectionWidth = size.width
        let zoneWidth = sectionWidth / 3
        let leftZoneCenter = -(sectionWidth / 2) + (zoneWidth / 2)
        
        // Piece positioning parameters
        let pieceSpacing: CGFloat = 70  // Tighter spacing in organization zone
        let pieceScale: CGFloat = 0.8  // Scale for visibility
        
        // Calculate grid layout for organization zone
        let totalPieces = puzzle.targetPieces.count
        let maxCols = 3  // 3 columns max in organization zone
        let rows = (totalPieces + maxCols - 1) / maxCols  // Ceiling division
        let cols = min(totalPieces, maxCols)
        
        // Center the grid in the organization zone
        let gridWidth = CGFloat(cols - 1) * pieceSpacing
        let startX = leftZoneCenter - gridWidth / 2
        let startY: CGFloat = 0  // Center vertically
        
        // Removed zone overlay visuals per design feedback
        
        for (index, target) in puzzle.targetPieces.enumerated() {
            let piece = PuzzlePieceNode(pieceType: target.pieceType)
            piece.name = "piece_\(target.pieceType)"
            
            // CRITICAL: Bind this piece to its specific target ID
            piece.userData = piece.userData ?? [:]
            piece.userData!["assignedTargetId"] = target.id
            piece.userData!["pieceType"] = target.pieceType.rawValue
            
            // Scale piece to match display requirements
            piece.setScale(pieceScale)
            
            // Position pieces in organization zone grid
            let row = index / maxCols
            let col = index % maxCols
            
            // Break down complex expression for compiler
            let colOffset = CGFloat(col) * pieceSpacing
            let xPos = startX + colOffset
            
            let rowFloat = CGFloat(row)
            let rowsFloat = CGFloat(rows)
            let rowOffset = (rowFloat - rowsFloat/2.0) * pieceSpacing
            let yPos = startY + rowOffset
            
            // Ensure fully on-screen: clamp by estimated radius
            let pieceRadius: CGFloat = TangramGameConstants.visualScale * 1.2
            let halfW = physicalBounds.width / 2
            let halfH = physicalBounds.height / 2
            let clampedX = max(-halfW + pieceRadius, min(halfW - pieceRadius, xPos))
            let clampedY = max(-halfH + pieceRadius, min(halfH - pieceRadius, yPos))
            piece.position = CGPoint(x: clampedX, y: clampedY)
            
            // Mild randomized rotation for variety
            piece.zRotation = CGFloat.random(in: -(.pi/4)...(.pi/4))
            
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
            
            print("[PIECE] Placed \(selected.pieceType?.rawValue ?? "unknown") at (\(Int(selected.position.x)), \(Int(selected.position.y))), rotation: \(Int(selected.zRotation * 180 / .pi))°")
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
        
        // Apply anchor mapping if available for the piece's group
        let mappedPosition: CGPoint = {
            guard let group = constructionGroups.first(where: { $0.pieces.contains(piece.name ?? "") }),
                  let mapping = mappingService.mapping(for: group.id),
                  let anchorNode = availablePieces.first(where: { $0.name == mapping.anchorPieceId }) else {
                return pieceScenePos
            }
            let anchorScenePos = physicalWorldSection.convert(anchorNode.position, to: self)
            return mappingService.mapPieceToTargetSpace(
                piecePositionScene: pieceScenePos,
                pieceRotation: piece.zRotation,
                pieceIsFlipped: piece.isFlipped,
                mapping: mapping,
                anchorPositionScene: anchorScenePos
            ).positionSK
        }()
        
        for target in puzzle.targetPieces where target.pieceType == pieceType && !validatedTargets.contains(target.id) {
            // Get target CENTROID position in scene space (not node position which is 0,0)
            guard let targetNode = targetSilhouettes[target.id] else { continue }
            let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
            let targetScenePos = targetSection.convert(targetCentroid, to: self)
            
            let distance = hypot(targetScenePos.x - mappedPosition.x, targetScenePos.y - mappedPosition.y)
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
        
        // Apply anchor mapping if available for the piece's group
        let mappedPosition: CGPoint = {
            guard let group = constructionGroups.first(where: { $0.pieces.contains(piece.name ?? "") }),
                  let mapping = mappingService.mapping(for: group.id),
                  let anchorNode = availablePieces.first(where: { $0.name == mapping.anchorPieceId }) else {
                return pieceScenePos
            }
            let anchorScenePos = physicalWorldSection.convert(anchorNode.position, to: self)
            return mappingService.mapPieceToTargetSpace(
                piecePositionScene: pieceScenePos,
                pieceRotation: piece.zRotation,
                pieceIsFlipped: piece.isFlipped,
                mapping: mapping,
                anchorPositionScene: anchorScenePos
            ).positionSK
        }()
        
        for target in puzzle.targetPieces where target.pieceType == pieceType && !validatedTargets.contains(target.id) {
            guard let targetNode = targetSilhouettes[target.id] else { continue }
            
            // Get target CENTROID position (not node position which is 0,0)
            let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
            let targetScenePos = targetSection.convert(targetCentroid, to: self)
            
            let distance = hypot(targetScenePos.x - mappedPosition.x, targetScenePos.y - mappedPosition.y)
            
            if distance < 50 {  // Snap distance
                // If we have anchor mapping, snap to the inverse-mapped position
                let snapPos: CGPoint
                if let group = constructionGroups.first(where: { $0.pieces.contains(piece.name ?? "") }),
                   let mapping = mappingService.mapping(for: group.id),
                   let anchorNode = availablePieces.first(where: { $0.name == mapping.anchorPieceId }) {
                    let anchorScenePos = physicalWorldSection.convert(anchorNode.position, to: self)
                    let inverseScene = mappingService.inverseMapTargetToPhysical(
                        mapping: mapping,
                        anchorScenePos: anchorScenePos,
                        targetScenePos: targetScenePos
                    )
                    snapPos = self.convert(inverseScene, to: physicalWorldSection)
                } else {
                    // Direct snap for pieces placed on silhouette
                    snapPos = self.convert(targetScenePos, to: physicalWorldSection)
                }
                
                // Animate snap
                let snapAction = SKAction.move(to: snapPos, duration: 0.1)
                piece.run(snapAction)
                
                // Snap rotation using feature angles (same formula as hints)
                let targetRotation = (targetNode.userData?["expectedZRotationSK"] as? CGFloat) ?? TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
                
                // Compute desired rotation using feature angles
                let canonicalTarget: CGFloat = pieceType.isTriangle ? (.pi/4) : 0  // 45° for triangles
                let canonicalPiece: CGFloat = pieceType.isTriangle ? (3 * .pi/4) : 0  // 135° for triangles
                let pieceLocalFeatureAngle = piece.isFlipped ? -canonicalPiece : canonicalPiece
                let targetFeatureAngle = targetRotation + canonicalTarget
                var desiredZ = TangramRotationValidator.normalizeAngle(targetFeatureAngle - pieceLocalFeatureAngle)
                
                // Apply mapping delta if in a group
                if let group = constructionGroups.first(where: { $0.pieces.contains(piece.name ?? "") }),
                   let mapping = mappingService.mapping(for: group.id) {
                    desiredZ = desiredZ - mapping.rotationDelta
                }
                
                let rotateAction = SKAction.rotate(toAngle: desiredZ, duration: 0.1, shortestUnitArc: true)
                piece.run(rotateAction)
                
                // Handle flip for parallelogram
                if pieceType == .parallelogram {
                    let targetFlipped = targetNode.userData?["isFlipped"] as? Bool ?? false
                    var shouldFlip = targetFlipped
                    if let group = constructionGroups.first(where: { $0.pieces.contains(piece.name ?? "") }),
                       let mapping = mappingService.mapping(for: group.id) {
                        shouldFlip = mapping.flipParity ? !targetFlipped : targetFlipped
                    }
                    if shouldFlip != piece.isFlipped { piece.flip() }
                }
                
                break
            }
        }
    }
    
    private func validatePlacedPiece(_ piece: PuzzlePieceNode) {
        guard let puzzle = puzzle,
              let pieceType = piece.pieceType,
              let pieceId = piece.name else { return }
        
        // No zone gating: validation is intent-based (clustering + stability), not screen regions
        
        // Update construction groups
        constructionGroups = groupManager.updateGroups(with: availablePieces)
        
        // Find this piece's group
        let pieceGroup = constructionGroups.first { $0.pieces.contains(pieceId) }
        
        // Validation gating: ensure group exists; we allow first piece mapping and direct validation
        if let group = pieceGroup {
            print("[VALIDATION] Group: \(group.pieces.count) pieces, confidence: \(String(format: "%.2f", group.confidence))")
        }
        
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
        
        // Get piece's current position in scene coordinates
        let pieceScenePos = physicalWorldSection.convert(piece.position, to: self)
        
        // Calculate feature angles for validation
        let localFeatureAngle = piece.userData?["localFeatureAngleSK"] as? CGFloat ?? 0
        let pieceFeatureAngle = piece.zRotation + localFeatureAngle
        
        // ANCHOR-BASED VALIDATION
        // Establish or refresh per-group anchor mapping
        if let group = pieceGroup {
            // Select anchor (prefer validated > largest stable > most central)
            // Use all pieces in the group (no spatial zone filtering)
            let groupNodes = availablePieces.filter { node in
                guard let id = node.name else { return false }
                return group.pieces.contains(id)
            }
            let validatedNodes = groupNodes.filter { node in
                guard let id = node.name, let st = pieceStates[id] else { return false }
                if case .validated = st.state { return true }
                return false
            }
            let rankedAnchor: PuzzlePieceNode = validatedNodes.first ?? groupNodes.sorted { a, b in
                func rank(_ t: TangramPieceType?) -> Int {
                    switch t {
                    case .largeTriangle1, .largeTriangle2: return 3
                    case .mediumTriangle: return 2
                    case .square, .parallelogram: return 2
                    case .smallTriangle1, .smallTriangle2: return 1
                    default: return 0
                    }
                }
                if rank(a.pieceType) != rank(b.pieceType) { return rank(a.pieceType) > rank(b.pieceType) }
                let c = group.centerOfMass
                let da = hypot(a.position.x - c.x, a.position.y - c.y)
                let db = hypot(b.position.x - c.x, b.position.y - c.y)
                return da < db
            }.first ?? piece
            // If no mapping exists or anchor changed, create mapping
            if mappingService.mapping(for: group.id)?.anchorPieceId != rankedAnchor.name {
                let anchorType = rankedAnchor.pieceType ?? pieceType
                let anchorScenePos = physicalWorldSection.convert(rankedAnchor.position, to: self)
                let mapping = mappingService.establishOrUpdateMapping(
                    groupId: group.id,
                    groupPieceIds: group.pieces,
                    pickAnchor: { () -> (anchorPieceId: String, anchorPositionScene: CGPoint, anchorRotation: CGFloat, anchorIsFlipped: Bool, anchorPieceType: TangramPieceType) in
                        let isFlipped = pieceStates[rankedAnchor.name ?? ""]?.isFlipped ?? false
                        return (rankedAnchor.name ?? "", anchorScenePos, rankedAnchor.zRotation, isFlipped, anchorType)
                    },
                    candidateTargets: { () -> [(target: GamePuzzleData.TargetPiece, centroidScene: CGPoint, expectedZ: CGFloat, isFlipped: Bool)] in
                        puzzle.targetPieces
                            .filter { $0.pieceType == anchorType && !mappingService.consumedTargets(groupId: group.id).contains($0.id) }
                            .compactMap { t in
                                guard let tNode = targetSilhouettes[t.id] else { return nil }
                                let centroid = (tNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                                let tScene = targetSection.convert(centroid, to: self)
                                let z = (tNode.userData?["expectedZRotationSK"] as? CGFloat) ?? 0
                                let flipped = (tNode.userData?["isFlipped"] as? Bool) ?? false
                                return (t, tScene, z, flipped)
                            }
                    }
                )
                if let m = mapping {
                    // Update anchor assignment and visuals
                    rankedAnchor.userData?["assignedTargetId"] = m.anchorTargetId
                    if let tN = targetSilhouettes[m.anchorTargetId] { applyValidatedFill(to: tN, for: anchorType) }
                    eventBus.emit(.validationChanged(pieceId: m.anchorTargetId, isValid: true))
                }
            }
        }
        
        // For non-anchor pieces, use per-group mapping if available
        if let group = pieceGroup, let mapping = mappingService.mapping(for: group.id) {
            // Apply anchor transformation to get expected target position
            // mappedPosition = anchorTarget + R(delta) * (piece - anchorPiece)
            guard let anchorNode = availablePieces.first(where: { $0.name == mapping.anchorPieceId }) else { return }
            let anchorScenePos = physicalWorldSection.convert(anchorNode.position, to: self)
            let rel = CGVector(dx: pieceScenePos.x - anchorScenePos.x, dy: pieceScenePos.y - anchorScenePos.y)
            let cosD = cos(mapping.rotationDelta)
            let sinD = sin(mapping.rotationDelta)
            let rotatedRel = CGVector(dx: rel.dx * cosD - rel.dy * sinD, dy: rel.dx * sinD + rel.dy * cosD)
            let mappedPosition = CGPoint(x: anchorScenePos.x + mapping.translationOffset.x + rotatedRel.dx,
                                         y: anchorScenePos.y + mapping.translationOffset.y + rotatedRel.dy)
            let mappedRotation = piece.zRotation + mapping.rotationDelta
            let mappedFlipped = mapping.flipParity ? !piece.isFlipped : piece.isFlipped
            
                // Enforce instance-based binding: use assignedTargetId only
                let assignedId = piece.userData?["assignedTargetId"] as? String
                let availableTargets = puzzle.targetPieces.filter { target in
                    target.id == assignedId && !mappingService.consumedTargets(groupId: group.id).contains(target.id)
                }
            
            var bestMatch: (target: GamePuzzleData.TargetPiece, distance: CGFloat)?
            
            for target in availableTargets {
                guard let targetNode = targetSilhouettes[target.id] else { continue }
                
                guard let targetPose = resolvePose(for: target) else { continue }
                let targetScenePos = targetSection.convert(targetPose.centroidInContainer, to: self)
                let targetRotation = targetPose.zRotationSK
                let distance = hypot(mappedPosition.x - targetScenePos.x, mappedPosition.y - targetScenePos.y)
                let isValid = mappingService.validateMapped(
                    mappedPose: (mappedPosition, mappedRotation, mappedFlipped),
                    pieceType: pieceType,
                    target: target,
                    targetCentroidScene: targetScenePos,
                    validator: validator
                )
                if isValid {
                    if bestMatch == nil || distance < bestMatch!.distance {
                        bestMatch = (target, distance)
                    }
                }
            }
            
            if let match = bestMatch {
                // Validation successful with anchor-based mapping!
                mappingService.markTargetConsumed(groupId: group.id, targetId: match.target.id)
                completedPieces.insert(match.target.id)
                
                var updatedState = state
                updatedState.markAsValidated(connections: [])
                pieceStates[pieceId] = updatedState
                piece.pieceState = updatedState
                piece.updateStateIndicator()
                
                // Update target visual
                if let targetNode = targetSilhouettes[match.target.id] {
                    applyValidatedFill(to: targetNode, for: pieceType)
                    
                    // Pulse effect
                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.1, duration: 0.1),
                        SKAction.scale(to: 1.0, duration: 0.1)
                    ])
                    targetNode.run(pulse)
                }
                
                // Store which target this piece validated against
                piece.userData!["validatedTargetId"] = match.target.id
                mappingService.appendPair(groupId: group.id, pieceId: pieceId, targetId: match.target.id)
                if mappingService.pairs(groupId: group.id).count >= 2,
                   let anchorId = mapping.anchorPieceId as String?,
                   let anchorTargetId = mapping.anchorTargetId as String? {
                    _ = mappingService.refineMapping(
                        groupId: group.id,
                        pairs: mappingService.pairs(groupId: group.id),
                        anchorPieceId: anchorId,
                        anchorTargetId: anchorTargetId,
                        pieceScenePosProvider: { pid in
                            self.availablePieces.first(where: { $0.name == pid }).map { self.physicalWorldSection.convert($0.position, to: self) }
                        },
                        targetScenePosProvider: { tid in
                            self.targetSilhouettes[tid].map {
                                let c = ($0.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                                return self.targetSection.convert(c, to: self)
                            }
                        }
                    )
                }
                
                showPieceCelebration(piece)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                eventBus.emit(.validationChanged(pieceId: match.target.id, isValid: true))
                onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
                
                // Check if puzzle complete
                if completedPieces.count == puzzle.targetPieces.count {
                    showPuzzleCompleteCelebration()
                    onPuzzleCompleted?()
                }
                
                print("[VALIDATION] ✅ Validated: \(pieceType.rawValue) → target \(match.target.id)")
                return
            }
        }
        
        // If no anchor mapping yet or validation failed, try direct validation (tight fallback)
        let assignedId = piece.userData?["assignedTargetId"] as? String
        let groupTargetsConsumed = pieceGroup.map { mappingService.consumedTargets(groupId: $0.id) } ?? []
        let availableTargets = puzzle.targetPieces.filter { target in
            target.id == assignedId && !groupTargetsConsumed.contains(target.id)
        }
        
        for target in availableTargets {
            guard let targetNode = targetSilhouettes[target.id] else { continue }
            
            guard let tPose = resolvePose(for: target) else { continue }
            let targetScenePos = targetSection.convert(tPose.centroidInContainer, to: self)
            let targetRotation = tPose.zRotationSK
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
                // Direct validation successful (piece placed directly on silhouette)
                validatedTargets.insert(target.id)
                completedPieces.insert(target.id)
                eventBus.emit(.validationChanged(pieceId: target.id, isValid: true))
                
                // Update piece state to validated
                var updatedState = state
                updatedState.markAsValidated(connections: [])
                pieceStates[pieceId] = updatedState
                piece.pieceState = updatedState
                piece.updateStateIndicator()
                
                // Store which target this piece validated against
                piece.userData!["validatedTargetId"] = target.id
                if let group = pieceGroup {
                    mappingService.markTargetConsumed(groupId: group.id, targetId: target.id)
                }
                
                // Update target visual
                applyValidatedFill(to: targetNode, for: pieceType)
                
                // Pulse effect on target
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                targetNode.run(pulse)
                
                // Add celebration effect on the physical piece
                showPieceCelebration(piece)
                
                // Visual feedback - success haptic
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Check if puzzle complete
                if completedPieces.count == puzzle.targetPieces.count {
                    showPuzzleCompleteCelebration()
                    onPuzzleCompleted?()
                }
                
                // Notify piece completion
                onPieceCompleted?(pieceType.rawValue, piece.isFlipped)
                
                print("[VALIDATION] ✅ Direct validation: \(pieceType.rawValue) → target \(target.id)")
                return
            }
        }
        
        // Validation failed - apply hysteresis before marking invalid
        let current = pieceInvalidStreak[pieceId] ?? 0
        let next = current + 1
        pieceInvalidStreak[pieceId] = next
        if next >= invalidStreakThreshold {
            var updatedState = state
            updatedState.markAsInvalid(reason: .wrongPosition(offset: 100))
            pieceStates[pieceId] = updatedState
            piece.pieceState = updatedState
            piece.updateStateIndicator()
        } else {
            // Keep in validating state, do not penalize yet
            pieceStates[pieceId] = state
            piece.pieceState = state
            piece.updateStateIndicator()
        }
        
        // Record attempt for smart nudging
        nudgeManager.recordAttempt(for: pieceId, at: piece.position)
        
        // Record attempt in construction group
        if let group = pieceGroup {
            groupManager.recordAttempt(for: pieceId, in: group.id)
        }
        
        // Check if we should show a smart nudge
        if let group = pieceGroup {
            let shouldNudge = nudgeManager.shouldShowNudge(
                for: piece,
                in: group
            )
            
            if shouldNudge {
                let nudgeLevel = nudgeManager.determineNudgeLevel(
                    confidence: group.confidence,
                    attempts: group.attemptHistory[pieceId] ?? 0,
                    state: group.validationState
                )
                
                // Find a target to nudge towards (prefer unvalidated targets of same type)
                if let target = puzzle.targetPieces.first(where: { 
                    $0.pieceType == pieceType && !validatedTargets.contains($0.id) 
                }) {
                    if let targetNode = targetSilhouettes[target.id] {
                        // Get actual centroid for correct hint position
                        let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                        let targetPos = targetSection.convert(targetCentroid, to: physicalWorldSection)
                        // Use feature-angle desiredZ so ghost aligns visually with baked silhouette
                        let targetRotation = targetNode.userData?["expectedZRotationSK"] as? CGFloat ?? 0
                        let canonicalTarget: CGFloat = pieceType.isTriangle ? (.pi/4) : 0
                        let canonicalPiece: CGFloat = pieceType.isTriangle ? (3 * .pi/4) : 0
                        let desiredZ = TangramRotationValidator.normalizeAngle(targetRotation + canonicalTarget - canonicalPiece)
                        let nudgeContent = nudgeManager.generateNudge(
                            level: nudgeLevel,
                            failure: .wrongPosition(offset: 50),
                            targetInfo: (position: targetPos, rotation: desiredZ)
                        )
                        
                        // Show nudge in top panel near the target piece
                        showSmartNudgeInTarget(targetNode: targetNode, content: nudgeContent, pieceType: pieceType)
                        nudgeManager.recordNudgeShown(for: pieceId)
                    }
                }
            }
        }
        
        // Not valid - emit event
        eventBus.emit(.validationChanged(pieceId: pieceId, isValid: false))
    }
    
    // MARK: - Nudge System
    
    private func showSmartNudgeInTarget(targetNode: SKShapeNode, content: NudgeContent, pieceType: TangramPieceType) {
        // Remove any existing nudge for this target
        targetSection.childNode(withName: "nudge_\(targetNode.name ?? "")")?.removeFromParent()
        
        guard content.level != .none else { return }
        
        let nudgeNode = SKNode()
        nudgeNode.name = "nudge_\(targetNode.name ?? "")"
        // Position nudge at the actual centroid, not at (0,0)
        let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
        nudgeNode.position = targetCentroid
        nudgeNode.zPosition = 1000
        
        // Visual nudge based on level
        switch content.level {
        case .visual:
            // Just highlight the target piece
            let highlight = SKShapeNode()
            highlight.path = targetNode.path
            highlight.strokeColor = .systemYellow
            highlight.lineWidth = 3
            highlight.fillColor = .clear
            highlight.glowWidth = 5
            nudgeNode.addChild(highlight)
            
            // Pulse animation
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.5),
                SKAction.fadeAlpha(to: 1.0, duration: 0.5)
            ]))
            highlight.run(pulse)
            
        case .gentle, .specific:
            // Show text hint above the target
            let label = SKLabelNode(text: content.message)
            label.fontSize = 16
            label.fontColor = .white
            label.fontName = "System-Bold"
            
            let background = SKShapeNode(rectOf: CGSize(width: label.frame.width + 20, height: 30), cornerRadius: 15)
            background.fillColor = nudgeLevelColor(content.level)
            background.strokeColor = .clear
            background.position = CGPoint(x: 0, y: 50)
            
            label.position = CGPoint(x: 0, y: 45)
            
            nudgeNode.addChild(background)
            nudgeNode.addChild(label)
            
        case .directed:
            // Show arrow pointing to correct position
            if let visualHint = content.visualHint,
               case .arrow(let direction) = visualHint {
                let arrowNode = createDirectionalArrow(angle: direction)
                arrowNode.position = CGPoint(x: 0, y: -30)
                arrowNode.strokeColor = SKColor.systemYellow
                arrowNode.lineWidth = 2
                nudgeNode.addChild(arrowNode)
                
                // Bounce animation
                let bounce = SKAction.repeatForever(SKAction.sequence([
                    SKAction.moveBy(x: 5, y: 0, duration: 0.5),
                    SKAction.moveBy(x: -5, y: 0, duration: 0.5)
                ]))
                arrowNode.run(bounce)
            }
            
            // Also show message
            if !content.message.isEmpty {
                let label = SKLabelNode(text: content.message)
                label.fontSize = 14
                label.fontColor = .systemYellow
                label.position = CGPoint(x: 0, y: 60)
                nudgeNode.addChild(label)
            }
            
        case .solution:
            // Show ghost piece in correct position
            if let visualHint = content.visualHint,
               case .ghostPiece(let position, let rotation) = visualHint {
                let ghostPiece = createGhostPiece(pieceType: pieceType, at: position, rotation: rotation)
                ghostPiece.alpha = 0.4
                nudgeNode.addChild(ghostPiece)
                
                // Fade in/out animation
                let fadeAnimation = SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.2, duration: 1.0),
                    SKAction.fadeAlpha(to: 0.6, duration: 1.0)
                ]))
                ghostPiece.run(fadeAnimation)
            }
            
        default:
            break
        }
        
        // Add text message if present and not already added
        if !content.message.isEmpty && content.level == .visual {
            let label = SKLabelNode(text: content.message)
            label.fontSize = 14
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: 40)
            nudgeNode.addChild(label)
        }
        
        // Add to target section
        if let container = targetSection.childNode(withName: "puzzleContainer") {
            container.addChild(nudgeNode)
        } else {
            targetSection.addChild(nudgeNode)
        }
        
        // Auto-remove after duration
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: content.duration - 0.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        nudgeNode.run(fadeOut)
    }
    
    private func showSmartNudge(for piece: PuzzlePieceNode, content: NudgeContent) {
        // Remove any existing nudge
        piece.childNode(withName: "nudge")?.removeFromParent()
        
        // Don't show empty nudges
        if content.level == .none { return }
        
        // Create nudge node
        let nudgeNode = SKNode()
        nudgeNode.name = "nudge"
        nudgeNode.zPosition = 100
        
        // Apply visual hint
        if let hint = content.visualHint {
            switch hint {
            case .colorChange(let color, let alpha):
                piece.shapeNode?.fillColor = color.withAlphaComponent(alpha)
                
            case .pulse(let intensity):
                let scale = 1.0 + (0.2 * intensity)
                let pulse = SKAction.sequence([
                    SKAction.scale(to: scale, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                piece.run(SKAction.repeat(pulse, count: 3))
                
            case .arrow(let direction):
                let arrow = createDirectionalArrow(angle: direction)
                nudgeNode.addChild(arrow)
                
            case .ghostPiece(let position, let rotation):
                let ghost = createGhostPiece(type: piece.pieceType!, at: position, rotation: rotation)
                physicalWorldSection.addChild(ghost)
                
                // Auto-remove ghost after duration
                ghost.run(SKAction.sequence([
                    SKAction.wait(forDuration: content.duration),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.removeFromParent()
                ]))
            }
        }
        
        // Add text message if present
        if !content.message.isEmpty {
            let label = SKLabelNode(text: content.message)
            label.fontSize = 14
            label.fontColor = .white
            label.fontName = "System-Bold"
            
            let background = SKShapeNode(rectOf: CGSize(width: label.frame.width + 20, height: 25), cornerRadius: 12)
            background.fillColor = nudgeLevelColor(content.level)
            background.strokeColor = .clear
            background.position = CGPoint(x: 0, y: 40)
            
            label.position = CGPoint(x: 0, y: 35)
            
            nudgeNode.addChild(background)
            nudgeNode.addChild(label)
        }
        
        piece.addChild(nudgeNode)
        
        // Auto-remove after duration
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: content.duration - 0.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        nudgeNode.run(fadeOut)
    }
    
    private func nudgeLevelColor(_ level: NudgeLevel) -> SKColor {
        switch level {
        case .none: return .clear
        case .visual: return .systemBlue
        case .gentle: return .systemTeal
        case .specific: return .systemOrange
        case .directed: return .systemYellow
        case .solution: return .systemGreen
        }
    }
    
    private func updateCVPieceVisualState(_ cvPiece: PuzzlePieceNode, state: PieceState) {
        // Update CV piece appearance based on validation state
        switch state.state {
        case .validated:
            // Green glow for validated pieces
            cvPiece.shapeNode?.strokeColor = .systemGreen
            cvPiece.shapeNode?.lineWidth = 2
            cvPiece.alpha = 1.0
        case .invalid:
            // Red highlight for invalid pieces
            cvPiece.shapeNode?.strokeColor = .systemRed
            cvPiece.shapeNode?.lineWidth = 2
            cvPiece.alpha = 0.8
        case .validating:
            // Yellow for validating
            cvPiece.shapeNode?.strokeColor = .systemYellow
            cvPiece.shapeNode?.lineWidth = 1
            cvPiece.alpha = 0.9
        case .placed:
            // Blue for placed pieces
            cvPiece.shapeNode?.strokeColor = .systemBlue
            cvPiece.shapeNode?.lineWidth = 1
            cvPiece.alpha = 0.9
        default:
            // Default appearance
            cvPiece.shapeNode?.strokeColor = .white
            cvPiece.shapeNode?.lineWidth = 1
            cvPiece.alpha = 0.7
        }
    }
    
    private func showCVValidationFeedback(pieceId: String, isValid: Bool) {
        guard let cvPiece = cvPieces[pieceId] else { return }
        
        if isValid {
            // Success animation - pulse and sparkle
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15)
            ])
            
            // Create sparkle effect
            let sparkle = SKEmitterNode()
            sparkle.particleTexture = SKTexture(imageNamed: "spark")
            sparkle.particleBirthRate = 100
            sparkle.numParticlesToEmit = 20
            sparkle.particleLifetime = 0.5
            sparkle.particleScale = 0.1
            sparkle.particleScaleSpeed = -0.2
            sparkle.particleColor = .systemGreen
            sparkle.particleColorBlendFactor = 1.0
            sparkle.particleAlpha = 0.8
            sparkle.particleAlphaSpeed = -1.6
            sparkle.position = .zero
            sparkle.zPosition = 100
            
            cvPiece.addChild(sparkle)
            cvPiece.run(pulse)
            
            // Remove sparkle after animation
            sparkle.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
            
            // Add checkmark
            let checkmark = SKLabelNode(text: "✓")
            checkmark.fontSize = 12
            checkmark.fontColor = .systemGreen
            checkmark.position = CGPoint(x: 0, y: -20)
            checkmark.zPosition = 101
            cvPiece.addChild(checkmark)
            
            checkmark.setScale(0)
            checkmark.run(SKAction.sequence([
                SKAction.scale(to: 1.0, duration: 0.2),
                SKAction.wait(forDuration: 1.5),
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        } else {
            // Failure feedback - shake
            let shake = SKAction.sequence([
                SKAction.moveBy(x: -3, y: 0, duration: 0.05),
                SKAction.moveBy(x: 6, y: 0, duration: 0.1),
                SKAction.moveBy(x: -6, y: 0, duration: 0.1),
                SKAction.moveBy(x: 3, y: 0, duration: 0.05)
            ])
            cvPiece.run(shake)
        }
    }
    
    private func showPieceCelebration(_ piece: PuzzlePieceNode) {
        // Create success effect on the piece
        let successNode = SKNode()
        successNode.position = .zero
        successNode.zPosition = 1000
        
        // Green glow effect
        let glow = SKShapeNode(circleOfRadius: 50)
        glow.fillColor = .systemGreen
        glow.strokeColor = .clear
        glow.alpha = 0.5
        successNode.addChild(glow)
        
        // Animate glow
        let glowAnimation = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        glow.run(glowAnimation)
        
        // Add checkmark
        let checkmark = SKLabelNode(text: "✅")
        checkmark.fontSize = 30
        checkmark.position = CGPoint(x: 0, y: 0)
        checkmark.zPosition = 1001
        successNode.addChild(checkmark)
        
        // Animate checkmark
        checkmark.setScale(0)
        let checkAnimation = SKAction.sequence([
            SKAction.scale(to: 1.0, duration: 0.2),
            SKAction.wait(forDuration: 1.0),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 20, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        checkmark.run(checkAnimation)
        
        piece.addChild(successNode)
        
        // Also add particles
        if let particles = SKEmitterNode(fileNamed: "Success") {
            particles.position = .zero
            particles.zPosition = 999
            piece.addChild(particles)
            
            particles.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
        }
    }
    
    private func showPuzzleCompleteCelebration() {
        // Create full-screen celebration
        let celebrationNode = SKNode()
        celebrationNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        celebrationNode.zPosition = 10000
        addChild(celebrationNode)
        
        // Add "Puzzle Complete!" text
        let label = SKLabelNode(text: "🎉 Puzzle Complete! 🎉")
        label.fontSize = 40
        label.fontColor = .systemYellow
        label.fontName = "System-Bold"
        label.position = .zero
        celebrationNode.addChild(label)
        
        // Animate text
        label.setScale(0)
        let textAnimation = SKAction.sequence([
            SKAction.scale(to: 1.0, duration: 0.3),
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        label.run(textAnimation)
        
        // Add confetti effect across the screen
        for _ in 0..<20 {
            let confetti = SKLabelNode(text: ["🎊", "🎉", "⭐", "✨", "🌟"].randomElement()!)
            confetti.fontSize = 30
            confetti.position = CGPoint(
                x: CGFloat.random(in: -size.width/2...size.width/2),
                y: size.height/2 + 50
            )
            celebrationNode.addChild(confetti)
            
            let fall = SKAction.sequence([
                SKAction.moveBy(x: CGFloat.random(in: -50...50), 
                               y: -size.height - 100, 
                               duration: Double.random(in: 2.0...4.0)),
                SKAction.removeFromParent()
            ])
            confetti.run(fall)
        }
        
        // Clean up celebration node after animation
        celebrationNode.run(SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.removeFromParent()
        ]))
    }
    
    private func createGhostPiece(pieceType: TangramPieceType, at position: CGPoint, rotation: CGFloat) -> SKShapeNode {
        // Create a semi-transparent outline of the piece
        let vertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(vertices, by: TangramGameConstants.visualScale * 0.8)
        
        let path = CGMutablePath()
        if let first = scaledVertices.first {
            path.move(to: first)
            for vertex in scaledVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        let ghost = SKShapeNode(path: path)
        ghost.strokeColor = .systemGreen
        ghost.lineWidth = 2
        ghost.fillColor = .systemGreen.withAlphaComponent(0.2)
        ghost.position = position
        ghost.zRotation = rotation
        ghost.name = "ghost_\(pieceType.rawValue)"
        
        return ghost
    }
    
    private func createDirectionalArrow(angle: CGFloat) -> SKShapeNode {
        let arrow = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 30, y: 0))
        path.addLine(to: CGPoint(x: 25, y: 5))
        path.move(to: CGPoint(x: 30, y: 0))
        path.addLine(to: CGPoint(x: 25, y: -5))
        arrow.path = path
        arrow.strokeColor = .systemYellow
        arrow.lineWidth = 3
        arrow.zRotation = angle
        arrow.position = CGPoint(x: 0, y: 0)
        return arrow
    }

    // MARK: - Helpers
    private struct ResolvedPose {
        let centroidInContainer: CGPoint
        let zRotationSK: CGFloat
        let isFlipped: Bool
        let displayScale: CGFloat
    }

    private func resolvePose(for target: GamePuzzleData.TargetPiece) -> ResolvedPose? {
        guard let targetNode = targetSilhouettes[target.id] else { return nil }
        let centroidLocal = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
        // Centroid is stored relative to puzzleContainer coordinates already
        let zRot = targetNode.userData?["expectedZRotationSK"] as? CGFloat ?? TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
        let flipped = targetNode.userData?["isFlipped"] as? Bool ?? false
        return ResolvedPose(centroidInContainer: centroidLocal, zRotationSK: zRot, isFlipped: flipped, displayScale: targetDisplayScale)
    }
    private func applyValidatedFill(to targetNode: SKShapeNode, for pieceType: TangramPieceType) {
        let ui = TangramColors.Sprite.uiColor(for: pieceType)
        targetNode.fillColor = ui.withAlphaComponent(0.7)
        targetNode.alpha = 0.7
    }
    private func tNodeExpectedRotation(for target: GamePuzzleData.TargetPiece) -> CGFloat {
        return TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
    }
    private func tNodeIsFlipped(for target: GamePuzzleData.TargetPiece) -> Bool {
        let det = target.transform.a * target.transform.d - target.transform.b * target.transform.c
        return det < 0
    }

    // Old refinement removed; handled by mappingService
    
    private func createGhostPiece(type: TangramPieceType, at position: CGPoint, rotation: CGFloat) -> SKNode {
        let ghost = PuzzlePieceNode(pieceType: type)
        ghost.position = position
        ghost.zRotation = rotation
        ghost.alpha = 0.3
        ghost.zPosition = -1
        ghost.name = "ghost_hint"
        return ghost
    }
    
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
            // Calculate direction to target - find an unvalidated target of same type
            if let pieceType = piece.pieceType,
               let target = puzzle?.targetPieces.first(where: { 
                   $0.pieceType == pieceType && !validatedTargets.contains($0.id) 
               }),
               let targetNode = targetSilhouettes[target.id] {
                // Use the actual centroid, not the node position
                let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                let targetScenePos = targetSection.convert(targetCentroid, to: self)
                
                // Apply inverse per-group anchor mapping if available
                let targetPhysicalPos: CGPoint = {
                    guard let group = constructionGroups.first(where: { $0.pieces.contains(piece.name ?? "") }),
                          let mapping = mappingService.mapping(for: group.id),
                          let anchorNode = availablePieces.first(where: { $0.name == mapping.anchorPieceId }) else {
                        return self.convert(targetScenePos, to: physicalWorldSection)
                    }
                    let anchorScenePos = physicalWorldSection.convert(anchorNode.position, to: self)
                    let inverseScene = mappingService.inverseMapTargetToPhysical(mapping: mapping, anchorScenePos: anchorScenePos, targetScenePos: targetScenePos)
                    return self.convert(inverseScene, to: physicalWorldSection)
                }()
                
                let direction = CGPoint(
                    x: targetPhysicalPos.x - piece.position.x,
                    y: targetPhysicalPos.y - piece.position.y
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
        if !result.positionValid { return .wrongPosition(offset: distance) }
        if !result.rotationValid { return .wrongRotation(degreesOff: 45) }
        if !result.flipValid { return .needsFlip }
        return .wrongPiece
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
                  piece.name != nil else { continue }
            
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
        
        // Locate the exact target; prefer instance-bound target id for duplicates
        var target: GamePuzzleData.TargetPiece?
        if let existingPiece = availablePieces.first(where: {
            ($0.userData?["pieceType"] as? String) == hint.targetPiece.rawValue &&
            ($0.userData?["validatedTargetId"] == nil)
        }) {
            if let assignedId = existingPiece.userData?["assignedTargetId"] as? String {
                target = puzzle.targetPieces.first(where: { $0.id == assignedId })
            }
        }
        if target == nil {
            // Fallback to first unconsumed target by type
            target = puzzle.targetPieces.first(where: { $0.pieceType == hint.targetPiece && !completedPieces.contains($0.id) })
        }
        guard let targetPiece = target,
              let pose = resolvePose(for: targetPiece) else { return }
        print("[HINT] Showing hint for \(hint.targetPiece.rawValue) → target \(targetPiece.id)")
        
        // Create hint visualization in TARGET section (silhouette area) for clarity
        let hintPiece = PuzzlePieceNode(pieceType: hint.targetPiece)
        hintPiece.alpha = 0.0
        hintPiece.isUserInteractionEnabled = false
        hintPiece.zPosition = 500
        
        // Find starting position - look for an existing piece of this type or use default
        let startPos: CGPoint
        if let existingPiece = availablePieces.first(where: { 
            ($0.userData?["pieceType"] as? String) == hint.targetPiece.rawValue &&
            !($0.userData?["validatedTargetId"] != nil)
        }) {
            // Start from actual piece position, converted into puzzleContainer space
            let pieceScenePos = physicalWorldSection.convert(existingPiece.position, to: self)
            if let container = targetSection.childNode(withName: "puzzleContainer") {
                startPos = container.convert(pieceScenePos, from: self)
            } else {
                startPos = self.convert(pieceScenePos, to: targetSection)
            }
        } else {
            // Start from a default position below the silhouette
            startPos = CGPoint(x: pose.centroidInContainer.x, y: -100)
        }
        
        hintPiece.position = startPos
        if let container = targetSection.childNode(withName: "puzzleContainer") {
            container.addChild(hintPiece)
        } else {
            targetSection.addChild(hintPiece)
        }
        // Scale hint to match silhouette display scale so rotation visually matches
        hintPiece.setScale(pose.displayScale)
        
        // Apply flip if needed for parallelogram BEFORE animation
        if hint.targetPiece == .parallelogram && pose.isFlipped {
            hintPiece.flip()
        }
        
        // Create animation sequence showing the solution path
        let fadeIn = SKAction.fadeAlpha(to: 0.6, duration: 0.3)
        
        // Step 1: Rotate to correct orientation using feature-angle formula
        let canonicalTarget: CGFloat = (hint.targetPiece.isTriangle ? (.pi/4) : 0) // 45° for triangles
        let canonicalPiece: CGFloat = (hint.targetPiece.isTriangle ? (3 * .pi/4) : 0) // 135° for triangles
        let desiredZ = TangramRotationValidator.normalizeAngle(pose.zRotationSK + canonicalTarget - canonicalPiece)
        let rotateAction = SKAction.rotate(toAngle: desiredZ, duration: 0.6, shortestUnitArc: true)
        
        // Step 2: Move to exact position in silhouette (centroid is in container coordinates)
        let moveAction = SKAction.move(to: pose.centroidInContainer, duration: 0.8)
        moveAction.timingMode = .easeInEaseOut
        
        // Step 3: Pulse to show it's in the right place
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.9, duration: 0.3),
            SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        ])
        let pulseRepeat = SKAction.repeat(pulse, count: 3)
        
        // Keep visible for a moment then fade
        let wait = SKAction.wait(forDuration: 0.5)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.4)
        let remove = SKAction.removeFromParent()
        
        // Run full animation sequence
        let fullAnimation = SKAction.sequence([
            fadeIn,
            rotateAction,
            moveAction,
            pulseRepeat,
            wait,
            fadeOut,
            remove
        ])
        
        hintPiece.run(fullAnimation) { [weak self] in
            self?.hintNode = nil
        }
        
        hintNode = hintPiece
        currentHint = (hint.targetPiece, targetPiece.id)
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