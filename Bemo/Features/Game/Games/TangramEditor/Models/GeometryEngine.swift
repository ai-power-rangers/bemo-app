//
//  GeometryEngine.swift
//  Bemo
//
//  Precise geometric calculations and transformations for tangram pieces
//

import Foundation
import CoreGraphics

struct GeometryEngine {
    
    private static let tolerance: Double = 0.0001
    
    static func transformVertices(_ vertices: [CGPoint], with transform: CGAffineTransform) -> [CGPoint] {
        return vertices.map { vertex in
            vertex.applying(transform)
        }
    }
    
    static func distance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        return sqrt(dx * dx + dy * dy)
    }
    
    static func angle(from p1: CGPoint, vertex: CGPoint, to p2: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)
        
        let dot = Double(v1.dx * v2.dx + v1.dy * v2.dy)
        let det = Double(v1.dx * v2.dy - v1.dy * v2.dx)
        
        let angle = atan2(det, dot)
        return angle * 180.0 / .pi
    }
    
    static func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360.0)
        if normalized < 0 {
            normalized += 360.0
        }
        return normalized
    }
    
    static func anglesEqual(_ angle1: Double, _ angle2: Double, tolerance: Double = 1.0) -> Bool {
        let diff = abs(normalizeAngle(angle1) - normalizeAngle(angle2))
        return diff <= tolerance || diff >= (360.0 - tolerance)
    }
    
    static func pointsEqual(_ p1: CGPoint, _ p2: CGPoint, tolerance: Double = tolerance) -> Bool {
        return distance(from: p1, to: p2) < tolerance
    }
    
    static func pointOnLineSegment(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> Bool {
        let epsilon: CGFloat = 1e-9
        
        // Check if point is collinear with the line segment
        let crossProduct = (point.y - start.y) * (end.x - start.x) - (point.x - start.x) * (end.y - start.y)
        if abs(crossProduct) > epsilon {
            return false // Not collinear
        }
        
        // Check if point is within the segment bounds
        let dotProduct = (point.x - start.x) * (end.x - start.x) + (point.y - start.y) * (end.y - start.y)
        let squaredLength = (end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)
        
        if dotProduct < -epsilon || dotProduct > squaredLength + epsilon {
            return false
        }
        
        return true
    }
    
    static func edgesEqual(_ edge1Length: Double, _ edge2Length: Double, tolerance: Double = tolerance) -> Bool {
        return abs(edge1Length - edge2Length) < tolerance
    }
    
    static func lineSegmentIntersection(
        _ p1: CGPoint, _ p2: CGPoint,
        _ p3: CGPoint, _ p4: CGPoint
    ) -> CGPoint? {
        let x1 = Double(p1.x), y1 = Double(p1.y)
        let x2 = Double(p2.x), y2 = Double(p2.y)
        let x3 = Double(p3.x), y3 = Double(p3.y)
        let x4 = Double(p4.x), y4 = Double(p4.y)
        
        let denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        
        if abs(denom) < tolerance {
            return nil
        }
        
        let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        let u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        
        if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
            let x = x1 + t * (x2 - x1)
            let y = y1 + t * (y2 - y1)
            return CGPoint(x: x, y: y)
        }
        
        return nil
    }
    
    static func polygonContainsPoint(_ point: CGPoint, vertices: [CGPoint]) -> Bool {
        guard vertices.count >= 3 else { return false }
        
        // First check if the point is exactly on a vertex (boundary point)
        let epsilon = 1e-9
        for vertex in vertices {
            if pointsEqual(point, vertex, tolerance: epsilon) {
                return false // Points on vertices are not "inside"
            }
        }
        
        // Check if point is on any edge
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            if pointOnLineSegment(point, vertices[i], vertices[j]) {
                return false // Points on edges are not "inside"
            }
        }
        
        // Ray casting algorithm for interior points
        var inside = false
        let x = Double(point.x)
        let y = Double(point.y)
        
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let xi = Double(vertices[i].x)
            let yi = Double(vertices[i].y)
            let xj = Double(vertices[j].x)
            let yj = Double(vertices[j].y)
            
            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            
            if intersect {
                inside = !inside
            }
        }
        
        return inside
    }
    
    static func polygonArea(_ vertices: [CGPoint]) -> Double {
        guard vertices.count >= 3 else { return 0 }
        
        var area: Double = 0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            area += Double(vertices[i].x * vertices[j].y)
            area -= Double(vertices[j].x * vertices[i].y)
        }
        
        return abs(area) / 2.0
    }
    
    static func polygonsOverlap(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Bool {
        // For convex polygons (all tangram pieces), we can use a simpler approach:
        // 1. Check if any vertex of polygon1 is inside polygon2
        // 2. Check if any vertex of polygon2 is inside polygon1
        // 3. Check if any edges intersect
        // This is more reliable than the complex clipping algorithm
        
        // Check if any vertex of polygon1 is inside polygon2
        for vertex in vertices1 {
            if polygonContainsPoint(vertex, vertices: vertices2) {
                return true
            }
        }
        
        // Check if any vertex of polygon2 is inside polygon1
        for vertex in vertices2 {
            if polygonContainsPoint(vertex, vertices: vertices1) {
                return true
            }
        }
        
        // Check if any edges intersect
        for i in 0..<vertices1.count {
            let edge1Start = vertices1[i]
            let edge1End = vertices1[(i + 1) % vertices1.count]
            
            for j in 0..<vertices2.count {
                let edge2Start = vertices2[j]
                let edge2End = vertices2[(j + 1) % vertices2.count]
                
                if lineSegmentIntersection(edge1Start, edge1End, edge2Start, edge2End) != nil {
                    // Check if it's a real intersection (not just touching at endpoints)
                    // We only care about interior intersection for area overlap
                    if let intersection = lineSegmentIntersection(edge1Start, edge1End, edge2Start, edge2End) {
                        // Check if intersection is not at an endpoint (which would be edge touching)
                        let epsilon = 1e-6
                        let isEndpoint = pointsEqual(intersection, edge1Start, tolerance: epsilon) ||
                                       pointsEqual(intersection, edge1End, tolerance: epsilon) ||
                                       pointsEqual(intersection, edge2Start, tolerance: epsilon) ||
                                       pointsEqual(intersection, edge2End, tolerance: epsilon)
                        
                        if !isEndpoint {
                            return true // Interior edge intersection means area overlap
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    private static func calculateIntersectionArea(_ subject: [CGPoint], _ clip: [CGPoint]) -> Double {
        // Sutherland-Hodgman polygon clipping algorithm
        var outputList = subject
        
        for i in 0..<clip.count {
            if outputList.isEmpty { break }
            
            let clipVertex1 = clip[i]
            let clipVertex2 = clip[(i + 1) % clip.count]
            
            let inputList = outputList
            outputList = []
            
            if !inputList.isEmpty {
                var s = inputList.last!
                
                for e in inputList {
                    if isInside(e, clipVertex1: clipVertex1, clipVertex2: clipVertex2) {
                        if !isInside(s, clipVertex1: clipVertex1, clipVertex2: clipVertex2) {
                            // Entering the clipping region
                            if let intersection = lineSegmentIntersection(s, e, clipVertex1, clipVertex2) {
                                outputList.append(intersection)
                            }
                        }
                        outputList.append(e)
                    } else if isInside(s, clipVertex1: clipVertex1, clipVertex2: clipVertex2) {
                        // Leaving the clipping region
                        if let intersection = lineSegmentIntersection(s, e, clipVertex1, clipVertex2) {
                            outputList.append(intersection)
                        }
                    }
                    s = e
                }
            }
        }
        
        // Calculate area of the resulting polygon
        guard outputList.count >= 3 else { return 0.0 }
        return abs(polygonArea(outputList))
    }
    
    private static func isInside(_ point: CGPoint, clipVertex1: CGPoint, clipVertex2: CGPoint) -> Bool {
        // Check if point is on the inside (left) side of the directed line from clipVertex1 to clipVertex2
        return (clipVertex2.x - clipVertex1.x) * (point.y - clipVertex1.y) - (clipVertex2.y - clipVertex1.y) * (point.x - clipVertex1.x) >= 0
    }
    
    static func boundingBoxesOverlap(_ box1: CGRect, _ box2: CGRect) -> Bool {
        return box1.intersects(box2)
    }
    
    // MARK: - Geometric Analysis Helpers for Semantic Validation
    
    /// Find vertices that are shared between two polygons (within tolerance)
    static func sharedVertices(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Set<CGPoint> {
        var shared = Set<CGPoint>()
        let tolerance: CGFloat = 1e-6
        
        for v1 in vertices1 {
            for v2 in vertices2 {
                if pointsEqual(v1, v2, tolerance: tolerance) {
                    shared.insert(v1)
                    break
                }
            }
        }
        
        return shared
    }
    
    /// Find edges that are shared between two polygons
    static func sharedEdges(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Set<String> {
        var shared = Set<String>()
        let tolerance: CGFloat = 1e-6
        
        // Get edges for both polygons
        let edges1 = getEdges(from: vertices1)
        let edges2 = getEdges(from: vertices2)
        
        for edge1 in edges1 {
            for edge2 in edges2 {
                if edgesCoincide(edge1, edge2, tolerance: tolerance) {
                    // Use a string representation for the edge to store in Set
                    let edgeKey = "\(edge1.0.x),\(edge1.0.y)-\(edge1.1.x),\(edge1.1.y)"
                    shared.insert(edgeKey)
                    break
                }
            }
        }
        
        return shared
    }
    
    /// Check if two edges coincide (within tolerance)
    static func edgesCoincide(_ edgeA: (CGPoint, CGPoint), _ edgeB: (CGPoint, CGPoint), tolerance: CGFloat = 1e-6) -> Bool {
        // Check if edges are the same (forward or backward)
        let sameDirection = pointsEqual(edgeA.0, edgeB.0, tolerance: tolerance) && 
                           pointsEqual(edgeA.1, edgeB.1, tolerance: tolerance)
        let reverseDirection = pointsEqual(edgeA.0, edgeB.1, tolerance: tolerance) && 
                              pointsEqual(edgeA.1, edgeB.0, tolerance: tolerance)
        
        return sameDirection || reverseDirection
    }
    
    /// Check if a shorter edge lies along a longer edge (partial coincidence)
    static func edgePartiallyCoincides(shorterEdge: (CGPoint, CGPoint), longerEdge: (CGPoint, CGPoint), tolerance: CGFloat = 1e-6) -> Bool {
        // Check if both endpoints of the shorter edge lie on the line defined by the longer edge
        let distStart = distanceFromPointToLine(shorterEdge.0, lineStart: longerEdge.0, lineEnd: longerEdge.1)
        let distEnd = distanceFromPointToLine(shorterEdge.1, lineStart: longerEdge.0, lineEnd: longerEdge.1)
        
        if distStart > tolerance || distEnd > tolerance {
            return false // Edges are not collinear
        }
        
        // Check if the shorter edge is within the bounds of the longer edge
        // Project both endpoints onto the longer edge and check if they're within [0, 1] range
        let longerVector = edgeVector(from: longerEdge.0, to: longerEdge.1)
        let longerLength = sqrt(Double(longerVector.dx * longerVector.dx + longerVector.dy * longerVector.dy))
        
        if longerLength < tolerance {
            return false // Degenerate edge
        }
        
        // Project shorter edge endpoints onto longer edge
        let v1 = edgeVector(from: longerEdge.0, to: shorterEdge.0)
        let v2 = edgeVector(from: longerEdge.0, to: shorterEdge.1)
        
        let proj1 = dotProduct(v1, longerVector) / (longerLength * longerLength)
        let proj2 = dotProduct(v2, longerVector) / (longerLength * longerLength)
        
        // Check if both projections are within [0, 1] (with tolerance)
        let minProj = min(proj1, proj2)
        let maxProj = max(proj1, proj2)
        
        return minProj >= -tolerance && maxProj <= 1.0 + tolerance
    }
    
    /// Get all edges from a polygon
    private static func getEdges(from vertices: [CGPoint]) -> [(CGPoint, CGPoint)] {
        var edges: [(CGPoint, CGPoint)] = []
        
        for i in 0..<vertices.count {
            let start = vertices[i]
            let end = vertices[(i + 1) % vertices.count]
            edges.append((start, end))
        }
        
        return edges
    }
    
    static func rotationMatrix(angle: Double) -> CGAffineTransform {
        let radians = angle * .pi / 180.0
        return CGAffineTransform(rotationAngle: CGFloat(radians))
    }
    
    static func translationMatrix(dx: Double, dy: Double) -> CGAffineTransform {
        return CGAffineTransform(translationX: CGFloat(dx), y: CGFloat(dy))
    }
    
    static func scaleMatrix(sx: Double, sy: Double) -> CGAffineTransform {
        return CGAffineTransform(scaleX: CGFloat(sx), y: CGFloat(sy))
    }
    
    static func combineTransforms(_ transforms: [CGAffineTransform]) -> CGAffineTransform {
        return transforms.reduce(CGAffineTransform.identity) { result, transform in
            result.concatenating(transform)
        }
    }
    
    static func extractRotation(from transform: CGAffineTransform) -> Double {
        let angle = atan2(Double(transform.b), Double(transform.a))
        return angle * 180.0 / .pi
    }
    
    static func extractTranslation(from transform: CGAffineTransform) -> CGPoint {
        return CGPoint(x: transform.tx, y: transform.ty)
    }
    
    static func projectPointOntoLine(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGPoint {
        let lineVec = CGVector(dx: lineEnd.x - lineStart.x, dy: lineEnd.y - lineStart.y)
        let pointVec = CGVector(dx: point.x - lineStart.x, dy: point.y - lineStart.y)
        
        let lineLengthSquared = Double(lineVec.dx * lineVec.dx + lineVec.dy * lineVec.dy)
        
        if lineLengthSquared < tolerance {
            return lineStart
        }
        
        let dot = Double(pointVec.dx * lineVec.dx + pointVec.dy * lineVec.dy)
        let t = max(0.0, min(1.0, dot / lineLengthSquared))
        
        return CGPoint(
            x: lineStart.x + CGFloat(t) * lineVec.dx,
            y: lineStart.y + CGFloat(t) * lineVec.dy
        )
    }
    
    static func distanceFromPointToLine(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let projection = projectPointOntoLine(point, lineStart: lineStart, lineEnd: lineEnd)
        return distance(from: point, to: projection)
    }
    
    static func edgeVector(from start: CGPoint, to end: CGPoint) -> CGVector {
        return CGVector(dx: end.x - start.x, dy: end.y - start.y)
    }
    
    static func normalizeVector(_ vector: CGVector) -> CGVector {
        let length = sqrt(Double(vector.dx * vector.dx + vector.dy * vector.dy))
        
        if length < tolerance {
            return CGVector(dx: 0, dy: 0)
        }
        
        return CGVector(dx: vector.dx / CGFloat(length), dy: vector.dy / CGFloat(length))
    }
    
    static func dotProduct(_ v1: CGVector, _ v2: CGVector) -> Double {
        return Double(v1.dx * v2.dx + v1.dy * v2.dy)
    }
    
    static func crossProduct2D(_ v1: CGVector, _ v2: CGVector) -> Double {
        return Double(v1.dx * v2.dy - v1.dy * v2.dx)
    }
}

extension GeometryEngine {
    static func alignTransform(
        from sourcePoint: CGPoint,
        sourceAngle: Double,
        to targetPoint: CGPoint,
        targetAngle: Double
    ) -> CGAffineTransform {
        let rotationDiff = targetAngle - sourceAngle
        let rotation = rotationMatrix(angle: rotationDiff)
        
        let rotatedSource = sourcePoint.applying(rotation)
        let translation = translationMatrix(
            dx: Double(targetPoint.x - rotatedSource.x),
            dy: Double(targetPoint.y - rotatedSource.y)
        )
        
        return combineTransforms([rotation, translation])
    }
    
    static func vertexMatchTransform(
        pieceVertices: [CGPoint],
        vertexIndex: Int,
        targetPoint: CGPoint
    ) -> CGAffineTransform {
        guard vertexIndex < pieceVertices.count else { return .identity }
        
        let vertex = pieceVertices[vertexIndex]
        let dx = Double(targetPoint.x - vertex.x)
        let dy = Double(targetPoint.y - vertex.y)
        
        return translationMatrix(dx: dx, dy: dy)
    }
    
    static func edgeAlignTransform(
        pieceVertices: [CGPoint],
        edgeStartIndex: Int,
        targetEdgeStart: CGPoint,
        targetEdgeEnd: CGPoint
    ) -> CGAffineTransform {
        guard edgeStartIndex < pieceVertices.count else { return .identity }
        
        let edgeEndIndex = (edgeStartIndex + 1) % pieceVertices.count
        let pieceEdgeStart = pieceVertices[edgeStartIndex]
        let pieceEdgeEnd = pieceVertices[edgeEndIndex]
        
        let pieceVector = edgeVector(from: pieceEdgeStart, to: pieceEdgeEnd)
        let targetVector = edgeVector(from: targetEdgeStart, to: targetEdgeEnd)
        
        let pieceAngle = atan2(Double(pieceVector.dy), Double(pieceVector.dx))
        let targetAngle = atan2(Double(targetVector.dy), Double(targetVector.dx))
        let rotationAngle = (targetAngle - pieceAngle) * 180.0 / .pi
        
        let rotation = rotationMatrix(angle: rotationAngle)
        let rotatedStart = pieceEdgeStart.applying(rotation)
        
        let translation = translationMatrix(
            dx: Double(targetEdgeStart.x - rotatedStart.x),
            dy: Double(targetEdgeStart.y - rotatedStart.y)
        )
        
        return combineTransforms([rotation, translation])
    }
}