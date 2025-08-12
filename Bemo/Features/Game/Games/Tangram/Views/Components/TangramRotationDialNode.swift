//
//  TangramRotationDialNode.swift
//  Bemo
//
//  Rotation dial UI component for Tangram puzzle pieces
//

// WHAT: SKNode subclass that provides a rotation dial interface for piece manipulation
// ARCHITECTURE: View component in MVVM-S, used by TangramPuzzleScene
// USAGE: Created when user taps a piece, allows rotation and flip operations

import SpriteKit

class TangramRotationDialNode: SKNode {
    private var dial: SKShapeNode!
    private var handle: SKShapeNode!
    private var angleLabel: SKLabelNode!
    private(set) var targetPiece: PuzzlePieceNode?  // Allow read access for flip button
    private var initialRotation: CGFloat = 0
    private var originalRotation: CGFloat = 0
    private var originalFlipState: Bool = false
    
    // Angle snapping configuration for user assistance (dial-only)
    private let snapAngles: [CGFloat] = stride(from: 0, through: 315, by: 45).map { CGFloat($0) * .pi / 180 }
    private let snapThreshold: CGFloat = 10 * .pi / 180  // Snap within 10 degrees
    private var isSnapped: Bool = false
    private var snapIndicators: [SKShapeNode] = []
    
    func showForPiece(_ piece: PuzzlePieceNode) {
        targetPiece = piece
        initialRotation = piece.zRotation
        originalRotation = piece.zRotation  // Store original for cancel
        originalFlipState = piece.isFlipped  // Store original flip state
        
        // Scale dial to match piece size (pieces are scaled to 0.4)
        let dialRadius: CGFloat = 40  // Reduced from 80 to match piece scale
        
        // Create dial circle
        dial = SKShapeNode(circleOfRadius: dialRadius)
        dial.strokeColor = .systemBlue
        dial.lineWidth = 2
        dial.fillColor = .clear
        dial.alpha = 0.8
        addChild(dial)
        
        // Add angle markers every 45° with snap indicators
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            
            // Regular marker on top
            let marker = SKShapeNode(circleOfRadius: 3)
            marker.fillColor = .white
            marker.strokeColor = .systemBlue
            marker.lineWidth = 1.5
            marker.position = CGPoint(
                x: cos(angle) * dialRadius,
                y: sin(angle) * dialRadius
            )
            dial.addChild(marker)
            
            // Add labels at all 45° increments for clarity
            let label = SKLabelNode(text: "\(i * 45)°")
            label.fontSize = i % 2 == 0 ? 10 : 8  // Larger for cardinal directions
            label.fontColor = i % 2 == 0 ? .systemBlue : .systemGray
            label.fontName = i % 2 == 0 ? "System-Bold" : "System"
            label.position = CGPoint(
                x: cos(angle) * (dialRadius + 18),
                y: sin(angle) * (dialRadius + 18) - 3
            )
            dial.addChild(label)
            
            // Snap indicator dots (hidden until snapped)
            let snapIndicator = SKShapeNode(circleOfRadius: 4)
            snapIndicator.fillColor = .systemGreen.withAlphaComponent(0.3)
            snapIndicator.strokeColor = .systemGreen
            snapIndicator.lineWidth = 1
            snapIndicator.alpha = 0
            snapIndicator.position = CGPoint(
                x: cos(angle) * dialRadius,
                y: sin(angle) * dialRadius
            )
            dial.addChild(snapIndicator)
            snapIndicators.append(snapIndicator)
        }
        
        // Create rotation handle
        handle = SKShapeNode(circleOfRadius: 8)  // Reduced from 12
        handle.fillColor = .systemBlue
        handle.strokeColor = .white
        handle.lineWidth = 2
        // Position handle to match current piece rotation
        // Note: negate angle because SpriteKit zRotation is clockwise
        handle.position = CGPoint(
            x: cos(-initialRotation) * dialRadius,
            y: sin(-initialRotation) * dialRadius
        )
        handle.zPosition = 10
        addChild(handle)
        
        // Add current angle display
        angleLabel = SKLabelNode(text: "\(Int(initialRotation * 180 / .pi))°")
        angleLabel.fontSize = 12  // Smaller font
        angleLabel.fontColor = .systemBlue
        angleLabel.fontName = "System-Bold"
        angleLabel.position = CGPoint(x: 0, y: -(dialRadius + 30))
        addChild(angleLabel)
        
        // Add close button (cancel)
        let closeButton = SKShapeNode(circleOfRadius: 12)  // Smaller button
        closeButton.fillColor = .systemRed
        closeButton.strokeColor = .white
        closeButton.lineWidth = 2
        closeButton.position = CGPoint(x: 35, y: 35)  // Closer to dial
        closeButton.name = "closeRotationDial"
        
        let xLabel = SKLabelNode(text: "✕")
        xLabel.fontSize = 12  // Smaller font
        xLabel.fontColor = .white
        xLabel.position = CGPoint(x: 0, y: -4)
        xLabel.name = "closeRotationDial"
        closeButton.addChild(xLabel)
        
        addChild(closeButton)
        
        // Add save button (confirm)
        let saveButton = SKShapeNode(circleOfRadius: 12)  // Smaller button
        saveButton.fillColor = .systemGreen
        saveButton.strokeColor = .white
        saveButton.lineWidth = 2
        saveButton.position = CGPoint(x: -35, y: 35)  // Closer to dial
        saveButton.name = "saveRotationDial"
        
