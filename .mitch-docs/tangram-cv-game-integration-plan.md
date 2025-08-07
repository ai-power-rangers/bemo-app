# Tangram CV-Game Integration Plan

## Executive Summary

This plan outlines the integration of computer vision (CV) data with the Tangram game system. After analyzing both the CV output format and the existing puzzle data structure, **the systems are compatible** with proper transformation and validation logic. The key is leveraging **relative positioning from dynamic anchor pieces** to handle coordinate system differences.

## System Compatibility Assessment ✅

### Current Architecture Strengths
1. **Relative positioning already implemented** in `PlacedPiece` and `TangramGameViewModel`
2. **Dynamic anchor selection** handles piece removal/addition gracefully  
3. **Validation framework exists** in `GamePuzzleData.TargetPiece.matches()`
4. **Piece type mapping** straightforward between CV class_id and `TangramPieceType`
5. **Database loading infrastructure** via `TangramDatabaseLoader` and `PuzzleDataConverter`
6. **CV processing pipeline** partially exists with `processCVInput()` and `processMockCVInput()`

### Data Format Alignment

| CV Provides | Game Uses | Mapping Strategy |
|------------|-----------|------------------|
| `class_id` (0-6) | `TangramPieceType` enum | Direct mapping table |
| `pose.translation` [x,y] | `CGAffineTransform.tx/ty` | Relative position from anchor |
| `pose.rotation_degrees` | Transform matrix (a,b,c,d) | Convert degrees to radians, build matrix |
| `vertices` array | Calculated from type+transform | Use for validation refinement |
| `homography` matrix | N/A | Apply for coordinate transformation |

## Implementation Plan

### Phase 1: CV Data Processing Service (2 days)

#### 1.1 Create `CVDataProcessor` Service

```swift
// Location: Bemo/Features/Game/Games/Tangram/Services/CVDataProcessor.swift

import Foundation
import CoreGraphics

class CVDataProcessor {
    // Map CV class_id to TangramPieceType
    private let pieceTypeMapping: [Int: TangramPieceType] = [
        0: .parallelogram,
        1: .square,
        2: .largeTriangle1,
        3: .largeTriangle2,
        4: .mediumTriangle,
        5: .smallTriangle1,
        6: .smallTriangle2
    ]
    
    // Map CV name to TangramPieceType (backup mapping)
    private let nameMapping: [String: TangramPieceType] = [
        "tangram_parallelogram": .parallelogram,
        "tangram_square": .square,
        "tangram_triangle_lrg": .largeTriangle1,
        "tangram_triangle_lrg2": .largeTriangle2,
        "tangram_triangle_med": .mediumTriangle,
        "tangram_triangle_sml": .smallTriangle1,
        "tangram_triangle_sml2": .smallTriangle2
    ]
    
    func processCVData(_ cvData: [String: Any]) -> [RecognizedPiece] {
        guard let objects = cvData["objects"] as? [[String: Any]] else {
            return []
        }
        
        let homography = cvData["homography"] as? [[Double]] ?? identityMatrix()
        let scale = cvData["scale"] as? Double ?? 2.819
        
        return objects.compactMap { object in
            parseObject(object, homography: homography, scale: scale)
        }
    }
    
    private func parseObject(_ object: [String: Any], homography: [[Double]], scale: Double) -> RecognizedPiece? {
        // Extract fields
        guard let classId = object["class_id"] as? Int,
              let pose = object["pose"] as? [String: Any],
              let rotation = pose["rotation_degrees"] as? Double,
              let translation = pose["translation"] as? [Double],
              translation.count >= 2,
              let pieceType = pieceTypeMapping[classId] else {
            return nil
        }
        
        // Apply coordinate transformation
        let transformedPoint = applyHomography(translation, homography)
        let gamePoint = convertToGameSpace(transformedPoint)
        
        return RecognizedPiece(
            id: "cv_\(classId)_\(UUID().uuidString.prefix(8))",
            pieceTypeId: pieceType.rawValue,
            position: gamePoint,
            rotation: rotation,
            velocity: CGVector(dx: 0, dy: 0),
            isMoving: false,
            confidence: 0.95, // CV doesn't provide confidence, use high default
            timestamp: Date(),
            frameNumber: 0
        )
    }
}
```

#### 1.2 Enhance `PlacedPiece` Model

Update the existing `PlacedPiece` to better handle CV data:
- Add `cvConfidence` property from CV model
- Add `rawVertices` for precise validation
- Enhance `matches()` method to use vertex-based validation

### Phase 2: Coordinate System Transformation (2 days)

#### 2.1 Implement Homography Transform

