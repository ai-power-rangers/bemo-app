//
//  PuzzlePieceNode.swift
//  Bemo
//
//  SpriteKit node representing a tangram puzzle piece
//

// WHAT: SKNode subclass that represents a draggable tangram piece with shape and state
// ARCHITECTURE: View component in MVVM-S, used by TangramPuzzleScene
// USAGE: Created for each puzzle piece, handles rendering and flip state

import SpriteKit
import UIKit

class PuzzlePieceNode: SKNode {
    var pieceType: TangramPieceType?
    var isSelected: Bool = false
    var isCompleted: Bool = false
    var isFlipped: Bool = false  // Track if piece is flipped
    var shapeNode: SKShapeNode?  // Made public for nudge color changes
    
    // State tracking
    var pieceState: PieceState?
    private var stateIndicator: SKNode?
    
    init(pieceType: TangramPieceType) {
        super.init()
        
        self.pieceType = pieceType
        self.name = "piece_\(pieceType.rawValue)"
        
        // Add stable ID for CV compatibility
        self.userData = [
            "pieceID": pieceType.rawValue,
            "pieceType": pieceType.rawValue
        ]
        
        // Initialize piece state
        self.pieceState = PieceState(pieceId: "piece_\(pieceType.rawValue)", pieceType: pieceType)
        
        // Create shape node with proper geometry
        let shapeNode = createShape(for: pieceType)
        self.shapeNode = shapeNode
        addChild(shapeNode)
        
        // Create state indicator (initially hidden)
        createStateIndicator()
        
        // Compute and store local feature angle
        computeAndStoreLocalFeatureAngle()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createShape(for pieceType: TangramPieceType) -> SKShapeNode {
        // Get normalized vertices from geometry
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        
        // Scale vertices to visual size
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        
        // Calculate the centroid of the scaled vertices
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        for vertex in scaledVertices {
            centerX += vertex.x
            centerY += vertex.y
        }
        centerX /= CGFloat(scaledVertices.count)
        centerY /= CGFloat(scaledVertices.count)
        
        // Create path with vertices centered around origin (0,0)
        // This makes the SKNode's position represent the piece's centroid
        let path = UIBezierPath()
        if let firstVertex = scaledVertices.first {
            // Center the vertices around (0,0) by subtracting the centroid
            let adjustedFirst = CGPoint(
                x: firstVertex.x - centerX,
                y: firstVertex.y - centerY
            )
            path.move(to: adjustedFirst)
            
            for vertex in scaledVertices.dropFirst() {
                let adjustedVertex = CGPoint(
                    x: vertex.x - centerX,
                    y: vertex.y - centerY
                )
                path.addLine(to: adjustedVertex)
            }
            path.close()
        }
        
        let shape = SKShapeNode(path: path.cgPath)
        shape.fillColor = TangramColors.Sprite.uiColor(for: pieceType)
        shape.strokeColor = shape.fillColor.darker(by: 20)
        shape.lineWidth = 2
        
        return shape
    }
    
    func flip() {
        // Flip the piece horizontally
        isFlipped = !isFlipped
        
        // Recreate the shape with flipped geometry centered at origin
        if let oldShape = shapeNode {
            oldShape.removeFromParent()
        }
        
        guard let pieceType = pieceType else { return }
        
        // Get the vertices
        let normalizedVertices = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
        
        // Flip vertices horizontally if needed
        let finalVertices: [CGPoint]
        if isFlipped {
            // Flip X coordinates
            finalVertices = scaledVertices.map { CGPoint(x: -$0.x, y: $0.y) }
        } else {
            finalVertices = scaledVertices
        }
        
        // Compute centroid from the FINAL vertices (after flip if applicable)
        let centroid = TangramGameGeometry.centerOfVertices(finalVertices)
        
        // Create path from vertices
        let path = UIBezierPath()
        if let firstVertex = finalVertices.first {
            // Center vertices around origin so node's position is the piece centroid
            let first = CGPoint(x: firstVertex.x - centroid.x, y: firstVertex.y - centroid.y)
            path.move(to: first)
            for vertex in finalVertices.dropFirst() {
                let adjusted = CGPoint(x: vertex.x - centroid.x, y: vertex.y - centroid.y)
                path.addLine(to: adjusted)
            }
            path.close()
        }
        
        // Create new shape
        let newShape = SKShapeNode(path: path.cgPath)
        newShape.fillColor = TangramColors.Sprite.uiColor(for: pieceType)
        newShape.strokeColor = newShape.fillColor.darker(by: 20)
        newShape.lineWidth = 2
        
        self.shapeNode = newShape
        addChild(newShape)
        
        // Recompute local feature angle after flip
        computeAndStoreLocalFeatureAngle()
    }
    
    /// Create visual indicator for state
    private func createStateIndicator() {
        let indicator = SKNode()
        
        // State icon background
        let background = SKShapeNode(circleOfRadius: 15)
        background.fillColor = .clear
        background.strokeColor = .clear
        background.position = CGPoint(x: 30, y: 30)
        background.zPosition = 100
        background.name = "stateBackground"
        indicator.addChild(background)
        
        // State icon (checkmark, X, etc.)
        let icon = SKLabelNode(text: "")
        icon.fontSize = 20
        icon.fontName = "System"
        icon.position = CGPoint(x: 30, y: 25)
        icon.zPosition = 101
        icon.name = "stateIcon"
        indicator.addChild(icon)
        
        self.stateIndicator = indicator
        addChild(indicator)
        indicator.isHidden = true
    }
    
    /// Update visual state indicator
    func updateStateIndicator() {
        guard let state = pieceState,
              let indicator = stateIndicator,
              let _ = indicator.childNode(withName: "stateBackground") as? SKShapeNode,
              let _ = indicator.childNode(withName: "stateIcon") as? SKLabelNode else { return }
        
        // Update visibility and appearance based on state
        switch state.state {
        case .unobserved, .detected:
            indicator.isHidden = true
            self.alpha = state.displayOpacity
            
        case .moved:
            indicator.isHidden = true
            self.alpha = state.displayOpacity
            // Add glow effect
            shapeNode?.glowWidth = 2.0
            
        case .placed:
            indicator.isHidden = true
            self.alpha = state.displayOpacity
            // Add pulse animation
            if state.shouldPulse {
                addPulseAnimation()
            }
            
        case .validating:
            // Suppress bottom-area validating icon; keep piece visuals clean
            indicator.isHidden = true
            self.alpha = state.displayOpacity
            
        case .validated:
            // Don't show indicator - validation is shown in target section
            indicator.isHidden = true
            self.alpha = 1.0
            shapeNode?.strokeColor = .systemGreen
            shapeNode?.lineWidth = 2
            shapeNode?.glowWidth = 0
            
        case .invalid(_):
            // Don't show indicator on the piece itself - nudges are shown in target section
            indicator.isHidden = true
            self.alpha = state.displayOpacity
            shapeNode?.strokeColor = .systemRed.withAlphaComponent(0.5)  // Subtle red outline
            shapeNode?.lineWidth = 2
        }
    }
    
    private func addPulseAnimation() {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        shapeNode?.run(SKAction.repeatForever(pulse), withKey: "pulse")
    }
    
    private func showNudge(for reason: ValidationFailure) {
        // This will be implemented to show visual nudges
        // For now, just log the nudge message
        #if DEBUG
        print("Nudge for \(pieceType?.rawValue ?? "unknown"): \(reason.nudgeMessage)")
        #endif
    }
    
    /// Compute and store the local feature angle for this piece
    private func computeAndStoreLocalFeatureAngle() {
        guard let pieceType = pieceType else { return }
        
        // The actual angle the hypotenuse points at when the piece is at zRotation=0
        // For triangles with vertices [(0,0), (2,0), (0,2)], the hypotenuse from (2,0) to (0,2)
        // points at atan2(2, -2) = 135° (3π/4 radians)
        var localFeatureAngle: CGFloat
        switch pieceType {
        case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2:
            localFeatureAngle = 3 * .pi / 4  // 135° - actual hypotenuse direction
        case .square:
            localFeatureAngle = 0
        case .parallelogram:
            localFeatureAngle = 0
        }
        
        // For flipped pieces, negate the feature angle
        // This accounts for the horizontal flip changing the reference direction
        if isFlipped {
            localFeatureAngle = -localFeatureAngle
        }
        
        // Store in userData
        if userData == nil {
            userData = [:]
        }
        userData!["localFeatureAngleSK"] = localFeatureAngle
    }
    
    // MARK: - State Management
    
    /// Mark piece as detected with baseline position
    func markAsDetected(at position: CGPoint, rotation: CGFloat) {
        pieceState?.state = .detected(baseline: position, rotation: rotation, detectedAt: Date())
        pieceState?.currentPosition = position
        pieceState?.currentRotation = rotation
        updateStateIndicator()
    }
    
    /// Mark piece as moved
    func markAsMoved() {
        guard var state = pieceState else { return }
        
        switch state.state {
        case .detected(let baseline, let rotation, _):
            state.state = .moved(from: baseline, rotation: rotation)
            state.interactionCount += 1
            state.lastMovedTime = Date()
            pieceState = state
            
        case .placed, .validated, .invalid:
            // Reset to moved state
            if let baseline = getBaseline() {
                state.state = .moved(from: baseline.position, rotation: baseline.rotation)
                state.lastMovedTime = Date()
                pieceState = state
            }
            
        default:
            break
        }
        
        updateStateIndicator()
    }
    
    /// Mark piece as placed
    func markAsPlaced() {
        pieceState?.markAsPlaced()
        updateStateIndicator()
    }
    
    /// Helper to get baseline from current state
    private func getBaseline() -> (position: CGPoint, rotation: CGFloat)? {
        guard let state = pieceState else { return nil }
        
        switch state.state {
        case .detected(let baseline, let rotation, _):
            return (baseline, rotation)
        case .moved(let from, let rotation):
            return (from, rotation)
        default:
            return (state.currentPosition, state.currentRotation)
        }
    }
}