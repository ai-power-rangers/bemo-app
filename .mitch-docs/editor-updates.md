# Tangram Editor Connection System Updates

## Overview
This document outlines surgical fixes to the tangram editor's connection and manipulation system based on deep code analysis. The fixes address vertex-to-edge sliding, dynamic constraint calculation for overlaps, and proper range limiting for both rotation and sliding operations.

## Issue 1: Vertex-to-Edge Sliding Not Enabled

### Current Problem
- **File**: `Bemo/Features/Game/Games/TangramEditor/Services/PieceManipulationService.swift`
- **Lines**: 99-102
- Vertex-to-edge connections return `.fixed` instead of `.slidable`

### Fix Required
Replace lines 99-102 in `PieceManipulationService.swift`:

```swift
case .vertexToEdge(let pieceAId, let vertex, let pieceBId, let edge):
    // Get the piece B (the edge owner) to determine the slide track
    let pieceB = pieces.first(where: { $0.id == pieceBId })
    guard let pieceB = pieceB else {
        return .fixed
    }
    
    let worldVerticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
    let edgesB = TangramGeometry.edges(for: pieceB.type)
    
    guard edge < edgesB.count else {
        return .fixed
    }
    
    let edgeDef = edgesB[edge]
    let edgeStart = worldVerticesB[edgeDef.startVertex]
    let edgeEnd = worldVerticesB[edgeDef.endVertex]
    
    // Calculate edge vector and length
    let dx = edgeEnd.x - edgeStart.x
    let dy = edgeEnd.y - edgeStart.y
    let edgeLength = sqrt(dx * dx + dy * dy)
    let normalizedVector = CGVector(dx: dx / edgeLength, dy: dy / edgeLength)
    
    // Allow sliding along the full edge
    let slideRange = 0...Double(edgeLength)
    let snapPositions = [0.0, 0.5, 1.0] // Snap at start, middle, end
    
    return .slidable(
        edge: ManipulationMode.Edge(
            start: edgeStart,
            end: edgeEnd,
            vector: normalizedVector
        ),
        range: slideRange,
        snapPositions: snapPositions
    )
```

## Issue 2: Dynamic Rotation Limits Based on Overlaps

