//
//  TangramCharacterNode.swift
//  Bemo
//
//  Builds an assembled tangram container node from piece types using game geometry
//

// WHAT: Utility to generate SKShapeNode children centered at origin with piece colors
// ARCHITECTURE: Independent node builder for DevTool; uses TangramGameGeometry and TangramPieceType
// USAGE: Call makeFrom(pieceTypes:) and position the container in scene

import SpriteKit

enum TangramCharacterNode {
    static func makeFrom(pieceTypes: [TangramPieceType]) -> SKNode {
        let container = SKNode()
        container.name = "assembled_tangram"
        // lay out pieces in a simple compact fan; this is only for the lab
        var angle: CGFloat = 0
        let step = (2 * CGFloat.pi) / CGFloat(max(1, pieceTypes.count))
        let radius: CGFloat = 90
        for type in pieceTypes.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let shape = makeShape(for: type)
            shape.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            shape.zRotation = angle
            container.addChild(shape)
            angle += step
        }
        return container
    }

    private static func makeShape(for pieceType: TangramPieceType) -> SKShapeNode {
        let normalized = TangramGameGeometry.normalizedVertices(for: pieceType)
        let scaled = TangramGameGeometry.scaleVertices(normalized, by: TangramGameConstants.visualScale)
        let centroid = TangramGameGeometry.centerOfVertices(scaled)
        let path = CGMutablePath()
        if let first = scaled.first {
            path.move(to: CGPoint(x: first.x - centroid.x, y: first.y - centroid.y))
            for v in scaled.dropFirst() {
                path.addLine(to: CGPoint(x: v.x - centroid.x, y: v.y - centroid.y))
            }
            path.closeSubpath()
        }
        let node = SKShapeNode(path: path)
        node.fillColor = TangramColors.Sprite.uiColor(for: pieceType)
        node.strokeColor = node.fillColor.darker(by: 20)
        node.lineWidth = 2
        node.name = "piece_\(pieceType.rawValue)"
        return node
    }
}


