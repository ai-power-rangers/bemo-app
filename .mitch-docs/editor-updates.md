# Tangram Editor Critical Fix: Strict Validation and Discrete Positioning

## Executive Summary

The Tangram Editor currently allows invalid piece placements and previews to be shown to users. This document outlines a comprehensive plan to enforce strict validation rules, ensuring pieces can only be placed in valid positions with discrete snap points and proper connection integrity.

## Current Problems Identified

### 1. Invalid Preview Display
- **Problem**: The preview system shows pieces in positions that would cause overlaps
- **Location**: `TangramEditorViewModel+StateAndUI.swift`, lines 216-275
- **Root Cause**: `updatePreviewIfNeeded()` doesn't validate transforms before displaying preview

### 2. Continuous vs. Discrete Positioning
- **Problem**: Pieces can be positioned at any angle/position instead of discrete snap points
- **Current Behavior**: 
  - Rotation allows any angle, not just 45° increments
  - Sliding allows any position along edge, not just 0%, 25%, 50%, 75%, 100%
- **Root Cause**: Snap calculations are suggestions, not enforced constraints

### 3. Connection Integrity Not Enforced
- **Problem**: Connections can be broken during manipulation
- **Specific Issues**:
  - Vertex-to-vertex connections don't maintain exact point connection
  - Vertex-to-edge connections allow vertex to leave the edge
  - Edge-to-edge connections don't maintain parallel alignment

### 4. Incomplete Validation Integration
- **Problem**: `PuzzleValidationRules` exists but isn't used consistently
- **Location**: Validation happens with basic `hasAreaOverlap()` instead of comprehensive rules
- **Impact**: Misses connection integrity checks and other validation rules

## Required Behavior Specification

### Rotation Rules
- **ONLY** allow rotations at 45° increments: -180°, -135°, -90°, -45°, 0°, 45°, 90°, 135°, 180°
- **NO** intermediate angles
- **NO** preview at invalid angles

### Sliding Rules  
- **ONLY** allow sliding at discrete positions: 0%, 25%, 50%, 75%, 100% of the stationary piece's edge
- **NO** continuous sliding between these points
- **NO** preview at invalid positions

### Connection Integrity Rules

#### Vertex-to-Vertex
- Connected vertices must remain at the EXACT same point
- During rotation: Connected vertex is the immovable pivot point
- During sliding: Not applicable (piece cannot slide)

#### Vertex-to-Edge
- Vertex must remain ON the edge at all times
- During rotation: Vertex stays on edge but may slide along it
- During sliding: Vertex moves to one of 5 discrete positions on edge

#### Edge-to-Edge
- Edges must remain parallel and touching
- During rotation: Not applicable (piece cannot rotate)
- During sliding: Piece moves to one of 5 discrete positions

### Preview Rules
- **NEVER** show a preview in an invalid position
- If position would cause overlap → No preview
- If position would break connection → No preview
- If position is between snap points → No preview

## Data Flow Analysis

### Current Flow (Broken)
```
User Gesture 
→ Calculate Transform (any value)
→ Basic Overlap Check
→ Show Preview (even if invalid)
→ User Confirms
→ Place Piece
```

### Required Flow (Fixed)
```
User Gesture
→ Calculate Nearest Snap Point
→ Create Transform at Snap Point
→ Comprehensive Validation (PuzzleValidationRules)
→ IF VALID: Show Preview
  IF INVALID: Show Nothing
→ User Confirms Valid Position
→ Place Piece
```

## Comprehensive Fix Plan

### Phase 1: Enforce Discrete Snap Points

