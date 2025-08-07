# Tangram Game Mock CV Implementation Plan

## Executive Summary

This plan outlines the implementation of a comprehensive mock Computer Vision (CV) system for the Tangram game to create a realistic gameplay experience that matches the expected real CV integration. The current implementation uses simplified touch interactions and SpriteKit's snapping mechanics, which need to be replaced with a coordinate-based system that mirrors how actual CV will work.

## Current Implementation Assessment

### What's Already Built ✅

1. **Self-Contained Game Architecture**
   - Complete independence from TangramEditor
   - Database integration with real puzzles (cat, rocket ship)
   - Proper coordinate system with vertex-based rendering
   - SpriteKit integration with touch handling

2. **Coordinate System Architecture**
   - 3-tier system: Normalized (0-2) → Visual (0-100) → World (screen pixels)
   - Proper CGAffineTransform handling for piece positioning
   - Accurate vertex transformation pipeline

3. **Data Models**
   - `PlacedPiece` with CV integration structure
   - `GamePuzzleData` with full transform matrices
   - Validation state tracking (pending/correct/incorrect)
   - Relative positioning logic with anchor piece support

4. **Visual System**
   - SpriteKit scene with proper piece rendering
   - Target silhouette display
   - Celebration effects and animations
   - Hint system overlay

### What Needs to Change ❌

1. **Unrealistic Touch Interactions**
   - Direct touch manipulation of pieces (lines 162-264 in TangramPuzzleScene.swift)
   - Automatic snapping to targets (line 253)
   - Double-tap rotation (line 179)
   - Visual drag feedback (line 192-194)

2. **Artificial Validation Logic**
   - Instant snap-to-target behavior
   - SpriteKit physics overriding realistic positioning
   - Missing CV coordinate tolerance validation

3. **Missing Real-Time Coordinate Display**
   - No coordinate feedback system
   - No CV format position reporting
   - No debug mode for development testing

## Implementation Plan - Pragmatic Approach

### Core Principles
- **Target 30 FPS** to match real CV performance
- **MVP First** - Get basic functionality working before enhancements
- **No over-engineering** - Noise/jitter as future stretch goals
- **Focus on validation logic** - The critical path for CV integration

### Phase 1: Remove Unrealistic Behaviors (Priority: HIGH)

#### 1.1 Simplify Touch-Based Manipulation
**Files to modify:**
- `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift`

**Changes needed:**
```swift
// REMOVE: Automatic snapping (lines 288-314)
// KEEP: Manual drag/rotate for testing
// REMOVE: Snap preview indicators
```

#### 1.2 Keep Manual Controls for Testing
**Rationale:** We need to manually position pieces to test validation
- Keep basic drag and rotation
- Remove only the artificial helpers (snapping, guides)
- Pieces move freely without assistance

### Phase 2: Add CV Format Coordinate Display (Priority: HIGH)

#### 2.1 Simple Coordinate Overlay
**New file:** `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Views/CoordinateDisplayOverlay.swift`

```swift
struct CoordinateDisplayOverlay: View {
    let placedPieces: [PlacedPiece]
    let showDebugInfo: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            if showDebugInfo {
                Text("CV Coordinate Data")
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    ForEach(placedPieces) { piece in
                        CoordinateInfoCard(piece: piece)
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

struct CoordinateInfoCard: View {
    let piece: PlacedPiece
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Piece: \(piece.pieceType.rawValue)")
                .font(.caption.weight(.semibold))
            Text("Position: (\(String(format: "%.1f", piece.position.x)), \(String(format: "%.1f", piece.position.y)))")
                .font(.caption.monospaced())
            Text("Rotation: \(String(format: "%.1f", piece.rotation))°")
                .font(.caption.monospaced())
            Text("Confidence: \(String(format: "%.2f", piece.confidence))")
                .font(.caption.monospaced())
            Text("State: \(piece.validationState.rawValue)")
                .font(.caption)
                .foregroundColor(validationColor(piece.validationState))
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func validationColor(_ state: PlacedPiece.ValidationState) -> Color {
        switch state {
        case .pending: return .orange
        case .correct: return .green
        case .incorrect: return .red
        }
    }
}
```

