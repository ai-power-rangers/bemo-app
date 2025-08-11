# Tangram Game Math & Validation System

## Executive Summary

This document serves as the canonical reference for the Tangram game's mathematical foundation, validation system, and coordinate transformations. The system handles piece placement validation using a feature-angle approach with different canonical angles for pieces versus targets to bridge the editor and runtime coordinate systems.

## Core Concepts

### 1. Coordinate Systems

#### Editor/Database Space (Raw)
- **Origin**: Top-left
- **Y-axis**: Positive downward (screen convention)
- **Rotation**: 0° = right, positive = counter-clockwise (CCW)
- **Storage**: CGAffineTransform with components (a, b, c, d, tx, ty)

#### SpriteKit Space (Runtime)
- **Origin**: Bottom-left  
- **Y-axis**: Positive upward (math convention)
- **Rotation**: 0° = right, positive = clockwise (CW) 
- **zRotation**: Clockwise rotation in radians

#### Conversion Rules
```swift
// Position conversion
spriteKitPos.x = rawPos.x
spriteKitPos.y = -rawPos.y  // Y-flip

// Angle conversion  
spriteKitAngle = -rawAngle  // Sign flip for CW
```

### 2. Feature Angle System

The validation system uses "feature angles" - the angle at which a distinctive feature of the piece points. For triangles, this is the hypotenuse direction.

#### Key Insight: Different Canonical Angles
- **Piece Canonical**: 135° (3π/4 rad) - The actual hypotenuse direction when piece is at zRotation=0
- **Target Canonical**: 45° (π/4 rad) - The editor's reference frame for transforms

This 90° difference bridges the gap between how pieces are created in the editor versus how they're rendered at runtime.

## Mathematical Foundations

### Transform Extraction

From a CGAffineTransform matrix:
```
[a  b  tx]
[c  d  ty]
[0  0  1 ]
```

Extract rotation and position:
```swift
rawAngle = atan2(b, a)  // Rotation in radians
rawPosition = CGPoint(x: tx, y: ty)
```

### Feature Angle Computation

#### For Target Pieces
```swift
// 1. Extract rotation from transform
rawAngle = atan2(transform.b, transform.a)
expectedZRotationSK = -rawAngle  // Y-flip for SpriteKit

// 2. Add canonical for editor reference frame
targetFeatureAngle = normalize(canonicalTarget + expectedZRotationSK)
// where canonicalTarget = 45° for triangles
```

#### For Movable Pieces  
```swift
// 1. Use actual geometric canonical
localFeatureAngle = canonicalPiece  // 135° for triangles

// 2. Adjust for flip if needed
if isFlipped {
    localFeatureAngle = -localFeatureAngle
}

// 3. Compute current feature angle
pieceFeatureAngle = normalize(piece.zRotation + localFeatureAngle)
```

### Validation Logic

#### Position Validation
```swift
distance = hypot(piecePos.x - targetPos.x, piecePos.y - targetPos.y)
positionValid = distance < tolerance  // typically 35 pixels
```

#### Rotation Validation with Symmetry
```swift
// Account for rotational symmetry
symmetryFold = getSymmetryFold(pieceType)
// - Square: 4 (every 90°)
// - Parallelogram: 2 (every 180°) when not flipped
// - Triangles: 1 (no rotational symmetry)

for i in 0..<symmetryFold {
    equivalentAngle = targetFeature + (i * 2π/symmetryFold)
    if abs(normalize(pieceFeature - equivalentAngle)) < tolerance {
        return true
    }
}
```

#### Flip Validation (Parallelogram Only)
```swift
// Check determinant of transform matrix
targetDeterminant = transform.a * transform.d - transform.b * transform.c
targetIsFlipped = determinant < 0
flipValid = (piece.isFlipped == targetIsFlipped)
```

### Snapping

When a piece is close enough to snap:
```swift
// Calculate desired piece rotation
desiredZ = normalize(targetFeatureAngle - localFeatureAngle)
piece.zRotation = desiredZ

// Snap position (convert coordinate spaces)
targetPosScene = puzzleLayer.convert(target.position, to: scene)
snapPos = scene.convert(targetPosScene, to: piecesLayer)
piece.position = snapPos
```

## Piece Geometry

### Standard Tangram Vertices (Normalized)

All pieces defined in a 0-2 coordinate system:

```swift
// Triangles (right triangles)
smallTriangle: [(0,0), (1,0), (0,1)]
mediumTriangle: [(0,0), (√2,0), (0,√2)]
largeTriangle: [(0,0), (2,0), (0,2)]

// Square
square: [(0,0), (1,0), (1,1), (0,1)]

// Parallelogram
parallelogram: [(0,0), (√2,0), (√2/2,√2/2), (-√2/2,√2/2)]
```

### Hypotenuse Direction

For triangles with vertices [(0,0), (2,0), (0,2)]:
- Hypotenuse: from (2,0) to (0,2)
- Direction: atan2(2-0, 0-2) = atan2(2, -2) = 135° (3π/4 rad)

This is why the piece canonical is 135°.

## Implementation Architecture

### Key Classes

1. **TangramPoseMapper**: Centralized coordinate conversion
2. **TangramRotationValidator**: Symmetry-aware rotation validation
3. **TangramPieceValidator**: Main validation orchestrator
4. **TangramGameConstants**: Canonical angle definitions
5. **PuzzlePieceNode**: Piece rendering with local feature tracking
6. **TangramPuzzleScene**: Scene management and interaction

