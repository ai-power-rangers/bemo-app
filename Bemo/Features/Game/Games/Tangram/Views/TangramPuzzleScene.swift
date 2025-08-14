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
    internal var cvMiniDisplay: SKNode!      // Mini CV display in top-right corner (internal for extensions)
    internal var cvContent: SKNode!          // Content container inside CV mini display (scaled mapping of physical world)
    internal var physicalWorldSection: SKNode! // Bottom - user interaction area (internal for extensions)
    
    // MARK: - Section Bounds
    
    internal var targetBounds: CGRect = .zero
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
    internal var cvPieces: [String: SKNode] = [:]  // Pieces in CV render section (internal for extensions)
    internal var targetSilhouettes: [String: SKShapeNode] = [:]  // Target section silhouettes (internal for validation)
    internal var completedPieces: Set<String> = []  // Internal for extensions
    // Notify VM when validated set changes (to drive connection-aware hints)
    var onValidatedTargetsChanged: ((Set<String>) -> Void)?
    // Difficulty setting from host for consistent tolerances/visuals
    var difficultySetting: UserPreferences.DifficultySetting = .normal
    
    // MARK: - Services
    
    internal let eventBus = CVEventBus.shared  // Internal for extensions
    internal var eventSubscriptionId: UUID?  // Internal for extensions
    internal var frameSubscriptionId: UUID?  // Internal for extensions
    internal let validator = TangramPieceValidator()  // Internal for extensions
    // Removed unused gameplay snapping/preview service for realism
    internal let groupManager = ConstructionGroupManager()  // Internal for extensions
    internal let nudgeManager = SmartNudgeManager()  // Internal for extensions
    internal var constructionGroups: [ConstructionGroup] = []  // Internal for extensions
    // Per-group anchor mapping and associations
    var mappingService: TangramRelativeMappingService = TangramRelativeMappingService()
    
    // MARK: - Unified Validation
    internal var validationBridge: CVValidationBridge?  // Bridge to unified validation engine
    internal var gameViewModel: TangramGameViewModel?  // Reference to view model for difficulty
    internal var pieceInvalidStreak: [String: Int] = [:]  // Internal for extensions
    internal let invalidStreakThreshold = 5  // Internal for extensions
    internal var targetDisplayScale: CGFloat = 0.8  // Internal for extensions
    internal var topMirrorContent: SKNode!  // Top-panel mirror of physical world
    // Orientation feedback handled by validation engine nudges only; no local overlays
    internal var lastMotionAt: [String: TimeInterval] = [:]  // Per-piece last motion timestamp (position/rotation/flip)
    internal let settleDwell: TimeInterval = 0.4  // Seconds to consider a piece settled after last motion
    
    // MARK: - Touch Tracking
    
    private var initialTouchLocation: CGPoint = .zero
    private var initialPieceRotation: CGFloat = 0
    private var isRotating = false
    internal var lastEmittedPositions: [String: CGPoint] = [:]  // Track last emitted position per piece (internal for extensions)
    internal var lastEmittedRotations: [String: CGFloat] = [:]  // Track last emitted rotation per piece (internal for extensions)
    
    // MARK: - Anchor-Based Validation
    
    // Legacy single mapping fields (kept for backward compatibility but unused in new per-group flow)
    private var anchorPieceId: String?
    internal var validatedTargets: Set<String> = []  // Internal for extensions
    // Hysteresis support: remember last valid pose per piece
    internal var lastValidPose: [String: (position: CGPoint, rotation: CGFloat, targetId: String)] = [:]  // Internal for extensions
    
    // MARK: - State Tracking
    
    internal var pieceStates: [String: PieceState] = [:]  // Track state for each piece (internal for extensions)
    private var placementTimer: Timer?  // Timer for detecting placement
    internal var firstMovedPieceId: String?  // Track the anchor piece (internal for extensions)
    
    // MARK: - Rotation Dial
    
    private var rotationDial: TangramRotationDialNode?
    private var isShowingRotationDial: Bool = false
    private var pendingRotationPiece: PuzzlePieceNode?
    private var tapStartTime: TimeInterval = 0
    private var tapStartLocation: CGPoint = .zero
    
    // MARK: - Hints
    
    internal var currentHint: (pieceType: TangramPieceType, targetId: String)?  // Internal for extensions
    internal var hintNode: SKNode?  // Internal for extensions
    
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
        
        // Initialize validation bridge with current difficulty
        validationBridge = CVValidationBridge(scene: self, difficulty: difficultySetting)
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
        
        // Remove mini CV display: pieces render only in the main top panel now
        cvMiniDisplay = SKNode()
        cvContent = SKNode()

        // Top mirror content (shows mirrored physical pieces in the top panel)
        topMirrorContent = SKNode()
        topMirrorContent.name = "topMirrorContent"
        topMirrorContent.position = .zero  // centered in targetSection
        topMirrorContent.zPosition = 2     // above silhouettes so it's clearly visible
        targetSection.addChild(topMirrorContent)
        
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
        
        // Mini CV display background (with a subtle border so we can see it during debugging)
        let miniDisplaySize: CGFloat = min(size.width * 0.25, 150)
        let cvMiniBg = SKShapeNode(rectOf: CGSize(width: miniDisplaySize, height: miniDisplaySize))
        cvMiniBg.fillColor = SKColor.systemBlue.withAlphaComponent(0.1)
        cvMiniBg.strokeColor = SKColor.systemBlue.withAlphaComponent(0.7)
        cvMiniBg.lineWidth = 2
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
        
        // Clear all child nodes except backgrounds, labels, CV mini display, and the top mirror container
        targetSection.children.forEach { node in
            // Keep backgrounds, labels, the CV mini display itself, and the top mirror container
            if node === cvMiniDisplay { return }
            if node === topMirrorContent { return }
            if (node is SKShapeNode) || (node is SKLabelNode) { return }
            node.removeFromParent()
        }
        // Ensure top mirror container exists and is attached, then clear its mirrored children
        if let mirror = topMirrorContent {
            if mirror.parent == nil { targetSection.addChild(mirror) }
            mirror.enumerateChildNodes(withName: "mirror_*") { node, _ in node.removeFromParent() }
        }
        
        // Clear CV mini display contents except its background and persistent content container
        cvMiniDisplay?.children.forEach { node in
            if node.name == "cvContent" { return }
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
        // Precision picking: sort by zPosition (topmost first) and use polygon-accurate hit testing
        // Also enforce a small pick radius around the touch to reduce accidental adjacent selections
        let pickRadius: CGFloat = 12
        let candidates = physicalWorldSection.children.compactMap { $0 as? PuzzlePieceNode }
            .filter { node in
                // Quick reject by distance to centroid
                let d = hypot(node.position.x - physicalLocation.x, node.position.y - physicalLocation.y)
                return d <= max(pickRadius, TangramGameConstants.visualScale * 0.9) // lenient radius near centroid
            }
            .sorted { a, b in a.zPosition > b.zPosition }
        
        if let piece = candidates.first(where: { $0.contains(physicalWorldSection.convert(physicalLocation, to: $0)) })
                    ?? physicalWorldSection.nodes(at: physicalLocation).compactMap({ $0 as? PuzzlePieceNode }).sorted(by: { $0.zPosition > $1.zPosition }).first {
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
                    // Record motion for settle gating
                    userData = userData ?? NSMutableDictionary()
                    lastMotionAt[pieceId] = CACurrentMediaTime()
                    
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
        // Apply small deadzone to reduce jitter causing accidental selection shifts
        let last = selected.position
        let dx = physicalLocation.x - last.x
        let dy = physicalLocation.y - last.y
        if hypot(dx, dy) < 2.0 { return }
        selected.position = CGPoint(x: last.x + dx, y: last.y + dy)
        
        // Update piece state position
        if let pieceId = selected.name {
            if var state = pieceStates[pieceId] {
                state.updatePosition(selected.position, rotation: selected.zRotation)
                pieceStates[pieceId] = state
                selected.pieceState = state
                selected.updateStateIndicator()

                // If this piece was previously validated, moving it should trigger re-check and potential invalidation
                if case .validated = state.state {
                    // Immediately re-validate this piece under current mapping; if it fails, invalidate it
                    // We reuse the same path as placement-time validation
                    validatePlacedPiece(selected)
                }
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
                // Record motion for settle gating
                userData = userData ?? NSMutableDictionary()
                lastMotionAt[pieceId] = CACurrentMediaTime()
                
                // Also emit CV frame event for top-right display
                emitCVFrameUpdate()
            }
        }
        
        // Snapping removed
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
        
        // Snapping removed
        
        // Mark state to PLACED at touch end (we already use a short placement delay to confirm)
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
            // Record motion end time
            userData = userData ?? NSMutableDictionary()
            lastMotionAt[pieceId] = CACurrentMediaTime()
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
                    // Record motion for settle gating
                    lastMotionAt[pieceId] = CACurrentMediaTime()
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
    
    // MARK: - Nudge System
    
    internal func showSmartNudgeInTarget(targetNode: SKShapeNode, content: NudgeContent, pieceType: TangramPieceType) {
        // Enforce only ONE nudge visible at a time in the silhouette area
        targetSection.enumerateChildNodes(withName: "nudge_*") { node, _ in node.removeFromParent() }
        if let container = targetSection.childNode(withName: "puzzleContainer") {
            container.enumerateChildNodes(withName: "nudge_*") { node, _ in node.removeFromParent() }
        }
        // Remove any existing nudge for this target (redundant safety)
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
            // Optional ghost demo for flip
            if let visual = content.visualHint, case .flipDemo = visual {
                // Align ghost to the target silhouette centroid and rotation for parity with the top panel
                let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                let expectedRot = targetNode.userData?["expectedZRotationSK"] as? CGFloat ?? 0
                let ghost = createGhostPiece(pieceType: pieceType, at: targetCentroid, rotation: expectedRot)
                ghost.alpha = 0.35
                nudgeNode.addChild(ghost)
                // Flip demonstration: quick scaleX mirror animation relative to its own anchor
                let flipOut = SKAction.scaleX(to: -1.0, duration: 0.25)
                let flipBack = SKAction.scaleX(to: 1.0, duration: 0.25)
                let wait = SKAction.wait(forDuration: 0.2)
                ghost.run(SKAction.sequence([flipOut, wait, flipBack]))
            } else if let visual = content.visualHint, case .rotationDemo(let current, let target) = visual {
                // Rotation demo at silhouette: show current orientation ghost then rotate to expected
                let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                let currentGhost = createGhostPiece(pieceType: pieceType, at: targetCentroid, rotation: current)
                currentGhost.alpha = 0.35
                nudgeNode.addChild(currentGhost)
                // Draw arc path around centroid
                let arc = SKShapeNode()
                let path = CGMutablePath()
                let radius: CGFloat = 60
                func norm(_ a: CGFloat) -> CGFloat { var x = a; while x > .pi { x -= 2 * .pi }; while x < -.pi { x += 2 * .pi }; return x }
                let a0 = norm(current)
                let a1 = norm(target)
                var d = a1 - a0; if d > .pi { d -= 2 * .pi }; if d < -.pi { d += 2 * .pi }
                let clockwise = d < 0
                path.addArc(center: targetCentroid, radius: radius, startAngle: a0, endAngle: a1, clockwise: clockwise)
                arc.path = path
                let arcColor = TangramColors.Sprite.uiColor(for: pieceType)
                arc.strokeColor = arcColor
                arc.lineWidth = 2
                nudgeNode.addChild(arc)
                // Animate rotation
                let rotate = SKAction.rotate(toAngle: target, duration: 0.8, shortestUnitArc: true)
                rotate.timingMode = .easeOut
                currentGhost.run(rotate)
            }

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

                // Slide demonstration: show a ghost piece sliding along the indicated direction into place
                let offset: CGFloat = 60
                let targetCentroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
                let start = CGPoint(x: targetCentroid.x - cos(direction) * offset, y: targetCentroid.y - sin(direction) * offset)
                let expectedRot = targetNode.userData?["expectedZRotationSK"] as? CGFloat ?? 0
                let ghost = createGhostPiece(pieceType: pieceType, at: start, rotation: expectedRot)
                ghost.alpha = 0.35
                nudgeNode.addChild(ghost)

                let slide = SKAction.move(to: targetCentroid, duration: 0.8)
                slide.timingMode = .easeOut
                ghost.run(SKAction.sequence([
                    slide,
                    SKAction.wait(forDuration: 0.6)
                ]))
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
               case .ghostPiece(_, let rotation) = visualHint {
                // Place ghost at centroid and demonstrate rotation into place
                let ghostPiece = createGhostPiece(pieceType: pieceType, at: .zero, rotation: rotation)
                ghostPiece.alpha = 0.4
                nudgeNode.addChild(ghostPiece)
                
                // Rotate demonstration (wiggle to show required alignment)
                let wiggle: CGFloat = .pi / 10 // ~18°
                let rotateDemo = SKAction.sequence([
                    SKAction.rotate(toAngle: rotation - wiggle, duration: 0.25, shortestUnitArc: true),
                    SKAction.rotate(toAngle: rotation + wiggle, duration: 0.25, shortestUnitArc: true),
                    SKAction.rotate(toAngle: rotation, duration: 0.2, shortestUnitArc: true)
                ])
                let loop = SKAction.repeat(rotateDemo, count: 2)
                ghostPiece.run(loop)
            }
            
        default:
            break
        }
        
        // No bottom-panel nudges; all indicators live in target section only
        
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
    
    // Bottom-piece nudges are disabled; nudges are shown only in the top target section
    private func showSmartNudge(for piece: PuzzlePieceNode, content: NudgeContent) { /* no-op for physical realism */ }
    
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

    // MARK: - Motion/Settlement Helpers

    /// A piece is considered settled if it hasn't moved/rotated/flipped for at
    /// least `settleDwell` seconds. Movement events record timestamps in
    /// `lastMotionAt`.
    internal func isPieceSettled(_ pieceId: String, now: TimeInterval = CACurrentMediaTime()) -> Bool {
        if let last = lastMotionAt[pieceId] {
            return (now - last) >= settleDwell
        }
        return false
    }

    // MARK: - Top Mirror Feedback/Nudges

    /// Shows a nudge bubble anchored near the mirrored piece in the top panel
    internal func showTopNudgeNearMirror(pieceId: String, content: NudgeContent) {
        guard let mirrorNode = topMirrorContent?.childNode(withName: "mirror_\(pieceId)") else { return }

        // Remove any existing nudge for this piece
        topMirrorContent?.childNode(withName: "mirror_nudge_\(pieceId)")?.removeFromParent()

        let nudgeNode = SKNode()
        nudgeNode.name = "mirror_nudge_\(pieceId)"
        // Position slightly above the mirrored piece
        nudgeNode.position = CGPoint(x: mirrorNode.position.x, y: mirrorNode.position.y + 50)
        nudgeNode.zPosition = (mirrorNode.zPosition + 10)

        // Visual content similar to target nudges, with optional demos
        switch content.level {
        case .visual, .gentle, .specific, .directed, .solution:
            let label = SKLabelNode(text: content.message.isEmpty ? "Hint" : content.message)
            label.fontSize = 16
            label.fontColor = .white
            label.fontName = "System-Bold"
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center

            let padding: CGFloat = 14
            // Use a fixed-height rounded rect, width based on label's calculated frame after alignment settings
            let bgSize = CGSize(width: max(100, label.frame.width + padding * 2), height: 34)
            let background = SKShapeNode(rectOf: bgSize, cornerRadius: 17)
            background.fillColor = nudgeLevelColor(content.level)
            background.strokeColor = .clear
            background.zPosition = -1

            nudgeNode.addChild(background)
            nudgeNode.addChild(label)

            // Render rotation/flip demos near the mirrored piece when provided
            if let visual = content.visualHint {
                switch visual {
                case .rotationDemo(let current, let target):
                    // Determine piece type and color
                    let resolvedType: TangramPieceType = availablePieces.first(where: { $0.name == pieceId })?.pieceType ?? .smallTriangle1
                    let ghost = createGhostPiece(pieceType: resolvedType, at: mirrorNode.position, rotation: current)
                    ghost.alpha = 0.35
                    ghost.zPosition = (mirrorNode.zPosition + 5)
                    topMirrorContent?.addChild(ghost)

                    // Draw arc indicating rotation direction (shortest path)
                    let arc = SKShapeNode()
                    let path = CGMutablePath()
                    let radius: CGFloat = 60
                    // Normalize angles to [-pi, pi]
                    func norm(_ a: CGFloat) -> CGFloat { var x = a; while x > .pi { x -= 2 * .pi }; while x < -.pi { x += 2 * .pi }; return x }
                    let a0 = norm(current)
                    let a1 = norm(target)
                    var delta = a1 - a0
                    if delta > .pi { delta -= 2 * .pi }
                    if delta < -.pi { delta += 2 * .pi }
                    let clockwise = delta < 0
                    path.addArc(center: mirrorNode.position, radius: radius, startAngle: a0, endAngle: a1, clockwise: clockwise)
                    arc.path = path
                    let arcColor = TangramColors.Sprite.uiColor(for: resolvedType)
                    arc.strokeColor = arcColor
                    arc.lineWidth = 2
                    arc.zPosition = ghost.zPosition + 1
                    topMirrorContent?.addChild(arc)

                    // Animate rotation demo then fade out
                    let rotate = SKAction.rotate(toAngle: target, duration: 0.8, shortestUnitArc: true)
                    rotate.timingMode = .easeOut
                    let hold = SKAction.wait(forDuration: max(0.2, content.duration - 1.2))
                    let fade = SKAction.fadeOut(withDuration: 0.2)
                    let remove = SKAction.removeFromParent()
                    ghost.run(SKAction.sequence([rotate, hold, fade, remove]))
                    arc.run(SKAction.sequence([SKAction.wait(forDuration: content.duration - 0.2), fade, remove]))

                case .flipDemo:
                    // Show flip demonstration using a ghost aligned to the mirror
                    let resolvedType: TangramPieceType = availablePieces.first(where: { $0.name == pieceId })?.pieceType ?? .smallTriangle1
                    let ghost = createGhostPiece(pieceType: resolvedType, at: mirrorNode.position, rotation: (mirrorNode.zRotation))
                    ghost.alpha = 0.35
                    ghost.zPosition = (mirrorNode.zPosition + 5)
                    topMirrorContent?.addChild(ghost)
                    let flipOut = SKAction.scaleX(to: -1.0, duration: 0.25)
                    let wait = SKAction.wait(forDuration: 0.2)
                    let flipBack = SKAction.scaleX(to: 1.0, duration: 0.25)
                    let fade = SKAction.fadeOut(withDuration: 0.2)
                    let remove = SKAction.removeFromParent()
                    ghost.run(SKAction.sequence([flipOut, wait, flipBack, SKAction.wait(forDuration: max(0.2, content.duration - 0.7)), fade, remove]))

                default:
                    break
                }
            }
        default:
            break
        }

        topMirrorContent?.addChild(nudgeNode)

        // Auto-remove after duration
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: max(1.2, content.duration - 0.3)),
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.removeFromParent()
        ])
        nudgeNode.run(fadeOut)
    }

    /// Shows a brief checkmark near the mirrored piece when orientation (rotation/flip) is correct
    internal func showMirrorCheckmark(for pieceId: String) {
        guard let mirrorNode = topMirrorContent?.childNode(withName: "mirror_\(pieceId)") else { return }
        let checkName = "mirror_check_\(pieceId)"
        topMirrorContent?.childNode(withName: checkName)?.removeFromParent()

        let checkmark = SKLabelNode(text: "✓")
        checkmark.name = checkName
        checkmark.fontSize = 28
        checkmark.fontName = "System-Bold"
        checkmark.fontColor = .systemGreen
        checkmark.position = CGPoint(x: mirrorNode.position.x, y: mirrorNode.position.y + 56)
        checkmark.zPosition = mirrorNode.zPosition + 20
        topMirrorContent?.addChild(checkmark)

        let seq = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 0.08),
                SKAction.scale(to: 1.25, duration: 0.08)
            ]),
            SKAction.wait(forDuration: 0.9),
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.removeFromParent()
        ])
        checkmark.run(seq)
    }
    
    // MARK: - Helper Methods
    
    func createGhostPiece(pieceType: TangramPieceType, at position: CGPoint, rotation: CGFloat) -> SKShapeNode {
        // Create a semi-transparent outline of the piece (centered at origin by centroid so node.pos is centroid)
        let vertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(vertices, by: TangramGameConstants.visualScale * 0.8)

        // Center vertices around centroid to match bottom-piece positioning semantics
        let centroid = TangramGameGeometry.centerOfVertices(scaledVertices)
        let centeredVertices = scaledVertices.map { CGPoint(x: $0.x - centroid.x, y: $0.y - centroid.y) }

        let path = CGMutablePath()
        if let first = centeredVertices.first {
            path.move(to: first)
            for vertex in centeredVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }

        let ghost = SKShapeNode(path: path)
        let color = TangramColors.Sprite.uiColor(for: pieceType)
        ghost.strokeColor = color
        ghost.lineWidth = 2
        ghost.fillColor = color.withAlphaComponent(0.2)
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

    private func resolvePoseLocal(for target: GamePuzzleData.TargetPiece) -> ResolvedPose? {
        guard let targetNode = targetSilhouettes[target.id] else { return nil }
        let centroidLocal = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
        // Centroid is stored relative to puzzleContainer coordinates already
        let zRot = targetNode.userData?["expectedZRotationSK"] as? CGFloat ?? TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
        let flipped = targetNode.userData?["isFlipped"] as? Bool ?? false
        return ResolvedPose(centroidInContainer: centroidLocal, zRotationSK: zRot, isFlipped: flipped, displayScale: targetDisplayScale)
    }
    private func tNodeExpectedRotation(for target: GamePuzzleData.TargetPiece) -> CGFloat {
        return TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: target.transform))
    }
    private func tNodeIsFlipped(for target: GamePuzzleData.TargetPiece) -> Bool {
        let det = target.transform.a * target.transform.d - target.transform.b * target.transform.c
        return det < 0
    }

    // Old refinement removed; handled by mappingService
    
    
    private func showNudge(for piece: PuzzlePieceNode, reason: ValidationFailure) { /* bottom-area nudges disabled */ }
    
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
    
    
    func updateCompletionState(_ completedPieces: Set<String>) {
        // Update completed pieces from external source
        self.completedPieces = completedPieces
        
        // Update visual state of targets
        for targetId in completedPieces {
            if let silhouette = targetSilhouettes[targetId],
               let typeRaw = silhouette.userData?["pieceType"] as? String,
               let pt = TangramPieceType(rawValue: typeRaw) {
                silhouette.fillColor = TangramColors.Sprite.uiColor(for: pt).withAlphaComponent(0.7)
                silhouette.alpha = 0.7
            }
        }
    }
    
    func showStructuredHint(_ hint: TangramHintEngine.HintData) {
        // Delegate to showHint
        showHint(for: hint)
    }

    // Revalidate all placed, unvalidated pieces in a group (used after mapping establish/refine and after a mapped validation)
    // revalidateUnvalidatedPieces is implemented in TangramSceneValidator extension
    
    // MARK: - CV Helpers
    
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
              let pose = resolvePoseLocal(for: targetPiece) else { return }
        print("[HINT] Showing hint for \(hint.targetPiece.rawValue) → target \(targetPiece.id)")
        
        // Create hint visualization in TARGET section (silhouette area) for clarity
        let hintPiece = PuzzlePieceNode(pieceType: hint.targetPiece)
        hintPiece.alpha = 0.0
        hintPiece.isUserInteractionEnabled = false
        hintPiece.zPosition = 500
        
        // Determine starting pose from the mirrored piece in the TOP panel when possible
        var startPos: CGPoint = CGPoint(x: pose.centroidInContainer.x, y: -100)
        var startRotation: CGFloat = 0
        var startIsFlipped: Bool = false
        if let physPiece = availablePieces.first(where: {
            ($0.userData?["pieceType"] as? String) == hint.targetPiece.rawValue &&
            !($0.userData?["validatedTargetId"] != nil)
        }), let pieceId = physPiece.name, let mirror = topMirrorContent?.childNode(withName: "mirror_\(pieceId)") as? SKShapeNode {
            // Convert mirror position into container space
            let inSection = topMirrorContent.convert(mirror.position, to: targetSection)
            if let container = targetSection.childNode(withName: "puzzleContainer") {
                startPos = container.convert(inSection, from: targetSection)
            } else {
                startPos = inSection
            }
            startRotation = mirror.zRotation
            startIsFlipped = mirror.xScale < 0
        } else if let existingPiece = availablePieces.first(where: {
            ($0.userData?["pieceType"] as? String) == hint.targetPiece.rawValue &&
            !($0.userData?["validatedTargetId"] != nil)
        }) {
            // Fallback to bottom piece converted into container space
            let pieceScenePos = physicalWorldSection.convert(existingPiece.position, to: self)
            if let container = targetSection.childNode(withName: "puzzleContainer") {
                startPos = container.convert(pieceScenePos, from: self)
            } else {
                startPos = self.convert(pieceScenePos, to: targetSection)
            }
            startRotation = existingPiece.zRotation
            startIsFlipped = existingPiece.isFlipped
        }
        
        hintPiece.position = startPos
        if let container = targetSection.childNode(withName: "puzzleContainer") {
            container.addChild(hintPiece)
        } else {
            targetSection.addChild(hintPiece)
        }
        // Scale hint to match silhouette display scale so rotation visually matches
        hintPiece.setScale(pose.displayScale)
        // Initialize rotation/flip from current mirrored/bottom state
        hintPiece.zRotation = startRotation
        if startIsFlipped { hintPiece.flip() }
        
        // Create animation sequence showing the solution path
        let fadeIn = SKAction.fadeAlpha(to: 0.6, duration: 0.3)
        
        // Step 1: Rotate to correct orientation using feature-angle formula
        let canonicalTarget: CGFloat = (hint.targetPiece.isTriangle ? (.pi/4) : 0) // 45° for triangles
        let canonicalPiece: CGFloat = (hint.targetPiece.isTriangle ? (3 * .pi/4) : 0) // 135° for triangles
        let desiredZ = TangramRotationValidator.normalizeAngle(pose.zRotationSK + canonicalTarget - canonicalPiece)
        let rotateAction = SKAction.rotate(toAngle: desiredZ, duration: 0.6, shortestUnitArc: true)
        
        // Step 2: Move to exact position in silhouette (centroid is in container coordinates)
        let moveAction = SKAction.move(to: pose.centroidInContainer, duration: 0.8)
        moveAction.timingMode = SKActionTimingMode.easeInEaseOut
        
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
        
        // Optional Step 0: Flip demo first if needed (parallelogram parity logic)
        var actions: [SKAction] = [fadeIn]
        if hint.targetPiece == .parallelogram {
            // Flip is needed when current parity matches target parity (inverted logic)
            if startIsFlipped == pose.isFlipped {
                let flipOut = SKAction.scaleX(to: -hintPiece.xScale, duration: 0.25)
                let waitFlip = SKAction.wait(forDuration: 0.1)
                actions.append(contentsOf: [flipOut, waitFlip])
            }
        }
        actions.append(contentsOf: [rotateAction, moveAction, pulseRepeat, wait, fadeOut, remove])
        let fullAnimation = SKAction.sequence(actions)
        
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