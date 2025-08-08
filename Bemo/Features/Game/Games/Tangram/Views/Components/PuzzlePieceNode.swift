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
    private var shapeNode: SKShapeNode?
    
    init(pieceType: TangramPieceType) {
        super.init()
        
        self.pieceType = pieceType
        self.name = "piece_\(pieceType.rawValue)"
        
        // Create shape node with proper geometry
        let shapeNode = createShape(for: pieceType)
        self.shapeNode = shapeNode
        addChild(shapeNode)
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
        print("DEBUG flip() called on piece: \(pieceType?.rawValue ?? "unknown")")
        print("  Before: isFlipped = \(isFlipped), xScale = \(xScale)")
        
        // Flip the piece horizontally
        isFlipped = !isFlipped
        
        // Recreate the shape with flipped geometry
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
        
        // Create path from vertices
        let path = UIBezierPath()
        if let firstVertex = finalVertices.first {
            path.move(to: firstVertex)
            for vertex in finalVertices.dropFirst() {
                path.addLine(to: vertex)
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
        
        print("  After: isFlipped = \(isFlipped), shape recreated with flipped geometry")
    }
}