#### 2.2 Add Debug Mode Toggle
**Modify:** `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift`

```swift
// Add to TangramGameViewModel
var showDebugMode: Bool = false

func toggleDebugMode() {
    showDebugMode.toggle()
}
```

**Modify:** `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Views/TangramGameView.swift`

```swift
// Add debug button to gameHeader (line 110)
Button(action: viewModel.toggleDebugMode) {
    Image(systemName: viewModel.showDebugMode ? "eye.fill" : "eye")
        .font(.body)
        .foregroundColor(viewModel.showDebugMode ? .blue : .secondary)
}
.buttonStyle(.plain)

// Add overlay to gamePlayView (line 86)
ZStack {
    // Existing SpriteKit view
    TangramSpriteView(...)
    
    // Debug overlay
    if viewModel.showDebugMode {
        VStack {
            Spacer()
            CoordinateDisplayOverlay(
                placedPieces: viewModel.placedPieces,
                showDebugInfo: viewModel.showDebugMode
            )
        }
    }
}
```

### Phase 3: Implement CV-Format Mock Data Generation

#### 3.1 Create Mock CV Data Generator
**New file:** `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Services/MockCVDataGenerator.swift`

```swift
import Foundation
import CoreGraphics

class MockCVDataGenerator {
    
    /// Generate mock CV data in the exact format expected from real CV
    func generateMockCVOutput(for puzzle: GamePuzzleData, withNoise: Bool = true) -> [String: Any] {
        let mockObjects = puzzle.targetPieces.map { targetPiece in
            generateMockPieceData(from: targetPiece, withNoise: withNoise)
        }
        
        return [
            "homography": generateMockHomography(),
            "scale": 2.8190987423182827, // Realistic CV scale factor
            "objects": mockObjects
        ]
    }
    
    private func generateMockPieceData(from target: GamePuzzleData.TargetPiece, withNoise: Bool) -> [String: Any] {
        // Extract position from transform matrix
        var position = [target.transform.tx, target.transform.ty]
        var rotation = extractRotationDegrees(from: target.transform)
        
        // NOTE: Noise/jitter is a stretch goal - skip for MVP
        // if withNoise {
        //     let positionNoise = Double.random(in: -5...5)
        //     let rotationNoise = Double.random(in: -3...3)
        //     position[0] += positionNoise
        //     position[1] += positionNoise
        //     rotation += rotationNoise
        // }
        
        return [
            "name": cvNameForPieceType(target.pieceType),
            "class_id": cvClassId(target.pieceType),
            "pose": [
                "rotation_degrees": rotation,
                "translation": position
            ],
            "vertices": generateMockVertices(target: target, withNoise: withNoise)
        ]
    }
    
    private func extractRotationDegrees(from transform: CGAffineTransform) -> Double {
        let radians = atan2(transform.b, transform.a)
        return radians * 180.0 / .pi
    }
    
    private func cvNameForPieceType(_ type: TangramPieceType) -> String {
        switch type {
        case .smallTriangle1, .smallTriangle2: return "tangram_triangle_sml"
        case .mediumTriangle: return "tangram_triangle_med"
        case .largeTriangle1: return "tangram_triangle_lrg"
        case .largeTriangle2: return "tangram_triangle_lrg2"
        case .square: return "tangram_square"
        case .parallelogram: return "tangram_parallelogram"
        }
    }
    
    private func cvClassId(_ type: TangramPieceType) -> Int {
        switch type {
        case .parallelogram: return 0
        case .square: return 1
        case .largeTriangle1: return 2
        case .largeTriangle2: return 3
        case .mediumTriangle: return 4
        case .smallTriangle1: return 5
        case .smallTriangle2: return 6
        }
    }
    
    // Additional helper methods...
}
```

#### 3.2 Integrate Mock CV Generator
**Modify:** `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift`