        let checkLabel = SKLabelNode(text: "✓")
        checkLabel.fontSize = 12  // Smaller font
        checkLabel.fontColor = .white
        checkLabel.position = CGPoint(x: 0, y: -4)
        checkLabel.name = "saveRotationDial"
        saveButton.addChild(checkLabel)
        
        addChild(saveButton)
        
        // Add center button (also saves)
        let centerButton = SKShapeNode(circleOfRadius: 25)
        centerButton.fillColor = .systemBlue.withAlphaComponent(0.3)
        centerButton.strokeColor = .systemBlue
        centerButton.lineWidth = 2
        centerButton.position = CGPoint.zero
        centerButton.name = "saveRotationDial"
        centerButton.zPosition = 5
        
        let saveIcon = SKLabelNode(text: "✓")
        saveIcon.fontSize = 20
        saveIcon.fontColor = .systemBlue
        saveIcon.position = CGPoint(x: 0, y: -7)
        saveIcon.name = "saveRotationDial"
        centerButton.addChild(saveIcon)
        
        addChild(centerButton)
        
        // Add flip button at the bottom - only for parallelogram
        if piece.pieceType == .parallelogram {
            let flipButton = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 15)
            flipButton.fillColor = .systemPurple
            flipButton.strokeColor = .white
            flipButton.lineWidth = 2
            flipButton.position = CGPoint(x: 0, y: -(dialRadius + 60))  // Position relative to dial radius
            flipButton.name = "flipPiece"
            flipButton.zPosition = 10  // Ensure it's on top
            
            let flipLabel = SKLabelNode(text: "↔ Flip")
            flipLabel.fontSize = 14
            flipLabel.fontColor = .white
            flipLabel.position = CGPoint(x: 0, y: -5)
            flipLabel.name = "flipPiece"
            flipButton.addChild(flipLabel)
            
            addChild(flipButton)
        } else {
        }
    }
    
    func updateRotation(to angle: CGFloat) {
        guard let piece = targetPiece else { return }
        
        let dialRadius: CGFloat = 40  // Match the radius used in showForPiece
        
        // Normalize angle to [-π, π] range for consistent behavior
        var normalizedAngle = normalizeAngle(angle)
        
        // Check for snapping to 45-degree increments
        var snappedToIndex: Int? = nil
        for (index, snapAngle) in snapAngles.enumerated() {
            let snapAngleNormalized = normalizeAngle(snapAngle)
            let angleDiff = abs(normalizedAngle - snapAngleNormalized)
            let wrappedDiff = min(angleDiff, 2 * .pi - angleDiff)
            if wrappedDiff < snapThreshold {
                normalizedAngle = snapAngleNormalized
                snappedToIndex = index
                if !isSnapped || snappedToIndex != index {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isSnapped = true
                }
                break
            }
        }
        
        // Update snap indicators visibility
        for (index, indicator) in snapIndicators.enumerated() {
            indicator.alpha = (snappedToIndex == index) ? 1.0 : 0.0
        }
        if snappedToIndex == nil { isSnapped = false }
        
        // Update piece rotation
        piece.zRotation = normalizedAngle
        
        // Update handle position to match piece rotation
        // Note: In SpriteKit, 0° is right, positive is counter-clockwise visually
        // But zRotation is clockwise, so we negate for visual
        handle.position = CGPoint(
            x: cos(-normalizedAngle) * dialRadius,
            y: sin(-normalizedAngle) * dialRadius
        )
        
        // Visual feedback for handle
        handle.fillColor = isSnapped ? .systemGreen : .systemBlue
        let targetScale: CGFloat = isSnapped ? 1.3 : 1.2
        if handle.xScale != targetScale { handle.run(SKAction.scale(to: targetScale, duration: 0.1)) }
        
        // Update angle label with positive degrees
        var degrees = Int(round(normalizedAngle * 180 / .pi))
        while degrees < 0 { degrees += 360 }
        while degrees >= 360 { degrees -= 360 }
        angleLabel.text = "\(degrees)°"
        
        // Label highlights when snapped
        angleLabel.fontName = "System-Bold"
        angleLabel.fontSize = isSnapped ? 20 : 18
        angleLabel.fontColor = isSnapped ? .systemGreen : .systemBlue
    }
    
    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle
        while normalized > CGFloat.pi {
            normalized -= 2 * CGFloat.pi
        }
        while normalized < -CGFloat.pi {
            normalized += 2 * CGFloat.pi
        }
        return normalized
    }
    
    func restoreOriginalRotation() {
        // Restore the piece to its original rotation and flip state if canceling
        if let piece = targetPiece {
            piece.zRotation = originalRotation
            // Restore original flip state
            if piece.isFlipped != originalFlipState {
                piece.flip()  // This will toggle it back to original state
            }
        }
        
        // Reset handle size
        handle?.run(SKAction.scale(to: 1.0, duration: 0.1))
    }
    
    func finishRotation() {
        // Reset handle size and color when done rotating
        handle?.run(SKAction.scale(to: 1.0, duration: 0.1))
        handle?.fillColor = .systemBlue
        angleLabel?.fontSize = 16
        angleLabel?.fontColor = .systemBlue
        
        // Reset snap state on finish
        for indicator in snapIndicators { indicator.alpha = 0 }
        isSnapped = false
    }
}