```swift
// Location: Bemo/Features/Game/Games/Tangram/Services/CoordinateTransformer.swift

struct CoordinateTransformer {
    let homography: [[Double]]
    let cvScale: Double
    let canvasSize: CGSize
    
    func transformCVToGameSpace(_ cvPoint: [Double]) -> CGPoint {
        // Apply homography
        // Scale conversion (CV scale 2.819 → game visualScale 50)
        // Coordinate system flip if needed
    }
}
```

#### 2.2 Relative Position Calculator

Enhance existing relative position logic:
- Use CV confidence scores for anchor selection
- Prefer stable pieces (low velocity) as anchors
- Handle coordinate space differences

### Phase 3: Enhanced Validation System (3 days)

#### 3.1 Enhance `GamePuzzleData.TargetPiece.matches()`

The current `matches()` method exists but needs enhancement for relative validation:

```swift
extension GamePuzzleData.TargetPiece {
    // Current method - uses absolute positions
    func matches(_ placed: PlacedPiece) -> Bool { ... }
    
    // Add new relative validation method
    func matchesRelative(
        _ placed: PlacedPiece, 
        relativeTo anchor: PlacedPiece?,
        anchorTarget: TargetPiece?,
        tolerance: ValidationTolerance
    ) -> Bool {
        guard let anchor = anchor, let anchorTarget = anchorTarget else {
            // Fallback to absolute matching if no anchor
            return matches(placed)
        }
        
        // Calculate relative positions
        let placedRelative = placed.calculateRelativePosition(to: anchor)
        let placedRelativeRot = placed.calculateRelativeRotation(to: anchor)
        
        // Extract target relative position from transforms
        let targetRelative = CGPoint(
            x: self.transform.tx - anchorTarget.transform.tx,
            y: self.transform.ty - anchorTarget.transform.ty
        )
        let targetRelativeRot = extractRotation(self.transform) - extractRotation(anchorTarget.transform)
        
        // Validate with tolerances
        let positionDiff = hypot(
            placedRelative.x - targetRelative.x,
            placedRelative.y - targetRelative.y
        )
        let rotationDiff = abs(normalizeAngle(placedRelativeRot - targetRelativeRot))
        
        return positionDiff <= tolerance.position && rotationDiff <= tolerance.rotation
    }
}
```

#### 3.2 Create Tolerance Configuration

```swift
struct ValidationTolerance {
    let position: CGFloat  // In pixels
    let rotation: Double   // In degrees
    
    static let easy = ValidationTolerance(position: 20, rotation: 15)
    static let medium = ValidationTolerance(position: 10, rotation: 7)
    static let hard = ValidationTolerance(position: 5, rotation: 3)
}
```

### Phase 4: Game Integration (2 days)

#### 4.1 Update `TangramGameViewModel`

The ViewModel already has CV processing infrastructure. Enhance the existing methods:

```swift
// Current method signature - processes PlacedPiece array
func processCVInput(_ pieces: [PlacedPiece]) { ... }

// Add new method to handle raw CV data
func processCVData(_ cvData: [String: Any]) -> PlayerActionOutcome {
    // Use CVDataProcessor to convert data
    let recognizedPieces = cvDataProcessor.processCVData(cvData)
    
    // Convert to PlacedPiece objects
    let placedPieces = recognizedPieces.map { PlacedPiece(from: $0) }
    
    // Use existing processCVInput method
    processCVInput(placedPieces)
    
    // Return appropriate outcome for Game protocol
    return determineOutcome(placedPieces)
}
```

#### 4.2 Real-time Processing Optimization

- Debounce CV updates (100ms minimum between updates)
- Cache transformation matrices
- Early exit validation for obvious mismatches

### Phase 5: Testing & Calibration (2 days)

#### 5.1 CV Mock Data Generator

Create realistic test data from existing puzzles:

```swift
// Location: Bemo/Features/Game/Games/Tangram/Testing/CVMockDataGenerator.swift

func generateMockCVData(from puzzle: GamePuzzleData, noise: NoiseLevel) -> [String: Any] {
    // Convert puzzle pieces to CV format
    // Add configurable noise for testing
    // Include realistic homography matrix
}
```

#### 5.2 Calibration Tools

- Scale calibration using known piece dimensions
- Tolerance tuning based on real-world testing
- Performance profiling and optimization

## Key Implementation Details

### Anchor Selection Algorithm

