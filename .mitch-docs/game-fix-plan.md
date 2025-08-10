# Tangram Game Fix Plan - Updated Implementation Strategy

## Current Status
- ✅ Basic PoseMapper created with rotation/position conversions
- ❌ Target pieces still scattered due to incorrect centroid handling
- ✅ Validation and hints updated to use PoseMapper
- ⚠️ Need to fix core rendering issue

## Root Cause Analysis
The migration broke target rendering because:
1. Current code extracts `tx, ty` directly from transform (origin position)
2. But we need where the **centroid** ends up after rotation
3. The CV game works because it applies full transforms to vertices first

## PHASE 1: Fix Tangram Game (Priority)

### Step 1: Enhance PoseMapper with Centroid Support

**File:** `Bemo/Features/Game/Games/Tangram/Utilities/TangramPoseMapper.swift`

Add these critical functions:
```swift
// Calculate local centroid for any piece type
static func pieceLocalCentroid(for pieceType: TangramPieceType) -> CGPoint {
    let vertices = TangramGameGeometry.normalizedVertices(for: pieceType)
    let scaled = TangramGameGeometry.scaleVertices(vertices, by: TangramGameConstants.visualScale)
    return TangramGameGeometry.centerOfVertices(scaled)
}

// Convert raw centroid to SpriteKit position
static func toSpriteKit(centroidRaw: CGPoint) -> CGPoint {
    return CGPoint(x: centroidRaw.x, y: -centroidRaw.y)
}

// Convert raw angle to SpriteKit rotation
static func toSpriteKit(angleRaw: CGFloat) -> CGFloat {
    return -angleRaw
}
```

### Step 2: Fix Target Piece Rendering (CRITICAL)

**File:** `Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift`
**Function:** `createTargetPiece(_:)`

Replace entire implementation:
```swift
private func createTargetPiece(_ target: GamePuzzleData.TargetPiece, puzzleBounds: CGRect, scale: CGFloat) {
    // 1. Get scaled vertices centered at local centroid
    let normalizedVertices = TangramGameGeometry.normalizedVertices(for: target.pieceType)
    let scaledVertices = TangramGameGeometry.scaleVertices(normalizedVertices, by: TangramGameConstants.visualScale)
    let localCentroid = TangramGameGeometry.centerOfVertices(scaledVertices)
    
    // 2. Build path centered at origin (like PuzzlePieceNode does)
    let path = UIBezierPath()
    let centeredVertices = scaledVertices.map { CGPoint(x: $0.x - localCentroid.x, y: $0.y - localCentroid.y) }
    
    if let firstVertex = centeredVertices.first {
        path.move(to: firstVertex)
        for vertex in centeredVertices.dropFirst() {
            path.addLine(to: vertex)
        }
        path.close()
    }
    
    // 3. Create shape node
    let shape = SKShapeNode(path: path.cgPath)
    shape.fillColor = SKColor.systemGray
    shape.alpha = targetAlpha
    shape.strokeColor = SKColor.darkGray
    shape.lineWidth = 1.0
    shape.name = "target_\(target.pieceType.rawValue)"
    
    // 4. Apply transform to centroid to get world position
    let worldCentroidRaw = localCentroid.applying(target.transform)
    
    // 5. Convert to SpriteKit and set pose
    shape.position = TangramPoseMapper.toSpriteKit(centroidRaw: worldCentroidRaw)
    shape.zRotation = TangramPoseMapper.toSpriteKit(angleRaw: TangramPoseMapper.rawAngle(from: target.transform))
    
    // 6. Store SK position for validation
    shape.userData = ["centerX": shape.position.x, "centerY": shape.position.y]
    
    targetPieces[target.pieceType.rawValue] = shape
    puzzleLayer.addChild(shape)
}
```

### Step 3: Verify Movable Pieces Consistency

**File:** `Bemo/Features/Game/Games/Tangram/Views/Components/PuzzlePieceNode.swift`

Verify that:
- Path is centered at centroid ✓ (already done)
- No extra transforms applied
- Uses same centroid calculation as targets

### Step 4: Add Stable IDs for CV Readiness

When creating pieces and targets, add:
```swift
shape.userData = [
    "pieceID": target.pieceType.rawValue,
    "dbID": target.id ?? UUID().uuidString
]
```

### Step 5: Document Conventions

Add to `TangramPoseMapper.swift` header:
```swift
/// Coordinate Conventions:
/// - Raw angle: 0° = right, positive = CCW (math convention)
/// - SK angle: 0° = right, positive = CW (negated from raw)
/// - Raw position: Y-down (screen convention)
/// - SK position: Y-up (negated Y from raw)
/// - All rotations happen around piece centroids
```

## PHASE 2: CV Game Migration (Later)

Once Tangram game is fixed and stable:
1. Copy enhanced PoseMapper to CV game
2. Update TangramThreeZoneScene to use same approach
3. Ensure consistent ID tagging

## Success Criteria

### Immediate (Tangram Game):
- ✅ Target pieces display as correctly composed puzzle
- ✅ Movable pieces match target geometry exactly
- ✅ Validation works with correct rotation/position
- ✅ Hints align properly

### Future (CV Ready):
- ✅ Can process: `{id: "piece1", rotation: 45, translation: [100, 200]}`
- ✅ Renders identically to current targets
- ✅ Single conversion path: CV → Raw → PoseMapper → Render

## Implementation Checklist

- [ ] Update TangramPoseMapper with centroid functions
- [ ] Fix createTargetPiece with centroid-based approach
- [ ] Test with multiple puzzles (cat, house, etc.)
- [ ] Verify validation still works
- [ ] Add stable IDs to all nodes
- [ ] Document conventions
- [ ] Clean up old code/comments

## Why This Works

1. **Preserves Geometry**: Transform applied to same reference point (centroid)
2. **Matches CV Format**: ID + angle + translation (no vertex transforms)
3. **Consistent**: Same approach for targets and movable pieces
4. **Simple**: One conversion point, no scattered sign flips

## Files to Modify

1. `Bemo/Features/Game/Games/Tangram/Utilities/TangramPoseMapper.swift` - Add centroid support
2. `Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift` - Fix createTargetPiece
3. `Bemo/Features/Game/Games/Tangram/Views/Components/PuzzlePieceNode.swift` - Verify consistency
4. Various files - Add stable IDs where pieces created

## Testing Steps

1. Load cat puzzle - should see complete cat silhouette
2. Load house puzzle - should see complete house
3. Drag piece to target - should snap correctly
4. Rotate piece - should validate at correct angles
5. Check hints - should show correct positions

---

**Note**: This plan focuses on fixing Tangram game first. CV game continues working with its current method until we're ready to migrate it.