#### Fix 1.1: Force 45° Rotation Snapping
**File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel+PieceOperations.swift`

**Lines 337-436** - `handleRotation` method:
```swift
// Replace lines 350-355 with:
func handleRotation(pieceId: String, angle: Double) {
    guard let mode = pieceManipulationModes[pieceId],
          let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
        return
    }
    
    switch mode {
    case .rotatable(let pivot, _):
        let piece = puzzle.pieces[pieceIndex]
        
        // CRITICAL: Force exact 45° increments
        let angleDegrees = angle * 180 / .pi
        let validAngles: [Double] = [-180, -135, -90, -45, 0, 45, 90, 135, 180]
        
        // Find nearest valid angle
        guard let snappedAngle = validAngles.min(by: { 
            abs($0 - angleDegrees) < abs($1 - angleDegrees) 
        }) else { return }
        
        // Store initial transform if not already stored
        if initialManipulationTransforms[pieceId] == nil {
            initialManipulationTransforms[pieceId] = piece.transform
        }
        
        guard let initialTransform = initialManipulationTransforms[pieceId] else { return }
        
        // Calculate rotation from initial position
        let snappedRadians = snappedAngle * .pi / 180
        
        // Create rotation transform around pivot
        var rotationTransform = CGAffineTransform.identity
        rotationTransform = rotationTransform.translatedBy(x: pivot.x, y: pivot.y)
        rotationTransform = rotationTransform.rotated(by: snappedRadians)
        rotationTransform = rotationTransform.translatedBy(x: -pivot.x, y: -pivot.y)
        
        // Apply to initial transform (not current)
        let finalTransform = initialTransform.concatenating(rotationTransform)
        
        // Find the connection this piece is maintaining
        let relevantConnection = puzzle.connections.first { conn in
            conn.pieceAId == pieceId || conn.pieceBId == pieceId
        }
        
        // CRITICAL: Use comprehensive validation
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        if PuzzleValidationRules.isValidPlacement(
            piece: piece,
            withTransform: finalTransform,
            amongPieces: otherPieces,
            maintainingConnection: relevantConnection
        ) {
            // Only show preview if valid
            uiState.ghostTransform = finalTransform
            uiState.showSnapIndicator = true
            uiState.manipulatingPieceId = pieceId
        } else {
            // NO PREVIEW for invalid positions
            uiState.ghostTransform = nil
            uiState.showSnapIndicator = false
        }
        
    default:
        break
    }
}
```

#### Fix 1.2: Force Discrete Slide Positions
**File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel+PieceOperations.swift`

**Lines 464-539** - `handleSlide` method:
```swift
// Replace lines 464-539 with:
func handleSlide(pieceId: String, distance: Double) {
    guard let mode = pieceManipulationModes[pieceId],
          let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
        return
    }
    
    switch mode {
    case .slidable(let edge, let baseRange, _):
        let piece = puzzle.pieces[pieceIndex]
        
        // Store initial transform if not already stored
        if initialManipulationTransforms[pieceId] == nil {
            initialManipulationTransforms[pieceId] = piece.transform
        }
        
        guard let initialTransform = initialManipulationTransforms[pieceId] else { return }
        
        // CRITICAL: Force exact percentage positions
        let rangeLength = baseRange.upperBound - baseRange.lowerBound
        let normalizedDistance = (distance - baseRange.lowerBound) / rangeLength
        
        // Snap to nearest percentage: 0%, 25%, 50%, 75%, 100%
        let snapPercentages: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
        guard let snappedPercentage = snapPercentages.min(by: {
            abs($0 - normalizedDistance) < abs($1 - normalizedDistance)
        }) else { return }
        
        // Calculate actual distance at snap position
        let snappedDistance = baseRange.lowerBound + (snappedPercentage * rangeLength)
        
        // Create translation from initial position
        let translation = CGAffineTransform(
            translationX: edge.vector.dx * CGFloat(snappedDistance),
            y: edge.vector.dy * CGFloat(snappedDistance)
        )
        
        // Apply to initial transform
        let finalTransform = initialTransform.concatenating(translation)
        
        // Find the connection this piece is maintaining
        let relevantConnection = puzzle.connections.first { conn in
            conn.pieceAId == pieceId || conn.pieceBId == pieceId
        }
        
        // CRITICAL: Use comprehensive validation
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        if PuzzleValidationRules.isValidPlacement(
            piece: piece,
            withTransform: finalTransform,
            amongPieces: otherPieces,
            maintainingConnection: relevantConnection
        ) {
            // Only show preview if valid
            uiState.ghostTransform = finalTransform
            uiState.showSnapIndicator = true
            uiState.manipulatingPieceId = pieceId
        } else {
            // NO PREVIEW for invalid positions
            uiState.ghostTransform = nil
            uiState.showSnapIndicator = false
        }
        
    default:
        break
    }
}
```

