# CV-First Implementation Tracker - Phase 1: Core Infrastructure & Conversion Pipeline

## Overview
This tracker covers Phase 1 of 4 for the CV-first Tangram game transformation. Phase 1 establishes the core infrastructure for CV↔Internal conversion, coordinate systems, and data flow foundations.

## Phase Breakdown (All 4 Phases)

### Phase 1: Core Infrastructure & Conversion Pipeline ← **CURRENT**
- CV↔Internal converter with all coordinate transformations
- Type mapping and piece identification system
- Scale calibration with fallbacks
- Homography handling
- Vertex canonicalization
- Angle/rotation helpers

### Phase 2: Three-Zone Layout & Anchor System
- Three-zone scene implementation
- Dynamic anchor management with promotion
- Touch handling without snapping
- Zone transition logic
- Assembly area management

### Phase 3: CV Stream Generation & Validation
- Touch→CV output bridge
- Real-time CV stream generation
- Relative position map builder
- Relative validation system
- Tolerance configuration

### Phase 4: Integration & Polish
- Stability checking and throttling
- Debug overlay and tools
- Persistence layer
- Performance optimization
- Testing and validation

---

## Phase 1 Detailed Implementation Tracker

### 📋 Pre-Implementation Checklist
- [ ] Review current codebase structure
- [ ] Identify files to modify or replace
- [ ] Verify Swift build targets

### 🎯 Objective
Establish the foundational conversion pipeline that handles all CV↔Internal coordinate transformations with proper scale calibration, homography handling, and vertex processing.

---

## Task 1: Create CVToInternalConverter Base Structure

### 1.1 Create File and Class Structure
**File:** `Bemo/Features/Game/Games/Tangram/Services/CVToInternalConverter.swift`

- [ ] Create new Swift file in correct directory
- [ ] Add file header with documentation
- [ ] Import required frameworks (Foundation, CoreGraphics, UIKit)
- [ ] Create CVToInternalConverter class with @Observable annotation

### 1.2 Add Core Properties
- [ ] Add `isCameraInverted` computed property with UserDefaults backing
- [ ] Add `squareSideInCV` computed property with UserDefaults backing
- [ ] Add piece state tracking dictionary
- [ ] Add schema version constant = 1

### 1.3 Add Documentation Block
- [ ] Copy comprehensive documentation from checkpoint doc
- [ ] Verify all contracts are documented
- [ ] Add usage examples in comments

**Validation:**
- [ ] File compiles without errors
- [ ] UserDefaults keys are unique and prefixed
- [ ] Documentation is clear and complete

---

## Task 2: Implement Type Mapping System

### 2.1 Create TangramPieceType Enum
**File:** `Bemo/Features/Game/Games/Tangram/Models/TangramPieceType.swift`

- [ ] Create enum with all 7 piece types
- [ ] Add String raw values for serialization
- [ ] Add CaseIterable conformance

### 2.2 Implement CV Name Mapping
- [ ] Create `mapCVNameToType(_ name: String) -> TangramPieceType?` function
- [ ] Map all CV names to internal types:
  - `tangram_square` → `.square`
  - `tangram_triangle_sml` → `.smallTriangle1`
  - `tangram_triangle_sml2` → `.smallTriangle2`
  - `tangram_triangle_med` → `.mediumTriangle`
  - `tangram_triangle_lrg` → `.largeTriangle1`
  - `tangram_triangle_lrg2` → `.largeTriangle2`
  - `tangram_parallelogram` → `.parallelogram`
- [ ] Create reverse mapping function `mapTypeToCV`
- [ ] Add CV class ID mapping function

### 2.3 Add Symmetry Rules
- [ ] Create `getRotationalSymmetry(for type:)` function
- [ ] Return correct symmetry angles:
  - Square: 90°
  - Triangles: 180°
  - Parallelogram: 360° (no rotational symmetry)

**Validation:**
- [ ] All 7 piece types map correctly both ways
- [ ] No missing or duplicate mappings
- [ ] Symmetry values are correct

---

## Task 3: Implement Scale Calibration System

### 3.1 Create Calibration Function
- [ ] Implement `calibrateScale(from cvData:)` function
- [ ] Try square vertices first (most reliable)
- [ ] Add fallback to large triangle (leg = square side)
- [ ] Add fallback to medium triangle (leg = square/√2)
- [ ] Add fallback to small triangle (leg = square/2)
- [ ] Cache calibration in UserDefaults

### 3.2 Add Helper Functions
- [ ] Create edge length calculation helper
- [ ] Create `findRightAngleVertex` for triangles
- [ ] Add validation for minimum vertex count

