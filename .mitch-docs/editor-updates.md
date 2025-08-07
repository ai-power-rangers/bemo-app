# Tangram Editor Connection System Updates

## Overview
This document outlines surgical fixes to the tangram editor's connection and manipulation system based on deep code analysis. The fixes address vertex-to-edge sliding, dynamic constraint calculation for overlaps, and proper range limiting for both rotation and sliding operations.

**CRITICAL: The implementation preserves the existing `ManipulationMode` enum to avoid breaking pattern matching throughout the codebase. Dynamic limits are calculated and stored separately in the ViewModel.**

## Implementation Order (CRITICAL - Must Follow)

1. **Issue 4** - Add pieces parameter (Foundation - Required by other fixes)
2. **Issue 1** - Enable vertex-to-edge sliding (Simple, isolated)
3. **Issue 3** - Add dynamic sliding limits (Builds on Issue 1 & 4)
4. **Issue 2** - Add dynamic rotation limits (Similar to Issue 3)
5. **Issue 6** - Update visual feedback (Depends on 2 & 3)
6. **Issue 5** - Add performance caching (Optimization)

---

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
    guard let pieceB = allPieces.first(where: { $0.id == pieceBId }) else {
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
    
    // Calculate dynamic slide limits if we have obstacle checking
    let baseRange = 0...Double(edgeLength)
    let otherPieces = allPieces.filter { $0.id != piece.id && $0.id != pieceBId }
    
    // For initial implementation, use full edge range
    // Dynamic limits will be calculated in Phase 3
    let slideRange = baseRange
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

---

## Issue 2: Dynamic Rotation Limits Based on Overlaps

### Current Problem
- **File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel+PieceOperations.swift`
- **Lines**: 299-353
- Rotation checks for overlap but doesn't find the maximum valid rotation range

### Fix Required

**Step 1:** Add constraint storage to `TangramEditorViewModel.swift` (around line 50 after other state variables):

```swift
// MARK: - Dynamic Manipulation Constraints
var manipulationConstraints: [String: ManipulationConstraints] = [:]

struct ManipulationConstraints {
    var rotationLimits: (min: Double, max: Double)?
    var slideLimits: ClosedRange<Double>?
}
```

**Step 2:** Add helper method to `PieceManipulationService.swift`:

```swift
/// Calculate the valid rotation range for a piece to prevent overlaps
func calculateRotationLimits(
    piece: TangramPiece,
    pivot: CGPoint,
    otherPieces: [TangramPiece],
    stepDegrees: Double = 5.0
) -> (minAngle: Double, maxAngle: Double) {
    let validationService = ValidationService()
    
    // Start from current rotation (0 degrees relative)
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

**Step 3:** Update `handleRotation` in `TangramEditorViewModel+PieceOperations.swift` (replace lines 299-353):

```swift
func handleRotation(pieceId: String, angle: Double) {
    guard let mode = pieceManipulationModes[pieceId],
          let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
        return
    }
    
    switch mode {
    case .rotatable(let pivot, let snapAngles):
        let piece = puzzle.pieces[pieceIndex]
        
        // Calculate dynamic rotation limits if not cached
        if manipulationConstraints[pieceId]?.rotationLimits == nil {
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            let limits = manipulationService.calculateRotationLimits(
                piece: piece,
                pivot: pivot,
                otherPieces: otherPieces
            )
            manipulationConstraints[pieceId] = ManipulationConstraints(
                rotationLimits: limits,
                slideLimits: nil
            )
        }
        
        let limits = manipulationConstraints[pieceId]?.rotationLimits ?? (-360.0, 360.0)
        
        // Convert angle to degrees and clamp to limits
        let angleDegrees = angle * 180 / .pi
        let clampedAngle = max(limits.min, min(limits.max, angleDegrees))
        
        // Find nearest valid snap angle within limits
        let validSnapAngles = snapAngles.filter { snapAngle in
            snapAngle >= limits.min && snapAngle <= limits.max
        }
        
        let snappedAngle = validSnapAngles.min(by: { 
            abs($0 - clampedAngle) < abs($1 - clampedAngle) 
        }) ?? clampedAngle
        
        // Convert back to radians
        let snappedRadians = snappedAngle * .pi / 180
        
        // Create rotation transform around pivot
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: pivot.x, y: pivot.y)
        transform = transform.rotated(by: snappedRadians)
        transform = transform.translatedBy(x: -pivot.x, y: -pivot.y)
        
        // Apply to piece's base transform
        let newTransform = piece.transform.concatenating(transform)
        
        // Final overlap check (should always pass due to limits)
        let testPiece = TangramPiece(type: piece.type, transform: newTransform)
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        
        var hasOverlap = false
        for other in otherPieces {
            if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                hasOverlap = true
                break
            }
        }
        
        if !hasOverlap {
            // Update ghost preview
            uiState.ghostTransform = newTransform
            uiState.showSnapIndicator = abs(angle - snappedRadians) < 0.1
            
            // Store as manipulating piece
            uiState.manipulatingPieceId = pieceId
        }
        
    default:
        break
    }
}
```

---

## Issue 3: Dynamic Sliding Limits Based on Overlaps

### Current Problem
- **File**: `Bemo/Features/Game/Games/TangramEditor/Services/PieceManipulationService.swift`
- **Lines**: 61-97 (edge-to-edge) and new vertex-to-edge
- Sliding doesn't account for obstacles along the path

### Fix Required

**Step 1:** Add method to `PieceManipulationService.swift`:

```swift
/// Calculate valid sliding range considering obstacles
func calculateSlideLimits(
    piece: TangramPiece,
    edge: ManipulationMode.Edge,
    baseRange: ClosedRange<Double>,
    otherPieces: [TangramPiece],
    stepSize: Double = 2.0
) -> ClosedRange<Double> {
    let validationService = ValidationService()
    var minValidDistance = baseRange.lowerBound
    var maxValidDistance = baseRange.upperBound
    
    // Get current position along edge (assumed to be 0 for initial placement)
    let currentPosition: Double = 0
    
    // Check forward (positive) direction from current position
    for distance in stride(from: currentPosition, through: baseRange.upperBound, by: stepSize) {
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
            maxValidDistance = max(currentPosition, distance - stepSize)
            break
        }
    }
    
    // Check backward (negative) direction from current position
    for distance in stride(from: currentPosition, through: baseRange.lowerBound, by: -stepSize) {
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
            minValidDistance = min(currentPosition, distance + stepSize)
            break
        }
    }
    
    return minValidDistance...maxValidDistance
}
```

**Step 2:** Update edge-to-edge case in `calculateManipulationMode` (lines 61-97):

```swift
case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
    // Determine which piece is sliding and which is stationary
    let isPieceA = piece.id == pieceAId
    
    // Get the other piece to determine the slide track
    guard let otherPiece = allPieces.first(where: { 
        $0.id == (isPieceA ? pieceBId : pieceAId) 
    }) else {
        return .fixed
    }
    
    let edgeIndex = isPieceA ? edgeA : edgeB
    let worldVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
    let edges = TangramGeometry.edges(for: piece.type)
    
    guard edgeIndex < edges.count else {
        return .fixed
    }
    
    let edgeDef = edges[edgeIndex]
    let edgeStart = worldVertices[edgeDef.startVertex]
    let edgeEnd = worldVertices[edgeDef.endVertex]
    
    // Calculate edge vector
    let dx = edgeEnd.x - edgeStart.x
    let dy = edgeEnd.y - edgeStart.y
    let edgeLength = sqrt(dx * dx + dy * dy)
    let normalizedVector = CGVector(dx: dx / edgeLength, dy: dy / edgeLength)
    
    // Calculate base slide range
    let slideRange = 0...Double(edgeLength)
    
    // For now, use base range - dynamic limits will be calculated in ViewModel
    let snapPositions = [0.0, 0.5, 1.0]
    
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

**Step 3:** Update `handleSlide` in `TangramEditorViewModel+PieceOperations.swift` (lines 376-433):

```swift
func handleSlide(pieceId: String, distance: Double) {
    guard let mode = pieceManipulationModes[pieceId],
          let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
        return
    }
    
    switch mode {
    case .slidable(let edge, let baseRange, let snapPositions):
        let piece = puzzle.pieces[pieceIndex]
        
        // Calculate dynamic slide limits if not cached
        if manipulationConstraints[pieceId]?.slideLimits == nil {
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            let limits = manipulationService.calculateSlideLimits(
                piece: piece,
                edge: edge,
                baseRange: baseRange,
                otherPieces: otherPieces
            )
            
            if var constraints = manipulationConstraints[pieceId] {
                constraints.slideLimits = limits
                manipulationConstraints[pieceId] = constraints
            } else {
                manipulationConstraints[pieceId] = ManipulationConstraints(
                    rotationLimits: nil,
                    slideLimits: limits
                )
            }
        }
        
        let range = manipulationConstraints[pieceId]?.slideLimits ?? baseRange
        
        // Clamp distance to valid range
        let clampedDistance = max(range.lowerBound, min(range.upperBound, distance))
        
        // Find nearest snap position within valid range
        let normalizedDistance = (clampedDistance - range.lowerBound) / (range.upperBound - range.lowerBound)
        let validSnapPositions = snapPositions.filter { pos in
            let absolutePos = range.lowerBound + pos * (range.upperBound - range.lowerBound)
            return absolutePos >= range.lowerBound && absolutePos <= range.upperBound
        }
        
        let snappedPosition = validSnapPositions.min(by: {
            abs($0 - normalizedDistance) < abs($1 - normalizedDistance)
        }) ?? normalizedDistance
        
        // Convert back to actual distance
        let snappedDistance = range.lowerBound + snappedPosition * (range.upperBound - range.lowerBound)
        
        // Calculate translation along edge vector
        let translation = CGVector(
            dx: edge.vector.dx * snappedDistance,
            dy: edge.vector.dy * snappedDistance
        )
        
        // Create new transform
        var newTransform = piece.transform
        newTransform.tx += translation.dx
        newTransform.ty += translation.dy
        
        // Final overlap check (should always pass due to limits)
        let testPiece = TangramPiece(type: piece.type, transform: newTransform)
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        
        var hasOverlap = false
        for other in otherPieces {
            if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                hasOverlap = true
                break
            }
        }
        
        if !hasOverlap {
            // Update ghost preview
            uiState.ghostTransform = newTransform
            uiState.showSnapIndicator = validSnapPositions.contains(snappedPosition)
            
            // Store as manipulating piece
            uiState.manipulatingPieceId = pieceId
        }
        
    default:
        break
    }
}
```

---

## Issue 4: Missing PieceManipulationService Dependency (DO THIS FIRST!)

### Current Problem
- `calculateManipulationMode` needs access to all pieces but only receives the single piece
- This blocks Issues 1, 2, and 3

### Fix Required

**Step 1:** Update method signature in `PieceManipulationService.swift` line 21:

```swift
func calculateManipulationMode(
    piece: TangramPiece, 
    connections: [Connection], 
    allPieces: [TangramPiece],  // Add this parameter
    isFirstPiece: Bool = false
) -> ManipulationMode {
```

**Step 2:** Update the method body to use `allPieces` parameter:
- Line 44: Already handled in Issue 1 fix
- Lines 61-97: Already handled in Issue 3 fix

**Step 3:** Update caller in `TangramEditorViewModel+PieceOperations.swift` line 283:

```swift
return manipulationService.calculateManipulationMode(
    piece: piece, 
    connections: puzzle.connections,
    allPieces: puzzle.pieces,  // Add this
    isFirstPiece: isFirstPiece
)
```

**Step 4:** Update `updateManipulationModes` in same file around line 291:

```swift
func updateManipulationModes() {
    pieceManipulationModes.removeAll()
    manipulationConstraints.removeAll()  // Clear cached constraints
    
    for piece in puzzle.pieces {
        let mode = determineManipulationMode(for: piece.id)
        pieceManipulationModes[piece.id] = mode
    }
}
```

---

## Issue 5: Improve Overlap Detection Performance

### Current Problem
- Multiple overlap checks during manipulation can be expensive

### Fix Required
Add caching to `ValidationService.swift` (after line 13):

```swift
class ValidationService {
    
    private let geometryService = GeometryService()
    private var overlapCache: [String: Bool] = [:]  // Add cache
    
    // Add cache management methods
    func clearCache() {
        overlapCache.removeAll()
    }
    
    private func getCacheKey(pieceA: TangramPiece, pieceB: TangramPiece) -> String {
        // Create a stable cache key based on piece IDs and transforms
        let transformA = "\(pieceA.transform.a),\(pieceA.transform.b),\(pieceA.transform.c),\(pieceA.transform.d),\(pieceA.transform.tx),\(pieceA.transform.ty)"
        let transformB = "\(pieceB.transform.a),\(pieceB.transform.b),\(pieceB.transform.c),\(pieceB.transform.d),\(pieceB.transform.tx),\(pieceB.transform.ty)"
        return "\(pieceA.id)_\(transformA)_\(pieceB.id)_\(transformB)"
    }
    
    // Update hasAreaOverlap to use cache
    func hasAreaOverlap(pieceA: TangramPiece, pieceB: TangramPiece, useCache: Bool = true) -> Bool {
        let cacheKey = getCacheKey(pieceA: pieceA, pieceB: pieceB)
        
        if useCache, let cached = overlapCache[cacheKey] {
            return cached
        }
        
        // Existing overlap detection logic (lines 47-89)
        let verticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
        let verticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
        
        // ... rest of existing overlap detection code ...
        
        let result = // ... existing calculation result
        
        if useCache {
            overlapCache[cacheKey] = result
        }
        
        return result
    }
```

Update `TangramEditorViewModel+PieceOperations.swift` to clear cache when pieces change:

```swift
func confirmRotation() {
    // ... existing code ...
    validationService.clearCache()  // Add this line
    validate()
    notifyPuzzleChanged()
}

func confirmSlide() {
    // ... existing code ...
    validationService.clearCache()  // Add this line
    validate()
    notifyPuzzleChanged()
}
```

---

## Issue 6: Visual Feedback for Constraints

### Current Problem
- Users can't see the valid manipulation range
- **NOTE:** We pass constraints through props instead of modifying the enum

### Fix Required

**Step 1:** Update `TangramEditorCanvasView.swift` to pass constraints (around line 235):

```swift
PieceView(
    piece: piece,
    isSelected: viewModel.selectedPieceId == piece.id,
    isGhost: false,
    showConnectionPoints: showConnectionPoints,
    availableConnectionPoints: connectionPoints,
    selectedConnectionPoints: viewModel.uiState.selectedCanvasPoints,
    manipulationMode: viewModel.pieceManipulationModes[piece.id],
    manipulationConstraints: viewModel.manipulationConstraints[piece.id],  // Add this
    onRotation: { angle in
        viewModel.handleRotation(pieceId: piece.id, angle: angle)
    },
    onSlide: { distance in
        viewModel.handleSlide(pieceId: piece.id, distance: distance)
    },
    onManipulationEnd: {
        viewModel.confirmRotation()
    }
)
```

**Step 2:** Update `PieceView.swift` to accept and use constraints:

Add property (after line 18):
```swift
let manipulationConstraints: TangramEditorViewModel.ManipulationConstraints?
```

Update the manipulation indicator overlay (lines 76-133):

```swift
@ViewBuilder
private func manipulationIndicatorOverlay(for mode: ManipulationMode) -> some View {
    switch mode {
    case .fixed:
        // Fixed piece indicator (subtle)
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 8, height: 8)
            .position(getPieceCenter())
        
    case .rotatable(let pivot, let snapAngles):
        // Rotation arc and snap indicators
        ZStack {
            // Pivot point
            Circle()
                .fill(Color.blue.opacity(0.8))
                .frame(width: 12, height: 12)
                .position(pivot)
            
            // Rotation arc with limits
            if isManipulating {
                if let limits = manipulationConstraints?.rotationLimits {
                    // Show constrained arc
                    Path { path in
                        path.addArc(
                            center: pivot,
                            radius: 50,
                            startAngle: Angle(degrees: limits.min),
                            endAngle: Angle(degrees: limits.max),
                            clockwise: false
                        )
                    }
                    .stroke(Color.blue.opacity(0.5), lineWidth: 3)
                    
                    // Limit indicators
                    Circle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .position(snapAnglePosition(angle: limits.min, pivot: pivot))
                    
                    Circle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .position(snapAnglePosition(angle: limits.max, pivot: pivot))
                } else {
                    // Show full circle if no limits
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .position(pivot)
                }
                
                // Snap angle indicators (only show valid ones)
                let validSnapAngles = manipulationConstraints?.rotationLimits != nil ?
                    snapAngles.filter { angle in
                        let limits = manipulationConstraints!.rotationLimits!
                        return angle >= limits.min && angle <= limits.max
                    } : snapAngles
                
                ForEach(validSnapAngles, id: \.self) { angle in
                    Circle()
                        .fill(isNearAngle(angle) ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .position(snapAnglePosition(angle: angle, pivot: pivot))
                }
            }
        }
        
    case .slidable(let edge, let baseRange, let snapPositions):
        // Slide track and snap points
        ZStack {
            let range = manipulationConstraints?.slideLimits ?? baseRange
            
            // Full theoretical track (semi-transparent)
            Path { path in
                path.move(to: edge.start)
                path.addLine(to: edge.end)
            }
            .stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: 3, dash: [5, 5]))
            
            // Valid slide range (solid)
            if let limits = manipulationConstraints?.slideLimits {
                Path { path in
                    let startPoint = CGPoint(
                        x: edge.start.x + edge.vector.dx * CGFloat(limits.lowerBound),
                        y: edge.start.y + edge.vector.dy * CGFloat(limits.lowerBound)
                    )
                    let endPoint = CGPoint(
                        x: edge.start.x + edge.vector.dx * CGFloat(limits.upperBound),
                        y: edge.start.y + edge.vector.dy * CGFloat(limits.upperBound)
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.orange.opacity(0.8), lineWidth: 4)
                
                // Range limit indicators
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .position(CGPoint(
                        x: edge.start.x + edge.vector.dx * CGFloat(limits.lowerBound),
                        y: edge.start.y + edge.vector.dy * CGFloat(limits.lowerBound)
                    ))
                
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .position(CGPoint(
                        x: edge.start.x + edge.vector.dx * CGFloat(limits.upperBound),
                        y: edge.start.y + edge.vector.dy * CGFloat(limits.upperBound)
                    ))
            }
            
            // Snap points within valid range
            ForEach(snapPositions, id: \.self) { position in
                let isWithinLimits = manipulationConstraints?.slideLimits != nil ?
                    range.contains(position) : true
                
                if isWithinLimits {
                    Circle()
                        .fill(isNearPosition(position, range: range) ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 10, height: 10)
                        .position(snapPointPosition(position: position, edge: edge, range: range))
                }
            }
        }
        
    case .free:
        // Free movement indicator - no visual needed
        EmptyView()
    }
}
```

---

## Testing Plan

### Test Cases for Each Fix:

1. **Foundation (Issue 4)**
   - Verify `calculateManipulationMode` receives all pieces
   - Check that manipulation modes are calculated correctly

2. **Vertex-to-Edge Sliding (Issue 1)**
   - Place a piece with vertex on another piece's edge
   - Verify piece can slide along the edge
   - Verify sliding stops at edge endpoints
   - Verify snap points work at 0%, 50%, 100%

3. **Dynamic Rotation Limits (Issue 2)**
   - Place pieces in configuration where rotation would cause overlap
   - Verify rotation stops just before overlap
   - Verify rotation works in opposite direction
   - Verify visual indicators show valid range (red dots at limits)

4. **Dynamic Sliding Limits (Issue 3)**
   - Place obstacle pieces along a sliding path
   - Verify sliding stops before collision
   - Verify sliding range updates when obstacles are added/removed
   - Verify visual indicators show constrained range (solid orange line)

5. **Performance (Issue 5)**
   - Verify cache speeds up repeated overlap checks
   - Verify cache clears when pieces change

6. **Visual Feedback (Issue 6)**
   - Verify rotation arc shows limited range when constrained
   - Verify slide track shows limited range when constrained
   - Verify limit indicators (red dots) appear at constraint boundaries

### Edge Cases:
- Test with all 7 tangram piece types
- Test with pieces at canvas boundaries
- Test with multiple simultaneous constraints
- Test undo/redo with constrained manipulations
- Test performance with complex arrangements

## File Change Summary

Files to modify (in order):
1. `PieceManipulationService.swift` - Add allPieces parameter, fix vertex-to-edge, add limit calculation methods
2. `TangramEditorViewModel+PieceOperations.swift` - Update method calls, add constraint storage and handling
3. `TangramEditorViewModel.swift` - Add ManipulationConstraints struct and storage
4. `ValidationService.swift` - Add caching
5. `TangramEditorCanvasView.swift` - Pass constraints to PieceView
6. `PieceView.swift` - Enhanced visual feedback using constraints

**Critical Notes:**
- DO NOT modify the `ManipulationMode` enum - this would break pattern matching throughout the codebase
- Constraints are calculated and stored separately in the ViewModel
- Visual feedback reads constraints from props, not from the enum
- Cache must be cleared whenever pieces are modified

Estimated effort: 3-4 hours for full implementation and testing