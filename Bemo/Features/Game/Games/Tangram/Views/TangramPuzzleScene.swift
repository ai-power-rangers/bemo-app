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
    private var sceneCamera: SKCameraNode?
    
    // MARK: - Section Bounds
    
    internal var targetBounds: CGRect = .zero
    private var cvMiniBounds: CGRect = .zero
    internal var physicalBounds: CGRect = .zero  // Internal for extensions
    
    // MARK: - Game State
    var canvasSize : CGSize = CGSize(width: 1080, height: 1920) // Match CVService viewSize
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
    // Touch selection disabled for CV mode
    // private var selectedPiece: PuzzlePieceNode?
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
    
    // MARK: - Touch Tracking (Disabled for CV mode)
    // Touch tracking removed - using CV input only
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
    
    // MARK: - Rotation Dial (Disabled for CV mode)
    // Touch-based rotation controls removed
    
    // MARK: - Hints
    
    internal var currentHint: (pieceType: TangramPieceType, targetId: String)?  // Internal for extensions
    internal var hintNode: SKNode?  // Internal for extensions
    
    // MARK: - Model Polygon Visualization (from Tangram pipeline)
    
    // Storage for latest model polygons (in plane coordinates) and colors
    private var modelPlanePolygons: [[CGPoint]] = []
    private var modelFillColors: [SKColor] = []
    private var modelPolygonLayer: SKNode?
    private var snappedPolygonLayer: SKNode?
    private var cvShapeNodesByGlobalIndex: [Int: SKShapeNode] = [:]
    private var cvOverlayRotationRadians: CGFloat = 0
    // Snapping hysteresis (render snapped for a short window after verification)
    private var snapHoldUntilByTargetId: [String: TimeInterval] = [:]
    private var lastMatchedGlobalIndexByTargetId: [String: Int] = [:]
    private let snapHoldDuration: TimeInterval = 1.0
    // Completion wiring to ViewModel
    private var firedCompletionTargetIds: Set<String> = []
    private var puzzleCompletionFired: Bool = false
    // Class ids aligned with `modelPlanePolygons` indices for interchangeability mapping
    private var modelPlaneClassIds: [Int] = []
    // Recompute outline scale only on new CV frames (not during verification-only passes)
    private var shouldUpdateScaleThisFrame: Bool = false
    // Persisted transform mapping model plane → panel (targetSection) coordinates
    private struct PanelTransform {
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
        let panelWidth: CGFloat
        let panelHeight: CGFloat
    }
    private var cvPanelTransform: PanelTransform?
    
    // Colors from tangram_shapes_2d.json by class id (fallback to pipeline-provided RGB)
    private static let jsonColorsByClassId: [Int: SKColor] = {
        var mapping: [Int: SKColor] = [:]
        guard let path = Bundle.main.path(forResource: "tangram_shapes_2d", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let root = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return mapping
        }
        let idToName: [Int: String] = [
            0: "tangram_parallelogram",
            1: "tangram_square",
            2: "tangram_triangle_lrg",
            3: "tangram_triangle_lrg2",
            4: "tangram_triangle_med",
            5: "tangram_triangle_sml",
            6: "tangram_triangle_sml2"
        ]
        for (cid, name) in idToName {
            if let obj = root[name] as? [String: Any],
               let arr = obj["color"] as? [Any], arr.count >= 3,
               let rN = arr[0] as? NSNumber, let gN = arr[1] as? NSNumber, let bN = arr[2] as? NSNumber {
                let r = CGFloat(truncating: rN) / 255.0
                let g = CGFloat(truncating: gN) / 255.0
                let b = CGFloat(truncating: bN) / 255.0
                mapping[cid] = SKColor(red: r, green: g, blue: b, alpha: 0.35)
            }
        }
        return mapping
    }()
    
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
        // Ensure a scene camera exists so we can apply a final, global centering
        if self.camera == nil {
            let cam = SKCameraNode()
            cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(cam)
            self.camera = cam
            self.sceneCamera = cam
        } else if let existing = self.camera {
            self.sceneCamera = existing
        }
        
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
        cvLabel.fontColor = SKColor(red: 0.18, green: 0.50, blue: 0.93, alpha: 0.7)
        cvLabel.position = CGPoint(x: 0, y: -miniDisplaySize/2 + 5)
        cvLabel.zPosition = 1
        cvMiniDisplay.addChild(cvLabel)
        
        // Physical world section - hidden in CV-driven mode (no touch interaction)
        // Keep the section for compatibility but make it invisible
        physicalWorldSection.isHidden = true
    }
    
    // MARK: - Puzzle Loading
    
    func loadPuzzle(_ puzzle: GamePuzzleData) {
        self.puzzle = puzzle
        
        // If scene hasn't been added to view yet, just store the puzzle
        guard targetSection != nil else { return }
        
        // Clear existing state
        clearAllSections()
        // Reset per-frame scaling flag for new puzzle
        shouldUpdateScaleThisFrame = false
        // Reset completion wiring state
        firedCompletionTargetIds.removeAll()
        puzzleCompletionFired = false
        validatedTargets.removeAll()
        
        // Setup target section with silhouettes
        setupTargetPuzzle(puzzle)
        
        // Create physical pieces
        createPhysicalPieces(puzzle)
        
        // Pre-populate top mirror from current physical piece poses so the top panel is populated immediately
        prepopulateTopMirrorFromPhysical()
        
        // Emit initial CV frame
        emitCVFrameUpdate()
    }
    
    /// Create top mirror ghosts at puzzle load based on physical piece positions
    private func prepopulateTopMirrorFromPhysical() {
        guard let mirror = topMirrorContent else { return }
        
        // Clear existing ghosts (keep any nudge overlays if present)
        mirror.enumerateChildNodes(withName: "mirror_*") { node, _ in node.removeFromParent() }
        
        // Compute uniform scale mapping physical bounds to target bounds (same as CV bridge)
        let physSize = physicalBounds.size
        let topSize = CGSize(width: targetBounds.width, height: targetBounds.height)
        guard physSize.width > 0, physSize.height > 0, topSize.width > 0, topSize.height > 0 else { return }
        let sx = topSize.width / physSize.width
        let sy = topSize.height / physSize.height
        let uniform = min(sx, sy)
        topMirrorContent.setScale(uniform)
        topMirrorContent.position = .zero
        
        // Create a ghost for each physical piece at its current pose
        for piece in availablePieces {
            guard let pieceId = piece.name, let pieceType = piece.pieceType else { continue }
            let nodeName = "mirror_\(pieceId)"
            if let existing = mirror.childNode(withName: nodeName) as? SKShapeNode { existing.removeFromParent() }
            let ghost = createGhostPiece(pieceType: pieceType, at: .zero, rotation: 0)
            ghost.name = nodeName
            // Position uses physical world coordinates; origins are both centered
            ghost.position = piece.position
            ghost.setScale(1.0)
            ghost.xScale = piece.isFlipped ? -abs(ghost.xScale) : abs(ghost.xScale)
            ghost.zRotation = piece.zRotation
            // Visual parity with live mirror rendering
            let baseColor = TangramColors.Sprite.uiColor(for: pieceType)
            ghost.fillColor = baseColor.withAlphaComponent(0.2)
            ghost.strokeColor = baseColor.withAlphaComponent(0.5)
            ghost.lineWidth = 1.0
            mirror.addChild(ghost)
        }
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
        // CV-driven mode: disable all touch interactions
        return
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // CV-driven mode: disable all touch interactions
        return
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // CV-driven mode: disable all touch interactions
        return
    }
    
    // MARK: - Rotation Dial (Disabled for CV-driven mode)
    
    // Rotation dial functionality removed - pieces are positioned by CV input only
    
    // MARK: - CV Update
    
    /// Update scene visuals to match TangramExample visualization: render model polygons from pipeline
    /// Call this after CV results update, or when the view refreshes
    func updateFromCVPieces(_ placedPieces: [PlacedPiece]) {
        // For visualization parity, ignore piece-by-piece ghosts and render the model polygons only
        renderModelPolygons()
    }

    /// Public entry to set model polygons and colors from the CV pipeline
    func updateModelPolygons(planeModelPolygons: [NSNumber: [NSNumber]], modelColorsRGB: [NSNumber: [NSNumber]]? = nil) {
        // Reset storage
        modelPlanePolygons.removeAll()
        modelFillColors.removeAll()
        modelPlaneClassIds.removeAll()
        // Mark that we should rescale the outline based on this fresh CV frame
        shouldUpdateScaleThisFrame = true
        
        // Deterministic order by class id
        for (key, arr) in planeModelPolygons.sorted(by: { $0.key.intValue < $1.key.intValue }) {
            var pts: [CGPoint] = []
            var j = 0
            while j + 1 < arr.count {
                let x = CGFloat(truncating: arr[j])
                let y = CGFloat(truncating: arr[j+1])
                pts.append(CGPoint(x: x, y: y))
                j += 2
            }
            if pts.count >= 3 {
                modelPlanePolygons.append(pts)
                modelPlaneClassIds.append(key.intValue)
                if let col = TangramPuzzleScene.jsonColorsByClassId[key.intValue] {
                    modelFillColors.append(col)
                } else if let rgb = modelColorsRGB?[key], rgb.count >= 3 {
                    let r = CGFloat(truncating: rgb[0]) / 255.0
                    let g = CGFloat(truncating: rgb[1]) / 255.0
                    let b = CGFloat(truncating: rgb[2]) / 255.0
                    modelFillColors.append(SKColor(red: r, green: g, blue: b, alpha: 0.35))
                } else {
                    modelFillColors.append(SKColor.white.withAlphaComponent(0.35))
                }
            }
        }
        
        renderModelPolygons()
    }

    /// Render model polygons into the target section, scaled and centered exactly like PolygonPlotView
    private func renderModelPolygons() {
        guard !modelPlanePolygons.isEmpty else { return }
        guard targetSection != nil else { return }
        
        // Remove any pre-existing mirrored piece nodes to avoid conflicts with model rendering
        topMirrorContent?.enumerateChildNodes(withName: "mirror_*") { node, _ in
            node.removeFromParent() 
        }
        
        // Ensure layer
        if modelPolygonLayer == nil {
            let layer = SKNode()
            layer.name = "modelPolygonLayer"
            layer.zPosition = 3 // Above silhouettes and mirror
            targetSection.addChild(layer)
            modelPolygonLayer = layer
        }
        if snappedPolygonLayer == nil {
            let layer = SKNode()
            layer.name = "snappedPolygonLayer"
            layer.zPosition = 4 // Above raw overlay
            targetSection.addChild(layer)
            snappedPolygonLayer = layer
        }
        
        // Clear previous raw overlay shapes; keep snapped layer empty since we won't draw snapped polygons anymore
        modelPolygonLayer?.removeAllChildren()
        snappedPolygonLayer?.removeAllChildren()
        cvShapeNodesByGlobalIndex.removeAll()
        // Ensure overlay rotation reflects any verification-driven adjustment
        modelPolygonLayer?.zRotation = cvOverlayRotationRadians
        
        // Compute fit within the top panel area (match sample: full width of the panel)
        let panelWidth = max(1, targetBounds.width)
        let panelHeight = max(1, targetBounds.height)
        
        // Compute bounds of all model polygons in plane coordinates
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for poly in modelPlanePolygons {
            for p in poly {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }
        let pad: CGFloat = 8
        let paddingFraction: CGFloat = 0.3 // 30% padding around ROI
        let srcW = max(1, maxX - minX)
        let srcH = max(1, maxY - minY)
        let cx = (minX + maxX) * 0.5
        let cy = (minY + maxY) * 0.5
        let paddedW = srcW * (1.0 + paddingFraction)
        let paddedH = srcH * (1.0 + paddingFraction)
        let paddedMinX = cx - paddedW * 0.5
        let paddedMinY = cy - paddedH * 0.5
        let scale = min((panelWidth - 2*pad)/paddedW, (panelHeight - 2*pad)/paddedH)
        let offsetX = (panelWidth - scale*paddedW)/2 - scale*paddedMinX
        let offsetY = (panelHeight - scale*paddedH)/2 - scale*paddedMinY
        // Store transform for unification
        cvPanelTransform = PanelTransform(
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            panelWidth: panelWidth,
            panelHeight: panelHeight
        )
        
        // Helper to convert plane → SpriteKit local (targetSection-centered)
        func toLocal(_ p: CGPoint) -> CGPoint { planeToPanel(p) }
        
        // Draw model polygons
        for (idx, poly) in modelPlanePolygons.enumerated() {
            guard poly.count >= 3 else { continue }
            let path = CGMutablePath()
            let p0 = toLocal(poly[0])
            path.move(to: p0)
            for k in 1..<poly.count {
                path.addLine(to: toLocal(poly[k]))
            }
            path.closeSubpath()
            
            let shape = SKShapeNode(path: path)
            let fill = (idx < modelFillColors.count) ? modelFillColors[idx] : SKColor.white.withAlphaComponent(0.35)
            shape.fillColor = fill
            shape.strokeColor = SKColor.white
            shape.lineWidth = 1.5
            modelPolygonLayer?.addChild(shape)
            cvShapeNodesByGlobalIndex[idx] = shape
        }
        
        // Draw plane axes (red X, green Y)
        func addArrow(from: CGPoint, to: CGPoint, color: SKColor, width: CGFloat) {
            let linePath = CGMutablePath()
            linePath.move(to: from)
            linePath.addLine(to: to)
            let line = SKShapeNode(path: linePath)
            line.strokeColor = color
            line.lineWidth = width
            modelPolygonLayer?.addChild(line)
            
            let angle = atan2(to.y - from.y, to.x - from.x)
            let headLen: CGFloat = 8
            let headAng: CGFloat = .pi / 7
            let p1 = CGPoint(x: to.x - headLen * cos(angle - headAng), y: to.y - headLen * sin(angle - headAng))
            let p2 = CGPoint(x: to.x - headLen * cos(angle + headAng), y: to.y - headLen * sin(angle + headAng))
            let headPath = CGMutablePath()
            headPath.move(to: to)
            headPath.addLine(to: p1)
            headPath.move(to: to)
            headPath.addLine(to: p2)
            let head = SKShapeNode(path: headPath)
            head.strokeColor = color
            head.lineWidth = width
            modelPolygonLayer?.addChild(head)
        }
        
        let axisLenPlane = 0.15 * min(srcW, srcH)
        let originPlane = CGPoint(x: minX + 0.1*srcW, y: maxY - 0.1*srcH)
        let originLocal = planeToPanel(originPlane)
        let xEndLocal = planeToPanel(CGPoint(x: originPlane.x + axisLenPlane, y: originPlane.y))
        // Match PolygonPlotView: draw positive Y axis upward on screen
        let yEndLocal = planeToPanel(CGPoint(x: originPlane.x, y: originPlane.y - axisLenPlane))
        addArrow(from: originLocal, to: xEndLocal, color: .systemRed, width: 2)
        addArrow(from: originLocal, to: yEndLocal, color: .systemGreen, width: 2)

        // Update outline scale only when a fresh CV frame arrived
        if shouldUpdateScaleThisFrame {
            adjustPuzzleContainerScaleToCV()
            shouldUpdateScaleThisFrame = false
        }
        // Run per-frame verification and global snap
        verifyAndSnapToCV()
        // Apply final global translation so the puzzle outline is centered in the view
        applyFinalSceneCenteringOnPuzzle()
    }

    /// Final global centering: move the scene camera so the puzzle outline is centered in the view
    private func applyFinalSceneCenteringOnPuzzle() {
        guard let cam = sceneCamera else { return }
        guard let container = targetSection.childNode(withName: "puzzleContainer") else { return }
        let frameInTarget = container.calculateAccumulatedFrame()
        guard frameInTarget.width > 0, frameInTarget.height > 0 else { return }
        let centerInTarget = CGPoint(x: frameInTarget.midX, y: frameInTarget.midY)
        let centerInScene = targetSection.convert(centerInTarget, to: self)
        cam.position = centerInScene
    }

    // MARK: - Panel-space Conversion Helpers

    /// Convert a point in model plane coordinates to panel (targetSection) coordinates
    internal func planeToPanel(_ p: CGPoint) -> CGPoint {
        guard let t = cvPanelTransform else { return .zero }
        // UIKit-like draw coords
        let ux = p.x * t.scale + t.offsetX
        let uy = p.y * t.scale + t.offsetY
        // Convert from top-left origin to center-origin with Y-up (SpriteKit)
        let lx = ux - t.panelWidth/2
        let ly = (t.panelHeight/2) - uy
        return CGPoint(x: lx, y: ly)
    }

    /// Convert a point from a child node (e.g., puzzleContainer or silhouette) into panel (targetSection) coordinates
    internal func nodeToPanel(_ point: CGPoint, from node: SKNode) -> CGPoint {
        return node.convert(point, to: targetSection)
    }

    // MARK: - Polygon Collection in Unified Panel Space

    /// Collect current CV model polygons in panel coordinates
    internal func collectCVPanelPolygons() -> [[CGPoint]] {
        guard !modelPlanePolygons.isEmpty, cvPanelTransform != nil else { return [] }
        var polys: [[CGPoint]] = []
        let rot = CGAffineTransform(rotationAngle: cvOverlayRotationRadians)
        for poly in modelPlanePolygons {
            let mapped = poly.map { planeToPanel($0).applying(rot) }
            if mapped.count >= 3 { polys.append(mapped) }
        }
        return polys
    }

    /// Collect target silhouette polygons in panel coordinates (by reading SKShapeNode paths)
    internal func collectTargetPanelPolygons() -> [String: [CGPoint]] {
        var result: [String: [CGPoint]] = [:]
        for (targetId, node) in targetSilhouettes {
            guard let path = node.path else { continue }
            let pts = path.extractPolygonPoints()
            if pts.count >= 3 {
                let mapped = pts.map { nodeToPanel($0, from: node) }
                result[targetId] = mapped
            }
        }
        return result
    }

    /// Adjust the puzzle outline container scale so silhouette size matches CV polygon size
    func adjustPuzzleContainerScaleToCV() {
        guard cvPanelTransform != nil else { return }
        // Get puzzleContainer in targetSection
        guard let container = targetSection.childNode(withName: "puzzleContainer") else { return }
        // Compute rotation-invariant ratio from total polygon areas
        let cvPolys = collectCVPanelPolygons()
        guard !cvPolys.isEmpty else { return }
        let targetPolys = collectTargetPanelPolygons().values
        guard !targetPolys.isEmpty else { return }
        let cvArea = cvPolys.reduce(0) { $0 + polygonAreaAbs($1) }
        let targetArea = targetPolys.reduce(0) { $0 + polygonAreaAbs($1) }
        guard cvArea > 0, targetArea > 0 else { return }
        let ratio = sqrt(cvArea / targetArea)
        // Multiply current scale by ratio to converge toward CV size
        let newScale = max(0.0001, container.xScale * ratio)
        container.setScale(newScale)
    }

    // MARK: - Verification & Snap Integration

    private func pieceTypeFromClassId(_ classId: Int) -> TangramPieceType? {
        switch classId {
        case 0: return .parallelogram
        case 1: return .square
        case 2: return .largeTriangle1
        case 3: return .largeTriangle2
        case 4: return .mediumTriangle
        case 5: return .smallTriangle1
        case 6: return .smallTriangle2
        default: return nil
        }
    }

    private func collectCVPanelPolygonsByType() -> [TangramPieceType: [[CGPoint]]] {
        var mapping: [TangramPieceType: [[CGPoint]]] = [:]
        guard cvPanelTransform != nil, !modelPlanePolygons.isEmpty else { return mapping }

        // Group piece types by display name to model interchangeability (e.g., the two large triangles)
        var typesByDisplayName: [String: [TangramPieceType]] = [:]
        for t in TangramPieceType.allCases {
            typesByDisplayName[t.displayName, default: []].append(t)
        }

        for (index, polyPlane) in modelPlanePolygons.enumerated() {
            let rot = CGAffineTransform(rotationAngle: cvOverlayRotationRadians)
            let polyPanel = polyPlane.map { planeToPanel($0).applying(rot) }
            let classId = (index < modelPlaneClassIds.count) ? modelPlaneClassIds[index] : -1

            if let primaryType = (classId >= 0 ? pieceTypeFromClassId(classId) : nil) {
                let display = primaryType.displayName
                let interchangeableTypes = typesByDisplayName[display] ?? [primaryType]
                for t in interchangeableTypes {
                    mapping[t, default: []].append(polyPanel)
                }
            } else {
                // If class id missing, make the polygon available to all types
                for t in TangramPieceType.allCases {
                    mapping[t, default: []].append(polyPanel)
                }
            }
        }

        return mapping
    }

    private func collectTargetTypesById() -> [String: TangramPieceType] {
        var mapping: [String: TangramPieceType] = [:]
        for (targetId, node) in targetSilhouettes {
            if let raw = node.userData?["pieceType"] as? String, let pt = TangramPieceType(rawValue: raw) {
                mapping[targetId] = pt
            }
        }
        return mapping
    }

    private func collectCVPanelPolygonsByTypeWithIndices() -> (polys: [TangramPieceType: [[CGPoint]]], globalIndices: [TangramPieceType: [Int]]) {
        var polysByType: [TangramPieceType: [[CGPoint]]] = [:]
        var indicesByType: [TangramPieceType: [Int]] = [:]
        guard cvPanelTransform != nil, !modelPlanePolygons.isEmpty else { return (polysByType, indicesByType) }

        var typesByDisplayName: [String: [TangramPieceType]] = [:]
        for t in TangramPieceType.allCases { typesByDisplayName[t.displayName, default: []].append(t) }

        let rot = CGAffineTransform(rotationAngle: cvOverlayRotationRadians)
        for (globalIndex, polyPlane) in modelPlanePolygons.enumerated() {
            let polyPanel = polyPlane.map { planeToPanel($0).applying(rot) }
            let classId = (globalIndex < modelPlaneClassIds.count) ? modelPlaneClassIds[globalIndex] : -1
            if let primaryType = (classId >= 0 ? pieceTypeFromClassId(classId) : nil) {
                let display = primaryType.displayName
                let interchangeableTypes = typesByDisplayName[display] ?? [primaryType]
                for t in interchangeableTypes {
                    polysByType[t, default: []].append(polyPanel)
                    indicesByType[t, default: []].append(globalIndex)
                }
            } else {
                for t in TangramPieceType.allCases {
                    polysByType[t, default: []].append(polyPanel)
                    indicesByType[t, default: []].append(globalIndex)
                }
            }
        }
        return (polysByType, indicesByType)
    }

    private func centroidOfPolygon(_ poly: [CGPoint]) -> CGPoint {
        guard poly.count >= 3 else { return .zero }
        var a: CGFloat = 0
        var cx: CGFloat = 0
        var cy: CGFloat = 0
        for i in 0..<poly.count {
            let p0 = poly[i]
            let p1 = poly[(i + 1) % poly.count]
            let cross = p0.x * p1.y - p1.x * p0.y
            a += cross
            cx += (p0.x + p1.x) * cross
            cy += (p0.y + p1.y) * cross
        }
        if abs(a) < 1e-6 {
            var sx: CGFloat = 0, sy: CGFloat = 0
            for p in poly { sx += p.x; sy += p.y }
            let n = CGFloat(max(1, poly.count))
            return CGPoint(x: sx / n, y: sy / n)
        }
        a *= 0.5
        let factor = 1.0 / (6.0 * a)
        return CGPoint(x: cx * factor, y: cy * factor)
    }

    private func normalizeAngle(_ a: CGFloat) -> CGFloat {
        var x = a
        while x > .pi { x -= 2 * .pi }
        while x < -.pi { x += 2 * .pi }
        return x
    }
    
    private func polygonAreaAbs(_ poly: [CGPoint]) -> CGFloat {
        guard poly.count >= 3 else { return 0 }
        var area: CGFloat = 0
        for i in 0..<poly.count {
            let p0 = poly[i]
            let p1 = poly[(i + 1) % poly.count]
            area += (p0.x * p1.y - p1.x * p0.y)
        }
        return abs(area) * 0.5
    }

    private func verifyAndSnapToCV() {
        let targetPolys = collectTargetPanelPolygons()
        guard !targetPolys.isEmpty else { return }
        let typesById = collectTargetTypesById()

        // Build CV polygons by type and remember their source indices for color mapping
        let cvCollected = collectCVPanelPolygonsByTypeWithIndices()
        var cvByType = cvCollected.polys
        let cvGlobalIndices = cvCollected.globalIndices
        if cvByType.isEmpty {
            let all = collectCVPanelPolygons()
            // If no type map, assign the same pool to each target's type so verifier can choose best
            var distinctTypes = Set<TangramPieceType>()
            for (_, t) in typesById { distinctTypes.insert(t) }
            for t in distinctTypes { cvByType[t] = all }
        }
        guard !cvByType.isEmpty else { return }
        let panelMin = max(1, min(targetBounds.width, targetBounds.height))

        let result = TangramVerificationEngine.verifyMatches(
            targetPolygonsById: targetPolys,
            targetTypesById: typesById,
            cvPolygonsByType: cvByType,
            panelMinDimension: panelMin
        )

        var targetCentroidsById: [String: CGPoint] = [:]
        for (tid, poly) in targetPolys { targetCentroidsById[tid] = centroidOfPolygon(poly) }

        var cvCentroidsById: [String: CGPoint] = [:]
        for (tid, match) in result.perTarget {
            guard let idx = match.matchedCVIndex, let list = cvByType[match.pieceType], idx < list.count else { continue }
            cvCentroidsById[tid] = centroidOfPolygon(list[idx])
        }

        if let snap = TangramVerificationEngine.computeGlobalSnap(
            result: result,
            targetCentroidsById: targetCentroidsById,
            cvCentroidsById: cvCentroidsById,
            maxRotationDegrees: 15
        ) {
            if let container = targetSection.childNode(withName: "puzzleContainer") {
                // Dampen translation to reduce oscillations
                let tAlpha: CGFloat = 1//0.2
                container.position = CGPoint(
                    x: container.position.x + tAlpha * snap.translation.dx,
                    y: container.position.y + tAlpha * snap.translation.dy
                )

                // Apply rotation to CV overlay (not the outline). Dampen and normalize to avoid spin.
                let matchedCount = result.matchedTargets.count
                if matchedCount >= 2 {
                    let rAlpha: CGFloat = 1//0.2
                    let delta = -rAlpha * snap.rotationRadians // rotate CV opposite the target->CV rotation
                    cvOverlayRotationRadians = normalizeAngle(cvOverlayRotationRadians + delta)
                    modelPolygonLayer?.zRotation = cvOverlayRotationRadians
                }
            }
        }

        // Visualization: On match/hold: hide CV shape, color and fill the corresponding outline.
        var matchedTargetsCurrentFrame: Set<String> = []
        let now = CACurrentMediaTime()
        for (tid, match) in result.perTarget {
            guard let idx = match.matchedCVIndex,
                  let node = targetSilhouettes[tid] else { continue }
            matchedTargetsCurrentFrame.insert(tid)
            // Map per-type index back to global polygon index to fetch its color
            if let list = cvGlobalIndices[match.pieceType], idx < list.count {
                let globalIdx = list[idx]
                if globalIdx >= 0 && globalIdx < modelFillColors.count {
                    let color = modelFillColors[globalIdx].withAlphaComponent(1.0)
                    node.strokeColor = color
                    node.lineWidth = 3.0
                    // Fill the outline to represent snapped state; keep CV shape hidden
                    node.fillColor = modelFillColors[globalIdx].withAlphaComponent(0.35)
                    // Start/extend snap hold window
                    snapHoldUntilByTargetId[tid] = now + snapHoldDuration
                    lastMatchedGlobalIndexByTargetId[tid] = globalIdx
                    // Hide the original CV shape; do not change its position/rotation
                    if let original = cvShapeNodesByGlobalIndex[globalIdx] {
                        original.isHidden = true
                    }
                }
            }
        }
        // Reset unmatched outlines unless within snap hold window
        for (tid, node) in targetSilhouettes where !matchedTargetsCurrentFrame.contains(tid) {
            // If within hold, keep outline filled/colored and CV hidden
            if let holdUntil = snapHoldUntilByTargetId[tid], now < holdUntil {
                // Keep outline colored and show snapped polygon; also hide original CV if known
                if let globalIdx = lastMatchedGlobalIndexByTargetId[tid], globalIdx >= 0 && globalIdx < modelFillColors.count {
                    let color = modelFillColors[globalIdx].withAlphaComponent(1.0)
                    node.strokeColor = color
                    node.lineWidth = 3.0
                    node.fillColor = modelFillColors[globalIdx].withAlphaComponent(0.35)
                    if let original = cvShapeNodesByGlobalIndex[globalIdx] { original.isHidden = true }
                }
                continue
            } else {
                // Expired hold → clean up memory
                snapHoldUntilByTargetId.removeValue(forKey: tid)
                lastMatchedGlobalIndexByTargetId.removeValue(forKey: tid)
            }
            // Restore base fill and stroke when not matched or held
            if let baseFill = node.userData?["baseFillColor"] as? SKColor {
                node.fillColor = baseFill
            } else {
                node.fillColor = .clear
            }
            if let baseColor = node.userData?["baseStrokeColor"] as? SKColor {
                node.strokeColor = baseColor
            } else {
                node.strokeColor = .systemGray2
            }
            if let baseWidth = node.userData?["baseLineWidth"] as? CGFloat {
                node.lineWidth = baseWidth
            } else {
                node.lineWidth = 2.0
            }
            if let baseAlpha = node.userData?["baseAlpha"] as? CGFloat {
                node.alpha = baseAlpha
            }
        }

        // Emit validation and completion events to ViewModel
        // Build validated set based on active snap-hold windows
        var currentlyValidated: Set<String> = []
        for (tid, holdUntil) in snapHoldUntilByTargetId {
            if now < holdUntil { currentlyValidated.insert(tid) }
        }
        // Fire per-piece completion for newly validated targets
        if let typesById = Optional(collectTargetTypesById()) {
            for tid in currentlyValidated where !firedCompletionTargetIds.contains(tid) {
                if let t = typesById[tid] {
                    onPieceCompleted?(t.rawValue, false)
                    firedCompletionTargetIds.insert(tid)
                }
            }
        }
        // Emit validated set change if it differs
        if currentlyValidated != validatedTargets {
            validatedTargets = currentlyValidated
            onValidatedTargetsChanged?(validatedTargets)
        }
        // Puzzle completion when all targets validated
        if !puzzleCompletionFired && validatedTargets.count == targetSilhouettes.count && !targetSilhouettes.isEmpty {
            puzzleCompletionFired = true
            onPuzzleCompleted?()
        }
    }
    // MARK: - Nudge System
    
    func showSmartNudgeInTarget(targetNode: SKShapeNode, content: NudgeContent, pieceType: TangramPieceType) {
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
            label.fontColor = SKColor.white
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
                label.fontColor = TangramTheme.Hint.skColor
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
        return TangramTheme.Nudge.skColor(for: level)
    }

    // MARK: - Motion/Settlement Helpers

    /// A piece is considered settled if it hasn't moved/rotated/flipped for at
    /// least `settleDwell` seconds. Movement events record timestamps in
    /// `lastMotionAt`.
    func isPieceSettled(_ pieceId: String, now: TimeInterval = CACurrentMediaTime()) -> Bool {
        if let last = lastMotionAt[pieceId] {
            return (now - last) >= settleDwell
        }
        return false
    }

    // MARK: - Top Mirror Feedback/Nudges

    /// Shows a nudge bubble anchored near the mirrored piece in the top panel
    func showTopNudgeNearMirror(pieceId: String, content: NudgeContent) {
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
            label.fontColor = SKColor.white
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
    func showMirrorCheckmark(for pieceId: String) {
        guard let mirrorNode = topMirrorContent?.childNode(withName: "mirror_\(pieceId)") else { return }
        let checkName = "mirror_check_\(pieceId)"
        topMirrorContent?.childNode(withName: checkName)?.removeFromParent()

        let checkmark = SKLabelNode(text: "✓")
        checkmark.name = checkName
        checkmark.fontSize = 28
        checkmark.fontName = "System-Bold"
        checkmark.fontColor = TangramTheme.Validation.correctSK
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
