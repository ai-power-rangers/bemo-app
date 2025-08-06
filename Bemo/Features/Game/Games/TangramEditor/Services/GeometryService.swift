//
//  GeometryService.swift
//  Bemo
//
//  Service for precise geometric calculations and transformations for tangram pieces
//

import Foundation
import CoreGraphics

class GeometryService {
    
    // Static constants for default parameters
    static let defaultTolerance: Double = TangramConstants.fineTolerance
    
    private let tolerance: Double = GeometryService.defaultTolerance
    
    func transformVertices(_ vertices: [CGPoint], with transform: CGAffineTransform) -> [CGPoint] {
        return vertices.map { vertex in
            vertex.applying(transform)
        }
    }
    
    func distance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        return sqrt(dx * dx + dy * dy)
    }
    
    func angle(from p1: CGPoint, vertex: CGPoint, to p2: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)
        
        let dot = Double(v1.dx * v2.dx + v1.dy * v2.dy)
        let det = Double(v1.dx * v2.dy - v1.dy * v2.dx)
        
        let angle = atan2(det, dot)
        return angle * 180.0 / .pi
    }
    
    func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360.0)
        if normalized < 0 {
            normalized += 360.0
        }
        return normalized
    }
    
    func anglesEqual(_ angle1: Double, _ angle2: Double, tolerance: Double = 1.0) -> Bool {
        let diff = abs(normalizeAngle(angle1) - normalizeAngle(angle2))
        return diff <= tolerance || diff >= (360.0 - tolerance)
    }
    
    func pointsEqual(_ p1: CGPoint, _ p2: CGPoint, tolerance: Double? = nil) -> Bool {
        let tol = tolerance ?? self.tolerance
        return distance(from: p1, to: p2) < tol
    }
    
    func pointOnLineSegment(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> Bool {
        let epsilon = TangramConstants.ultraFineTolerance
        
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
    
    func edgesEqual(_ edge1Length: Double, _ edge2Length: Double, tolerance: Double? = nil) -> Bool {
        let tol = tolerance ?? self.tolerance
        return abs(edge1Length - edge2Length) < tol
    }
    
    func lineSegmentIntersection(
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
    
    func polygonContainsPoint(_ point: CGPoint, vertices: [CGPoint]) -> Bool {
        guard vertices.count >= 3 else { return false }
        
        // First check if the point is exactly on a vertex (boundary point)
        let epsilon = TangramConstants.ultraFineTolerance
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
    
    func polygonArea(_ vertices: [CGPoint]) -> Double {
        guard vertices.count >= 3 else { return 0 }
        
        var area: Double = 0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            area += Double(vertices[i].x * vertices[j].y)
            area -= Double(vertices[j].x * vertices[i].y)
        }
        
        return abs(area) / 2.0
    }
    
    func polygonsOverlap(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Bool {
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
                        let epsilon = TangramConstants.edgeCoincidenceTolerance
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
    
    private func calculateIntersectionArea(_ subject: [CGPoint], _ clip: [CGPoint]) -> Double {
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
    
    private func isInside(_ point: CGPoint, clipVertex1: CGPoint, clipVertex2: CGPoint) -> Bool {
        // Check if point is on the inside (left) side of the directed line from clipVertex1 to clipVertex2
        return (clipVertex2.x - clipVertex1.x) * (point.y - clipVertex1.y) - (clipVertex2.y - clipVertex1.y) * (point.x - clipVertex1.x) >= 0
    }
    
    func boundingBox(for vertices: [CGPoint]) -> CGRect {
        guard !vertices.isEmpty else { return .zero }
        
        var minX = vertices[0].x
        var maxX = vertices[0].x
        var minY = vertices[0].y
        var maxY = vertices[0].y
        
        for vertex in vertices.dropFirst() {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func boundingBoxesOverlap(_ box1: CGRect, _ box2: CGRect) -> Bool {
        return box1.intersects(box2)
    }
    
    // MARK: - Geometric Analysis Helpers for Semantic Validation
    
    /// Find vertices that are shared between two polygons (within tolerance)
    func sharedVertices(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Set<CGPoint> {
        var shared = Set<CGPoint>()
        // Use a more generous tolerance for vertex matching to handle floating point precision
        let tolerance = TangramConstants.geometricTolerance  // Consistent tolerance
        
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
    func sharedEdges(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Set<String> {
        var shared = Set<String>()
        // Use consistent tolerance with vertex matching
        let tolerance = TangramConstants.geometricTolerance  // Consistent tolerance
        
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
    
    /// Get all edges from a polygon
    private func getEdges(from vertices: [CGPoint]) -> [(CGPoint, CGPoint)] {
        var edges: [(CGPoint, CGPoint)] = []
        
        for i in 0..<vertices.count {
            let start = vertices[i]
            let end = vertices[(i + 1) % vertices.count]
            edges.append((start, end))
        }
        
        return edges
    }
    
    func rotationMatrix(angle: Double) -> CGAffineTransform {
        let radians = angle * .pi / 180.0
        return CGAffineTransform(rotationAngle: CGFloat(radians))
    }
    
    func translationMatrix(dx: Double, dy: Double) -> CGAffineTransform {
        return CGAffineTransform(translationX: CGFloat(dx), y: CGFloat(dy))
    }
    
    func scaleMatrix(sx: Double, sy: Double) -> CGAffineTransform {
        return CGAffineTransform(scaleX: CGFloat(sx), y: CGFloat(sy))
    }
    
    func combineTransforms(_ transforms: [CGAffineTransform]) -> CGAffineTransform {
        return transforms.reduce(CGAffineTransform.identity) { result, transform in
            result.concatenating(transform)
        }
    }
    
    func extractRotation(from transform: CGAffineTransform) -> Double {
        let angle = atan2(Double(transform.b), Double(transform.a))
        return angle * 180.0 / .pi
    }
    
    func extractTranslation(from transform: CGAffineTransform) -> CGPoint {
        return CGPoint(x: transform.tx, y: transform.ty)
    }
    
    func projectPointOntoLine(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGPoint {
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
    
    func distanceFromPointToLine(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let projection = projectPointOntoLine(point, lineStart: lineStart, lineEnd: lineEnd)
        return distance(from: point, to: projection)
    }
    
    func edgeVector(from start: CGPoint, to end: CGPoint) -> CGVector {
        return CGVector(dx: end.x - start.x, dy: end.y - start.y)
    }
    
    func normalizeVector(_ vector: CGVector) -> CGVector {
        let length = sqrt(Double(vector.dx * vector.dx + vector.dy * vector.dy))
        
        if length < tolerance {
            return CGVector(dx: 0, dy: 0)
        }
        
        return CGVector(dx: vector.dx / CGFloat(length), dy: vector.dy / CGFloat(length))
    }
    
    func dotProduct(_ v1: CGVector, _ v2: CGVector) -> Double {
        return Double(v1.dx * v2.dx + v1.dy * v2.dy)
    }
    
    func crossProduct2D(_ v1: CGVector, _ v2: CGVector) -> Double {
        return Double(v1.dx * v2.dy - v1.dy * v2.dx)
    }
}

// MARK: - Edge Coincidence Methods

extension GeometryService {
    
    /// Check if two edges coincide (same line segment)
    func edgesCoincide(_ edge1: (CGPoint, CGPoint), _ edge2: (CGPoint, CGPoint), tolerance: Double = 1e-6) -> Bool {
        // Check if both endpoints match (in either order)
        let forwardMatch = pointsEqual(edge1.0, edge2.0, tolerance: tolerance) && 
                          pointsEqual(edge1.1, edge2.1, tolerance: tolerance)
        let reverseMatch = pointsEqual(edge1.0, edge2.1, tolerance: tolerance) && 
                          pointsEqual(edge1.1, edge2.0, tolerance: tolerance)
        return forwardMatch || reverseMatch
    }
    
    /// Check if a shorter edge lies along a longer edge
    func edgePartiallyCoincides(shorterEdge: (CGPoint, CGPoint), longerEdge: (CGPoint, CGPoint), tolerance: Double = 1e-6) -> Bool {
        // Check if both points of the shorter edge lie on the longer edge line segment
        let onLine1 = pointOnLineSegment(shorterEdge.0, lineStart: longerEdge.0, lineEnd: longerEdge.1, tolerance: tolerance)
        let onLine2 = pointOnLineSegment(shorterEdge.1, lineStart: longerEdge.0, lineEnd: longerEdge.1, tolerance: tolerance)
        return onLine1 && onLine2
    }
    
    /// Check if a point lies on a line segment
    func pointOnLineSegment(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint, tolerance: Double = 1e-6) -> Bool {
        // Check if point is collinear with the line segment
        let crossProduct = (point.y - lineStart.y) * (lineEnd.x - lineStart.x) - 
                          (point.x - lineStart.x) * (lineEnd.y - lineStart.y)
        
        if abs(crossProduct) > tolerance {
            return false // Not on the line
        }
        
        // Check if point is within the segment bounds
        let dotProduct = (point.x - lineStart.x) * (lineEnd.x - lineStart.x) + 
                        (point.y - lineStart.y) * (lineEnd.y - lineStart.y)
        let squaredLength = (lineEnd.x - lineStart.x) * (lineEnd.x - lineStart.x) + 
                           (lineEnd.y - lineStart.y) * (lineEnd.y - lineStart.y)
        
        if dotProduct < -tolerance || dotProduct > squaredLength + tolerance {
            return false // Outside the segment
        }
        
        return true
    }
}