### 3.3 Handle Edge Cases
- [ ] Check for empty objects array
- [ ] Validate vertex array lengths
- [ ] Handle missing vertices gracefully
- [ ] Add logging for calibration source

**Validation:**
- [ ] Calibration works with only square visible
- [ ] Each fallback calculates correct scale
- [ ] Scale persists across sessions
- [ ] No crashes with malformed data

---

## Task 4: Implement Vertex Canonicalization

### 4.1 Create Main Canonicalization Function
- [ ] Implement `canonicalizeVertices(_ vertices:, for type:)` function
- [ ] Handle squares/parallelograms (min Y, then min X)
- [ ] Handle triangles (start from right angle)
- [ ] Maintain clockwise ordering

### 4.2 Implement Right-Angle Detection
- [ ] Calculate all three edge lengths
- [ ] Find longest edge (hypotenuse)
- [ ] Return vertex opposite to hypotenuse
- [ ] Handle degenerate cases

### 4.3 Create Flip Detection
- [ ] Implement `detectFlipFromVertices(_ obj:)` function
- [ ] Use shoelace formula for signed area
- [ ] Interpret winding order correctly
- [ ] Only apply to parallelogram

**Validation:**
- [ ] Vertices always start from canonical corner
- [ ] Ordering is consistently clockwise
- [ ] Flip detection works for all orientations
- [ ] No index out of bounds errors

---

## Task 5: Implement Homography Handling

### 5.1 Create Homography Check
- [ ] Check for `homography_applied` flag in CV data
- [ ] If false and homography present, prepare to apply
- [ ] If true or missing, use coordinates as-is
- [ ] Don't reject non-identity matrices

### 5.2 Implement Homography Application (if needed)
- [ ] Create `applyHomography(_ matrix:, to objects:)` function
- [ ] Apply 3x3 matrix transformation to coordinates
- [ ] Handle vertices transformation
- [ ] Preserve other object properties

### 5.3 Add Identity Check Helper
- [ ] Create `isIdentityHomography(_ matrix:)` function
- [ ] Check diagonal = 1, others = 0 with epsilon
- [ ] Use for logging/debugging only

**Validation:**
- [ ] Accepts CV data with non-identity homography
- [ ] Correctly applies homography when needed
- [ ] Preserves data when already transformed
- [ ] No false rejections

---

## Task 6: Implement Main Conversion Function

### 6.1 Create convertToInternal Function
- [ ] Handle homography check/application first
- [ ] Load cached scale or trigger calibration
- [ ] Process each object in CV data
- [ ] Apply confidence and stability filters

### 6.2 Process Each Piece
- [ ] Extract name, pose, vertices, object_id
- [ ] Map CV name to internal type
- [ ] Canonicalize vertices BEFORE other processing
- [ ] Normalize coordinates by scale
- [ ] Convert degrees to radians

### 6.3 Handle Camera Inversion
- [ ] Check isCameraInverted flag
- [ ] If inverted, add π to rotation
- [ ] If inverted, negate x and y
- [ ] Maintain consistency across all pieces

### 6.4 Create Internal Data Structure
- [ ] Define InternalPiece struct with:
  - id: String
  - type: TangramPieceType
  - position: CGPoint (normalized)
  - rotation: Double (radians)
  - isFlipped: Bool
- [ ] Define InternalPuzzleState wrapper
- [ ] Return complete state

**Validation:**
- [ ] Conversion handles all piece types
- [ ] Coordinates are properly normalized
- [ ] Angles are in radians
- [ ] Camera inversion works correctly

---

## Task 7: Implement Angle/Rotation Helpers

### 7.1 Create Angle Normalization
- [ ] Implement `normalizeAngle(_ angle:)` function
- [ ] Normalize to (-π, π] range
- [ ] Handle multiple rotations correctly
- [ ] Add unit tests for edge cases

### 7.2 Create Vector Rotation Extension
- [ ] Extend CGVector with `rotated(by angle:)` method
- [ ] Use rotation matrix (cos/sin)
- [ ] Maintain CCW positive convention
- [ ] Test with known angles

### 7.3 Add Symmetry Reduction
- [ ] Create `reduceAngleBySymmetry(_ angle:, symmetry:)` function
- [ ] Reduce rotation to smallest equivalent
- [ ] Handle all symmetry types correctly

**Validation:**
- [ ] Angles normalize correctly
- [ ] Vector rotation maintains magnitude
- [ ] Symmetry reduction works for all pieces

---

