//
//  TangramScenePieceFactory.swift
//  Bemo
//
//  Handles piece and target creation for TangramPuzzleScene
//

// WHAT: Factory for creating physical pieces and target silhouettes in the scene
// ARCHITECTURE: Component of TangramPuzzleScene handling piece creation and setup
// USAGE: Called by scene during puzzle loading to create all visual elements

import SpriteKit
import Foundation

extension TangramPuzzleScene {
    
    // MARK: - Physical Piece Creation
    
    func createPhysicalPieces(_ puzzle: GamePuzzleData) {
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
        
        for (index, target) in puzzle.targetPieces.enumerated() {
            let piece = PuzzlePieceNode(pieceType: target.pieceType)
            piece.name = "piece_\(target.pieceType)"
            
            // Initialize piece metadata (do NOT pre-bind to a specific target; bind on first valid match)
            piece.userData = piece.userData ?? [:]
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
    
    // MARK: - Target Silhouette Creation
    
    func setupTargetPuzzle(_ puzzle: GamePuzzleData) {
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
            // Persist piece type on silhouette for color fill updates
            silhouette.userData = (silhouette.userData ?? NSMutableDictionary())
            silhouette.userData?["pieceType"] = target.pieceType.rawValue
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
        // Style depends on current difficulty setting (scene property set by host/VM)
        switch TangramGameConstants.VisualDifficultyStyle.style(for: difficultySetting) {
        case .easyColoredOutlines:
            silhouette.fillColor = .clear
            silhouette.strokeColor = TangramColors.Sprite.uiColor(for: target.pieceType)
            silhouette.lineWidth = 3
            silhouette.alpha = 0.85
        case .mediumStandard:
            silhouette.fillColor = .clear
            silhouette.strokeColor = .systemGray2
            silhouette.lineWidth = 2
            silhouette.alpha = 0.6
        case .hardAllBlack:
            silhouette.fillColor = .black
            silhouette.strokeColor = .black
            silhouette.lineWidth = 0
            silhouette.alpha = 1.0
        }
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
    
    // MARK: - CV Visualization Creation
    
    func createCVVisualization(for pieceId: String) {
        // Clean up existing CV piece if any
        cvPieces[pieceId]?.removeFromParent()
        
        // Create a shape node that mirrors the physical piece geometry
        guard let physicalPiece = availablePieces.first(where: { $0.name == pieceId }),
              let pieceType = physicalPiece.pieceType else { return }

        let path = CGMutablePath()
        let normalized = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaled = TangramGameGeometry.scaleVertices(normalized, by: TangramGameConstants.visualScale)
        // Center path around origin so we can position by centroid accurately
        let centroid = TangramGameGeometry.centerOfVertices(scaled)
        if let first = scaled.first {
            path.move(to: CGPoint(x: first.x - centroid.x, y: first.y - centroid.y))
            for v in scaled.dropFirst() {
                path.addLine(to: CGPoint(x: v.x - centroid.x, y: v.y - centroid.y))
            }
            path.closeSubpath()
        }

        let cvPiece = SKShapeNode(path: path)
        cvPiece.name = "cv_\(pieceId)"
        cvPiece.fillColor = TangramColors.Sprite.uiColor(for: pieceType).withAlphaComponent(0.6)
        cvPiece.strokeColor = TangramColors.Sprite.uiColor(for: pieceType)
        cvPiece.lineWidth = 1
        // Start with same scale as physical piece so transformed edge distances match once cvContent uniform scale is applied
        cvPiece.xScale = max(0.0001, abs(physicalPiece.xScale))
        cvPiece.yScale = max(0.0001, abs(physicalPiece.yScale))
        if physicalPiece.isFlipped { cvPiece.xScale *= -1 }

        // Add to top mirror content, not cvContent, to ensure mapping matches mirror layer
        if cvPiece.parent !== topMirrorContent { topMirrorContent.addChild(cvPiece) }
        cvPieces[pieceId] = cvPiece
    }
    
    // MARK: - Visual Effects
    
    func applyValidatedFill(to targetNode: SKShapeNode, for pieceType: TangramPieceType) {
        // Fill the silhouette with the piece's color when validated
        targetNode.fillColor = TangramColors.Sprite.uiColor(for: pieceType).withAlphaComponent(0.7)
        targetNode.strokeColor = TangramColors.Sprite.uiColor(for: pieceType)
        targetNode.lineWidth = 2
        targetNode.alpha = 1.0
    }
    
    func applyOrientedFill(to targetNode: SKShapeNode, for pieceType: TangramPieceType) {
        // Partial fill (orientation/flip correct, position not yet correct)
        targetNode.fillColor = TangramColors.Sprite.uiColor(for: pieceType).withAlphaComponent(0.25)
        // Keep stroke subtle to distinguish from validated
        targetNode.strokeColor = TangramColors.Sprite.uiColor(for: pieceType).withAlphaComponent(0.5)
        targetNode.lineWidth = 2
        targetNode.alpha = 1.0
    }
    
    func showPieceCelebration(_ piece: PuzzlePieceNode) {
        // Create a brief celebration effect on the piece
        let scale = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.1),
            SKAction.scale(to: 0.8, duration: 0.1)  // Back to original scale (pieces are at 0.8)
        ])
        
        // Create particle effect
        let particleNode = SKShapeNode(circleOfRadius: 5)
        particleNode.fillColor = .systemGreen
        particleNode.position = piece.position
        physicalWorldSection.addChild(particleNode)
        
        let expand = SKAction.scale(to: 3, duration: 0.5)
        let fade = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        particleNode.run(SKAction.sequence([
            SKAction.group([expand, fade]),
            remove
        ]))
        
        piece.run(scale)
    }
    
