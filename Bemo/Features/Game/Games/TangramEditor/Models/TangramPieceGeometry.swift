//
//  TangramPieceGeometry.swift
//  Bemo
//
//  Mathematical definitions for all 7 tangram pieces with precise geometry
//

import Foundation
import CoreGraphics

struct TangramPieceGeometry {
    enum PieceType: CaseIterable {
        case smallTriangle1
        case smallTriangle2
        case square
        case mediumTriangle
        case largeTriangle1
        case largeTriangle2
        case parallelogram
        
        var displayName: String {
            switch self {
            case .smallTriangle1, .smallTriangle2:
                return "Small Triangle"
            case .square:
                return "Square"
            case .mediumTriangle:
                return "Medium Triangle"
            case .largeTriangle1, .largeTriangle2:
                return "Large Triangle"
            case .parallelogram:
                return "Parallelogram"
            }
        }
    }
    
    struct Edge: Equatable {
        let startVertex: Int
        let endVertex: Int
        let length: Double
        
        func isEqual(to other: Edge, tolerance: Double = 0.0001) -> Bool {
            return abs(length - other.length) < tolerance
        }
    }
    
    static func vertices(for pieceType: PieceType) -> [CGPoint] {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 0, y: 1)
            ]
            
        case .square:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: 1)
            ]
            
        case .mediumTriangle:
            let sqrt2 = sqrt(2.0)
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: sqrt2, y: 0),
                CGPoint(x: 0, y: sqrt2)
            ]
            
        case .largeTriangle1, .largeTriangle2:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 2, y: 0),
                CGPoint(x: 0, y: 2)
            ]
            
        case .parallelogram:
            let sqrt2 = sqrt(2.0)
            let halfSqrt2 = sqrt2 / 2.0
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: sqrt2, y: 0),
                CGPoint(x: halfSqrt2, y: halfSqrt2),
                CGPoint(x: -halfSqrt2, y: halfSqrt2)
            ]
        }
    }
    
    static func edges(for pieceType: PieceType) -> [Edge] {
        let verts = vertices(for: pieceType)
        var edges: [Edge] = []
        
        for i in 0..<verts.count {
            let startIdx = i
            let endIdx = (i + 1) % verts.count
            let start = verts[startIdx]
            let end = verts[endIdx]
            let length = distance(from: start, to: end)
            
            edges.append(Edge(startVertex: startIdx, endVertex: endIdx, length: length))
        }
        
        return edges
    }
    
    static func area(for pieceType: PieceType) -> Double {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2:
            return 0.5
        case .square:
            return 1.0
        case .mediumTriangle:
            return 1.0
        case .largeTriangle1, .largeTriangle2:
            return 2.0
        case .parallelogram:
            return 1.0
        }
    }
    
    static func angles(for pieceType: PieceType) -> [Double] {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2:
            return [90.0, 45.0, 45.0]
        case .square:
            return [90.0, 90.0, 90.0, 90.0]
        case .parallelogram:
            return [45.0, 135.0, 45.0, 135.0]
        }
    }
    
    static func centroid(for pieceType: PieceType) -> CGPoint {
        let verts = vertices(for: pieceType)
        var sumX: Double = 0
        var sumY: Double = 0
        
        for vertex in verts {
            sumX += Double(vertex.x)
            sumY += Double(vertex.y)
        }
        
        return CGPoint(x: sumX / Double(verts.count), y: sumY / Double(verts.count))
    }
    
    static func boundingBox(for pieceType: PieceType) -> CGRect {
        let verts = vertices(for: pieceType)
        guard !verts.isEmpty else { return .zero }
        
        var minX = Double(verts[0].x)
        var maxX = Double(verts[0].x)
        var minY = Double(verts[0].y)
        var maxY = Double(verts[0].y)
        
        for vertex in verts {
            minX = min(minX, Double(vertex.x))
            maxX = max(maxX, Double(vertex.x))
            minY = min(minY, Double(vertex.y))
            maxY = max(maxY, Double(vertex.y))
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    static func edgeLengths(for pieceType: PieceType) -> [Double] {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2:
            let sqrt2 = sqrt(2.0)
            return [1.0, 1.0, sqrt2]
        case .square:
            return [1.0, 1.0, 1.0, 1.0]
        case .mediumTriangle:
            let sqrt2 = sqrt(2.0)
            return [sqrt2, sqrt2, 2.0]
        case .largeTriangle1, .largeTriangle2:
            let twoSqrt2 = 2.0 * sqrt(2.0)
            return [2.0, 2.0, twoSqrt2]
        case .parallelogram:
            let sqrt2 = sqrt(2.0)
            return [sqrt2, 1.0, sqrt2, 1.0]
        }
    }
    
    static func vertexAngles(for pieceType: PieceType) -> [Double] {
        switch pieceType {
        case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2:
            return [90.0, 45.0, 45.0]
        case .square:
            return [90.0, 90.0, 90.0, 90.0]
        case .parallelogram:
            return [45.0, 135.0, 45.0, 135.0]
        }
    }
    
    private static func distance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        return sqrt(dx * dx + dy * dy)
    }
}

extension TangramPieceGeometry {
    static func verifyTotalArea() -> Bool {
        var totalArea: Double = 0
        let pieceCounts: [PieceType: Int] = [
            .smallTriangle1: 1,
            .smallTriangle2: 1,
            .square: 1,
            .mediumTriangle: 1,
            .largeTriangle1: 1,
            .largeTriangle2: 1,
            .parallelogram: 1
        ]
        
        for (pieceType, count) in pieceCounts {
            totalArea += area(for: pieceType) * Double(count)
        }
        
        return abs(totalArea - 8.0) < 0.0001
    }
    
    static func uniquePieceTypes() -> [PieceType] {
        return [.smallTriangle1, .square, .mediumTriangle, .largeTriangle1, .parallelogram]
    }
}