```swift
// Add property
private let mockCVGenerator = MockCVDataGenerator()

// Add method to simulate CV input
func simulatePerfectCVInput() {
    guard let puzzle = selectedPuzzle else { return }
    
    let mockCVData = mockCVGenerator.generateMockCVOutput(for: puzzle, withNoise: false)
    processMockCVData(mockCVData)
}

func simulateRealisticCVInput() {
    guard let puzzle = selectedPuzzle else { return }
    
    let mockCVData = mockCVGenerator.generateMockCVOutput(for: puzzle, withNoise: true)
    processMockCVData(mockCVData)
}

private func processMockCVData(_ cvData: [String: Any]) {
    guard let objects = cvData["objects"] as? [[String: Any]] else { return }
    
    let recognizedPieces = objects.compactMap { objectData -> RecognizedPiece? in
        // Convert CV format to RecognizedPiece
        convertCVObjectToRecognizedPiece(objectData)
    }
    
    // Process as if from real CV
    _ = processMockCVInput(recognizedPieces)
}
```

### Phase 3: Core Validation System (Priority: CRITICAL)

#### 4.1 Implement Tolerance-Based Validation
**Modify:** `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift`

```swift
// Replace validatePieces method (line 362) with tolerance-based validation
private func validatePiecesWithTolerance() {
    guard let puzzle = selectedPuzzle else { return }
    
    for i in 0..<placedPieces.count {
        var piece = placedPieces[i]
        
        // Only validate stationary pieces
        guard piece.isPlacedLongEnough() else {
            piece.validationState = .pending
            placedPieces[i] = piece
            continue
        }
        
        // Find matching target using tolerance-based validation
        let matchingTarget = puzzle.targetPieces.first { target in
            isValidPlacement(piece: piece, target: target)
        }
        
        piece.validationState = matchingTarget != nil ? .correct : .incorrect
        placedPieces[i] = piece
    }
}

private func isValidPlacement(piece: PlacedPiece, target: GamePuzzleData.TargetPiece) -> Bool {
    // Check piece type match
    guard piece.pieceType == target.pieceType else { return false }
    
    // Extract target position and rotation from transform
    let targetPosition = CGPoint(x: target.transform.tx, y: target.transform.ty)
    let targetRotation = atan2(target.transform.b, target.transform.a) * 180.0 / .pi
    
    // Check position tolerance
    let positionDistance = hypot(
        piece.position.x - targetPosition.x,
        piece.position.y - targetPosition.y
    )
    
    guard positionDistance <= TangramGameConstants.positionTolerance else { return false }
    
    // Check rotation tolerance (handle 360° wrapping)
    let rotationDifference = abs(piece.rotation - targetRotation)
    let normalizedRotationDiff = min(rotationDifference, 360 - rotationDifference)
    
    return normalizedRotationDiff <= TangramGameConstants.rotationTolerance
}
```

### Phase 4: Basic Testing Controls (Priority: MEDIUM)

#### 5.1 Add Mock CV Control Panel
**New file:** `/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Views/MockCVControlPanel.swift`

```swift
struct MockCVControlPanel: View {
    let onPerfectPlacement: () -> Void
    let onRealisticPlacement: () -> Void
    let onClearPieces: () -> Void
    let onRandomNoise: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Mock CV Controls")
                .font(.headline)
            
            // MVP: Just basic controls
            Button("Simulate CV Detection", action: onPerfectPlacement)
                .buttonStyle(.bordered)
            
            Button("Clear All", action: onClearPieces)
                .buttonStyle(.bordered)
            
            // Stretch goals:
            // - Realistic placement with noise
            // - Random jitter simulation
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
```

#### 4.2 Integration with Game View
Add the control panel to the debug overlay in `TangramGameView.swift`.

## Simplified Implementation Timeline

### MVP Phase (3-4 days)
**Goal:** Get core CV simulation working at 30 FPS

**Day 1-2: Essential Changes**
1. Remove snapping logic from TangramPuzzleScene
2. Add simple CV coordinate display overlay
3. Keep manual drag/rotate for testing

**Day 3: Validation Logic**
1. Implement tolerance-based validation
2. Replace snap-to-target with coordinate matching
3. Test with existing puzzles (cat, rocket ship)

**Day 4: Basic Testing**
1. Add simple CV simulation button
2. Verify 30 FPS performance
3. Debug coordinate display formatting

