//
//  TangramThreeZoneScene.swift
//  Bemo
//
//  Three-zone puzzle scene for TangramCV game
//

// WHAT: SpriteKit scene with three zones for CV puzzle simulation
// ARCHITECTURE: View layer in MVVM-S, delegates business logic
// USAGE: Renders puzzle state and handles touch input only

import SpriteKit
import UIKit

class TangramThreeZoneScene: SKScene {
    
    // MARK: - Scene Graph Properties
    
    private var referenceZone: SKNode!     // Top 2/5 - shows target
    private var assemblyZone: SKNode!      // Middle 2/5 - assembly area
    private var storageZone: SKNode!       // Bottom 1/5 - piece storage
    
    private var assemblyZoneBounds: CGRect = .zero
    private var storageZoneBounds: CGRect = .zero
    
    // MARK: - State Management
    
    /// Single source of truth for all game state
    private let gameState = TangramCVPuzzleState()
    
    /// Game delegate for business logic coordination
    weak var gameDelegate: TangramCVSceneDelegate?
    
    // MARK: - Configuration
    
    var isCVMode: Bool = false
    
    // MARK: - UI Feedback
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .systemBackground
        setupZones()
        
        // Load any pending puzzle now that zones are ready
        if let pendingPuzzle = gameState.pendingPuzzle {
            gameState.pendingPuzzle = nil
            loadPuzzle(pendingPuzzle)
        }
    }
    
    // MARK: - Setup
    
    private func setupZones() {
        let referenceHeight = size.height * 2.0 / 5.0
        let assemblyHeight = size.height * 2.0 / 5.0
        let storageHeight = size.height * 1.0 / 5.0
        
        // REFERENCE ZONE
        referenceZone = SKNode()
        referenceZone.position = CGPoint(x: size.width / 2, y: size.height - referenceHeight / 2)
        referenceZone.zPosition = 0
        addChild(referenceZone)
        
        // ASSEMBLY ZONE
        assemblyZone = SKNode()
        assemblyZone.position = CGPoint(x: size.width / 2, y: storageHeight + assemblyHeight / 2)
        assemblyZone.zPosition = 1
        addChild(assemblyZone)
        
        assemblyZoneBounds = CGRect(
            x: 0,
            y: storageHeight,
            width: size.width,
            height: assemblyHeight
        )
        
        // STORAGE ZONE
        storageZone = SKNode()
        storageZone.position = CGPoint(x: size.width / 2, y: storageHeight / 2)
        storageZone.zPosition = 1
        addChild(storageZone)
        
        storageZoneBounds = CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: storageHeight
        )
        
        impactFeedback.prepare()
    }
    
    // MARK: - Public Interface
    
    func loadPuzzle(_ puzzle: GamePuzzleData) {
        // CRITICAL: Reset state BEFORE clearing zones
        // This ensures piece references are cleared before nodes are removed
        gameState.reset()  // Clear all dictionaries and references FIRST
        
        // Now safe to load the new puzzle
        gameState.loadPuzzle(puzzle)
        
        // Only proceed if zones are initialized (scene is in view)
        guard referenceZone != nil, assemblyZone != nil, storageZone != nil else {
            // Store puzzle to load later when scene is ready
            gameState.pendingPuzzle = puzzle
            return
        }
        
        // Clear all children from zones
        clearAllZones()
        
        // Setup zones
        setupZoneBackgrounds()
        
        // Load new puzzle
        loadReferenceDisplay(puzzle)
        scatterPiecesInStorage(puzzle.targetPieces)
    }
    
    private func clearAllZones() {
        // Safe unwrapping in case this is called before zones are initialized
        referenceZone?.removeAllChildren()
        assemblyZone?.removeAllChildren()
        storageZone?.removeAllChildren()
    }
    
    private func setupZoneBackgrounds() {
        // Reference zone background
        let referenceHeight = size.height * 2.0 / 5.0
        let referenceBackground = SKShapeNode(rectOf: CGSize(width: size.width, height: referenceHeight))
        referenceBackground.fillColor = SKColor.systemGray6.withAlphaComponent(0.3)
        referenceBackground.strokeColor = .clear
        referenceBackground.position = .zero
        referenceBackground.zPosition = -1
        referenceZone.addChild(referenceBackground)
        
        // Assembly zone boundary
        let assemblyHeight = size.height * 2.0 / 5.0
        let borderRect = CGRect(
            x: -size.width/2 + 10,
            y: -assemblyHeight/2 + 10,
            width: size.width - 20,
            height: assemblyHeight - 20
        )
        let border = SKShapeNode(rect: borderRect, cornerRadius: 8)
        border.strokeColor = .systemBlue.withAlphaComponent(0.4)
        border.fillColor = .clear
        border.lineWidth = 2
        border.position = .zero
        border.zPosition = -1
        assemblyZone.addChild(border)
    }
    
    private func loadReferenceDisplay(_ puzzle: GamePuzzleData) {
        // Calculate bounds EXACTLY like original game
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for target in puzzle.targetPieces {
            let vertices = TangramCVGeometry.normalizedVertices(for: target.pieceType)
            let scaled = TangramCVGeometry.scaleVertices(vertices, by: TangramCVConstants.visualScale)
            let transformed = TangramCVGeometry.transformVertices(scaled, with: target.transform)
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        let puzzleBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let puzzleCenterX = (minX + maxX) / 2
        let puzzleCenterY = (minY + maxY) / 2
        
        // Create a container for reference pieces to allow scaling
        let referenceContent = SKNode()
        referenceContent.position = .zero
        
        // Calculate scale to fit in reference zone
        let referenceHeight = size.height * 2.0 / 5.0
        let margin: CGFloat = 40
        let scaleX = (size.width - margin) / puzzleBounds.width
        let scaleY = (referenceHeight - margin) / puzzleBounds.height
        let scale = min(scaleX, scaleY, 1.0) * TangramCVConstants.referenceScale
        referenceContent.setScale(scale)
        
        referenceZone.addChild(referenceContent)
        
        // Create reference pieces EXACTLY like original
        for target in puzzle.targetPieces {
            let vertices = TangramCVGeometry.normalizedVertices(for: target.pieceType)
            let scaled = TangramCVGeometry.scaleVertices(vertices, by: TangramCVConstants.visualScale)
            let transformed = TangramCVGeometry.transformVertices(scaled, with: target.transform)
            
            // Calculate center EXACTLY like original
            var centerX: CGFloat = 0
            var centerY: CGFloat = 0
            for vertex in transformed {
                centerX += vertex.x
                centerY += vertex.y
            }
            centerX /= CGFloat(transformed.count)
            centerY /= CGFloat(transformed.count)
            
            // Create centered vertices EXACTLY like original
            let path = UIBezierPath()
            if let first = transformed.first {
                let adjustedFirst = CGPoint(
                    x: first.x - centerX,
                    y: -(first.y - centerY)  // Flip Y for SpriteKit after centering
                )
                path.move(to: adjustedFirst)
                
                for vertex in transformed.dropFirst() {
                    let adjustedVertex = CGPoint(
                        x: vertex.x - centerX,
                        y: -(vertex.y - centerY)  // Flip Y for SpriteKit after centering
                    )
                    path.addLine(to: adjustedVertex)
                }
                path.close()
            }
            
            let referencePiece = SKShapeNode(path: path.cgPath)
            referencePiece.fillColor = TangramCVColors.targetSilhouetteColor.withAlphaComponent(TangramCVConstants.targetPieceAlpha)
            referencePiece.strokeColor = TangramCVColors.targetStrokeColor
            referencePiece.lineWidth = TangramCVConstants.referencePieceStrokeWidth
            
            // Position relative to puzzle center for zone-local coordinates
            referencePiece.position = CGPoint(
                x: centerX - puzzleCenterX,
                y: -(centerY - puzzleCenterY)
            )
            
            referenceContent.addChild(referencePiece)
        }
        
        // Center the entire puzzle in the reference zone
        // The referenceZone itself is already positioned correctly in setupZones()
    }
    
    private func scatterPiecesInStorage(_ targets: [GamePuzzleData.TargetPiece]) {
        let storageHeight = size.height * 1.0 / 5.0
        let margin: CGFloat = TangramCVConstants.storageZoneMargin
        
        let cols = 3
        let rows = 3
        
        for (index, target) in targets.enumerated() {
            let piece = CVPuzzlePieceNode(pieceType: target.pieceType)
            piece.id = UUID().uuidString
            
            let col = index % cols
            let row = index / cols
            
            let xSpacing = (size.width - 2 * margin) / CGFloat(cols)
            let ySpacing = (storageHeight - 2 * margin) / CGFloat(rows)
            
            let baseX = margin + xSpacing * (CGFloat(col) + 0.5) - size.width / 2
            let baseY = margin + ySpacing * (CGFloat(row) + 0.5) - storageHeight / 2
            
            let randomX = CGFloat.random(in: -20...20)
            let randomY = CGFloat.random(in: -20...20)
            
            piece.position = CGPoint(x: baseX + randomX, y: baseY + randomY)
            piece.zRotation = CGFloat.random(in: 0...(2 * .pi))
            piece.zPosition = CGFloat(index)
            
            gameState.availablePieces[target.pieceType.rawValue] = piece
            storageZone.addChild(piece)
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        let nodes = self.nodes(at: location)
        for node in nodes {
            if let piece = node as? CVPuzzlePieceNode {
                gameState.selectedPiece = piece
                gameState.lastZoneForSelectedPiece = getZone(for: piece.position)
                piece.zPosition = 1000
                
                gameDelegate?.sceneDidSelectPiece(piece)
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let selected = gameState.selectedPiece else { return }
        
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        
        // Move piece
        let deltaX = location.x - previousLocation.x
        let deltaY = location.y - previousLocation.y
        selected.position.x += deltaX
        selected.position.y += deltaY
        
        // Check zone transition
        let currentZone = getZone(for: selected.position)
        if currentZone != gameState.lastZoneForSelectedPiece {
            gameDelegate?.sceneDidMovePiece(selected, 
                                       from: gameState.lastZoneForSelectedPiece, 
                                       to: currentZone)
            
            if currentZone == .assembly {
                impactFeedback.impactOccurred()
            }
            
            gameState.lastZoneForSelectedPiece = currentZone
        }
        
        // Request CV generation
        if isCVMode {
            gameDelegate?.sceneRequestsCVGeneration(state: gameState)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let selected = gameState.selectedPiece else { return }
        
        let currentZone = getZone(for: selected.position)
        
        // Update state based on zone
        if currentZone == .assembly {
            gameState.addAssembledPiece(selected)
            gameDelegate?.sceneDidAddPieceToAssembly(selected)
            
            // Check for anchor update
            gameDelegate?.sceneRequestsAnchorUpdate(
                currentAnchor: gameState.anchorPiece,
                assembledPieces: gameState.assembledPieces
            )
        } else {
            gameState.removeAssembledPiece(selected)
            gameDelegate?.sceneDidRemovePieceFromAssembly(selected)
        }
        
        gameDelegate?.sceneDidReleasePiece(selected, in: currentZone)
        
        // Check completion
        if gameDelegate?.sceneRequestsCompletionCheck(state: gameState) == true {
            // Puzzle complete!
        }
        
        gameState.selectedPiece = nil
    }
    
    // MARK: - Helpers
    
    private func getZone(for position: CGPoint) -> Zone {
        if assemblyZoneBounds.contains(position) {
            return .assembly
        } else if storageZoneBounds.contains(position) {
            return .storage
        } else if position.y > assemblyZoneBounds.maxY {
            return .reference
        }
        return .unknown
    }
    
    // MARK: - Public Accessors (for ViewModel)
    
    var currentState: TangramCVPuzzleState {
        return gameState
    }
    
    func updateAnchor(_ piece: CVPuzzlePieceNode?) {
        gameState.setAnchor(piece)
    }
}