### Current Problem
- **File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel+PieceOperations.swift`
- **Lines**: 299-353
- Rotation checks for overlap but doesn't find the maximum valid rotation range

### Fix Required
Add new method to `PieceManipulationService.swift`:

```swift
/// Calculate the valid rotation range for a piece to prevent overlaps
func calculateRotationLimits(
    piece: TangramPiece,
    pivot: CGPoint,
    otherPieces: [TangramPiece],
    stepDegrees: Double = 1.0
) -> (minAngle: Double, maxAngle: Double) {
    let validationService = ValidationService()
    
    // Test rotations in both directions to find limits
    var minValidAngle: Double = -360
    var maxValidAngle: Double = 360
    
    // Find minimum valid angle (counterclockwise limit)
    for angle in stride(from: 0, through: -360, by: -stepDegrees) {
        let radians = angle * .pi / 180
        var testTransform = CGAffineTransform.identity
        testTransform = testTransform.translatedBy(x: pivot.x, y: pivot.y)
        testTransform = testTransform.rotated(by: radians)
        testTransform = testTransform.translatedBy(x: -pivot.x, y: -pivot.y)
        
        let newTransform = piece.transform.concatenating(testTransform)
        let testPiece = TangramPiece(type: piece.type, transform: newTransform)
        
        var hasOverlap = false
        for other in otherPieces {
            if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                hasOverlap = true
                break
            }
        }
        
        if hasOverlap {
            minValidAngle = angle + stepDegrees
            break
        }
    }
    
    // Find maximum valid angle (clockwise limit)
    for angle in stride(from: 0, through: 360, by: stepDegrees) {
        let radians = angle * .pi / 180
        var testTransform = CGAffineTransform.identity
        testTransform = testTransform.translatedBy(x: pivot.x, y: pivot.y)
        testTransform = testTransform.rotated(by: radians)
        testTransform = testTransform.translatedBy(x: -pivot.x, y: -pivot.y)
        
        let newTransform = piece.transform.concatenating(testTransform)
        let testPiece = TangramPiece(type: piece.type, transform: newTransform)
        
        var hasOverlap = false
        for other in otherPieces {
            if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                hasOverlap = true
                break
            }
        }
        
        if hasOverlap {
            maxValidAngle = angle - stepDegrees
            break
        }
    }
    
    return (minValidAngle, maxValidAngle)
}
```

Update `calculateManipulationMode` in `PieceManipulationService.swift` at line 56-59:

```swift
case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
    // Get the pivot point (vertex in world space)
    let isPieceA = piece.id == pieceAId
    let vertexIndex = isPieceA ? vertexA : vertexB
    let worldVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
    
    guard vertexIndex < worldVertices.count else {
        return .fixed
    }
    
    let pivot = worldVertices[vertexIndex]
    
    // Calculate rotation limits based on other pieces
    let otherPieces = pieces.filter { $0.id != piece.id }
    let rotationLimits = calculateRotationLimits(
        piece: piece,
        pivot: pivot,
        otherPieces: otherPieces
    )
    
    // Snap at 45° intervals within valid range
    let allSnapAngles = [0, 45, 90, 135, 180, 225, 270, 315].map { Double($0) }
    let validSnapAngles = allSnapAngles.filter { angle in
        angle >= rotationLimits.minAngle && angle <= rotationLimits.maxAngle
    }
    
    return .rotatable(
        pivot: pivot,
        snapAngles: validSnapAngles,
        limits: rotationLimits  // Add limits to ManipulationMode enum
    )
```

Update `ManipulationMode.swift` line 17:

```swift
case rotatable(pivot: CGPoint, snapAngles: [Double], limits: (min: Double, max: Double))
```

## Issue 3: Dynamic Sliding Limits Based on Overlaps

### Current Problem
- **File**: `Bemo/Features/Game/Games/TangramEditor/Services/PieceManipulationService.swift`
- **Lines**: 61-97 (edge-to-edge) and new vertex-to-edge
- Sliding doesn't account for obstacles along the path

### Fix Required
Add new method to `PieceManipulationService.swift`:

```swift
/// Calculate valid sliding range considering obstacles
func calculateSlideLimits(
    piece: TangramPiece,
    edge: ManipulationMode.Edge,
    baseRange: ClosedRange<Double>,
    otherPieces: [TangramPiece],
    stepSize: Double = 1.0
) -> ClosedRange<Double> {
    let validationService = ValidationService()
    var minValidDistance = baseRange.lowerBound
    var maxValidDistance = baseRange.upperBound
    
    // Test sliding positions to find collision points
    // Check forward (positive) direction
    for distance in stride(from: 0, through: baseRange.upperBound, by: stepSize) {
        let translation = CGAffineTransform(
            translationX: edge.vector.dx * CGFloat(distance),
            y: edge.vector.dy * CGFloat(distance)
        )
        
        let newTransform = piece.transform.concatenating(translation)
        let testPiece = TangramPiece(type: piece.type, transform: newTransform)
        
        var hasOverlap = false
        for other in otherPieces {
            if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                hasOverlap = true
                break
            }
        }
        
        if hasOverlap {
            maxValidDistance = max(0, distance - stepSize)
            break
        }
    }
    
    // Check backward (negative) direction
    for distance in stride(from: 0, through: baseRange.lowerBound, by: -stepSize) {
        let translation = CGAffineTransform(
            translationX: edge.vector.dx * CGFloat(distance),
            y: edge.vector.dy * CGFloat(distance)
        )
        
        let newTransform = piece.transform.concatenating(translation)
        let testPiece = TangramPiece(type: piece.type, transform: newTransform)
        
        var hasOverlap = false
        for other in otherPieces {
            if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                hasOverlap = true
                break
            }
        }
        
        if hasOverlap {
            minValidDistance = distance + stepSize
            break
        }
    }
    
    return minValidDistance...maxValidDistance
}
```

Update edge-to-edge calculation in `PieceManipulationService.swift` lines 85-97:

```swift
// Calculate base slide range
let baseSlideRange = 0...Double(edgeLength)