```swift
// Already exists in TangramGameViewModel, enhance with:
private func selectNewAnchor() {
    anchorPiece = placedPieces
        .filter { $0.confidence > 0.8 }  // High confidence only
        .filter { !$0.isMoving }          // Stationary pieces
        .sorted { p1, p2 in
            // Priority order:
            // 1. Larger pieces (more stable reference)
            if p1.area != p2.area { return p1.area > p2.area }
            // 2. Closer to center (less edge distortion)
            if p1.distanceFromCenter != p2.distanceFromCenter {
                return p1.distanceFromCenter < p2.distanceFromCenter
            }
            // 3. Higher CV confidence
            return p1.confidence > p2.confidence
        }
        .first
}
```

### Relative Position Validation

```swift
func validateRelativePosition(
    placed: PlacedPiece,
    target: GamePuzzleData.TargetPiece,
    anchor: PlacedPiece,
    anchorTarget: GamePuzzleData.TargetPiece
) -> Bool {
    // Calculate relative positions
    let placedRelative = placed.calculateRelativePosition(to: anchor)
    let targetRelative = calculateTargetRelative(target, anchorTarget)
    
    // Compare with tolerance
    let distance = hypot(
        placedRelative.x - targetRelative.x,
        placedRelative.y - targetRelative.y
    )
    
    return distance <= currentTolerance.position
}
```

### Handling Edge Cases

1. **Missing Pieces**: Continue with available pieces
2. **Piece Removal**: Automatic anchor switching
3. **Rapid Movement**: Debounce and stability checks
4. **Symmetry**: Handle rotation ambiguities for square and triangles
5. **Scale Drift**: Dynamic calibration from known pieces

## Migration Path

### Step 1: Non-Breaking Additions
- Add CV services without modifying existing game flow
- Create parallel validation path for testing

### Step 2: Integration Testing
- Use mock CV data in development
- A/B test CV validation vs current touch-based system

### Step 3: Production Rollout
- Feature flag for CV mode
- Gradual rollout with monitoring
- Fallback to touch mode if CV unavailable

## Performance Targets

- **CV Processing**: < 50ms per frame
- **Validation**: < 10ms per piece set
- **UI Update**: Maintain 60 FPS
- **Memory**: < 10MB additional for CV processing

## Risk Mitigation

### Technical Risks
1. **Coordinate transformation errors**
   - Mitigation: Extensive unit tests with known transforms
   - Fallback: Use relative positions only

2. **Performance degradation**
   - Mitigation: Profiling and optimization
   - Fallback: Reduce validation frequency

3. **CV noise/errors**
   - Mitigation: Confidence thresholds, smoothing
   - Fallback: Require multiple consistent frames

### UX Risks
1. **False negatives** (correct pieces marked wrong)
   - Mitigation: Generous initial tolerances
   - Solution: Dynamic tolerance adjustment

2. **Delayed feedback**
   - Mitigation: Optimistic UI updates
   - Solution: Show pending state during validation

## Success Metrics

1. **Accuracy**: 95%+ correct validation rate
2. **Latency**: < 100ms from CV input to UI update
3. **Stability**: < 1% anchor switching frequency
4. **Completion**: 90%+ puzzle completion rate

## Timeline

**Total: 11 days**

- Days 1-2: CV Data Processing Service
- Days 3-4: Coordinate Transformation
- Days 5-7: Enhanced Validation System
- Days 8-9: Game Integration
- Days 10-11: Testing & Calibration

## Next Steps

1. ✅ Review and approve plan
2. Create feature branch `feature/tangram-cv-integration`
3. Implement `CVDataProcessor` service
4. Set up mock CV data generator for testing
5. Begin coordinate transformation implementation

## Appendix: File Structure

### Existing Files to Modify
- `Bemo/Features/Game/Games/Tangram/Models/PlacedPiece.swift` - Add CV-specific fields
- `Bemo/Features/Game/Games/Tangram/Models/GamePuzzleData.swift` - Add relative validation
- `Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift` - Enhance CV processing
- `Bemo/Features/Game/Games/Tangram/Services/PuzzleDataConverter.swift` - Handle CV format

### New Files to Create
- `Bemo/Features/Game/Games/Tangram/Services/CVDataProcessor.swift` - CV to game conversion
- `Bemo/Features/Game/Games/Tangram/Services/CoordinateTransformer.swift` - Coordinate math
- `Bemo/Features/Game/Games/Tangram/Models/ValidationTolerance.swift` - Tolerance config
- `Bemo/Features/Game/Games/Tangram/Testing/CVMockDataGenerator.swift` - Test data generation

## Conclusion

The CV and game systems are **fully compatible** with the proper transformation pipeline. The existing codebase's relative positioning approach and dynamic anchor system provide a robust foundation for CV integration. The key to success is maintaining the relative position validation approach while properly transforming CV coordinates into game space.

The implementation can proceed incrementally without breaking existing functionality, allowing for thorough testing at each phase.