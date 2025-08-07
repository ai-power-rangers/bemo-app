# Computer Vision Output Format Explainer

## Overview
This document explains the CV (Computer Vision) model output format for Tangram piece detection, how it compares to the Tangram Editor's database format, and how these two systems integrate for real-time puzzle validation.

## CV Output Structure

The CV model outputs a JSON structure with detected Tangram pieces in a real-world coordinate system:

```json
{
  "homography": [[3x3 matrix]],     // Plane-to-camera transformation
  "scale": 2.8190987423182827,      // CV coordinate scale factor
  "objects": [                      // Array of detected pieces
    {
      "name": "tangram_parallelogram",
      "class_id": 0,
      "pose": {
        "rotation_degrees": 34.98,
        "translation": [734.56, -211.27]
      },
      "vertices": [[x,y], [x,y], ...]
    }
  ]
}
```

## Field Definitions

### Top-Level Fields

| Field | Type | Description |
|-------|------|-------------|
| `homography` | 3x3 matrix | Transformation matrix for perspective correction from physical plane to camera view |
| `scale` | float | Scale factor for CV coordinates (typically ~2.819) |
| `objects` | array | List of detected Tangram pieces |

### Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | CV model's piece identifier (e.g., "tangram_square") |
| `class_id` | int (0-6) | Numeric identifier for piece type |
| `pose.rotation_degrees` | float | Rotation angle in degrees (0-360) |
| `pose.translation` | [x, y] | Center position in CV coordinate space |
| `vertices` | array of [x,y] | Exact corner points of the detected piece |

## Piece Type Mapping

### CV to Game Mapping Table

| CV class_id | CV name | TangramPieceType (Game) | Area (units²) |
|-------------|---------|-------------------------|---------------|
| 0 | tangram_parallelogram | `.parallelogram` | 1.0 |
| 1 | tangram_square | `.square` | 1.0 |
| 2 | tangram_triangle_lrg | `.largeTriangle1` | 2.0 |
| 3 | tangram_triangle_lrg2 | `.largeTriangle2` | 2.0 |
| 4 | tangram_triangle_med | `.mediumTriangle` | 1.0 |
| 5 | tangram_triangle_sml | `.smallTriangle1` | 0.5 |
| 6 | tangram_triangle_sml2 | `.smallTriangle2` | 0.5 |

## Coordinate System Comparison

### CV Coordinate System
- **Origin**: Arbitrary point on physical plane
- **Y-axis**: Can be negative (camera-relative)
- **Scale**: Uses CV scale factor (~2.819)
- **Units**: Camera pixels after homography transform

### Editor/Game Coordinate System
- **Origin**: Top-left corner (0,0)
- **Y-axis**: Positive downward (screen coordinates)
- **Scale**: visualScale = 50 (normalized 0-2 → visual 0-100)
- **Units**: Screen pixels

### Coordinate Transformation Pipeline
```
Physical Piece → Camera View → CV Detection → Homography Transform → Game Space
```

## Data Format Comparison

### CV Output Format
```json
{
  "name": "tangram_square",
  "class_id": 1,
  "pose": {
    "rotation_degrees": -170.17,
    "translation": [339.58, -107.48]
  },
  "vertices": [
    [371.47, -158.78],
    [282.65, -221.37],
    [346.37, -311.80],
    [435.19, -249.22]
  ]
}
```

### Editor Database Format
```json
{
  "type": "square",
  "transform": {
    "a": 0.985,    // cos(rotation)
    "b": -0.174,   // sin(rotation)
    "c": 0.174,    // -sin(rotation)
    "d": 0.985,    // cos(rotation)
    "tx": 339.58,  // x translation
    "ty": 107.48   // y translation (positive)
  },
  "isLocked": true,
  "zIndex": 0
}
```

### Key Differences

| Aspect | CV Output | Editor Database |
|--------|-----------|-----------------|
| **Piece ID** | `name` + `class_id` | `type` enum string |
| **Position** | Separate `translation` array | Embedded in transform matrix (`tx`, `ty`) |
| **Rotation** | Explicit `rotation_degrees` | Encoded in transform matrix (a,b,c,d) |
| **Vertices** | Provided explicitly | Calculated from type + transform |
| **Coordinate Space** | Camera-relative, may have negative Y | Screen space, positive Y down |

## Integration Strategy

### 1. Relative Positioning Approach

Instead of trying to match absolute coordinates, we use **relative positions from an anchor piece**:

```swift
// Pseudocode for relative position calculation
anchorPiece = selectLargestOrMostCentralPiece(detectedPieces)

for each piece in detectedPieces {
    relativePosition = piece.position - anchorPiece.position
    relativeRotation = piece.rotation - anchorPiece.rotation
    
    // Compare relative positions to puzzle solution
    validateRelativePosition(relativePosition, puzzleSolution)
}
```

### 2. Why Relative Positioning Works

- **Coordinate Independence**: Works regardless of CV coordinate origin
- **Scale Invariance**: Relative distances scale proportionally
- **Rotation Invariance**: Can handle entire puzzle rotation
- **Robust to Drift**: Anchor switching handles piece removal/addition

