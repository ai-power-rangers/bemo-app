//
//  TangramThreeZoneScene.swift
//  Bemo
//
//  Three-zone SpriteKit scene for CV-ready Tangram gameplay
//

// WHAT: Physical world simulation with reference/assembly/storage zones, no snapping
// ARCHITECTURE: SKScene that simulates CV camera view of physical tangram pieces
// USAGE: Main gameplay scene for TangramCV, handles all piece interaction

import SpriteKit
import SwiftUI
import UIKit

class TangramThreeZoneScene: SKScene {
    
    // MARK: - Zone Properties
    
    private var referenceZone: SKNode!     // Top 1/3 - shows target (read-only)
    private var assemblyZone: SKNode!      // Middle 1/3 - "physical table"
    private var storageZone: SKNode!       // Bottom 1/3 - scattered pieces
    
    // Zone boundaries for detection
    private var assemblyZoneBounds: CGRect = .zero
    private var storageZoneBounds: CGRect = .zero
    
    // Visual indicators
    private var assemblyBoundary: SKShapeNode!
    
    // MARK: - Piece Tracking
    
    private var anchorPiece: CVPuzzlePieceNode?
    private var assembledPieces: [CVPuzzlePieceNode] = []
    private var availablePieces: [String: CVPuzzlePieceNode] = [:]
    private var selectedPiece: CVPuzzlePieceNode?
    
    // For haptic feedback
    private var lastZoneForSelectedPiece: Zone = .storage
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum Zone {
        case reference
        case assembly
        case storage
        case none
    }
    
    // MARK: - Callbacks
    
    var puzzle: GamePuzzleData?
    var onPiecePlaced: ((CVPuzzlePieceNode, Bool) -> Void)?  // piece and inAssemblyZone
    var onAnchorChanged: ((CVPuzzlePieceNode?) -> Void)?
    var onCVDataGenerated: (([String: Any]) -> Void)?
    var onPuzzleCompleted: (() -> Void)?
    
    // MARK: - CV Tracking
    
    private var pieceStabilityFrames: [String: Int] = [:]
    private var lastCVEmissionTime: TimeInterval = 0
    private let cvEmissionInterval: TimeInterval = 0.05  // 20Hz max
    var isCVMode: Bool = false  // Toggle for CV vs touch mode
    
    // MARK: - Scene Setup
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupZones()
        impactFeedback.prepare()
        