// Calculate actual limits considering obstacles
let otherPieces = pieces.filter { $0.id != piece.id }
let actualSlideRange = calculateSlideLimits(
    piece: piece,
    edge: ManipulationMode.Edge(
        start: edgeStart,
        end: edgeEnd,
        vector: normalizedVector
    ),
    baseRange: baseSlideRange,
    otherPieces: otherPieces
)

// Calculate snap positions within valid range
let rangeLength = actualSlideRange.upperBound - actualSlideRange.lowerBound
let snapPositions = [0.0, 0.5, 1.0].map { 
    actualSlideRange.lowerBound + $0 * rangeLength
}

return .slidable(
    edge: ManipulationMode.Edge(
        start: edgeStart,
        end: edgeEnd,
        vector: normalizedVector
    ),
    range: actualSlideRange,
    snapPositions: snapPositions
)
```

## Issue 4: Missing PieceManipulationService Dependency

### Current Problem
- `calculateManipulationMode` needs access to all pieces but only receives the single piece

### Fix Required
Update method signature in `PieceManipulationService.swift` line 21:

```swift
func calculateManipulationMode(
    piece: TangramPiece, 
    connections: [Connection], 
    allPieces: [TangramPiece],  // Add this parameter
    isFirstPiece: Bool = false
) -> ManipulationMode {
```

Update all callers:
- `TangramEditorViewModel+PieceOperations.swift` line 283
- `TangramEditorViewModel+PieceOperations.swift` line 291

## Issue 5: Improve Overlap Detection Performance

### Current Problem
- Multiple overlap checks during manipulation can be expensive

### Fix Required
Add caching to `ValidationService.swift`:

```swift
class ValidationService {
    private var overlapCache: [String: Bool] = [:]
    
    func clearCache() {
        overlapCache.removeAll()
    }
    
    func hasAreaOverlap(pieceA: TangramPiece, pieceB: TangramPiece, useCache: Bool = true) -> Bool {
        let cacheKey = "\(pieceA.id)_\(pieceB.id)_\(pieceA.transform)_\(pieceB.transform)"
        
        if useCache, let cached = overlapCache[cacheKey] {
            return cached
        }
        
        // Existing overlap detection logic...
        let result = // ... existing calculation
        
        if useCache {
            overlapCache[cacheKey] = result
        }
        
        return result
    }
}
```

## Issue 6: Visual Feedback for Constraints

### Current Problem
- Users can't see the valid manipulation range

### Fix Required
Update `PieceView.swift` manipulation indicators (lines 76-130) to show limits:

```swift
case .rotatable(let pivot, let snapAngles, let limits):
    ZStack {
        // Pivot point
        Circle()
            .fill(Color.blue.opacity(0.8))
            .frame(width: 12, height: 12)
            .position(pivot)
        
        // Valid rotation arc (show limits)
        if isManipulating {
            Path { path in
                path.addArc(
                    center: pivot,
                    radius: 50,
                    startAngle: Angle(degrees: limits.min),
                    endAngle: Angle(degrees: limits.max),
                    clockwise: false
                )
            }
            .stroke(Color.blue.opacity(0.3), lineWidth: 3)
            
            // Limit indicators
            Circle()
                .fill(Color.red.opacity(0.5))
                .frame(width: 8, height: 8)
                .position(snapAnglePosition(angle: limits.min, pivot: pivot))
            
            Circle()
                .fill(Color.red.opacity(0.5))
                .frame(width: 8, height: 8)
                .position(snapAnglePosition(angle: limits.max, pivot: pivot))
            
            // Valid snap angles within limits
            ForEach(snapAngles, id: \.self) { angle in
                Circle()
                    .fill(isNearAngle(angle) ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .position(snapAnglePosition(angle: angle, pivot: pivot))
            }
        }
    }

case .slidable(let edge, let range, let snapPositions):
    ZStack {
        // Full theoretical track (semi-transparent)
        Path { path in
            path.move(to: edge.start)
            path.addLine(to: edge.end)
        }
        .stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: 3, dash: [5, 5]))
        
        // Valid slide range (solid)
        Path { path in
            let startPoint = CGPoint(
                x: edge.start.x + edge.vector.dx * CGFloat(range.lowerBound),
                y: edge.start.y + edge.vector.dy * CGFloat(range.lowerBound)
            )
            let endPoint = CGPoint(
                x: edge.start.x + edge.vector.dx * CGFloat(range.upperBound),
                y: edge.start.y + edge.vector.dy * CGFloat(range.upperBound)
            )
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        }
        .stroke(Color.orange.opacity(0.8), lineWidth: 3)
        
        // Range limit indicators
        Circle()
            .fill(Color.red.opacity(0.5))
            .frame(width: 10, height: 10)
            .position(CGPoint(
                x: edge.start.x + edge.vector.dx * CGFloat(range.lowerBound),
                y: edge.start.y + edge.vector.dy * CGFloat(range.lowerBound)
            ))
        
        Circle()
            .fill(Color.red.opacity(0.5))
            .frame(width: 10, height: 10)
            .position(CGPoint(
                x: edge.start.x + edge.vector.dx * CGFloat(range.upperBound),
                y: edge.start.y + edge.vector.dy * CGFloat(range.upperBound)
            ))
        
        // Snap points within valid range
        ForEach(snapPositions, id: \.self) { position in
            Circle()
                .fill(isNearPosition(position, range: range) ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 10, height: 10)
                .position(CGPoint(
                    x: edge.start.x + edge.vector.dx * CGFloat(position),
                    y: edge.start.y + edge.vector.dy * CGFloat(position)
                ))
        }
    }