### Phase 2: Fix Preview Validation

#### Fix 2.1: Validate New Piece Preview
**File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel+StateAndUI.swift`

**Lines 216-275** - `updatePreviewIfNeeded` method:
```swift
// Add validation after line 260:
private func updatePreviewIfNeeded() {
    // ... existing code up to line 260 ...
    
    // After placeConnectedPiece call (around line 260):
    if case .success(let placedPiece) = result {
        // CRITICAL: Validate before showing preview
        if PuzzleValidationRules.isValidPlacement(
            piece: placedPiece,
            withTransform: placedPiece.transform,
            amongPieces: puzzle.pieces,
            maintainingConnection: nil  // New piece, no existing connection
        ) {
            uiState.previewPiece = placedPiece
            uiState.previewTransform = placedPiece.transform
        } else {
            // NO PREVIEW for invalid positions
            uiState.previewPiece = nil
            uiState.previewTransform = nil
            // Optionally show error feedback
            toastService.showError("Invalid placement - pieces would overlap")
        }
    }
}
```

### Phase 3: Update Manipulation Service

#### Fix 3.1: Enforce Discrete Snap Points in Service
**File**: `Bemo/Features/Game/Games/TangramEditor/Services/PieceManipulationService.swift`

**Lines 65-66** - Rotation snap angles:
```swift
// Line 65-66, ensure exact values:
let snapAngles = [-180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0]
```

**Lines 130-131** - Edge-to-edge slide positions:
```swift
// Replace lines 130-131:
// Calculate snap positions as exact percentages
let snapPositions: [Double] = [
    0.0,                    // 0% - Start of edge
    maxSlide * 0.25,        // 25%
    maxSlide * 0.5,         // 50% - Middle
    maxSlide * 0.75,        // 75%
    maxSlide                // 100% - End of edge
].filter { $0 >= 0 && $0 <= maxSlide }  // Remove invalid positions
```

**Lines 173-174** - Vertex-to-edge slide positions:
```swift
// Replace lines 173-174:
// Snap at exact percentages along the edge
let edgeLengthDouble = Double(edgeLength)
let snapPositions = [
    0.0,                        // 0% - Start of edge
    edgeLengthDouble * 0.25,    // 25%
    edgeLengthDouble * 0.5,     // 50% - Middle
    edgeLengthDouble * 0.75,    // 75%
    edgeLengthDouble            // 100% - End of edge
]
```

### Phase 4: Add Manipulation State Management

#### Fix 4.1: Track Initial Transform During Manipulation
**File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel.swift`

**After line 60** - Add state tracking:
```swift
// MARK: - Manipulation State
var initialManipulationTransforms: [String: CGAffineTransform] = [:]  // Store initial transform when starting manipulation
```

#### Fix 4.2: Clear Initial Transform on Manipulation End
**File**: `Bemo/Features/Game/Games/TangramEditor/ViewModels/TangramEditorViewModel+PieceOperations.swift`