        if let puzzle = puzzle {
            loadPuzzle(puzzle)
        }
    }
    
    private func setupZones() {
        backgroundColor = SKColor(named: "GameBackground") ?? SKColor.systemBackground
        
        let zoneHeight = size.height / 3
        
        // REFERENCE ZONE - Top 1/3 (non-interactive)
        referenceZone = SKNode()
        referenceZone.position = CGPoint(x: size.width / 2, y: size.height - zoneHeight / 2)
        referenceZone.zPosition = 0
        addChild(referenceZone)
        
        // Add subtle background for reference zone
        let referenceBackground = SKShapeNode(rectOf: CGSize(width: size.width, height: zoneHeight))
        referenceBackground.fillColor = SKColor.systemGray6.withAlphaComponent(0.3)
        referenceBackground.strokeColor = .clear
        referenceBackground.position = .zero
        referenceBackground.zPosition = -1
        referenceZone.addChild(referenceBackground)
        
        // ASSEMBLY ZONE - Middle 1/3 ("physical table")
        assemblyZone = SKNode()
        assemblyZone.position = CGPoint(x: size.width / 2, y: size.height / 2)
        assemblyZone.zPosition = 1
        addChild(assemblyZone)
        
        // Assembly zone bounds for detection
        assemblyZoneBounds = CGRect(
            x: 0,
            y: zoneHeight,
            width: size.width,
            height: zoneHeight
        )
        
        // Visual boundary for assembly zone
        // Note: SKShapeNode doesn't support dashed lines directly, so we'll use a solid border
        let borderRect = CGRect(x: -size.width/2 + 10, y: -zoneHeight/2 + 10, 
                               width: size.width - 20, height: zoneHeight - 20)
        assemblyBoundary = SKShapeNode(rect: borderRect, cornerRadius: 8)
        assemblyBoundary.strokeColor = .systemBlue.withAlphaComponent(0.4)
        assemblyBoundary.fillColor = .clear
        assemblyBoundary.lineWidth = 2
        assemblyBoundary.position = .zero
        assemblyBoundary.zPosition = -1
        assemblyZone.addChild(assemblyBoundary)
        
        // STORAGE ZONE - Bottom 1/3 (piece storage)
        storageZone = SKNode()
        storageZone.position = CGPoint(x: size.width / 2, y: zoneHeight / 2)
        storageZone.zPosition = 1
        addChild(storageZone)
        
        // Storage zone bounds
        storageZoneBounds = CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: zoneHeight
        )
    }
    
    // MARK: - Puzzle Loading
    
    func loadPuzzle(_ puzzle: GamePuzzleData) {
        self.puzzle = puzzle
        
        // Clear existing pieces
        availablePieces.removeAll()
        assembledPieces.removeAll()
        anchorPiece = nil
        
        referenceZone.removeAllChildren()
        assemblyZone.removeAllChildren()
        storageZone.removeAllChildren()
        
        // Re-add assembly boundary
        setupAssemblyBoundary()
        
        // Load reference display in top zone
        loadReferenceDisplay(puzzle)
        
        // Scatter pieces in storage zone
        scatterPiecesInStorage(puzzle.targetPieces)
    }
    
    private func setupAssemblyBoundary() {
        let zoneHeight = size.height / 3
        
        // Create a solid border since SKShapeNode doesn't support dashed lines
        let borderRect = CGRect(x: -size.width/2 + 10, y: -zoneHeight/2 + 10,
                               width: size.width - 20, height: zoneHeight - 20)
        let border = SKShapeNode(rect: borderRect, cornerRadius: 8)
        border.strokeColor = .systemBlue.withAlphaComponent(0.4)
        border.fillColor = .clear
        border.lineWidth = 2
        border.position = .zero
        border.zPosition = -1
        assemblyZone.addChild(border)
    }
    
    private func loadReferenceDisplay(_ puzzle: GamePuzzleData) {
        // Calculate bounds for centering
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        // First pass: calculate bounds
        for target in puzzle.targetPieces {
            let vertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
            let scaled = TangramGameGeometry.scaleVertices(vertices, by: TangramGameConstants.visualScale * 0.6) // Smaller for reference
            let transformed = TangramGameGeometry.transformVertices(scaled, with: target.transform)
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        // Second pass: create reference pieces
        for target in puzzle.targetPieces {
            let vertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
            let scaled = TangramGameGeometry.scaleVertices(vertices, by: TangramGameConstants.visualScale * 0.6)
            let transformed = TangramGameGeometry.transformVertices(scaled, with: target.transform)
            
            // Center the vertices
            let centered = transformed.map { vertex in
                CGPoint(x: vertex.x - centerX, y: -(vertex.y - centerY)) // Flip Y for SpriteKit
            }
            
            // Create path
            let path = UIBezierPath()
            if let first = centered.first {
                path.move(to: first)
                for vertex in centered.dropFirst() {
                    path.addLine(to: vertex)
                }
                path.close()
            }
            
            // Create reference piece (non-interactive)
            let referencePiece = SKShapeNode(path: path.cgPath)
            referencePiece.fillColor = TangramColors.Sprite.uiColor(for: target.pieceType).withAlphaComponent(0.6)
            referencePiece.strokeColor = referencePiece.fillColor.darker(by: 20)
            referencePiece.lineWidth = 1
            referencePiece.position = .zero
            referenceZone.addChild(referencePiece)
        }
        
        // Add label
        let label = SKLabelNode(text: puzzle.name)
        label.fontName = "System"
        label.fontSize = 14
        label.fontColor = .label
        label.position = CGPoint(x: 0, y: -size.height / 6 + 20)
        referenceZone.addChild(label)
    }
    
    private func scatterPiecesInStorage(_ targets: [GamePuzzleData.TargetPiece]) {
        let zoneHeight = size.height / 3
        let margin: CGFloat = 30
        
        // Create grid positions for pieces
        let cols = 3
        let rows = 3
        
        for (index, target) in targets.enumerated() {
            // Create piece node with unique ID
            let piece = CVPuzzlePieceNode(pieceType: target.pieceType)
            piece.id = UUID().uuidString
            
            // Calculate grid position with randomization
            let col = index % cols
            let row = index / cols
            
            let xSpacing = (size.width - 2 * margin) / CGFloat(cols)
            let ySpacing = (zoneHeight - 2 * margin) / CGFloat(rows)
            
            let baseX = margin + xSpacing * (CGFloat(col) + 0.5) - size.width / 2
            let baseY = margin + ySpacing * (CGFloat(row) + 0.5) - zoneHeight / 2
            
            // Add random offset
            let randomX = CGFloat.random(in: -20...20)
            let randomY = CGFloat.random(in: -20...20)
            
            piece.position = CGPoint(
                x: baseX + randomX,
                y: baseY + randomY
            )
            
            // Random rotation for natural scatter
            piece.zRotation = CGFloat.random(in: 0...(2 * .pi))
            piece.zPosition = CGFloat(index)
            
            availablePieces[target.pieceType.rawValue] = piece
            storageZone.addChild(piece)
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Find tapped piece
        let nodes = self.nodes(at: location)
        for node in nodes {
            if let piece = node as? CVPuzzlePieceNode {
                selectedPiece = piece
                piece.zPosition = 1000  // Bring to front
                lastZoneForSelectedPiece = getZone(for: piece.position)
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let selected = selectedPiece else { return }
        
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        
        // Simple drag - NO SNAPPING
        let deltaX = location.x - previousLocation.x
        let deltaY = location.y - previousLocation.y
        selected.position.x += deltaX
        selected.position.y += deltaY
        
        // Check zone transition for haptic feedback
        let currentZone = getZone(for: selected.position)
        if currentZone != lastZoneForSelectedPiece {
            if currentZone == .assembly {
                // Entering assembly zone
                impactFeedback.impactOccurred()
            }
            lastZoneForSelectedPiece = currentZone
        }
        
        // Generate CV output during drag
        generateCVOutputStream()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let selected = selectedPiece else { return }
        
        // Check which zone the piece is in
        let finalZone = getZone(for: selected.position)
        
        if finalZone == .assembly {
            handlePiecePlacement(selected, at: selected.position)
        } else {
            handlePieceRemoval(selected)
        }
        
        // Reset z-position
        selected.zPosition = CGFloat(availablePieces.count)
        selectedPiece = nil
        
        // Generate final CV output
        generateCVOutputStream()
    }
    
    // MARK: - Zone Detection
    
    private func getZone(for position: CGPoint) -> Zone {
        let zoneHeight = size.height / 3
        
        if position.y >= 2 * zoneHeight {
            return .reference
        } else if position.y >= zoneHeight {
            return .assembly
        } else {
            return .storage
        }
    }
    
    // MARK: - Anchor Management
    
    private func handlePiecePlacement(_ piece: CVPuzzlePieceNode, at position: CGPoint) {
        // First piece becomes anchor
        if anchorPiece == nil && assembledPieces.isEmpty {
            setAsAnchor(piece)
        }
        
        // Add to assembled pieces
        if !assembledPieces.contains(where: { $0.id == piece.id }) {
            assembledPieces.append(piece)
        }
        
        // Notify view model
        onPiecePlaced?(piece, true)
        
        // Generate CV output
        generateCVOutputStream()
    }
    
    private func handlePieceRemoval(_ piece: CVPuzzlePieceNode) {
        // Remove from assembled pieces
        assembledPieces.removeAll { $0.id == piece.id }
        
        // If this was the anchor, promote a new one
        if piece == anchorPiece {
            anchorPiece = nil
            piece.isAnchor = false
            removeAnchorIndicator(from: piece)
            
            // Promote new anchor if pieces remain
            if !assembledPieces.isEmpty {
                promoteNewAnchor()
            }
        }
        
        // Notify view model
        onPiecePlaced?(piece, false)
        
        // Generate CV output
        generateCVOutputStream()
    }
    
    private func setAsAnchor(_ piece: CVPuzzlePieceNode) {
        // Clear any existing anchor
        if let oldAnchor = anchorPiece {
            oldAnchor.isAnchor = false
            removeAnchorIndicator(from: oldAnchor)
        }
        
        // Set new anchor
        anchorPiece = piece
        piece.isAnchor = true
        
        // Visual feedback - small green circle
        let anchorIndicator = SKShapeNode(circleOfRadius: 5)
        anchorIndicator.fillColor = .systemGreen
        anchorIndicator.strokeColor = .systemGreen.darker(by: 20)
        anchorIndicator.lineWidth = 1
        anchorIndicator.position = .zero
        anchorIndicator.zPosition = -1
        anchorIndicator.name = "anchorIndicator"
        piece.addChild(anchorIndicator)
        
        // Notify view model
        onAnchorChanged?(piece)
        
        print("🎯 Anchor established: \(piece.pieceType?.rawValue ?? "unknown")")
    }
    
    private func removeAnchorIndicator(from piece: CVPuzzlePieceNode) {
        piece.childNode(withName: "anchorIndicator")?.removeFromParent()
    }
    
    private func promoteNewAnchor() {
        let newAnchor: CVPuzzlePieceNode?
        
        if isCVMode {
            // CV mode: largest stable piece
            newAnchor = assembledPieces
                .filter { hasBeenStableForFrames($0, frames: 5) }
                .max { p1, p2 in
                    getPieceArea(p1.pieceType) < getPieceArea(p2.pieceType)
                }
        } else {
            // Touch mode: oldest piece (first in array)
            newAnchor = assembledPieces.first
        }
        
        if let anchor = newAnchor {
            setAsAnchor(anchor)
            print("🔄 Anchor promoted to: \(anchor.pieceType?.rawValue ?? "unknown")")
        }
    }
    
    private func hasBeenStableForFrames(_ piece: CVPuzzlePieceNode, frames: Int) -> Bool {
        guard let id = piece.id else { return false }
        return (pieceStabilityFrames[id] ?? 0) >= frames
    }
    
    private func getPieceArea(_ type: TangramPieceType?) -> Double {
        guard let type = type else { return 0 }
        
        switch type {
        case .largeTriangle1, .largeTriangle2:
            return 2.0
        case .mediumTriangle, .square, .parallelogram:
            return 1.0
        case .smallTriangle1, .smallTriangle2:
            return 0.5
        }
    }
    
    // MARK: - CV Output Generation
    
    private func generateCVOutputStream() {
        // Throttle to 20Hz
        let now = CACurrentMediaTime()
        guard now - lastCVEmissionTime >= cvEmissionInterval else { return }
        lastCVEmissionTime = now
        
        guard !assembledPieces.isEmpty else {
            onCVDataGenerated?(["schema_version": 1, "objects": []])
            return
        }
        
        let referencePoint = anchorPiece?.position ?? assembledPieces.first?.position ?? .zero
        
        let cvObjects = assembledPieces.map { piece in
            [
                "name": mapTypeToCV(piece.pieceType),
                "object_id": piece.id ?? UUID().uuidString,
                "pose": [
                    "rotation_degrees": piece.zRotation * 180.0 / .pi,
                    "translation": [
                        piece.position.x - referencePoint.x,
                        -(piece.position.y - referencePoint.y)  // Y-up for CV
                    ]
                ],
                "is_anchor": piece.isAnchor,
                "confidence": 1.0,
                "stability_ms": 0  // Will track this later
            ] as [String : Any]
        }
        
        let cvData: [String: Any] = [
            "schema_version": 1,
            "objects": cvObjects,
            "anchor_id": anchorPiece?.id ?? "none",
            "homography_applied": true  // Touch coords are already plane-aligned
        ]
        
        onCVDataGenerated?(cvData)
        
        #if DEBUG
        print("📸 CV Stream: \(assembledPieces.count) pieces, anchor: \(anchorPiece?.pieceType?.rawValue ?? "none")")
        #endif
    }
    
    private func mapTypeToCV(_ type: TangramPieceType?) -> String {
        switch type {
        case .square: return "tangram_square"
        case .smallTriangle1: return "tangram_triangle_sml"
        case .smallTriangle2: return "tangram_triangle_sml2"
        case .mediumTriangle: return "tangram_triangle_med"
        case .largeTriangle1: return "tangram_triangle_lrg"
        case .largeTriangle2: return "tangram_triangle_lrg2"
        case .parallelogram: return "tangram_parallelogram"
        default: return "unknown"
        }
    }
}