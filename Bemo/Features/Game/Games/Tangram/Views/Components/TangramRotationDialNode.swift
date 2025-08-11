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
        
        // Add angle markers every 45°
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let marker = SKShapeNode(circleOfRadius: 2)
            marker.fillColor = .white
            marker.strokeColor = .systemBlue
            marker.position = CGPoint(
                x: cos(angle) * dialRadius,
                y: sin(angle) * dialRadius
            )
            dial.addChild(marker)
            
            // Add labels at 0°, 90°, 180°, 270°
            if i % 2 == 0 {
                let label = SKLabelNode(text: "\(i * 45)°")
                label.fontSize = 8  // Smaller font
                label.fontColor = .systemBlue
                label.position = CGPoint(
                    x: cos(angle) * (dialRadius + 15),
                    y: sin(angle) * (dialRadius + 15) - 3
                )
                dial.addChild(label)
            }
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
        print("DEBUG: Creating flip button check - piece type: \(piece.pieceType?.rawValue ?? "nil")")
        if piece.pieceType == .parallelogram {
            print("DEBUG: Creating flip button for parallelogram")
            let flipButton = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 15)
            flipButton.fillColor = .systemPurple
            flipButton.strokeColor = .white
            flipButton.lineWidth = 2
            flipButton.position = CGPoint(x: 0, y: -140)  // Move down to avoid overlap with angle label
            flipButton.name = "flipPiece"
            flipButton.zPosition = 10  // Ensure it's on top
            
            let flipLabel = SKLabelNode(text: "↔ Flip")
            flipLabel.fontSize = 14
            flipLabel.fontColor = .white
            flipLabel.position = CGPoint(x: 0, y: -5)
            flipLabel.name = "flipPiece"
            flipButton.addChild(flipLabel)
            
            addChild(flipButton)
            print("DEBUG: Flip button added to rotation dial")
        } else {
            print("DEBUG: Not creating flip button - piece type is \(piece.pieceType?.rawValue ?? "nil")")
        }
    }
    
    func updateRotation(to angle: CGFloat) {
        guard let piece = targetPiece else { return }
        
        let dialRadius: CGFloat = 60  // Match the radius used in showForPiece
        
        // Normalize angle to [-π, π] range for consistent behavior
        let normalizedAngle = normalizeAngle(angle)
        
        // Update piece rotation
        piece.zRotation = normalizedAngle
        
        // Update handle position to match piece rotation
        // Note: In SpriteKit, 0° is right, positive is counter-clockwise visually
        // But zRotation is clockwise, so we negate for visual
        handle.position = CGPoint(
            x: cos(-normalizedAngle) * dialRadius,
            y: sin(-normalizedAngle) * dialRadius
        )
        
        // Add visual feedback - make handle bigger when dragging
        if handle.xScale != 1.2 {
            handle.run(SKAction.scale(to: 1.2, duration: 0.1))
        }
        
        // Update angle label with positive degrees
        var degrees = Int(round(normalizedAngle * 180 / .pi))
        while degrees < 0 { degrees += 360 }
        while degrees >= 360 { degrees -= 360 }
        angleLabel.text = "\(degrees)°"
        
        // Make label bold during rotation
        angleLabel.fontName = "System-Bold"
        angleLabel.fontSize = 18
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
            print("\n=== RESTORING ORIGINAL STATE for \(piece.pieceType?.rawValue ?? "unknown") ===")
            print("Restoring rotation to: \(String(format: "%.2f", originalRotation)) rad = \(String(format: "%.1f", originalRotation * 180 / .pi))°")
            print("Restoring flip state to: \(originalFlipState)")
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
        // Reset handle size when done rotating
        handle?.run(SKAction.scale(to: 1.0, duration: 0.1))
        angleLabel?.fontSize = 16
    }
}