```

## Testing Plan

### Test Cases for Each Fix:

1. **Vertex-to-Edge Sliding**
   - Place a piece with vertex on another piece's edge
   - Verify piece can slide along the edge
   - Verify sliding stops at edge endpoints
   - Verify snap points work at 0%, 50%, 100%

2. **Dynamic Rotation Limits**
   - Place pieces in configuration where rotation would cause overlap
   - Verify rotation stops just before overlap
   - Verify rotation works in opposite direction
   - Verify visual indicators show valid range

3. **Dynamic Sliding Limits**
   - Place obstacle pieces along a sliding path
   - Verify sliding stops before collision
   - Verify sliding range updates when obstacles are added/removed
   - Verify visual indicators show constrained range

4. **Edge Cases**
   - Test with all 7 tangram piece types
   - Test with pieces at canvas boundaries
   - Test with multiple simultaneous constraints
   - Test undo/redo with constrained manipulations

## Implementation Order

1. Fix vertex-to-edge sliding (Issue 1) - Simple, isolated change
2. Add dynamic sliding limits (Issue 3) - Builds on Issue 1
3. Add dynamic rotation limits (Issue 2) - Similar pattern to Issue 3
4. Update visual feedback (Issue 6) - Depends on Issues 2 & 3
5. Add performance caching (Issue 5) - Optimization after functionality works

## File Change Summary

Files to modify:
- `PieceManipulationService.swift` - Core logic updates
- `ManipulationMode.swift` - Add limits to enum
- `ValidationService.swift` - Add caching
- `TangramEditorViewModel+PieceOperations.swift` - Update method calls
- `PieceView.swift` - Enhanced visual feedback

Estimated effort: 4-6 hours for full implementation and testing