Add new methods:
```swift
// Add after confirmRotation (around line 360):
func confirmRotation() {
    guard let ghostTransform = uiState.ghostTransform,
          let manipulatingId = uiState.manipulatingPieceId,
          let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == manipulatingId }) else {
        return
    }
    
    // Apply the validated transform
    undoManager.saveState(puzzle: puzzle)
    puzzle.pieces[pieceIndex].transform = ghostTransform
    
    // Clear manipulation state
    uiState.ghostTransform = nil
    uiState.manipulatingPieceId = nil
    uiState.showSnapIndicator = false
    initialManipulationTransforms.removeValue(forKey: manipulatingId)  // Clear initial transform
    
    // Update and validate
    updateManipulationModes()
    validate()
    notifyPuzzleChanged()
}

func confirmSlide() {
    // Same as confirmRotation
    guard let ghostTransform = uiState.ghostTransform,
          let manipulatingId = uiState.manipulatingPieceId,
          let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == manipulatingId }) else {
        return
    }
    
    // Apply the validated transform
    undoManager.saveState(puzzle: puzzle)
    puzzle.pieces[pieceIndex].transform = ghostTransform
    
    // Clear manipulation state
    uiState.ghostTransform = nil
    uiState.manipulatingPieceId = nil
    uiState.showSnapIndicator = false
    initialManipulationTransforms.removeValue(forKey: manipulatingId)  // Clear initial transform
    
    // Update and validate
    updateManipulationModes()
    validate()
    notifyPuzzleChanged()
}

func cancelManipulation() {
    // Clear all manipulation state without applying changes
    if let manipulatingId = uiState.manipulatingPieceId {
        initialManipulationTransforms.removeValue(forKey: manipulatingId)
    }
    uiState.ghostTransform = nil
    uiState.manipulatingPieceId = nil
    uiState.showSnapIndicator = false
}
```

### Phase 5: Enhance Validation Rules

#### Fix 5.1: Implement Proper Edge-to-Edge Validation
**File**: `Bemo/Features/Game/Games/TangramEditor/Services/PuzzleValidationRules.swift`

**Lines 82-93** - Complete edge-to-edge validation:
```swift
static func isEdgeToEdgeConnectionValid(
    pieceA: TangramPiece,
    edgeA: Int,
    pieceB: TangramPiece,
    edgeB: Int
) -> Bool {
    let verticesA = TangramCoordinateSystem.getWorldVertices(for: pieceA)
    let verticesB = TangramCoordinateSystem.getWorldVertices(for: pieceB)
    
    let edgesA = TangramGeometry.edges(for: pieceA.type)
    let edgesB = TangramGeometry.edges(for: pieceB.type)
    
    guard edgeA < edgesA.count, edgeB < edgesB.count else {
        return false
    }
    
    let edgeDefA = edgesA[edgeA]
    let edgeDefB = edgesB[edgeB]
    
    let edgeStartA = verticesA[edgeDefA.startVertex]
    let edgeEndA = verticesA[edgeDefA.endVertex]
    let edgeStartB = verticesB[edgeDefB.startVertex]
    let edgeEndB = verticesB[edgeDefB.endVertex]
    
    // Check if edges are parallel (within tolerance)
    let vectorA = CGVector(dx: edgeEndA.x - edgeStartA.x, dy: edgeEndA.y - edgeStartA.y)
    let vectorB = CGVector(dx: edgeEndB.x - edgeStartB.x, dy: edgeEndB.y - edgeStartB.y)
    
    let lengthA = sqrt(vectorA.dx * vectorA.dx + vectorA.dy * vectorA.dy)
    let lengthB = sqrt(vectorB.dx * vectorB.dx + vectorB.dy * vectorB.dy)
    
    let normalizedA = CGVector(dx: vectorA.dx / lengthA, dy: vectorA.dy / lengthB)
    let normalizedB = CGVector(dx: vectorB.dx / lengthB, dy: vectorB.dy / lengthB)
    
    // Dot product should be -1 (opposite direction) or 1 (same direction) for parallel
    let dotProduct = normalizedA.dx * normalizedB.dx + normalizedA.dy * normalizedB.dy
    let isParallel = abs(abs(dotProduct) - 1.0) < 0.01
    
    if !isParallel {
        return false
    }
    
    // Check if edges are touching (at least one endpoint is close to the other edge)
    let startAToB = isPointOnLineSegment(point: edgeStartA, lineStart: edgeStartB, lineEnd: edgeEndB, tolerance: touchTolerance)
    let endAToB = isPointOnLineSegment(point: edgeEndA, lineStart: edgeStartB, lineEnd: edgeEndB, tolerance: touchTolerance)
    let startBToA = isPointOnLineSegment(point: edgeStartB, lineStart: edgeStartA, lineEnd: edgeEndA, tolerance: touchTolerance)
    let endBToA = isPointOnLineSegment(point: edgeEndB, lineStart: edgeStartA, lineEnd: edgeEndA, tolerance: touchTolerance)
    
    return startAToB || endAToB || startBToA || endBToA
}
```

