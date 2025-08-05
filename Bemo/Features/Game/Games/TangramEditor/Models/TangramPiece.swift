//
//  TangramPiece.swift
//  Bemo
//
//  Individual tangram piece with transform and connections
//

import Foundation
import CoreGraphics

struct TangramPiece: Codable, Identifiable {
    let id: String
    let type: TangramPieceGeometry.PieceType
    var currentTransform: CGAffineTransform
    var connectionIds: [String]
    var isLocked: Bool
    var zIndex: Int
    
    init(type: TangramPieceGeometry.PieceType, transform: CGAffineTransform = .identity) {
        self.id = UUID().uuidString
        self.type = type
        self.currentTransform = transform
        self.connectionIds = []
        self.isLocked = false
        self.zIndex = 0
    }
    
    var vertices: [CGPoint] {
        let baseVertices = TangramPieceGeometry.vertices(for: type)
        return GeometryEngine.transformVertices(baseVertices, with: currentTransform)
    }
    
    var edges: [TangramPieceGeometry.Edge] {
        return TangramPieceGeometry.edges(for: type)
    }
    
    var area: Double {
        return TangramPieceGeometry.area(for: type)
    }
    
    var centroid: CGPoint {
        let baseCentroid = TangramPieceGeometry.centroid(for: type)
        return baseCentroid.applying(currentTransform)
    }
    
    var boundingBox: CGRect {
        let transformedVertices = vertices
        guard !transformedVertices.isEmpty else { return .zero }
        
        var minX = transformedVertices[0].x
        var maxX = transformedVertices[0].x
        var minY = transformedVertices[0].y
        var maxY = transformedVertices[0].y
        
        for vertex in transformedVertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    mutating func applyTransform(_ transform: CGAffineTransform) {
        currentTransform = currentTransform.concatenating(transform)
    }
    
    mutating func setTransform(_ transform: CGAffineTransform) {
        currentTransform = transform
    }
    
    mutating func addConnection(_ connectionId: String) {
        if !connectionIds.contains(connectionId) {
            connectionIds.append(connectionId)
        }
    }
    
    mutating func removeConnection(_ connectionId: String) {
        connectionIds.removeAll { $0 == connectionId }
    }
    
    func contains(point: CGPoint) -> Bool {
        return GeometryEngine.polygonContainsPoint(point, vertices: vertices)
    }
    
    func vertex(at index: Int) -> CGPoint? {
        let verts = vertices
        guard index >= 0 && index < verts.count else { return nil }
        return verts[index]
    }
    
    func edge(at index: Int) -> (start: CGPoint, end: CGPoint)? {
        let verts = vertices
        let edgeInfo = edges
        guard index >= 0 && index < edgeInfo.count else { return nil }
        
        let edge = edgeInfo[index]
        return (verts[edge.startVertex], verts[edge.endVertex])
    }
    
    func nearestVertex(to point: CGPoint) -> (index: Int, vertex: CGPoint, distance: Double)? {
        let verts = vertices
        guard !verts.isEmpty else { return nil }
        
        var nearestIndex = 0
        var nearestVertex = verts[0]
        var minDistance = GeometryEngine.distance(from: point, to: verts[0])
        
        for (index, vertex) in verts.enumerated() {
            let distance = GeometryEngine.distance(from: point, to: vertex)
            if distance < minDistance {
                nearestIndex = index
                nearestVertex = vertex
                minDistance = distance
            }
        }
        
        return (nearestIndex, nearestVertex, minDistance)
    }
    
    func nearestEdge(to point: CGPoint) -> (index: Int, distance: Double)? {
        let verts = vertices
        let edgeInfo = edges
        guard !edgeInfo.isEmpty else { return nil }
        
        var nearestIndex = 0
        var minDistance = Double.infinity
        
        for (index, edge) in edgeInfo.enumerated() {
            let start = verts[edge.startVertex]
            let end = verts[edge.endVertex]
            let distance = GeometryEngine.distanceFromPointToLine(point, lineStart: start, lineEnd: end)
            
            if distance < minDistance {
                nearestIndex = index
                minDistance = distance
            }
        }
        
        return (nearestIndex, minDistance)
    }
    
    func overlaps(with other: TangramPiece) -> Bool {
        return GeometryEngine.polygonsOverlap(vertices, other.vertices)
    }
}

extension TangramPiece {
    enum InteractionMode {
        case none
        case moving
        case rotating(center: CGPoint)
        case connecting(type: ConnectionPointType)
    }
    
    enum ConnectionPointType {
        case vertex(index: Int)
        case edge(index: Int)
    }
}

extension TangramPiece {
    func rotationAngle() -> Double {
        return GeometryEngine.extractRotation(from: currentTransform)
    }
    
    func position() -> CGPoint {
        return GeometryEngine.extractTranslation(from: currentTransform)
    }
    
    mutating func rotate(by angle: Double, around center: CGPoint) {
        let rotation = GeometryEngine.rotationMatrix(angle: angle)
        let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
        let fromOrigin = CGAffineTransform(translationX: center.x, y: center.y)
        
        let combinedTransform = toOrigin
            .concatenating(rotation)
            .concatenating(fromOrigin)
        
        applyTransform(combinedTransform)
    }
    
    mutating func translate(by offset: CGVector) {
        let translation = CGAffineTransform(translationX: offset.dx, y: offset.dy)
        applyTransform(translation)
    }
}

extension TangramPieceGeometry.PieceType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "smallTriangle1": self = .smallTriangle1
        case "smallTriangle2": self = .smallTriangle2
        case "square": self = .square
        case "mediumTriangle": self = .mediumTriangle
        case "largeTriangle1": self = .largeTriangle1
        case "largeTriangle2": self = .largeTriangle2
        case "parallelogram": self = .parallelogram
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown piece type: \(rawValue)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let rawValue: String
        switch self {
        case .smallTriangle1: rawValue = "smallTriangle1"
        case .smallTriangle2: rawValue = "smallTriangle2"
        case .square: rawValue = "square"
        case .mediumTriangle: rawValue = "mediumTriangle"
        case .largeTriangle1: rawValue = "largeTriangle1"
        case .largeTriangle2: rawValue = "largeTriangle2"
        case .parallelogram: rawValue = "parallelogram"
        }
        
        try container.encode(rawValue)
    }
}