### 3. Anchor Selection Priority

1. **Largest pieces first** (largeTriangle1/2 → 2.0 area units)
2. **Most central position** (closest to average position)
3. **Highest confidence** (from CV model)
4. **Most stable** (lowest velocity)

## Validation Process

### Step-by-Step Flow

1. **CV Detection**
   ```json
   // Raw CV output with negative Y values
   "translation": [734.56, -211.27]
   ```

2. **Homography Application**
   ```swift
   // Apply 3x3 homography matrix
   transformedPoint = applyHomography(cvPoint, homographyMatrix)
   ```

3. **Coordinate Conversion**
   ```swift
   // Convert to game space (flip Y if needed)
   gamePoint = CGPoint(
       x: transformedPoint.x,
       y: canvasHeight + transformedPoint.y  // Handle negative Y
   )
   ```

4. **Anchor Selection**
   ```swift
   // Choose most reliable piece as reference
   anchor = pieces.filter { $0.type == .largeTriangle1 }.first
           ?? pieces.sorted { $0.area > $1.area }.first
   ```

5. **Relative Position Calculation**
   ```swift
   // Calculate positions relative to anchor
   relativePos = CGPoint(
       x: piece.position.x - anchor.position.x,
       y: piece.position.y - anchor.position.y
   )
   relativeRot = piece.rotation - anchor.rotation
   ```

6. **Validation Against Solution**
   ```swift
   // Compare with stored puzzle solution
   isCorrect = abs(relativePos.x - targetRelative.x) < tolerance &&
               abs(relativePos.y - targetRelative.y) < tolerance &&
               abs(relativeRot - targetRotation) < rotationTolerance
   ```

## Tolerance Configuration

### Position Tolerances (pixels)
- **Easy Mode**: ±20 pixels
- **Medium Mode**: ±10 pixels  
- **Hard Mode**: ±5 pixels

### Rotation Tolerances (degrees)
- **Easy Mode**: ±15°
- **Medium Mode**: ±7°
- **Hard Mode**: ±3°

### Special Cases
- **Square**: 90° rotation symmetry (0°, 90°, 180°, 270° are equivalent)
- **Triangles**: Some positions may have 180° symmetry
- **Parallelogram**: Can be flipped (requires special handling)

## Real-World Considerations

### CV Detection Challenges
1. **Lighting variations** - Pieces may not be detected consistently
2. **Occlusion** - Hands or objects blocking pieces
3. **Motion blur** - Moving pieces have uncertain positions
4. **Similar pieces** - Two small triangles can be confused

### Mitigation Strategies
1. **Confidence thresholds** - Ignore low-confidence detections
2. **Temporal smoothing** - Average positions over multiple frames
3. **Stability requirements** - Piece must be stationary for 0.5s
4. **Redundant validation** - Multiple consistent frames required

## Example: Complete Detection Cycle

### 1. CV Detects Pieces
```json
{
  "objects": [
    {
      "name": "tangram_square",
      "class_id": 1,
      "pose": {
        "rotation_degrees": 45,
        "translation": [300, -200]
      }
    },
    {
      "name": "tangram_triangle_lrg",
      "class_id": 2,
      "pose": {
        "rotation_degrees": 90,
        "translation": [350, -250]
      }
    }
  ]
}
```

### 2. Game Processes Detection
```swift
// Select large triangle as anchor (larger piece)
anchor = largeTriangle

// Square relative to anchor:
relativePosition = (300-350, -200-(-250)) = (-50, 50)
relativeRotation = 45 - 90 = -45°
```

### 3. Compare to Puzzle Solution
```swift
// Puzzle solution (relative positions from large triangle)
expectedSquareRelative = (-48, 52)  // Close to (-50, 50)
expectedSquareRotation = -45°       // Matches exactly

// Validation result: ✅ Correct placement
```

## Testing with Mock Data

### Generate Test CV Output
```swift
func generateMockCVData(puzzle: GamePuzzleData) -> [String: Any] {
    return [
        "homography": identityMatrix(),
        "scale": 2.819,
        "objects": puzzle.targetPieces.map { piece in
            [
                "name": mapPieceTypeToCV(piece.pieceType),
                "class_id": piece.pieceType.cvClassId,
                "pose": [
                    "rotation_degrees": extractRotation(piece.transform),
                    "translation": [piece.transform.tx, -piece.transform.ty]
                ],
                "vertices": calculateVertices(piece)
            ]
        }
    ]
}
```

## Summary

The CV output and Editor database formats are **fully compatible** through:

1. **Type mapping** - Simple lookup table between class_id and piece types
2. **Relative positioning** - Eliminates coordinate system dependencies
3. **Dynamic anchoring** - Handles piece addition/removal gracefully
4. **Configurable tolerances** - Accommodates real-world imperfection

The key insight is that while absolute coordinates differ, the **relative spatial relationships** between pieces remain constant, enabling robust puzzle validation regardless of coordinate system differences.