### Stretch Goals (Future)
- Add noise/jitter to simulate real CV imperfection
- Multiple confidence levels
- Piece occlusion simulation
- Advanced debug controls

## Key Implementation Notes

### Performance Target
- **30 FPS refresh rate** for coordinate updates
- Use `Timer.publish(every: 0.033)` for SwiftUI updates
- Debounce validation checks to every 100ms

### Coordinate Format (Must Match CV Output)
```json
{
  "name": "tangram_square",
  "class_id": 1,
  "pose": {
    "rotation_degrees": 45.0,
    "translation": [300.0, -200.0]
  }
}
```

### Validation Tolerances (Start Generous)
- Position: ±15 pixels
- Rotation: ±10 degrees
- Can tighten later based on testing

## Success Criteria

1. **Pieces display CV-format coordinates** in real-time
2. **No automatic snapping** - pieces stay where placed
3. **Tolerance-based validation** working correctly
4. **30 FPS performance** maintained
5. **Debug toggle** shows/hides coordinate overlay

## Files to Modify (Priority Order)

1. `TangramPuzzleScene.swift` - Remove snapping
2. `TangramGameView.swift` - Add coordinate overlay
3. `TangramGameViewModel.swift` - Update validation logic
4. `TangramGameConstants.swift` - Add tolerance values

This pragmatic approach focuses on the essential CV simulation features first, with complex enhancements as future improvements.

### Phase 5: Performance Optimization (Priority: LOW)

#### 5.1 Target 30 FPS
- Update coordinate display at 30 FPS (33ms intervals)
- Debounce validation checks to avoid excessive computation
- Simple rendering without complex animations

#### 6.2 Visual Polish
- Add coordinate trails showing piece movement history
- Implement proper CV confidence visualization
- Add realistic detection latency simulation

## Implementation Timeline

### Week 1: Core Infrastructure
- Phase 1: Remove unrealistic behaviors
- Phase 2: Implement coordinate display system
- Basic mock CV data generation

### Week 2: Advanced Features  
- Phase 3: Complete mock CV generator
- Phase 4: Enhanced validation system
- Integration and testing

### Week 3: Polish and Testing
- Phase 5: Control panel and testing tools
- Phase 6: Performance optimization and visual polish
- Final testing and validation

## Success Criteria

### Technical Validation
1. ✅ No touch-based piece manipulation
2. ✅ All positioning via coordinate data only
3. ✅ Real-time coordinate display matching CV format
4. ✅ Tolerance-based validation (not automatic snapping)
5. ✅ Debug mode for development testing

### Gameplay Validation
1. ✅ Realistic puzzle solving experience
2. ✅ Proper difficulty scaling with tolerances
3. ✅ Smooth integration with existing game flow
4. ✅ Performance maintains 60 FPS

### Integration Readiness
1. ✅ Mock data format exactly matches expected CV output
2. ✅ Easy swap-out of mock generator for real CV service
3. ✅ Comprehensive testing tools for CV scenarios
4. ✅ Proper error handling for invalid/missing data

## File Summary

### New Files to Create
- `CoordinateDisplayOverlay.swift` - Real-time coordinate display
- `MockCVDataGenerator.swift` - CV format data generation  
- `MockCVControlPanel.swift` - Testing controls

### Existing Files to Modify
- `TangramPuzzleScene.swift` - Remove touch handling (major changes)
- `TangramGameViewModel.swift` - Add mock CV integration and validation
- `TangramGameView.swift` - Add debug mode and coordinate overlay
- `TangramGameConstants.swift` - Add tolerance configuration

### Files to Reference (No Changes Needed)
- `PlacedPiece.swift` - Already has proper CV integration structure
- `GamePuzzleData.swift` - Transform system works correctly
- `TangramGameGeometry.swift` - Vertex calculations are accurate
- `cv-output-explainer.md` - CV format specification
- `json-explainer.md` - Coordinate system documentation

This plan transforms the current touch-based Tangram game into a realistic mock CV system that accurately simulates the final computer vision integration while maintaining all existing functionality and visual polish.