    func showPuzzleCompleteCelebration() {
        // Create a celebration overlay
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = .clear
        overlay.zPosition = 5000
        addChild(overlay)
        
        // Create "Puzzle Complete!" label
        let label = SKLabelNode(text: "🎉 Puzzle Complete! 🎉")
        label.fontSize = 48
        label.fontName = "System-Bold"
        label.fontColor = .systemGreen
        label.position = CGPoint(x: 0, y: 0)
        overlay.addChild(label)
        
        // Animate the label
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        label.run(SKAction.repeat(pulse, count: 3))
        
        // Create confetti particles
        for _ in 0..<20 {
            let particle = SKShapeNode(circleOfRadius: 5)
            particle.fillColor = [UIColor.systemRed, .systemGreen, .systemBlue, .systemYellow].randomElement()!
            particle.position = CGPoint(
                x: CGFloat.random(in: -size.width/2...size.width/2),
                y: size.height/2
            )
            overlay.addChild(particle)
            
            let fall = SKAction.moveBy(x: CGFloat.random(in: -50...50), y: -size.height, duration: 2)
            let rotate = SKAction.rotate(byAngle: .pi * 4, duration: 2)
            let fade = SKAction.fadeOut(withDuration: 2)
            particle.run(SKAction.group([fall, rotate, fade]))
        }
        
        // Remove overlay after animation
        overlay.run(SKAction.sequence([
            SKAction.wait(forDuration: 3),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    func showValidationCheckmark(over targetNode: SKShapeNode) {
        // Show green checkmark above the validated target silhouette
        let checkmark = SKLabelNode(text: "✓")
        checkmark.name = "validation_check_\(targetNode.name ?? "")"
        checkmark.fontSize = 24
        checkmark.fontName = "System-Bold"
        checkmark.fontColor = .systemGreen
        
        // Position above the target centroid
        let centroid = (targetNode.userData?["centroidSK"] as? NSValue)?.cgPointValue ?? .zero
        checkmark.position = CGPoint(x: centroid.x, y: centroid.y + 30)
        checkmark.zPosition = 100
        
        // Add to target's parent (puzzleContainer)
        targetNode.parent?.addChild(checkmark)
        
        // Animate checkmark
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        checkmark.run(SKAction.sequence([scaleUp, scaleDown, wait, fadeOut, remove]))
    }
}