### Data Flow

```
Database Transform
    ↓
TangramPoseMapper (coordinate conversion)
    ↓
Target Creation (baked vertices + feature angle)
    ↓
User Interaction (drag/rotate)
    ↓
Validation (feature angle comparison)
    ↓
Snap or Reject
```

## Critical Implementation Details

### 1. Baked Vertices Approach

Targets use "baked vertices" where the transform is applied directly to the vertices, then rendered at zRotation=0. This ensures visual accuracy while keeping rotation separate for validation.

```swift
// Apply transform to vertices
transformedVertices = vertices.map { vertex in
    CGPoint(
        x: transform.a * vertex.x + transform.c * vertex.y + transform.tx,
        y: transform.b * vertex.x + transform.d * vertex.y + transform.ty
    )
}
// Render at zRotation = 0
```

### 2. Instance-Based Target Tracking

Each piece is bound to a specific target ID (not just type) to handle duplicates:
```swift
piece.userData["assignedTargetId"] = target.id
targetNodesById[target.id] = shapeNode
```

### 3. Rotation Dial UX

The rotation dial tracks touch deltas to avoid jumps:
```swift
// On first touch
initialTouchAngle = atan2(touch.y - center.y, touch.x - center.x)
initialPieceRotation = piece.zRotation

// During drag
angleDelta = currentTouchAngle - initialTouchAngle
piece.zRotation = initialPieceRotation - angleDelta  // Negative for CW
```

## Lessons Learned

### 1. Reference Frame Mismatch
**Problem**: 90° offset between visual alignment and validation.
**Root Cause**: Editor uses different baseline orientation than runtime geometry.
**Solution**: Use different canonical angles (45° for targets, 135° for pieces).

### 2. Vertex-Based Feature Extraction Unreliable
**Problem**: Computing features from transformed vertices gave inconsistent results.
**Root Cause**: Vertex ordering and edge selection heuristics can change after transformation.
**Solution**: Use fixed canonical angles + rotation from transform.

### 3. Mixed Validation Paths
**Problem**: Multiple validation methods with different angle computations.
**Root Cause**: Technical debt from iterative development.
**Solution**: Single validation path using feature angles exclusively.

### 4. Touch Interaction Disconnect
**Problem**: Rotation dial would jump when touched.
**Root Cause**: Direct angle assignment instead of tracking deltas.
**Solution**: Track initial touch and apply relative changes.

## Must-Haves for Future Changes

1. **Preserve Canonical Angles**: The 45°/135° split is fundamental to the system
2. **Maintain Coordinate Conversions**: Always use TangramPoseMapper for consistency
3. **Keep Feature-Based Validation**: Don't mix raw angles with feature angles
4. **Instance-Based Tracking**: Essential for handling duplicate piece types
5. **Baked Vertices for Targets**: Ensures visual accuracy

## Common Pitfalls to Avoid

1. **Don't compute features from transformed vertices** - Use canonical + rotation
2. **Don't use raw angles in validation** - Always use feature angles
3. **Don't forget coordinate space conversions** - Scene vs layer spaces matter
4. **Don't assume piece type uniqueness** - Use target IDs
5. **Don't mix validation approaches** - Stick to one consistent system

## Testing Checklist

- [ ] All 7 pieces validate when visually aligned
- [ ] Triangles (including duplicates) snap correctly
- [ ] Square validates at 0°, 90°, 180°, 270°
- [ ] Parallelogram flip detection works
- [ ] Rotation dial follows finger smoothly
- [ ] Hints show correct target orientation
- [ ] Auto-rotation snaps within threshold
- [ ] Pieces maintain state after rotation/flip

## Mathematical Constants

```swift
// Canonical Feature Angles
TRIANGLE_PIECE_CANONICAL = 3π/4 (135°)  // Actual hypotenuse direction
TRIANGLE_TARGET_CANONICAL = π/4 (45°)    // Editor reference frame
SQUARE_CANONICAL = 0
PARALLELOGRAM_CANONICAL = 0

// Validation Tolerances
POSITION_TOLERANCE = 35 pixels
ROTATION_TOLERANCE = 25° (0.44 radians)

// Visual Scale
NORMALIZED_TO_VISUAL = 50 (pixels per unit)
```

## Debugging Guide

### When pieces don't validate:
1. Check feature angles in logs - piece and target should match when aligned
2. Verify canonical angles are correct (135° for piece, 45° for target)
3. Ensure coordinate space conversions are applied
4. Check if symmetry is being considered

### Common log patterns:
```
// Correct validation
pieceFeature=-135°, targetFeature=-135°, rotOK=true ✓

// 90° offset (wrong canonical)
pieceFeature=-45°, targetFeature=-135°, rotOK=false ✗

// 180° offset (sign error)
pieceFeature=135°, targetFeature=-135°, rotOK=false ✗
```

## Future Improvements

1. **Dynamic Canonical Detection**: Auto-detect editor baseline from first successful placement
2. **Visual Debugging Mode**: Overlay showing feature angles and validation zones
3. **Configurable Tolerances**: Per-difficulty or per-piece tolerance settings
4. **Alternative Input Methods**: Gesture-based rotation, keyboard controls
5. **CV Integration**: Unified validation for both touch and computer vision input

---

*This document represents the accumulated knowledge from implementing and debugging the Tangram validation system. It should be treated as the single source of truth for understanding the mathematical foundations and implementation details.*