## Task 8: Add Logging and Debugging

### 8.1 Add Comprehensive Logging
- [ ] Log calibration source and value
- [ ] Log piece type mapping
- [ ] Log coordinate transformations
- [ ] Log camera inversion state

### 8.2 Create Debug Helpers
- [ ] Add pretty-print for CV data
- [ ] Add validation state inspector
- [ ] Create coordinate system visualizer
- [ ] Add performance timing logs

### 8.3 Add Error Handling
- [ ] Graceful handling of malformed CV data
- [ ] Clear error messages
- [ ] Recovery strategies
- [ ] Never crash on bad input

**Validation:**
- [ ] Logs provide useful debugging info
- [ ] No sensitive data in logs
- [ ] Performance impact minimal
- [ ] Errors are actionable

---

## Task 9: Create Unit Tests

### 9.1 Test Type Mapping
- [ ] Test all CV name → type mappings
- [ ] Test reverse mappings
- [ ] Test invalid names return nil
- [ ] Test symmetry values

### 9.2 Test Scale Calibration
- [ ] Test square calibration
- [ ] Test each fallback piece
- [ ] Test persistence
- [ ] Test invalid data handling

### 9.3 Test Vertex Processing
- [ ] Test canonicalization for each shape
- [ ] Test flip detection
- [ ] Test various orientations
- [ ] Test edge cases

### 9.4 Test Coordinate Conversion
- [ ] Test normalization
- [ ] Test camera inversion
- [ ] Test angle conversion
- [ ] Test full pipeline

**Validation:**
- [ ] All tests pass
- [ ] Good code coverage (>80%)
- [ ] Edge cases covered
- [ ] Tests are maintainable

---

## Task 10: Integration Preparation

### 10.1 Create Integration Points
- [ ] Create mock CV data generator for testing
- [ ] Add converter to DependencyContainer
- [ ] Wire up to game structure

### 10.2 Performance Validation
- [ ] Measure conversion performance
- [ ] Test with 20Hz stream rate
- [ ] Check memory usage
- [ ] Optimize hot paths if needed

**Validation:**
- [ ] Converter integrates cleanly
- [ ] Performance meets requirements
- [ ] Ready for Phase 2

---

## 📊 Success Metrics for Phase 1

### Functional Requirements
- [ ] All 7 piece types correctly mapped
- [ ] Scale calibration works with any piece
- [ ] Coordinates properly normalized
- [ ] Camera inversion toggle works
- [ ] Homography handled correctly
- [ ] Vertices canonicalized consistently

### Performance Requirements  
- [ ] Conversion < 5ms for 7 pieces
- [ ] No memory leaks
- [ ] Smooth 60 FPS maintained
- [ ] 20Hz stream rate supported

### Code Quality
- [ ] All functions documented
- [ ] No compiler warnings
- [ ] Unit test coverage > 80%
- [ ] Code follows Swift style guide

### Integration Readiness
- [ ] Clean API surface
- [ ] Mock data generator working
- [ ] Ready for Phase 2 three-zone layout

---

## 🚨 Risk Mitigation

### Identified Risks
1. **Scale calibration fails** → Multiple fallbacks implemented
2. **Vertex order inconsistent** → Canonicalization applied to all
3. **Camera inversion confusion** → Manual toggle with persistence
4. **Performance issues** → Profiling and optimization points identified
5. **Coordinate system mismatch** → Single conversion boundary


---

## 📝 Notes & Decisions Log

### Key Decisions Made
- Single conversion boundary pattern
- UserDefaults for all persistence
- Manual camera inversion (no auto-detect)
- Normalized units (square = 1.0)
- CCW positive rotation convention

### Open Questions
- [ ] Confirm CV team's homography_applied flag name
- [ ] Verify scale values from real CV
- [ ] Test with actual device orientations

### Dependencies
- No external dependencies
- Uses standard iOS frameworks only
- Compatible with iOS 17+

---

## ✅ Phase 1 Completion Checklist

### Code Complete
- [ ] All 10 tasks implemented
- [ ] All subtasks checked off
- [ ] Tests passing

### Validation
- [ ] Manual testing with mock data
- [ ] Performance benchmarks met
- [ ] Ready for Phase 2

---

## Next Steps (Phase 2 Preview)
Once Phase 1 is complete and validated:
1. Begin three-zone layout implementation
2. Create dynamic anchor system
3. Remove snap-to-target behavior
4. Implement zone transition logic

---

*Last Updated: [Current Date]*
*Phase 1 of 4 - Core Infrastructure*
*Estimated Time: 2-3 days*