## Testing Plan

### Test Case 1: Rotation at 45° Increments
1. Place a piece with vertex-to-vertex connection
2. Attempt to rotate to 30° → Should snap to 45°
3. Attempt to rotate to 50° → Should snap to 45°
4. Verify preview only appears at valid 45° positions

### Test Case 2: Sliding at Discrete Positions
1. Place a piece with edge-to-edge connection
2. Attempt to slide to 10% → Should snap to 0% or 25%
3. Attempt to slide to 60% → Should snap to 50% or 75%
4. Verify preview only appears at 0%, 25%, 50%, 75%, 100%

### Test Case 3: No Invalid Previews
1. Attempt to place piece that would overlap
2. Verify NO preview appears
3. Verify error feedback is shown
4. Verify placement is prevented

### Test Case 4: Connection Integrity
1. Place piece with vertex-to-vertex connection
2. Rotate piece → Verify vertex remains at exact connection point
3. Place piece with vertex-to-edge connection
4. Slide piece → Verify vertex stays on edge at snap points
5. Rotate piece → Verify vertex stays on edge during rotation

### Test Case 5: Multi-Connection Pieces
1. Place piece with two connections
2. Verify piece becomes fixed (cannot move)
3. Verify no manipulation handles appear

## Implementation Order

1. **Phase 1**: Enforce discrete snap points (handleRotation, handleSlide)
2. **Phase 2**: Fix preview validation (updatePreviewIfNeeded)
3. **Phase 3**: Update manipulation service snap calculations
4. **Phase 4**: Add manipulation state management
5. **Phase 5**: Enhance validation rules

## Estimated Timeline

- Phase 1: 2 hours (critical path)
- Phase 2: 1 hour (critical path)
- Phase 3: 1 hour
- Phase 4: 1 hour
- Phase 5: 2 hours
- Testing: 2 hours

**Total: 9 hours**

## Success Criteria

1. ✅ Pieces ONLY rotate at 45° increments
2. ✅ Pieces ONLY slide at 0%, 25%, 50%, 75%, 100% positions
3. ✅ Preview NEVER shows invalid positions
4. ✅ Connections are ALWAYS maintained during manipulation
5. ✅ Overlapping pieces are IMPOSSIBLE to create
6. ✅ All validation uses centralized `PuzzleValidationRules`

## Risk Mitigation

- **Risk**: Breaking existing puzzles
- **Mitigation**: Validation only affects new placements, existing puzzles remain valid

- **Risk**: Performance impact from validation
- **Mitigation**: Cache validation results during manipulation

- **Risk**: User confusion from strict constraints
- **Mitigation**: Clear visual feedback showing valid positions

## Notes

- The `ManipulationMode` enum is NOT modified (would break pattern matching)
- Dynamic constraints stored separately in ViewModel
- Initial transform tracking ensures manipulations are relative to starting position
- All changes are surgical - no architectural changes required

---

*Document Version: 2.0*
*Last Updated: [Current Date]*
*Status: Ready for Implementation*