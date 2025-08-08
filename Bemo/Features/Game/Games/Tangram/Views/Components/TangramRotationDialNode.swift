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
    private var targetPiece: PuzzlePieceNode?
    private var initialRotation: CGFloat = 0
    private var originalRotation: CGFloat = 0
    private var originalFlipState: Bool = false
    
    func showForPiece(_ piece: PuzzlePieceNode) {
        targetPiece = piece
        initialRotation = piece.zRotation
        originalRotation = piece.zRotation  // Store original for cancel
        originalFlipState = piece.isFlipped  // Store original flip state
        
        // Create dial circle
        dial = SKShapeNode(circleOfRadius: 80)
        dial.strokeColor = .systemBlue
        dial.lineWidth = 3
        dial.fillColor = .clear
        dial.alpha = 0.8
        addChild(dial)
        
        // Add angle markers every 45°
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let marker = SKShapeNode(circleOfRadius: 3)
            marker.fillColor = .white
            marker.strokeColor = .systemBlue
            marker.position = CGPoint(
                x: cos(angle) * 80,
                y: sin(angle) * 80
            )
            dial.addChild(marker)
            
            // Add labels at 0°, 90°, 180°, 270°
            if i % 2 == 0 {
                let label = SKLabelNode(text: "\(i * 45)°")
                label.fontSize = 10
                label.fontColor = .systemBlue
                label.position = CGPoint(
                    x: cos(angle) * 95,
                    y: sin(angle) * 95 - 5
                )
                dial.addChild(label)
            }
        }
        
        // Create rotation handle
        handle = SKShapeNode(circleOfRadius: 12)
        handle.fillColor = .systemBlue
        handle.strokeColor = .white
        handle.lineWidth = 2
        handle.position = CGPoint(
            x: cos(initialRotation) * 80,
            y: sin(initialRotation) * 80
        )
        handle.zPosition = 10
        addChild(handle)
        
        // Add current angle display
        angleLabel = SKLabelNode(text: "\(Int(initialRotation * 180 / .pi))°")
        angleLabel.fontSize = 16
        angleLabel.fontColor = .systemBlue
        angleLabel.fontName = "System-Bold"
        angleLabel.position = CGPoint(x: 0, y: -110)
        addChild(angleLabel)
        
        // Add close button (cancel)
        let closeButton = SKShapeNode(circleOfRadius: 15)
        closeButton.fillColor = .systemRed
        closeButton.strokeColor = .white
        closeButton.lineWidth = 2
        closeButton.position = CGPoint(x: 60, y: 60)
        closeButton.name = "closeRotationDial"
        
        let xLabel = SKLabelNode(text: "✕")
        xLabel.fontSize = 16
        xLabel.fontColor = .white
        xLabel.position = CGPoint(x: 0, y: -5)
        xLabel.name = "closeRotationDial"
        closeButton.addChild(xLabel)
        
        addChild(closeButton)
        
        // Add save button (confirm)
        let saveButton = SKShapeNode(circleOfRadius: 15)
        saveButton.fillColor = .systemGreen
        saveButton.strokeColor = .white
        saveButton.lineWidth = 2
        saveButton.position = CGPoint(x: -60, y: 60)
        saveButton.name = "saveRotationDial"
        
        let checkLabel = SKLabelNode(text: "✓")
        checkLabel.fontSize = 16
        checkLabel.fontColor = .white
        checkLabel.position = CGPoint(x: 0, y: -5)
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
        
        // Update piece rotation
        piece.zRotation = angle
        
        // Update handle position
        handle.position = CGPoint(
            x: cos(angle) * 80,
            y: sin(angle) * 80
        )
        
        // Update angle label
        var degrees = Int(angle * 180 / .pi)
        while degrees < 0 { degrees += 360 }
        while degrees >= 360 { degrees -= 360 }
        angleLabel.text = "\(degrees)°"
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
    }
}